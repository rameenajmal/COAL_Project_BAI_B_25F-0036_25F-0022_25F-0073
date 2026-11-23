; File    : enemies.asm
; Module  : 11 - Enemies and Shells
; Author  : 25F-0073 (Abdul Rafay)
; Purpose : Entity table (Goomba, Koopa Troopa, Koopa shell and the
;           mushroom power-up), their movement, the stomp / kick /
;           hurt rules of Sections 5.4 - 5.7 and drawing.
; Notes   : * Entities are fixed-size records (ENT_SIZE bytes) in
;             entity_table, walked with indexed addressing.
;           * Positions are world pixels with a fraction byte;
;             speeds are 8.8 fixed point (Appendix A.5).
;           * Procedures take their inputs on the stack (RET n) and
;             preserve every register they do not return.
;           * Collision with tiles uses IsSolidAt (collision.asm).

; ---- Entity types ----
ENT_NONE       EQU 0            ; free slot
ENT_GOOMBA     EQU 1
ENT_KOOPA      EQU 2
ENT_SHELL      EQU 3
ENT_MUSH       EQU 4

; ---- Entity states ----
ST_IDLE        EQU 0            ; waiting until it comes near the screen
ST_WALK        EQU 1            ; walking (also: mushroom moving)
ST_FLAT        EQU 2            ; flattened Goomba
ST_STILL       EQU 3            ; stationary shell
ST_SLIDE       EQU 4            ; sliding shell

; ---- Record layout (16 bytes) ----
E_TYPE         EQU 0            ; byte  ENT_xxx
E_STATE        EQU 1            ; byte  ST_xxx
E_X            EQU 2            ; word  world x (whole pixels)
E_Y            EQU 4            ; word  world y of the top
E_XF           EQU 6            ; byte  x fraction
E_YF           EQU 7            ; byte  y fraction
E_VX           EQU 8            ; word  horizontal speed, 8.8 signed
E_VY           EQU 10           ; word  vertical speed, 8.8 signed
E_TIMER        EQU 12           ; word  flat time / kick grace frames
E_GROUND       EQU 14           ; byte  1 = standing on solid ground
ENT_SIZE       EQU 16
MAX_ENTITIES   EQU 8            ; at most 8 entities (Appendix A.4)

; ---- Numbers (Appendix A.4 / A.5, frames at the 18 Hz timer) ----
GOOMBA_SPEED   EQU 0080h        ; 0.5  px/frame
KOOPA_SPEED    EQU 00C0h        ; 0.75 px/frame
SHELL_SPEED    EQU 0300h        ; 3.0  px/frame
MUSH_SPEED     EQU 0100h        ; 1.0  px/frame
ENT_GRAVITY    EQU 0040h        ; added to vy every frame
ENT_MAX_FALL   EQU 0400h
FLAT_FRAMES    EQU 18           ; flat Goomba stays about 1 s
KICK_GRACE     EQU 8            ; shell ignores Mario for 8 frames
STOMP_BOUNCE   EQU 0FD00h       ; -3.0 : bounce after a stomp
STOMP_BOUNCE_HI EQU 0FC00h      ; -4.0 : bounce while Space is held
INVULN_FRAMES  EQU 36           ; about 2 s of blinking

; ---- Cause of death (read by states.asm) ----
DEATH_ENEMY    EQU 1
DEATH_PIT      EQU 2
DEATH_TIME     EQU 3

; ---- Data ----
entity_table  times ENT_SIZE * MAX_ENTITIES db 0
hero_dead     db 0              ; 1 = Mario was killed by an enemy

ent_speed     dw 0, GOOMBA_SPEED, KOOPA_SPEED, SHELL_SPEED, MUSH_SPEED

; stomp chain (Section 5.4): points of stomp number 1 .. 10
stomp_table   dw 100, 200, 400, 500, 800, 1000, 2000, 4000, 5000, 8000

