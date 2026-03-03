return {
  {
    id = "high_card_no_joker",
    jokers = {},
    cards = {
      { rank = 2, suit = "S" },
      { rank = 7, suit = "H" },
      { rank = "K", suit = "C" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 5,
      total_mult = 1,
      total = 5,
      joker_details = {},
    },
  },
  {
    id = "high_card_joker",
    jokers = { "JOKER" },
    cards = {
      { rank = 2, suit = "S" },
      { rank = 7, suit = "H" },
      { rank = "K", suit = "C" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 5,
      total_mult = 5,
      total = 25,
      joker_details = {
        { joker_key = "JOKER", effect = { mult = 4 } },
      },
    },
  },
  {
    id = "high_card_greedy_no_diamond",
    jokers = { "GREEDY_JOKER" },
    cards = {
      { rank = 2, suit = "S" },
      { rank = 7, suit = "H" },
      { rank = "K", suit = "C" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 5,
      total_mult = 1,
      total = 5,
      joker_details = {
        { joker_key = "GREEDY_JOKER", effect = {} },
      },
    },
  },
  {
    id = "high_card_greedy_with_diamond",
    jokers = { "GREEDY_JOKER" },
    cards = {
      { rank = 2, suit = "S" },
      { rank = 7, suit = "D" },
      { rank = "K", suit = "C" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 5,
      total_mult = 5,
      total = 25,
      joker_details = {
        { joker_key = "GREEDY_JOKER", effect = { mult = 4 } },
      },
    },
  },
  {
    id = "pair_pair_joker",
    jokers = { "PAIR_JOKER" },
    cards = {
      { rank = 2, suit = "S" },
      { rank = 2, suit = "H" },
      { rank = 8, suit = "D" },
    },
    expected = {
      hand_type_id = "PAIR",
      hand_type_label = "Pair",
      base_chips = 10,
      base_mult = 2,
      total_chips = 10,
      total_mult = 4,
      total = 40,
      joker_details = {
        { joker_key = "PAIR_JOKER", effect = { mult = 2 } },
      },
    },
  },
  {
    id = "two_pair_pair_joker",
    jokers = { "PAIR_JOKER" },
    cards = {
      { rank = 2, suit = "S" },
      { rank = 2, suit = "D" },
      { rank = 9, suit = "H" },
      { rank = 9, suit = "C" },
    },
    expected = {
      hand_type_id = "TWO_PAIR",
      hand_type_label = "Two Pair",
      base_chips = 20,
      base_mult = 2,
      total_chips = 20,
      total_mult = 6,
      total = 120,
      joker_details = {
        { joker_key = "PAIR_JOKER", effect = { mult = 4 } },
      },
    },
  },
  {
    id = "two_pair_combo_all",
    jokers = { "JOKER", "GREEDY_JOKER", "PAIR_JOKER" },
    cards = {
      { rank = 2, suit = "S" },
      { rank = 2, suit = "D" },
      { rank = 9, suit = "H" },
      { rank = 9, suit = "C" },
    },
    expected = {
      hand_type_id = "TWO_PAIR",
      hand_type_label = "Two Pair",
      base_chips = 20,
      base_mult = 2,
      total_chips = 20,
      total_mult = 14,
      total = 280,
      joker_details = {
        { joker_key = "JOKER", effect = { mult = 4 } },
        { joker_key = "GREEDY_JOKER", effect = { mult = 4 } },
        { joker_key = "PAIR_JOKER", effect = { mult = 4 } },
      },
    },
  },
  {
    id = "royal_flush_combo_all_diamond",
    jokers = { "JOKER", "GREEDY_JOKER", "PAIR_JOKER" },
    cards = {
      { rank = 10, suit = "D" },
      { rank = "J", suit = "D" },
      { rank = "Q", suit = "D" },
      { rank = "K", suit = "D" },
      { rank = "A", suit = "D" },
    },
    expected = {
      hand_type_id = "ROYAL_FLUSH",
      hand_type_label = "Royal Flush",
      base_chips = 150,
      base_mult = 10,
      total_chips = 150,
      total_mult = 18,
      total = 2700,
      joker_details = {
        { joker_key = "JOKER", effect = { mult = 4 } },
        { joker_key = "GREEDY_JOKER", effect = { mult = 4 } },
        { joker_key = "PAIR_JOKER", effect = { mult = 0 } },
      },
    },
  },

  -- Suit triggers
  {
    id = "heart_joker_two_hearts",
    jokers = { "HEART_JOKER" },
    cards = {
      { rank = 7, suit = "H" },
      { rank = 2, suit = "H" },
      { rank = "K", suit = "C" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 5,
      total_mult = 7,      -- +3 per heart × 2 = +6
      total = 35,
      joker_details = {
        { joker_key = "HEART_JOKER", effect = { mult = 6 } },
      },
    },
  },
  {
    id = "heart_joker_no_hearts",
    jokers = { "HEART_JOKER" },
    cards = {
      { rank = 7, suit = "S" },
      { rank = 2, suit = "C" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 5,
      total_mult = 1,
      total = 5,
      joker_details = {
        { joker_key = "HEART_JOKER", effect = { mult = 0 } },
      },
    },
  },
  {
    id = "club_joker_two_clubs",
    jokers = { "CLUB_JOKER" },
    cards = {
      { rank = 7, suit = "C" },
      { rank = 2, suit = "C" },
      { rank = "K", suit = "S" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 25,    -- +10 per club × 2 = +20
      total_mult = 1,
      total = 25,
      joker_details = {
        { joker_key = "CLUB_JOKER", effect = { chips = 20 } },
      },
    },
  },

  -- Rank triggers
  {
    id = "ace_joker_two_aces",
    jokers = { "ACE_JOKER" },
    cards = {
      { rank = "A", suit = "H" },
      { rank = "A", suit = "D" },
      { rank = 3, suit = "S" },
    },
    expected = {
      hand_type_id = "PAIR",
      hand_type_label = "Pair",
      base_chips = 10,
      base_mult = 2,
      total_chips = 10,
      total_mult = 14,     -- +6 per ace × 2 = +12
      total = 140,
      joker_details = {
        { joker_key = "ACE_JOKER", effect = { mult = 12 } },
      },
    },
  },
  {
    id = "face_joker_two_faces",
    jokers = { "FACE_JOKER" },
    cards = {
      { rank = "J", suit = "H" },
      { rank = "Q", suit = "D" },
      { rank = 3, suit = "S" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 13,    -- +4 per face × 2 = +8
      total_mult = 1,
      total = 13,
      joker_details = {
        { joker_key = "FACE_JOKER", effect = { chips = 8 } },
      },
    },
  },

  -- Hand-type triggers
  {
    id = "flush_master_with_flush",
    jokers = { "FLUSH_MASTER" },
    cards = {
      { rank = 2, suit = "H" },
      { rank = 5, suit = "H" },
      { rank = 7, suit = "H" },
      { rank = 9, suit = "H" },
      { rank = "J", suit = "H" },
    },
    expected = {
      hand_type_id = "FLUSH",
      hand_type_label = "Flush",
      base_chips = 35,
      base_mult = 4,
      total_chips = 35,
      total_mult = 34,     -- +30
      total = 1190,
      joker_details = {
        { joker_key = "FLUSH_MASTER", effect = { mult = 30 } },
      },
    },
  },
  {
    id = "flush_master_no_flush",
    jokers = { "FLUSH_MASTER" },
    cards = {
      { rank = 2, suit = "H" },
      { rank = 5, suit = "S" },
      { rank = 7, suit = "D" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 5,
      total_mult = 1,
      total = 5,
      joker_details = {
        { joker_key = "FLUSH_MASTER", effect = {} },
      },
    },
  },
  {
    id = "straight_arrow_with_straight",
    jokers = { "STRAIGHT_ARROW" },
    cards = {
      { rank = 3, suit = "H" },
      { rank = 4, suit = "D" },
      { rank = 5, suit = "S" },
      { rank = 6, suit = "C" },
      { rank = 7, suit = "H" },
    },
    expected = {
      hand_type_id = "STRAIGHT",
      hand_type_label = "Straight",
      base_chips = 30,
      base_mult = 4,
      total_chips = 30,
      total_mult = 24,     -- +20
      total = 720,
      joker_details = {
        { joker_key = "STRAIGHT_ARROW", effect = { mult = 20 } },
      },
    },
  },

  -- Count triggers
  {
    id = "street_rat_five_cards",
    jokers = { "STREET_RAT" },
    cards = {
      { rank = 2, suit = "S" },
      { rank = 3, suit = "H" },
      { rank = 5, suit = "D" },
      { rank = 7, suit = "C" },
      { rank = "K", suit = "S" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 5,
      total_mult = 11,     -- +2 per card × 5 = +10
      total = 55,
      joker_details = {
        { joker_key = "STREET_RAT", effect = { mult = 10 } },
      },
    },
  },
  {
    id = "minimalist_one_card",
    jokers = { "MINIMALIST" },
    cards = {
      { rank = "A", suit = "S" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 5,
      total_mult = 21,     -- +20
      total = 105,
      joker_details = {
        { joker_key = "MINIMALIST", effect = { mult = 20 } },
      },
    },
  },
  {
    id = "minimalist_two_cards",
    jokers = { "MINIMALIST" },
    cards = {
      { rank = "A", suit = "S" },
      { rank = 2, suit = "H" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 5,
      total_mult = 1,
      total = 5,
      joker_details = {
        { joker_key = "MINIMALIST", effect = {} },
      },
    },
  },

  -- State-aware triggers
  {
    id = "hoarder_three_jokers",
    jokers = { "HOARDER", "JOKER", "GREEDY_JOKER" },
    cards = {
      { rank = 2, suit = "S" },
      { rank = 7, suit = "H" },
      { rank = "K", suit = "C" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 5,
      total_mult = 11,     -- HOARDER +6 (3×2), JOKER +4, GREEDY +0 = +10
      total = 55,
      joker_details = {
        { joker_key = "HOARDER", effect = { mult = 6 } },
        { joker_key = "JOKER", effect = { mult = 4 } },
        { joker_key = "GREEDY_JOKER", effect = {} },
      },
    },
  },
  {
    -- state.discards defaults to STARTING_DISCARDS = 2
    id = "conservative_full_discards",
    jokers = { "CONSERVATIVE" },
    cards = {
      { rank = 2, suit = "S" },
      { rank = 7, suit = "H" },
      { rank = "K", suit = "C" },
    },
    expected = {
      hand_type_id = "HIGH_CARD",
      hand_type_label = "High Card",
      base_chips = 5,
      base_mult = 1,
      total_chips = 5,
      total_mult = 5,      -- +2 per discard × 2 = +4
      total = 25,
      joker_details = {
        { joker_key = "CONSERVATIVE", effect = { mult = 4 } },
      },
    },
  },

  -- Multi-category combo
  {
    id = "flush_heart_street_rat_combo",
    jokers = { "HEART_JOKER", "FLUSH_MASTER", "STREET_RAT" },
    cards = {
      { rank = 2, suit = "H" },
      { rank = 5, suit = "H" },
      { rank = 7, suit = "H" },
      { rank = 9, suit = "H" },
      { rank = "J", suit = "H" },
    },
    expected = {
      hand_type_id = "FLUSH",
      hand_type_label = "Flush",
      base_chips = 35,
      base_mult = 4,
      total_chips = 35,
      total_mult = 59,     -- HEART +15 (5×3), FLUSH_MASTER +30, STREET_RAT +10 (5×2)
      total = 2065,
      joker_details = {
        { joker_key = "HEART_JOKER", effect = { mult = 15 } },
        { joker_key = "FLUSH_MASTER", effect = { mult = 30 } },
        { joker_key = "STREET_RAT", effect = { mult = 10 } },
      },
    },
  },
}
