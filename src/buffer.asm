; ============================================================
; File    : buffer.asm
; Module  : 5 (Frame Buffer and Block Operations)
; Purpose : Off-screen frame buffer in a second segment.
;           InitBuffer - sets buffer_seg, ClearBuffer - fills it black,
;           ShowBuffer - copies it to video memory.
; Author  : 25F-0036
; ============================================================
buffer_seg dw 0
; InitBuffer | sets buffer_seg to the free segment 1000h above CS 
;| in: none | out: buffer_seg | changes: none
InitBuffer:
    push ax
    mov ax, cs
    add ax, 1000h
    mov [buffer_seg], ax
    pop ax
    ret

; ClearBuffer | fills the whole buffer with colour 0 | in: buffer_seg 
;| out: none | changes: none
ClearBuffer:
    push ax
    push cx
    push di
    push es
    mov es, [buffer_seg]
    xor di, di
    xor ax, ax
    mov cx, 32000
    cld
    rep stosw
    pop es
    pop di
    pop cx
    pop ax
    ret

; ShowBuffer | copies the buffer to video memory at 0A000h | in: buffer_seg | out: none | changes: none
ShowBuffer:
    push ax
    push cx
    push si
    push di
    push ds
    push es
    mov ax, [buffer_seg]
    mov ds, ax
    mov ax, 0A000h
    mov es, ax
    xor si, si
    xor di, di
    mov cx, 32000
    cld
    rep movsw
    pop es
    pop ds
    pop di
    pop si
    pop cx
    pop ax
    ret