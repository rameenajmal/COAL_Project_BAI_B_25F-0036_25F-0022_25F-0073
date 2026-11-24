; ============================================================
; File    : blocks.asm
; Module  : 12 - Blocks, Coins and Power-ups (Section 5.9)
; Author  : 25F-0022 (Faryal Fatima)
; Purpose : * HandleHeadHit    - what happens when Mario's head hits a
;                                brick or a "?" block from below
;           * Coin pop effect  - the coin that jumps out of a coin
;                                "?" block (StartCoinPop,
;                                UpdateCoinPops, DrawCoinPops)
;           * CollectCoinTiles - coins lying on the map
;           The mushroom itself is an entity (SpawnMushroom, the
;           mushroom movement and MakeHeroSuper are in enemies.asm).
;           Only the WORKING map is changed; level_original stays
;           intact so ResetMap can restore it.
; Notes   : DrawCoinPops must be called from DrawScene (states.asm)
;           after DrawMap, so the popping coin is drawn over the map.
; ============================================================

TILE_SKY       EQU 0
TILE_BRICK     EQU 2
TILE_Q_COIN    EQU 3            ; "?" block with a coin
TILE_Q_MUSH    EQU 4            ; "?" block with a mushroom
TILE_EMPTY     EQU 5            ; empty block
TILE_COIN      EQU 11

POP_MAX        EQU 4            ; coin pops that can show at the same time
POP_FRAMES     EQU 12           ; one pop lasts 12 frames (about 2/3 s)

; ---- scratch variables of HandleHeadHit ----
hh_cols        db 0, 0, 0       ; candidate columns: centre, left, right

; ---- coin pop records (one byte each, POP_MAX entries) ----
pop_col        times POP_MAX db 0   ; tile column of the block
pop_row        times POP_MAX db 0   ; tile row of the block
pop_timer      times POP_MAX db 0   ; frames left, 0 = slot free

; height of the coin above the block for every frame of the pop
; (it shoots up, slows down, falls back a little and disappears)
pop_rise       db 8, 15, 21, 26, 30, 33, 35, 36, 35, 32, 28, 23

; ---- scratch variables of CollectCoinTiles ----
cc_row         dw 0
cc_col         dw 0
cc_last_row    dw 0
cc_last_col    dw 0
cc_first_col   dw 0

; ------------------------------------------------------------
; HandleHeadHit
; Purpose : Use the head hit recorded by CollideHeroY
;           (head_hit_flag, head_hit_col, head_hit_row).
;           The head touches up to three columns (left edge, centre,
;           right edge). A "?" block in any of them is taken first,
;           then a brick, so a "?" block always reacts even when it
;           is hit with the edge of the head.
;           Brick        : Small Mario - nothing; Super Mario - the
;                          brick becomes sky, +50.
;           "?" coin     : becomes an empty block, a coin pops out,
;                          +200, coins + 1.
;           "?" mushroom : becomes an empty block, a mushroom
;                          appears on top and starts moving.
;           Empty block, ground, pipe ... : nothing.
;           Also ages the coin pops (called once per playing frame).
; Inputs  : head_hit_flag, head_hit_col, head_hit_row, hero_x, form
; Outputs : level_working, score, coins, entity_table, coin pops
;           head_hit_flag is cleared
; Changes : none
; ------------------------------------------------------------
HandleHeadHit:
    push ax
    push bx
    push cx
    push dx
    push si

    call UpdateCoinPops             ; coin pops move every frame

    cmp  byte [head_hit_flag], 1
    je   .hit                       ; short jumps only (8086 safe)
    jmp  .done
.hit:
    mov  byte [head_hit_flag], 0

    ; ---- the three columns the head touches ----
    mov  al, [head_hit_col]         ; centre of the head
    mov  [hh_cols], al
    mov  ax, [hero_x]
    add  ax, HITBOX_LEFT
    shr  ax, 4
    mov  [hh_cols + 1], al          ; left edge
    mov  ax, [hero_x]
    add  ax, HITBOX_RIGHT
    shr  ax, 4
    mov  [hh_cols + 2], al          ; right edge

    ; ---- pass 1: look for a "?" block ----
    xor  si, si
