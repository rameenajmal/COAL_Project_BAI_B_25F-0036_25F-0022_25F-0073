; ============================================================
; File    : blocks.asm
; Module  : 12 - Blocks, Coins and Power-ups (Section 5.9)
; Purpose : * HandleHeadHit    - what happens when Mario's head hits a
;                                brick or a "?" block from below
;           * CollectCoinTiles - coins lying on the map
;           The mushroom itself is an entity (SpawnMushroom and the
;           mushroom movement are in enemies.asm).
;           Only the WORKING map is changed; level_original stays
;           intact so ResetMap can restore it.
; ============================================================

TILE_SKY       EQU 0
TILE_BRICK     EQU 2
TILE_Q_COIN    EQU 3            ; "?" block with a coin
TILE_Q_MUSH    EQU 4            ; "?" block with a mushroom
TILE_EMPTY     EQU 5            ; empty block
TILE_COIN      EQU 11

cc_row         dw 0             ; scratch variables of CollectCoinTiles
cc_col         dw 0
cc_last_row    dw 0
cc_last_col    dw 0
cc_first_col   dw 0

; ------------------------------------------------------------
; HandleHeadHit
; Purpose : Use the head hit recorded by CollideHeroY
;           (head_hit_flag, head_hit_col, head_hit_row).
;           Brick  : Small Mario - nothing; Super Mario - the brick
;                    becomes sky, +50.
;           "?" coin     : becomes an empty block, +200, coins + 1.
;           "?" mushroom : becomes an empty block, a mushroom
;                          appears on top and starts moving.
;           Empty block  : nothing.
; Inputs  : head_hit_flag, head_hit_col, head_hit_row, form
; Outputs : level_working, score, coins, entity_table
;           head_hit_flag is cleared
; Changes : none
; ------------------------------------------------------------
HandleHeadHit:
    push ax
    push bx
    push dx

    cmp  byte [head_hit_flag], 1
    jne  .done
    mov  byte [head_hit_flag], 0

    xor  ax, ax                     ; BX = row * LEVEL_W + column
    mov  al, [head_hit_row]
    mov  bx, LEVEL_W
    mul  bx
    mov  bx, ax
    xor  ax, ax
    mov  al, [head_hit_col]
    add  bx, ax

    mov  al, [level_working + bx]   ; tile code that was hit
    cmp  al, TILE_BRICK
    je   .brick
    cmp  al, TILE_Q_COIN
    je   .coin_block
    cmp  al, TILE_Q_MUSH
    je   .mushroom_block
    jmp  .done                      ; empty block, ground, pipe ...

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
    pop  dx
    pop  bx
    pop  ax
    ret

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