; one start record: type, x, y
%macro ENT 3
    db %1, ST_IDLE              ; type, state
    dw %2, %3                   ; x, y
    db 0, 0                     ; x fraction, y fraction
    dw 0, 0                     ; vx, vy
    dw 0                        ; timer
    db 0, 0                     ; on ground, spare
%endmacro

; start positions: 4 Goombas, 2 Koopas, 2 free slots for mushrooms
entity_init:
    ENT ENT_GOOMBA, 160, 144    ; first screen
    ENT ENT_GOOMBA, 304, 144    ; between the two pipes
    ENT ENT_GOOMBA, 432, 144    ; before the first pit
    ENT ENT_GOOMBA, 560, 144    ; on the middle platform
    ENT ENT_KOOPA,  640, 144    ; near the second pit
    ENT ENT_KOOPA,  800, 144    ; before the stairs
    ENT ENT_NONE,   0,   0      ; mushroom slot
    ENT ENT_NONE,   0,   0      ; mushroom slot

; ============================================================
; Updating the entities (frame step 4)
; ============================================================

; ------------------------------------------------------------
; UpdateEntities
; Purpose : Update every entity (indexed loop over the table),
;           then let the entities meet each other (shell kills).
; Inputs  : entity_table      Outputs : entity_table updated
; Changes : none
; ------------------------------------------------------------
UpdateEntities:
    push ax
    push bx
    push cx

    mov  bx, entity_table
    mov  cx, MAX_ENTITIES
.next:
    cmp  byte [bx + E_TYPE], ENT_NONE
    je   .skip
    push bx
    call UpdateOneEntity
.skip:
    add  bx, ENT_SIZE
    loop .next

    call EntitiesCollide

    pop  cx
    pop  bx
    pop  ax
    ret

; ------------------------------------------------------------
; UpdateOneEntity(address)            ret 2
; Purpose : Removal, activation, flat timer, gravity and walking
;           of one entity (Section 5.5).
; Inputs  : [bp+4] = address of the record
; Outputs : record updated (type = ENT_NONE when removed)
; Changes : none
; ------------------------------------------------------------
UpdateOneEntity:
    push bp
    mov  bp, sp
    push ax
    push bx
    push si

    mov  bx, [bp + 4]

    ; removed when it falls below the map ...
    cmp  word [bx + E_Y], MAP_BOTTOM
    jge  .remove
    ; ... or is more than 32 pixels left of the screen
    mov  ax, [bx + E_X]
    sub  ax, [camera_x]             ; AX = screen x
    cmp  ax, -32
    jl   .remove

    ; stands still until it is within one tile of the screen
    cmp  byte [bx + E_STATE], ST_IDLE
    jne  .active
    cmp  ax, SCREEN_W + TILE_SIZE
    jge  .done
    mov  byte [bx + E_STATE], ST_WALK
    mov  al, [bx + E_TYPE]          ; start walking to the left
    xor  ah, ah
    mov  si, ax
    shl  si, 1
    mov  ax, [ent_speed + si]
    neg  ax
    mov  [bx + E_VX], ax
    jmp  .done

.active:
    cmp  byte [bx + E_STATE], ST_FLAT
    jne  .not_flat
    dec  word [bx + E_TIMER]        ; flat Goomba: only the timer runs
    jnz  .done
    jmp  .remove
.not_flat:
    cmp  word [bx + E_TIMER], 0     ; kick grace counts down to 0
    je   .moving
    dec  word [bx + E_TIMER]
.moving:
    push bx
    call EntityFall
    cmp  byte [bx + E_STATE], ST_STILL
    je   .done                      ; a stationary shell does not walk
    push bx
    call EntityWalk
    jmp  .done

.remove:
    mov  byte [bx + E_TYPE], ENT_NONE
.done:
    pop  si
    pop  bx
    pop  ax
    pop  bp
    ret  2

