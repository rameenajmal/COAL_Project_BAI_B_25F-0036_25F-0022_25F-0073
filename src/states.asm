; ============================================================
; File    : states.asm
; Modules : 14 - Game States, Screens and Menus
;           15 - Win, Lose, Restart and Clean Exit (with reset.asm)
; Author  : 25F-0073 (Abdul Rafay)
; Purpose : The state machine (Section 5.12) driven by a state
;           variable and a jump table, the frame order of
;           Section 5.13, every screen (Title, Playing, Paused,
;           Dying, Life-lost, Level-complete, Game-over), the death
;           and win sequences and the clean exit to DOS.
; Notes   : GameMain is called once from mario.asm. Every state
;           handler runs ONCE per timer tick, draws its own picture
;           into the frame buffer and copies it to the screen.
; ============================================================

; ---- State numbers (index into state_table) ----
STATE_TITLE      EQU 0
STATE_PLAYING    EQU 1
STATE_PAUSED     EQU 2
STATE_DYING      EQU 3
STATE_LIFELOST   EQU 4
STATE_WIN        EQU 5          ; win sequence: slide, walk
STATE_LEVELDONE  EQU 6          ; Level Complete screen
STATE_GAMEOVER   EQU 7
STATE_EXIT       EQU 8          ; leave the game

; ---- Timing (frames at the 18 Hz timer) and sequence numbers ----
DYING_MIN_FRAMES EQU 18         ; death animation lasts at least 1 s
LIFELOST_FRAMES  EQU 36         ; Life-lost screen about 2 s
WIN_WALK_FRAMES  EQU 18         ; walk to the castle about 1 s
DEATH_HOP        EQU 0FA00h     ; -6.0 px/frame: hop up about 48 px
DEATH_GRAV       EQU 0060h      ; 0.375 px/frame^2 during the death fall
POLE_HERO_X      EQU 902        ; Mario's x while on the flag pole
GROUND_FEET_Y    EQU 160        ; y of the top of the ground (row 10)

; ---- Variables ----
game_state     db STATE_TITLE
menu_sel       db 0             ; 0 = START GAME, 1 = EXIT
death_cause    db 0             ; DEATH_ENEMY / DEATH_PIT / DEATH_TIME
win_phase      db 0             ; 0 = sliding down, 1 = walking
state_timer    dw 0             ; frames left in the current screen
win_score_lo   dw 0             ; score before the time bonus
win_score_hi   dw 0
win_time       dw 0             ; seconds left when the flag was touched
win_bonus      dw 0             ; win_time * 50

key_prev       times 128 db 0   ; key_state of the previous frame
key_edge       times 128 db 0   ; 1 = key was pressed THIS frame

; jump table: one handler per state, indexed by game_state
state_table    dw StateTitle, StatePlaying, StatePaused, StateDying
               dw StateLifeLost, StateWinSeq, StateLevelDone, StateGameOver

small_sprites  dw mario_stand, mario_run, mario_jump       ; by pose
super_sprites  dw super_stand, super_run, super_jump

; ---- Border macro: 2-pixel frame ----
%macro BORDER 5                 ; BORDER x, y, w, h, colour
    RECT %1, %2, %3, 2, %5
    RECT %1, (%2) + (%4) - 2, %3, 2, %5
    RECT %1, %2, 2, %4, %5
    RECT (%1) + (%3) - 2, %2, 2, %4, %5
%endmacro

; ============================================================
; Main loop and clean exit
; ============================================================

; ------------------------------------------------------------
; GameMain
; Purpose : Install the keyboard and timer handlers, run the state
;           machine until STATE_EXIT, then restore everything
;           (keyboard vector, timer vector, text mode) and return
;           to DOS. This is the ONLY exit path of the game.
; Inputs  : none      Outputs : never returns
; Changes : all
; ------------------------------------------------------------
GameMain:
    call InitBuffer                 ; frame buffer segment
    mov  ax, [buffer_seg]
    mov  [draw_seg], ax             ; all drawing goes to the buffer
    call InstallKeyboard
    call InstallTimer
    mov  byte [game_state], STATE_TITLE
    mov  byte [menu_sel], 0

