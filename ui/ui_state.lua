local UiState = {}
UiState.__index = UiState

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
  end)

  self._unsubscribers[#self._unsubscribers + 1] = event_bus:on("action:blocked", function(payload)
    self:push_event("action:blocked", payload)
  end)
end

function UiState:toggle_debug_overlay()
  self.debug_overlay = not self.debug_overlay
end

function UiState:push_event(kind, payload)
  self.recent_events[#self.recent_events + 1] = {
    kind = kind,
    action_id = payload and payload.action_id or nil,
    event = payload and payload.event or nil,
    reason = payload and payload.reason or nil,
    timestamp = love and love.timer and love.timer.getTime and love.timer.getTime() or os.clock(),
  }
  trim_history(self.recent_events, self.max_recent_events)
end

return UiState
