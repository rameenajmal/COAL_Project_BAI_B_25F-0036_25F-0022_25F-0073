; ============================================================
; File    : mario.asm
; Module  : 1 (Program Skeleton and Build Setup)
; Purpose : Main file of MARIO.COM. Sets the entry point at
;           ORG 100h, switches to VGA Mode 13h, sets the custom
;           palette colours, resets and draws the level map,
;           waits for a key, then returns to text mode and DOS.
;           All other source files are joined here with %include.
; Build   : sh build.sh (Mac) or build.bat (Windows)
; Author  : 25F-0036
; ============================================================
ORG 100h

%include "constants.asm"

%macro FILL 5
    push word %1
    push word %2
    push word %3
    push word %4
    push word %5
    call FillRect
%endmacro
start:
    mov ax, 0013h               ; switch to mode 13h
    int 10h

    push word 20
    push word 23
    push word 37
    push word 63
    call SetColour

    push word 21
    push word 30
    push word 18
    push word 8
    call SetColour

    push COL_SKIN
    push 63
    push 46
    push 30
    call SetColour
    call ResetMap               ; fill working map from original
    call InitBuffer
    mov ax, [buffer_seg]
    mov [draw_seg], ax

    call InstallTimer

; test: one bar grows 4 pixels per second, esc exits
test_loop:
    call WaitTick
    call UpdateClock

    push 0
    push 0
    push SCREEN_W
    push 200
    push COL_BLACK
    call FillRect

    mov ax, 300
    sub ax, [game_time]
    shl ax, 2
    add ax, 4
    push 10
    push 60
    push ax
    push 20
    push COL_COIN
    call FillRect

    mov ax, [tick_count]
    and ax, 127
    add ax, 4
    push 10
    push 120
    push ax
    push 20
    push COL_HERO
    call FillRect

    call ShowBuffer

    mov ah, 1
    int 16h
    jz test_loop
    mov ah, 0
    int 16h
    cmp ah, 01h
    jne test_loop

    call RestoreTimer
    mov ax, 0003h               ; back to text mode
    int 10h
    mov ax, 4C00h               ; exit to DOS
    int 21h
test_exit:
    mov ax, 0003h               ; back to text mode
    int 10h
    mov ax, 4C00h               ; exit to DOS
    int 21h

%include "video.asm"
%include "buffer.asm"
%include "map.asm"
%include "level_data.asm"
%include "sprites.asm"
%include "sprite_data.asm"
%include "camera.asm"
%include "timer.asm"
%include "input.asm"
%include "player.asm"
%include "collision.asm"
%include "blocks.asm"
%include "enemies.asm"
%include "hud.asm"
%include "states.asm"
%include "reset.asm"