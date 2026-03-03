local Layout = require("ui.layout")

local M = {}

local function card_label(card)
  return ("%s%s"):format(tostring(card.rank), tostring(card.suit))
end

local function build_stable_keys(cards)
  local counts = {}
  local keys = {}
  for i, card in ipairs(cards or {}) do
    local base = card_label(card)
    local seq = (counts[base] or 0) + 1
    counts[base] = seq
    keys[i] = ("%s#%d"):format(base, seq)
  end
  return keys
end

local function index_visuals_by_key(visuals)
  local map = {}
  for _, visual in ipairs(visuals or {}) do
    if visual.stable_key then
      local bucket = map[visual.stable_key]
      if not bucket then
        bucket = {}
        map[visual.stable_key] = bucket
      end
      bucket[#bucket + 1] = visual
    end
  end
  return map
end

local function pop_visual(map, key)
  local bucket = map[key]
  if not bucket or #bucket == 0 then
    return nil
  end
  local visual = bucket[1]
  table.remove(bucket, 1)
  return visual
end

function M.install(GameScene, game)
  function GameScene:selected_card_indices()
    local _, indices = game.selected_cards(self.state)
    return indices
  end

  function GameScene:recalc_card_slots()
    local grid = Layout.columns(self.base_width, self.base_height)
    self.card_slots = Layout.card_slots(#self.state.hand, grid.center.hand)
  end

  function GameScene:make_card_visual(index, card, stable_key, from_deal)
    local slot = self.card_slots[index]
    if not slot then
      return nil
    end
    local visual = {
      uid = self.next_uid,
      index = index,
      card = card,
      stable_key = stable_key,
      x = slot.x,
      y = from_deal and (slot.y - 64) or slot.y,
      w = slot.w,
      h = slot.h,
      alpha = from_deal and 0 or 1,
      scale = 1,
      rotation = 0,
      lift = 0,
      target_lift = 0,
      exiting = false,
      to_remove = false,
    }
    self.next_uid = self.next_uid + 1
    return visual
  end

  function GameScene:rebuild_visuals(mode)
    local rebuild_mode = mode
    if type(mode) == "boolean" then
      rebuild_mode = mode and "deal" or "snap"
    end
    rebuild_mode = rebuild_mode or "snap"

    self:recalc_card_slots()
    local old_map = index_visuals_by_key(self.card_visuals)
    local stable_keys = build_stable_keys(self.state.hand)
    local next_visuals = {}

    for i, card in ipairs(self.state.hand) do
      local stable_key = stable_keys[i]
      local slot = self.card_slots[i]
      local previous = pop_visual(old_map, stable_key)
      local visual = nil

      if previous then
        visual = previous
        visual.index = i
        visual.card = card
        visual.stable_key = stable_key
      else
        visual = self:make_card_visual(i, card, stable_key, rebuild_mode == "deal")
      end

      visual.w = slot.w
      visual.h = slot.h
      visual.to_remove = false
      visual.exiting = false
      visual.target_lift = self.state.selected[i] and -36 or 0

      next_visuals[#next_visuals + 1] = visual
    end

    self.card_visuals = next_visuals

    for i, visual in ipairs(self.card_visuals) do
      local slot = self.card_slots[i]
      local delay = (i - 1) * ((self.anim.reduced_motion and 0) or (0.012))
      if rebuild_mode == "snap" then
        visual.x = slot.x
        visual.y = slot.y
        visual.alpha = 1
        visual.scale = 1
        visual.rotation = 0
      elseif rebuild_mode == "deal" then
        if visual.alpha < 0.99 then
          self.anim:add_tween({
            preset = "card_deal",
            delay = delay,
            subject = visual,
            to = { x = slot.x, y = slot.y, alpha = 1, scale = 1, rotation = 0 },
          })
        else
          self.anim:add_tween({
            preset = "card_reflow",
            delay = delay,
            subject = visual,
            to = { x = slot.x, y = slot.y, alpha = 1, scale = 1, rotation = 0 },
          })
        end
      else
        self.anim:add_tween({
          preset = "card_reflow",
          delay = delay,
          subject = visual,
          to = { x = slot.x, y = slot.y, alpha = 1, scale = 1, rotation = 0 },
        })
      end
    end
  end

  function GameScene:update_selection_lifts(dt)
    local speed = self.anim.reduced_motion and 1 or math.min(1, dt * 16)
    for i, visual in ipairs(self.card_visuals) do
      visual.index = i
      visual.target_lift = self.state.selected[i] and -36 or 0
      visual.lift = visual.lift + ((visual.target_lift or 0) - visual.lift) * speed
    end
  end

  function GameScene:find_visual_by_index(index)
    for _, visual in ipairs(self.card_visuals) do
      if visual.index == index then
        return visual
      end
    end
    return nil
  end

  function GameScene:animate_selected_out(kind, on_complete)
    local indices = self:selected_card_indices()
    if #indices == 0 then
      on_complete()
      return
    end

    local pending = 0
    for order, idx in ipairs(indices) do
      local visual = self:find_visual_by_index(idx)
      if visual then
        visual.exiting = true
        pending = pending + 1
        local direction = kind == "discard" and 44 or -48
        local preset = kind == "discard" and "card_discard" or "card_play"
        self.anim:add_tween({
          preset = preset,
          delay = (order - 1) * ((self.anim.reduced_motion and 0) or 0.016),
          subject = visual,
          to = {
            y = visual.y + direction,
            alpha = 0,
            scale = 0.88,
            rotation = kind == "discard" and -0.11 or 0.12,
          },
          on_complete = function()
            pending = pending - 1
            if pending == 0 then
              on_complete()
            end
          end,
        })
      end
    end

    if pending == 0 then
      on_complete()
    end
  end
end

return M