; ------------------------------------------------------------
; EntityFall(address)                 ret 2
; Purpose : Gravity and landing. vy grows by ENT_GRAVITY (limited
;           to ENT_MAX_FALL), y moves by vy (fraction first, then
;           ADC), then the two pixels under the feet are tested.
; Inputs  : [bp+4] = address of the record
; Outputs : E_Y, E_YF, E_VY, E_GROUND
; Changes : none
; ------------------------------------------------------------
EntityFall:
    push bp
    mov  bp, sp
    push ax
    push bx
    push cx
    push dx

    mov  bx, [bp + 4]
    mov  ax, [bx + E_VY]
    add  ax, ENT_GRAVITY
    cmp  ax, ENT_MAX_FALL
    jle  .speed_ok
    mov  ax, ENT_MAX_FALL
.speed_ok:
    mov  [bx + E_VY], ax
    add  [bx + E_YF], al            ; fraction, carry in CF
    mov  al, ah                     ; whole pixels of the speed
    cbw
    adc  [bx + E_Y], ax             ; y = y + whole + carry

    mov  byte [bx + E_GROUND], 0
    mov  dx, [bx + E_Y]
    add  dx, 16                     ; DX = pixel row just under the feet
    mov  cx, [bx + E_X]
    add  cx, 3                      ; left foot
    push cx
    push dx
    call IsSolidAt
    cmp  al, 1
    je   .land
    mov  cx, [bx + E_X]
    add  cx, 12                     ; right foot
    push cx
    push dx
    call IsSolidAt
    cmp  al, 1
    jne  .done
.land:
    mov  ax, [bx + E_Y]             ; put the feet on top of the tile
    add  ax, 16
    and  ax, 0FFF0h
    sub  ax, 16
    mov  [bx + E_Y], ax
    mov  byte [bx + E_YF], 0
    mov  word [bx + E_VY], 0
    mov  byte [bx + E_GROUND], 1
.done:
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    pop  bp
    ret  2

; ------------------------------------------------------------
; EntityWalk(address)                 ret 2
; Purpose : Move horizontally. A wall in front turns the entity
;           around (a sliding shell bounces). A walking Koopa also
;           turns around at the edge of a platform. Goombas and the
;           mushroom walk off ledges and fall.
; Inputs  : [bp+4] = address of the record
; Outputs : E_X, E_XF, E_VX
; Changes : none
; ------------------------------------------------------------
EntityWalk:
    push bp
    mov  bp, sp
    push ax
    push bx
    push cx
    push dx
    push si

    mov  bx, [bp + 4]
    mov  ax, [bx + E_VX]
    cmp  ax, 0
    je   .done                      ; not moving
    mov  dx, [bx + E_X]             ; remember the old position
    mov  cl, [bx + E_XF]

    add  [bx + E_XF], al            ; move: fraction, then whole + carry
    mov  al, ah
    cbw
    adc  [bx + E_X], ax

    cmp  word [bx + E_VX], 0        ; SI = x of the leading edge
    jl   .going_left
    mov  si, [bx + E_X]
    add  si, 15
    jmp  .probe
.going_left:
    mov  si, [bx + E_X]
.probe:
    mov  ax, [bx + E_Y]             ; wall at the upper body ...
    add  ax, 4
    push si
    push ax
    call IsSolidAt
    cmp  al, 1
    je   .turn
    mov  ax, [bx + E_Y]             ; ... and at the lower body
    add  ax, 13
    push si
    push ax
    call IsSolidAt
    cmp  al, 1
    je   .turn

    cmp  byte [bx + E_TYPE], ENT_KOOPA      ; platform edge: Koopa only
    jne  .done
    cmp  byte [bx + E_GROUND], 1
    jne  .done
    cmp  byte [bx + E_STATE], ST_WALK
    jne  .done
    mov  ax, [bx + E_Y]
    add  ax, 16                     ; tile under the leading foot
    push si
    push ax
    call IsSolidAt
    cmp  al, 1
    je   .done                      ; still ground ahead
