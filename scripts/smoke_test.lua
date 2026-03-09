local game = require("src.game_logic")

local function assert_true(condition, message)
  if not condition then
    error(message or "assertion failed")
  end
end

local function assert_equals(actual, expected, message)
  if actual ~= expected then
    error((message or "values are not equal") .. (" (expected=%s, actual=%s)"):format(tostring(expected), tostring(actual)))
  end
end

local function run()
  local state = game.new_state()

  assert_equals(state.ante, 1, "ante should start at 1")
  assert_equals(state.hands, game.STARTING_HANDS, "hands should start at configured value")
  assert_equals(state.discards, game.STARTING_DISCARDS, "discards should start at configured value")
  assert_equals(#state.hand, 8, "hand should start with 8 cards")
  assert_equals(#state.deck, 44, "deck should have 44 cards after initial draw")

  local ok, msg = game.toggle_selection(state, 1)
  assert_true(ok, "toggle selection should succeed")
  assert_true(msg == nil, "toggle selection should not return error")
  assert_equals(game.selected_count(state), 1, "one card should be selected")

  local discard_result = game.discard_selected(state)
  assert_true(discard_result.ok, "discard should succeed")
  assert_equals(state.discards, game.STARTING_DISCARDS - 1, "discards should decrement")
  assert_equals(#state.hand, 8, "hand should replenish to 8 after discard")

  game.toggle_selection(state, 1)
  game.toggle_selection(state, 2)
  local play_result = game.play_selected(state)
  assert_true(play_result.ok, "play should succeed with selected cards")
  assert_equals(state.hands, game.STARTING_HANDS - 1, "hands should decrement after play")
  assert_equals(state.money, 0, "money should not increase unless a blind is cleared")

  state.score = game.current_target(state) - 1
  game.toggle_selection(state, 1)
  local clear_result = game.play_selected(state)
  assert_true(clear_result.ok, "play should succeed when clearing blind")
  assert_true((clear_result.payout or 0) > 0, "blind clear should grant payout")
  assert_equals(state.money, clear_result.money, "state money should match action result money")
  assert_equals(clear_result.event, "shop", "blind clear should enter shop")
  assert_true(state.shop and state.shop.active, "shop should be active after clear")

  local continue_result = game.shop_continue(state)
  assert_true(continue_result.ok, "shop continue should succeed")
  assert_equals(continue_result.event, "next_blind", "shop continue should progress to next blind")

  game.set_hand_to_royal_flush(state)
  game.clear_selection(state)
  game.toggle_selection(state, 1)
  game.toggle_selection(state, 2)
  game.toggle_selection(state, 3)
  game.toggle_selection(state, 4)
  game.toggle_selection(state, 5)
  local hand = game.selected_cards(state)
  local hand_type = game.evaluate_hand(hand)
  assert_equals(hand_type.id, "ROYAL_FLUSH", "royal flush should evaluate correctly")

  local add_joker = game.add_joker(state, "JOKER")
  assert_true(add_joker.ok, "adding forced joker should succeed")
  assert_equals(#state.jokers, 1, "joker list should have one entry")

  local sprite = game.card_sprite_path({ rank = "A", suit = "S" }, "dark")
  assert_equals(sprite, "Cards/Cards_Dark/SA.png", "card sprite path should match expected format")

  -- Phase 2: Consumable system
  assert_true(game.CONSUMABLES ~= nil, "CONSUMABLES registry should exist")
  assert_true(game.CONSUMABLES["MERCURY"] ~= nil, "MERCURY planet should be registered")
  assert_true(game.CONSUMABLES["THE_HERMIT"] ~= nil, "THE_HERMIT tarot should be registered")
  assert_equals(game.MAX_CONSUMABLES, 2, "max consumables should be 2")

  -- Test use_consumable with planet card
  local state2 = game.new_state()
  game.new_run(state2)
  state2.consumables = { "MERCURY" }
  local use_result = game.use_consumable(state2, 1)
  assert_true(use_result.ok, "using MERCURY should succeed")
  assert_equals(state2.hand_levels["PAIR"], 1, "PAIR hand level should be 1 after MERCURY")
  assert_equals(#state2.consumables, 0, "consumable should be removed after use")

  -- Phase 2: Boss blind system
  assert_true(game.BOSS_BLINDS ~= nil, "BOSS_BLINDS registry should exist")
  assert_true(game.BOSS_BLINDS["THE_HOOK"] ~= nil, "THE_HOOK boss should be registered")
  assert_true(game.BOSS_BLINDS["THE_WALL"] ~= nil, "THE_WALL boss should be registered")
  assert_true(game.BOSS_BLINDS["THE_FLINT"] ~= nil, "THE_FLINT boss should be registered")
  assert_true(game.BOSS_BLINDS["THE_MARK"] ~= nil, "THE_MARK boss should be registered")
  assert_true(game.BOSS_BLINDS["THE_PSYCHIC"] ~= nil, "THE_PSYCHIC boss should be registered")
  assert_true(game.BOSS_BLINDS["THE_NEEDLE"] ~= nil, "THE_NEEDLE boss should be registered")

  local boss_key = game.roll_boss_blind(state2)
  assert_true(boss_key ~= nil, "roll_boss_blind should return a key")
  assert_true(game.BOSS_BLINDS[boss_key] ~= nil, "rolled boss should exist in registry")

  -- Phase 2: Card enhancements
  assert_true(game.ENHANCEMENTS ~= nil, "ENHANCEMENTS config should exist")
  assert_equals(game.ENHANCEMENTS.foil_chips, 50, "foil should add 50 chips")
  assert_equals(game.ENHANCEMENTS.holo_mult, 10, "holo should add 10 mult")
  assert_equals(game.ENHANCEMENTS.poly_x_mult, 1.5, "poly should multiply by 1.5")

  local foil_c, foil_m, foil_x = game.apply_card_enhancement({ rank = 5, suit = "S", enhancement = "foil" }, 10, 2, 1)
  assert_equals(foil_c, 60, "foil should add 50 chips")
  assert_equals(foil_m, 2, "foil should not change mult")

  local holo_c, holo_m, holo_x = game.apply_card_enhancement({ rank = 5, suit = "S", enhancement = "holo" }, 10, 2, 1)
  assert_equals(holo_m, 12, "holo should add 10 mult")

  local poly_c, poly_m, poly_x = game.apply_card_enhancement({ rank = 5, suit = "S", enhancement = "polychrome" }, 10, 2, 1)
  assert_equals(poly_x, 1.5, "polychrome should set x_mult to 1.5")

  -- Phase 2: Hand level bonuses in projection
  state2.hand_levels = { PAIR = 2 }
  state2.jokers = {}
  state2.boss_blind_key = nil
  state2.hand = {
    { rank = 5, suit = "S" },
    { rank = 5, suit = "H" },
    { rank = 8, suit = "D" },
  }
  state2.selected = { [1] = true, [2] = true }
  local chosen = game.selected_cards(state2)
  local proj = game.calculate_projection(state2, chosen)
  assert_equals(proj.hand_type.id, "PAIR", "should detect PAIR")
  assert_equals(proj.hand_level, 2, "hand level should be 2")
  -- PAIR base 10 chips, 2 mult + level 2: +20 chips, +2 mult = 30 chips, 4 mult = 120
  assert_equals(proj.total_chips, 30, "chips should include hand level bonus")
  assert_equals(proj.total_mult, 4, "mult should include hand level bonus")
  assert_equals(proj.total, 120, "total should reflect hand level bonuses")
end

run()
print("All smoke tests passed.")
