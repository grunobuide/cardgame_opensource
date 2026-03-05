# Balatrin Feature Roadmap — From Prototype to Polished Game

## Context

Balatrin is a Balatro-inspired roguelike card game (Lua/LÖVE 2D) with a complete core loop: play poker hands, score via chips×mult, 13 jokers, 3-ante blind progression, full shop/economy, seeded RNG, save/load, and an "alien vaporwave 8bit" visual identity. Architecture is clean (pure logic in `src/game_logic.lua`, event bus, tween queue, asset loader with fallbacks).

**Problem:** The game is functionally solid but feels flat — scoring is silent, strategic depth is shallow (no consumables, no boss mechanics, no card enhancements), and every run starts identically. This roadmap transforms Balatrin from "working prototype" into a replayable, satisfying card game.

---

## Phase 1: Game Feel (1–2 weeks)

*Make every interaction produce satisfying feedback. Zero new strategy — pure juice.*

### 1.1 Floating Score Popups — `M`
Rising "+N" text when a hand scores. Chips in cyan, mult in magenta. Fades upward over 1.2s. Header score counter "ticks up" instead of snapping.

- **New:** `ui/score_fx.lua` — popup manager (text, position, alpha, lifetime)
- **Modify:** `ui/render.lua` — draw popups after hand panel; rolling score in header
- **Modify:** `scene/game_scene.lua` — own ScoreFx, add `display_score` approach in `update()`
- **Preset:** `score_popup = { duration = 1.2, ease = "out_quad" }`
- **Test:** `spec/score_fx_spec.lua` — creation, aging, removal, reduced-motion skip

### 1.2 Joker Activation Flash — `S`
When a joker triggers during scoring, its dock slot pulses bright for 0.35s. Uses existing `joker_trigger_flash` asset entry.

- **Modify:** `scene/game_scene.lua` — `joker_flash_state[slot] = timer`, decrement in `update()`
- **Modify:** `ui/render.lua` — glow border in `draw_joker_dock()` when timer > 0

### 1.3 Card Flip Animation — `M`
Cards dealt face-down, flip to face-up via scaleX trick (−1 → 0 → +1 over 0.28s with stagger).

- **Modify:** `scene/card_visuals.lua` — add `flip` field, flip tween in `rebuild_visuals("deal")`
- **Modify:** `ui/render.lua` — compute scaleX from flip, render card back when flip < 0.5
- **Preset:** `card_flip = { duration = 0.28, ease = "in_out_quad" }`

### 1.4 Screen Phase Transitions — `S`
Full-screen flash/wipe on blind clear, shop enter, game over. Cyan flash for clears, magenta for bust, green for victory. 0.4s pulse.

- **Modify:** `scene/game_scene.lua` — `phase_transition` state, driven in `update()`
- **Modify:** `ui/render.lua` — `draw_phase_transition()` as late overlay

### 1.5 Particle System — `M`
Lightweight pixel particle emitter: cyan sparks for chips, magenta for mult. Drift upward, fade, die. Cap 128 particles.

- **New:** `anim/particles.lua` — `ParticleEmitter` class (spawn, update, draw, cap)
- **Modify:** `scene/game_scene.lua` — own emitter, update/draw in pipeline
- **Depends on:** 1.1 (spawn from popup location)
- **Test:** `spec/particles_spec.lua` — spawn, aging, removal, cap enforcement

---

## Phase 2: Strategic Depth (2–3 weeks)

*Transform "play poker hands to beat a number" into a game of meaningful decisions.*

### 2.1 Consumable System (Tarot + Planet Cards) — `L`
One-shot items in 2 dedicated slots. Registry pattern mirroring jokers.

**Logic (`src/game_logic.lua`):**
- `M.CONSUMABLES = {}`, `M.register_consumable(key, def)` with `apply(state)` callback
- `state.consumables = {}` (max 2), `state.hand_levels = {}` (hand type → level)
- `M.use_consumable(state, slot)` — calls apply, removes from slot
- `calculate_projection` reads `hand_levels[hand_type.id]` → +10 chips/+1 mult per level

