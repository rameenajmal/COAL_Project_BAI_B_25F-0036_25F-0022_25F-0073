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
    call GameMain               ; Modules 11, 13, 14, 15 (states.asm), never returns

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