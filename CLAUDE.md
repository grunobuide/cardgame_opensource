# CLAUDE.md

## Project Overview

Open-source roguelike card game prototype inspired by Balatro. Single-run gameplay loop: card selection, hand scoring, joker modifiers, blind progression, and a shop/economy system. Written in Lua with the LÖVE 2D framework.

## Tech Stack

- **Language:** Lua 5.1+
- **Framework:** LÖVE 11.x (2D game engine)
- **Testing:** Busted (BDD/TDD), LuaRocks
- **CI:** GitHub Actions (`.github/workflows/lua-tests.yml`)

## Running the Game & Tests

```bash
# Launch game window
love .

# Fast headless logic validation (no window required)
lua scripts/smoke_test.lua

# Full test suite
busted

# Individual suites
busted spec/game_logic_spec.lua
busted spec/simulation_spec.lua
busted spec/projection_golden_spec.lua
busted spec/progression_economy_regression_spec.lua
```

CI runs both `smoke_test.lua` and `busted` on every push/PR.

## Directory Structure

```
main.lua              # LÖVE entry point; bootstraps GameScene
config/               # Centralized tunables and config loader
  tunables.lua        # All game constants (ante, hand size, pricing, etc.)
  init.lua            # Config loader with deep merge support
src/                  # Core game logic (side-effect free, fully testable)
  game_logic.lua      # Hand detection, scoring engine, joker registry (1457 lines)
  save_load.lua       # Run snapshot persistence, schema versioning v1
  event_bus.lua       # Lightweight pub-sub for component decoupling
scene/                # Runtime orchestration
  game_scene.lua      # Main state machine (448 lines)
  input.lua           # Keyboard + mouse input handling
  actions.lua         # Play, discard, shop action handlers
  card_visuals.lua    # Card rendering + animation state
ui/                   # All rendering
  render.lua          # Complete UI rendering pipeline (1264 lines)
  layout.lua          # Responsive 3-column layout engine
  pixel_kit.lua       # Reusable pixel-art UI components
anim/
  tween_queue.lua     # Tweening with easing presets + frame budget
spec/                 # Test suite
  fixtures/           # Golden snapshot data
assets/               # PNG assets (buttons, logos, joker icons)
Cards/                # Light-theme card sprite sheets
Cards_Dark/           # Dark-theme card sprite sheets
```

## Architecture & Conventions

### Module System
Every file returns a plain Lua table (module). Use `require()` with dot-separated paths.

### Key Patterns
- **Pure game logic:** `src/game_logic.lua` has no I/O or side effects — safe to `require` in tests without LÖVE.
- **Scene state machine:** `GameScene` owns all subsystems; coordinates via event bus.
- **Event bus:** Pub-sub (`event_bus.lua`) decouples rendering from logic. Prefer events over direct calls across module boundaries.
- **Joker registry:** `register_joker(def)` in `game_logic.lua` — add new jokers here.
- **Tweening:** All animations go through `tween_queue.lua`. Respects reduced-motion toggle.
- **Visual identity keys:** Cards carry a stable `visual_id` separate from hand position to prevent animation flicker on reorder.
- **Seeded RNG:** Custom LCG seeded RNG (`game_logic.lua`) for deterministic tests and replay.

### OOP Style
Classes use `__index` metatables:
```lua
local MyClass = {}
MyClass.__index = MyClass
function MyClass.new(args) return setmetatable({}, MyClass) end
function MyClass:method() end
```

### Configuration
All tunables live in `config/tunables.lua`. Never hardcode game constants inline; always reference config. Override via deep merge in `config/init.lua`.

Key values:
- Hand size: 8 cards, max select: 5
- Joker slots: max 5
- Ante targets: `{200, 400, 700}`
- Blind multipliers: small 1.0×, big 1.65×, boss 2.35×
- Shop prices: common 6, uncommon 8, rare 11, cards 4+
- Sell ratio: 50%

### Layout
3-column battle layout: left (run status), center (combat + hand), right (joker dock). Target viewport: 1366×768. `ui/layout.lua` computes column bounds dynamically.

## Testing Strategy

- **Unit tests** (`game_logic_spec.lua`): hand detection, scoring, joker effects.
- **Integration/simulation** (`simulation_spec.lua`): seeded multi-turn runs for deterministic outcome verification.
- **Golden snapshots** (`projection_golden_spec.lua`): joker combination scoring locked to known values in `spec/fixtures/projection_goldens.lua`. Update goldens intentionally when scoring changes.
- **Regression** (`progression_economy_regression_spec.lua`): blind progression, shop economy, balance checks.
- **Save/load** (`save_load_spec.lua`): snapshot round-trip and schema validation.

When adding new game logic, add corresponding specs. Keep `src/game_logic.lua` free of LÖVE dependencies so tests run headlessly.

## Development Status

Completed: M1 (run loop), M2 (shop/economy), MA (architecture), MU1–MU5 (visual polish).

Active/planned: M3 (content expansion — jokers, consumables, blind variants, unlocks), MU6 (run-end UX, settings, onboarding, run history), MT-UX (screenshot baselines, accessibility).

See `ROADMAP.md` for full milestone breakdown.

## Debugging

Press **F1** in-game to toggle the debug overlay.

Save files use LÖVE's save directory (`love.filesystem.getSaveDirectory()`), schema version 1.
