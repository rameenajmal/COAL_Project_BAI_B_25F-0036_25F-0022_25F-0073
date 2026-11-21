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

; test: arrow keys move camera_x by 4, Esc exits
; test: arrow keys move a test Mario, camera follows, Esc exits
test_loop:
    call DrawMap
    mov ax, [test_mario_x]
    sub ax, [camera_x]
    push ax
    push 144
    push mario_stand
    push 0
    call DrawSprite
    call ShowBuffer
    mov ah, 0
    int 16h
    cmp ah, 4Dh
    je test_right
    cmp ah, 4Bh
    je test_left
    cmp ah, 01h
    je test_exit
    jmp test_loop

test_right:
    add word [test_mario_x], 4
    cmp word [test_mario_x], 944
    jle test_update
    mov word [test_mario_x], 944
    jmp test_update

test_left:
    sub word [test_mario_x], 4

test_update:
    push word [test_mario_x]
    call UpdateCamera
    mov [test_mario_x], ax
    jmp test_loop
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