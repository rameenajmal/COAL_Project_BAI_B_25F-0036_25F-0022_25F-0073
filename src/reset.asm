; ============================================================
; File    : reset.asm
; Module  : 15 - Win, Lose, Restart and Clean Exit
; Author  : 25F-0073 (Abdul Rafay)
; Purpose : Re-initialise the game so it can be replayed without
;           leaving the program.
;           ResetLevel - after losing a life (Section 5.8):
;                        score, coins and lives are KEPT
;           NewGame    - start from scratch: score 0, coins 0,
;                        lives 3, then ResetLevel
; ============================================================

; ------------------------------------------------------------
; ResetLevel
; Purpose : Put the level back to its start:
;           * working map restored from the original (REP MOVSB)
;           * enemies / shells / mushrooms back to their start
;             records (REP MOVSB from entity_init)
;           * Mario: start position, Small, HP 1 (ResetHero)
;           * camera 0, clock 300, collision and flag flags cleared
; Inputs  : none
; Outputs : map, entity_table, hero variables, camera_x, game_time
; Changes : none
; ------------------------------------------------------------
ResetLevel:
    push cx
    push si
    push di
    push es

    call ResetMap                   ; level_original -> level_working

    push cs                         ; MOVSB copies DS:SI -> ES:DI
    pop  es
    cld
    mov  si, entity_init
    mov  di, entity_table
    mov  cx, ENT_SIZE * MAX_ENTITIES
    rep  movsb                      ; enemies back to their start

    call ResetHero                  ; Small Mario at the start
    call ClearCollisionFlags        ; head hit, pit, flag touched
    mov  word [flag_points], 0
    mov  byte [hero_dead], 0
    mov  word [camera_x], 0         ; camera back to the left
    mov  word [game_time], 300      ; clock 300
    mov  word [sec_ticks], 0

    pop  es
    pop  di
    pop  si
    pop  cx
    ret

; ------------------------------------------------------------
; NewGame
; Purpose : Score 0, coins 0, lives 3, then a fresh level.
; Inputs  : none
; Outputs : score, coins, lives and everything ResetLevel sets
; Changes : none
; ------------------------------------------------------------
NewGame:
    mov  word [score_lo], 0
    mov  word [score_hi], 0
    mov  word [coins], 0
    mov  word [lives], START_LIVES
    call ResetLevel
    ret