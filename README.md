# Sugar Street Tycoon: Match & Build

Portrait **Godot 4.3** / **GDScript** bakery match-3 with a shop management vertical slice.

**Core loop:** Title → Shop Hub → Orders → Match-3 (`main.tscn`) → Win/Lose → Orders / Shop → Complete Order → Rewards → Save → Next Order

Workers / locations / events / ads / IAP / Supabase / offline earnings are **not** part of this phase (Coming Soon / gated).

---

## How to launch

1. Install [Godot 4.3+](https://godotengine.org/download).
2. Import this folder (`project.godot`).
3. Press **F5** — main scene is `res://scenes/main/title_screen.tscn`.
4. Play / Continue → Shop Hub → **Orders** → Start Order → puzzle.

**Viewport:** 405×720 portrait, `canvas_items` + `keep_width` stretch.

---

## Scene flow

```
title_screen.tscn
  → shop_hub.tscn
      → orders_screen.tscn
          → main.tscn  (hosts gameplay.tscn in GameplaySlot)
              → Level Complete / Order Failed popup
              → orders_screen / shop_hub
      → recipe_book.tscn
      → upgrades_screen.tscn
      → inventory_screen.tscn
```

**Autoloads:** `GameState`, `AudioManager`, `SceneRouter`  
**Helpers:** `NavigationManager`, `SaveManager`, `RewardCalculator`, `PlayerProgression`, `ThemeFactory`

**Shared UI:** `scenes/ui/top_resource_bar.tscn`, `scenes/ui/bottom_navigation.tscn`, theme `resources/themes/sugar_street_theme.tres` (palette via `SugarStreetColors` / `ThemeFactory`)

Frontend screens build visible bakery-themed placeholder UI in script (rounded panels, cards, coral/mint/cream). Roots are full-rect Controls; content uses containers + ScrollContainer.

Main scene: `res://scenes/main/title_screen.tscn`

---

## GameState structure

Autoload: `scripts/shop/game_state.gd`

Owns runtime progression (no scene node refs):

| Field | Notes |
|-------|--------|
| `player_level` / `experience` | XP curve below |
| `coins` / `stars` / `reputation` | Player resources |
| `shop_level` / `shop_name` | Shop meta |
| `active_order_id` | Selected / in-progress order |
| `order_statuses` / `order_reward_claimed` | Per-order runtime |
| `completed_order_ids` / `visible_order_ids` | Board |
| `best_level_stars` / `best_level_scores` | Never decrease |
| `granted_level_stars` | Permanent stars already awarded per level |
| `unlocked_recipes` / `equipment_levels` / `ingredients` | Progression |
| `current_session_result` | Last puzzle result |
| `settings` | Music/SFX/vibration/reduce motion |
| Save version | `SaveData.SAVE_VERSION` (**3**) |

Signals include: `coins_changed`, `stars_changed`, `reputation_changed`, `experience_changed`, `player_level_changed`, `selected_order_changed`, `order_status_changed`, `save_loaded`, `save_completed`.

---

## Save-data structure

Local JSON: `user://sugar_street_save.json` via `SaveManager`.

Saved fields: version, timestamp, player stats, shop, recipes, equipment, ingredients, order statuses, reward-claimed flags, completed IDs, best scores/stars, granted permanent stars, settings, plus legacy worker/passive fields for migration.

- Load on boot; defaults when missing
- Corrupted files recover from `.bak` or defaults (no crash)
- Missing fields filled safely
- Migration: v1/v2 → v3 (Mia order catalog cleanup)

---

## Customer-order data structure

`OrderTemplate` (`scripts/data/order_template.gd`) + catalog (`scripts/shop/content_catalog.gd`):

- Order ID, customer name/message, recipe ID/name
- Target piece ID + amount (and `additional_objectives` for multi-target)
- Move limit, level ID, difficulty
- Coin / XP / reputation / ingredient rewards
- Runtime: status, best score/stars, completed, reward-claimed

**Statuses:** Available · Selected · In Progress (`LEVEL_IN_PROGRESS`) · Ready to Complete · Completed · Failed · Locked

### Starter orders

| ID | Customer | Recipe | Objective | Moves | Coins/XP/Rep | Difficulty |
|----|----------|--------|-----------|-------|--------------|------------|
| `order_mia_001` | Mia | Chocolate Strawberries | 20 Strawberry | 20 | 150/25/5 | Easy |
| `order_jordan_002` | Jordan | Classic Cupcakes | 22 Cupcake | 22 | 200/35/7 | Easy |
| `order_taylor_003` | Taylor | Chocolate Strawberries | 25 Chocolate | 20 | 275/45/10 | Medium |
| `order_noah_004` | Noah | Classic Cupcakes | 18 Cupcake + 12 Candy | 24 | 325/55/12 | Medium |
| `order_morgan_005` | Morgan | Candied Grapes | 35 Candy | 18 | 450/75/18 | Hard (locked) |

Winning marks **Ready to Complete**. Rewards grant **once** via `GameState.complete_order(order_id)`.

---

## Level configuration structure

`LevelConfig` (`scripts/data/level_config.gd`):

- `level_id`, board width/height, `move_limit`
- `objectives` (one or many `ObjectiveData`)
- Optional score thresholds (future), `piece_types`, difficulty via order
- Order start clones the template and applies order move/objective overrides

Board templates: `level_01` … `level_05` in `ContentCatalog._build_levels()`.

---

## Reward calculation order

`RewardCalculator.compute_order_rewards`:

1. Base reward (order template)
2. Equipment-specific bonuses (Oven coins / Mixer XP / Display reputation: **+2% per level above 1**)
3. Checkout Counter global bonus (**+1% per level above 1** on all)
4. Worker bonus placeholder (0 this phase)
5. Event bonus placeholder (0)
6. Final rounded integers

---

## Star-rating rules

- **1★** — level completed  
- **2★** — ≥ 25% starting moves remaining  
- **3★** — ≥ 50% starting moves remaining  

Best rating per level never decreases. Permanent player stars = difference between new best and already granted (`granted_level_stars`). Prevents farming the same level for unlimited stars.

---

## Player-level formula

XP to next level: `100 + ((current_level - 1) × 75)`

| From → To | XP |
|-----------|-----|
| 1 → 2 | 100 |
| 2 → 3 | 175 |
| 3 → 4 | 250 |

Level-up coin reward: `100 × new_player_level`. Excess XP carries forward; multiple level-ups from one grant are supported.

---

## Recipe-unlock rules

| Recipe | Default | Requirements | Cost |
|--------|---------|--------------|------|
| Chocolate Strawberries | Unlocked | — | — |
| Classic Cupcakes | Unlocked | — | — |
| Candied Grapes | Locked | Player Lv 2 + 3★ | 300 |
| Cookies and Cream Cupcakes | Locked | Player Lv 3 + 6★ | 500 |

Unlock validates, deducts coins, saves immediately, blocks duplicates, and unlocks dependent orders (Morgan).

---

## Equipment-upgrade rules

Oven / Mixer / Display Case / Checkout Counter — levels **1–3** this phase.

| Upgrade | Cost |
|---------|------|
| 1 → 2 | 500 |
| 2 → 3 | 1,000 |

Benefits: Oven +2% order coins / Mixer +2% XP / Display +2% reputation / Checkout +1% all — per level above 1.

---

## Inventory behavior

Ingredients displayed with quantity and category placeholders. Order rewards add stock. Ingredients are **not consumed** yet and cannot go negative.

Starter: Chocolate/Strawberries/Flour/Sugar **5**, Cream/Packaging **3**, others **0**.

---

## Debug controls

Dev-only (`OS.is_debug_build()` + `GameState.DEBUG_TOOLS_ENABLED`): Shop Debug panel.

Add coins/stars/XP/rep · complete/win/lose level · set moves · unlock recipes · max equipment (Lv3) · reset orders · print GameState/save · corrupt/reset save.

---

## How to add content

### New order
1. Add `_add_order(...)` in `ContentCatalog._build_orders()`
2. Append ID to `order_sequence`
3. Point `level_id` at a board template; set targets / `additional_objectives` / rewards

### New level
1. Add `_make_level(...)` in `_build_levels()` (and optional `.tres` under `resources/levels/`)
2. Reference from an order’s `level_id`

### New recipe
1. `_add_recipe(...)` in `_build_recipes()`
2. Wire unlock requirements; gated orders use `requires_recipe_unlocked`

### New equipment
1. `_add_equipment(...)` in `_build_equipment()`
2. Extend `RewardCalculator` if a new bonus type is needed

---

## Final artwork integration

Placeholder hooks:

| Goal | Location |
|------|----------|
| Title / shop backgrounds | `assets/backgrounds/` + load in title/shop scripts |
| Logo | `assets/ui/sugar_street_logo.png` |
| Customer portraits | `OrderTemplate.customer_avatar` |
| Piece art | `assets/placeholders/` / `PieceType` textures |
| Recipe icons | Recipe book ColorRect → TextureRect |

Do not embed screenshots as interactive screens.

---

## Headless tests

```bash
GODOT=/tmp/Godot_v4.3-stable_linux.x86_64   # or your godot binary
$GODOT --headless --path . -s res://scripts/tools/headless_f5_boot_test.gd
$GODOT --headless --path . -s res://scripts/tools/headless_nav_boot_test.gd
$GODOT --headless --path . -s res://scripts/tools/headless_shop_loop_test.gd
$GODOT --headless --path . -s res://scripts/tools/headless_smoke_test.gd
$GODOT --headless --path . -s res://scripts/tools/headless_swap_test.gd
$GODOT --headless --path . -s res://scripts/tools/headless_invalid_swap_test.gd
```

---

## Known limitations

- Final Figma bitmaps not imported (styled placeholders).
- Match-3 boosters are visual-only (disabled).
- Workers / Locations / Events / Decor / Sign-in gated as Coming Soon.
- Worker/passive backend code may exist from earlier branches but is not exposed in this UI phase.
- Ingredients are not consumed when fulfilling recipes yet.
