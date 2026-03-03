local Layout = {}

Layout.grid = 8
Layout.outer = 24
Layout.gap = 16
Layout.padding = 16

local function snap(value)
  return math.floor((value + (Layout.grid * 0.5)) / Layout.grid) * Layout.grid
end

function Layout.columns(width, height)
  local outer = Layout.outer
  local gap = Layout.gap
  local pad = Layout.padding
  local top_h = 72

  local content_x = outer
  local content_y = outer + top_h + gap
  local content_w = width - (outer * 2)
  local content_h = height - content_y - outer

  local feedback_h = height <= 720 and 80 or 88
  local min_bottom_h = height <= 720 and 144 or 152
  local hand_h = snap(content_h * 0.58)
  hand_h = math.max(304, math.min(hand_h, content_h - (feedback_h + (gap * 2) + min_bottom_h)))
  local bottom_h = content_h - feedback_h - hand_h - (gap * 2)

  local actions_w = snap(content_w * 0.68)
  actions_w = math.max(760, math.min(actions_w, content_w - 280))
  local jokers_w = content_w - actions_w - gap

  local feedback = {
    x = content_x,
    y = content_y,
    w = content_w,
    h = feedback_h,
  }

  local hand = {
    x = content_x,
    y = feedback.y + feedback.h + gap,
    w = content_w,
    h = hand_h,
  }

  local actions = {
    x = content_x,
    y = hand.y + hand.h + gap,
    w = actions_w,
    h = bottom_h,
  }

  local side = {
    x = actions.x + actions.w + gap,
    y = actions.y,
    w = jokers_w,
    h = bottom_h,
  }
  local side_summary_h = math.max(64, math.min(96, math.floor(side.h * 0.48)))
  side.summary = {
    x = side.x,
    y = side.y,
    w = side.w,
    h = side_summary_h,
  }
  side.jokers = {
    x = side.x,
    y = side.y + side_summary_h + 8,
    w = side.w,
    h = side.h - side_summary_h - 8,
  }

  return {
    outer = outer,
    gap = gap,
    padding = pad,
    top = { x = outer, y = outer, w = content_w, h = top_h },
    feedback = feedback,
    hand = hand,
    actions = actions,
    side = side,
    run_summary = side.summary,
    jokers = side.jokers,
    center = {
      feedback = feedback,
      hand = hand,
      actions = actions,
    },
  }
end

function Layout.buttons()
  return {
    { id = "play", label = "PLAY HAND", key_hint = "SPACE", tier = "primary", group = "center_actions" },
    { id = "discard", label = "DISCARD", key_hint = "D", tier = "secondary", group = "center_actions" },
    { id = "new_run", label = "NEW RUN", key_hint = "R", tier = "utility", group = "tools" },
    { id = "sort_suit", label = "SORT SUIT", key_hint = "S", tier = "utility", group = "tools" },
    { id = "sort_rank", label = "SORT RANK", key_hint = "N", tier = "utility", group = "tools" },
    { id = "add_joker", label = "ADD JOKER", key_hint = "J", tier = "utility", group = "tools" },
    { id = "royal", label = "SET ROYAL", key_hint = "F", tier = "utility", group = "tools" },
  }
end

function Layout.position_buttons(buttons, width, height)
  local grid = Layout.columns(width, height)
  local panel = grid.actions
  local pad = Layout.padding
  local gap = Layout.gap

  local top_y = panel.y + pad + 8
  local top_h = math.min(64, panel.h - (pad * 2) - 28)
  top_h = math.max(48, top_h)
  local top_w = math.floor((panel.w - (pad * 2) - gap) * 0.5)

  local play_rect = {
    x = panel.x + pad,
    y = top_y,
    w = top_w,
    h = top_h,
  }
  local discard_rect = {
    x = play_rect.x + play_rect.w + gap,
    y = top_y,
    w = panel.w - pad - (play_rect.x + play_rect.w + gap),
    h = top_h,
  }

  local tool_y = top_y + top_h + 8
  local tool_h = panel.y + panel.h - pad - tool_y
  tool_h = math.max(24, tool_h)
  local tool_order = { "new_run", "sort_suit", "sort_rank", "add_joker", "royal" }
  local tool_gap = 8
  local tool_w = math.floor((panel.w - (pad * 2) - (tool_gap * (#tool_order - 1))) / #tool_order)

  for _, button in ipairs(buttons) do
    if button.id == "play" then
      button.x, button.y, button.w, button.h = play_rect.x, play_rect.y, play_rect.w, play_rect.h
    elseif button.id == "discard" then
      button.x, button.y, button.w, button.h = discard_rect.x, discard_rect.y, discard_rect.w, discard_rect.h
    end
  end

  for index, id in ipairs(tool_order) do
    local slot_x = panel.x + pad + ((index - 1) * (tool_w + tool_gap))
    for _, button in ipairs(buttons) do
      if button.id == id then
        button.x = slot_x
        button.y = tool_y
        button.w = tool_w
        button.h = tool_h
        break
      end
    end
  end
end

function Layout.card_slots(hand_count, hand_region)
  local slots = {}
  if hand_count <= 0 then
    return slots
  end

  local bounds = hand_region or { x = 24, y = 208, w = 1318, h = 368 }
  local available_w = bounds.w - 40
  local card_h = math.max(196, math.min(bounds.h - 36, 332))
  local card_w = math.floor(card_h * 0.71)
  local step = 0

  while hand_count > 1 and card_h > 176 do
    local trial_w = math.floor(card_h * 0.71)
    local max_step = math.floor((available_w - trial_w) / (hand_count - 1))
    local desired_ratio = hand_count <= 4 and 0.72 or (hand_count <= 6 and 0.58 or 0.46)
    local desired_step = math.floor(trial_w * desired_ratio)
    local min_step = math.floor(trial_w * 0.20)

    if max_step >= min_step then
      card_w = trial_w
      step = math.max(min_step, math.min(max_step, desired_step))
      break
    end
    card_h = card_h - 8
  end

  if hand_count == 1 then
    step = 0
  elseif step == 0 then
    step = math.max(
      math.floor(card_w * 0.20),
      math.floor((available_w - card_w) / (hand_count - 1))
    )
  end

  local total_w = card_w + ((hand_count - 1) * step)
  local base_x = math.floor(bounds.x + ((bounds.w - total_w) * 0.5))
  local base_y = bounds.y + bounds.h - card_h - 14
  local midpoint = (hand_count + 1) * 0.5
  local curve_strength = hand_count <= 4 and 3.2 or (hand_count <= 6 and 2.4 or 1.6)

  for i = 1, hand_count do
    local arc = math.abs(i - midpoint)
    slots[i] = {
      x = base_x + ((i - 1) * step),
      y = math.floor(base_y + ((arc * arc) * curve_strength)),
      w = card_w,
      h = card_h,
    }
  end

  return slots
end

return Layout