.loop:
    call WaitTick                   ; frame step 1: wait for the timer
    call UpdateKeyEdges             ; which keys were just pressed
    xor  bx, bx
    mov  bl, [game_state]
    cmp  bl, STATE_EXIT
    je   .quit
    shl  bx, 1                      ; word table
    call word [state_table + bx]    ; indexed jump to the state handler
    jmp  .loop

.quit:
    call RestoreKeyboard            ; MUST be restored or DOS typing breaks
    call RestoreTimer
    mov  ax, 0003h                  ; back to text mode
    int  10h
    mov  ax, 4C00h                  ; exit to DOS
    int  21h

; ------------------------------------------------------------
; UpdateKeyEdges
; Purpose : Compare key_state with the previous frame. key_edge[k]
;           becomes 1 only in the frame in which key k went down
;           (menu keys, P and Esc must react once per press).
; Inputs  : key_state, key_prev      Outputs : key_edge, key_prev
; Changes : none
; ------------------------------------------------------------
UpdateKeyEdges:
    push ax
    push bx
    push cx

    xor  bx, bx
    mov  cx, 128
.next_key:
    mov  al, [key_state + bx]
    mov  ah, [key_prev + bx]
    mov  [key_prev + bx], al        ; remember for the next frame
    not  ah
    and  al, ah                     ; held now AND not held before
    mov  [key_edge + bx], al
    inc  bx
    loop .next_key

    pop  cx
    pop  bx
    pop  ax
    ret

; ============================================================
; TITLE
; ============================================================

; ------------------------------------------------------------
; StateTitle
; Purpose : Up / Down move the highlight, Enter on START begins a
;           new game, Enter on EXIT or Esc leaves the game.
; Inputs  : key_edge      Outputs : game_state, menu_sel
; Changes : AX
; ------------------------------------------------------------
StateTitle:
    cmp  byte [key_edge + SC_ESC], 1
    je   .exit
    cmp  byte [key_edge + SC_UP], 1
    jne  .not_up
    mov  byte [menu_sel], 0
.not_up:
    cmp  byte [key_edge + SC_DOWN], 1
    jne  .not_down
    mov  byte [menu_sel], 1
.not_down:
    cmp  byte [key_edge + SC_ENTER], 1
    jne  .draw
    cmp  byte [menu_sel], 0
    jne  .exit
    call NewGame                    ; score 0, lives 3, fresh level
    mov  byte [game_state], STATE_PLAYING
    ret
.exit:
    mov  byte [game_state], STATE_EXIT
    ret
.draw:
    call DrawTitleScreen
    call ShowBuffer
    ret

; ------------------------------------------------------------
; DrawTitleScreen
; Purpose : Title picture: brick frame, name, START / EXIT menu
;           with the highlighted entry, team names.
; Inputs  : menu_sel      Outputs : frame buffer      Changes : none
; ------------------------------------------------------------
DrawTitleScreen:
    push bx
    push dx
    push si

    call ClearBuffer
    RECT 0, 0, SCREEN_W, 192, COL_SKY
    RECT 0, 0, SCREEN_W, 8, COL_BRICK           ; brick frame
    RECT 0, 184, SCREEN_W, 8, COL_BRICK
    RECT 0, 0, 8, 192, COL_BRICK
    RECT 312, 0, 8, 192, COL_BRICK
    RECT 8, 152, 304, 4, COL_GREEN_TXT          ; grass and ground
    RECT 8, 156, 304, 28, COL_GROUND

    TEXT 31, 31, s_title_a, COL_HERO, 4         ; shadow
    TEXT 28, 28, s_title_a, COL_YELLOW, 4
    TEXT 94, 62, s_title_b, COL_WHITE, 2

    RECT 78, 82, 164, 56, COL_WHITE             ; menu box
    RECT 80, 84, 160, 52, COL_BLACK

    mov  bx, COL_WHITE                          ; colour of START
    mov  dx, COL_WHITE                          ; colour of EXIT
    mov  si, 94                                 ; y of the '>' marker
    cmp  byte [menu_sel], 0
    jne  .exit_selected
    mov  bx, COL_YELLOW
    jmp  .colours_ready
.exit_selected:
    mov  dx, COL_YELLOW
    mov  si, 116