.turn:
    mov  [bx + E_X], dx             ; undo the step and turn around
    mov  [bx + E_XF], cl
    neg  word [bx + E_VX]
.done:
    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    pop  bp
    ret  2

; ============================================================
; Entity meets entity (shell kills, turning at each other)
; ============================================================

; ------------------------------------------------------------
; EntitiesCollide
; Purpose : Test every pair of active entities with RectsOverlap
;           (16x16 boxes) and apply ResolveEntityPair.
; Inputs  : entity_table      Outputs : entity_table updated
; Changes : none
; ------------------------------------------------------------
EntitiesCollide:
    push ax
    push bx
    push cx
    push si
    push di

    mov  si, entity_table
    mov  cx, MAX_ENTITIES - 1       ; outer loop: entity 0 .. 6
.outer:
    mov  bx, cx                     ; inner loop count = entities after SI
    mov  di, si
    add  di, ENT_SIZE
.inner:
    cmp  byte [si + E_TYPE], ENT_NONE       ; SI may have been removed
    je   .next_outer
    cmp  byte [si + E_STATE], ST_IDLE
    je   .next_outer
    cmp  byte [si + E_STATE], ST_FLAT
    je   .next_outer
    cmp  byte [di + E_TYPE], ENT_NONE
    je   .next_inner
    cmp  byte [di + E_STATE], ST_IDLE
    je   .next_inner
    cmp  byte [di + E_STATE], ST_FLAT
    je   .next_inner

    push word [si + E_X]
    push word [si + E_Y]
    push word 16
    push word 16
    push word [di + E_X]
    push word [di + E_Y]
    push word 16
    push word 16
    call RectsOverlap
    cmp  al, 1
    jne  .next_inner
    call ResolveEntityPair          ; works on the records at SI and DI
.next_inner:
    add  di, ENT_SIZE
    dec  bx
    jnz  .inner
.next_outer:
    add  si, ENT_SIZE
    loop .outer

    pop  di
    pop  si
    pop  cx
    pop  bx
    pop  ax
    ret

; ------------------------------------------------------------
; ResolveEntityPair
; Purpose : Two overlapping entities.
;           * a sliding shell removes the Goomba / Koopa it touches
;             (+500 points each)
;           * two walking enemies that move toward each other turn
;             around
; Inputs  : SI = first record, DI = second record
; Outputs : records updated, score
; Changes : none
; ------------------------------------------------------------
ResolveEntityPair:
    push ax

    cmp  byte [si + E_TYPE], ENT_SHELL      ; SI is a sliding shell?
    jne  .di_shell
    cmp  byte [si + E_STATE], ST_SLIDE
    jne  .di_shell
    cmp  byte [di + E_TYPE], ENT_GOOMBA
    je   .kill_di
    cmp  byte [di + E_TYPE], ENT_KOOPA
    je   .kill_di
.di_shell:
    cmp  byte [di + E_TYPE], ENT_SHELL      ; DI is a sliding shell?
    jne  .walkers
    cmp  byte [di + E_STATE], ST_SLIDE
    jne  .walkers
    cmp  byte [si + E_TYPE], ENT_GOOMBA
    je   .kill_si
    cmp  byte [si + E_TYPE], ENT_KOOPA
    je   .kill_si

.walkers:                                   ; both walking enemies?
    mov  al, [si + E_TYPE]
    dec  al
    cmp  al, 1                              ; type 1 or 2 only
    ja   .done
    mov  al, [di + E_TYPE]
    dec  al
    cmp  al, 1
    ja   .done
    cmp  byte [si + E_STATE], ST_WALK
    jne  .done
    cmp  byte [di + E_STATE], ST_WALK
    jne  .done
    mov  ax, [si + E_VX]
    xor  ax, [di + E_VX]
    jns  .done                              ; same direction: nothing
    neg  word [si + E_VX]                   ; head-on: both turn around
    neg  word [di + E_VX]
    jmp  .done

