local TweenQueue = {}
TweenQueue.__index = TweenQueue

local function ease_out_quad(t)
  return 1 - ((1 - t) * (1 - t))
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

function TweenQueue.new()
  return setmetatable({
    queue = {},
    tweens = {},
    locked = false,
  }, TweenQueue)
end

function TweenQueue:push(step)
  self.queue[#self.queue + 1] = step
  self.locked = true
end

function TweenQueue:run_next()
  if #self.queue == 0 then
    self.locked = false
    return
  end

  local step = table.remove(self.queue, 1)
  if step and step.run then
    step.run()
  else
    self:run_next()
  end
end

function TweenQueue:add_tween(config)
  local tween = {
    subject = config.subject,
    duration = config.duration or 0.2,
    elapsed = 0,
    ease = config.ease or ease_out_quad,
    to = config.to or {},
    from = {},
    on_complete = config.on_complete,
  }

  for key, _ in pairs(tween.to) do
    tween.from[key] = tween.subject[key]
    if tween.from[key] == nil then
      tween.from[key] = 0
      tween.subject[key] = 0
    end
  end

  self.tweens[#self.tweens + 1] = tween
  return tween
end

function TweenQueue:update(dt)
  local i = 1
  while i <= #self.tweens do
    local tween = self.tweens[i]
    tween.elapsed = tween.elapsed + dt
    local t = tween.elapsed / tween.duration
    if t > 1 then
      t = 1
    end

    local eased = tween.ease(t)
    for key, to_value in pairs(tween.to) do
      tween.subject[key] = lerp(tween.from[key], to_value, eased)
    end

    if tween.elapsed >= tween.duration then
      if tween.on_complete then
        tween.on_complete()
      end
      table.remove(self.tweens, i)
    else
      i = i + 1
    end
  end
end

return TweenQueue