.colours_ready:
    push word 112
    push word 94
    push word s_start
    push bx
    push word 2
    call DrawString
    push word 112
    push word 116
    push word s_exit
    push dx
    push word 2
    call DrawString
    push word 92                                ; highlight marker
    push si
    push word s_arrow
    push word COL_YELLOW
    push word 2
    call DrawString

    push word 24                                ; Mario and a Goomba
    push word 136
    push word mario_stand
    push word 0
    call DrawSprite
    push word 280
    push word 136
    push word goomba_walk
    push word 0
    call DrawSprite

    TEXT 79, 166, s_team, COL_WHITE, 1

    pop  si
    pop  dx
    pop  bx
    ret

; ============================================================
; PLAYING  (frame order of Section 5.13)
; ============================================================

; ------------------------------------------------------------
; StatePlaying
; Purpose : One game frame. Esc -> TITLE, P -> PAUSED.
;           3 Mario  4 enemies  5 contacts  6 clock  7 death / flag
;           8 camera  9 draw  10 show   (step 1 is WaitTick in
;           GameMain, step 2 is the key-state table).
; Inputs  : everything      Outputs : game state and all game data
; Changes : AX
; ------------------------------------------------------------
StatePlaying:
    cmp  byte [key_edge + SC_ESC], 1
    jne  .not_esc
    mov  byte [game_state], STATE_TITLE
    mov  byte [menu_sel], 0
    ret
.not_esc:
    cmp  byte [key_edge + SC_P], 1
    jne  .play
    mov  byte [game_state], STATE_PAUSED
    ret

.play:
    call SaveHeroPrevFeet           ; (for the stomp test)
    call UpdateHorizontal           ; 3: speed from the keys
    call UpdateVertical             ;    jump and gravity
    call MoveHeroWithCollision      ;    move X then Y with tile collision
    call HandleHeadHit              ;    bricks and "?" blocks
    call CollectCoinTiles           ;    coins lying on the map
    call UpdateEntities             ; 4: enemies, shells, mushrooms
    call ResolveHeroEntities        ; 5: stomp, damage, kick, collect

    call UpdateClock                ; 6: one second every 18 frames
    cmp  word [invuln_timer], 0
    je   .no_invuln
    dec  word [invuln_timer]        ;    blink time
.no_invuln:

    cmp  byte [hero_dead], 1        ; 7: death by enemy?
    jne  .check_pit
    mov  al, DEATH_ENEMY
    jmp  .die
.check_pit:
    cmp  byte [pit_fall], 1         ;    death by pit?
    jne  .check_time
    mov  al, DEATH_PIT
    jmp  .die
.check_time:
    cmp  word [game_time], 0        ;    clock at 0?
    jne  .check_flag
    mov  al, DEATH_TIME
.die:
    call StartDying
    ret

.check_flag:
    call CheckFlagPole              ;    flag pole touched?
    cmp  byte [flag_touched], 1
    jne  .camera
    call StartWin
    ret

.camera:
    call SetHeroPose
    push word [hero_x]              ; 8: camera follows Mario
    call UpdateCamera               ;    AX = hero_x after the left wall
    cmp  ax, [hero_x]
    je   .draw
    mov  [hero_x], ax               ;    pushed back by the left wall
    mov  byte [hero_x_frac], 0
    mov  word [hero_vx], 0
.draw:
    call DrawScene                  ; 9: draw into the frame buffer
    call ShowBuffer                 ; 10: copy to the screen
    ret

; ------------------------------------------------------------
; DrawScene
; Purpose : Clear the frame buffer, draw map, entities, Mario and
;           the HUD (step 9 of the frame order).
; Inputs  : game data      Outputs : frame buffer      Changes : none
; ------------------------------------------------------------
DrawScene:
    call ClearBuffer
    call DrawMap
    call DrawEntities
    call DrawHero
    call DrawHUD
    ret

; ------------------------------------------------------------
; DrawHero
; Purpose : Draw Mario at screen_x = hero_x - camera_x. Sprite by
;           form and pose, mirrored when he faces left, drawn only
;           on every second frame while invulnerable (blinking).
; Inputs  : hero_*, form, camera_x, invuln_timer
; Outputs : frame buffer      Changes : none
; ------------------------------------------------------------
DrawHero:
    push ax
    push bx
    push dx
    push si

    mov  ax, [hero_x]
    sub  ax, [camera_x]             ; screen x
    xor  dx, dx                     ; DX = flags for DrawSprite
    cmp  byte [hero_facing], 0
    jne  .no_mirror
    or   dx, 1                      ; bit 0: mirror (facing left)
