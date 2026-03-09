# Phase 2 Roadmap

Picks up after M1, M2, MA, and MU1–MU5 are complete.
Priorities: deepen gameplay content, finish run-end UX, lay groundwork for consumables.

---

## M3-A — Joker Pool Expansion (Complete)

Goal: make joker slots a meaningful strategic decision by offering varied, synergistic trigger categories.

**Trigger categories to cover:**

| Category | Description | Examples |
|----------|-------------|---------|
| Suit | Bonus per card of a given suit | Heart Joker, Club Joker |
| Rank | Bonus per card of a given rank | Ace Joker, Face Joker |
| Hand type | Bonus for achieving a specific hand class | Flush Master, Straight Arrow |
| Count | Bonus based on how many cards were played | Street Rat, Minimalist |
| State-aware | Bonus using live run state (discards, joker count) | Conservative, Hoarder |

**Jokers to add:**

- [x] `HEART_JOKER` — +3 Mult per Heart in played hand (common, suit)
- [x] `CLUB_JOKER` — +10 Chips per Club in played hand (common, suit)
- [x] `ACE_JOKER` — +6 Mult per Ace in played hand (uncommon, rank)
- [x] `FACE_JOKER` — +4 Chips per face card (J/Q/K) in played hand (common, rank)
- [x] `FLUSH_MASTER` — +30 Mult if hand is Flush or better (rare, hand-type)
- [x] `STRAIGHT_ARROW` — +20 Mult if hand is Straight or Straight Flush (uncommon, hand-type)
- [x] `STREET_RAT` — +2 Mult per card played (common, count)
- [x] `MINIMALIST` — +20 Mult if exactly 1 card played (rare, count)
- [x] `HOARDER` — +2 Mult per Joker owned (uncommon, state-aware)
- [x] `CONSERVATIVE` — +2 Mult per discard remaining this blind (common, state-aware)

**Acceptance criteria:**
- [x] All new jokers registered in `game_logic.lua`
- [x] State-aware jokers receive `state` as 3rd arg to `apply()` — existing jokers unaffected
- [x] `calculate_projection` passes state through (pure function: read-only)
- [x] Golden snapshot fixtures updated for new jokers
- [x] Smoke test passes headlessly
- [x] Busted suite passes with no regressions

---

## MU6-A — Run Result Screen Polish (Complete)

Goal: the end screen conveys outcome, key highlights, and a clear next action.

- [x] Show run seed on result screen (copyable hint)
- [x] Show MVP joker (joker that contributed most mult over the run)
- [x] Show best hand played (hand type + score of highest-scoring single play)
- [x] Add `[R] New Run` and `[S] Enter Seed` keyboard hint on result screen
- [x] Add visual separator between summary stats and per-round log
- [x] Wire `R` key to restart directly from result screen (without clicking)

**Acceptance criteria:**
- [x] Seed visible on result screen
- [x] MVP joker name visible when jokers were used
- [x] `R` key from result screen starts a new run

---

## MA2 — Consumables Pipeline (Complete)

Goal: one-shot item type that can be bought in shop and used from hand area.

- [x] `consumable` item type in shop offer model
- [x] Consumable inventory slot (max 2) distinct from joker slots
- [x] `apply_consumable(state, key)` pure function, registered like jokers
- [x] First consumables: `THE_FOOL` (copy last played hand), `HIGH_PRIESTESS` (draw 2 cards)
- [x] Shop UI shows consumable slot with use/discard affordance
- [x] 8 Planet cards (MERCURY through PLUTO) — upgrade hand type levels
- [x] 4 Tarot cards (THE_FOOL, HIGH_PRIESTESS, THE_HERMIT, THE_WHEEL)

**Acceptance criteria:**
- [x] Consumables can be bought and held without affecting joker slot count
- [x] Using a consumable fires an event through the event bus
- [x] Pure logic tested headlessly in busted

---

## M3-B — Boss Blinds (Complete)

Goal: add meaningful boss encounters at the third blind of each ante.

- [x] `register_boss_blind(key, definition)` with callbacks: `on_start`, `on_play`, `on_score`
- [x] 6 boss blinds: THE_HOOK, THE_WALL, THE_FLINT, THE_MARK, THE_PSYCHIC, THE_NEEDLE
- [x] Boss blind rolls deterministically from seeded RNG at blind_index 3
- [x] Boss `on_score` hooks modify projection after joker effects
- [x] UI displays boss name + description on blind start
- [x] Save/load persists boss blind state

---

## M3-C — Card Enhancements (Complete)

Goal: add per-card modifiers that change scoring behavior.

- [x] `apply_card_enhancement(card, chips, mult, x_mult)` pure function
- [x] 3 enhancement types: Foil (+50 chips), Holo (+10 mult), Polychrome (×1.5 x_mult)
- [x] x_mult system: projection includes `x_mult` field, final = `floor(chips × mult × x_mult)`
- [x] Enhancement border glows and label overlays in UI
- [x] Save/load persists card enhancements

---

## M3-D — Hand Level Bonuses (Complete)

Goal: planet consumables upgrade hand type levels for growing returns.

- [x] `hand_levels[hand_type_id]` state field with per-level chip/mult bonus
- [x] Config: `chips_per_level = 10`, `mult_per_level = 1`
- [x] Applied in projection after hand type base, before joker effects
- [x] UI shows level suffix in projection formula

---

## Save/Load Schema v2 (Complete)

- [x] Schema migration path: v1 → v2
- [x] New fields: `consumables[]`, `hand_levels{}`, `boss_blind_key`, `last_hand_type`
- [x] Card enhancement + face_down persistence
- [x] Auto-upgrade v1 saves with default empty tables

---

## MU6-B — Settings Panel (Complete)

Goal: expose the two most-needed runtime toggles without blocking gameplay.

- [x] Settings overlay (toggle with `O` or `Esc` to close)
- [x] Reduced-motion toggle (F3, shown in settings)
- [x] Dark/light card theme toggle (F2, shown in settings)
- [x] Keybind reference list (full keybind table in settings panel)

---

## MT-B — CI & Coverage (Complete)

Goal: close the remaining testing gaps.

- [x] Add Lua 5.4 to CI matrix (`.github/workflows/lua-tests.yml`)
- [x] Add `busted --coverage` step to generate luacov report as CI artifact
- [x] Tests exist for boss blinds, consumables, enhancements (new trigger categories covered)

---

## Next Priority Order

1. ~~**M3-A** — Joker expansion~~ ✅
2. ~~**MU6-A** — Run result polish~~ ✅
3. ~~**MA2** — Consumables pipeline~~ ✅
4. ~~**M3-B** — Boss blinds~~ ✅
5. ~~**M3-C** — Card enhancements~~ ✅
6. ~~**M3-D** — Hand level bonuses~~ ✅
7. ~~**MU6-B** — Settings panel~~ ✅
8. ~~**MT-B** — CI coverage~~ ✅
