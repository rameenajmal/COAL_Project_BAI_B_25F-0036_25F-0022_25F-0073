; ============================================================
; File    : player.asm
; Module  : 9 - Player Movement and Physics
; Purpose : Hero data (position, velocity, health, flags) and
;           the physics rules of Section 5.2.
; Notes   : Velocity is 8.8 fixed point (high byte = whole pixels,
;           low byte = fraction). Position is a 16-bit pixel word
;           plus an 8-bit fraction byte, because x goes up to 944
;           and does not fit in the high byte of an 8.8 word.
; ============================================================

; ---- Physics constants (Appendix A.5, 8.8 fixed point) ----
ACCEL        EQU 0020h          ; walk acceleration   0.125 px/frame^2
BRAKE        EQU 0040h          ; braking (opposite key) 0.25 px/frame^2
FRICTION     EQU 0010h          ; friction            0.0625 px/frame^2
MAX_WALK     EQU 0180h          ; maximum walk speed  1.5 px/frame
MAX_RUN      EQU 0280h          ; maximum run speed   2.5 px/frame
GRAVITY      EQU 0040h          ; gravity             0.25 px/frame^2
JUMP_START   EQU 0FA80h         ; jump start speed   -5.5 px/frame
JUMP_CUTOFF  EQU 0FE00h         ; jump cut-off speed -2.0 px/frame
MAX_FALL     EQU 0400h          ; maximum fall speed  4.0 px/frame

; ---- Start position and hero states ----
HERO_START_X EQU 32             ; world x at level start (pixels)
HERO_START_Y EQU 144            ; top of Small Mario standing on row 9
FORM_SMALL   EQU 0
FORM_SUPER   EQU 1
POSE_STAND   EQU 0
POSE_RUN     EQU 1
POSE_JUMP    EQU 2

; ---- Hero data (kept together on purpose) ----
hero_x        dw 0              ; world x, whole pixels
hero_x_frac   db 0              ; world x, fraction (1/256 pixel)
hero_y        dw 0              ; world y (top of sprite), whole pixels
hero_y_frac   db 0              ; world y, fraction
hero_vx       dw 0              ; horizontal velocity, 8.8 signed
hero_vy       dw 0              ; vertical velocity, 8.8 signed
hero_facing   db 1              ; 1 = facing right, 0 = facing left
hero_pose     db 0              ; POSE_STAND / POSE_RUN / POSE_JUMP
on_ground     db 0              ; 1 = standing on solid ground
jump_locked   db 0              ; 1 = Space still held since last jump
form          db 0              ; FORM_SMALL or FORM_SUPER
hp            db 1              ; health: 1 = Small, 2 = Super
invuln_timer  dw 0              ; frames of invulnerability left
stomp_chain   db 0              ; consecutive stomps in one jump

; ------------------------------------------------------------
; ResetHero
; Purpose : Put the hero back at the level start as Small Mario.
;           Used at new game and after every death.
; Inputs  : none
; Outputs : all hero variables set to their start values
; Changes : none (no registers used)
; ------------------------------------------------------------
ResetHero:
    mov  word [hero_x], HERO_START_X
    mov  byte [hero_x_frac], 0
    mov  word [hero_y], HERO_START_Y
    mov  byte [hero_y_frac], 0
    mov  word [hero_vx], 0
    mov  word [hero_vy], 0
    mov  byte [hero_facing], 1
    mov  byte [hero_pose], POSE_STAND
    mov  byte [on_ground], 0
    mov  byte [jump_locked], 0
    mov  byte [form], FORM_SMALL
    mov  byte [hp], 1
    mov  word [invuln_timer], 0
    mov  byte [stomp_chain], 0
    ret

; ------------------------------------------------------------
; MoveHeroX
; Purpose : Add the horizontal velocity to the x position.
;           Fraction is added first; its carry goes into the
;           whole-pixel part (ADC). Whole part is sign-extended
;           so negative speeds move Mario left.
; Inputs  : hero_vx
; Outputs : hero_x, hero_x_frac updated
; Changes : none (AX is saved)
; ------------------------------------------------------------
MoveHeroX:
    push ax
    mov  ax, [hero_vx]          ; AH = whole part, AL = fraction
    add  [hero_x_frac], al      ; add fraction, carry goes to CF
    mov  al, ah                 ; AL = whole part of speed
    cbw                         ; sign-extend AL into AX (flags unchanged)
    adc  [hero_x], ax           ; x = x + whole part + carry
    pop  ax
    ret

; ------------------------------------------------------------
; MoveHeroY
; Purpose : Add the vertical velocity to the y position
;           (same method as MoveHeroX).
; Inputs  : hero_vy
; Outputs : hero_y, hero_y_frac updated
; Changes : none (AX is saved)
; ------------------------------------------------------------
MoveHeroY:
    push ax
    mov  ax, [hero_vy]
    add  [hero_y_frac], al
    mov  al, ah
    cbw
    adc  [hero_y], ax
    pop  ax
    ret

    ; ------------------------------------------------------------
; UpdateHorizontal
; Purpose : Walk / run / brake / friction (Section 5.2).
;           Right or Left accelerates up to the speed limit
;           (Shift = run limit). Opposite key brakes faster.
;           No key (or both keys) -> friction slows Mario to 0.
; Inputs  : key_state (via IsKeyHeld), hero_vx
; Outputs : hero_vx, hero_facing updated
; Changes : none (AX, BX, CX are saved)
; ------------------------------------------------------------
UpdateHorizontal:
    push ax
    push bx
    push cx

    mov  bx, MAX_WALK           ; BX = speed limit (walk by default)
    push word SC_LSHIFT
    call IsKeyHeld
    cmp  al, 1
    jne  .limit_ready
    mov  bx, MAX_RUN            ; Shift held -> run limit
.limit_ready:
    push word SC_RIGHT
    call IsKeyHeld
    mov  cl, al                 ; CL = Right held?
    push word SC_LEFT
    call IsKeyHeld
    mov  ch, al                 ; CH = Left held?

    mov  ax, [hero_vx]          ; AX = current speed
    cmp  cl, ch
    je   .friction              ; none or both keys -> friction
    cmp  cl, 1
    je   .go_right
    jmp  .go_left

.go_right:
    mov  byte [hero_facing], 1
    cmp  ax, 0
    jl   .brake_right           ; moving left -> brake
    add  ax, ACCEL
    jmp  .clamp_right
.brake_right:
    add  ax, BRAKE
.clamp_right:
    cmp  ax, bx                 ; signed compare with the limit
    jle  .store
    mov  ax, bx                 ; do not exceed the limit
    jmp  .store

.go_left:
    mov  byte [hero_facing], 0
    cmp  ax, 0
    jg   .brake_left            ; moving right -> brake
    sub  ax, ACCEL
    jmp  .clamp_left
.brake_left:
    sub  ax, BRAKE
.clamp_left:
    neg  bx                     ; BX = -limit
    cmp  ax, bx
    jge  .store
    mov  ax, bx
    jmp  .store

.friction:
    cmp  ax, 0
    jg   .slow_positive
    jl   .slow_negative
    jmp  .store                 ; already 0
.slow_positive:
    sub  ax, FRICTION
    jge  .store
    xor  ax, ax                 ; went below 0 -> stop exactly
    jmp  .store
.slow_negative:
    add  ax, FRICTION
    jle  .store
    xor  ax, ax                 ; went above 0 -> stop exactly

.store:
    mov  [hero_vx], ax
    pop  cx
    pop  bx
    pop  ax
    ret