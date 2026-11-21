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
