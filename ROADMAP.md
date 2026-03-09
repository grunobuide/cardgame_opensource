# Project Roadmap

This roadmap is split into product milestones (`M1..M3`) and dedicated engineering tracks for architecture/testing.

## M1 - Playable Run Loop (Complete)

Goal: a complete single-run core loop with clear progression and failure states.

- [x] Core hand play/discard flow (1..5 cards, capped selection)
- [x] Joker modifier application during scoring
- [x] Tweened action queue for play/discard/deal transitions
- [x] In-run HUD panels (stats, preview, pressure bar, jokers)
- [x] Blind progression system per ante (`Small -> Big -> Boss`)
- [x] Run result screen (win/lose summary with per-round stats)
- [x] Seeded run support (enter/display seed)
- [x] Balance pass for blind multipliers and hand/discard counts

## M2 - Shop + Economy

Goal: meta decisions between blinds and an economy that shapes deck growth.

- [x] Currency and payout rules per blind clear
- [x] Shop scene between blinds
- [x] Buy/sell/reroll loop for jokers/cards
- [x] Deck editing (remove/upgrade/duplicate cards)
- [x] Persistent per-run inventory model
- [x] Shop UI polish + tooltips for expected value

## M3 - Content + Progression

Goal: long-term replayability and unlock depth.

- [x] Expanded joker pool with trigger categories (13 jokers across 5 categories)
- [x] Consumables/events (8 planet cards + 4 tarot cards)
- [x] Blind variants and boss modifiers (6 boss blinds)
- [x] Card enhancements (foil, holo, polychrome)
- [x] Hand level upgrade system via planet consumables
- [ ] Unlock tree and achievement conditions
- [ ] Saved profile progression and unlock persistence
- [ ] Run history browser

## MA - Architecture Milestones

Goal: keep code maintainable as systems scale.

- [x] Split runtime into `scene/`, `ui/`, `anim/`, `src/`
- [x] Split `scene/game_scene.lua` into focused modules:
  - `scene/input.lua`
  - `scene/actions.lua`
  - `scene/card_visuals.lua`
- [x] Introduce a configuration layer (`config/`) for tunables
- [x] Introduce lightweight event bus for scene/UI decoupling
- [x] Save/load module with schema versioning

## MT - Testing Milestones

Goal: high-confidence gameplay changes with fast regression feedback.

- [x] `busted` unit/state suite for core logic
- [x] CI on push/PR running smoke + busted tests
- [x] Deterministic simulation tests for multi-turn scenarios
- [x] Golden tests for projection outputs (joker combinations)
- [x] Regression tests for blind progression and economy phases
- [x] Lua version matrix in CI (`5.1`, `5.4`)

## MU1 - Visual Foundation

Goal: establish a cohesive art direction and readability baseline.

- [x] Define visual theme tokens (color, spacing, radius, shadows, typography scale)
- [x] Replace placeholder panel look with polished card-table aesthetic
- [x] Improve hierarchy of primary/secondary/tertiary actions
- [x] Standardize iconography and labels for controls
- [x] Improve contrast/accessibility for text, highlights, warnings
- [x] Add responsive layout rules for lower resolutions

## MU1.5 - Battle Layout Direction

Goal: establish a clear 8-bit battle screen hierarchy before deeper style polish.

What this implies for our next implementation pass:

- [x] Adopt a true 3-column battle layout
  - Left: run status + upgrades
  - Center: hand/combat lane (primary focus)
  - Right: shop/jokers/details
- [x] Pixel component kit
  - Reusable `PixelPanel`, `PixelButton`, `PixelBadge`, `PixelBar`, `PixelSlot`
  - Hard 2px borders, 2px shadows, no soft gradients/glow
- [x] Icon-first HUD
  - Every stat/action gets an icon + short token label
  - Move from text-heavy rows to compact status cards
- [x] Combat lane clarity
  - Center stack: round marker, enemies, hand, action buttons, boss bar
  - Bigger hand cards, clearer selected state
