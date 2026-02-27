local M = {}

function M.install(GameScene, game)
  function GameScene:set_message_if_present(result)
    if result and result.message then
      self.state.message = result.message
    end
  end

  function GameScene:apply_logic_action(action_id)
    if action_id == "play" then
      local selected_count = game.selected_count(self.state)
      local result = game.play_selected(self.state)
      self:set_message_if_present(result)
      if result and result.ok then
        self:record_play(selected_count, result)
        if self.state.game_over then
          self:build_run_result()
        end
      end
      return result
    end
    if action_id == "discard" then
      local result = game.discard_selected(self.state)
      self:set_message_if_present(result)
      if result and result.ok then
        self:record_discard()
      end
      return result
    end
    if action_id == "new_run" then
      game.new_run(self.state)
      self:init_run_stats()
      return { ok = true, event = "new_run" }
    end
    if action_id == "add_joker" then
      local result = game.add_joker(self.state)
      self:set_message_if_present(result)
      return result
    end
    if action_id == "royal" then
      game.set_hand_to_royal_flush(self.state)
      return { ok = true, event = "royal" }
    end
    if action_id == "sort_suit" then
      game.sort_hand(self.state, "suit")
      return { ok = true, event = "sorted_suit" }
    end
    if action_id == "sort_rank" then
      game.sort_hand(self.state, "rank")
      return { ok = true, event = "sorted_rank" }
    end
    if action_id == "shop_buy_1" then
      return game.shop_buy_offer(self.state, 1)
    end
    if action_id == "shop_buy_2" then
      return game.shop_buy_offer(self.state, 2)
    end
    if action_id == "shop_buy_3" then
      return game.shop_buy_offer(self.state, 3)
    end
    if action_id == "shop_reroll" then
      return game.shop_reroll(self.state)
    end
    if action_id == "shop_continue" then
      return game.shop_continue(self.state)
    end
    return nil
  end

  function GameScene:enqueue_action(action_id)
    if self.anim.locked then
      return
    end

    local in_shop = self.state.shop and self.state.shop.active
    if in_shop and not (
      action_id == "shop_buy_1"
      or action_id == "shop_buy_2"
      or action_id == "shop_buy_3"
      or action_id == "shop_reroll"
      or action_id == "shop_continue"
      or action_id == "new_run"
    ) then
      self.state.message = "Finish the shop before continuing."
      return
    end

    if action_id == "discard" and self.state.discards <= 0 then
      self.state.message = "No discards left this ante."
      return
    end

    if action_id == "play" and self.state.hands <= 0 then
      self.state.message = "No hands left this ante."
      return
    end

    if action_id == "play" or action_id == "discard" then
      local selected = game.selected_count(self.state)
      if selected == 0 then
        self.state.message = action_id == "play" and "Select at least 1 card to play." or "Select at least 1 card to discard."
        return
      end
    end

    self.anim:push({
      run = function()
        if action_id == "play" or action_id == "discard" then
          self:animate_selected_out(action_id, function()
            local result = self:apply_logic_action(action_id)
            if result and result.ok then
              if not (result.event == "shop_bought" or result.event == "shop_rerolled") then
                self:rebuild_visuals(true)
              end
            end
            self.anim:run_next()
          end)
        else
          local result = self:apply_logic_action(action_id)
          if result and result.ok then
            if not (result.event == "shop_bought" or result.event == "shop_rerolled") then
              self:rebuild_visuals(true)
            end
          end
          self.anim:run_next()
        end
      end,
    })
    self.anim:run_next()
  end

  function GameScene:get_projection()
    local chosen = game.selected_cards(self.state)
    if #chosen == 0 then
      return nil
    end
    return game.calculate_projection(self.state, chosen)
  end
end

return M
