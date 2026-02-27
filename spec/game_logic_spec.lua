local game = require("src.game_logic")

local function deterministic_rng(min, _max)
  return min
end

describe("game_logic", function()
  describe("deck/state bootstrap", function()
    it("creates a 52-card deck", function()
      local deck = game.build_deck(deterministic_rng)
      assert.are.equal(52, #deck)
    end)

    it("initializes run state correctly", function()
      local state = game.new_state(deterministic_rng)
      assert.are.equal(1, state.ante)
      assert.are.equal(1, state.blind_index)
      assert.are.equal("Small Blind", game.current_blind(state).label)
      assert.are.equal(game.STARTING_HANDS, state.hands)
      assert.are.equal(game.STARTING_DISCARDS, state.discards)
      assert.are.equal(8, #state.hand)
      assert.are.equal(44, #state.deck)
      assert.are.equal(false, state.game_over)
    end)

    it("builds deterministic decks from identical seeds", function()
      local rng_a = game.make_seeded_rng("abc123")
      local rng_b = game.make_seeded_rng("abc123")
      local deck_a = game.build_deck(rng_a)
      local deck_b = game.build_deck(rng_b)

      for i = 1, #deck_a do
        assert.are.equal(deck_a[i].suit, deck_b[i].suit)
        assert.are.equal(deck_a[i].rank, deck_b[i].rank)
      end
    end)

    it("changes run deck when seed changes", function()
      local state = game.new_state(game.make_seeded_rng("first"), { seed = "first" })
      local first_top = tostring(state.hand[1].rank) .. state.hand[1].suit

      game.set_seed(state, "second", game.make_seeded_rng("second"))
      game.new_run(state)
      local second_top = tostring(state.hand[1].rank) .. state.hand[1].suit

      assert.not_equal(first_top, second_top)
      assert.are.equal("second", state.seed)
    end)
  end)

  describe("hand evaluation", function()
    it("evaluates royal flush", function()
      local cards = {
        { rank = 10, suit = "S" },
        { rank = "J", suit = "S" },
        { rank = "Q", suit = "S" },
        { rank = "K", suit = "S" },
        { rank = "A", suit = "S" },
      }
      local hand_type = game.evaluate_hand(cards)
      assert.are.equal("ROYAL_FLUSH", hand_type.id)
    end)

    it("evaluates pair", function()
      local cards = {
        { rank = 2, suit = "S" },
        { rank = 2, suit = "H" },
        { rank = 8, suit = "D" },
      }
      local hand_type = game.evaluate_hand(cards)
      assert.are.equal("PAIR", hand_type.id)
    end)

    it("does not evaluate flush on less than 5 cards", function()
      local cards = {
        { rank = 2, suit = "H" },
        { rank = 5, suit = "H" },
        { rank = "Q", suit = "H" },
      }
      local hand_type = game.evaluate_hand(cards)
      assert.are.equal("HIGH_CARD", hand_type.id)
    end)
  end)

  describe("selection and transitions", function()
    it("caps selection at 5 cards", function()
      local state = game.new_state(deterministic_rng)
      for i = 1, 5 do
        local ok = game.toggle_selection(state, i)
        assert.is_true(ok)
      end
      local ok, msg = game.toggle_selection(state, 6)
      assert.is_false(ok)
      assert.are.equal("You can only select up to 5 cards.", msg)
    end)

    it("play_selected requires at least one selected card", function()
      local state = game.new_state(deterministic_rng)
      local result = game.play_selected(state)
      assert.is_false(result.ok)
      assert.are.equal("no_selection", result.reason)
    end)

    it("discard_selected decrements discards and replenishes hand", function()
      local state = game.new_state(deterministic_rng)
      local before = #state.hand
      game.toggle_selection(state, 1)
      local result = game.discard_selected(state)
      assert.is_true(result.ok)
      assert.are.equal("discarded", result.event)
      assert.are.equal(game.STARTING_DISCARDS - 1, state.discards)
      assert.are.equal(before, #state.hand)
    end)

    it("play_selected consumes a hand and adds score", function()
      local state = game.new_state(deterministic_rng)
      game.toggle_selection(state, 1)
      game.toggle_selection(state, 2)
      local result = game.play_selected(state)
      assert.is_true(result.ok)
      assert.are.equal("played", result.event)
      assert.are.equal(game.STARTING_HANDS - 1, state.hands)
      assert.is_true(state.score > 0)
      assert.are.equal(8, #state.hand)
    end)

    it("advances to next blind when current blind target is cleared", function()
      local state = game.new_state(deterministic_rng)
      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)
      local result = game.play_selected(state)
      assert.is_true(result.ok)
      assert.are.equal("next_blind", result.event)
      assert.are.equal(1, state.ante)
      assert.are.equal(2, state.blind_index)
      assert.are.equal(0, state.score)
      assert.are.equal(game.STARTING_HANDS, state.hands)
      assert.are.equal(game.STARTING_DISCARDS, state.discards)
    end)

    it("advances ante after boss blind is cleared", function()
      local state = game.new_state(deterministic_rng)
      state.blind_index = #game.BLINDS
      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)
      local result = game.play_selected(state)
      assert.is_true(result.ok)
      assert.are.equal("next_ante", result.event)
      assert.are.equal(2, state.ante)
      assert.are.equal(1, state.blind_index)
      assert.are.equal(0, state.score)
    end)

    it("wins run after clearing final boss blind on max ante", function()
      local state = game.new_state(deterministic_rng)
      state.ante = game.MAX_ANTE
      state.blind_index = #game.BLINDS
      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)

      local result = game.play_selected(state)

      assert.is_true(result.ok)
      assert.are.equal("run_won", result.event)
      assert.is_true(state.game_over)
      assert.is_true(state.run_won)
    end)
  end)

  describe("jokers", function()
    it("adds forced joker and applies projection bonus", function()
      local state = game.new_state(deterministic_rng)
      local add = game.add_joker(state, "JOKER")
      assert.is_true(add.ok)
      assert.are.equal(1, #state.jokers)

      local cards = {
        { rank = 2, suit = "S" },
        { rank = 7, suit = "H" },
      }
      local projection = game.calculate_projection(state, cards)
      assert.are.equal(5, projection.base_chips)
      assert.are.equal(1, projection.base_mult)
      assert.are.equal(25, projection.total)
    end)
  end)

  describe("sorting", function()
    it("sorts hand by rank ascending with suit tie-break", function()
      local state = game.new_state(deterministic_rng)
      state.hand = {
        { rank = "A", suit = "H" },
        { rank = 2, suit = "S" },
        { rank = "J", suit = "C" },
        { rank = 2, suit = "D" },
      }

      game.sort_hand(state, "rank")

      assert.are.equal(2, state.hand[1].rank)
      assert.are.equal("S", state.hand[1].suit)
      assert.are.equal(2, state.hand[2].rank)
      assert.are.equal("D", state.hand[2].suit)
      assert.are.equal("J", state.hand[3].rank)
      assert.are.equal("A", state.hand[4].rank)
      assert.are.equal("Hand sorted by rank.", state.message)
    end)

    it("sorts hand by suit then rank", function()
      local state = game.new_state(deterministic_rng)
      state.hand = {
        { rank = "K", suit = "C" },
        { rank = 9, suit = "H" },
        { rank = 2, suit = "S" },
        { rank = "A", suit = "D" },
      }

      game.sort_hand(state, "suit")

      assert.are.equal("S", state.hand[1].suit)
      assert.are.equal("H", state.hand[2].suit)
      assert.are.equal("D", state.hand[3].suit)
      assert.are.equal("C", state.hand[4].suit)
      assert.are.equal("Hand sorted by suit.", state.message)
    end)
  end)
end)
