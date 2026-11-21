; ============================================================
; File    : test_collision.asm
; Purpose : Test Module 10 (floor, walls, head hit, pit, flag pole).
;           Builds its own wall, stairs, flag pole and pit in the
;           working map. Enter = restart the test, Esc = quit.
; ============================================================
ORG 100h
%include "constants.asm"        ; EQUs only (no bytes)

start:
    call ResetMap               ; original map -> working map
    call ResetHero              ; Mario at the start

    ; ---- test obstacles (working map only) ----
    mov  byte [level_working + 9*LEVEL_W + 12], 10   ; stair 1 high, col 12
    mov  byte [level_working + 9*LEVEL_W + 13], 10   ; stair 2 high, col 13
    mov  byte [level_working + 8*LEVEL_W + 13], 10
    mov  byte [level_working + 9*LEVEL_W + 14], 10   ; stair 3 high, col 14
    mov  byte [level_working + 8*LEVEL_W + 14], 10
    mov  byte [level_working + 7*LEVEL_W + 14], 10
    mov  byte [level_working + 9*LEVEL_W + 15], 10   ; flag base block, col 15
    mov  cx, 7                                       ; flag pole rows 2..8
    mov  bx, level_working + 2*LEVEL_W + 15
.pole:
    mov  byte [bx], 12
    add  bx, LEVEL_W
    loop .pole
    mov  byte [level_working + 10*LEVEL_W + 20], 0   ; pit: cols 20..22
    mov  byte [level_working + 10*LEVEL_W + 21], 0
    mov  byte [level_working + 10*LEVEL_W + 22], 0
    mov  byte [level_working + 11*LEVEL_W + 20], 0
    mov  byte [level_working + 11*LEVEL_W + 21], 0
    mov  byte [level_working + 11*LEVEL_W + 22], 0

    mov  ax, 0003h              ; clear screen (text mode)
    int  10h
    mov  ah, 09h                ; print instructions and column titles
    mov  dx, msg
    int  21h

    call InstallKeyboard
    mov  ax, 0B800h             ; text-mode video memory
    mov  es, ax

main_loop:
    call WaitTick               ; one step per tick (Esc quits here)
    call SaveHeroPrevFeet       ; remember feet position before moving
    call UpdateHorizontal       ; speed from keys
    call UpdateVertical         ; jump and gravity
    call MoveHeroWithCollision  ; move and collide, X then Y
    call CheckFlagPole          ; flag pole touched?
    push word 128               ; fake enemy at x=128, y=144, 16 x 16
    push word 144
    push word 16
    push word 16
    call DecideStompOrHurt
    cmp  al, 0
    je   .no_hit
    cmp  byte [test_result], 0
    jne  .no_hit                ; keep only the first result
    mov  [test_result], al
.no_hit:
    call SetHeroPose

    push word SC_ENTER          ; Enter restarts the test
    call IsKeyHeld
    cmp  al, 1
    jne  .no_restart
    call ResetHero
    call ClearCollisionFlags
    mov  word [flag_points], 0
    mov  byte [test_result], 0
.no_restart:
    cmp  word [hero_y], 200     ; fell far enough -> respawn
    jl   .alive
    call ResetHero              ; (PIT flag stays 1 as proof)
.alive:

    push word [hero_x]          ; X at col 0
    push word 480
    call ShowHex16
    push word [hero_y]          ; Y at col 6
    push word 492
    call ShowHex16
    push word [hero_vx]         ; VX at col 12
    push word 504
    call ShowHex16
    push word [hero_vy]         ; VY at col 18
    push word 516
    call ShowHex16
    mov  al, [on_ground]        ; GND at col 24
    add  al, '0'
    mov  ah, 07h
    mov  [es:528], ax
    mov  al, [head_hit_flag]    ; HEAD at col 30
    add  al, '0'
    mov  ah, 07h
    mov  [es:540], ax
    mov  al, [pit_fall]         ; PIT at col 36
    add  al, '0'
    mov  ah, 07h
    mov  [es:552], ax
    mov  al, [flag_touched]     ; FLAG at col 42
    add  al, '0'
    mov  ah, 07h
    mov  [es:564], ax
    push word [flag_points]     ; PTS at col 48
    push word 576
    call ShowHex16
    mov  al, [test_result]      ; RES at col 54
    add  al, '0'
    mov  ah, 07h
    mov  [es:588], ax
    jmp  main_loop              ; always the LAST line of the loop

; ------------------------------------------------------------
; WaitTick
; Purpose : Wait until the BIOS timer tick counter (0040:006C)
;           changes. Esc is checked while waiting, so a quick tap
;           is never missed. Only for this test; the game uses
;           Module 8.
; Inputs  : none
; Outputs : none (exits to DOS if Esc is pressed)
; Changes : none
; ------------------------------------------------------------
WaitTick:
    push ax
    push dx
    push es
    mov  ax, 0040h
    mov  es, ax
    mov  dx, [es:006Ch]         ; DX = current tick count
.same:
    push word SC_ESC            ; check Esc while waiting
    call IsKeyHeld
    cmp  al, 1
    je   .quit
    cmp  dx, [es:006Ch]
    je   .same                  ; wait until the tick changes
    pop  es
    pop  dx
    pop  ax
    ret
.quit:
    call RestoreKeyboard        ; restore BEFORE returning to DOS
    mov  ax, 4C00h
    int  21h

; ------------------------------------------------------------
; ShowHex16(value, screen_offset)   parameters on the stack
; Purpose : Print a word as 4 hex digits in text-mode video memory.
; Inputs  : [bp+6] = value, [bp+4] = byte offset in B800 segment
;           (ES must be B800h)
; Outputs : 4 characters on screen
; Changes : none
; ------------------------------------------------------------
ShowHex16:
    push bp
    mov  bp, sp
    push ax
    push bx
    push cx
    push di

    mov  bx, [bp + 6]           ; BX = value
    mov  di, [bp + 4]           ; DI = screen offset
    mov  cx, 4                  ; 4 hex digits
.next_digit:
    rol  bx, 4                  ; bring the next nibble to the bottom
    mov  al, bl
    and  al, 0Fh
    cmp  al, 9
    jbe  .is_digit
    add  al, 7                  ; skip gap between '9' and 'A'
.is_digit:
    add  al, '0'
    mov  ah, 07h                ; grey on black
    mov  [es:di], ax
    add  di, 2
    loop .next_digit

    pop  di
    pop  cx
    pop  bx
    pop  ax
    pop  bp
    ret  4

; ---- stand-ins for Rameen's drawing code (map.asm needs them) ----
test_result db 0                ; first stomp/hurt result of the test
camera_x dw 0
FillRect:
    ret  10                     ; 5 word parameters, draws nothing

msg db 'Arrows move, Shift runs, Space jumps, Enter restarts, Esc quits.', 0Dh, 0Ah
    db 0Dh, 0Ah
    db 'X     Y     VX    VY    GND   HEAD  PIT   FLAG  PTS   RES', 0Dh, 0Ah, '$'
%include "map.asm"
%include "level_data.asm"
%include "input.asm"
%include "player.asm"
%include "collision.asm"