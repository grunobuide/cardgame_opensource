local EventBus = {}
EventBus.__index = EventBus

function EventBus.new()
  return setmetatable({
    listeners = {},
    errors = {},
  }, EventBus)
end

function EventBus:on(event_name, handler)
  if type(event_name) ~= "string" or event_name == "" then
    error("event_name must be a non-empty string")
  end
  if type(handler) ~= "function" then
    error("handler must be a function")
  end

  local bucket = self.listeners[event_name]
  if not bucket then
    bucket = {}
    self.listeners[event_name] = bucket
  end
  bucket[#bucket + 1] = handler

  return function()
    self:off(event_name, handler)
  end
end

function EventBus:once(event_name, handler)
  local unsubscribe = nil
  unsubscribe = self:on(event_name, function(payload)
    if unsubscribe then
      unsubscribe()
      unsubscribe = nil
    end
    handler(payload)
  end)
  return unsubscribe
end

function EventBus:off(event_name, handler)
  local bucket = self.listeners[event_name]
  if not bucket then
    return false
  end

  for i = #bucket, 1, -1 do
    if bucket[i] == handler then
      table.remove(bucket, i)
      if #bucket == 0 then
        self.listeners[event_name] = nil
      end
      return true
    end
  end
  return false
end

function EventBus:emit(event_name, payload)
  local bucket = self.listeners[event_name]
  if not bucket or #bucket == 0 then
    return
  end

  -- Snapshot listeners to allow safe unsubscribe during emit.
  local snapshot = {}
  for i = 1, #bucket do
    snapshot[i] = bucket[i]
  end
  for i = 1, #snapshot do
    local ok, err = pcall(snapshot[i], payload)
    if not ok then
      self.errors[#self.errors + 1] = {
        event = event_name,
        error = tostring(err),
        handler_index = i,
      }
    end
  end
end

function EventBus:last_error()
  if #self.errors == 0 then
    return nil
  end
  return self.errors[#self.errors]
end

function EventBus:drain_errors()
  local errs = self.errors
  self.errors = {}
  return errs
end

return EventBus
