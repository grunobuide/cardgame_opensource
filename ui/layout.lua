local Layout = {}

function Layout.buttons()
  return {
    -- Primary actions
    { id = "play", label = "Play", x = 24, y = 112, w = 156, h = 48 },
    { id = "discard", label = "Discard", x = 188, y = 112, w = 156, h = 48 },
    -- Secondary/system actions
    { id = "sort_suit", label = "Sort Suit", x = 368, y = 116, w = 110, h = 40 },
    { id = "sort_rank", label = "Sort Rank", x = 484, y = 116, w = 110, h = 40 },
    { id = "add_joker", label = "Add Joker", x = 600, y = 116, w = 110, h = 40 },
    { id = "royal", label = "Set Royal", x = 716, y = 116, w = 110, h = 40 },
    { id = "new_run", label = "New Run", x = 832, y = 116, w = 104, h = 40 },
  }
end

function Layout.card_slots(hand_count)
  local slots = {}
  local card_w = 112
  local card_h = 157
  local overlap = 56
  local base_y = 254
  local max_cards = math.max(hand_count, 8)
  local mid = (max_cards + 1) / 2
  local total_w = card_w + (hand_count - 1) * overlap
  local base_x = math.floor((960 - total_w) * 0.5)

  for i = 1, hand_count do
    local curve = math.abs(i - mid)
    slots[i] = {
      x = base_x + (i - 1) * overlap,
      y = base_y + curve * 2.6,
      w = card_w,
      h = card_h,
    }
  end

  return slots
end

return Layout
