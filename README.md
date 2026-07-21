# Sugar Street Tycoon: Match & Build

Phase 1 prototype: a playable **match-3** foundation for a portrait mobile game built in **Godot 4** + **GDScript**.

Business management, Supabase, ads, IAP, workers, and online features are intentionally **not** included yet.

---

## How to launch

1. Install [Godot 4.3+](https://godotengine.org/download) (4.x Mobile/Forward+ is fine).
2. Open Godot → **Import** → select this folder (`project.godot`).
3. Press **F5** (or Play). The main scene is `res://scenes/main/main.tscn`.
4. Use the mouse on desktop; touch works on device / with touch emulation.

**Viewport:** 720×1280 portrait, stretched with `keep_width` for phones.

---

## Project structure

```
res://
├── assets/placeholders/     # Temporary dessert PNGs (swap later)
├── icon/                    # App icon
├── resources/
│   ├── pieces/              # PieceType .tres (chocolate, strawberry, …)
│   └── levels/              # LevelConfig + ObjectiveData .tres
├── scenes/
│   ├── main/                # Boot / main scene
│   ├── gameplay/            # Gameplay + board scenes
│   ├── ui/                  # HUD, win/loss/pause/debug
│   └── pieces/              # Dessert piece scene
└── scripts/
    ├── board/               # Board, match, swap, gravity
    ├── gameplay/            # Controller, score, objectives, level state
    ├── ui/                  # HUD / popup scripts
    ├── pieces/              # DessertPiece behavior
    ├── data/                # Resource class scripts
    └── main/                # Main boot script
```

---

## Main scripts

| Script | Role |
|--------|------|
| `scripts/board/board.gd` | Grid ownership, swaps, cascades, refill, reshuffle |
| `scripts/board/match_detector.gd` | Horizontal / vertical match finding + score tiers |
| `scripts/board/swap_validator.gd` | Adjacent swap rules + possible-move search |
| `scripts/board/board_gravity.gd` | Fall compaction + empty-cell discovery |
| `scripts/pieces/dessert_piece.gd` | Piece visuals, select/drag input, tweens |
| `scripts/gameplay/game_controller.gd` | Moves, win/loss, debug commands, orchestration |
| `scripts/gameplay/level_state.gd` | Playing / paused / won / lost |
| `scripts/gameplay/objective_tracker.gd` | Collect-N progress |
| `scripts/gameplay/score_tracker.gd` | Score + cascade multiplier reset |
| `scripts/data/level_config.gd` | Data-driven level settings |
| `scripts/data/piece_type.gd` | Piece id, color, texture |
| `scripts/data/objective_data.gd` | Target piece + amount |

---

## How to create another level

1. Duplicate `resources/levels/level_01.tres` (e.g. `level_02.tres`).
2. Optionally create a new `ObjectiveData` resource (or reuse one).
3. Edit exports:
   - `move_limit`
   - `columns` / `rows` (prototype assumes 8×8 but supports other sizes ≥ 3)
   - `piece_types` array
   - `objectives` array
4. Point `GameController.level_config` in `scenes/gameplay/gameplay.tscn` at the new resource  
   **or** load it from code in `GameController.start_level()`.

No board logic changes are required for a new collect-style level.

---

## How to replace placeholder piece artwork

1. Drop final textures into `assets/` (keep or replace files under `assets/placeholders/`).
2. Open the matching resource in `resources/pieces/*.tres`.
3. Assign the new `texture` on the `PieceType` resource.
4. Leave `id` values unchanged (`strawberry`, `chocolate`, …) so levels and objectives keep working.

Board and match logic only care about `PieceType.id`, not the image.

---

## Controls

- **Tap / click** a piece, then tap an adjacent piece to swap.
- **Drag** a piece toward an adjacent neighbor to swap.
- Only orthogonal adjacent swaps are allowed.
- Invalid swaps animate back and **do not** consume a move.

### Debug (development)

| Key | Action |
|-----|--------|
| `` ` `` | Toggle debug panel |
| `1` | Print board to Output |
| `2` | Restart level |
| `3` | Show whether possible moves exist |
| `4` | Add 5 moves |
| `5` | Add 5 objective progress |
| `6` | Force reshuffle |

---

## Current test level

- **20 moves**
- **Collect 20 strawberries**
- Scoring:
  - Match of 3 → 100 pts / piece
  - Match of 4 → 150 pts / piece
  - Match of 5+ → 200 pts / piece
  - Cascade multiplier increases each wave, resets when the board is stable

---

## Current limitations (by design)

- No shop / business management layer
- No Supabase accounts, cloud saves, leaderboards, or live events
- No ads or in-app purchases
- No special pieces (striped, wrapped, color bomb)
- No level map / multiple unlockable stages UI
- Placeholder art only
- Win **Continue** currently replays the same test level

---

## Manual Godot editor steps

Usually **none** if you open the project as-is. Optional:

1. Project → Project Settings → confirm **Display → Window** portrait 720×1280.
2. Project → Export → add Android / iOS presets when you are ready to ship.
3. Reimport textures after replacing artwork (Godot does this automatically on focus).

---

## Automated smoke tests (optional)

With Godot 4.3+ on your PATH:

```bash
godot --headless --path . -s res://scripts/tools/headless_smoke_test.gd
godot --headless --path . -s res://scripts/tools/headless_swap_test.gd
godot --headless --path . -s res://scripts/tools/headless_invalid_swap_test.gd
```

These verify level resources, starting-board constraints, valid move consumption, and invalid-swap rollback.

---

## Exact manual testing steps

1. Open the project in Godot 4.3+ and press **F5**.
2. Confirm the HUD shows **Sugar Street Tycoon**, **20 moves**, **0 / 20** strawberries, score **0**.
3. Tap a piece, then an adjacent piece — invalid pairs should bounce back with moves unchanged.
4. Make a valid match — pieces clear, others fall, new pieces spawn, cascades resolve, moves decrease by 1.
5. Press `` ` `` and use debug **+5 Objective** until you win; confirm the win popup.
6. Restart, burn moves with debug or play until loss; confirm the loss popup.
7. Use debug **Reshuffle** / **Check Moves** to confirm reshuffle leaves a playable board.
