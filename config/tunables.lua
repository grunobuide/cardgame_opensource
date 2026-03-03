local Tunables = {}

Tunables.cards = {
  suits = { "S", "H", "D", "C" },
  ranks = { 2, 3, 4, 5, 6, 7, 8, 9, 10, "J", "Q", "K", "A" },
}

Tunables.run = {
  ante_targets = { 200, 400, 700 },
  starting_hands = 5,
  starting_discards = 2,
  hand_size = 8,
  max_select = 5,
  max_jokers = 5,
}

Tunables.blinds = {
  { id = "small", label = "Small Blind", target_mult = 1.0 },
  { id = "big", label = "Big Blind", target_mult = 1.65 },
  { id = "boss", label = "Boss Blind", target_mult = 2.35 },
}

Tunables.payouts = {
  small = 4,
  big = 7,
  boss = 12,
}

Tunables.shop = {
  offer_count = 3,
  reroll_base_cost = 2,
  reroll_cost_step = 1,
  joker_offer_weight = 70,
  card_offer_weight = 30,
  prices = {
    common = 6,
    uncommon = 8,
    rare = 11,
    card_base = 4,
  },
  deck_edit_costs = {
    remove = 3,
    upgrade = 4,
    duplicate = 5,
  },
  sell_ratio = 0.5,
}

Tunables.inventory = {
  schema = 1,
}

return Tunables