.no_mirror:
    cmp  word [invuln_timer], 0
    je   .visible
    test word [invuln_timer], 1
    jz   .visible
    or   dx, 2                      ; bit 1: skip this frame (blink)
.visible:
    xor  bx, bx
    mov  bl, [hero_pose]
    shl  bx, 1
    cmp  byte [form], FORM_SUPER
    je   .super
    mov  si, [small_sprites + bx]
    jmp  .draw
.super:
    mov  si, [super_sprites + bx]
    or   dx, 4                      ; bit 2: 16 x 32 sprite
.draw:
    push ax
    push word [hero_y]
    push si
    push dx
    call DrawSprite

    pop  si
    pop  dx
    pop  bx
    pop  ax
    ret

; ============================================================
; PAUSED
; ============================================================

; ------------------------------------------------------------
; StatePaused
; Purpose : Frozen picture with a PAUSED box. Nothing is updated,
;           so the clock and the camera stay frozen. P resumes,
;           Esc returns to the title.
; Inputs  : key_edge      Outputs : game_state     Changes : none
; ------------------------------------------------------------
StatePaused:
    cmp  byte [key_edge + SC_ESC], 1
    jne  .not_esc
    mov  byte [game_state], STATE_TITLE
    mov  byte [menu_sel], 0
    ret
.not_esc:
    cmp  byte [key_edge + SC_P], 1
    jne  .draw
    mov  byte [game_state], STATE_PLAYING
    ret
.draw:
    call DrawScene
    RECT 78, 66, 164, 60, COL_WHITE
    RECT 80, 68, 160, 56, COL_BLACK
    TEXT 106, 78, s_paused, COL_YELLOW, 3
    TEXT 109, 108, s_press_p, COL_WHITE, 1
    call ShowBuffer
    ret

; ============================================================
; DYING and LIFE LOST  (Section 5.8)
; ============================================================

; ------------------------------------------------------------
; StartDying
; Purpose : Switch to the DYING state. Enemies, clock and keys are
;           frozen (their code is not called). An enemy or clock
;           death starts with a hop of about 48 px; a pit death
;           just keeps falling.
; Inputs  : AL = DEATH_xxx
; Outputs : game_state, hero_vy, state_timer
; Changes : none
; ------------------------------------------------------------
StartDying:
    mov  [death_cause], al
    mov  byte [hero_dead], 0
    mov  byte [game_state], STATE_DYING
    mov  word [state_timer], DYING_MIN_FRAMES
    mov  word [hero_vx], 0
    mov  word [hero_vy], 0
    mov  byte [hero_pose], POSE_JUMP
    mov  byte [on_ground], 0
    mov  word [invuln_timer], 0
    cmp  al, DEATH_PIT
    je   .done
    mov  word [hero_vy], DEATH_HOP  ; hop up first
.done:
    ret

; ------------------------------------------------------------
; StateDying
; Purpose : Death animation: gravity, no collisions. When the
;           minimum time has passed and Mario has fallen off the
;           bottom of the screen, FinishDeath is called.
; Inputs  : hero_*      Outputs : hero_y, hero_vy, game_state
; Changes : none
; ------------------------------------------------------------
StateDying:
    add  word [hero_vy], DEATH_GRAV
    cmp  word [hero_vy], MAX_FALL
    jle  .speed_ok
    mov  word [hero_vy], MAX_FALL
.speed_ok:
    call MoveHeroY                  ; falls through everything
    call DrawScene
    call ShowBuffer

    cmp  word [state_timer], 0
    je   .timer_done
    dec  word [state_timer]
.timer_done:
    cmp  word [state_timer], 0
    jne  .done
    cmp  word [hero_y], 200
    jl   .done                      ; still visible
    call FinishDeath
.done:
    ret

; ------------------------------------------------------------
; FinishDeath
; Purpose : Lives - 1. Lives left -> LIFE LOST screen, otherwise
;           GAME OVER.
; Inputs  : lives      Outputs : lives, game_state, state_timer
; Changes : none
; ------------------------------------------------------------
FinishDeath:
    dec  word [lives]
    jz   .game_over
    mov  byte [game_state], STATE_LIFELOST
    mov  word [state_timer], LIFELOST_FRAMES
    ret
