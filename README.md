# Open Balatro Prototype (Lua)

This project now uses Lua only:

- `main.lua`: thin LÖVE bootstrap
- `scene/game_scene.lua`: runtime scene orchestration/input/action pipeline
- `anim/tween_queue.lua`: tween + queued transition system
- `ui/layout.lua`, `ui/palette.lua`, `ui/render.lua`: UI layout, theming, and drawing
- `src/game_logic.lua`: pure game rules/state module

Roadmap:

- See `ROADMAP.md` for product (`M1..M3`) and engineering (`MA`, `MT`) milestones.

## Prerequisites

- [LÖVE 11.x](https://love2d.org/)
- Optional: Lua interpreter (for command-line smoke tests)
- Optional: [LuaRocks](https://luarocks.org/) + `busted` (for full automated tests)

## Run

```bash
love .
```

## Controls

- Mouse: click cards to select/deselect, click buttons to act
- `1..8`: quick-select card index
- `Space`: play selected cards
- `D`: discard selected cards
- `R`: new run
- `S`: sort hand by suit
- `N`: sort hand by rank
- `T`: toggle dark/light sprite set
- `Enter` / `Space` on result screen: start new run

## How To Test

### 1. Logic smoke test (fast, no game window)

```bash
lua scripts/smoke_test.lua
```

Expected output: `All smoke tests passed.`

### 2. Full unit/state tests with busted

Install busted once:

```bash
luarocks install busted
```

Run all specs:

```bash
busted
```

Run only game-logic specs:

```bash
busted spec/game_logic_spec.lua
```

### 3. Manual gameplay verification in LÖVE

Run `love .` and verify:

1. A new run starts with `Ante 1`, `Hands 4`, `Discards 3`, and 8 cards in hand.
2. Selecting 1 to 5 cards allows play; selecting 0 cards shows a validation message.
3. Discarding selected cards decreases discards and refills hand back to 8.
4. Adding jokers changes projected and actual score behavior when hands are played.
5. `T` toggles between light and dark card sprite sets.
6. Clearing a target advances ante and resets hands/discards.
7. On run end, a result overlay appears with per-round stats and totals.

## Notes

- The old JavaScript/HTML/CSS and Node test stack were removed.
- Card art is loaded from `Cards/Cards_Dark` and `Cards/Cards`.
- `main.lua` now includes queued card transitions with tweened play/discard/deal animations.
