; ============================================================
; File    : hud.asm
; Module  : 13 - Score, Health, Lives and HUD
; Author  : 25F-0073 (Abdul Rafay)
; Purpose : * Own 5x7 bitmap font and text drawing
;             (DrawBits, DrawChar, DrawString, DrawNumber)
;           * Score / coins / lives variables and the scoring
;             procedures (AddScore, AddCoin, AddLife)
;           * The HUD strip at the top of the screen (DrawHUD)
; Notes   : All procedures take their inputs on the stack
;           (first push = first parameter) and remove them with
;           RET n. Every procedure preserves all registers.
;           All drawing goes to the segment in draw_seg
;           (the off-screen frame buffer).
; ============================================================

; ---- Text colours (default VGA palette) ----
COL_WHITE      EQU 15
COL_YELLOW     EQU 14
COL_RED_TXT    EQU 12
COL_GREEN_TXT  EQU 10
COL_GRAY       EQU 8

; ---- Limits (Appendix A.4) ----
MAX_LIVES      EQU 99
START_LIVES    EQU 3
COINS_FOR_LIFE EQU 100
SCORE_MAX_HI   EQU 000Fh        ; 999999 = 000F423Fh
SCORE_MAX_LO   EQU 423Fh

; ---- Game counters (score is 32 bit: two words) ----
score_lo       dw 0             ; low  word of the score
score_hi       dw 0             ; high word of the score
coins          dw 0             ; coins collected (0..99)
lives          dw START_LIVES   ; lives left (0..99)

; ---- Scratch variables used by the text routines ----
bits_rows      dw 0             ; rows left in DrawBits
num_lo         dw 0             ; working copy of the number (low)
num_hi         dw 0             ; working copy of the number (high)

; ---- Macros to keep the drawing code short ----
%macro TEXT 5                   ; TEXT x, y, string, colour, scale
    push word %1
    push word %2
    push word %3
    push word %4
    push word %5
    call DrawString
%endmacro

%macro NUM 7                    ; NUM x, y, low, high, digits, colour, scale
    push word %1
    push word %2
    push word %3
    push word %4
    push word %5
    push word %6
    push word %7
    call DrawNumber
%endmacro

%macro RECT 5                   ; RECT x, y, w, h, colour (FillRect)
    push word %1
    push word %2
    push word %3
    push word %4
    push word %5
    call FillRect
%endmacro

; ============================================================
; Scoring procedures
; ============================================================

; ------------------------------------------------------------
; AddScore(points)                    ret 2
; Purpose : The ONE place where points are added (Section 5.4).
;           32-bit add with ADD / ADC, then clamp to 999,999.
; Inputs  : [bp+4] = points (word, 0..65535)
; Outputs : score_lo / score_hi updated
; Changes : none
; ------------------------------------------------------------
AddScore:
    push bp
    mov  bp, sp
    push ax

    mov  ax, [bp + 4]
    add  [score_lo], ax             ; low word, carry goes to CF
    adc  word [score_hi], 0         ; high word + carry

    cmp  word [score_hi], SCORE_MAX_HI
    jb   .ok                        ; clearly below the limit
    ja   .clamp                     ; clearly above the limit
    cmp  word [score_lo], SCORE_MAX_LO
    jbe  .ok                        ; same high word, low word fits
.clamp:
    mov  word [score_hi], SCORE_MAX_HI
    mov  word [score_lo], SCORE_MAX_LO
.ok:
    pop  ax
    pop  bp
    ret  2

; ------------------------------------------------------------
; AddLife
; Purpose : Lives + 1, never above 99.
; Inputs  : none      Outputs : lives      Changes : none
; ------------------------------------------------------------
AddLife:
    cmp  word [lives], MAX_LIVES
    jae  .done
    inc  word [lives]
.done:
    ret

; ------------------------------------------------------------
; AddCoin
; Purpose : Coins + 1. Reaching 100 coins gives +1 life and
;           the counter returns to 0 (no points, Section 5.4).
; Inputs  : none      Outputs : coins, lives      Changes : none
; ------------------------------------------------------------
AddCoin:
    inc  word [coins]
    cmp  word [coins], COINS_FOR_LIFE
    jb   .done
    mov  word [coins], 0
    call AddLife
.done:
    ret

; ============================================================
; Text engine (own bitmap font)
; ============================================================

