# Open Balatro Prototype (Lua)

This project now uses Lua only:

- `main.lua`: minimal playable LÖVE loop
- `src/game_logic.lua`: pure game rules/state module

## Prerequisites

- [LÖVE 11.x](https://love2d.org/)
- Optional: Lua interpreter (for command-line smoke tests)

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
- `T`: toggle dark/light sprite set

## How To Test

### 1. Logic smoke test (fast, no game window)

```bash
lua scripts/smoke_test.lua
```

Expected output: `All smoke tests passed.`

### 2. Manual gameplay verification in LÖVE

Run `love .` and verify:

1. A new run starts with `Ante 1`, `Hands 4`, `Discards 3`, and 8 cards in hand.
2. Selecting 1 to 5 cards allows play; selecting 0 cards shows a validation message.
3. Discarding selected cards decreases discards and refills hand back to 8.
4. Adding jokers changes projected and actual score behavior when hands are played.
5. `T` toggles between light and dark card sprite sets.
6. Clearing a target advances ante and resets hands/discards.

## Notes

- The old JavaScript/HTML/CSS and Node test stack were removed.
- Card art is loaded from `Cards/Cards_Dark` and `Cards/Cards`.
