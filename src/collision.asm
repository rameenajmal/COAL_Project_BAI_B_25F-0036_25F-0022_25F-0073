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

; ------------------------------------------------------------
; CollideHeroY
; Purpose : Call right after MoveHeroY.
;           Falling or standing (vy >= 0): look at the pixel just
;             below the feet (y+h). If solid -> Mario stands on the
;             tile: on_ground = 1, speed 0, stomp chain reset.
;           Rising (vy < 0): look at the top pixel row. If solid ->
;             head hit: record the block (tile under head centre),
;             push Mario down below the tile, speed 0.
;           Pit: if y >= 192, set pit_fall = 1.
; Inputs  : hero_x, hero_y, hero_vy, form
; Outputs : hero_y, hero_y_frac, hero_vy, on_ground, stomp_chain,
;           head_hit_flag/col/row, pit_fall
; Changes : none (AX, BX, CX saved)
; ------------------------------------------------------------
CollideHeroY:
    push ax
    push bx
    push cx

    call GetHeroHeight
    mov  cx, ax                     ; CX = hitbox height

    mov  ax, [hero_vy]
    cmp  ax, 0
    jl   .rising

    ; ---- falling or standing: probe just below the feet ----
    mov  bx, [hero_y]
    add  bx, cx                     ; BX = y + height (pixel below feet)
    mov  ax, [hero_x]
    add  ax, HITBOX_LEFT
    push ax
    push bx
    call IsSolidAt                  ; left foot
    cmp  al, 1
    je   .land
    mov  ax, [hero_x]
    add  ax, HITBOX_RIGHT
    push ax
    push bx
    call IsSolidAt                  ; right foot
    cmp  al, 1
    je   .land
    mov  byte [on_ground], 0        ; nothing below -> in the air
    jmp  .check_pit

.land:
    and  bx, 0FFF0h                 ; top of the tile below
    sub  bx, cx                     ; feet exactly on the tile
    mov  [hero_y], bx
    mov  byte [hero_y_frac], 0
    mov  word [hero_vy], 0
    mov  byte [on_ground], 1
    mov  byte [stomp_chain], 0
    jmp  .check_pit

    ; ---- rising: probe the top row of the hitbox ----
.rising:
    mov  byte [on_ground], 0
    mov  bx, [hero_y]               ; BX = top pixel row of Mario
    mov  ax, [hero_x]
    add  ax, HITBOX_LEFT
    push ax
    push bx
    call IsSolidAt                  ; top-left corner
    cmp  al, 1
    je   .head_hit
    mov  ax, [hero_x]
    add  ax, HITBOX_RIGHT
    push ax
    push bx
    call IsSolidAt                  ; top-right corner
    cmp  al, 1
    je   .head_hit
    jmp  .check_pit

.head_hit:
    mov  ax, [hero_x]
    add  ax, 8                      ; horizontal centre of the head
    shr  ax, 4
    mov  [head_hit_col], al         ; tile column under head centre
    mov  ax, bx
    shr  ax, 4
    mov  [head_hit_row], al         ; tile row that was hit
    mov  byte [head_hit_flag], 1
    shr  bx, 4                      ; row of the hit tile
    inc  bx                         ; one row lower
    shl  bx, 4                      ; = pixel y just below the tile
    mov  [hero_y], bx
    mov  byte [hero_y_frac], 0
    mov  word [hero_vy], 0          ; he starts falling

.check_pit:
    cmp  word [hero_y], MAP_BOTTOM
    jl   .done
    mov  byte [pit_fall], 1         ; fell below the map -> dies
.done:
    pop  cx
    pop  bx
    pop  ax
    ret

; ------------------------------------------------------------
; MoveHeroWithCollision
; Purpose : One full movement step: X first, then Y, each followed
;           by its collision check (frame order step 3, Section 5.13).
; Inputs  : hero variables
; Outputs : hero position/speed/flags updated
; Changes : none
; ------------------------------------------------------------
MoveHeroWithCollision:
    call MoveHeroX
    call CollideHeroX
    call MoveHeroY
    call CollideHeroY
    ret

