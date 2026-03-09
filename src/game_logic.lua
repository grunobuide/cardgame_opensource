local M = {}
local Config = require("config.init")

local function apply_tunables(tunables)
  local cards = tunables.cards or {}
  local run = tunables.run or {}
  M.CONFIG = tunables
  M.SUITS = cards.suits or { "S", "H", "D", "C" }
  M.RANKS = cards.ranks or { 2, 3, 4, 5, 6, 7, 8, 9, 10, "J", "Q", "K", "A" }
  M.ANTE_TARGETS = run.ante_targets or { 200, 400, 700 }
  M.MAX_ANTE = #M.ANTE_TARGETS
  M.BLINDS = tunables.blinds or {
    { id = "small", label = "Small Blind", target_mult = 1.0 },
    { id = "big", label = "Big Blind", target_mult = 1.65 },
    { id = "boss", label = "Boss Blind", target_mult = 2.35 },
  }
  M.BLIND_PAYOUTS = tunables.payouts or { small = 4, big = 7, boss = 12 }
  M.SHOP = tunables.shop or {}
  M.STARTING_HANDS = run.starting_hands or 5
  M.STARTING_DISCARDS = run.starting_discards or 2
  M.HAND_SIZE = run.hand_size or 8
  M.MAX_SELECT = run.max_select or 5
  M.MAX_JOKERS = run.max_jokers or 5
  M.MAX_CONSUMABLES = run.max_consumables or 2
  M.HAND_LEVEL_BONUS = tunables.hand_level_bonus or { chips_per_level = 10, mult_per_level = 1 }
  M.ENHANCEMENTS = tunables.enhancements or { foil_chips = 50, holo_mult = 10, poly_x_mult = 1.5 }
  M.INVENTORY_SCHEMA = ((tunables.inventory or {}).schema) or 1
  M.EV = tunables.ev or {}
end

function M.load_tunables(overrides)
  local tunables = Config.load(overrides)
  apply_tunables(tunables)
  return tunables
end

M.load_tunables()

M.HAND_TYPES = {
  HIGH_CARD = { id = "HIGH_CARD", label = "High Card", chips = 5, mult = 1 },
  PAIR = { id = "PAIR", label = "Pair", chips = 10, mult = 2 },
  TWO_PAIR = { id = "TWO_PAIR", label = "Two Pair", chips = 20, mult = 2 },
  THREE_KIND = { id = "THREE_KIND", label = "Three of a Kind", chips = 30, mult = 3 },
  STRAIGHT = { id = "STRAIGHT", label = "Straight", chips = 30, mult = 4 },
  FLUSH = { id = "FLUSH", label = "Flush", chips = 35, mult = 4 },
  FULL_HOUSE = { id = "FULL_HOUSE", label = "Full House", chips = 40, mult = 4 },
  FOUR_KIND = { id = "FOUR_KIND", label = "Four of a Kind", chips = 60, mult = 7 },
  STRAIGHT_FLUSH = { id = "STRAIGHT_FLUSH", label = "Straight Flush", chips = 100, mult = 8 },
  ROYAL_FLUSH = { id = "ROYAL_FLUSH", label = "Royal Flush", chips = 150, mult = 10 },
}

local function default_rng(min, max)
  return math.random(min, max)
end

local function normalize_seed(seed)
  local text = tostring(seed or "")
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  return text
end

function M.make_seeded_rng(seed)
  local text = normalize_seed(seed)
  if text == "" then
    text = "default"
  end

  local state = 2166136261
  for i = 1, #text do
    state = (state * 16777619 + text:byte(i)) % 4294967296
  end
  if state == 0 then
    state = 1
  end

  return function(min, max)
    state = (1664525 * state + 1013904223) % 4294967296
    local span = (max - min + 1)
    local value = min + math.floor((state / 4294967296) * span)
    if value > max then
      value = max
    end
    return value
  end
end

local function to_suit_code(suit)
  if suit == "S" or suit == "H" or suit == "D" or suit == "C" then
    return suit
  end
  if suit == "♠" then
    return "S"
  end
  if suit == "♥" then
    return "H"
  end
  if suit == "♦" then
    return "D"
  end
  if suit == "♣" then
    return "C"
  end
  return suit
end

local function clone_card(card)
  return { suit = to_suit_code(card.suit), rank = card.rank }
end

local function card_label(card)
  return ("%s%s"):format(tostring(card.rank), tostring(to_suit_code(card.suit)))
end

local function card_offer_price(card)
  if not card then
    return M.SHOP.prices.card_base
  end
  local value = M.rank_to_value(card.rank)
  local premium = 0
  if value >= 14 then
    premium = 2
  elseif value >= 11 then
    premium = 1
  end
  return (M.SHOP.prices.card_base or 4) + premium
end

local function joker_sell_price(joker_key)
  local joker = M.JOKERS[joker_key]
  local rarity = joker and joker.rarity or "common"
  local buy_price = M.SHOP.prices[rarity] or M.SHOP.prices.common
  return math.max(1, math.floor((buy_price * (M.SHOP.sell_ratio or 0.5)) + 0.5))
end

local function card_sell_price(card)
  local buy_price = card_offer_price(card)
  return math.max(1, math.floor((buy_price * (M.SHOP.sell_ratio or 0.5)) + 0.5))
end

local function clamp(value, min_v, max_v)
  if value < min_v then
    return min_v
  end
  if value > max_v then
    return max_v
  end
  return value
end

local function parse_formula_hint(formula)
  local text = tostring(formula or "")
  local chips = 0
  local mult = 0
  for number in text:gmatch("%+(%d+)%s*[Cc]") do
    chips = chips + tonumber(number)
  end
  for number in text:gmatch("%+(%d+)%s*[Mm]") do
    mult = mult + tonumber(number)
  end
  if chips == 0 and mult == 0 then
    local fallback = 0
    for number in text:gmatch("%+(%d+)") do
      fallback = fallback + tonumber(number)
    end
    mult = fallback
  end
  return chips, mult
end

local function score_ev_for_card(card)
  local ev = M.EV
  local value = M.rank_to_value(card.rank)
  local base = (value - (ev.card_base_offset or 8)) * (ev.card_rank_weight or 1.3)
  if card.rank == "A" then
    base = base + (ev.ace_bonus or 1.5)
  elseif card.rank == "K" or card.rank == "Q" or card.rank == "J" then
    base = base + (ev.face_bonus or 0.6)
  end
  return base
end

local function score_ev_for_joker(joker)
  if not joker then
    return 0
  end
  local ev = M.EV
  local rarity_bonuses = ev.rarity_bonus or { common = 4, uncommon = 7, rare = 11 }
  local rarity_bonus = rarity_bonuses[joker.rarity] or rarity_bonuses.common or 4
  local chips, mult = parse_formula_hint(joker.formula)
  local formula_bonus = (chips * (ev.chip_weight or 0.14)) + (mult * (ev.mult_weight or 2.1))
  return rarity_bonus + formula_bonus
end

local function normalize_ev(score_ev, money_ev)
  local ev = M.EV
  local combined = score_ev + (money_ev * (ev.money_weight or 1.1))
  local verdict = "neutral"
  if combined >= (ev.verdict_good or 2) then
    verdict = "good"
  elseif combined <= (ev.verdict_risky or -2) then
    verdict = "risky"
  end
  return {
    score_ev = math.floor(score_ev * 10 + 0.5) / 10,
    money_ev = math.floor(money_ev * 10 + 0.5) / 10,
    combined = math.floor(combined * 10 + 0.5) / 10,
    verdict = verdict,
  }
end