.kill_di:
    mov  byte [di + E_TYPE], ENT_NONE
    jmp  .points
.kill_si:
    mov  byte [si + E_TYPE], ENT_NONE
.points:
    push word 500
    call AddScore
.done:
    pop  ax
    ret

; ============================================================
; Mario meets the entities (frame step 5)
; ============================================================

; ------------------------------------------------------------
; ResolveHeroEntities
; Purpose : Test Mario against every active entity.
;           Mushroom: +1000, Small -> Super.
;           Others: DecideStompOrHurt (collision.asm) then
;           HandleEnemyContact.
; Inputs  : entity_table, hero variables
; Outputs : score, form, hp, hero_vy, entities
; Changes : none
; ------------------------------------------------------------
ResolveHeroEntities:
    push ax
    push bx
    push cx

    mov  bx, entity_table
    mov  cx, MAX_ENTITIES
.next:
    cmp  byte [bx + E_TYPE], ENT_NONE
    je   .skip
    cmp  byte [bx + E_STATE], ST_IDLE
    je   .skip
    cmp  byte [bx + E_STATE], ST_FLAT
    je   .skip
    cmp  byte [bx + E_TYPE], ENT_MUSH
    je   .mushroom
    cmp  word [bx + E_TIMER], 0     ; kick grace: shell ignores Mario
    jne  .skip

    push word [bx + E_X]
    push word [bx + E_Y]
    push word 16
    push word 16
    call DecideStompOrHurt          ; AL = HIT_xxx
    cmp  al, HIT_NONE
    je   .skip
    xor  ah, ah
    push bx
    push ax
    call HandleEnemyContact
    jmp  .skip

.mushroom:
    push word [bx + E_X]
    push word [bx + E_Y]
    push word 16
    push word 16
    call HeroOverlapsBox
    cmp  al, 1
    jne  .skip
    mov  byte [bx + E_TYPE], ENT_NONE
    push word 1000
    call AddScore
    call MakeHeroSuper
.skip:
    add  bx, ENT_SIZE
    loop .next

    pop  cx
    pop  bx
    pop  ax
    ret

; ------------------------------------------------------------
; HandleEnemyContact(address, result)      ret 4
; Purpose : Apply one contact (Sections 5.4 - 5.7).
;           Walking Goomba / Koopa: stomp -> flat Goomba or shell,
;           chain points and bounce; otherwise Mario is hurt.
;           Stationary shell: any touch kicks it (+400, no damage).
;           Sliding shell: stomp stops it (chain points), a side
;           touch hurts Mario.
; Inputs  : [bp+6] = address of the record, [bp+4] = HIT_xxx
; Outputs : entity, score, hero state
; Changes : none
; ------------------------------------------------------------
HandleEnemyContact:
    push bp
    mov  bp, sp
    push ax
    push bx

    mov  bx, [bp + 6]
    mov  ax, [bp + 4]

    cmp  byte [bx + E_TYPE], ENT_SHELL
    jne  .walker
    cmp  byte [bx + E_STATE], ST_STILL
    jne  .sliding

    ; stationary shell: kicked by any touch, Mario is not hurt
    push bx
    call KickShell
    cmp  al, HIT_STOMP              ; AL still holds the contact result
    jne  .done
    call BounceHero
    jmp  .done

.sliding:
    cmp  al, HIT_STOMP
    jne  .not_stomp
    mov  byte [bx + E_STATE], ST_STILL      ; stomp stops the shell
    mov  word [bx + E_VX], 0
    mov  word [bx + E_TIMER], KICK_GRACE
    call StompPoints
    call BounceHero
    jmp  .done

.walker:
    cmp  al, HIT_STOMP
    jne  .not_stomp
    cmp  byte [bx + E_TYPE], ENT_KOOPA
    je   .koopa
    mov  byte [bx + E_STATE], ST_FLAT       ; Goomba is flattened
    mov  word [bx + E_VX], 0
    mov  word [bx + E_TIMER], FLAT_FRAMES
    jmp  .stomped
