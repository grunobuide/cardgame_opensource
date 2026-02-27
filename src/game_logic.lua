local M = {}

M.SUITS = { "S", "H", "D", "C" }
M.RANKS = { 2, 3, 4, 5, 6, 7, 8, 9, 10, "J", "Q", "K", "A" }
M.ANTE_TARGETS = { 200, 400, 700 }
M.MAX_ANTE = #M.ANTE_TARGETS
M.BLINDS = {
  { id = "small", label = "Small Blind", target_mult = 1.0 },
  { id = "big", label = "Big Blind", target_mult = 1.65 },
  { id = "boss", label = "Boss Blind", target_mult = 2.35 },
}
M.STARTING_HANDS = 5
M.STARTING_DISCARDS = 2
M.HAND_SIZE = 8
M.MAX_SELECT = 5
M.MAX_JOKERS = 5

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

function M.build_deck(rng)
  local rnd = rng or default_rng
  local deck = {}

  for _, suit in ipairs(M.SUITS) do
    for _, rank in ipairs(M.RANKS) do
      deck[#deck + 1] = { suit = suit, rank = rank }
    end
  end

  for i = #deck, 2, -1 do
    local j = rnd(1, i)
    deck[i], deck[j] = deck[j], deck[i]
  end

  return deck
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
  return math.floor((base * blind.target_mult) + 0.5)
end

function M.rank_to_value(rank)
  if type(rank) == "number" then
    return rank
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
  return 14
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

M.JOKERS = {
  JOKER = {
    name = "Joker",
    rarity = "common",
    formula = "+4 Mult",
    image = "Joker.png",
    apply = function(_cards, _hand_type)
      return { mult = 4 }
    end,
  },
  GREEDY_JOKER = {
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
  },
  PAIR_JOKER = {
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
  },
}

function M.new_state(rng, opts)
  opts = opts or {}
  local state = {
    ante = 1,
    blind_index = 1,
    score = 0,
    hands = M.STARTING_HANDS,
    discards = M.STARTING_DISCARDS,
    deck = {},
    hand = {},
    selected = {},
    jokers = {},
    game_over = false,
    run_won = false,
    message = "",
    seed = normalize_seed(opts.seed),
    rng = rng or default_rng,
  }
  M.new_run(state)
  return state
end

function M.set_seed(state, seed, rng)
  state.seed = normalize_seed(seed)
  if state.seed == "" then
    state.seed = "random"
  end
  state.rng = rng or M.make_seeded_rng(state.seed)
end

function M.draw_cards(state, count)
  for _ = 1, count do
    if #state.deck == 0 then
      state.deck = M.build_deck(state.rng)
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
  local details = {}

  for _, joker_key in ipairs(state.jokers) do
    local joker = M.JOKERS[joker_key]
    if joker then
      local effect = joker.apply(cards, hand_type) or {}
      if effect.chips then
        current_chips = current_chips + effect.chips
      end
      if effect.mult then
        current_mult = current_mult + effect.mult
      end
      details[#details + 1] = { joker_key = joker_key, effect = effect }
    end
  end

  return {
    hand_type = hand_type,
    base_chips = hand_type.chips,
    base_mult = hand_type.mult,
    total_chips = current_chips,
    total_mult = current_mult,
    total = current_chips * current_mult,
    joker_details = details,
  }
end

function M.next_ante(state)
  state.ante = state.ante + 1
  state.blind_index = 1
  state.score = 0
  state.hands = M.STARTING_HANDS
  state.discards = M.STARTING_DISCARDS
  state.deck = M.build_deck(state.rng)
  state.hand = {}
  M.draw_cards(state, M.HAND_SIZE)
  M.clear_selection(state)
  state.message = ("Blind cleared! Welcome to Ante %d."):format(state.ante)
end

function M.next_blind(state)
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
  state.deck = M.build_deck(state.rng)
  state.hand = {}
  M.draw_cards(state, M.HAND_SIZE)
  M.clear_selection(state)
  state.message = ("Blind cleared! %s begins."):format(M.current_blind(state).label)
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
  if state.hands <= 0 then
    return { ok = false, reason = "no_hands" }
  end

  local chosen = M.selected_cards(state)
  if #chosen == 0 then
    return { ok = false, reason = "no_selection", message = "Select at least 1 card to play." }
  end

  local projection = M.calculate_projection(state, chosen)
  state.score = state.score + projection.total
  state.hands = state.hands - 1
  M.remove_selected_cards(state)

  local target = M.current_target(state)
  if state.score >= target then
    local event = M.next_blind(state)
    return { ok = true, event = event, projection = projection }
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
  if #state.jokers >= M.MAX_JOKERS then
    return { ok = false, reason = "max_jokers", message = "Max 5 Jokers!" }
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
  state.ante = 1
  state.blind_index = 1
  state.score = 0
  state.hands = M.STARTING_HANDS
  state.discards = M.STARTING_DISCARDS
  state.deck = M.build_deck(state.rng)
  state.hand = {}
  state.jokers = {}
  M.clear_selection(state)
  state.game_over = false
  state.run_won = false
  M.draw_cards(state, M.HAND_SIZE)
  state.message = "Select up to 5 cards and play a poker hand."
end

function M.card_sprite_path(card, theme)
  local folder = (theme == "light") and "Cards/Cards" or "Cards/Cards_Dark"
  local suit = to_suit_code(card.suit)
  return ("%s/%s%s.png"):format(folder, suit, tostring(card.rank))
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
