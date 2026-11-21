; ============================================================
; File    : level_data.asm
; Module  : 3 (Level Map and Tile Drawing)
; Purpose : Level data, 60 columns x 12 rows, one byte per tile
;           (tile codes of Appendix A.2).
;           level_original - never changed
;           level_working  - copy used while playing
;           Current level is a starter version: ground, bricks,
;           ? blocks and coins. Pits, pipes, stairs and the flag
;           pole will be added later.
;           Level has ground, 2 pits, 2 pipes, bricks, ? blocks,
;           coins, 4 stairs and the flag pole.
; Author  : 25F-0036
; ============================================================
; original map (never changed)
level_original:
; row 0 (HUD)
db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
; row 1
db 0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
; row 2 (flag pole top)
times 57 db 0
db 12
times 2 db 0
; row 3
times 57 db 0
db 12
times 2 db 0
; row 4
times 57 db 0
db 12
times 2 db 0
; row 5 (coins, flag pole)
times 10 db 0
db 11,11,11
times 23 db 0
db 11,11,11,11,11
times 16 db 0
db 12
times 2 db 0
; row 6 (stair step 4, flag pole)
times 55 db 0
db 10
db 0
db 12
times 2 db 0
; row 7 (blocks, pipe 2 top, coins, blocks, stairs, flag pole)
times 6 db 0
db 2,3,2,4,2
times 11 db 0
db 6,7
times 6 db 0
db 11,11
times 4 db 0
db 2,3,2,3,2
times 8 db 0
db 4
times 4 db 0
db 10,10
db 0
db 12
times 2 db 0
; row 8 (pipe 1 top, pipe 2 body, stairs, flag pole)
times 16 db 0
db 6,7
times 4 db 0
db 8,9
times 29 db 0
db 10,10,10
db 0
db 12
times 2 db 0
; row 9 (pipe bodies, stairs, flag base)
times 16 db 0
db 8,9
times 4 db 0
db 8,9
times 28 db 0
db 10,10,10,10
db 0
db 10
times 2 db 0
; row 10 (ground with 2 pits)
times 30 db 1
times 2 db 0
times 12 db 1
times 3 db 0
times 13 db 1
; row 11 (ground with 2 pits)
times 30 db 1
times 2 db 0
times 12 db 1
times 3 db 0
times 13 db 1
level_working:
times 720 db 0