- [x] Typography direction
  - Pixel font stack for titles + labels + values
  - Strict size scale (`tiny/small/medium/title`) and spacing grid

## MU2 - Core Interaction Polish

Goal: make moment-to-moment play feel crisp and intentional.

- [x] Refine hand fan geometry and overlap behavior
- [x] Add hover intent states for cards/buttons/jokers
- [x] Improve selected-card state (lift, glow, border treatment)
- [x] Add contextual tooltips for jokers and controls
- [x] Add keyboard shortcut hints directly in UI
- [x] Add input feedback for invalid actions (not enough cards, no discards)

## MU3 - Gameplay Feedback System

Goal: improve clarity of scoring and progression feedback.

- [x] Add score breakdown strip (base -> joker modifiers -> total)
- [x] Add animated chip/mult deltas with clear sequencing
- [x] Improve blind pressure bar animation and threshold signaling
- [x] Add round transition banners (Blind Cleared, Next Blind, Ante Up)
- [x] Add richer run state messages with severity levels (info/warn/fail)
- [x] Add subtle screen-space effects for major events (boss clear, bust)

## MU4 - Motion & Animation Quality

Goal: consistent, non-jittery motion language across the game.

- [x] Define animation timing/easing standards by interaction type
- [x] Add staggered deal/discard/play choreography
- [x] Add enter/exit transitions for panels and overlays
- [x] Add reduced-motion mode toggle
- [x] Prevent flicker on reorder/sort/deal by stabilizing visual identity keys
- [x] Profile and cap animation cost for smooth frame pacing

## MU5 - Information Architecture & HUD

Goal: make strategic info scannable at a glance.

- [x] Redesign top HUD into compact, glanceable blocks
- [x] Improve preview panel with clearer formula formatting
- [x] Add blind context panel (type, target, special rule)
- [x] Group controls by intent (play/discard/run/debug)
- [x] Add persistent run summary side panel (ante, blind, jokers, economy when added)
- [x] Add visual priority system for urgent states (low hands, near bust)

## MU6 - Run End & Meta UX

Goal: make outcomes feel rewarding and understandable.

- [x] Add run end screen (win/loss, ante reached, key stats)
- [x] Add post-run recap (best hand, MVP joker, efficiency metrics)
- [x] Add restart/continue shortcuts and focus flow ([R] new run, [S] seed entry)
- [x] Add seed display/copy UX
- [ ] Add onboarding tips for first-time users
- [x] Add settings panel (theme, motion, keybind hints)

## MT-UX - UX Testing & Validation

Goal: keep UI quality measurable, not subjective.

- [ ] Create UX acceptance checklist per milestone
- [ ] Add screenshot baselines for key states (hand, blind clear, game over)
- [ ] Add usability test script for 10-minute first-run session
- [ ] Define quantitative goals (time-to-first-play, misclick rate)
- [ ] Add accessibility checks (contrast + keyboard-only flow)
- [ ] Run periodic polish passes tied to milestone exits

## Next Priority Slice (Current)

1. Roadmap cleanup pass: mark `M1` complete, replace stale next-priority notes with `MU2 -> MU3 -> M3`.
2. `MU2` sprint: finalize hover/selection states, contextual joker/control tooltips, invalid-action feedback consistency, shortcut hint polish.
3. `MU3` sprint: add score breakdown strip (`base -> jokers -> total`) and clearer event messaging banners.
4. `MT-UX` baseline: screenshot baselines for key states and a lightweight UX acceptance checklist.
5. `M3` scaffolding: implement joker trigger categories first (content pipeline), then blind modifiers, then unlock persistence.

### Acceptance Criteria for This Slice

- [ ] Roadmap and board status are aligned (`M1/M2` complete, `MU2` active).
- [ ] `MU2` deliverables are testable in one run without debug tools.
- [ ] `MU3` score/explanation UI is visible after every play action.
- [ ] Screenshot baselines exist for hand, blind clear, shop, game over.
- [ ] `M3` content pipeline supports adding new joker trigger categories without touching core scoring flow.