; ------------------------------------------------------------
; DrawBits(x, y, address, rows, colour, scale)       ret 12
; Purpose : Draw a 1-bit-per-pixel bitmap. Every row is one byte,
;           bit 7 is the left-most pixel. Each set bit becomes a
;           scale x scale block of the given colour. Clear bits
;           are transparent. Writes straight to draw_seg.
; Inputs  : [bp+14]=x [bp+12]=y [bp+10]=address [bp+8]=rows
;           [bp+6]=colour [bp+4]=scale
; Outputs : pixels in the frame buffer
; Changes : none
; Notes   : the caller keeps the bitmap inside the screen.
; ------------------------------------------------------------
DrawBits:
    push bp
    mov  bp, sp
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push es

    cld
    mov  es, [draw_seg]
    mov  si, [bp + 10]              ; SI -> bitmap rows
    mov  ax, [bp + 12]              ; DI = y * 320 + x  (y*256 + y*64)
    mov  bx, ax
    shl  ax, 8
    shl  bx, 6
    add  ax, bx
    add  ax, [bp + 14]
    mov  di, ax
    mov  ax, [bp + 8]
    mov  [bits_rows], ax

.row:
    lodsb                           ; AL = bits of this row
    mov  bh, al
    mov  dl, [bp + 4]               ; repeat the row 'scale' times
.repeat:
    push di                         ; remember the start of the row
    mov  bl, bh                     ; BL = bits still to draw
    mov  dh, 8                      ; 8 pixels per row
.pixel:
    mov  cx, [bp + 4]               ; CX = scale (pixels per bit)
    shl  bl, 1                      ; next bit -> carry flag
    jnc  .gap
    mov  al, [bp + 6]               ; colour
    rep  stosb                      ; 'scale' pixels
    jmp  .next_pixel
.gap:
    add  di, cx                     ; transparent: skip 'scale' pixels
.next_pixel:
    dec  dh
    jnz  .pixel
    pop  di
    add  di, SCREEN_W               ; next screen line
    dec  dl
    jnz  .repeat
    dec  word [bits_rows]
    jnz  .row

    pop  es
    pop  di
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    pop  bp
    ret  12

; ------------------------------------------------------------
; DrawChar(x, y, char, colour, scale)                ret 10
; Purpose : Draw one character. The glyph is found with
;           REPNE SCASB in font_chars; unknown characters are
;           drawn as a space. Glyph size is 5x7, advance 6*scale.
; Inputs  : [bp+12]=x [bp+10]=y [bp+8]=char (ASCII, upper case)
;           [bp+6]=colour [bp+4]=scale
; Outputs : pixels in the frame buffer
; Changes : none
; ------------------------------------------------------------
DrawChar:
    push bp
    mov  bp, sp
    push ax
    push bx
    push cx
    push di
    push es

    push cs                         ; SCASB works on ES:DI,
    pop  es                         ; the font table is in our segment
    cld
    mov  al, [bp + 8]               ; character to find
    mov  di, font_chars
    mov  cx, FONT_COUNT
    repne scasb
    jne  .unknown
    mov  bx, di                     ; DI is one past the match
    sub  bx, font_chars
    dec  bx                         ; BX = glyph index
    jmp  .have_index
.unknown:
    xor  bx, bx                     ; index 0 = space
.have_index:
    mov  ax, bx                     ; address = font_data + index * 7
    shl  ax, 3
    sub  ax, bx
    add  ax, font_data

    push word [bp + 12]             ; x
    push word [bp + 10]             ; y
    push ax                         ; glyph address
    push word 7                     ; 7 rows
    push word [bp + 6]              ; colour
    push word [bp + 4]              ; scale
    call DrawBits

    pop  es
    pop  di
    pop  cx
    pop  bx
    pop  ax
    pop  bp
    ret  10

; ------------------------------------------------------------
; DrawString(x, y, address, colour, scale)           ret 10
; Purpose : Draw a zero-terminated string, left to right.
; Inputs  : [bp+12]=x [bp+10]=y [bp+8]=address of the string
;           [bp+6]=colour [bp+4]=scale
; Outputs : pixels in the frame buffer
; Changes : none
; ------------------------------------------------------------
DrawString:
    push bp
    mov  bp, sp
    push ax
    push bx
    push cx
    push dx
    push si

    mov  si, [bp + 8]               ; SI -> string
    mov  ax, [bp + 4]
    mov  bx, 6
    mul  bx                         ; AX = advance = 6 * scale
    mov  cx, ax                     ; CX = advance
    mov  bx, [bp + 12]              ; BX = current x
