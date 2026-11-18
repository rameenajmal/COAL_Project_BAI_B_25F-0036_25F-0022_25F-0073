ORG 100h

SCREEN_W  EQU 320
SCREEN_H  EQU 200
TILE_SIZE EQU 16

start:
    mov ax, 4C00h      ; DOS pe wapas jao
    int 21h

%include "constants.asm"
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