; ------------------------------------------------------------
; ClearCollisionFlags
; Purpose : Reset head_hit_flag and pit_fall. The game calls this
;           at the start of a life (and after handling a hit).
; Inputs  : none
; Outputs : flags = 0
; Changes : none
; ------------------------------------------------------------
ClearCollisionFlags:
    mov  byte [head_hit_flag], 0
    mov  byte [pit_fall], 0
    mov  byte [flag_touched], 0
    ret

; ============================================================
; Flag pole and rectangle overlap
; ============================================================
TILE_FLAG_POLE EQU 12           ; tile code of the flag pole (Appendix A.2)
HITBOX_WIDTH   EQU 12           ; Mario's hitbox width

flag_touched   db 0             ; 1 = Mario has touched the flag pole
flag_row       db 0             ; map row of Mario's feet at the touch
flag_points    dw 0             ; points for that height (5000 .. 100)

; ------------------------------------------------------------
; GetTileAt(px, py)             parameters on the stack
; Purpose : Safe tile read. Returns 0 (sky) for any pixel outside
;           the map, otherwise the tile code from GetTile.
; Inputs  : [bp+6] = px, [bp+4] = py   (push px first, then py)
; Outputs : AL = tile code (AH = 0)
; Changes : AX only
; ------------------------------------------------------------
GetTileAt:
    push bp
    mov  bp, sp

    mov  ax, [bp + 6]
    cmp  ax, LEVEL_PIXELS_W
    jae  .outside               ; px outside the level
    mov  ax, [bp + 4]
    cmp  ax, MAP_BOTTOM
    jae  .outside               ; py outside the map
    push word [bp + 6]
    push word [bp + 4]
    call GetTile                ; AL = tile code
    jmp  .done
.outside:
    xor  al, al
.done:
    xor  ah, ah
    pop  bp
    ret  4

; ------------------------------------------------------------
; BodyHasFlagAt(px)             parameter on the stack
; Purpose : Look down the line x = px along Mario's body (top,
;           middle, bottom) for a flag pole tile.
; Inputs  : [bp+4] = px, hero_y, form
; Outputs : AL = 1 if a flag pole tile is found, else 0
; Changes : AX only (CX, DX saved)
; ------------------------------------------------------------
BodyHasFlagAt:
    push bp
    mov  bp, sp
    push cx
    push dx

    call GetHeroHeight
    mov  cx, ax
    dec  cx                     ; CX = offset of the bottom body row
    xor  dx, dx                 ; DX = probe offset (0, middle, bottom)
.probe:
    mov  ax, [hero_y]
    add  ax, dx                 ; AX = probe y
    push word [bp + 4]
    push ax
    call GetTileAt
    cmp  al, TILE_FLAG_POLE
    je   .found
    cmp  dx, cx
    jae  .none                  ; bottom row was the last probe
    cmp  dx, 0
    jne  .go_bottom
    mov  dx, cx
    shr  dx, 1                  ; next probe: middle of the body
    jmp  .probe
.go_bottom:
    mov  dx, cx                 ; last probe: bottom row
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
    pop  bp
    ret  2

; ------------------------------------------------------------
; GetFlagPoints(row)            parameter on the stack
; Purpose : Flag score zones (Section 5.4) from the map row of
;           Mario's feet: rows 2-3 = 5000, 4 = 2000, 5 = 800,
;           6-7 = 400, 8 = 100.
; Inputs  : [bp+4] = map row of Mario's feet
; Outputs : AX = points
; Changes : AX only
; ------------------------------------------------------------
GetFlagPoints:
    push bp
    mov  bp, sp

    mov  ax, [bp + 4]
    cmp  ax, 3
    jbe  .top
    cmp  ax, 4
    je   .row4
    cmp  ax, 5
    je   .row5
    cmp  ax, 7
    jbe  .row67
    mov  ax, 100                ; row 8 (bottom)
    jmp  .out
.top:
    mov  ax, 5000
    jmp  .out
.row4:
    mov  ax, 2000
    jmp  .out
.row5:
    mov  ax, 800
    jmp  .out
.row67:
    mov  ax, 400
.out:
    pop  bp
    ret  2

