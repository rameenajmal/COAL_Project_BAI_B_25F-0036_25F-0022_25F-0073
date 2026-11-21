; ============================================================
; File    : collision.asm
; Module  : 10 - Collision Detection
; Purpose : Tile collision for Mario (Section 5.6). Mario is moved
;           one axis at a time; after each move we check the tiles
;           and push him back out of walls, floors and ceilings.
; Notes   : Hitbox is 12 pixels wide, centred in the 16-pixel
;           sprite (x+2 .. x+13). Height is 16 (Small) or 32 (Super).
;           Uses GetTile(px, py) from map.asm.
; ============================================================

; ---- Collision constants ----
HITBOX_LEFT    EQU 2                       ; left edge offset from sprite x
HITBOX_RIGHT   EQU 13                      ; right edge offset from sprite x
SMALL_HEIGHT   EQU 16                      ; Small Mario hitbox height
SUPER_HEIGHT   EQU 32                      ; Super Mario hitbox height
MAP_BOTTOM     EQU 192                     ; bottom of the map in pixels (pit line)
LEVEL_PIXELS_W EQU LEVEL_W * TILE_SIZE     ; level width in pixels (960)
HERO_MAX_X     EQU LEVEL_PIXELS_W - TILE_SIZE  ; right-most x for the sprite (944)

; ---- Collision results (read by other modules) ----
head_hit_flag  db 0             ; 1 = Mario's head hit a solid tile
head_hit_col   db 0             ; tile column of the hit (under head centre)
head_hit_row   db 0             ; tile row of the hit
pit_fall       db 0             ; 1 = Mario fell below the map (y >= 192)

; ------------------------------------------------------------
; GetHeroHeight
; Purpose : Return the hitbox height of Mario's current form.
; Inputs  : form
; Outputs : AX = 16 (Small) or 32 (Super)
; Changes : AX
; ------------------------------------------------------------
GetHeroHeight:
    mov  ax, SMALL_HEIGHT
    cmp  byte [form], FORM_SUPER
    jne  .done
    mov  ax, SUPER_HEIGHT
.done:
    ret

; ------------------------------------------------------------
; IsSolidAt(px, py)             parameters on the stack
; Purpose : Safe wrapper around GetTile. Tells if the pixel
;           (px, py) is inside a solid tile (codes 1..10).
;           Left/right outside the level counts as wall;
;           above the top or below the bottom counts as empty.
; Inputs  : [bp+6] = px, [bp+4] = py   (push px first, then py)
; Outputs : AL = 1 solid, 0 not solid (AH = 0)
; Changes : AX only
; ------------------------------------------------------------
IsSolidAt:
    push bp
    mov  bp, sp

    mov  ax, [bp + 6]           ; AX = px
    cmp  ax, LEVEL_PIXELS_W
    jae  .solid                 ; outside left/right end -> wall
    mov  ax, [bp + 4]           ; AX = py
    cmp  ax, MAP_BOTTOM
    jae  .empty                 ; above top / below bottom -> empty

    push word [bp + 6]          ; GetTile(px, py)
    push word [bp + 4]
    call GetTile                ; AL = tile code
    cmp  al, 1
    jb   .empty                 ; 0 = sky
    cmp  al, 10
    ja   .empty                 ; 11 coin, 12 flag pole: not solid
.solid:
    mov  al, 1
    jmp  .done
.empty:
    xor  al, al
.done:
    xor  ah, ah
    pop  bp
    ret  4

; ------------------------------------------------------------
; IsBodySolidAt(px)             parameter on the stack
; Purpose : Check a vertical line at x = px along Mario's body
;           (top, every 16 pixels, and bottom row) for solid tiles.
; Inputs  : [bp+4] = px, hero_y, form
; Outputs : AL = 1 if any probe is solid, else 0
; Changes : AX only (BX, CX, DX saved)
; ------------------------------------------------------------
IsBodySolidAt:
    push bp
    mov  bp, sp
    push bx
    push cx
    push dx

    call GetHeroHeight          ; AX = height
    mov  cx, ax
    dec  cx                     ; CX = offset of the last body row
    xor  bx, bx                 ; BX = current probe offset
.probe:
    mov  dx, [hero_y]
    add  dx, bx                 ; DX = probe y
    push word [bp + 4]
    push dx
    call IsSolidAt
    cmp  al, 1
    je   .found
    cmp  bx, cx
    jae  .none                  ; last row already probed
    add  bx, 16                 ; next probe one tile lower
    cmp  bx, cx
    jbe  .probe
    mov  bx, cx                 ; past the end -> probe the last row
    jmp  .probe
.none:
    xor  al, al
    jmp  .out
.found:
    mov  al, 1
.out:
    xor  ah, ah
    pop  dx
    pop  cx
    pop  bx
    pop  bp
    ret  2

; ------------------------------------------------------------
; CollideHeroX
; Purpose : Call right after MoveHeroX. Keeps Mario inside the
;           level (x = 0 .. 944) and stops him against solid tiles:
;           moving right -> check right edge (x+13), snap so the
;           edge touches the wall; moving left -> check left edge
;           (x+2). Horizontal speed becomes 0 on contact.
; Inputs  : hero_x, hero_vx, hero_y, form
; Outputs : hero_x, hero_x_frac, hero_vx corrected
; Changes : none (AX saved)
; ------------------------------------------------------------
CollideHeroX:
    push ax

    mov  ax, [hero_x]
    cmp  ax, 0
    jge  .check_right_end
    mov  word [hero_x], 0           ; left end of the level
    jmp  .stop
.check_right_end:
    cmp  ax, HERO_MAX_X
    jle  .check_wall
    mov  word [hero_x], HERO_MAX_X  ; right end of the level
    jmp  .stop

.check_wall:
    mov  ax, [hero_vx]
    cmp  ax, 0
    je   .done                      ; not moving sideways
    jl   .moving_left

    mov  ax, [hero_x]               ; moving right: right edge
    add  ax, HITBOX_RIGHT
    push ax
    call IsBodySolidAt
    cmp  al, 1
    jne  .done
    mov  ax, [hero_x]
    add  ax, HITBOX_RIGHT
    and  ax, 0FFF0h                 ; left edge of the wall tile
    sub  ax, HITBOX_RIGHT + 1       ; right edge just touches the wall
    mov  [hero_x], ax
    jmp  .stop

.moving_left:
    mov  ax, [hero_x]               ; moving left: left edge
    add  ax, HITBOX_LEFT
    push ax
    call IsBodySolidAt
    cmp  al, 1
    jne  .done
    mov  ax, [hero_x]
    add  ax, HITBOX_LEFT
    and  ax, 0FFF0h                 ; left edge of the wall tile
    add  ax, TILE_SIZE - HITBOX_LEFT ; left edge just touches the wall

    mov  [hero_x], ax

.stop:
    mov  byte [hero_x_frac], 0
    mov  word [hero_vx], 0
.done:
    pop  ax
    ret