.find_q:
    mov  al, [hh_cols + si]
    call GetHitTile                 ; AL = tile code, BX = map offset
    cmp  al, TILE_Q_COIN
    je   .found
    cmp  al, TILE_Q_MUSH
    je   .found
    inc  si
    cmp  si, 3
    jb   .find_q

    ; ---- pass 2: look for a brick ----
    xor  si, si
.find_brick:
    mov  al, [hh_cols + si]
    call GetHitTile
    cmp  al, TILE_BRICK
    je   .found
    inc  si
    cmp  si, 3
    jb   .find_brick
    jmp  .done                      ; empty block, ground, pipe ...

.found:
    mov  ah, [hh_cols + si]
    mov  [head_hit_col], ah         ; the column that really reacts
    cmp  al, TILE_BRICK
    je   .brick
    cmp  al, TILE_Q_COIN
    je   .coin_block
    jmp  .mushroom_block

.brick:
    cmp  byte [form], FORM_SUPER
    jne  .done                      ; Small Mario: the brick stays
    mov  byte [level_working + bx], TILE_SKY
    push word 50
    call AddScore
    jmp  .done

.coin_block:
    mov  byte [level_working + bx], TILE_EMPTY
    push word 200
    call AddScore
    call AddCoin
    call StartCoinPop               ; the coin jumps out of the block
    jmp  .done

.mushroom_block:
    mov  byte [level_working + bx], TILE_EMPTY
    xor  ax, ax
    mov  al, [head_hit_col]
    shl  ax, 4                      ; x = column * 16
    push ax
    xor  ax, ax
    mov  al, [head_hit_row]
    dec  ax
    shl  ax, 4                      ; y = (row - 1) * 16: on top of the block
    push ax
    call SpawnMushroom

.done:
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; ------------------------------------------------------------
; GetHitTile
; Purpose : Tile code in the row of the head hit at one column.
; Inputs  : AL = tile column, head_hit_row
; Outputs : AL = tile code (0 if outside the map)
;           BX = offset in level_working (row * LEVEL_W + column)
; Changes : AX, BX
; ------------------------------------------------------------
GetHitTile:
    push dx
    xor  ah, ah
    cmp  al, LEVEL_W
    jae  .outside
    mov  bx, ax                     ; BX = column
    xor  ax, ax
    mov  al, [head_hit_row]
    cmp  al, LEVEL_H
    jae  .outside
    mov  dx, LEVEL_W
    mul  dx                         ; AX = row * LEVEL_W
    add  bx, ax                     ; BX = offset of the tile
    mov  al, [level_working + bx]
    xor  ah, ah
    jmp  .out
.outside:
    xor  ax, ax
    xor  bx, bx
.out:
    pop  dx
    ret

; ============================================================
; Coin pop effect (coin released by a "?" block)
; ============================================================

; ------------------------------------------------------------
; StartCoinPop
; Purpose : Start a coin pop above the block that was just hit.
;           Uses the first free slot; if all are busy, slot 0 is
;           reused (the points are already given anyway).
; Inputs  : head_hit_col, head_hit_row
; Outputs : pop_col, pop_row, pop_timer
; Changes : none
; ------------------------------------------------------------
StartCoinPop:
    push ax
    push si

    xor  si, si
.find:
    cmp  byte [pop_timer + si], 0
    je   .use
    inc  si
    cmp  si, POP_MAX
    jb   .find
    xor  si, si                     ; all busy: reuse the oldest slot
.use:
    mov  al, [head_hit_col]
    mov  [pop_col + si], al
    mov  al, [head_hit_row]
    mov  [pop_row + si], al
    mov  byte [pop_timer + si], POP_FRAMES

    pop  si
    pop  ax
    ret

; ------------------------------------------------------------
; UpdateCoinPops
; Purpose : Every running coin pop loses one frame.
; Inputs  : pop_timer      Outputs : pop_timer      Changes : none
; ------------------------------------------------------------
UpdateCoinPops:
    push si

    xor  si, si
.next:
    cmp  byte [pop_timer + si], 0
    je   .skip
    dec  byte [pop_timer + si]
.skip:
    inc  si
    cmp  si, POP_MAX
    jb   .next

    pop  si
    ret