; ------------------------------------------------------------
; CheckFlagPole
; Purpose : Detect Mario touching the flag pole. Looks at the
;           body centre and one pixel beyond the right edge, so
;           the pole is detected as soon as Mario reaches it.
;           On the first touch it records the feet row and points.
; Inputs  : hero_x, hero_y, form, flag_touched
; Outputs : flag_touched = 1, flag_row, flag_points
; Changes : none (AX saved)
; ------------------------------------------------------------
CheckFlagPole:
    push ax

    cmp  byte [flag_touched], 1
    je   .done                  ; already touched, keep first result

    mov  ax, [hero_x]
    add  ax, 8                  ; body centre
    push ax
    call BodyHasFlagAt
    cmp  al, 1
    je   .touched

    mov  ax, [hero_x]
    add  ax, HITBOX_RIGHT + 1   ; one pixel beyond the right edge
    push ax
    call BodyHasFlagAt
    cmp  al, 1
    jne  .done

.touched:
    call GetHeroHeight
    add  ax, [hero_y]
    dec  ax                     ; bottom pixel row of Mario
    shr  ax, 4                  ; map row of his feet
    mov  [flag_row], al
    push ax
    call GetFlagPoints          ; AX = points for that row
    mov  [flag_points], ax
    mov  byte [flag_touched], 1
.done:
    pop  ax
    ret

; ------------------------------------------------------------
; RectsOverlap(x1, y1, w1, h1, x2, y2, w2, h2)   8 words on stack
; Purpose : Rectangle overlap test. The rectangles overlap when
;           x1 < x2+w2, x2 < x1+w1, y1 < y2+h2 and y2 < y1+h1.
; Inputs  : pushed in the order x1, y1, w1, h1, x2, y2, w2, h2
;           [bp+18]=x1 [bp+16]=y1 [bp+14]=w1 [bp+12]=h1
;           [bp+10]=x2 [bp+8]=y2  [bp+6]=w2  [bp+4]=h2
; Outputs : AL = 1 overlap, 0 no overlap (AH = 0)
; Changes : AX only (BX saved)
; ------------------------------------------------------------
RectsOverlap:
    push bp
    mov  bp, sp
    push bx

    mov  ax, [bp + 18]          ; x1
    mov  bx, [bp + 10]
    add  bx, [bp + 6]           ; x2 + w2
    cmp  ax, bx
    jge  .no
    mov  ax, [bp + 10]          ; x2
    mov  bx, [bp + 18]
    add  bx, [bp + 14]          ; x1 + w1
    cmp  ax, bx
    jge  .no
    mov  ax, [bp + 16]          ; y1
    mov  bx, [bp + 8]
    add  bx, [bp + 4]           ; y2 + h2
    cmp  ax, bx
    jge  .no
    mov  ax, [bp + 8]           ; y2
    mov  bx, [bp + 16]
    add  bx, [bp + 12]          ; y1 + h1
    cmp  ax, bx
    jge  .no
    mov  al, 1
    jmp  .out
.no:
    xor  al, al
.out:
    xor  ah, ah
    pop  bx
    pop  bp
    ret  16

; ------------------------------------------------------------
; HeroOverlapsBox(x, y, w, h)   parameters on the stack
; Purpose : Does Mario's hitbox overlap the box (x, y, w, h)?
;           Used for enemies, shells, mushrooms and coins.
; Inputs  : [bp+10]=x [bp+8]=y [bp+6]=w [bp+4]=h  (push x first)
; Outputs : AL = 1 overlap, 0 no overlap
; Changes : AX only
; ------------------------------------------------------------
HeroOverlapsBox:
    push bp
    mov  bp, sp

    mov  ax, [hero_x]
    add  ax, HITBOX_LEFT
    push ax                     ; x1 = hitbox left edge
    push word [hero_y]          ; y1
    push word HITBOX_WIDTH      ; w1
    call GetHeroHeight
    push ax                     ; h1 = 16 or 32
    push word [bp + 10]         ; x2
    push word [bp + 8]          ; y2
    push word [bp + 6]          ; w2
    push word [bp + 4]          ; h2
    call RectsOverlap

    pop  bp
    ret  8