.next_char:
    lodsb
    or   al, al
    jz   .done                      ; zero byte ends the string
    xor  ah, ah
    push bx
    push word [bp + 10]
    push ax
    push word [bp + 6]
    push word [bp + 4]
    call DrawChar
    add  bx, cx
    jmp  .next_char
.done:
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    pop  bp
    ret  10

; ------------------------------------------------------------
; DrawNumber(x, y, low, high, digits, colour, scale)   ret 14
; Purpose : Draw an unsigned 32-bit number as 'digits' decimal
;           digits (zero padded). Decimal conversion: divide by 10
;           again and again, PUSH each remainder, then POP them
;           in reverse order (most significant digit first).
;           A 16-bit value is passed with high = 0.
; Inputs  : [bp+16]=x [bp+14]=y [bp+12]=low word [bp+10]=high word
;           [bp+8]=digits (1..10) [bp+6]=colour [bp+4]=scale
; Outputs : pixels in the frame buffer
; Changes : none
; ------------------------------------------------------------
DrawNumber:
    push bp
    mov  bp, sp
    push ax
    push bx
    push cx
    push dx

    mov  ax, [bp + 12]
    mov  [num_lo], ax
    mov  ax, [bp + 10]
    mov  [num_hi], ax
    mov  cx, [bp + 8]               ; one remainder per digit
    mov  bx, 10
.divide:
    mov  ax, [num_hi]               ; high word / 10
    xor  dx, dx
    div  bx
    mov  [num_hi], ax
    mov  ax, [num_lo]               ; (remainder:low word) / 10
    div  bx
    mov  [num_lo], ax
    push dx                         ; DX = remainder = next digit
    loop .divide

    mov  ax, [bp + 4]               ; BX = advance = 6 * scale
    mov  bx, 6
    mul  bx
    mov  bx, ax
    mov  cx, [bp + 8]
.draw:
    pop  dx                         ; most significant digit first
    add  dl, '0'
    xor  dh, dh
    push word [bp + 16]
    push word [bp + 14]
    push dx
    push word [bp + 6]
    push word [bp + 4]
    call DrawChar
    add  [bp + 16], bx              ; move x to the next digit
    loop .draw

    pop  dx
    pop  cx
    pop  bx
    pop  ax
    pop  bp
    ret  14

; ============================================================
; HUD (Section 5.14)
; ============================================================

; ------------------------------------------------------------
; DrawHUD
; Purpose : Draw the top 16-pixel strip: SCORE (6 digits),
;           COINS, WORLD, TIME (3 digits), LIVES and two hearts
;           (HP 1 = one filled heart, HP 2 = two filled hearts).
; Inputs  : score, coins, game_time, lives, hp
; Outputs : pixels in the frame buffer
; Changes : none
; ------------------------------------------------------------
DrawHUD:
    push ax

    RECT 0, 0, SCREEN_W, 16, COL_BLACK

    TEXT   8, 1, s_score,  COL_YELLOW, 1
    TEXT  72, 1, s_coins,  COL_YELLOW, 1
    TEXT 128, 1, s_world,  COL_YELLOW, 1
    TEXT 184, 1, s_time,   COL_YELLOW, 1
    TEXT 232, 1, s_lives,  COL_YELLOW, 1
    TEXT 272, 1, s_health, COL_YELLOW, 1

    NUM    8, 9, [score_lo], [score_hi], 6, COL_WHITE, 1
    TEXT  72, 9, s_x,      COL_WHITE, 1
    NUM   78, 9, [coins], 0, 2, COL_WHITE, 1
    TEXT 128, 9, s_world11, COL_WHITE, 1
    NUM  184, 9, [game_time], 0, 3, COL_WHITE, 1
    TEXT 232, 9, s_x,      COL_WHITE, 1
    NUM  238, 9, [lives], 0, 2, COL_WHITE, 1

    ; heart 1 is always filled (HP is at least 1)
    push word 272
    push word 8
    push word heart_bits
    push word 7
    push word COL_RED_TXT
    push word 1
    call DrawBits

    ; heart 2 is filled only for Super Mario (HP 2)
    mov  ax, COL_GRAY
    cmp  byte [hp], 2
    jb   .second_heart
    mov  ax, COL_RED_TXT
.second_heart:
    push word 284
    push word 8
    push word heart_bits
    push word 7
    push ax
    push word 1
    call DrawBits

    pop  ax
    ret

