; ============================================================
; File    : test_player.asm
; Purpose : Test Module 9 physics. Shows X, Y, VX, VY (hex).
;           Arrows move, Shift runs. Esc quits.
; ============================================================
ORG 100h

start:
    call ResetHero              ; start values
    mov  ax, 0003h              ; clear screen (text mode)
    int  10h
    mov  ah, 09h                ; print instructions and column titles
    mov  dx, msg
    int  21h

    call InstallKeyboard        ; our keyboard handler on
    mov  ax, 0B800h             ; text-mode video memory
    mov  es, ax

main_loop:
    call WaitTick               ; one step per timer tick
    call UpdateHorizontal       ; speed from keys
    call UpdateVertical         ; jump and gravity
    call MoveHeroX              ; speed -> position
    call MoveHeroY              ; vertical speed -> position
    call TestFloor              ; temporary floor (Module 10 replaces it)

    push word [hero_x]          ; show X at row 3, col 0
    push word 480
    call ShowHex16
    push word [hero_y]          ; show Y at col 6
    push word 492
    call ShowHex16
    push word [hero_vx]         ; show VX at col 12
    push word 504
    call ShowHex16
    push word [hero_vy]         ; show VY at col 18
    push word 516
    call ShowHex16
    mov  al, [on_ground]        ; show on_ground at col 24
    add  al, '0'
    mov  ah, 07h
    mov  [es:528], ax
    

    push word SC_ESC            ; Esc -> leave
    call IsKeyHeld
    cmp  al, 1
    jne  main_loop

    call RestoreKeyboard        ; restore BEFORE returning to DOS
    mov  ax, 4C00h
    int  21h

    
; ------------------------------------------------------------
; TestFloor
; Purpose : Temporary floor for this test only. Real tile
;           collision comes in Module 10.
; Inputs  : hero_y
; Outputs : hero_y, hero_vy, on_ground
; Changes : none
; ------------------------------------------------------------
TestFloor:
    cmp  word [hero_y], HERO_START_Y
    jl   .in_air
    mov  word [hero_y], HERO_START_Y    ; stand on the floor
    mov  byte [hero_y_frac], 0
    mov  word [hero_vy], 0
    mov  byte [on_ground], 1
    ret
.in_air:
    mov  byte [on_ground], 0
    ret

    
; ------------------------------------------------------------
; WaitTick
; Purpose : Wait until the BIOS timer tick counter (0040:006C)
;           changes. Only for this test; the game uses Module 8.
; Inputs  : none
; Outputs : none
; Changes : none
; ------------------------------------------------------------
WaitTick:
    push ax
    push es
    mov  ax, 0040h
    mov  es, ax
    mov  ax, [es:006Ch]         ; current tick count
.same:
    cmp  ax, [es:006Ch]
    je   .same                  ; wait until it changes
    pop  es
    pop  ax
    ret

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

msg db 'Arrows move, Shift runs, Space jumps, Esc quits.', 0Dh, 0Ah
    db 0Dh, 0Ah
    db 'X     Y     VX    VY    GND   POSE', 0Dh, 0Ah, '$'

%include "input.asm"            ; input first (scan code constants)
%include "player.asm"