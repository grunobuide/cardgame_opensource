local M = {}

function M.install(GameScene, game)
  local block_messages = {
    shop_active = {
      message = "Shop is active. Buy, reroll, or press C to continue.",
      severity = "warn",
    },
    no_discards = {
      message = "No discards left this ante. Play a hand or start a new run.",
      severity = "warn",
    },
    no_hands = {
      message = "No hands left this ante. Discard for outs or start a new run.",
      severity = "warn",
    },
    no_selection_play = {
      message = "Select cards first (click cards or press 1..8), then PLAY.",
      severity = "warn",
    },
    no_selection_discard = {
      message = "Select cards first (click cards or press 1..8), then DISCARD.",
      severity = "warn",
    },
  }

  local function is_non_rebuild_shop_event(event_name)
    return event_name == "shop_bought"
      or event_name == "shop_rerolled"
      or event_name == "shop_sold_joker"
      or event_name == "shop_sold_card"
      or event_name == "shop_deck_removed"
      or event_name == "shop_deck_upgraded"
      or event_name == "shop_deck_duplicated"
  end

  local function rebuild_mode_for(action_id, result)
    if not result or not result.ok then
      return "snap"
    end
    if action_id == "sort_suit" or action_id == "sort_rank" then
      return "reflow"
    end
    if action_id == "add_joker" or action_id == "royal" then
      return "reflow"
    end
    if action_id == "new_run" then
      return "deal"
    end
    if action_id == "play" or action_id == "discard" then
      return "deal"
    end
    return "reflow"
  end

  local function severity_for_result(result, action_id)
    if not result then
      if action_id == "new_run" then
        return "ok"
      end
      return "info"
    end

    if not result.ok then
      if result.reason == "game_over" then
        return "danger"
      end
      return "warn"
    end

    if result.event == "run_won" then
      return "ok"
    end
    if result.event == "game_over" then
      return "danger"
    end
    if result.event == "shop" then
      return "ok"
    end
    if result.event == "next_ante" or result.event == "next_blind" then
      return "info"
    end
    if result.event == "shop_bought"
      or result.event == "shop_sold_joker"
      or result.event == "shop_sold_card"
      or result.event == "shop_rerolled"
      or result.event == "shop_deck_removed"
      or result.event == "shop_deck_upgraded"
      or result.event == "shop_deck_duplicated"
    then
      return "info"
    end
    if action_id == "play" then
      return "ok"
    end
    return "info"
  end

  function GameScene:emit_event(event_name, payload)
    if self.event_bus then
      self.event_bus:emit(event_name, payload)
    end
  end

  function GameScene:publish_message(message, severity, source)
    local text = tostring(message or "")
    self.state.message = text
    self:emit_event("ui:message", {
      message = text,
      severity = severity or "info",
      source = source or "scene",
    })
  end

  function GameScene:block_action(action_id, reason, message, severity)
    self:publish_message(message, severity or "warn", reason or "rules")
    self:emit_event("action:blocked", {
      action_id = action_id,
      reason = reason,
      message = message,
    })
  end

  function GameScene:set_message_if_present(result)
    if result and result.message then
      local severity = severity_for_result(result)
      self:publish_message(result.message, severity, "logic_result")
    end
  end

  function GameScene:apply_logic_action(action_id)
    local message_before = self.state.message
    local result = nil

    if action_id == "play" then
      local selected_count = game.selected_count(self.state)
      result = game.play_selected(self.state)
      if result and result.ok then
        self:record_play(selected_count, result)
        if self.state.game_over then
          self:build_run_result()
        end
      end
    elseif action_id == "discard" then
      result = game.discard_selected(self.state)
      if result and result.ok then
        self:record_discard()
      end
    elseif action_id == "new_run" then
      game.new_run(self.state)
      self:init_run_stats()
      self.ui_panel_intro = 0
      result = { ok = true, event = "new_run" }
    elseif action_id == "add_joker" then
      result = game.add_joker(self.state)
    elseif action_id == "royal" then
      game.set_hand_to_royal_flush(self.state)
      result = { ok = true, event = "royal" }
    elseif action_id == "sort_suit" then
      game.sort_hand(self.state, "suit")
      result = { ok = true, event = "sorted_suit" }
    elseif action_id == "sort_rank" then
      game.sort_hand(self.state, "rank")
      result = { ok = true, event = "sorted_rank" }
    elseif action_id == "shop_buy_1" then
      result = game.shop_buy_offer(self.state, 1)
    elseif action_id == "shop_buy_2" then
      result = game.shop_buy_offer(self.state, 2)
    elseif action_id == "shop_buy_3" then
      result = game.shop_buy_offer(self.state, 3)
    elseif action_id == "shop_reroll" then
      result = game.shop_reroll(self.state)
    elseif action_id == "shop_continue" then
      result = game.shop_continue(self.state)
    elseif action_id == "shop_deck_remove" then
      result = game.shop_deck_remove(self.state)
    elseif action_id == "shop_deck_upgrade" then
      result = game.shop_deck_upgrade(self.state)
    elseif action_id == "shop_deck_duplicate" then
      result = game.shop_deck_duplicate(self.state)
    else
      local sell_joker_idx = action_id:match("^shop_sell_joker_(%d+)$")
      if sell_joker_idx then
        result = game.shop_sell_joker(self.state, tonumber(sell_joker_idx))
      else
        local sell_card_idx = action_id:match("^shop_sell_card_(%d+)$")
        if sell_card_idx then
          result = game.shop_sell_card(self.state, tonumber(sell_card_idx))
        end
      end
    end

    self:set_message_if_present(result)
    if result and not result.message and self.state.message ~= message_before then
      self:publish_message(self.state.message, severity_for_result(result, action_id), "logic_state")
    end

    self:emit_event("action:result", {
      action_id = action_id,
      ok = result and result.ok or false,
      event = result and result.event or nil,
      reason = result and result.reason or nil,
      result = result,
    })

    return result
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
      or action_id == "shop_deck_remove"
      or action_id == "shop_deck_upgrade"
      or action_id == "shop_deck_duplicate"
      or action_id:match("^shop_sell_joker_%d+$")
      or action_id:match("^shop_sell_card_%d+$")
      or action_id == "new_run"
    ) then
      local payload = block_messages.shop_active
      self:block_action(action_id, "shop_active", payload.message, payload.severity)
      return
    end

    if action_id == "discard" and self.state.discards <= 0 then
      local payload = block_messages.no_discards
      self:block_action(action_id, "no_discards", payload.message, payload.severity)
      return
    end

    if action_id == "play" and self.state.hands <= 0 then
      local payload = block_messages.no_hands
      self:block_action(action_id, "no_hands", payload.message, payload.severity)
      return
    end

    if action_id == "play" or action_id == "discard" then
      local selected = game.selected_count(self.state)
      if selected == 0 then
        local payload = action_id == "play" and block_messages.no_selection_play or block_messages.no_selection_discard
        self:block_action(action_id, "no_selection", payload.message, payload.severity)
        return
      end
    end

    self:emit_event("action:queued", { action_id = action_id })
    self.anim:push({
      run = function()
        if action_id == "play" or action_id == "discard" then
          self:animate_selected_out(action_id, function()
            local result = self:apply_logic_action(action_id)
            if result and result.ok then
              if not is_non_rebuild_shop_event(result.event) then
                self:rebuild_visuals(rebuild_mode_for(action_id, result))
              end
            end
            self.anim:run_next()
          end)
        else
          local result = self:apply_logic_action(action_id)
          if result and result.ok then
            if not is_non_rebuild_shop_event(result.event) then
              self:rebuild_visuals(rebuild_mode_for(action_id, result))
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
