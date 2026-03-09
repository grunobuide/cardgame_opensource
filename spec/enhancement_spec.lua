local game = require("src.game_logic")

local function make_rng(seed)
  return game.make_seeded_rng(seed or "enh-test")
end

local function make_state(opts)
  opts = opts or {}
  local state = game.new_state(make_rng(opts.seed or "enh-test"), { seed = opts.seed or "enh-test" })
  game.new_run(state)
  return state
end

describe("card enhancements", function()
  describe("apply_card_enhancement", function()
    it("foil adds chips", function()
      local card = { rank = 5, suit = "S", enhancement = "foil" }
      local chips, mult, x_mult = game.apply_card_enhancement(card, 10, 2, 1)
      assert.are.equal(60, chips) -- 10 + 50
      assert.are.equal(2, mult)
      assert.are.equal(1, x_mult)
    end)

    it("holo adds mult", function()
      local card = { rank = 5, suit = "S", enhancement = "holo" }
      local chips, mult, x_mult = game.apply_card_enhancement(card, 10, 2, 1)
      assert.are.equal(10, chips)
      assert.are.equal(12, mult) -- 2 + 10
      assert.are.equal(1, x_mult)
    end)

    it("polychrome multiplies x_mult", function()
      local card = { rank = 5, suit = "S", enhancement = "polychrome" }
      local chips, mult, x_mult = game.apply_card_enhancement(card, 10, 2, 1)
      assert.are.equal(10, chips)
      assert.are.equal(2, mult)
      assert.are.equal(1.5, x_mult) -- 1 * 1.5
    end)

    it("returns unchanged values for no enhancement", function()
      local card = { rank = 5, suit = "S" }
      local chips, mult, x_mult = game.apply_card_enhancement(card, 10, 2, 1)
      assert.are.equal(10, chips)
      assert.are.equal(2, mult)
      assert.are.equal(1, x_mult)
    end)

    it("handles nil card gracefully", function()
      local chips, mult, x_mult = game.apply_card_enhancement(nil, 10, 2, 1)
      assert.are.equal(10, chips)
      assert.are.equal(2, mult)
      assert.are.equal(1, x_mult)
    end)
  end)

  describe("enhancements in projection", function()
    it("foil card increases chips in projection", function()
      local state = make_state()
      state.jokers = {}
      local cards = {
        { rank = 5, suit = "S", enhancement = "foil" },
        { rank = 5, suit = "H" },
      }
      local proj = game.calculate_projection(state, cards)
      -- PAIR base: 10 chips, 2 mult
      -- Foil adds 50 chips -> 60 chips, 2 mult -> total 120
      assert.are.equal("PAIR", proj.hand_type.id)
      assert.are.equal(60, proj.total_chips)
      assert.are.equal(120, proj.total)
    end)

    it("holo card increases mult in projection", function()
      local state = make_state()
      state.jokers = {}
      local cards = {
        { rank = 5, suit = "S", enhancement = "holo" },
        { rank = 5, suit = "H" },
      }
      local proj = game.calculate_projection(state, cards)
      -- PAIR base: 10 chips, 2 mult
      -- Holo adds 10 mult -> 10 chips, 12 mult -> total 120
      assert.are.equal(12, proj.total_mult)
      assert.are.equal(120, proj.total)
    end)

    it("polychrome card applies x_mult in projection", function()
      local state = make_state()
      state.jokers = {}
      local cards = {
        { rank = 5, suit = "S", enhancement = "polychrome" },
        { rank = 5, suit = "H" },
      }
      local proj = game.calculate_projection(state, cards)
      -- PAIR base: 10 chips, 2 mult, x_mult 1.5
      -- Total = floor(10 * 2 * 1.5) = 30
      assert.are.equal(1.5, proj.x_mult)
      assert.are.equal(30, proj.total)
    end)

    it("multiple enhancements stack correctly", function()
      local state = make_state()
      state.jokers = {}
      local cards = {
        { rank = 5, suit = "S", enhancement = "foil" },
        { rank = 5, suit = "H", enhancement = "polychrome" },
      }
      local proj = game.calculate_projection(state, cards)
      -- PAIR base: 10 chips, 2 mult
      -- Foil: +50 chips -> 60 chips
      -- Polychrome: x1.5 x_mult
      -- Total = floor(60 * 2 * 1.5) = 180
      assert.are.equal(60, proj.total_chips)
      assert.are.equal(2, proj.total_mult)
      assert.are.equal(1.5, proj.x_mult)
      assert.are.equal(180, proj.total)
    end)

    it("foil + holo + polychrome all together", function()
      local state = make_state()
      state.jokers = {}
      local cards = {
        { rank = 5, suit = "S", enhancement = "foil" },
        { rank = 5, suit = "H", enhancement = "holo" },
        { rank = 5, suit = "D", enhancement = "polychrome" },
      }
      local proj = game.calculate_projection(state, cards)
      -- THREE_KIND base: 30 chips, 3 mult
      -- Foil: +50 chips -> 80 chips
      -- Holo: +10 mult -> 13 mult
      -- Polychrome: x1.5 x_mult
      -- Total = floor(80 * 13 * 1.5) = 1560
      assert.are.equal("THREE_KIND", proj.hand_type.id)
      assert.are.equal(80, proj.total_chips)
      assert.are.equal(13, proj.total_mult)
      assert.are.equal(1.5, proj.x_mult)
      assert.are.equal(1560, proj.total)
    end)
  end)

  describe("enhancement values from tunables", function()
    it("uses configured foil chips", function()
      assert.are.equal(50, game.ENHANCEMENTS.foil_chips)
    end)

    it("uses configured holo mult", function()
      assert.are.equal(10, game.ENHANCEMENTS.holo_mult)
    end)

    it("uses configured poly x_mult", function()
      assert.are.equal(1.5, game.ENHANCEMENTS.poly_x_mult)
    end)
  end)
end)