.koopa:
    mov  byte [bx + E_TYPE], ENT_SHELL      ; Koopa becomes a shell
    mov  byte [bx + E_STATE], ST_STILL
    mov  word [bx + E_VX], 0
    mov  word [bx + E_TIMER], KICK_GRACE
.stomped:
    call StompPoints
    call BounceHero
    jmp  .done

.not_stomp:
    cmp  al, HIT_HURT
    jne  .done                      ; HIT_IGNORED: invulnerable
    call HurtHero
.done:
    pop  bx
    pop  ax
    pop  bp
    ret  4

; ------------------------------------------------------------
; KickShell(address)                 ret 2
; Purpose : Kick a stationary shell: +400 points, it slides away
;           from Mario and ignores him for KICK_GRACE frames.
; Inputs  : [bp+4] = address of the record
; Outputs : record, score
; Changes : none
; ------------------------------------------------------------
KickShell:
    push bp
    mov  bp, sp
    push ax
    push bx

    mov  bx, [bp + 4]
    push word 400
    call AddScore
    mov  byte [bx + E_STATE], ST_SLIDE
    mov  word [bx + E_TIMER], KICK_GRACE
    mov  ax, [hero_x]
    cmp  ax, [bx + E_X]
    jl   .slide_right               ; Mario is on the left: push right
    mov  word [bx + E_VX], -SHELL_SPEED
    jmp  .done
.slide_right:
    mov  word [bx + E_VX], SHELL_SPEED
.done:
    pop  bx
    pop  ax
    pop  bp
    ret  2

; ------------------------------------------------------------
; StompPoints
; Purpose : Points of the next stomp in this jump (chain table
;           100, 200, 400, ... 8000). The 11th stomp gives a life.
; Inputs  : stomp_chain      Outputs : score / lives, stomp_chain + 1
; Changes : none
; ------------------------------------------------------------
StompPoints:
    push bx

    xor  bx, bx
    mov  bl, [stomp_chain]
    cmp  bl, 10
    jae  .one_up
    shl  bx, 1                      ; word table
    push word [stomp_table + bx]
    call AddScore
    jmp  .count
.one_up:
    call AddLife
.count:
    cmp  byte [stomp_chain], 255
    jae  .done
    inc  byte [stomp_chain]
.done:
    pop  bx
    ret

; ------------------------------------------------------------
; BounceHero
; Purpose : Mario bounces up after a stomp (higher while Space
;           is held).
; Inputs  : key_state     Outputs : hero_vy, on_ground     Changes : none
; ------------------------------------------------------------
BounceHero:
    push ax

    push word SC_SPACE
    call IsKeyHeld                  ; AL = 1 when Space is held
    cmp  al, 1
    mov  ax, STOMP_BOUNCE           ; MOV does not change the flags
    jne  .set
    mov  ax, STOMP_BOUNCE_HI
.set:
    mov  [hero_vy], ax
    mov  byte [on_ground], 0
    pop  ax
    ret

; ------------------------------------------------------------
; HurtHero
; Purpose : Mario touched an enemy (Section 5.7).
;           Super -> Small (HP 1) with 2 s invulnerability and
;           fixed feet. Small -> dies (hero_dead = 1).
; Inputs  : form      Outputs : form, hp, hero_y, invuln_timer, hero_dead
; Changes : none
; ------------------------------------------------------------
HurtHero:
    cmp  byte [form], FORM_SUPER
    jne  .die
    mov  byte [form], FORM_SMALL
    mov  byte [hp], 1
    add  word [hero_y], 16          ; feet stay: new top = old top + 16
    mov  word [invuln_timer], INVULN_FRAMES
    ret
.die:
    mov  byte [hp], 0
    mov  byte [hero_dead], 1
    ret