.game_over:
    mov  byte [game_state], STATE_GAMEOVER
    ret

; ------------------------------------------------------------
; StateLifeLost
; Purpose : "WORLD 1-1, Mario x lives" for about 2 s, then the
;           level is reset (score and coins are kept).
; Inputs  : state_timer      Outputs : game_state, level data
; Changes : AX, BX
; ------------------------------------------------------------
StateLifeLost:
    call ClearBuffer
    TEXT 79, 36, s_world_full, COL_WHITE, 3
    push word 120                   ; Mario icon
    push word 92
    push word mario_stand
    push word 0
    call DrawSprite
    TEXT 150, 94, s_x, COL_WHITE, 3
    mov  bx, 1                      ; one digit below 10 lives
    cmp  word [lives], 10
    jb   .one_digit
    mov  bx, 2
.one_digit:
    NUM 186, 94, [lives], 0, bx, COL_WHITE, 3
    TEXT 100, 140, s_lives_left, COL_YELLOW, 2
    call ShowBuffer

    dec  word [state_timer]
    jnz  .done
    call ResetLevel                 ; map, enemies, Mario, camera, clock
    mov  byte [game_state], STATE_PLAYING
.done:
    ret

; ============================================================
; WIN  (Section 5.11)
; ============================================================

; ------------------------------------------------------------
; StartWin
; Purpose : Flag touched. Add the flag points, freeze clock and
;           keys (their code is no longer called) and start the
;           win sequence on the pole.
; Inputs  : flag_points      Outputs : score, game_state, hero_*
; Changes : none
; ------------------------------------------------------------
StartWin:
    push word [flag_points]
    call AddScore                   ; 100 .. 5000 by the height
    mov  byte [game_state], STATE_WIN
    mov  byte [win_phase], 0
    mov  word [hero_x], POLE_HERO_X ; snap to the pole
    mov  byte [hero_x_frac], 0
    mov  word [hero_vx], 0
    mov  word [hero_vy], 0
    mov  byte [hero_facing], 1
    mov  byte [hero_pose], POSE_JUMP
    ret

; ------------------------------------------------------------
; StateWinSeq
; Purpose : Phase 0: Mario slides down the pole (2 px per frame)
;           until his feet reach the ground. Phase 1: he walks to
;           the right for about 1 s. Then the Level Complete
;           screen starts.
; Inputs  : win_phase      Outputs : hero_x, hero_y, game_state
; Changes : AX, BX
; ------------------------------------------------------------
StateWinSeq:
    cmp  byte [win_phase], 0
    jne  .walk

    add  word [hero_y], 2           ; slide down
    call GetHeroHeight
    mov  bx, ax                     ; BX = height
    add  ax, [hero_y]               ; AX = feet y
    cmp  ax, GROUND_FEET_Y
    jl   .draw
    mov  ax, GROUND_FEET_Y          ; feet exactly on the ground
    sub  ax, bx
    mov  [hero_y], ax
    mov  byte [win_phase], 1
    mov  word [state_timer], WIN_WALK_FRAMES
    mov  byte [hero_pose], POSE_RUN
    jmp  .draw

.walk:
    add  word [hero_x], 2           ; walk towards the castle
    dec  word [state_timer]
    jnz  .draw
    call EnterLevelDone
    ret
.draw:
    call DrawScene
    call ShowBuffer
    ret

; ------------------------------------------------------------
; EnterLevelDone
; Purpose : Time left x 50 becomes bonus points (added once, here).
;           The score before the bonus is kept for the screen.
; Inputs  : game_time, score      Outputs : win_*, score, game_state
; Changes : none
; ------------------------------------------------------------
EnterLevelDone:
    push ax
    push bx
    push dx

    mov  ax, [score_lo]
    mov  [win_score_lo], ax
    mov  ax, [score_hi]
    mov  [win_score_hi], ax
    mov  ax, [game_time]
    mov  [win_time], ax
    mov  bx, 50
    mul  bx                         ; AX = seconds * 50 (at most 15000)
    mov  [win_bonus], ax
    push ax
    call AddScore
    mov  byte [game_state], STATE_LEVELDONE

    pop  dx
    pop  bx
    pop  ax
    ret

