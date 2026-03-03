# Phase 2 Roadmap

Picks up after M1, M2, MA, and MU1–MU5 are complete.
Priorities: deepen gameplay content, finish run-end UX, lay groundwork for consumables.

---

## M3-A — Joker Pool Expansion (Active)

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
- [ ] All new jokers registered in `game_logic.lua`
- [ ] State-aware jokers receive `state` as 3rd arg to `apply()` — existing jokers unaffected
- [ ] `calculate_projection` passes state through (pure function: read-only)
- [ ] Golden snapshot fixtures updated for new jokers
- [ ] Smoke test passes headlessly
- [ ] Busted suite passes with no regressions

---

## MU6-A — Run Result Screen Polish (Active)

Goal: the end screen conveys outcome, key highlights, and a clear next action.

- [x] Show run seed on result screen (copyable hint)
- [x] Show MVP joker (joker that contributed most mult over the run)
- [ ] Show best hand played (hand type + score of highest-scoring single play)
- [ ] Add `[R] New Run` and `[S] Enter Seed` keyboard hint on result screen
- [ ] Add visual separator between summary stats and per-round log
- [ ] Wire `R` key to restart directly from result screen (without clicking)

**Acceptance criteria:**
- [ ] Seed visible on result screen
- [ ] MVP joker name visible when jokers were used
- [ ] `R` key from result screen starts a new run

---

## MU6-B — Settings Panel

Goal: expose the two most-needed runtime toggles without blocking gameplay.

- [ ] Settings overlay (toggle with `O` or `Esc`-menu)
- [ ] Reduced-motion toggle (persisted via save meta)
- [ ] Dark/light card theme toggle
- [ ] Keybind reference list

---

## MA2 — Consumables Pipeline

Goal: one-shot item type that can be bought in shop and used from hand area.

- [ ] `consumable` item type in shop offer model
- [ ] Consumable inventory slot (max 2) distinct from joker slots
- [ ] `apply_consumable(state, key)` pure function, registered like jokers
- [ ] First consumables: `THE_FOOL` (copy last played hand), `HIGH_PRIESTESS` (draw 2 cards)
- [ ] Shop UI shows consumable slot with use/discard affordance

**Acceptance criteria:**
- [ ] Consumables can be bought and held without affecting joker slot count
- [ ] Using a consumable fires an event through the event bus
- [ ] Pure logic tested headlessly in busted

---

## MT-B — CI & Coverage

Goal: close the remaining testing gaps.

- [ ] Add Lua 5.4 to CI matrix (`.github/workflows/lua-tests.yml`)
- [ ] Add `busted --coverage` step to generate lcov report as CI artifact
- [ ] Add test for each new joker trigger category

---

## Next Priority Order

1. **M3-A** — Joker expansion (most gameplay impact, existing infrastructure)
2. **MU6-A** — Run result polish (completes the visible run loop)
3. **MT-B** — CI coverage (quality gate before M3-B)
4. **MA2** — Consumables pipeline (unlock M3 consumable content)
5. **MU6-B** — Settings panel (quality-of-life)
