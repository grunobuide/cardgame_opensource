local Layout = {}

function Layout.columns(width, height)
  local outer = 12
  local gap = 10
  local side_w = 192
  local top_h = 80
  local content_y = outer + top_h + 12
  local content_h = height - content_y - outer
  local center_w = width - (outer * 2) - (gap * 2) - (side_w * 2)

  local left_x = outer
  local center_x = left_x + side_w + gap
  local right_x = center_x + center_w + gap

  local center = {
    x = center_x,
    y = content_y,
    w = center_w,
    h = content_h,
  }

  local cg = 10
  local round_h = 36
  local enemies_h = 50
  local hand_h = 320
  local actions_h = 64
  local pressure_h = 68
  local feedback_h = content_h - (round_h + enemies_h + hand_h + actions_h + pressure_h + (cg * 5))

  center.round = { x = center_x, y = content_y, w = center_w, h = round_h }
  center.enemies = { x = center_x, y = center.round.y + round_h + cg, w = center_w, h = enemies_h }
  center.hand = { x = center_x, y = center.enemies.y + enemies_h + cg, w = center_w, h = hand_h }
  center.actions = { x = center_x, y = center.hand.y + hand_h + cg, w = center_w, h = actions_h }
  center.pressure = { x = center_x, y = center.actions.y + actions_h + cg, w = center_w, h = pressure_h }
  center.feedback = { x = center_x, y = center.pressure.y + pressure_h + cg, w = center_w, h = feedback_h }
  local preview_h = math.min(64, math.max(48, math.floor(center.feedback.h * 0.62)))
  local message_h = math.max(24, center.feedback.h - preview_h - 8)
  center.preview = { x = center.feedback.x, y = center.feedback.y, w = center.feedback.w, h = preview_h }
  center.message = {
    x = center.feedback.x,
    y = center.preview.y + center.preview.h + 8,
    w = center.feedback.w,
    h = message_h,
  }

  local left = { x = left_x, y = content_y, w = side_w, h = content_h }
  local lg = 10
  local status_h = 220
  local upgrades_h = 148
  local tools_h = content_h - (status_h + upgrades_h + (lg * 2))
  left.status = { x = left_x, y = content_y, w = side_w, h = status_h }
  left.upgrades = { x = left_x, y = left.status.y + status_h + lg, w = side_w, h = upgrades_h }
  left.tools = { x = left_x, y = left.upgrades.y + upgrades_h + lg, w = side_w, h = tools_h }

  local right = { x = right_x, y = content_y, w = side_w, h = content_h }
  local rg = 10
  local jokers_h = 440
  local details_h = 120
  local shop_h = content_h - (jokers_h + details_h + (rg * 2))
  right.jokers = { x = right_x, y = content_y, w = side_w, h = jokers_h }
  right.details = { x = right_x, y = right.jokers.y + jokers_h + rg, w = side_w, h = details_h }
  right.shop = { x = right_x, y = right.details.y + details_h + rg, w = side_w, h = shop_h }

  return {
    outer = outer,
    gap = gap,
    top = { x = outer, y = outer, w = width - outer * 2, h = top_h },
    left = left,
    center = center,
    right = right,
  }
end

function Layout.buttons()
  return {
    -- Primary actions
    { id = "play", label = "Play Hand", icon = "PLAY", key_hint = "SPACE", x = 24, y = 108, w = 170, h = 54, tier = "primary", group = "center_actions" },
    { id = "discard", label = "Discard Cards", icon = "DROP", key_hint = "D", x = 202, y = 112, w = 146, h = 46, tier = "secondary", group = "center_actions" },
    -- Secondary/system actions
    { id = "sort_suit", label = "Sort by Suit", icon = "SUIT", key_hint = "S", x = 368, y = 116, w = 102, h = 40, tier = "tertiary", group = "tools" },
    { id = "sort_rank", label = "Sort by Rank", icon = "RANK", key_hint = "N", x = 476, y = 116, w = 102, h = 40, tier = "tertiary", group = "tools" },
    { id = "add_joker", label = "Add Joker", icon = "JOKER", key_hint = "J", x = 584, y = 116, w = 102, h = 40, tier = "tertiary", group = "tools" },
    { id = "royal", label = "Set Royal", icon = "ROYAL", key_hint = "F", x = 692, y = 116, w = 102, h = 40, tier = "tertiary", group = "tools" },
    { id = "new_run", label = "Start New Run", icon = "RUN", key_hint = "R", x = 800, y = 116, w = 136, h = 40, tier = "tertiary", group = "tools" },
  }
end

function Layout.position_buttons(buttons, width, height)
  local grid = Layout.columns(width, height)
  local actions = grid.center.actions
  local tools = grid.left.tools
  local action_gap = 8
  local action_w = math.floor((actions.w - (action_gap * 3)) * 0.5)
  local action_h = actions.h - 10

  for _, button in ipairs(buttons) do
    if button.id == "play" then
      button.x = actions.x + action_gap
      button.y = actions.y + 5
      button.w = action_w
      button.h = action_h
    elseif button.id == "discard" then
      button.x = actions.x + actions.w - action_w - action_gap
      button.y = actions.y + 5
      button.w = action_w
      button.h = action_h
    end
  end

  local gx = tools.x + 10
  local gy = tools.y + 40
  local gw = tools.w - 20
  local gh = 40

  local tool_positions = {
    new_run = { x = gx, y = gy, w = gw, h = gh },
    add_joker = { x = gx, y = gy + 48, w = gw, h = gh },
    sort_suit = { x = gx, y = gy + 96, w = gw, h = gh },
    sort_rank = { x = gx, y = gy + 144, w = gw, h = gh },
    royal = { x = gx, y = gy + 192, w = gw, h = gh },
  }

  for _, button in ipairs(buttons) do
    local slot = tool_positions[button.id]
    if slot then
      button.x = slot.x
      button.y = slot.y
      button.w = slot.w
      button.h = slot.h
    end
  end
end

function Layout.card_slots(hand_count, hand_region)
  local slots = {}
  local bounds = hand_region or { x = 250, y = 234, w = 460, h = 264 }
  local card_h = math.max(130, math.min(212, bounds.h - 28))
  local card_w = math.floor(card_h * 0.71)
  local available_w = bounds.w - 24

  while hand_count > 1 and card_h > 120 do
    local trial_w = math.floor(card_h * 0.71)
    local trial_overlap = math.floor((available_w - trial_w) / (hand_count - 1))
    if trial_overlap >= math.floor(trial_w * 0.34) then
      card_w = trial_w
      break
    end
    card_h = card_h - 4
  end

  local overlap = hand_count <= 1 and 0 or math.floor((available_w - card_w) / (hand_count - 1))
  overlap = math.max(math.floor(card_w * 0.32), math.min(overlap, math.floor(card_w * 0.62)))
  local total_w = card_w + (hand_count - 1) * overlap
  local mid = (hand_count + 1) * 0.5
  local base_x = math.floor(bounds.x + (bounds.w - total_w) * 0.5)
  local base_y = bounds.y + bounds.h - card_h - 10

  for i = 1, hand_count do
    local curve = math.abs(i - mid)
    slots[i] = {
      x = base_x + (i - 1) * overlap,
      y = base_y + curve * 2.0,
      w = card_w,
      h = card_h,
    }
  end

  return slots
end

return Layout