; ------------------------------------------------------------
; StateLevelDone
; Purpose : Level Complete screen. Enter returns to the title
;           (a new game then starts from scratch).
; Inputs  : win_*, score      Outputs : game_state
; Changes : none
; ------------------------------------------------------------
StateLevelDone:
    cmp  byte [key_edge + SC_ENTER], 1
    jne  .draw
    mov  byte [game_state], STATE_TITLE
    mov  byte [menu_sel], 0
    ret
.draw:
    call ClearBuffer
    RECT 24, 16, 272, 160, COL_YELLOW
    RECT 28, 20, 264, 152, COL_BLACK
    TEXT 70, 30, s_level_complete, COL_YELLOW, 2

    TEXT  56, 64, s_score, COL_WHITE, 1
    NUM  160, 64, [win_score_lo], [win_score_hi], 6, COL_WHITE, 1
    TEXT  56, 80, s_coins, COL_WHITE, 1
    TEXT 160, 80, s_x, COL_WHITE, 1
    NUM  170, 80, [coins], 0, 2, COL_WHITE, 1
    TEXT  56, 96, s_time_left, COL_WHITE, 1
    NUM  160, 96, [win_time], 0, 3, COL_WHITE, 1
    TEXT 190, 96, s_x50, COL_WHITE, 1
    NUM  232, 96, [win_bonus], 0, 5, COL_WHITE, 1
    TEXT  56, 112, s_time_bonus, COL_WHITE, 1
    TEXT 160, 112, s_plus, COL_WHITE, 1
    NUM  172, 112, [win_bonus], 0, 5, COL_WHITE, 1
    TEXT  56, 132, s_final, COL_WHITE, 1
    NUM  160, 132, [score_lo], [score_hi], 6, COL_YELLOW, 1
    TEXT  91, 154, s_press_cont, COL_GREEN_TXT, 1
    call ShowBuffer
    ret

; ============================================================
; GAME OVER
; ============================================================

; ------------------------------------------------------------
; StateGameOver
; Purpose : Game Over screen with the final score. Enter returns
;           to the title.
; Inputs  : score, coins      Outputs : game_state     Changes : none
; ------------------------------------------------------------
StateGameOver:
    cmp  byte [key_edge + SC_ENTER], 1
    jne  .draw
    mov  byte [game_state], STATE_TITLE
    mov  byte [menu_sel], 0
    ret
.draw:
    call ClearBuffer
    BORDER 24, 16, 272, 160, COL_RED_TXT
    BORDER 28, 20, 264, 152, COL_RED_TXT
    TEXT  52, 44, s_game_over, COL_RED_TXT, 4
    TEXT  50, 96, s_final_colon, COL_WHITE, 2
    NUM  206, 96, [score_lo], [score_hi], 6, COL_WHITE, 2
    TEXT 100, 124, s_coins, COL_YELLOW, 1
    NUM  136, 124, [coins], 0, 2, COL_YELLOW, 1
    TEXT 184, 124, s_time, COL_YELLOW, 1
    NUM  214, 124, [game_time], 0, 3, COL_YELLOW, 1
    TEXT  85, 150, s_press_title, COL_GREEN_TXT, 1
    call ShowBuffer
    ret

; ============================================================
; Screen texts
; ============================================================
s_title_a       db "SUPER MARIO", 0
s_title_b       db "E N G I N E", 0
s_start         db "START GAME", 0
s_exit          db "EXIT", 0
s_arrow         db ">", 0
s_team          db "RAMEEN  FARYAL  ABDUL RAFAY", 0
s_paused        db "PAUSED", 0
s_press_p       db "PRESS P TO RESUME", 0
s_world_full    db "WORLD 1-1", 0
s_lives_left    db "LIVES LEFT", 0
s_level_complete db "LEVEL COMPLETE!", 0
s_time_left     db "TIME LEFT", 0
s_x50           db "X 50 =", 0
s_time_bonus    db "TIME BONUS", 0
s_plus          db "+", 0
s_final         db "FINAL SCORE", 0
s_press_cont    db "PRESS ENTER TO CONTINUE", 0
s_game_over     db "GAME OVER", 0
s_final_colon   db "FINAL SCORE:", 0
s_press_title   db "PRESS ENTER FOR THE TITLE", 0