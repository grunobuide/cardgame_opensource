local game = require("src.game_logic")
local goldens = require("spec.fixtures.projection_goldens")

local function deterministic_rng(min, _max)
  return min
end

local function normalize_effect(effect)
  local out = {}
  if effect and effect.chips ~= nil then
    out.chips = effect.chips
  end
  if effect and effect.mult ~= nil then
    out.mult = effect.mult
  end
  return out
end

local function normalize_projection(projection)
  local joker_details = {}
  for i, detail in ipairs(projection.joker_details or {}) do
    joker_details[i] = {
      joker_key = detail.joker_key,
      effect = normalize_effect(detail.effect),
    }
  end

  return {
    hand_type_id = projection.hand_type.id,
    hand_type_label = projection.hand_type.label,
    base_chips = projection.base_chips,
    base_mult = projection.base_mult,
    total_chips = projection.total_chips,
    total_mult = projection.total_mult,
    total = projection.total,
    joker_details = joker_details,
  }
end

describe("projection golden outputs", function()
  for _, fixture in ipairs(goldens) do
    it(("matches golden snapshot: %s"):format(fixture.id), function()
      local state = game.new_state(deterministic_rng)
      state.jokers = fixture.jokers
      game.ensure_run_inventory(state)

      local projection = game.calculate_projection(state, fixture.cards)
      local normalized = normalize_projection(projection)

      assert.are.same(fixture.expected, normalized)
    end)
  end
end)
