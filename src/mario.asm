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
    mov ax, 0013h           ; switch to mode 13h
    int 10h

    ; one swatch for every game colour
    FILL 10,  20, 24, 24, COL_SKY
    FILL 50,  20, 24, 24, COL_GROUND
    FILL 90,  20, 24, 24, COL_BRICK
    FILL 130, 20, 24, 24, COL_PIPE
    FILL 170, 20, 24, 24, COL_HERO
    FILL 210, 20, 24, 24, COL_ENEMY
    FILL 250, 20, 24, 24, COL_COIN
    FILL 10,  60, 24, 24, COL_TEXT

    mov si, 100             ; row of single pixels with PutPixel
pixel_loop:
    push si
    push word 100
    push word COL_TEXT
    call PutPixel
    inc si
    cmp si, 140
    jne pixel_loop

    mov ah, 0               ; wait for any key
    int 16h

    mov ax, 0003h           ; back to text mode
    int 10h
    mov ax, 4C00h           ; exit to DOS
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