; ------------------------------------------------------------
; MakeHeroSuper
; Purpose : Mushroom collected. Small -> Super (HP 2) with fixed
;           feet (y_top = y_feet - 32). Already Super: nothing.
; Inputs  : form      Outputs : form, hp, hero_y      Changes : none
; ------------------------------------------------------------
MakeHeroSuper:
    cmp  byte [form], FORM_SUPER
    je   .done
    mov  byte [form], FORM_SUPER
    mov  byte [hp], 2
    sub  word [hero_y], 16
.done:
    ret

; ------------------------------------------------------------
; SpawnMushroom(x, y)                 ret 4
; Purpose : Put a mushroom into a free slot; it appears on top of
;           its block and moves right at 1 px/frame.
; Inputs  : [bp+6] = world x, [bp+4] = world y (top of mushroom)
; Outputs : entity_table
; Changes : none
; ------------------------------------------------------------
SpawnMushroom:
    push bp
    mov  bp, sp
    push ax
    push bx
    push cx

    mov  bx, entity_table
    mov  cx, MAX_ENTITIES
.find:
    cmp  byte [bx + E_TYPE], ENT_NONE
    je   .found
    add  bx, ENT_SIZE
    loop .find
    jmp  .done                      ; table full: no mushroom
.found:
    mov  byte [bx + E_TYPE], ENT_MUSH
    mov  byte [bx + E_STATE], ST_WALK
    mov  ax, [bp + 6]
    mov  [bx + E_X], ax
    mov  ax, [bp + 4]
    mov  [bx + E_Y], ax
    mov  byte [bx + E_XF], 0
    mov  byte [bx + E_YF], 0
    mov  word [bx + E_VX], MUSH_SPEED
    mov  word [bx + E_VY], 0
    mov  word [bx + E_TIMER], 0
    mov  byte [bx + E_GROUND], 0
.done:
    pop  cx
    pop  bx
    pop  ax
    pop  bp
    ret  4

; ============================================================
; Drawing
; ============================================================

; ------------------------------------------------------------
; DrawEntities
; Purpose : Draw every active entity that is on the screen
;           (-16 < screen_x < 320). Koopas are mirrored when they
;           walk to the left (the sprite faces right).
; Inputs  : entity_table, camera_x
; Outputs : sprites in the frame buffer
; Changes : none
; ------------------------------------------------------------
DrawEntities:
    push ax
    push bx
    push cx
    push dx
    push si

    mov  bx, entity_table
    mov  cx, MAX_ENTITIES
.next:
    cmp  byte [bx + E_TYPE], ENT_NONE
    je   .skip
    mov  ax, [bx + E_X]
    sub  ax, [camera_x]             ; AX = screen x
    cmp  ax, -16
    jle  .skip                      ; fully left of the screen
    cmp  ax, SCREEN_W
    jge  .skip                      ; fully right of the screen

    xor  dx, dx                     ; DX = flags (bit 0 = mirror)
    mov  si, goomba_walk
    cmp  byte [bx + E_TYPE], ENT_GOOMBA
    jne  .not_goomba
    cmp  byte [bx + E_STATE], ST_FLAT
    jne  .draw
    mov  si, goomba_flat
    jmp  .draw
.not_goomba:
    cmp  byte [bx + E_TYPE], ENT_KOOPA
    jne  .not_koopa
    mov  si, koopa_walk
    cmp  word [bx + E_VX], 0
    jge  .draw
    mov  dx, 1                      ; walking left: mirror
    jmp  .draw
.not_koopa:
    mov  si, shell_sprite
    cmp  byte [bx + E_TYPE], ENT_SHELL
    je   .draw
    mov  si, mushroom_sprite
.draw:
    push ax
    push word [bx + E_Y]
    push si
    push dx
    call DrawSprite
.skip:
    add  bx, ENT_SIZE
    loop .next

    pop  si
    pop  dx
    pop  cx
    pop  bx
    pop  ax
    ret