; ============================================================
; Data: HUD strings, heart bitmap and the font
; ============================================================
s_score    db "SCORE", 0
s_coins    db "COINS", 0
s_world    db "WORLD", 0
s_world11  db "1-1", 0
s_time     db "TIME", 0
s_lives    db "LIVES", 0
s_health   db "HEALTH", 0
s_x        db "X", 0

heart_bits db 01100110b, 11111111b, 11111111b, 11111111b
           db 01111110b, 00111100b, 00011000b

; Font: 5x7 glyphs, 7 bytes each, left aligned (bit 7 = left pixel).
; G writes one glyph from seven 5-bit row values.
%macro G 7
    db (%1 << 3), (%2 << 3), (%3 << 3), (%4 << 3), (%5 << 3), (%6 << 3), (%7 << 3)
%endmacro

font_chars db " 0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ:-!>.=+"
FONT_COUNT EQU $ - font_chars

font_data:
    G 00h,00h,00h,00h,00h,00h,00h       ; space
    G 0Eh,11h,13h,15h,19h,11h,0Eh       ; 0
    G 04h,0Ch,04h,04h,04h,04h,0Eh       ; 1
    G 0Eh,11h,01h,02h,04h,08h,1Fh       ; 2
    G 1Fh,02h,04h,02h,01h,11h,0Eh       ; 3
    G 02h,06h,0Ah,12h,1Fh,02h,02h       ; 4
    G 1Fh,10h,1Eh,01h,01h,11h,0Eh       ; 5
    G 06h,08h,10h,1Eh,11h,11h,0Eh       ; 6
    G 1Fh,01h,02h,04h,08h,08h,08h       ; 7
    G 0Eh,11h,11h,0Eh,11h,11h,0Eh       ; 8
    G 0Eh,11h,11h,0Fh,01h,02h,0Ch       ; 9
    G 0Eh,11h,11h,1Fh,11h,11h,11h       ; A
    G 1Eh,11h,11h,1Eh,11h,11h,1Eh       ; B
    G 0Eh,11h,10h,10h,10h,11h,0Eh       ; C
    G 1Eh,11h,11h,11h,11h,11h,1Eh       ; D
    G 1Fh,10h,10h,1Eh,10h,10h,1Fh       ; E
    G 1Fh,10h,10h,1Eh,10h,10h,10h       ; F
    G 0Eh,11h,10h,17h,11h,11h,0Fh       ; G
    G 11h,11h,11h,1Fh,11h,11h,11h       ; H
    G 0Eh,04h,04h,04h,04h,04h,0Eh       ; I
    G 07h,02h,02h,02h,02h,12h,0Ch       ; J
    G 11h,12h,14h,18h,14h,12h,11h       ; K
    G 10h,10h,10h,10h,10h,10h,1Fh       ; L
    G 11h,1Bh,15h,15h,11h,11h,11h       ; M
    G 11h,11h,19h,15h,13h,11h,11h       ; N
    G 0Eh,11h,11h,11h,11h,11h,0Eh       ; O
    G 1Eh,11h,11h,1Eh,10h,10h,10h       ; P
    G 0Eh,11h,11h,11h,15h,12h,0Dh       ; Q
    G 1Eh,11h,11h,1Eh,14h,12h,11h       ; R
    G 0Fh,10h,10h,0Eh,01h,01h,1Eh       ; S
    G 1Fh,04h,04h,04h,04h,04h,04h       ; T
    G 11h,11h,11h,11h,11h,11h,0Eh       ; U
    G 11h,11h,11h,11h,11h,0Ah,04h       ; V
    G 11h,11h,11h,15h,15h,15h,0Ah       ; W
    G 11h,11h,0Ah,04h,0Ah,11h,11h       ; X
    G 11h,11h,0Ah,04h,04h,04h,04h       ; Y
    G 1Fh,01h,02h,04h,08h,10h,1Fh       ; Z
    G 00h,04h,04h,00h,04h,04h,00h       ; :
    G 00h,00h,00h,1Fh,00h,00h,00h       ; -
    G 04h,04h,04h,04h,04h,00h,04h       ; !
    G 08h,04h,02h,01h,02h,04h,08h       ; >
    G 00h,00h,00h,00h,00h,0Ch,0Ch       ; .
    G 00h,00h,1Fh,00h,1Fh,00h,00h       ; =
    G 00h,04h,04h,1Fh,04h,04h,00h       ; +