local function find_card_index_by_ref(cards, target)
  for i, card in ipairs(cards or {}) do
    if card == target then
      return i
    end
  end
  return nil
end

local function find_card_index_by_value(cards, target)
  if not target then
    return nil
  end
  local suit = to_suit_code(target.suit)
  for i, card in ipairs(cards or {}) do
    if card.rank == target.rank and to_suit_code(card.suit) == suit then
      return i
    end
  end
  return nil
end

local function next_rank(rank)
  for i, value in ipairs(M.RANKS) do
    if value == rank then
      return M.RANKS[math.min(#M.RANKS, i + 1)]
    end
  end
  return rank
end

local function sort_numeric(values)
  table.sort(values, function(a, b)
    return a < b
  end)
end

local function selected_indices(state)
  local out = {}
  for index, is_selected in pairs(state.selected) do
    if is_selected then
      out[#out + 1] = index
    end
  end
  table.sort(out)
  return out
end

local function copy_cards(cards)
  local out = {}
  for i, card in ipairs(cards or {}) do
    out[i] = clone_card(card)
  end
  return out
end

local function shuffle_cards(cards, rnd)
  local rng = rnd or default_rng
  for i = #cards, 2, -1 do
    local j = rng(1, i)
    cards[i], cards[j] = cards[j], cards[i]
  end
  return cards
end

local function sync_inventory_aliases(state)
  if not state.inventory then
    return
  end
  state.jokers = state.inventory.jokers
  state.deck_cards = state.inventory.deck_cards
  state.owned_cards = state.inventory.owned_cards
end

function M.ensure_run_inventory(state)
  local inv = state.inventory
  if not inv then
    inv = {
      schema = M.INVENTORY_SCHEMA,
      next_event_index = 1,
      jokers = state.jokers or {},
      deck_cards = state.deck_cards or M.build_base_deck(),
      owned_cards = state.owned_cards or {},
      ledger = {
        earned = 0,
        spent = 0,
      },
      history = {},
    }
    state.inventory = inv
  else
    inv.schema = inv.schema or M.INVENTORY_SCHEMA
    inv.next_event_index = inv.next_event_index or 1
    if state.jokers and state.jokers ~= inv.jokers then
      inv.jokers = state.jokers
    end
    if state.deck_cards and state.deck_cards ~= inv.deck_cards then
      inv.deck_cards = state.deck_cards
    end
    if state.owned_cards and state.owned_cards ~= inv.owned_cards then
      inv.owned_cards = state.owned_cards
    end
    inv.jokers = inv.jokers or {}
    inv.deck_cards = inv.deck_cards or M.build_base_deck()
    inv.owned_cards = inv.owned_cards or {}
    inv.ledger = inv.ledger or { earned = 0, spent = 0 }
    inv.history = inv.history or {}
  end
  sync_inventory_aliases(state)
  return state.inventory
end

function M.init_run_inventory(state)
  state.inventory = {
    schema = M.INVENTORY_SCHEMA,
    next_event_index = 1,
    jokers = {},
    deck_cards = M.build_base_deck(),
    owned_cards = {},
    ledger = {
      earned = 0,
      spent = 0,
    },
    history = {},
  }
  sync_inventory_aliases(state)
  return state.inventory
end

local function record_inventory_event(state, event, payload)
  local inv = M.ensure_run_inventory(state)
  local index = inv.next_event_index or (#inv.history + 1)
  inv.next_event_index = index + 1
  inv.history[#inv.history + 1] = {
    index = index,
    event = event,
    ante = state.ante or 1,
    blind_index = state.blind_index or 1,
    money = state.money or 0,
    payload = payload or {},
  }
end

local function inventory_earn(state, amount, event, payload)
  local gain = math.max(0, tonumber(amount or 0) or 0)
  state.money = (state.money or 0) + gain
  local inv = M.ensure_run_inventory(state)
  inv.ledger.earned = (inv.ledger.earned or 0) + gain
  record_inventory_event(state, event, payload or { amount = gain })
  return gain
end

local function inventory_spend(state, amount, event, payload)
  local cost = math.max(0, tonumber(amount or 0) or 0)
  state.money = (state.money or 0) - cost
  local inv = M.ensure_run_inventory(state)
  inv.ledger.spent = (inv.ledger.spent or 0) + cost
  record_inventory_event(state, event, payload or { amount = cost })
  return cost
end

function M.inventory_snapshot(state)
  local inv = M.ensure_run_inventory(state)
  local earned = inv.ledger.earned or 0
  local spent = inv.ledger.spent or 0
  return {
    schema = inv.schema or M.INVENTORY_SCHEMA,
    jokers = #inv.jokers,
    deck_cards = #inv.deck_cards,
    owned_cards = #inv.owned_cards,
    earned = earned,
    spent = spent,
    net = earned - spent,
    history_size = #inv.history,
  }
end

function M.selected_count(state)
  local count = 0
  for _, is_selected in pairs(state.selected) do
    if is_selected then
      count = count + 1
    end
  end
  return count
end

function M.clear_selection(state)
  state.selected = {}
end

function M.build_base_deck()
  local deck = {}

  for _, suit in ipairs(M.SUITS) do
    for _, rank in ipairs(M.RANKS) do
      deck[#deck + 1] = { suit = suit, rank = rank }
    end
  end

  return deck
end

function M.build_deck(rng, extra_cards)
  local rnd = rng or default_rng
  local deck = M.build_base_deck()

  if extra_cards then
    for _, card in ipairs(extra_cards) do
      deck[#deck + 1] = clone_card(card)
    end
  end

  return shuffle_cards(deck, rnd)
end

function M.build_run_deck(state)
  M.ensure_run_inventory(state)
  if state.deck_cards and #state.deck_cards > 0 then
    return shuffle_cards(copy_cards(state.deck_cards), state.rng)
  end
  return M.build_deck(state.rng, state.owned_cards)
end

function M.target_score(ante)
  local target_ante = ante or 1
  if target_ante <= #M.ANTE_TARGETS then
    return M.ANTE_TARGETS[target_ante]
  end
  return M.ANTE_TARGETS[#M.ANTE_TARGETS] + (target_ante - #M.ANTE_TARGETS) * 300
end

function M.current_blind(state)
  local idx = state.blind_index or 1
  return M.BLINDS[idx] or M.BLINDS[1]
end

function M.current_target(state)
  local base = M.target_score(state.ante)
  local blind = M.current_blind(state)
  local target = math.floor((base * blind.target_mult) + 0.5)
  -- Boss blind: THE_WALL doubles target
  if state.boss_blind_key == "THE_WALL" and blind.id == "boss" then
    target = target * 2
  end
  return target
end

function M.blind_clear_payout(state, blind)
  local target_blind = blind or M.current_blind(state)
  local base = M.BLIND_PAYOUTS[target_blind.id] or 0
  local ante_bonus = math.max(0, (state.ante or 1) - 1) * 2
  return base + ante_bonus
end

function M.award_blind_clear_payout(state, blind)
  local payout = M.blind_clear_payout(state, blind)
  inventory_earn(state, payout, "blind_clear_payout", {
    blind = (blind or M.current_blind(state)).id,
    amount = payout,
  })
  return payout
end

local function shop_offer_from_joker_key(state, joker_key)
  local joker = M.JOKERS[joker_key]
  if not joker then
    return nil
  end
  local rarity = joker.rarity or "common"
  local price = M.SHOP.prices[rarity] or M.SHOP.prices.common
  return {
    type = "joker",
    joker_key = joker_key,
    price = price,
    rarity = rarity,
  }
end

local function shop_offer_from_card(state)
  local rank = M.RANKS[state.rng(1, #M.RANKS)]
  local suit = M.SUITS[state.rng(1, #M.SUITS)]
  local card = { rank = rank, suit = suit }
  return {
    type = "card",
    card = card,
    price = card_offer_price(card),
    rarity = "card",
  }
end

function M.roll_shop_offers(state, count)
  local total = count or M.SHOP.offer_count
  local joker_keys = {}
  for joker_key, _ in pairs(M.JOKERS) do
    joker_keys[#joker_keys + 1] = joker_key
  end
  table.sort(joker_keys)

  local consumable_keys = {}
  for ckey, _ in pairs(M.CONSUMABLES) do
    consumable_keys[#consumable_keys + 1] = ckey
  end
  table.sort(consumable_keys)

  local offers = {}
  for _ = 1, total do
    local offer
    local roll = state.rng(1, 100)
    local joker_weight = M.SHOP.joker_offer_weight or 50
    local consumable_weight = M.SHOP.consumable_offer_weight or 20
    if #joker_keys == 0 and #consumable_keys == 0 then
      offer = shop_offer_from_card(state)
    elseif roll <= joker_weight and #joker_keys > 0 then
      local key = joker_keys[state.rng(1, #joker_keys)]
      offer = shop_offer_from_joker_key(state, key)
    elseif roll <= joker_weight + consumable_weight and #consumable_keys > 0 then
      local key = consumable_keys[state.rng(1, #consumable_keys)]
      local consumable = M.CONSUMABLES[key]
      offer = {
        type = "consumable",
        consumable_key = key,
        price = consumable.category == "planet" and 5 or 6,
        rarity = consumable.rarity or "common",
      }
    else
      offer = shop_offer_from_card(state)
    end
    offers[#offers + 1] = offer
  end
  return offers
end

local function average_joker_offer_ev()
  local total = 0
  local count = 0
  for _, joker in pairs(M.JOKERS) do
    total = total + score_ev_for_joker(joker)
    count = count + 1
  end
  if count == 0 then
    return 0
  end
  return total / count
end

local function average_card_offer_ev()
  local total = 0
  local count = 0
  for _, rank in ipairs(M.RANKS) do
    total = total + score_ev_for_card({ rank = rank, suit = "S" })
    count = count + 1
  end
  if count == 0 then
    return 0
  end
  return total / count
end

function M.shop_expected_value(state, subject)
  M.ensure_run_inventory(state)
  local info = subject or {}
  local action = info.action or "buy_offer"

  if action == "buy_offer" then
    local offer = info.offer
    if not offer then
      return normalize_ev(0, 0)
    end
    if offer.type == "card" then
      local score_ev = score_ev_for_card(offer.card or { rank = 8, suit = "S" })
      local money_ev = card_sell_price(offer.card or { rank = 8, suit = "S" }) - (offer.price or 0)
      local out = normalize_ev(score_ev, money_ev)
      out.label = "Card Offer"
      return out
    end
    local joker = M.JOKERS[offer.joker_key]
    local score_ev = score_ev_for_joker(joker)
    local money_ev = joker_sell_price(offer.joker_key) - (offer.price or 0)
    local out = normalize_ev(score_ev, money_ev)
    out.label = "Joker Offer"
    return out
  end

  if action == "reroll" then
    local cost = tonumber(info.cost) or ((state.shop and state.shop.reroll_cost) or M.SHOP.reroll_base_cost)
    local joker_weight = clamp((M.SHOP.joker_offer_weight or 70) / 100, 0, 1)
    local card_weight = 1 - joker_weight
    local avg_offer_score = (average_joker_offer_ev() * joker_weight) + (average_card_offer_ev() * card_weight)
    local score_ev = avg_offer_score * (M.EV.reroll_score_scale or 1.2)
    local money_ev = -cost
    local out = normalize_ev(score_ev, money_ev)
    out.label = "Reroll"
    return out
  end

  if action == "sell_joker" then
    local slot = tonumber(info.slot or 0)
    local joker_key = state.jokers[slot]
    if not joker_key then
      return normalize_ev(0, 0)
    end
    local joker = M.JOKERS[joker_key]
    local score_ev = -score_ev_for_joker(joker) * (M.EV.sell_joker_penalty or 0.85)
    local money_ev = joker_sell_price(joker_key)
    local out = normalize_ev(score_ev, money_ev)
    out.label = "Sell Joker"
    return out
  end

  if action == "sell_card" then
    local slot = tonumber(info.slot or 0)
    local card = state.owned_cards[slot]
    if not card then
      return normalize_ev(0, 0)
    end
    local score_ev = -score_ev_for_card(card) * (M.EV.sell_card_penalty or 0.65)
    local money_ev = card_sell_price(card)
    local out = normalize_ev(score_ev, money_ev)
    out.label = "Sell Card"
    return out
  end

  if action == "deck_remove" then
    local cost = (M.SHOP.deck_edit_costs and M.SHOP.deck_edit_costs.remove) or 3
    local over_base = math.max(0, #state.deck_cards - 52)
    local score_ev = (M.EV.deck_remove_base or 0.8) + (over_base * (M.EV.deck_remove_over or 0.15))
    local money_ev = -cost
    local out = normalize_ev(score_ev, money_ev)
    out.label = "Deck Remove"
    return out
  end

  if action == "deck_upgrade" then
    local cost = (M.SHOP.deck_edit_costs and M.SHOP.deck_edit_costs.upgrade) or 4
    local score_ev = M.EV.deck_upgrade_ev or 3.6
    local money_ev = -cost
    local out = normalize_ev(score_ev, money_ev)
    out.label = "Deck Upgrade"
    return out
  end

  if action == "deck_duplicate" then
    local cost = (M.SHOP.deck_edit_costs and M.SHOP.deck_edit_costs.duplicate) or 5
    local avg_rank_ev = average_card_offer_ev()
    local score_ev = (M.EV.deck_dup_base or 1.2) + (avg_rank_ev * (M.EV.deck_dup_avg_weight or 0.45))
    local money_ev = -cost
    local out = normalize_ev(score_ev, money_ev)
    out.label = "Deck Duplicate"
    return out
  end

  return normalize_ev(0, 0)
end

function M.open_shop(state, clear_event)
  M.ensure_run_inventory(state)
  state.shop = {
    active = true,
    offers = M.roll_shop_offers(state, M.SHOP.offer_count),
    reroll_cost = M.SHOP.reroll_base_cost,
    clear_event = clear_event,
  }
end

function M.shop_buy_offer(state, index)
  M.ensure_run_inventory(state)
  local shop = state.shop
  if not shop or not shop.active then
    return { ok = false, reason = "shop_inactive", message = "Shop is not open." }
  end
  local offer = shop.offers[index]
  if not offer then
    return { ok = false, reason = "invalid_offer", message = "Invalid shop offer." }
  end
  if (state.money or 0) < offer.price then
    return { ok = false, reason = "insufficient_money", message = "Not enough money." }
  end

  if offer.type == "joker" and #state.jokers >= M.MAX_JOKERS then
    return { ok = false, reason = "max_jokers", message = ("Max %d Jokers!"):format(M.MAX_JOKERS) }
  end
  if offer.type == "consumable" and #(state.consumables or {}) >= M.MAX_CONSUMABLES then
    return { ok = false, reason = "max_consumables", message = ("Max %d Consumables!"):format(M.MAX_CONSUMABLES) }
  end

  inventory_spend(state, offer.price, "shop_buy", {
    offer_type = offer.type,
    index = index,
    price = offer.price,
  })
  local event = "shop_bought"
  local payload = { ok = true, event = event, cost = offer.price, money = state.money }

  if offer.type == "joker" then
    state.jokers[#state.jokers + 1] = offer.joker_key
    local joker_name = M.JOKERS[offer.joker_key] and M.JOKERS[offer.joker_key].name or offer.joker_key
    payload.joker_key = offer.joker_key
    payload.offer_type = "joker"
    state.message = ("Bought %s for $%d."):format(joker_name, offer.price)
  elseif offer.type == "consumable" then
    state.consumables = state.consumables or {}
    state.consumables[#state.consumables + 1] = offer.consumable_key
    local cname = M.CONSUMABLES[offer.consumable_key] and M.CONSUMABLES[offer.consumable_key].name or offer.consumable_key
    payload.consumable_key = offer.consumable_key
    payload.offer_type = "consumable"
    state.message = ("Bought %s for $%d."):format(cname, offer.price)
  else
    local card = clone_card(offer.card)
    state.deck_cards[#state.deck_cards + 1] = card
    state.owned_cards[#state.owned_cards + 1] = card
    payload.card = card
    payload.offer_type = "card"
    state.message = ("Bought card %s for $%d."):format(card_label(card), offer.price)
  end

  shop.offers[index] = nil
  return payload
end

function M.shop_reroll(state)
  M.ensure_run_inventory(state)
  local shop = state.shop
  if not shop or not shop.active then
    return { ok = false, reason = "shop_inactive", message = "Shop is not open." }
  end
  local cost = shop.reroll_cost or M.SHOP.reroll_base_cost
  if (state.money or 0) < cost then
    return { ok = false, reason = "insufficient_money", message = "Not enough money to reroll." }
  end

  inventory_spend(state, cost, "shop_reroll", { cost = cost })
  shop.offers = M.roll_shop_offers(state, M.SHOP.offer_count)
  shop.reroll_cost = cost + M.SHOP.reroll_cost_step
  state.message = ("Shop rerolled for $%d."):format(cost)
  return { ok = true, event = "shop_rerolled", cost = cost, next_reroll_cost = shop.reroll_cost, money = state.money }
end

function M.shop_deck_remove(state)
  M.ensure_run_inventory(state)
  local shop = state.shop
  if not shop or not shop.active then
    return { ok = false, reason = "shop_inactive", message = "Shop is not open." }
  end

  local cost = (M.SHOP.deck_edit_costs and M.SHOP.deck_edit_costs.remove) or 3
  if (state.money or 0) < cost then
    return { ok = false, reason = "insufficient_money", message = "Not enough money to remove a card." }
  end
  if #state.deck_cards <= M.HAND_SIZE then
    return { ok = false, reason = "deck_too_small", message = "Deck is already at minimum size." }
  end

  local idx = state.rng(1, #state.deck_cards)
  local removed = table.remove(state.deck_cards, idx)
  local owned_idx = find_card_index_by_ref(state.owned_cards, removed)
  if owned_idx then
    table.remove(state.owned_cards, owned_idx)
  end
  inventory_spend(state, cost, "shop_deck_remove", { cost = cost, card = card_label(removed) })
  state.message = ("Removed %s from deck for $%d."):format(card_label(removed), cost)
  return {
    ok = true,
    event = "shop_deck_removed",
    card = removed,
    cost = cost,
    money = state.money,
    deck_size = #state.deck_cards,
  }
end

function M.shop_deck_upgrade(state)
  M.ensure_run_inventory(state)
  local shop = state.shop
  if not shop or not shop.active then
    return { ok = false, reason = "shop_inactive", message = "Shop is not open." }
  end

  local cost = (M.SHOP.deck_edit_costs and M.SHOP.deck_edit_costs.upgrade) or 4
  if (state.money or 0) < cost then
    return { ok = false, reason = "insufficient_money", message = "Not enough money to upgrade a card." }
  end

  local candidates = {}
  for i, card in ipairs(state.deck_cards) do
    if card.rank ~= "A" then
      candidates[#candidates + 1] = i
    end
  end
  if #candidates == 0 then
    return { ok = false, reason = "no_upgrade_targets", message = "No cards available to upgrade." }
  end

  local target_index = candidates[state.rng(1, #candidates)]
  local card = state.deck_cards[target_index]
  local before = card_label(card)
  card.rank = next_rank(card.rank)
  local after = card_label(card)
  inventory_spend(state, cost, "shop_deck_upgrade", { cost = cost, before = before, after = after })
  state.message = ("Upgraded %s -> %s for $%d."):format(before, after, cost)
  return {
    ok = true,
    event = "shop_deck_upgraded",
    before = before,
    after = after,
    cost = cost,
    money = state.money,
  }
end

function M.shop_deck_duplicate(state)
  M.ensure_run_inventory(state)
  local shop = state.shop
  if not shop or not shop.active then
    return { ok = false, reason = "shop_inactive", message = "Shop is not open." }
  end

  local cost = (M.SHOP.deck_edit_costs and M.SHOP.deck_edit_costs.duplicate) or 5
  if (state.money or 0) < cost then
    return { ok = false, reason = "insufficient_money", message = "Not enough money to duplicate a card." }
  end
  if #state.deck_cards == 0 then
    return { ok = false, reason = "empty_deck", message = "Deck is empty." }
  end

  local idx = state.rng(1, #state.deck_cards)
  local source = state.deck_cards[idx]
  local clone = clone_card(source)
  state.deck_cards[#state.deck_cards + 1] = clone
  inventory_spend(state, cost, "shop_deck_duplicate", { cost = cost, card = card_label(clone) })
  state.message = ("Duplicated %s for $%d."):format(card_label(clone), cost)
  return {
    ok = true,
    event = "shop_deck_duplicated",
    card = clone,
    cost = cost,
    money = state.money,
    deck_size = #state.deck_cards,
  }
end

function M.shop_sell_joker(state, index)
  M.ensure_run_inventory(state)
  local shop = state.shop
  if not shop or not shop.active then
    return { ok = false, reason = "shop_inactive", message = "Shop is not open." }
  end
  local i = tonumber(index or 0)
  if i <= 0 or i > #state.jokers then
    return { ok = false, reason = "invalid_sell_index", message = "Invalid Joker slot to sell." }
  end

  local joker_key = state.jokers[i]
  local price = joker_sell_price(joker_key)
  local joker_name = M.JOKERS[joker_key] and M.JOKERS[joker_key].name or joker_key
  table.remove(state.jokers, i)
  inventory_earn(state, price, "shop_sell_joker", { gain = price, joker_key = joker_key, slot = i })
  state.message = ("Sold %s for $%d."):format(joker_name, price)
  return {
    ok = true,
    event = "shop_sold_joker",
    joker_key = joker_key,
    slot = i,
    gain = price,
    money = state.money,
  }
end

function M.shop_sell_card(state, index)
  M.ensure_run_inventory(state)
  local shop = state.shop
  if not shop or not shop.active then
    return { ok = false, reason = "shop_inactive", message = "Shop is not open." }
  end
  local i = tonumber(index or 0)
  if i <= 0 or i > #state.owned_cards then
    return { ok = false, reason = "invalid_sell_index", message = "Invalid card slot to sell." }
  end

  local card = state.owned_cards[i]
  local price = card_sell_price(card)
  table.remove(state.owned_cards, i)
  local deck_idx = find_card_index_by_ref(state.deck_cards, card) or find_card_index_by_value(state.deck_cards, card)
  if deck_idx then
    table.remove(state.deck_cards, deck_idx)
  end
  inventory_earn(state, price, "shop_sell_card", { gain = price, card = card_label(card), slot = i })
  state.message = ("Sold card %s for $%d."):format(card_label(card), price)
  return {
    ok = true,
    event = "shop_sold_card",
    card = card,
    slot = i,
    gain = price,
    money = state.money,
  }
end

function M.shop_continue(state)
  local shop = state.shop
  if not shop or not shop.active then
    return { ok = false, reason = "shop_inactive", message = "Shop is not open." }
  end

  local clear_event = shop.clear_event
  state.shop = nil

  local event = clear_event
  if clear_event == "next_ante" then
    M.next_ante(state)
  elseif clear_event == "next_blind" then
    M.next_blind(state)
  else
    event = "shop_closed"
  end
  return { ok = true, event = event, money = state.money }
end

function M.rank_to_value(rank)
  if type(rank) == "number" then
    return rank
  end
  if rank == "A" then
    return 14
  end
  if rank == "J" then
    return 11
  end
  if rank == "Q" then
    return 12
  end
  if rank == "K" then
    return 13
  end
  return 0
end

function M.evaluate_hand(cards)
  if #cards == 0 then
    return M.HAND_TYPES.HIGH_CARD
  end

  local values = {}
  local suits = {}
  local count_by_value = {}

  for _, card in ipairs(cards) do
    local value = M.rank_to_value(card.rank)
    values[#values + 1] = value
    suits[#suits + 1] = to_suit_code(card.suit)
    count_by_value[value] = (count_by_value[value] or 0) + 1
  end

  sort_numeric(values)

  local counts = {}
  local unique_values = {}
  for value, count in pairs(count_by_value) do
    counts[#counts + 1] = count
    unique_values[#unique_values + 1] = value
  end
  table.sort(counts, function(a, b)
    return a > b
  end)
  sort_numeric(unique_values)

  local is_five_card_hand = (#cards == 5)
  local is_flush = false
  if is_five_card_hand then
    is_flush = true
    for i = 2, #suits do
      if suits[i] ~= suits[1] then
        is_flush = false
        break
      end
    end
  end

  local is_straight = false
  if is_five_card_hand and #unique_values == 5 then
    is_straight = (unique_values[5] - unique_values[1] == 4)
    if not is_straight then
      local wheel = { 2, 3, 4, 5, 14 }
      local is_wheel = true
      for i = 1, 5 do
        if unique_values[i] ~= wheel[i] then
          is_wheel = false
          break
        end
      end
      is_straight = is_wheel
    end
  end

  local is_royal = is_straight and is_flush
    and values[1] == 10
    and values[2] == 11
    and values[3] == 12
    and values[4] == 13
    and values[5] == 14

  if is_royal then
    return M.HAND_TYPES.ROYAL_FLUSH
  end
  if is_straight and is_flush then
    return M.HAND_TYPES.STRAIGHT_FLUSH
  end
  if counts[1] == 4 then
    return M.HAND_TYPES.FOUR_KIND
  end
  if counts[1] == 3 and counts[2] == 2 then
    return M.HAND_TYPES.FULL_HOUSE
  end
  if is_flush then
    return M.HAND_TYPES.FLUSH
  end
  if is_straight then
    return M.HAND_TYPES.STRAIGHT
  end
  if counts[1] == 3 then
    return M.HAND_TYPES.THREE_KIND
  end
  if counts[1] == 2 and counts[2] == 2 then
    return M.HAND_TYPES.TWO_PAIR
  end
  if counts[1] == 2 then
    return M.HAND_TYPES.PAIR
  end
  return M.HAND_TYPES.HIGH_CARD
end

M.JOKERS = {}
local next_joker_sprite_index = 1

function M.register_joker(key, definition)
  local def = definition or {}
  local sprite_index = def.sprite_index or next_joker_sprite_index
  if def.sprite_index == nil then
    next_joker_sprite_index = next_joker_sprite_index + 1
  end

  M.JOKERS[key] = {
    name = def.name or key,
    rarity = def.rarity or "common",
    formula = def.formula or "",
    image = def.image or "Joker.png",
    sprite_index = sprite_index,
    apply = def.apply or function()
      return {}
    end,
  }
end

M.register_joker("JOKER", {
  name = "Joker",
  rarity = "common",
  formula = "+4 Mult",
  image = "Joker.png",
  apply = function(_cards, _hand_type)
    return { mult = 4 }
  end,
})

M.register_joker("GREEDY_JOKER", {
  name = "Greedy Joker",
  rarity = "uncommon",
  formula = "+4 Mult if at least one Diamond is played",
  image = "Joker2.png",
  apply = function(cards, _hand_type)
    for _, card in ipairs(cards) do
      if to_suit_code(card.suit) == "D" then
        return { mult = 4 }
      end
    end
    return {}
  end,
})

M.register_joker("PAIR_JOKER", {
  name = "Pair Joker",
  rarity = "rare",
  formula = "+2 Mult x number of pairs in played cards",
  image = "Joker.png",
  apply = function(cards, _hand_type)
    local counts = {}
    for _, card in ipairs(cards) do
      local key = tostring(card.rank)
      counts[key] = (counts[key] or 0) + 1
    end
    local pair_count = 0
    for _, count in pairs(counts) do
      if count == 2 then
        pair_count = pair_count + 1
      end
    end
    return { mult = pair_count * 2 }
  end,
})

-- Suit triggers
M.register_joker("HEART_JOKER", {
  name = "Heart Joker",
  rarity = "common",
  formula = "+3 Mult per Heart in played hand",
  image = "Joker.png",
  apply = function(cards, _hand_type)
    local count = 0
    for _, card in ipairs(cards) do
      if to_suit_code(card.suit) == "H" then
        count = count + 1
      end
    end
    return { mult = count * 3 }
  end,
})

M.register_joker("CLUB_JOKER", {
  name = "Club Joker",
  rarity = "common",
  formula = "+10 Chips per Club in played hand",
  image = "Joker.png",
  apply = function(cards, _hand_type)
    local count = 0
    for _, card in ipairs(cards) do
      if to_suit_code(card.suit) == "C" then
        count = count + 1
      end
    end
    return { chips = count * 10 }
  end,
})

-- Rank triggers
M.register_joker("ACE_JOKER", {
  name = "Ace Joker",
  rarity = "uncommon",
  formula = "+6 Mult per Ace in played hand",
  image = "Joker2.png",
  apply = function(cards, _hand_type)
    local count = 0
    for _, card in ipairs(cards) do
      if M.rank_to_value(card.rank) == 14 then
        count = count + 1
      end
    end
    return { mult = count * 6 }
  end,
})

M.register_joker("FACE_JOKER", {
  name = "Face Joker",
  rarity = "common",
  formula = "+4 Chips per Jack, Queen, or King in played hand",
  image = "Joker.png",
  apply = function(cards, _hand_type)
    local count = 0
    for _, card in ipairs(cards) do
      local v = M.rank_to_value(card.rank)
      if v >= 11 and v <= 13 then
        count = count + 1
      end
    end
    return { chips = count * 4 }
  end,
})

-- Hand-type triggers
M.register_joker("FLUSH_MASTER", {
  name = "Flush Master",
  rarity = "rare",
  formula = "+30 Mult if hand is Flush or better",
  image = "Joker2.png",
  apply = function(_cards, hand_type)
    local flush_ids = {
      FLUSH = true, FULL_HOUSE = true, FOUR_KIND = true,
      STRAIGHT_FLUSH = true, ROYAL_FLUSH = true,
    }
    if flush_ids[hand_type.id] then
      return { mult = 30 }
    end
    return {}
  end,
})

M.register_joker("STRAIGHT_ARROW", {
  name = "Straight Arrow",
  rarity = "uncommon",
  formula = "+20 Mult if hand is a Straight or Straight Flush",
  image = "Joker2.png",
  apply = function(_cards, hand_type)
    if hand_type.id == "STRAIGHT" or hand_type.id == "STRAIGHT_FLUSH" then
      return { mult = 20 }
    end
    return {}
  end,
})

-- Count triggers
M.register_joker("STREET_RAT", {
  name = "Street Rat",
  rarity = "common",
  formula = "+2 Mult per card played",
  image = "Joker.png",
  apply = function(cards, _hand_type)
    return { mult = #cards * 2 }
  end,
})

M.register_joker("MINIMALIST", {
  name = "Minimalist",
  rarity = "rare",
  formula = "+20 Mult if exactly 1 card is played",
  image = "Joker2.png",
  apply = function(cards, _hand_type)
    if #cards == 1 then
      return { mult = 20 }
    end
    return {}
  end,
})

-- State-aware triggers
M.register_joker("HOARDER", {
  name = "Hoarder",
  rarity = "uncommon",
  formula = "+2 Mult per Joker owned",
  image = "Joker2.png",
  apply = function(_cards, _hand_type, state)
    local count = state and #state.jokers or 0
    return { mult = count * 2 }
  end,
})

M.register_joker("CONSERVATIVE", {
  name = "Conservative",
  rarity = "common",
  formula = "+2 Mult per discard remaining this blind",
  image = "Joker.png",
  apply = function(_cards, _hand_type, state)
    local remaining = state and state.discards or 0
    return { mult = remaining * 2 }
  end,
})

-- ============================================================
-- CONSUMABLE REGISTRY
-- ============================================================
M.CONSUMABLES = {}

function M.register_consumable(key, definition)
  local def = definition or {}
  M.CONSUMABLES[key] = {
    name = def.name or key,
    category = def.category or "tarot",
    rarity = def.rarity or "common",
    description = def.description or "",
    apply = def.apply or function() return {} end,
  }
end

-- Planet cards: upgrade a hand type by +1 level
local planet_defs = {
  { key = "MERCURY", name = "Mercury", hand = "PAIR" },
  { key = "VENUS", name = "Venus", hand = "THREE_KIND" },
  { key = "EARTH", name = "Earth", hand = "FULL_HOUSE" },
  { key = "MARS", name = "Mars", hand = "FLUSH" },
  { key = "JUPITER", name = "Jupiter", hand = "STRAIGHT" },
  { key = "SATURN", name = "Saturn", hand = "TWO_PAIR" },
  { key = "NEPTUNE", name = "Neptune", hand = "STRAIGHT_FLUSH" },
  { key = "PLUTO", name = "Pluto", hand = "HIGH_CARD" },
}

for _, pdef in ipairs(planet_defs) do
  M.register_consumable(pdef.key, {
    name = pdef.name,
    category = "planet",
    description = ("Level up %s (+%d chips, +%d mult per level)"):format(
      pdef.hand, 10, 1
    ),
    apply = function(state)
      state.hand_levels = state.hand_levels or {}
      state.hand_levels[pdef.hand] = (state.hand_levels[pdef.hand] or 0) + 1
      return { ok = true, message = ("%s leveled up %s!"):format(pdef.name, pdef.hand) }
    end,
  })
end

-- Tarot cards
M.register_consumable("THE_FOOL", {
  name = "The Fool",
  category = "tarot",
  description = "Copy the last played hand type as a consumable (if slot open).",
  apply = function(state)
    local last = state.last_hand_type
    if not last then
      return { ok = false, message = "No hand played yet." }
    end
    -- Find the matching planet card key
    for _, pdef in ipairs(planet_defs) do
      if pdef.hand == last then
        if #(state.consumables or {}) < M.MAX_CONSUMABLES then
          state.consumables[#state.consumables + 1] = pdef.key
          return { ok = true, message = ("The Fool created %s!"):format(pdef.name) }
        end
        return { ok = false, message = "Consumable slots full." }
      end
    end
    return { ok = true, message = "The Fool has no effect." }
  end,
})

M.register_consumable("HIGH_PRIESTESS", {
  name = "High Priestess",
  category = "tarot",
  description = "Draw +2 cards for this blind.",
  apply = function(state)
    M.draw_cards(state, 2)
    return { ok = true, message = "High Priestess drew 2 extra cards!" }
  end,
})

M.register_consumable("THE_HERMIT", {
  name = "The Hermit",
  category = "tarot",
  description = "Double your money (max +$20).",
  apply = function(state)
    local bonus = math.min(state.money, 20)
    state.money = state.money + bonus
    return { ok = true, message = ("The Hermit doubled money! +$%d"):format(bonus) }
  end,
})

M.register_consumable("THE_WHEEL", {
  name = "The Wheel",
  category = "tarot",
  description = "1-in-4 chance to add Foil to a random hand card.",
  apply = function(state)
    if #(state.hand or {}) == 0 then
      return { ok = false, message = "No cards in hand." }
    end
    local roll = state.rng(1, 4)
    if roll == 1 then
      local idx = state.rng(1, #state.hand)
      state.hand[idx].enhancement = "foil"
      return { ok = true, message = ("The Wheel granted Foil to %s!"):format(M.card_label(state.hand[idx])) }
    end
    return { ok = true, message = "The Wheel spun... no luck this time." }
  end,
})

function M.use_consumable(state, slot)
  if not state.consumables or not state.consumables[slot] then
    return { ok = false, reason = "no_consumable", message = "No consumable in that slot." }
  end
  local key = state.consumables[slot]
  local consumable = M.CONSUMABLES[key]
  if not consumable then
    return { ok = false, reason = "unknown_consumable", message = "Unknown consumable." }
  end
  local result = consumable.apply(state)
  if result and result.ok ~= false then
    table.remove(state.consumables, slot)
    state.message = result.message or ("Used %s."):format(consumable.name)
    return { ok = true, event = "consumable_used", consumable_key = key, message = state.message }
  end
  state.message = result and result.message or "Consumable had no effect."
  return { ok = false, reason = "apply_failed", message = state.message }
end

-- ============================================================
-- BOSS BLIND REGISTRY
-- ============================================================
M.BOSS_BLINDS = {}

function M.register_boss_blind(key, definition)
  local def = definition or {}
  M.BOSS_BLINDS[key] = {
    name = def.name or key,
    description = def.description or "",
    on_start = def.on_start or function() end,
    on_play = def.on_play or function() end,
    on_score = def.on_score or function(_state, projection) return projection end,
  }
end

M.register_boss_blind("THE_HOOK", {
  name = "The Hook",
  description = "Discards 2 random cards at blind start.",
  on_start = function(state)
    for _ = 1, 2 do
      if #state.hand > 1 then
        local idx = state.rng(1, #state.hand)
        table.remove(state.hand, idx)
      end
    end
    M.replenish_hand(state)
  end,
})

M.register_boss_blind("THE_WALL", {
  name = "The Wall",
  description = "Target score is doubled.",
  -- Effect applied via boss_target_mult in current_target
})

M.register_boss_blind("THE_FLINT", {
  name = "The Flint",
  description = "Base chips and mult are halved.",
  on_score = function(_state, projection)
    projection.base_chips = math.floor(projection.base_chips * 0.5)
    projection.base_mult = math.max(1, math.floor(projection.base_mult * 0.5))
    return projection
  end,
})

M.register_boss_blind("THE_MARK", {
  name = "The Mark",
  description = "Face cards are drawn face-down (hidden rank).",
  on_start = function(state)
    for _, card in ipairs(state.hand) do
      local val = M.rank_to_value(card.rank)
      if val >= 11 and val <= 13 then
        card.face_down = true
      end
    end
  end,
})

M.register_boss_blind("THE_PSYCHIC", {
  name = "The Psychic",
  description = "Must play exactly 5 cards.",
  on_play = function(state, cards)
    if #cards ~= 5 then
      return { blocked = true, message = "The Psychic demands exactly 5 cards!" }
    end
  end,
})

M.register_boss_blind("THE_NEEDLE", {
  name = "The Needle",
  description = "Only 1 hand allowed this blind.",
  on_start = function(state)
    state.hands = 1
  end,
})

function M.roll_boss_blind(state)
  local keys = {}
  for key in pairs(M.BOSS_BLINDS) do
    keys[#keys + 1] = key
  end
  table.sort(keys)
  if #keys == 0 then
    return nil
  end
  return keys[state.rng(1, #keys)]
end

function M.apply_boss_blind_start(state)
  local boss_key = state.boss_blind_key
  if not boss_key then return end
  local boss = M.BOSS_BLINDS[boss_key]
  if boss and boss.on_start then
    boss.on_start(state)
  end
end

function M.apply_boss_blind_on_play(state, cards)
  local boss_key = state.boss_blind_key
  if not boss_key then return nil end
  local boss = M.BOSS_BLINDS[boss_key]
  if boss and boss.on_play then
    return boss.on_play(state, cards)
  end
  return nil
end

-- ============================================================
-- CARD ENHANCEMENT HELPERS
-- ============================================================

function M.apply_card_enhancement(card, chips, mult, x_mult)
  if not card or not card.enhancement then
    return chips, mult, x_mult
  end
  local enh = card.enhancement
  local cfg = M.ENHANCEMENTS
  if enh == "foil" then
    chips = chips + (cfg.foil_chips or 50)
  elseif enh == "holo" then
    mult = mult + (cfg.holo_mult or 10)
  elseif enh == "polychrome" then
    x_mult = x_mult * (cfg.poly_x_mult or 1.5)
  end
  return chips, mult, x_mult
end

function M.new_state(rng, opts)
  opts = opts or {}
  local state = {
    ante = 1,
    blind_index = 1,
    score = 0,
    money = 0,
    hands = M.STARTING_HANDS,
    discards = M.STARTING_DISCARDS,
    deck = {},
    hand = {},
    selected = {},
    jokers = {},
    consumables = {},
    hand_levels = {},
    boss_blind_key = nil,
    last_hand_type = nil,
    owned_cards = {},
    deck_cards = {},
    inventory = nil,
    game_over = false,
    run_won = false,
    message = "",
    seed = normalize_seed(opts.seed),
    shop = nil,
    rng = rng or default_rng,
  }
  M.new_run(state)
  M.ensure_run_inventory(state)
  return state
end

function M.set_seed(state, seed, rng)
  M.ensure_run_inventory(state)
  state.seed = normalize_seed(seed)
  if state.seed == "" then
    state.seed = "random"
  end
  state.rng = rng or M.make_seeded_rng(state.seed)
end

function M.draw_cards(state, count)
  for _ = 1, count do
    if #state.deck == 0 then
      state.deck = M.build_run_deck(state)
    end
    state.hand[#state.hand + 1] = table.remove(state.deck)
  end
end

function M.replenish_hand(state)
  local needed = math.max(0, M.HAND_SIZE - #state.hand)
  if needed > 0 then
    M.draw_cards(state, needed)
  end
end

function M.toggle_selection(state, index)
  if state.selected[index] then
    state.selected[index] = nil
    return true, nil
  end

  if M.selected_count(state) >= M.MAX_SELECT then
    return false, "You can only select up to 5 cards."
  end

  state.selected[index] = true
  return true, nil
end

function M.selected_cards(state)
  local out = {}
  local indices = selected_indices(state)
  for _, index in ipairs(indices) do
    local card = state.hand[index]
    if card then
      out[#out + 1] = card
    end
  end
  return out, indices
end

function M.remove_selected_cards(state)
  local _, indices = M.selected_cards(state)
  local removed = {}

  for i = #indices, 1, -1 do
    local index = indices[i]
    removed[#removed + 1] = table.remove(state.hand, index)
  end

  M.clear_selection(state)
  M.replenish_hand(state)
  return removed
end

function M.calculate_projection(state, cards)
  local hand_type = M.evaluate_hand(cards)
  local current_chips = hand_type.chips
  local current_mult = hand_type.mult
  local x_mult = 1
  local details = {}

  -- Apply hand level bonuses
  local hand_levels = state.hand_levels or {}
  local level = hand_levels[hand_type.id] or 0
  if level > 0 then
    local bonus = M.HAND_LEVEL_BONUS or {}
    current_chips = current_chips + level * (bonus.chips_per_level or 10)
    current_mult = current_mult + level * (bonus.mult_per_level or 1)
  end

  -- Apply per-card enhancements (foil/holo/polychrome)
  for _, card in ipairs(cards) do
    if card.enhancement then
      current_chips, current_mult, x_mult = M.apply_card_enhancement(card, current_chips, current_mult, x_mult)
    end
  end

  -- Apply joker effects
  for _, joker_key in ipairs(state.jokers) do
    local joker = M.JOKERS[joker_key]
    if joker then
      local effect = joker.apply(cards, hand_type, state) or {}
      if effect.chips then
        current_chips = current_chips + effect.chips
      end
      if effect.mult then
        current_mult = current_mult + effect.mult
      end
      details[#details + 1] = { joker_key = joker_key, effect = effect }
    end
  end

  local projection = {
    hand_type = hand_type,
    base_chips = hand_type.chips,
    base_mult = hand_type.mult,
    total_chips = current_chips,
    total_mult = current_mult,
    x_mult = x_mult,
    total = math.floor(current_chips * current_mult * x_mult),
    joker_details = details,
    hand_level = level,
  }

  -- Apply boss blind on_score hook (e.g. The Flint halves base)
  local boss_key = state.boss_blind_key
  if boss_key then
    local boss = M.BOSS_BLINDS[boss_key]
    if boss and boss.on_score then
      projection = boss.on_score(state, projection)
      -- Recalculate total after boss modification
      projection.total = math.floor(projection.total_chips * projection.total_mult * (projection.x_mult or 1))
    end
  end

  return projection
end

function M.next_ante(state)
  M.ensure_run_inventory(state)
  state.ante = state.ante + 1
  state.blind_index = 1
  state.score = 0
  state.hands = M.STARTING_HANDS
  state.discards = M.STARTING_DISCARDS
  state.boss_blind_key = nil
  state.deck = M.build_run_deck(state)
  state.hand = {}
  M.draw_cards(state, M.HAND_SIZE)
  M.clear_selection(state)
  state.message = ("Blind cleared! Welcome to Ante %d."):format(state.ante)
end

function M.next_blind(state)
  M.ensure_run_inventory(state)
  if state.blind_index >= #M.BLINDS then
    if state.ante >= M.MAX_ANTE then
      state.game_over = true
      state.run_won = true
      state.message = "You defeated the final boss blind! Run complete."
      return "run_won"
    end
    M.next_ante(state)
    return "next_ante"
  end

  state.blind_index = state.blind_index + 1
  state.score = 0
  state.hands = M.STARTING_HANDS
  state.discards = M.STARTING_DISCARDS
  -- Roll boss blind when entering the boss blind slot
  if state.blind_index == #M.BLINDS then
    state.boss_blind_key = M.roll_boss_blind(state)
  else
    state.boss_blind_key = nil
  end
  state.deck = M.build_run_deck(state)
  state.hand = {}
  M.draw_cards(state, M.HAND_SIZE)
  M.clear_selection(state)
  -- Apply boss blind on_start effect (e.g. The Hook, The Needle)
  if state.boss_blind_key then
    M.apply_boss_blind_start(state)
    local boss = M.BOSS_BLINDS[state.boss_blind_key]
    local boss_name = boss and boss.name or state.boss_blind_key
    state.message = ("Boss Blind: %s! %s"):format(boss_name, boss and boss.description or "")
  else
    state.message = ("Blind cleared! %s begins."):format(M.current_blind(state).label)
  end
  return "next_blind"
end

function M.end_run(state, message)
  state.game_over = true
  state.run_won = false
  state.message = ("%s Click New Run to play again."):format(message)
end

function M.play_selected(state)
  if state.game_over then
    return { ok = false, reason = "game_over" }
  end
  if state.shop and state.shop.active then
    return { ok = false, reason = "shop_active", message = "Finish the shop before playing." }
  end
  if state.hands <= 0 then
    return { ok = false, reason = "no_hands" }
  end

  local chosen = M.selected_cards(state)
  if #chosen == 0 then
    return { ok = false, reason = "no_selection", message = "Select at least 1 card to play." }
  end

  -- Boss blind on_play check (e.g. The Psychic requires exactly 5)
  local boss_block = M.apply_boss_blind_on_play(state, chosen)
  if boss_block and boss_block.blocked then
    return { ok = false, reason = "boss_blocked", message = boss_block.message or "Blocked by boss blind." }
  end

  local projection = M.calculate_projection(state, chosen)
  state.score = state.score + projection.total
  state.hands = state.hands - 1
  state.last_hand_type = projection.hand_type and projection.hand_type.id or nil
  M.remove_selected_cards(state)

  local target = M.current_target(state)
  if state.score >= target then
    local cleared_blind = M.current_blind(state)
    local payout = M.award_blind_clear_payout(state, cleared_blind)
    local event = "next_blind"
    if state.blind_index >= #M.BLINDS then
      if state.ante >= M.MAX_ANTE then
        event = "run_won"
      else
        event = "next_ante"
      end
    end

    if event == "run_won" then
      state.game_over = true
      state.run_won = true
      state.message = "You defeated the final boss blind! Run complete."
    else
      M.open_shop(state, event)
      state.message = ("Blind cleared! +$%d. Entering shop."):format(payout)
      event = "shop"
    end
    return {
      ok = true,
      event = event,
      projection = projection,
      payout = payout,
      money = state.money,
      cleared_blind = cleared_blind.id,
    }
  end
  if state.hands == 0 then
    M.end_run(state, "You busted this blind.")
    return { ok = true, event = "game_over", projection = projection }
  end

  state.message = ("%s! +%d."):format(projection.hand_type.label, projection.total)
  return { ok = true, event = "played", projection = projection }
end

function M.discard_selected(state)
  if state.game_over then
    return { ok = false, reason = "game_over" }
  end
  if state.shop and state.shop.active then
    return { ok = false, reason = "shop_active", message = "Finish the shop before discarding." }
  end
  if state.discards <= 0 then
    return { ok = false, reason = "no_discards", message = "No discards left this ante." }
  end
  if M.selected_count(state) == 0 then
    return { ok = false, reason = "no_selection", message = "Select at least 1 card to discard." }
  end

  M.remove_selected_cards(state)
  state.discards = state.discards - 1
  state.message = "Discarded selected cards."
  return { ok = true, event = "discarded" }
end

function M.add_joker(state, forced_key)
  M.ensure_run_inventory(state)
  if #state.jokers >= M.MAX_JOKERS then
    return { ok = false, reason = "max_jokers", message = ("Max %d Jokers!"):format(M.MAX_JOKERS) }
  end

  local key = forced_key
  if not key then
    local keys = {}
    for joker_key, _ in pairs(M.JOKERS) do
      keys[#keys + 1] = joker_key
    end
    table.sort(keys)
    key = keys[state.rng(1, #keys)]
  end

  if not M.JOKERS[key] then
    return { ok = false, reason = "unknown_joker", message = "Unknown Joker key." }
  end

  state.jokers[#state.jokers + 1] = key
  record_inventory_event(state, "add_joker_debug", { joker_key = key })
  state.message = ("Added %s!"):format(M.JOKERS[key].name)
  return { ok = true, joker_key = key }
end

function M.set_hand_to_royal_flush(state)
  state.hand = {
    { rank = 10, suit = "S" },
    { rank = "J", suit = "S" },
    { rank = "Q", suit = "S" },
    { rank = "K", suit = "S" },
    { rank = "A", suit = "S" },
    { rank = 2, suit = "H" },
    { rank = 3, suit = "H" },
    { rank = 4, suit = "H" },
  }
  M.clear_selection(state)
  state.message = "Hand set to Royal Flush + extras!"
end

function M.new_run(state)
  M.init_run_inventory(state)
  state.ante = 1
  state.blind_index = 1
  state.score = 0
  state.money = 0
  state.hands = M.STARTING_HANDS
  state.discards = M.STARTING_DISCARDS
  sync_inventory_aliases(state)
  state.deck = M.build_run_deck(state)
  state.hand = {}
  state.jokers = {}
  state.consumables = {}
  state.hand_levels = {}
  state.boss_blind_key = nil
  state.last_hand_type = nil
  state.shop = nil
  M.clear_selection(state)
  state.game_over = false
  state.run_won = false
  M.draw_cards(state, M.HAND_SIZE)
  state.message = ("Select up to %d cards and play a poker hand."):format(M.MAX_SELECT)
end

function M.card_sprite_path(card, theme)
  local folder = (theme == "light") and "Cards/Cards" or "Cards/Cards_Dark"
  local suit = to_suit_code(card.suit)
  return ("%s/%s%s.png"):format(folder, suit, tostring(card.rank))
end

function M.card_label(card)
  return card_label(card)
end

function M.joker_sprite_path(joker_key, theme)
  local folder = (theme == "light") and "Cards/Cards" or "Cards/Cards_Dark"
  local joker = M.JOKERS[joker_key]
  if not joker then
    return nil
  end
  return ("%s/%s"):format(folder, joker.image)
end

function M.sort_hand(state, mode)
  local selected_cards = {}
  for index, is_selected in pairs(state.selected) do
    if is_selected and state.hand[index] then
      selected_cards[state.hand[index]] = true
    end
  end

  local rank_weight = {
    J = 11,
    Q = 12,
    K = 13,
    A = 14,
  }
  local suit_weight = {
    S = 1,
    H = 2,
    D = 3,
    C = 4,
  }

  table.sort(state.hand, function(a, b)
    local suit_a = to_suit_code(a.suit)
    local suit_b = to_suit_code(b.suit)
    local rank_a = type(a.rank) == "number" and a.rank or rank_weight[a.rank]
    local rank_b = type(b.rank) == "number" and b.rank or rank_weight[b.rank]

    if mode == "suit" then
      if suit_a == suit_b then
        if rank_a == rank_b then
          return tostring(a.rank) < tostring(b.rank)
        end
        return rank_a < rank_b
      end
      return suit_weight[suit_a] < suit_weight[suit_b]
    end

    if rank_a == rank_b then
      return suit_weight[suit_a] < suit_weight[suit_b]
    end
    return rank_a < rank_b
  end)

  state.selected = {}
  for index, card in ipairs(state.hand) do
    if selected_cards[card] then
      state.selected[index] = true
    end
  end

  if mode == "suit" then
    state.message = "Hand sorted by suit."
  else
    state.message = "Hand sorted by rank."
  end
end

return M
