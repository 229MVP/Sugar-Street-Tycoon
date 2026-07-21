# Sugar Street Tycoon: Match & Build

Portrait **Godot 4** / **GDScript** prototype combining:

1. Match-3 dessert puzzles  
2. Dessert shop management (orders, recipes, equipment, inventory)  
3. Worker system with passive / offline earnings  

Supabase, ads, IAP, multiple locations, and multiplayer are **not** included yet.

---

## How to launch

1. Install [Godot 4.3+](https://godotengine.org/download).
2. Open Godot → **Import** → this folder (`project.godot`).
3. Press **F5**. Main scene: `res://scenes/main/title_screen.tscn`.
4. Flow: **Title (Play/Continue) → Shop Hub → Start Order → `main.tscn` puzzle → Shop Hub**.
5. Mouse on desktop; touch on device (`emulate_touch_from_mouse` enabled).

**Viewport:** 720×1280 portrait, `keep_width` stretch.

---

## Game loop

```
Title → Continue / New Game
  → Shop Hub
    → Select customer order
    → Match-3 level (win / lose)
    → Return to Shop
    → Complete Order (grants rewards once)
    → Hire / upgrade workers, unlock recipes, upgrade equipment
    → Collect walk-in (passive) income
```

Winning a level marks the order **Ready to Complete**. Rewards are granted only when you press **Complete Order** in the shop.

---

## Scene flow

`title_screen.tscn` → `shop_hub.tscn` ⇄ `worker_roster.tscn` / `recipe_book.tscn` / `upgrade_shop.tscn` / `inventory_screen.tscn`  
`shop_hub` → `main.tscn` (order session; hosts gameplay) → back to `shop_hub`

Autoloads: `GameState`, `AudioManager`, `SceneRouter`.

---

## Worker system overview

| Worker | Role | Station | Unlock | Hire | Primary bonus |
|--------|------|---------|--------|------|----------------|
| Ava | Baker | Oven | Lv1 | 300 | +3% order coins / level |
| Marcus | Cashier | Checkout | Lv2 | 450 | +2% order reputation / level |
| Lily | Mixer Specialist | Mixer | Lv3 | 750 | +3% order XP / level |
| Noah | Display Decorator | Display Case | Lv4 | 1000 | +5% passive income / level |
| Sofia | Order Coordinator | Order Desk | Lv5 | 1500 | Bonus ingredient chance 5% +2%/level |
| Chef Andre | Store Manager | Manager | Lv8 + 150 rep | 4000 | +2% all order rewards / level; +3% passive / level |

- Max worker level: **10**
- Bonuses apply only when **hired and assigned** to a compatible station
- One worker per station

### How to create a new worker

1. Add a `_add_worker(...)` entry in `scripts/shop/content_catalog.gd` → `_build_workers()`.
2. Set role, rarity, unlock requirements, hire cost, station, bonus types.
3. Append the id to `worker_sequence`.

### Hiring / upgrades / assignments

- **Hire:** unlocked + enough coins → confirmation → deduct → save. Cannot hire twice.
- **Upgrade costs:** base ladder 250→5500 with rarity multipliers (Common 1.0, Uncommon 1.2, Rare 1.5, Premium 2.0).
- **Assign:** hired + compatible station; replace confirmation if occupied; unassign clears bonuses.

### Reward calculation order

1. Base customer order reward  
2. Equipment bonuses  
3. Worker bonuses (assigned only)  
4. (Reserved) temporary event bonuses  
5. Final rounded integers  

Order detail popup shows base / equipment / worker / final breakdown.

---

## Passive income formula

```
rate = 10 coins/min
     × shop_level_multiplier (1.0 / 1.15 / 1.30 / 1.50 / 1.75 for shop lv 1–5)
     × (1 + display_case_bonus)   # +3% per display level above 1
     × (1 + worker_passive_bonus) # Noah / Chef Andre when assigned
```

- Accumulates while Shop Hub is open (1s ticks).
- Stored in `stored_passive_coins` until **Collect**.
- **Cap:** 4 hours of storage at the current rate; then stops until collected.

### Offline earnings

On load / continue:

1. `elapsed = now - last_active_unix`
2. Reject if missing timestamp, negative (clock skew), or `< 60s`
3. Cap elapsed at **4 hours**
4. Compute using the passive formula with saved bonuses
5. Add into **storage** (not wallet)
6. Show Offline Earnings popup → Collect moves storage into coins
7. `last_offline_calc_unix` prevents double application of the same away period

---

## Save data (version 2)

File: `user://sugar_street_save.json` (+ `.bak.json`)

Includes player economy, orders, recipes, equipment, inventory, **plus**:

- `hired_workers`, `worker_levels`, `worker_assignments`, `worker_unlock_flags`
- `stored_passive_coins`, `last_active_unix`, `last_passive_tick_unix`, `last_offline_calc_unix`
- `offline_pending_popup`, `worker_save_version`

**Migration:** v1 saves load with defaults (`apply_worker_defaults`) without wiping progress. Invalid assignments/levels/negative storage are repaired by `WorkerManager.repair_assignments`.

---

## Project structure (additions)

```
scripts/workers/     worker_data helpers, manager, bonus calculator, roster UI
scripts/economy/     reward_calculator, passive_income_manager, offline_earnings_calculator
scripts/shop/        game_state, shop hub/visual/activity, passive + offline UI
scenes/workers/      worker_roster.tscn
scenes/shop/         shop_hub.tscn
scenes/title/        title.tscn
```

---

## Debug tools (debug builds only)

Shop debug panel includes: +coins/stars/XP/rep, unlock/hire/assign workers, simulate 1h offline, fill/clear passive storage, print workers/bonuses, corrupt/repair worker save, reset workers only, reset full save.

Match-3 debug keys (`  / 1–6) still work in gameplay.

---

## Automated tests

```bash
godot --headless --path . -s res://scripts/tools/headless_worker_test.gd
```

---

## Current limitations

- Placeholder art / silent audio hooks
- No ingredient consumption or ingredient shop
- No multiple locations / workers pathfinding
- Passive income intentionally weaker than active puzzle play
- Offline protections are local anti-glitch only (not cheat-proof)
- Win **Continue** from a non-order sandbox still replays the level

---

## Exact testing steps

1. New Game → starter shop, Ava available, other workers locked.  
2. Hire Ava (300 coins), assign to Oven, confirm she appears by the oven.  
3. Start Mia’s order → win → Ready to Complete → Complete once → coins/XP/rep once.  
4. Confirm order popup shows equipment + worker bonus breakdown.  
5. Upgrade Ava; confirm cost and level cap at 10.  
6. Leave Ava unassigned → bonuses leave reward preview.  
7. Wait in shop / use debug “Fill Passive Storage” → Collect once.  
8. Debug “Simulate 1h Offline” → popup → Collect.  
9. Restart game → Continue loads progress; offline not duplicated.  
10. Match-3, recipes, and equipment upgrades still function.
