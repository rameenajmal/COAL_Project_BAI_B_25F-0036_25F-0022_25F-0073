; ============================================================
; File    : test_keyboard.asm
; Purpose : Test Module 7. Shows three digits: Right, Shift,
;           Space (1 = held). Press Esc to quit.
; ============================================================
ORG 100h

start:
    mov  ax, 0003h              ; clear screen (text mode)
    int  10h

    mov  ah, 09h                ; print the instruction text
    mov  dx, msg
    int  21h

    call InstallKeyboard        ; our keyboard handler is now active

    mov  ax, 0B800h             ; text-mode video memory
    mov  es, ax

main_loop:
    push word SC_RIGHT          ; Right arrow held?
    call IsKeyHeld
    add  al, '0'                ; 0/1 -> '0'/'1'
    mov  ah, 07h                ; grey on black
    mov  [es:800], ax

    push word SC_LSHIFT         ; Left Shift held?
    call IsKeyHeld
    add  al, '0'
    mov  ah, 07h
    mov  [es:806], ax

    push word SC_SPACE          ; Space held?
    call IsKeyHeld
    add  al, '0'
    mov  ah, 07h
    mov  [es:812], ax

    push word SC_ESC            ; Esc held? then leave
    call IsKeyHeld
    cmp  al, 1
    jne  main_loop

    call RestoreKeyboard        ; restore BEFORE returning to DOS
    mov  ax, 4C00h              ; exit to DOS
    int  21h

msg db 'Hold Right, Shift, Space. Digits below: 1 = held. Esc = quit.', 0Dh, 0Ah, '$'

%include "input.asm"