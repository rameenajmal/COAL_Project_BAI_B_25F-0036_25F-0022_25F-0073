; ============================================================
; File    : map.asm
; Module  : 3 (Level Map and Tile Drawing)
; Purpose : Draws and reads the level map.
;           DrawTile(x, y, code) - draws one 16x16 tile in its colour
;           DrawMap  - draws the 20 visible columns x 12 rows
;           ResetMap - copies level_original to level_working
;                      with REP MOVSB
;           GetTile(px, py) - returns the tile code at a pixel
;                      position in AL (used for collision)
;           Tiles are plain colours for now; bitmaps come later.
; Author  : 25F-0036
; ============================================================
tile_colours:
    db COL_SKY, COL_GROUND, COL_BRICK, COL_COIN, COL_COIN, COL_EMPTY
    db COL_PIPE, COL_PIPE, COL_PIPE, COL_PIPE
    db COL_GROUND, COL_COIN, COL_TEXT

; DrawTile | draws one 16x16 tile | in: x, y, code (stack) 
;| out: none | changes: none
DrawTile:
    push bp
    mov bp, sp
    push ax
    push bx

    mov bx, [bp+4]
    cmp bx, 0
    je dt_fill
    cmp bx, 11
    je dt_fill
    cmp bx, 12
    je dt_fill
    jmp dt_bitmap

dt_fill:
    push word [bp+8]
    push word [bp+6]
    push TILE_SIZE
    push TILE_SIZE
    push COL_SKY
    call FillRect
    cmp word [bp+4], 0
    je dt_done

dt_bitmap:
    mov bx, [bp+4]
    shl bx, 1
    mov ax, [tile_table+bx]
    push word [bp+8]
    push word [bp+6]
    push ax
    push 0
    call DrawSprite

dt_done:
    pop bx
    pop ax
    pop bp
    ret 6

; DrawMap | draws the 20 visible columns x 12 rows 
;| in: camera_x | out: none | changes: none
DrawMap:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    mov si, [camera_x]
    shr si, 4                   ; first visible column
    mov di, level_working
    add di, si                  ; di = first visible tile of row 0
    mov dx, 0                   ; screen y

.row_loop:
    mov cx, 0                   ; screen x
    mov bx, di                  ; bx walks along this row
.col_loop:
    mov al, [bx]
    xor ah, ah
    push cx
    push dx
    push ax
    call DrawTile
    inc bx
    add cx, TILE_SIZE
    cmp cx, SCREEN_W
    jb .col_loop

    add di, LEVEL_W             ; next row of the map
    add dx, TILE_SIZE
    cmp dx, 192
    jb .row_loop

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ResetMap | copies level_original to level_working 
;| in: none | out: none | changes: none
ResetMap:
    push cx
    push si
    push di

    cld
    mov si, level_original
    mov di, level_working
    mov cx, LEVEL_W * LEVEL_H
    rep movsb

    pop di
    pop si
    pop cx
    ret

; GetTile | tile code at pixel position | in: px, py (stack) 
;| out: AL = tile code | changes: AX
GetTile:
    push bp
    mov bp, sp
    push bx
    push dx

    mov ax, [bp+4]              ; py
    shr ax, 4                   ; row
    mov bx, LEVEL_W
    mul bx                      ; ax = row * 60
    mov bx, [bp+6]              ; px
    shr bx, 4                   ; column
    add bx, ax                  ; offset
    mov al, [level_working + bx]
    xor ah, ah

    pop dx
    pop bx
    pop bp
    ret 4