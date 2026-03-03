local game = require("src.game_logic")

local function deterministic_rng(min, _max)
  return min
end

local function select_first_n(state, n)
  game.clear_selection(state)
  for i = 1, math.min(n, #state.hand) do
    local ok = game.toggle_selection(state, i)
    assert.is_true(ok)
  end
end

local function clear_current_blind(state)
  local blind_id = game.current_blind(state).id
  state.score = game.current_target(state) - 1
  select_first_n(state, 1)
  local result = game.play_selected(state)
  assert.is_true(result.ok)
  assert.are.equal("shop", result.event)
  return blind_id, result
end

describe("regression: blind progression + economy phases", function()
  it("keeps money/progression coherent through small->big->boss shop phases", function()
    local state = game.new_state(deterministic_rng)
    local expected_money = state.money

    -- Phase 1: clear small blind and run a full shop action mix.
    local blind_small, clear_small = clear_current_blind(state)
    assert.are.equal("small", blind_small)
    expected_money = expected_money + (clear_small.payout or 0)
    assert.are.equal(expected_money, state.money)

    state.shop.offers[1] = {
      type = "joker",
      joker_key = "JOKER",
      rarity = "common",
      price = 1,
    }
    local buy_small = game.shop_buy_offer(state, 1)
    assert.is_true(buy_small.ok)
    expected_money = expected_money - (buy_small.cost or 0)
    assert.are.equal(expected_money, state.money)

    local reroll_small = game.shop_reroll(state)
    assert.is_true(reroll_small.ok)
    expected_money = expected_money - (reroll_small.cost or 0)
    assert.are.equal(expected_money, state.money)

    local sell_small = game.shop_sell_joker(state, 1)
    assert.is_true(sell_small.ok)
    expected_money = expected_money + (sell_small.gain or 0)
    assert.are.equal(expected_money, state.money)

    local cont_small = game.shop_continue(state)
    assert.is_true(cont_small.ok)
    assert.are.equal("next_blind", cont_small.event)
    assert.are.equal(1, state.ante)
    assert.are.equal(2, state.blind_index)
    assert.are.equal(expected_money, state.money)

    -- Phase 2: clear big blind and do deck economy operations.
    local blind_big, clear_big = clear_current_blind(state)
    assert.are.equal("big", blind_big)
    expected_money = expected_money + (clear_big.payout or 0)
    assert.are.equal(expected_money, state.money)

    local min_deck = game.HAND_SIZE + 1
    if #state.deck_cards <= min_deck then
      state.deck_cards[#state.deck_cards + 1] = { rank = 2, suit = "S" }
      state.deck_cards[#state.deck_cards + 1] = { rank = 3, suit = "H" }
    end
    state.money = math.max(state.money, 100)
    expected_money = state.money

    local remove_big = game.shop_deck_remove(state)
    assert.is_true(remove_big.ok)
    expected_money = expected_money - (remove_big.cost or 0)
    assert.are.equal(expected_money, state.money)

    local duplicate_big = game.shop_deck_duplicate(state)
    assert.is_true(duplicate_big.ok)
    expected_money = expected_money - (duplicate_big.cost or 0)
    assert.are.equal(expected_money, state.money)

    local cont_big = game.shop_continue(state)
    assert.is_true(cont_big.ok)
    assert.are.equal("next_blind", cont_big.event)
    assert.are.equal(1, state.ante)
    assert.are.equal(3, state.blind_index)
    assert.are.equal(expected_money, state.money)

    -- Phase 3: boss clear enters shop first, then continue advances ante.
    local blind_boss, clear_boss = clear_current_blind(state)
    assert.are.equal("boss", blind_boss)
    expected_money = expected_money + (clear_boss.payout or 0)
    assert.are.equal(expected_money, state.money)
    assert.are.equal(1, state.ante)
    assert.are.equal(3, state.blind_index)

    local cont_boss = game.shop_continue(state)
    assert.is_true(cont_boss.ok)
    assert.are.equal("next_ante", cont_boss.event)
    assert.are.equal(2, state.ante)
    assert.are.equal(1, state.blind_index)
    assert.are.equal(expected_money, state.money)
    assert.are.equal(0, state.score)
    assert.are.equal(game.STARTING_HANDS, state.hands)
    assert.are.equal(game.STARTING_DISCARDS, state.discards)
  end)

  it("keeps economy ledger events and values stable across phase actions", function()
    local state = game.new_state(deterministic_rng)

    local _, clear_small = clear_current_blind(state)
    assert.is_true((clear_small.payout or 0) > 0)
    local payout_gain = clear_small.payout or 0

    state.shop.offers[1] = {
      type = "joker",
      joker_key = "JOKER",
      rarity = "common",
      price = 1,
    }
    local buy = game.shop_buy_offer(state, 1)
    assert.is_true(buy.ok)

    local reroll = game.shop_reroll(state)
    assert.is_true(reroll.ok)

    local sell = game.shop_sell_joker(state, 1)
    assert.is_true(sell.ok)

    local snap = game.inventory_snapshot(state)
    assert.is_true((snap.earned or 0) >= payout_gain + (sell.gain or 0))
    assert.is_true((snap.spent or 0) >= (buy.cost or 0) + (reroll.cost or 0))
    assert.is_true((snap.history_size or 0) >= 4)

    local history = state.inventory.history
    local seen = {}
    for _, entry in ipairs(history) do
      seen[entry.event] = true
    end
    assert.is_true(seen["blind_clear_payout"])
    assert.is_true(seen["shop_buy"])
    assert.is_true(seen["shop_reroll"])
    assert.is_true(seen["shop_sell_joker"])
  end)
end)
