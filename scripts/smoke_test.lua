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
  assert_equals(state.hands, 4, "hands should start at 4")
  assert_equals(state.discards, 3, "discards should start at 3")
  assert_equals(#state.hand, 8, "hand should start with 8 cards")
  assert_equals(#state.deck, 44, "deck should have 44 cards after initial draw")

  local ok, msg = game.toggle_selection(state, 1)
  assert_true(ok, "toggle selection should succeed")
  assert_true(msg == nil, "toggle selection should not return error")
  assert_equals(game.selected_count(state), 1, "one card should be selected")

  local discard_result = game.discard_selected(state)
  assert_true(discard_result.ok, "discard should succeed")
  assert_equals(state.discards, 2, "discards should decrement")
  assert_equals(#state.hand, 8, "hand should replenish to 8 after discard")

  game.toggle_selection(state, 1)
  game.toggle_selection(state, 2)
  local play_result = game.play_selected(state)
  assert_true(play_result.ok, "play should succeed with selected cards")
  assert_equals(state.hands, 3, "hands should decrement after play")

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
end

run()
print("All smoke tests passed.")