; ------------------------------------------------------------
; DrawCoinPops
; Purpose : Draw every running coin pop: the coin sprite above its
;           block, at the height of pop_rise for that frame.
;           screen x = column * 16 - camera_x
;           screen y = row * 16 - 16 - rise
;           A pop whose block is no longer empty (the map was reset
;           after a lost life) is cancelled.
; Inputs  : pop records, camera_x, level_working
; Outputs : coin sprites in the frame buffer
; Changes : none
; ------------------------------------------------------------
DrawCoinPops:
    push ax
    push bx
    push cx
    push dx
    push si

    xor  si, si
.next:
    cmp  byte [pop_timer + si], 0
    je   .skip

    ; is the block still the empty block it became?
    xor  ax, ax
    mov  al, [pop_row + si]
    mov  bx, LEVEL_W
    mul  bx                         ; AX = row * LEVEL_W (DX = 0)
    xor  bx, bx
    mov  bl, [pop_col + si]
    add  bx, ax
    cmp  byte [level_working + bx], TILE_EMPTY
    je   .draw
    mov  byte [pop_timer + si], 0   ; map was reset: cancel the pop
    jmp  .skip

.draw:
    xor  ax, ax                     ; CX = screen x
    mov  al, [pop_col + si]
    shl  ax, 4
    sub  ax, [camera_x]
    cmp  ax, -16
    jle  .skip                      ; left of the screen
    cmp  ax, SCREEN_W
    jge  .skip                      ; right of the screen
    mov  cx, ax

    mov  bl, POP_FRAMES             ; BX = age of the pop (0 .. 11)
    sub  bl, [pop_timer + si]
    xor  bh, bh
    xor  dx, dx
    mov  dl, [pop_rise + bx]        ; DX = height above the block

    xor  ax, ax                     ; AX = screen y
    mov  al, [pop_row + si]
    shl  ax, 4
    sub  ax, TILE_SIZE              ; tile above the block
    sub  ax, dx                     ; minus the rise

    push cx                         ; DrawSprite(x, y, coin, flags 0)
    push ax
    push word coin_sprite
    push word 0
    call DrawSprite
.skip:
    inc  si
    cmp  si, POP_MAX
    jb   .next

    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret

; ============================================================
; Coins lying on the map
; ============================================================

; ------------------------------------------------------------
; CollectCoinTiles
; Purpose : Every coin tile that Mario's hitbox touches is taken:
;           the tile becomes sky, +200 points, coins + 1
;           (100 coins give a life, see AddCoin).
; Inputs  : hero_x, hero_y, form, level_working
; Outputs : level_working, score, coins
; Changes : none
; ------------------------------------------------------------
CollectCoinTiles:
    push ax
    push bx
    push dx

    mov  ax, [hero_x]               ; first and last tile column
    add  ax, HITBOX_LEFT
    shr  ax, 4
    mov  [cc_first_col], ax
    mov  ax, [hero_x]
    add  ax, HITBOX_RIGHT
    shr  ax, 4
    mov  [cc_last_col], ax
    mov  ax, [hero_y]               ; first and last tile row
    shr  ax, 4
    mov  [cc_row], ax
    call GetHeroHeight
    add  ax, [hero_y]
    dec  ax
    shr  ax, 4
    mov  [cc_last_row], ax

.row_loop:
    mov  ax, [cc_row]
    cmp  ax, [cc_last_row]
    ja   .done                      ; unsigned: also stops for rows < 0
    cmp  ax, LEVEL_H
    jae  .next_row                  ; row outside the map
    mov  ax, [cc_first_col]
    mov  [cc_col], ax
.col_loop:
    mov  ax, [cc_col]
    cmp  ax, [cc_last_col]
    ja   .next_row
    cmp  ax, LEVEL_W
    jae  .next_col

    mov  bx, [cc_row]               ; BX = row * LEVEL_W + column
    mov  ax, LEVEL_W
    mul  bx
    mov  bx, ax
    add  bx, [cc_col]
    cmp  byte [level_working + bx], TILE_COIN
    jne  .next_col
    mov  byte [level_working + bx], TILE_SKY
    push word 200
    call AddScore
    call AddCoin
.next_col:
    inc  word [cc_col]
    jmp  .col_loop
.next_row:
    inc  word [cc_row]
    jmp  .row_loop
.done:
    pop  dx
    pop  bx
    pop  ax
    ret
