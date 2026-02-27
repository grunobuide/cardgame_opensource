# Project Roadmap

This roadmap is split into product milestones (`M1..M3`) and dedicated engineering tracks for architecture/testing.

## M1 - Playable Run Loop (In Progress)

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

- [ ] Currency and payout rules per blind clear
- [ ] Shop scene between blinds
- [ ] Buy/sell/reroll loop for jokers/cards
- [ ] Deck editing (remove/upgrade/duplicate cards)
- [ ] Persistent per-run inventory model
- [ ] Shop UI polish + tooltips for expected value

## M3 - Content + Progression

Goal: long-term replayability and unlock depth.

- [ ] Expanded joker pool with trigger categories
- [ ] Consumables/events (tarot-like one-shot effects)
- [ ] Blind variants and boss modifiers
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
- [ ] Introduce a configuration layer (`config/`) for tunables
- [ ] Introduce lightweight event bus for scene/UI decoupling
- [ ] Save/load module with schema versioning

## MT - Testing Milestones

Goal: high-confidence gameplay changes with fast regression feedback.

- [x] `busted` unit/state suite for core logic
- [x] CI on push/PR running smoke + busted tests
- [x] Deterministic simulation tests for multi-turn scenarios
- [ ] Golden tests for projection outputs (joker combinations)
- [ ] Regression tests for blind progression and economy phases
- [ ] Lua version matrix in CI (`5.1`, `5.4`)

## MU1 - Visual Foundation

Goal: establish a cohesive art direction and readability baseline.

- [x] Define visual theme tokens (color, spacing, radius, shadows, typography scale)
- [x] Replace placeholder panel look with polished card-table aesthetic
- [ ] Improve hierarchy of primary/secondary/tertiary actions
- [ ] Standardize iconography and labels for controls
- [ ] Improve contrast/accessibility for text, highlights, warnings
- [ ] Add responsive layout rules for lower resolutions

## MU2 - Core Interaction Polish

Goal: make moment-to-moment play feel crisp and intentional.

- [ ] Refine hand fan geometry and overlap behavior
- [ ] Add hover intent states for cards/buttons/jokers
- [ ] Improve selected-card state (lift, glow, border treatment)
- [ ] Add contextual tooltips for jokers and controls
- [ ] Add keyboard shortcut hints directly in UI
- [ ] Add input feedback for invalid actions (not enough cards, no discards)

## MU3 - Gameplay Feedback System

Goal: improve clarity of scoring and progression feedback.

- [ ] Add score breakdown strip (base -> joker modifiers -> total)
- [ ] Add animated chip/mult deltas with clear sequencing
- [ ] Improve blind pressure bar animation and threshold signaling
- [ ] Add round transition banners (Blind Cleared, Next Blind, Ante Up)
- [ ] Add richer run state messages with severity levels (info/warn/fail)
- [ ] Add subtle screen-space effects for major events (boss clear, bust)

## MU4 - Motion & Animation Quality

Goal: consistent, non-jittery motion language across the game.

- [ ] Define animation timing/easing standards by interaction type
- [ ] Add staggered deal/discard/play choreography
- [ ] Add enter/exit transitions for panels and overlays
- [ ] Add reduced-motion mode toggle
- [ ] Prevent flicker on reorder/sort/deal by stabilizing visual identity keys
- [ ] Profile and cap animation cost for smooth frame pacing

## MU5 - Information Architecture & HUD

Goal: make strategic info scannable at a glance.

- [ ] Redesign top HUD into compact, glanceable blocks
- [ ] Improve preview panel with clearer formula formatting
- [ ] Add blind context panel (type, target, special rule)
- [ ] Group controls by intent (play/discard/run/debug)
- [ ] Add persistent run summary side panel (ante, blind, jokers, economy when added)
- [ ] Add visual priority system for urgent states (low hands, near bust)

## MU6 - Run End & Meta UX

Goal: make outcomes feel rewarding and understandable.

- [ ] Add run end screen (win/loss, ante reached, key stats)
- [ ] Add post-run recap (best hand, MVP joker, efficiency metrics)
- [ ] Add restart/continue shortcuts and focus flow
- [ ] Add seed display/copy UX
- [ ] Add onboarding tips for first-time users
- [ ] Add settings panel (theme, motion, keybind hints)

## MT-UX - UX Testing & Validation

Goal: keep UI quality measurable, not subjective.

- [ ] Create UX acceptance checklist per milestone
- [ ] Add screenshot baselines for key states (hand, blind clear, game over)
- [ ] Add usability test script for 10-minute first-run session
- [ ] Define quantitative goals (time-to-first-play, misclick rate)
- [ ] Add accessibility checks (contrast + keyboard-only flow)
- [ ] Run periodic polish passes tied to milestone exits

## Next Priority Slice

1. Finish M1 with a balance pass for blind multipliers and hand/discard counts.
2. Begin M2 with minimal economy (`money + payouts + single reroll shop`).
