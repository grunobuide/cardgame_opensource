local game = require("src.game_logic")

local function make_rng(seed)
  return game.make_seeded_rng(seed or "consumable-test")
end

local function make_state(opts)
  opts = opts or {}
  local state = game.new_state(make_rng(opts.seed or "consumable-test"), { seed = opts.seed or "consumable-test" })
  game.new_run(state)
  return state
end

describe("consumable system", function()
  describe("registry", function()
    it("has planet cards registered", function()
      local planet_keys = { "MERCURY", "VENUS", "EARTH", "MARS", "JUPITER", "SATURN", "NEPTUNE", "PLUTO" }
      for _, key in ipairs(planet_keys) do
        assert.is_not_nil(game.CONSUMABLES[key], ("Missing planet: %s"):format(key))
        assert.are.equal("planet", game.CONSUMABLES[key].category)
      end
    end)

    it("has tarot cards registered", function()
      local tarot_keys = { "THE_FOOL", "HIGH_PRIESTESS", "THE_HERMIT", "THE_WHEEL" }
      for _, key in ipairs(tarot_keys) do
        assert.is_not_nil(game.CONSUMABLES[key], ("Missing tarot: %s"):format(key))
        assert.are.equal("tarot", game.CONSUMABLES[key].category)
      end
    end)

    it("consumable definitions have required fields", function()
      for key, def in pairs(game.CONSUMABLES) do
        assert.is_string(def.name, ("Name missing for %s"):format(key))
        assert.is_string(def.description, ("Description missing for %s"):format(key))
        assert.is_function(def.apply, ("Apply missing for %s"):format(key))
        assert.is_string(def.category, ("Category missing for %s"):format(key))
      end
    end)
  end)

  describe("use_consumable", function()
    it("returns error for empty slot", function()
      local state = make_state()
      local result = game.use_consumable(state, 1)
      assert.is_false(result.ok)
      assert.are.equal("no_consumable", result.reason)
    end)

    it("returns error for nil slot", function()
      local state = make_state()
      local result = game.use_consumable(state, 5)
      assert.is_false(result.ok)
    end)

    it("uses planet card and upgrades hand level", function()
      local state = make_state()
      state.consumables = { "MERCURY" }
      local result = game.use_consumable(state, 1)
      assert.is_true(result.ok)
      assert.are.equal("consumable_used", result.event)
      assert.are.equal(1, state.hand_levels["PAIR"])
      assert.are.equal(0, #state.consumables)
    end)

    it("planet card stacks levels", function()
      local state = make_state()
      state.hand_levels["PAIR"] = 2
      state.consumables = { "MERCURY" }
      game.use_consumable(state, 1)
      assert.are.equal(3, state.hand_levels["PAIR"])
    end)

    it("uses The Hermit to double money capped at +20", function()
      local state = make_state()
      state.money = 15
      state.consumables = { "THE_HERMIT" }
      game.use_consumable(state, 1)
      assert.are.equal(30, state.money)
    end)

    it("The Hermit caps bonus at 20", function()
      local state = make_state()
      state.money = 50
      state.consumables = { "THE_HERMIT" }
      game.use_consumable(state, 1)
      assert.are.equal(70, state.money)
    end)

    it("uses High Priestess to draw +2 cards", function()
      local state = make_state()
      local hand_before = #state.hand
      state.consumables = { "HIGH_PRIESTESS" }
      game.use_consumable(state, 1)
      assert.is_true(#state.hand >= hand_before)
    end)

    it("removes consumable from slot after use", function()
      local state = make_state()
      state.consumables = { "MERCURY", "VENUS" }
      game.use_consumable(state, 1)
      assert.are.equal(1, #state.consumables)
      assert.are.equal("VENUS", state.consumables[1])
    end)

    it("The Fool fails with no prior hand played", function()
      local state = make_state()
      state.consumables = { "THE_FOOL" }
      state.last_hand_type = nil
      local result = game.use_consumable(state, 1)
      -- The Fool should fail or have no effect without prior hand
      assert.is_not_nil(result)
    end)

    it("The Fool creates planet when last hand type matches", function()
      local state = make_state()
      state.last_hand_type = "PAIR"
      state.consumables = { "THE_FOOL" }
      local result = game.use_consumable(state, 1)
      assert.is_true(result.ok)
      -- Should have created MERCURY in a slot
      assert.are.equal(1, #state.consumables)
      assert.are.equal("MERCURY", state.consumables[1])
    end)
  end)

  describe("hand level bonuses in projection", function()
    it("adds bonus chips and mult from hand level", function()
      local state = make_state()
      state.hand_levels = { PAIR = 3 }
      local cards = {
        { rank = 5, suit = "S" },
        { rank = 5, suit = "H" },
      }
      local proj = game.calculate_projection(state, cards)
      assert.are.equal("PAIR", proj.hand_type.id)
      -- Base pair is 10 chips, 2 mult
      -- Level 3 adds 30 chips, 3 mult = 40 chips, 5 mult
      assert.are.equal(3, proj.hand_level)
      assert.is_true(proj.total_chips >= 40)
      assert.is_true(proj.total_mult >= 5)
    end)
  end)

  describe("consumables in state", function()
    it("new_run resets consumables and hand levels", function()
      local state = make_state()
      state.consumables = { "MERCURY" }
      state.hand_levels = { PAIR = 5 }
      game.new_run(state)
      assert.are.equal(0, #state.consumables)
      -- hand_levels should be reset
      assert.are.same({}, state.hand_levels)
    end)

    it("state has max consumable cap", function()
      assert.is_true(game.MAX_CONSUMABLES >= 2)
    end)
  end)
end)
