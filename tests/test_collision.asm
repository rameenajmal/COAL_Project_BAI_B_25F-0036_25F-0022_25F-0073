; ============================================================
; File    : test_collision.asm
; Purpose : Test Module 10. Shows X, Y, VX, VY, GND, HEAD, PIT (hex).
;           The test builds its own wall and pit in the working map.
; ============================================================
ORG 100h
%include "constants.asm"        ; EQUs only (no bytes)

start:
    call ResetMap               ; original map -> working map
    call ResetHero              ; Mario at the start

    ; ---- test obstacles (working map only) ----
    mov  byte [level_working + 9*LEVEL_W + 12], 10   ; 1-tile wall, col 12
    mov  byte [level_working + 10*LEVEL_W + 20], 0   ; pit: cols 20..22,
    mov  byte [level_working + 10*LEVEL_W + 21], 0   ;      rows 10 and 11
    mov  byte [level_working + 10*LEVEL_W + 22], 0
    mov  byte [level_working + 11*LEVEL_W + 20], 0
    mov  byte [level_working + 11*LEVEL_W + 21], 0
    mov  byte [level_working + 11*LEVEL_W + 22], 0

    mov  ax, 0003h              ; clear screen (text mode)
    int  10h
    mov  ah, 09h
    mov  dx, msg
    int  21h

    call InstallKeyboard
    mov  ax, 0B800h             ; text-mode video memory
    mov  es, ax

main_loop:
    call WaitTick               ; one step per tick (Esc quits here)
    call UpdateHorizontal       ; speed from keys
    call MoveHeroX              ; move by speed
    call CollideHeroX           ; wall / level edge check

    push word [hero_x]          ; X at col 0
    push word 480
    call ShowHex16
    push word [hero_vx]         ; VX at col 12
    push word 504
    call ShowHex16
    jmp  main_loop

; ---- stand-ins for Rameen's drawing code (map.asm needs them) ----
camera_x dw 0
FillRect:
    ret  10                     ; 5 word parameters, draws nothing

msg db 'Arrows move, Shift runs, Space jumps, Esc quits.', 0Dh, 0Ah
    db 0Dh, 0Ah
    db 'X     Y     VX    VY    GND   HEAD  PIT', 0Dh, 0Ah, '$'

; ---- paste WaitTick and ShowHex16 from test_player.asm here ----

%include "map.asm"
%include "level_data.asm"
%include "input.asm"
%include "player.asm"
%include "collision.asm"