**Planet cards (8):** MERCURY (Pair+1), VENUS (3Kind+1), EARTH (FullHouse+1), MARS (Flush+1), JUPITER (Straight+1), SATURN (2Pair+1), NEPTUNE (StraightFlush+1), PLUTO (HighCard+1)

**Tarot cards (4 initial):** THE_FOOL (copy last hand type as consumable), HIGH_PRIESTESS (draw +2 cards this blind), THE_HERMIT (double money, max +20), THE_WHEEL (1-in-4 Foil on random card — links to 2.3)

**Shop:** Add `consumable_offer_weight: 20` to tunables (joker→50, card→30). Extend `roll_shop_offers` and `shop_buy_offer`.

**UI:** Consumable slots in right panel, `U`/`I` keys to use, `draw_consumables()` in render.

**Files:** `game_logic.lua`, `tunables.lua`, `save_load.lua` (schema v2), `actions.lua`, `input.lua`, `layout.lua`, `render.lua`
**Tests:** `spec/consumable_spec.lua`, update `game_logic_spec`, `save_load_spec`, projection goldens

### 2.2 Boss Blind Mechanics — `M`
Boss blinds get unique debuffs instead of just higher multipliers. Registry pattern.

- `M.BOSS_BLINDS = {}`, `M.register_boss_blind(key, def)` with hooks: `on_start(state)`, `on_play(state, cards)`, `on_score(state, projection)`
- **6 initial bosses:**
  - THE_HOOK — Discards 2 random cards at blind start
  - THE_WALL — 2× the normal target score
  - THE_FLINT — Base chips and mult halved
  - THE_MARK — Face cards drawn face-down (hidden rank)
  - THE_PSYCHIC — Must play exactly 5 cards
  - THE_NEEDLE — Only 1 hand allowed
- Roll boss from pool at ante start using seeded RNG. Store in `state.boss_blind_key`.
- Show boss name + description in feedback panel.

**Files:** `game_logic.lua`, `tunables.lua`, `save_load.lua`, `render.lua`
**Tests:** `spec/boss_blind_spec.lua` — each mechanic individually + integration

### 2.3 Card Enhancements (Foil/Holo/Polychrome) — `M`
Cards gain `enhancement` field. Applied via tarot consumables or boss rewards.

| Enhancement | Effect |
|-------------|--------|
| Foil | +50 Chips to this card |
| Holographic | +10 Mult to this card |
| Polychrome | ×1.5 Mult (multiplicative, end of chain) |

- Modify `calculate_projection` to apply per-card bonuses before joker pass
- Modify `clone_card` to preserve enhancement field
- Visual: overlay sprites on enhanced cards (assets already in manifest)
- **Stretch:** Seals (`card.seal = "red"|"blue"`) — Red retriggers card, Blue creates planet

**Depends on:** 2.1 (tarots are the delivery mechanism)
**Files:** `game_logic.lua`, `tunables.lua`, `save_load.lua`, `card_visuals.lua`, `render.lua`
**Tests:** `spec/enhancement_spec.lua`, updated goldens

---

## Phase 3: Replayability & Progression (2–3 weeks)

*Every run starts different, and there's always a reason to do "one more run."*

### 3.1 Deck Selection — `M`
Choose a starter deck before each run. Registry pattern.

| Deck | Effect |
|------|--------|
| RED_DECK | +1 discard per blind |
| BLUE_DECK | +1 hand per blind |
| YELLOW_DECK | Start with +10 money |
| BLACK_DECK | +1 joker slot, −1 hand per blind |
| MAGIC_DECK | Start with 2 tarot cards (needs 2.1) |

- `M.STARTER_DECKS = {}`, `register_starter_deck(key, def)` with `modifiers` table
- New `pre_run` state in GameScene showing deck selection panel
- `state.starter_deck` persisted in save

