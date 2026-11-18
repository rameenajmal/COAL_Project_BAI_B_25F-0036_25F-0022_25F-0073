tile_colours:
    db COL_SKY, COL_GROUND, COL_BRICK, COL_COIN, COL_COIN, COL_EMPTY
    db COL_PIPE, COL_PIPE, COL_PIPE, COL_PIPE
    db COL_GROUND, COL_COIN, COL_TEXT

; DrawTile(x, y, code) - push x, push y, push code
DrawTile:
    push bp
    mov bp, sp
    push ax
    push bx

    mov bx, [bp+4]              ; tile code
    mov al, [tile_colours + bx]
    xor ah, ah
    push word [bp+8]            ; x
    push word [bp+6]            ; y
    push word TILE_SIZE
    push word TILE_SIZE
    push ax                     ; colour
    call FillRect

    pop bx
    pop ax
    pop bp
    ret 6

; DrawMap - draws the 20 visible columns, no parameters
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

; ResetMap - copies original map over the working map
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