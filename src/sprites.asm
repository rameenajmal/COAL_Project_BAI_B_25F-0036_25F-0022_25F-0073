; ============================================================
; File    : sprites.asm
; Module  : 4 (Sprites)
; Purpose : Draws 16x16 and 16x32 sprites to the draw segment.
;           DrawSprite - transparent colour 0, mirror, blink skip,
;           clipping on all four screen edges.
; Author  : 25F-0036
; ============================================================
draw_seg dw 0A000h
spr_row  dw 0
spr_col  dw 0
spr_h    dw 16

; DrawSprite(x, y, address, flags)  ret 8
DrawSprite:
    push bp
    mov bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    test word [bp+4], 2
    jnz ds_done

    mov es, [draw_seg]
    mov word [spr_h], 16
    test word [bp+4], 4
    jz ds_start
    mov word [spr_h], 32

ds_start:
    mov word [spr_row], 0

; row loop: ek row draw karta hai
ds_row:
    mov bx, [spr_row]
    shl bx, 4
    add bx, [bp+6]
    mov si, bx

    mov ax, [bp+8]
    add ax, [spr_row]
    cmp ax, 0
    jl ds_next_row
    cmp ax, SCREEN_H
    jge ds_next_row

    mov bx, SCREEN_W
    mul bx
    mov di, ax
    mov word [spr_col], 0

ds_col:
    mov ax, [bp+10]
    add ax, [spr_col]
    cmp ax, 0
    jl ds_next_col
    cmp ax, SCREEN_W
    jge ds_next_col

    mov bx, [spr_col]
    test word [bp+4], 1
    jz ds_read
    mov bx, 15
    sub bx, [spr_col]

ds_read:
    mov dl, [si+bx]
    cmp dl, 0
    je ds_next_col

    mov bx, di
    add bx, ax
    mov [es:bx], dl

ds_next_col:
    inc word [spr_col]
    cmp word [spr_col], 16
    jl ds_col

ds_next_row:
    inc word [spr_row]
    mov ax, [spr_row]
    cmp ax, [spr_h]
    jl ds_row

ds_done:
    pop es
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    pop bp
    ret 8