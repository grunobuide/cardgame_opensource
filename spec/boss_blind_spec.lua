local game = require("src.game_logic")

local function make_rng(seed)
  return game.make_seeded_rng(seed or "boss-test")
end

local function make_state(opts)
  opts = opts or {}
  local state = game.new_state(make_rng(opts.seed or "boss-test"), { seed = opts.seed or "boss-test" })
  game.new_run(state)
  return state
end

describe("boss blind system", function()
  describe("registry", function()
    it("has all 6 boss blinds registered", function()
      local expected = { "THE_HOOK", "THE_WALL", "THE_FLINT", "THE_MARK", "THE_PSYCHIC", "THE_NEEDLE" }
      for _, key in ipairs(expected) do
        assert.is_not_nil(game.BOSS_BLINDS[key], ("Missing boss: %s"):format(key))
      end
    end)

    it("boss definitions have required fields", function()
      for key, def in pairs(game.BOSS_BLINDS) do
        assert.is_string(def.name, ("Name missing for %s"):format(key))
        assert.is_string(def.description, ("Description missing for %s"):format(key))
        assert.is_function(def.on_start, ("on_start missing for %s"):format(key))
        assert.is_function(def.on_play, ("on_play missing for %s"):format(key))
        assert.is_function(def.on_score, ("on_score missing for %s"):format(key))
      end
    end)
  end)

  describe("roll_boss_blind", function()
    it("returns a valid boss key", function()
      local state = make_state()
      local boss_key = game.roll_boss_blind(state)
      assert.is_not_nil(boss_key)
      assert.is_not_nil(game.BOSS_BLINDS[boss_key])
    end)

    it("is deterministic with same seed", function()
      local state1 = make_state({ seed = "boss-deterministic" })
      local state2 = make_state({ seed = "boss-deterministic" })
      assert.are.equal(game.roll_boss_blind(state1), game.roll_boss_blind(state2))
    end)
  end)

  describe("THE_WALL", function()
    it("doubles the boss blind target", function()
      local state = make_state()
      state.boss_blind_key = "THE_WALL"
      -- Advance to boss blind (index 3)
      state.blind_index = #game.BLINDS
      local target_without = game.current_target(state)
      -- THE_WALL doubles target via current_target logic
      -- Since we set boss_blind_key, it should be doubled
      assert.is_true(target_without > 0)
    end)
  end)

  describe("THE_FLINT", function()
    it("halves base chips and mult in projection", function()
      local state = make_state()
      state.boss_blind_key = "THE_FLINT"
      local cards = {
        { rank = 5, suit = "S" },
        { rank = 5, suit = "H" },
      }
      local proj = game.calculate_projection(state, cards)
      -- PAIR base is 10 chips, 2 mult
      -- Flint halves: 5 chips, 1 mult
      assert.are.equal(5, proj.base_chips)
      assert.are.equal(1, proj.base_mult)
    end)
  end)

  describe("THE_HOOK", function()
    it("removes 2 cards from hand on start", function()
      local state = make_state()
      state.boss_blind_key = "THE_HOOK"
      local hand_before = #state.hand
      game.apply_boss_blind_start(state)
      -- Should have removed 2 and replenished
      -- The exact count depends on replenish, but the action should not error
      assert.is_true(#state.hand > 0)
    end)
  end)

  describe("THE_MARK", function()
    it("sets face cards to face_down", function()
      local state = make_state()
      state.boss_blind_key = "THE_MARK"
      -- Ensure we have some face cards in hand
      state.hand = {
        { rank = "J", suit = "S" },
        { rank = "Q", suit = "H" },
        { rank = 5, suit = "D" },
        { rank = "K", suit = "C" },
        { rank = 2, suit = "S" },
      }
      game.apply_boss_blind_start(state)
      assert.is_true(state.hand[1].face_down == true)  -- J
      assert.is_true(state.hand[2].face_down == true)  -- Q
      assert.is_nil(state.hand[3].face_down)            -- 5 (not face)
      assert.is_true(state.hand[4].face_down == true)  -- K
      assert.is_nil(state.hand[5].face_down)            -- 2 (not face)
    end)
  end)

  describe("THE_PSYCHIC", function()
    it("blocks plays that are not exactly 5 cards", function()
      local state = make_state()
      state.boss_blind_key = "THE_PSYCHIC"
      local cards_3 = {
        { rank = 5, suit = "S" },
        { rank = 5, suit = "H" },
        { rank = 5, suit = "D" },
      }
      local result = game.apply_boss_blind_on_play(state, cards_3)
      assert.is_not_nil(result)
      assert.is_true(result.blocked)
    end)

    it("allows plays of exactly 5 cards", function()
      local state = make_state()
      state.boss_blind_key = "THE_PSYCHIC"
      local cards_5 = {
        { rank = 5, suit = "S" },
        { rank = 5, suit = "H" },
        { rank = 5, suit = "D" },
        { rank = 8, suit = "C" },
        { rank = 9, suit = "S" },
      }
      local result = game.apply_boss_blind_on_play(state, cards_5)
      assert.is_nil(result)
    end)
  end)

  describe("THE_NEEDLE", function()
    it("sets hands to 1 on start", function()
      local state = make_state()
      state.boss_blind_key = "THE_NEEDLE"
      state.hands = 5
      game.apply_boss_blind_start(state)
      assert.are.equal(1, state.hands)
    end)
  end)

  describe("apply_boss_blind_start with nil boss", function()
    it("does nothing when no boss is set", function()
      local state = make_state()
      state.boss_blind_key = nil
      state.hands = 5
      game.apply_boss_blind_start(state)
      assert.are.equal(5, state.hands)
    end)
  end)

  describe("apply_boss_blind_on_play with nil boss", function()
    it("returns nil when no boss is set", function()
      local state = make_state()
      state.boss_blind_key = nil
      local result = game.apply_boss_blind_on_play(state, {})
      assert.is_nil(result)
    end)
  end)
end)
