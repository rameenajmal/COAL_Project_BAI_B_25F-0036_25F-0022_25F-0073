; ============================================================
; File    : input.asm
; Module  : 7 - Keyboard Interrupt Handler (INT 09h)
; Purpose : Replace the BIOS keyboard handler with our own so
;           several keys (Right + Shift + Space) can be held at
;           the same time. Keeps a 128-byte key-state table.
; ============================================================

; ---- Scan codes (Appendix A.3) ----
SC_ESC     EQU 01h
SC_P       EQU 19h
SC_ENTER   EQU 1Ch
SC_LSHIFT  EQU 2Ah
SC_SPACE   EQU 39h
SC_UP      EQU 48h
SC_LEFT    EQU 4Bh
SC_RIGHT   EQU 4Dh
SC_DOWN    EQU 50h

; ---- Keyboard data ----
key_state   times 128 db 0      ; one byte per key: 1 = held, 0 = released
old_kb_off  dw 0                ; saved offset  of the original INT 09h
old_kb_seg  dw 0                ; saved segment of the original INT 09h

; ------------------------------------------------------------
; InstallKeyboard
; Purpose : Save the old INT 09h vector, then install KeyboardISR.
; Inputs  : none
; Outputs : old vector stored in old_kb_off / old_kb_seg
; Changes : none (all registers preserved)
; ------------------------------------------------------------
InstallKeyboard:
    push ax
    push bx
    push dx
    push es

    mov  ax, 3509h              ; DOS: get vector of INT 09h
    int  21h                    ; returns old handler in ES:BX
    mov  [old_kb_off], bx       ; save offset
    mov  [old_kb_seg], es       ; save segment

    mov  dx, KeyboardISR        ; DS:DX = our handler (DS = CS in .COM)
    mov  ax, 2509h              ; DOS: set vector of INT 09h
    int  21h

    pop  es
    pop  dx
    pop  bx
    pop  ax
    ret

; ------------------------------------------------------------
; RestoreKeyboard
; Purpose : Put the original INT 09h handler back.
;           MUST run on every exit path, or DOS typing breaks.
; Inputs  : none (reads old_kb_off / old_kb_seg)
; Outputs : none
; Changes : none (all registers preserved)
; ------------------------------------------------------------
RestoreKeyboard:
    push ax
    push dx
    push ds

    mov  dx, [old_kb_off]       ; DX = old offset
    mov  ds, [old_kb_seg]       ; DS = old segment
    mov  ax, 2509h              ; DOS: set vector of INT 09h
    int  21h

    pop  ds
    pop  dx
    pop  ax
    ret

; ------------------------------------------------------------
; KeyboardISR   (hardware interrupt handler, ends with IRET)
; Purpose : Read the scan code from port 60h and update key_state.
;           Bit 7 set = key released. The 0E0h prefix is ignored.
; Inputs  : scan code from port 60h
; Outputs : key_state[scan code] = 1 (pressed) or 0 (released)
; Changes : none (all registers preserved)
; ------------------------------------------------------------
KeyboardISR:
    push ax
    push bx
    push ds

    push cs                     ; in a .COM file CS = data segment,
    pop  ds                     ; so set DS = CS

    in   al, 60h                ; read scan code from keyboard port
    cmp  al, 0E0h               ; extended-key prefix byte?
    je   .send_eoi              ; yes: ignore it, real code comes next

    mov  ah, al                 ; keep a copy to test bit 7 later
    and  al, 7Fh                ; clear bit 7 -> plain key number
    xor  bx, bx
    mov  bl, al                 ; BX = index into key_state

    test ah, 80h                ; bit 7 set means key released
    jnz  .key_released

    mov  byte [key_state + bx], 1   ; key pressed
    jmp  .send_eoi

.key_released:
    mov  byte [key_state + bx], 0   ; key released

.send_eoi:
    mov  al, 20h                ; End Of Interrupt command
    out  20h, al                ; tell the interrupt controller we are done

    pop  ds
    pop  bx
    pop  ax
    iret                        ; return from interrupt (restores flags)

; ------------------------------------------------------------
; IsKeyHeld(scancode)           parameter passed on the stack
; Purpose : Tell whether a key is currently held.
; Inputs  : [bp+4] = scan code (word)
; Outputs : AL = 1 if held, 0 if not
; Changes : AL only (RET 2 removes the parameter)
; ------------------------------------------------------------
IsKeyHeld:
    push bp
    mov  bp, sp
    push bx

    mov  bx, [bp + 4]           ; BX = scan code
    and  bx, 7Fh                ; keep index inside the 128-byte table
    mov  al, [key_state + bx]   ; AL = 1 or 0

    pop  bx
    pop  bp
    ret  2                      ; pop the 2-byte parameter