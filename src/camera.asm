; ============================================================
; File    : camera.asm
; Module  : 6 (Camera and Scrolling)
; Purpose : Holds camera_x, the world x position of the left
;           edge of the screen. Camera update and scrolling
;           logic will be added in Module 6.
; Author  : 25F-0036
; ============================================================
camera_x dw 0
; UpdateCamera | follows Mario past screen x 160, never goes left, stops at 640, keeps Mario inside left edge | in: mario_x (stack) | out: AX = mario_x after left wall fix | changes: AX
UpdateCamera:
    push bp
    mov bp, sp
    push bx

    mov ax, [bp+4]
    mov bx, ax
    sub bx, 160
    cmp bx, [camera_x]
    jle uc_wall
    cmp bx, 640
    jle uc_set
    mov bx, 640
uc_set:
    mov [camera_x], bx

; left wall: Mario cannot go left of camera_x
uc_wall:
    cmp ax, [camera_x]
    jge uc_done
    mov ax, [camera_x]

uc_done:
    pop bx
    pop bp
    ret 2