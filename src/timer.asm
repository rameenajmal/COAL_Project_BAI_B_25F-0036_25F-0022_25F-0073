; ============================================================
; File    : timer.asm
; Module  : 8 (Timer and Game Clock)
; Purpose : Hooks INT 1Ch to count timer ticks.
;           InstallTimer, RestoreTimer - set and restore the vector
;           TimerHandler - counts a tick, chains to the old handler
;           WaitTick - waits for the next tick
;           UpdateClock - counts down game_time once per second
; Author  : 25F-0036
; ============================================================

tick_count dw 0
last_tick  dw 0
sec_ticks  dw 0
game_time  dw 300
old_timer  dw 0, 0

; TimerHandler | counts one tick, then jumps to the old handler | in: none | out: tick_count | changes: none
TimerHandler:
    inc word [cs:tick_count]
    jmp far [cs:old_timer]

; InstallTimer | saves the old INT 1Ch vector and sets TimerHandler | in: none | out: old_timer | changes: none
InstallTimer:
    push ax
    push bx
    push dx
    push es
    mov ax, 351Ch
    int 21h
    mov [old_timer], bx
    mov [old_timer+2], es
    mov dx, TimerHandler
    mov ax, 251Ch
    int 21h
    pop es
    pop dx
    pop bx
    pop ax
    ret

; RestoreTimer | puts the old INT 1Ch vector back | in: old_timer | out: none | changes: none
RestoreTimer:
    push ax
    push dx
    push ds
    mov dx, [old_timer]
    mov ax, [old_timer+2]
    mov ds, ax
    mov ax, 251Ch
    int 21h
    pop ds
    pop dx
    pop ax
    ret

; WaitTick | waits until tick_count changes | in: tick_count | out: none | changes: none
WaitTick:
    push ax
    mov ax, [last_tick]
wt_loop:
    cmp ax, [tick_count]
    je wt_loop
    mov ax, [tick_count]
    mov [last_tick], ax
    pop ax
    ret

; UpdateClock | call once per frame, game_time goes down by 1 every 18 frames | in: none | out: game_time | changes: none
UpdateClock:
    inc word [sec_ticks]
    cmp word [sec_ticks], 18
    jl uc_exit
    mov word [sec_ticks], 0
    cmp word [game_time], 0
    je uc_exit
    dec word [game_time]
uc_exit:
    ret