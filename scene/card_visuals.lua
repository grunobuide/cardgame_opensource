local Layout = require("ui.layout")

local M = {}

function M.install(GameScene, game)
  function GameScene:selected_card_indices()
    local _, indices = game.selected_cards(self.state)
    return indices
  end

  function GameScene:recalc_card_slots()
    self.card_slots = Layout.card_slots(#self.state.hand)
  end

  function GameScene:make_card_visual(index, card, from_deal)
    local slot = self.card_slots[index]
    if not slot then
      return nil
    end
    local visual = {
      uid = self.next_uid,
      index = index,
      card = card,
      x = slot.x,
      y = from_deal and (slot.y - 42) or slot.y,
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

  function GameScene:rebuild_visuals(from_deal)
    self:recalc_card_slots()
    self.card_visuals = {}
    for i, card in ipairs(self.state.hand) do
      local visual = self:make_card_visual(i, card, from_deal)
      self.card_visuals[#self.card_visuals + 1] = visual
      if from_deal then
        self.anim:add_tween({
          subject = visual,
          duration = 0.26 + i * 0.02,
          to = { y = self.card_slots[i].y, alpha = 1 },
        })
      end
    end
  end

  function GameScene:update_selection_lifts(dt)
    for i, visual in ipairs(self.card_visuals) do
      visual.index = i
      visual.target_lift = self.state.selected[i] and -18 or 0
      local speed = math.min(1, dt * 16)
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
    for _, idx in ipairs(indices) do
      local visual = self:find_visual_by_index(idx)
      if visual then
        visual.exiting = true
        pending = pending + 1
        local direction = kind == "discard" and 40 or -42
        self.anim:add_tween({
          subject = visual,
          duration = 0.22,
          to = {
            y = visual.y + direction,
            alpha = 0,
            scale = 0.88,
            rotation = kind == "discard" and -0.1 or 0.1,
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
