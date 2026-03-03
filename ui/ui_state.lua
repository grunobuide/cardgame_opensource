local UiState = {}
UiState.__index = UiState

local function now_time()
  if love and love.timer and love.timer.getTime then
    return love.timer.getTime()
  end
  return os.clock()
end

local function banner_for_action_result(payload)
  local event = payload and payload.event or nil
  local ok = payload and payload.ok == true
  if not ok then
    local reason = payload and payload.reason or "blocked"
    if reason == "insufficient_money" then
      return "NOT ENOUGH CREDITS", "warn", 1.6, nil
    end
    if reason == "no_hands" or reason == "no_discards" or reason == "no_selection" then
      return "ACTION BLOCKED", "warn", 1.5, nil
    end
    return nil
  end

  if event == "shop" then
    return "BLIND CLEARED - SHOP OPEN", "ok", 2.2, "clear"
  end
  if event == "next_blind" then
    return "NEXT BLIND", "info", 1.8, nil
  end
  if event == "next_ante" then
    return "ANTE UP", "ok", 2.0, "clear"
  end
  if event == "run_won" then
    return "RUN COMPLETE", "ok", 2.6, "victory"
  end
  if event == "game_over" then
    return "BUSTED", "danger", 2.4, "danger"
  end
  if event == "shop_closed" then
    return "BACK TO TABLE", "info", 1.6, nil
  end
  return nil
end

local function trim_history(history, max_items)
  while #history > max_items do
    table.remove(history, #history)
  end
end

function UiState.new(event_bus, opts)
  local self = setmetatable({
    message = "",
    message_severity = "info",
    recent_events = {},
    banner = nil,
    major_fx = nil,
    debug_overlay = false,
    max_recent_events = (opts and opts.max_recent_events) or 10,
    _unsubscribers = {},
    _event_bus = nil,
  }, UiState)

  if event_bus then
    self:attach(event_bus)
  end
  return self
end

function UiState:detach()
  for i = 1, #self._unsubscribers do
    local unsubscribe = self._unsubscribers[i]
    unsubscribe()
  end
  self._unsubscribers = {}
  self._event_bus = nil
end

function UiState:attach(event_bus)
  self:detach()
  self._event_bus = event_bus

  self._unsubscribers[#self._unsubscribers + 1] = event_bus:on("ui:message", function(payload)
    local message = payload and payload.message or ""
    self.message = tostring(message)
    self.message_severity = (payload and payload.severity) or "info"
  end)

  self._unsubscribers[#self._unsubscribers + 1] = event_bus:on("action:result", function(payload)
    self:push_event("action:result", payload)
    self:handle_action_result(payload)
  end)

  self._unsubscribers[#self._unsubscribers + 1] = event_bus:on("action:blocked", function(payload)
    self:push_event("action:blocked", payload)
    self:show_banner((payload and payload.message) or "Action blocked.", "warn", 1.8)
  end)
end

function UiState:toggle_debug_overlay()
  self.debug_overlay = not self.debug_overlay
end

function UiState:show_banner(text, severity, duration, fx_kind)
  local now = now_time()
  self.banner = {
    text = tostring(text or ""),
    severity = severity or "info",
    expires_at = now + (duration or 1.8),
  }
  if fx_kind then
    self.major_fx = {
      kind = fx_kind,
      severity = severity or "info",
      expires_at = now + 0.95,
    }
  end
end

function UiState:handle_action_result(payload)
  local text, severity, duration, fx_kind = banner_for_action_result(payload)
  if text then
    self:show_banner(text, severity, duration, fx_kind)
  end
end

function UiState:get_active_banner()
  local now = now_time()
  if self.banner and now >= (self.banner.expires_at or 0) then
    self.banner = nil
  end
  return self.banner
end

function UiState:get_major_fx()
  local now = now_time()
  if self.major_fx and now >= (self.major_fx.expires_at or 0) then
    self.major_fx = nil
  end
  return self.major_fx
end

function UiState:push_event(kind, payload)
  self.recent_events[#self.recent_events + 1] = {
    kind = kind,
    action_id = payload and payload.action_id or nil,
    event = payload and payload.event or nil,
    reason = payload and payload.reason or nil,
    timestamp = now_time(),
  }
  trim_history(self.recent_events, self.max_recent_events)
end

return UiState
