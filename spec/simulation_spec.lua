local game = require("src.game_logic")

local function select_first_n(state, n)
  game.clear_selection(state)
  for i = 1, math.min(n, #state.hand) do
    local ok = game.toggle_selection(state, i)
    assert.is_true(ok)
  end
end

local function run_scripted(seed)
  local state = game.new_state(game.make_seeded_rng(seed), { seed = seed })
  local trace = {}
  local initial_hand = {}
  for i = 1, #state.hand do
    local card = state.hand[i]
    initial_hand[i] = tostring(card.rank) .. card.suit
  end

  local function push(step)
    trace[#trace + 1] = step
  end

  select_first_n(state, 2)
  local d1 = game.discard_selected(state)
  assert.is_true(d1.ok)
  push(("discard:%s:%d"):format(d1.event, state.discards))

  select_first_n(state, 1)
  local d2 = game.discard_selected(state)
  assert.is_true(d2.ok)
  push(("discard:%s:%d"):format(d2.event, state.discards))

  select_first_n(state, 1)
  local d3 = game.discard_selected(state)
  assert.is_false(d3.ok)
  assert.are.equal("no_discards", d3.reason)
  push(("discard_fail:%s:%d"):format(d3.reason, state.discards))

  local safety = 0
  while not state.game_over and safety < 24 do
    select_first_n(state, 3)
    local play = game.play_selected(state)
    assert.is_true(play.ok)
    push(("play:%s:%d:%d:%d"):format(play.event, state.ante, state.blind_index, state.score))
    safety = safety + 1
  end

  assert.is_true(state.game_over)
  return {
    trace = trace,
    initial_hand = table.concat(initial_hand, ","),
    final = {
      ante = state.ante,
      blind_index = state.blind_index,
      score = state.score,
      hands = state.hands,
      discards = state.discards,
      run_won = state.run_won,
      message = state.message,
    },
  }
end

describe("deterministic simulation", function()
  it("produces identical trace for same seed and scripted actions", function()
    local a = run_scripted("mt-sim-seed-001")
    local b = run_scripted("mt-sim-seed-001")

    assert.are.same(a.trace, b.trace)
    assert.are.same(a.final, b.final)
  end)

  it("produces different traces for different seeds", function()
    local a = run_scripted("mt-sim-seed-001")
    local b = run_scripted("mt-sim-seed-002")

    assert.are_not.equal(a.initial_hand, b.initial_hand)
  end)
end)
