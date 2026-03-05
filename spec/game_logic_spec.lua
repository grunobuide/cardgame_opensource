local game = require("src.game_logic")
local config = require("config.init")

local function deterministic_rng(min, _max)
  return min
end

describe("game_logic", function()
  describe("deck/state bootstrap", function()
    it("loads tunables from config layer", function()
      local defaults = config.defaults()
      assert.are.equal(defaults.run.starting_hands, game.STARTING_HANDS)
      assert.are.equal(defaults.run.starting_discards, game.STARTING_DISCARDS)
      assert.are.equal(defaults.shop.offer_count, game.SHOP.offer_count)
      assert.are.equal(defaults.inventory.schema, game.INVENTORY_SCHEMA)
    end)

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
      assert.are.equal(0, state.money)
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
      assert.are.equal("shop", result.event)
      assert.are.equal(game.BLIND_PAYOUTS.small, result.payout)
      assert.are.equal(game.BLIND_PAYOUTS.small, state.money)
      assert.is_true(state.shop and state.shop.active)
      assert.are.equal(1, state.ante)

      local cont = game.shop_continue(state)
      assert.is_true(cont.ok)
      assert.are.equal("next_blind", cont.event)
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
      assert.are.equal("shop", result.event)
      local cont = game.shop_continue(state)
      assert.is_true(cont.ok)
      assert.are.equal("next_ante", cont.event)
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

  describe("currency and payouts", function()
    it("calculates blind clear payout with ante bonus", function()
      local state = game.new_state(deterministic_rng)
      state.ante = 3
      state.blind_index = 2
      local payout = game.blind_clear_payout(state)
      assert.are.equal(game.BLIND_PAYOUTS.big + 4, payout)
    end)

    it("awards money only when a blind is cleared", function()
      local state = game.new_state(deterministic_rng)

      game.toggle_selection(state, 1)
      local played = game.play_selected(state)
      assert.is_true(played.ok)
      assert.are.equal("played", played.event)
      assert.are.equal(0, state.money)

      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)
      local clear = game.play_selected(state)
      assert.is_true(clear.ok)
      assert.are.equal("shop", clear.event)
      assert.is_true((clear.payout or 0) > 0)
      assert.are.equal(clear.money, state.money)
      assert.is_true(state.shop and state.shop.active)
    end)

    it("enters shop on blind clear and continues progression after shop", function()
      local state = game.new_state(deterministic_rng)
      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)
      local clear = game.play_selected(state)

      assert.is_true(clear.ok)
      assert.are.equal("shop", clear.event)
      assert.is_true(state.shop and state.shop.active)
      assert.are.equal(1, state.blind_index)

      local cont = game.shop_continue(state)
      assert.is_true(cont.ok)
      assert.are.equal("next_blind", cont.event)
      assert.is_nil(state.shop)
      assert.are.equal(2, state.blind_index)
    end)

    it("supports shop buy and reroll actions", function()
      local state = game.new_state(deterministic_rng)
      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)
      local clear = game.play_selected(state)
      assert.are.equal("shop", clear.event)

      state.money = 100
      local before_jokers = #state.jokers
      state.shop.offers[1] = {
        type = "joker",
        joker_key = "JOKER",
        rarity = "common",
        price = game.SHOP.prices.common,
      }

      local buy = game.shop_buy_offer(state, 1)
      assert.is_true(buy.ok)
      assert.are.equal("shop_bought", buy.event)
      assert.is_true(#state.jokers == before_jokers + 1)

      local reroll = game.shop_reroll(state)
      assert.is_true(reroll.ok)
      assert.are.equal("shop_rerolled", reroll.event)
      assert.is_true((state.shop.reroll_cost or 0) > game.SHOP.reroll_base_cost)
    end)

    it("supports card offers and keeps bought cards in run deck pool", function()
      local state = game.new_state(deterministic_rng)
      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)
      local clear = game.play_selected(state)
      assert.are.equal("shop", clear.event)

      state.money = 100
      state.shop.offers[1] = {
        type = "card",
        card = { rank = "A", suit = "S" },
        rarity = "card",
        price = 6,
      }

      local buy = game.shop_buy_offer(state, 1)
      assert.is_true(buy.ok)
      assert.are.equal("card", buy.offer_type)
      assert.are.equal(1, #state.owned_cards)
      assert.are.equal("A", state.owned_cards[1].rank)
      assert.are.equal("S", state.owned_cards[1].suit)

      local deck = game.build_run_deck(state)
      assert.are.equal(53, #deck)
    end)

    it("supports selling jokers and bought cards from shop", function()
      local state = game.new_state(deterministic_rng)
      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)
      local clear = game.play_selected(state)
      assert.are.equal("shop", clear.event)

      state.money = 0
      state.jokers = { "JOKER", "GREEDY_JOKER" }
      state.owned_cards = {
        { rank = "A", suit = "S" },
        { rank = 10, suit = "H" },
      }

      local sell_joker = game.shop_sell_joker(state, 2)
      assert.is_true(sell_joker.ok)
      assert.are.equal("shop_sold_joker", sell_joker.event)
      assert.are.equal(1, #state.jokers)
      assert.is_true(state.money > 0)

      local money_after_joker = state.money
      local sell_card = game.shop_sell_card(state, 1)
      assert.is_true(sell_card.ok)
      assert.are.equal("shop_sold_card", sell_card.event)
      assert.are.equal(1, #state.owned_cards)
      assert.is_true(state.money > money_after_joker)
    end)

    it("supports deck editing remove/upgrade/duplicate during shop", function()
      local state = game.new_state(deterministic_rng)
      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)
      local clear = game.play_selected(state)
      assert.are.equal("shop", clear.event)

      state.money = 100
      state.deck_cards = {
        { rank = 2, suit = "S" },
        { rank = "A", suit = "H" },
        { rank = 5, suit = "D" },
        { rank = 6, suit = "C" },
        { rank = 7, suit = "S" },
        { rank = 8, suit = "H" },
        { rank = 9, suit = "D" },
        { rank = 10, suit = "C" },
        { rank = "J", suit = "S" },
      }
      state.owned_cards = {}

      local before_size = #state.deck_cards
      local remove = game.shop_deck_remove(state)
      assert.is_true(remove.ok)
      assert.are.equal("shop_deck_removed", remove.event)
      assert.are.equal(before_size - 1, #state.deck_cards)

      local before_upgrade_rank = state.deck_cards[1].rank
      local upgrade = game.shop_deck_upgrade(state)
      assert.is_true(upgrade.ok)
      assert.are.equal("shop_deck_upgraded", upgrade.event)
      assert.are_not.equal(upgrade.before, upgrade.after)
      assert.are.equal("A", before_upgrade_rank)

      local before_dup = #state.deck_cards
      local duplicate = game.shop_deck_duplicate(state)
      assert.is_true(duplicate.ok)
      assert.are.equal("shop_deck_duplicated", duplicate.event)
      assert.are.equal(before_dup + 1, #state.deck_cards)
    end)
  end)

  describe("persistent per-run inventory", function()
    it("initializes schema-backed run inventory with aliases", function()
      local state = game.new_state(deterministic_rng)
      assert.is_truthy(state.inventory)
      assert.are.equal(game.INVENTORY_SCHEMA, state.inventory.schema)
      assert.are.equal(state.jokers, state.inventory.jokers)
      assert.are.equal(state.deck_cards, state.inventory.deck_cards)
      assert.are.equal(state.owned_cards, state.inventory.owned_cards)
    end)

    it("persists inventory across shop continue and blind progression", function()
      local state = game.new_state(deterministic_rng)
      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)
      local clear = game.play_selected(state)
      assert.are.equal("shop", clear.event)

      state.money = 100
      state.shop.offers[1] = {
        type = "joker",
        joker_key = "JOKER",
        rarity = "common",
        price = game.SHOP.prices.common,
      }
      state.shop.offers[2] = {
        type = "card",
        card = { rank = "A", suit = "S" },
        rarity = "card",
        price = 6,
      }

      local b1 = game.shop_buy_offer(state, 1)
      assert.is_true(b1.ok)
      local b2 = game.shop_buy_offer(state, 2)
      assert.is_true(b2.ok)
      assert.are.equal(1, #state.jokers)
      assert.are.equal(1, #state.owned_cards)

      local cont = game.shop_continue(state)
      assert.is_true(cont.ok)
      assert.are.equal("next_blind", cont.event)
      assert.are.equal(1, #state.jokers)
      assert.are.equal(1, #state.owned_cards)
      assert.is_truthy(state.inventory)
      assert.are.equal(1, state.inventory.schema)
    end)

    it("resets inventory model on new run", function()
      local state = game.new_state(deterministic_rng)
      state.jokers[#state.jokers + 1] = "JOKER"
      state.owned_cards[#state.owned_cards + 1] = { rank = "A", suit = "S" }
      state.deck_cards[#state.deck_cards + 1] = { rank = "K", suit = "H" }
      state.money = 77
      game.new_run(state)

      assert.are.equal(0, #state.jokers)
      assert.are.equal(0, #state.owned_cards)
      assert.are.equal(52, #state.deck_cards)
      assert.are.equal(0, state.money)
      assert.are.equal(game.INVENTORY_SCHEMA, state.inventory.schema)
      local snap = game.inventory_snapshot(state)
      assert.are.equal(0, snap.earned)
      assert.are.equal(0, snap.spent)
      assert.are.equal(0, snap.history_size)
    end)

    it("tracks earnings/spending in inventory ledger", function()
      local state = game.new_state(deterministic_rng)
      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)
      local clear = game.play_selected(state)
      assert.are.equal("shop", clear.event)
      assert.is_true((state.money or 0) > 0)

      state.shop.offers[1] = {
        type = "joker",
        joker_key = "JOKER",
        rarity = "common",
        price = 2,
      }
      local buy = game.shop_buy_offer(state, 1)
      assert.is_true(buy.ok)

      local snap = game.inventory_snapshot(state)
      assert.is_true((snap.earned or 0) > 0)
      assert.is_true((snap.spent or 0) > 0)
      assert.is_true((snap.history_size or 0) >= 2)
    end)
  end)

  describe("shop expected value hints", function()
    it("returns EV payloads for core shop actions", function()
      local state = game.new_state(deterministic_rng)
      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)
      local clear = game.play_selected(state)
      assert.are.equal("shop", clear.event)

      state.money = 100
      state.shop.offers[1] = {
        type = "joker",
        joker_key = "JOKER",
        rarity = "common",
        price = game.SHOP.prices.common,
      }
      state.shop.offers[2] = {
        type = "card",
        card = { rank = "A", suit = "S" },
        rarity = "card",
        price = 6,
      }

      local buy_joker = game.shop_expected_value(state, { action = "buy_offer", offer = state.shop.offers[1] })
      assert.is_truthy(buy_joker)
      assert.is_truthy(buy_joker.combined)
      assert.is_truthy(buy_joker.verdict)

      local buy_card = game.shop_expected_value(state, { action = "buy_offer", offer = state.shop.offers[2] })
      assert.is_truthy(buy_card)
      assert.is_truthy(buy_card.combined)

      local reroll = game.shop_expected_value(state, { action = "reroll", cost = state.shop.reroll_cost })
      assert.is_truthy(reroll)
      assert.is_truthy(reroll.combined)

      state.jokers = { "JOKER" }
      state.owned_cards = { { rank = "K", suit = "H" } }
      local sell_joker = game.shop_expected_value(state, { action = "sell_joker", slot = 1 })
      local sell_card = game.shop_expected_value(state, { action = "sell_card", slot = 1 })
      assert.is_truthy(sell_joker.combined)
      assert.is_truthy(sell_card.combined)
    end)
  end)

  describe("rank_to_value", function()
    it("maps numeric ranks to themselves", function()
      for _, r in ipairs({ 2, 3, 4, 5, 6, 7, 8, 9, 10 }) do
        assert.are.equal(r, game.rank_to_value(r))
      end
    end)

    it("maps face cards correctly", function()
      assert.are.equal(11, game.rank_to_value("J"))
      assert.are.equal(12, game.rank_to_value("Q"))
      assert.are.equal(13, game.rank_to_value("K"))
    end)

    it("maps Ace to 14 explicitly", function()
      assert.are.equal(14, game.rank_to_value("A"))
    end)

    it("returns 0 for unknown rank strings", function()
      assert.are.equal(0, game.rank_to_value("X"))
      assert.are.equal(0, game.rank_to_value(""))
    end)
  end)

  describe("EV calculation helpers", function()
    it("score_ev_for_card values Aces highest", function()
      local state = game.new_state(deterministic_rng)
      -- Use shop_expected_value to exercise score_ev_for_card indirectly
      local ace_ev = game.shop_expected_value(state, {
        action = "buy_offer",
        offer = { type = "card", card = { rank = "A", suit = "S" }, price = 4 },
      })
      local two_ev = game.shop_expected_value(state, {
        action = "buy_offer",
        offer = { type = "card", card = { rank = 2, suit = "S" }, price = 4 },
      })
      assert.is_true(ace_ev.score_ev > two_ev.score_ev)
    end)

    it("score_ev_for_joker scales with rarity", function()
      local state = game.new_state(deterministic_rng)
      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)
      game.play_selected(state)
      state.money = 100

      local common_ev = game.shop_expected_value(state, {
        action = "buy_offer",
        offer = { type = "joker", joker_key = "JOKER", rarity = "common", price = 6 },
      })
      -- Greedy Joker is uncommon with formula "+3 Mult"
      local uncommon_ev = game.shop_expected_value(state, {
        action = "buy_offer",
        offer = { type = "joker", joker_key = "GREEDY_JOKER", rarity = "uncommon", price = 8 },
      })
      assert.is_true(uncommon_ev.score_ev > common_ev.score_ev)
    end)

    it("normalize_ev produces correct verdicts", function()
      -- Good: buy a rare joker cheaply
      local state = game.new_state(deterministic_rng)
      state.score = game.current_target(state) - 1
      game.toggle_selection(state, 1)
      game.play_selected(state)
      state.money = 100

      local good = game.shop_expected_value(state, {
        action = "buy_offer",
        offer = { type = "joker", joker_key = "FLUSH_MASTER", rarity = "rare", price = 1 },
      })
      assert.are.equal("good", good.verdict)
    end)

    it("EV tunables load from config", function()
      local defaults = config.defaults()
      assert.is_truthy(defaults.ev)
      assert.are.equal(8, defaults.ev.card_base_offset)
      assert.are.equal(1.3, defaults.ev.card_rank_weight)
      assert.are.equal(1.5, defaults.ev.ace_bonus)
      assert.are.equal(4, defaults.ev.rarity_bonus.common)
      assert.are.equal(7, defaults.ev.rarity_bonus.uncommon)
      assert.are.equal(11, defaults.ev.rarity_bonus.rare)
    end)
  end)

  describe("config-driven messages", function()
    it("new_run message uses MAX_SELECT not hardcoded 5", function()
      local state = game.new_state(deterministic_rng)
      game.new_run(state)
      assert.is_truthy(state.message:find(tostring(game.MAX_SELECT)))
    end)

    it("max jokers message uses MAX_JOKERS not hardcoded 5", function()
      local state = game.new_state(deterministic_rng)
      -- Fill all joker slots
      for i = 1, game.MAX_JOKERS do
        state.jokers[i] = "JOKER"
      end
      local result = game.add_joker(state, "JOKER")
      assert.is_false(result.ok)
      assert.is_truthy(result.message:find(tostring(game.MAX_JOKERS)))
    end)
  end)
end)
