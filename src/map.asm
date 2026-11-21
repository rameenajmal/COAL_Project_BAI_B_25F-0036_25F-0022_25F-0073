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

; DrawTile | draws a tile bitmap, skips sky | in: x, y, code (stack) | out: none | changes: none
DrawTile:
    push bp
    mov bp, sp
    push ax
    push bx

    mov bx, [bp+4]
    cmp bx, 0
    je dt_done
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

; DrawMap | draws the visible 21 tile columns using camera_x | in: camera_x | out: none | changes: none
DrawMap:
    push ax
    push bx
    push cx
    push dx

    push 0
    push 0
    push SCREEN_W
    push 192
    push COL_SKY
    call FillRect

    mov ax, [camera_x]
    shr ax, 4
    mov [map_first], ax
    mov word [map_row], 0

; row loop: one map row at a time
dm_row:
    mov word [map_col], 0

; column loop: 21 columns, skips columns past the level end
dm_col:
    mov bx, [map_first]
    add bx, [map_col]
    cmp bx, LEVEL_W
    jge dm_next_col

    mov ax, [map_row]
    mov cx, LEVEL_W
    mul cx
    add bx, ax
    mov al, [level_working+bx]
    mov ah, 0
    mov dx, ax

    mov ax, [map_col]
    shl ax, 4
    mov cx, [camera_x]
    and cx, 15
    sub ax, cx
    push ax
    mov ax, [map_row]
    shl ax, 4
    push ax
    push dx
    call DrawTile

dm_next_col:
    inc word [map_col]
    cmp word [map_col], 21
    jl dm_col

    inc word [map_row]
    cmp word [map_row], LEVEL_H
    jl dm_row

    pop dx
    pop cx
    pop bx
    pop ax
    ret

map_first dw 0
map_row   dw 0
map_col   dw 0
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