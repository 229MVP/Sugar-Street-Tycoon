# Sugar Street Tycoon: Match & Build

Portrait **Godot 4.3** / **GDScript** bakery match-3 with a Figma-inspired cozy UI.

**Core loop:** Title → Shop Hub → Orders → Match-3 (`main.tscn`) → Level Complete → Orders / Shop → Complete Order

Workers / locations / events / ads / IAP / Supabase are **not** part of the active UI (Coming Soon / gated).

---

## How to launch

1. Install [Godot 4.3+](https://godotengine.org/download).
2. Import this folder (`project.godot`).
3. Press **F5** — main scene is `res://scenes/main/title_screen.tscn`.
4. Play / Continue → Shop Hub → **Orders** → Start Order → puzzle.

**Viewport:** 405×720 portrait, `canvas_items` + `keep_width` stretch (scales to common phones).

---

## Scene flow

```
title_screen.tscn
  → shop_hub.tscn
      → orders_screen.tscn
          → main.tscn  (hosts gameplay.tscn in GameplaySlot)
              → Level Complete popup
              → orders_screen / shop_hub
      → recipe_book / upgrades / inventory
```

Autoloads: `GameState`, `AudioManager`, `SceneRouter`  
Helpers: `NavigationManager`, `ThemeFactory`, `SugarStreetColors`

---

## UI structure

| Screen | Path |
|--------|------|
| Title | `scenes/main/title_screen.tscn` |
| Shop Hub | `scenes/shop/shop_hub.tscn` |
| Orders | `scenes/orders/orders_screen.tscn` |
| Puzzle host | `scenes/main/main.tscn` |
| Level Complete | `scenes/popups/level_complete_popup.tscn` |
| Theme | `resources/themes/sugar_street_theme.tres` + `scripts/theme/` |

### Shared components

- `scenes/ui/top_resource_bar.tscn` — level / energy / coins / stars / menu
- `scenes/ui/bottom_navigation.tscn` — Shop / Inventory / Customers / Events
- `scripts/ui/components/customer_order_card.gd`
- `scripts/ui/components/notification_badge_view.gd`
- Theme styles via `ThemeFactory` (mint primary, coral secondary, cream cards)

---

## Assets

### Present

- `assets/placeholders/*.png` — dessert piece art (chocolate, strawberry, cupcake, cookie, candy, donut)

### Missing (use placeholders)

- `assets/backgrounds/title_background.png`
- `assets/backgrounds/shop_background.png`
- `assets/ui/sugar_street_logo.png`
- `assets/characters/` portraits
- `assets/icons/`
- Final `assets/pieces/` overrides

Drop Figma exports into those folders; screens already prefer them when present and fall back to ColorRect / ThemeFactory styling.

### How to replace art

| Goal | Do this |
|------|---------|
| Title background | Add `assets/backgrounds/title_background.png` and load it in `title_screen.gd` |
| Logo | Add `assets/ui/sugar_street_logo.png` and swap the Label brand block for a `TextureRect` |
| Customer portrait | Add `assets/characters/<name>.png` and set `OrderTemplate.customer_avatar` |
| Piece art | Replace files under `assets/placeholders/` (or point PieceType textures at `assets/pieces/`) |
| Add an order | Extend `_build_orders()` in `scripts/shop/content_catalog.gd` and append to `order_sequence` |

---

## Starter orders

1. **Lily** — Chocolate Strawberries · 20 strawberries · 20 moves · 320 / 25 / 5  
2. **Noah** — Chocolate Cupcakes · 25 chocolate · 22 moves · 380 / 35 / 8  
3. **Mrs. Maple** — Classic Pastries · 30 cookies · 20 moves · 350 / 45 / 10  

Winning marks **Ready to Complete**. Rewards grant once via **Complete Order**.

---

## Save

Local JSON: `user://sugar_street_save.json`  
Fields include level, XP, coins, stars, reputation, order statuses, completed IDs, best scores/stars, settings, version. Single save system via `SaveManager` + `GameState`.

---

## Headless tests

```bash
godot --headless --path . -s res://scripts/tools/headless_f5_boot_test.gd
godot --headless --path . -s res://scripts/tools/headless_nav_boot_test.gd
godot --headless --path . -s res://scripts/tools/headless_shop_loop_test.gd
godot --headless --path . -s res://scripts/tools/headless_smoke_test.gd
```

---

## Current limitations

- Final Figma bitmaps not imported yet (styled placeholders).
- Boosters on the match-3 HUD are visual-only (disabled).
- Workers / Locations / Events / Decor / Sign-in / Trophies / Favorites show Coming Soon.
- Worker/passive backend code may still exist from earlier branches but is gated in the new UI.
