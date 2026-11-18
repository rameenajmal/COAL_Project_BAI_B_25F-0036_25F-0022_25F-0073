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

    call ResetMap               ; fill working map from original
    call DrawMap                ; draw the level

    mov ah, 0                   ; wait for any key
    int 16h

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