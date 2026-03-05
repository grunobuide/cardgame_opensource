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

Tunables.ev = {
  card_base_offset    = 8,     -- subtracted from rank value in score_ev_for_card
  card_rank_weight    = 1.3,   -- multiplier for (value - offset)
  ace_bonus           = 1.5,   -- extra EV for Aces
  face_bonus          = 0.6,   -- extra EV for J/Q/K
  rarity_bonus        = { common = 4, uncommon = 7, rare = 11 },
  chip_weight         = 0.14,  -- formula chip contribution to joker EV
  mult_weight         = 2.1,   -- formula mult contribution to joker EV
  money_weight        = 1.1,   -- money_ev multiplier in normalize_ev
  verdict_good        = 2,     -- combined EV threshold for "good"
  verdict_risky       = -2,    -- combined EV threshold for "risky"
  sell_joker_penalty  = 0.85,  -- score EV kept when selling a joker
  sell_card_penalty   = 0.65,  -- score EV kept when selling a card
  deck_remove_base    = 0.8,   -- base score EV for deck remove
  deck_remove_over    = 0.15,  -- per-card-over-52 bonus for deck remove
  deck_upgrade_ev     = 3.6,   -- fixed score EV for deck upgrade
  deck_dup_base       = 1.2,   -- base score EV for deck duplicate
  deck_dup_avg_weight = 0.45,  -- avg rank EV weight for deck duplicate
  reroll_score_scale  = 1.2,   -- multiplier on avg offer EV for reroll
}

Tunables.inventory = {
  schema = 1,
}

return Tunables
