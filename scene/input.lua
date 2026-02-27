local M = {}

function M.install(GameScene, game)
  function GameScene:mousepressed(x, y, button)
    if button ~= 1 or self.anim.locked then
      return
    end
    x, y = self:to_virtual(x, y)
    if x < 0 or y < 0 or x > self.base_width or y > self.base_height then
      return
    end

    if self.run_result then
      self:enqueue_action("new_run")
      return
    end

    if self.state.shop and self.state.shop.active then
      return
    end

    for i = #self.card_visuals, 1, -1 do
      local visual = self.card_visuals[i]
      local cx = visual.x
      local cy = visual.y + visual.lift
      if x >= cx and x <= cx + visual.w and y >= cy and y <= cy + visual.h then
        local ok, msg = game.toggle_selection(self.state, visual.index)
        if not ok and msg then
          self.state.message = msg
        end
        return
      end
    end

    for _, btn in ipairs(self.buttons) do
      if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        self:enqueue_action(btn.id)
        return
      end
    end
  end

  function GameScene:keypressed(key)
    if self.seed_input_mode then
      if key == "return" or key == "kpenter" then
        self.seed_input_mode = false
        self:apply_seed(self.seed_buffer, true)
        self.state.message = ("Seed set to %s. New run started."):format(self.current_seed)
        return
      end
      if key == "escape" then
        self.seed_input_mode = false
        self.seed_buffer = ""
        self.state.message = "Seed entry cancelled."
        return
      end
      if key == "backspace" then
        if #self.seed_buffer > 0 then
          self.seed_buffer = string.sub(self.seed_buffer, 1, #self.seed_buffer - 1)
        end
        return
      end
    end

    if key == "t" then
      self.theme = (self.theme == "dark") and "light" or "dark"
      return
    end

    if key == "k" then
      self.seed_input_mode = true
      self.seed_buffer = self.current_seed
      self.state.message = "Seed entry mode: type seed and press Enter."
      return
    end
    if key == "g" then
      self:apply_seed("", true)
      self.state.message = ("Generated new seed: %s"):format(self.current_seed)
      return
    end

    if self.anim.locked then
      return
    end

    if self.state.shop and self.state.shop.active then
      if key == "1" then
        self:enqueue_action("shop_buy_1")
        return
      end
      if key == "2" then
        self:enqueue_action("shop_buy_2")
        return
      end
      if key == "3" then
        self:enqueue_action("shop_buy_3")
        return
      end
      if key == "e" then
        self:enqueue_action("shop_reroll")
        return
      end
      if key == "c" or key == "return" or key == "kpenter" then
        self:enqueue_action("shop_continue")
        return
      end
      self.state.message = "Shop controls: 1/2/3 buy | E reroll | C continue"
      return
    end

    if self.run_result then
      if key == "return" or key == "kpenter" or key == "space" then
        self:enqueue_action("new_run")
      end
      return
    end

    if key == "space" then
      self:enqueue_action("play")
      return
    end
    if key == "d" then
      self:enqueue_action("discard")
      return
    end
    if key == "r" then
      self:enqueue_action("new_run")
      return
    end
    if key == "j" then
      self:enqueue_action("add_joker")
      return
    end
    if key == "f" then
      self:enqueue_action("royal")
      return
    end
    if key == "s" then
      self:enqueue_action("sort_suit")
      return
    end
    if key == "n" then
      self:enqueue_action("sort_rank")
      return
    end

    local n = tonumber(key)
    if n and n >= 1 and n <= #self.state.hand then
      local ok, msg = game.toggle_selection(self.state, n)
      if not ok and msg then
        self.state.message = msg
      end
    end
  end

  function GameScene:textinput(text)
    if not self.seed_input_mode then
      return
    end

    if text and text ~= "" then
      self.seed_buffer = self.seed_buffer .. text
    end
  end
end

return M
