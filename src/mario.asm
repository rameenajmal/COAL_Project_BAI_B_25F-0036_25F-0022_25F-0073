ORG 100h

SCREEN_W  EQU 320
SCREEN_H  EQU 200
TILE_SIZE EQU 16

start:
    mov ax, 4C00h      ; DOS pe wapas jao
    int 21h

%include "video.asm"
%include "map.asm"
%include "input.asm"
%include "game.asm"