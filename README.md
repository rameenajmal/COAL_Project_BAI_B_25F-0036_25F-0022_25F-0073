# COAL_Project_BAI_B_25F-0036_25F-0022_25F-0073
## Team Members and Module Division

The project has 15 modules (Section 6 of the project manual). We divided them
among the three members according to the amount of code and the difficulty of
each module, so that every member has an equal workload.

| Member | Roll Number | Modules | Source Files |
|--------|-------------|---------|--------------|
| Member 1: Rameen Ajmal | 25F-0036 | 1, 2, 3, 4, 5, 6, 8 | `mario.asm`, `video.asm`, `map.asm`, `timer.asm` |
| Member 2: Faryal Fatima | 25F-0022 | 7, 9, 10, 12 | `input.asm`, `player.asm` |
| Member 3: Abdul Rafay | 25F-0073 | 11, 13, 14, 15 | `enemies.asm`, `hud.asm`, `states.asm` |

### Member 1 (25F-0036): Graphics, Map, Camera and Timer
- Module 1: Program Skeleton and Build Setup
- Module 2: Video Mode and Colours
- Module 3: Level Map and Tile Drawing
- Module 4: Sprites
- Module 5: Frame Buffer and Block Operations
- Module 6: Camera and Scrolling
- Module 8: Timer and Game Clock

### Member 2 (25F-0022): Input, Movement, Collision and Blocks
- Module 7: Keyboard Interrupt Handler
- Module 9: Player Movement and Physics
- Module 10: Collision Detection
- Module 12: Blocks, Coins and Power-ups

### Member 3 (25F-0073): Enemies, HUD, Game States and Restart
- Module 11: Enemies and Shells
- Module 13: Score, Health, Lives and HUD
- Module 14: Game States, Screens and Menus
- Module 15: Win, Lose, Restart and Clean Exit

### Workload Balance
Each module was given a difficulty weight from 1 (small) to 5 (large), and the
modules were divided so that each member has a total weight of 16.

| Member | Modules | Total Weight |
|--------|---------|--------------|
| Member 1 | 1, 2, 3, 4, 5, 6, 8 | 1+2+3+4+2+2+2 = 16 |
| Member 2 | 7, 9, 10, 12 | 3+4+5+4 = 16 |
| Member 3 | 11, 13, 14, 15 | 5+4+4+3 = 16 |

### Working Rules
- Each member works mainly in his or her own source files to avoid merge conflicts.
- All files are joined into `mario.asm` using `%include`.
- Each member commits from his or her own GitHub account.
- Integration work (Modules 14 and 15) needs all members, so it is done together.

## Memory Choices

### Frame Buffer (Module 5)

- The game is a `.COM` program, so code, data and stack share one 64 KB segment.
- A full-screen frame buffer needs 64,000 bytes, so it cannot sit beside the code.
- The buffer lives in a separate segment placed `1000h` paragraphs (64 KB) above the program's code segment (`buffer_seg = CS + 1000h`).
- DOS gives a `.COM` program all the free conventional memory, so this segment is free and no extra allocation call (INT 21h) is needed.
- All drawing procedures (`PutPixel`, `FillRect`, `DrawSprite`) write to the segment stored in `draw_seg`. Setting `draw_seg = buffer_seg` sends all drawing to the buffer.

### Frame Drawing Steps

1. `ClearBuffer` fills the buffer with black using `rep stosw` (32000 words).
2. The map, sprites and HUD are drawn into the buffer.
3. `ShowBuffer` copies the buffer to video memory (`0A000h`) using `rep movsw` (32000 words), once per frame.

This removes flicker, because the screen only ever receives a finished picture.

### Timer and Game Clock (Module 8)

- The game hooks `INT 1Ch` (the user timer hook). `TimerHandler` increments `tick_count` and then jumps to the old handler, so the BIOS timer keeps working.
- The timer rate is not changed (about 18.2 ticks per second), so no rate restore is needed. The old vector is restored by `RestoreTimer` on exit.
- The game loop calls `WaitTick`, so the speed does not depend on the PC speed.
- `UpdateClock` is called once per frame and counts `game_time` down by 1 every 18 frames (18 ticks is treated as one second).