**Tests:** `spec/starter_deck_spec.lua`

### 3.2 Meta-Progression (Unlocks) — `M`
Persistent profile across runs. Unlocks earned by milestones.

- **New:** `src/profile.lua` — loads/saves profile to `saves/profile.lua`
  - `{ total_runs, total_wins, unlocks = {}, run_history = {}, discovery = {} }`
- **New:** `src/unlock_registry.lua` — `register_unlock(key, {condition(profile)})`
  - RED_DECK after 3 runs, BLUE_DECK after 1 win, BLACK_DECK after reaching Ante 3, etc.
- After each run: `profile:record_run()`, `profile:check_unlocks()`
- Locked decks shown grayed with hint text

**Depends on:** 3.1 (decks as unlock targets)
**Tests:** `spec/profile_spec.lua`, `spec/unlock_registry_spec.lua`

### 3.3 Run History — `S`
Last 20 run summaries viewable via `H` key overlay. Shows win/loss, ante, score, MVP joker, seed, deck.

**Depends on:** 3.2 (profile stores history)

### 3.4 Discovery Log — `S`
Collection grid of all jokers/consumables. Discovered = icon+name, undiscovered = silhouette+"???".

**Depends on:** 3.2, 2.1

---

## Phase 4: Polish & Community (1–2 weeks)

*Smooth edges, welcome new players, extend endgame.*

### 4.1 Settings Panel — `S`
`O`/`Escape` overlay: reduced-motion toggle, dark/light theme, keybind reference. Persisted in save meta.

### 4.2 Onboarding Tutorial — `M`
First-run tooltip sequence: "Select cards" → "Press SPACE" → "Beat the target" → "Buy jokers in the shop." Event-bus-driven step advancement. Stored in profile.

- **New:** `src/tutorial.lua` — step state machine
**Depends on:** 3.2 (profile for completion flag)

### 4.3 Accessibility Pass — `M`
- Keyboard focus navigation (arrow keys + Enter)
- Colorblind palette variant in `ui/palette.lua`
- Reduced-motion audit across all Phase 1–3 features
- Focus ring rendering

### 4.4 Endless Mode — `S`
After Ante 3 victory, offer "Continue (Endless)" with exponential scaling: `target[last] × 1.5^(ante − 3)`. Stack boss debuffs after Ante 5. Track highest ante in profile.

**Depends on:** 2.2 (boss blinds), 3.2 (profile)

---

## Implementation Rules

1. **Registry pattern for everything** — consumables, boss blinds, decks, unlocks all use `register_X(key, def)` like jokers
2. **`game_logic.lua` stays LÖVE-free** — all `apply()` functions modify `state` only, no I/O
3. **Tunables centralization** — every new constant goes in `config/tunables.lua`
4. **Save schema v1 → v2 migration** — `save_load.lua` must auto-migrate old saves when adding `consumables`, `hand_levels`, `boss_blind_key`, `starter_deck`, `enhancement` fields
5. **Event bus for cross-module comms** — emit `consumable:used`, `boss_blind:start`, `unlock:achieved`, `discovery:new`
6. **Tests for all new logic** — busted specs, golden snapshots updated

## Verification

After each phase:
1. `lua scripts/smoke_test.lua` — headless logic check
2. `busted` — full test suite (including new specs)
3. `love .` — launch and manually verify visual features
4. Save/load round-trip: save mid-run with new features, load, verify state integrity

## Key Files

| File | Role |
|------|------|
| `src/game_logic.lua` | All registries, scoring, state, shop |
| `config/tunables.lua` | All constants and balance values |
| `src/save_load.lua` | Persistence + schema migration |
| `scene/game_scene.lua` | State machine, visual state, profile |
| `ui/render.lua` | All new UI panels and overlays |
| `scene/input.lua` | New keybindings |
| `scene/actions.lua` | New action handlers |
