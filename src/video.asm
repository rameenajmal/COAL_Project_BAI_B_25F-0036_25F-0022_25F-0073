; ============================================================
; File    : video.asm
; Module  : 2 (Video Mode and Colours)
; Purpose : Basic drawing routines for VGA Mode 13h (320x200,
;           video segment 0A000h).
;           PutPixel(x, y, colour)  - draws one pixel
;           FillRect(x, y, w, h, colour) - draws a filled rectangle
;           SetColour(index, r, g, b) - sets a palette colour
;           (r, g, b are 0 to 63)
;           Offset = y*320 + x, calculated with shifts (y*256 + y*64).
;           All parameters are passed on the stack.
; Author  : 25F-0036
; ============================================================
; PutPixel | draws one pixel | in: x, y, colour (stack) | out: none | changes: none
PutPixel:
    push bp
    mov bp, sp
    push ax
    push bx
    push di
    push es

    mov es, [draw_seg]
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

; FillRect | draws a filled rectangle | in: x, y, w, h, colour (stack) 
;| out: none | changes: none
FillRect:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push di
    push es

    mov es, [draw_seg]
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
; SetColour | sets one palette colour | 
;in: index, r, g, b (stack, 0-63) | out: none | changes: none
SetColour:
    push bp
    mov bp, sp
    push ax
    push dx

    mov dx, 3C8h
    mov al, [bp+10]             ; index
    out dx, al
    inc dx                      ; port 3C9h
    mov al, [bp+8]              ; red
    out dx, al
    mov al, [bp+6]              ; green
    out dx, al
    mov al, [bp+4]              ; blue
    out dx, al

    pop dx
    pop ax
    pop bp
    ret 8

