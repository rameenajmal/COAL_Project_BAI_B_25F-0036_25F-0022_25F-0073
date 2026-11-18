; PutPixel(x, y, colour) - push x, push y, push colour, then call
PutPixel:
    push bp
    mov bp, sp
    push ax
    push bx
    push di
    push es

    mov ax, 0A000h
    mov es, ax
    mov bx, [bp+6]          ; y
    mov di, bx
    shl di, 8               ; y * 256
    shl bx, 6               ; y * 64
    add di, bx              ; y * 320
    add di, [bp+8]          ; + x
    mov al, [bp+4]          ; colour
    mov [es:di], al

    pop es
    pop di
    pop bx
    pop ax
    pop bp
    ret 6

; FillRect(x, y, w, h, colour) - push in this order, then call
FillRect:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push di
    push es

    mov ax, 0A000h
    mov es, ax
    mov bx, [bp+10]         ; y
    mov di, bx
    shl di, 8
    shl bx, 6
    add di, bx
    add di, [bp+12]         ; di = start of first row
    mov al, [bp+4]          ; colour
    mov dx, [bp+6]          ; rows left

.next_row:
    mov cx, [bp+8]          ; width
    push di
.next_pixel:
    mov [es:di], al
    inc di
    loop .next_pixel
    pop di
    add di, 320             ; go to next row
    dec dx
    jnz .next_row

    pop es
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 10