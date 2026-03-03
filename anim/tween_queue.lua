local TweenQueue = {}
TweenQueue.__index = TweenQueue

local function ease_linear(t)
  return t
end

local function ease_in_quad(t)
  return t * t
end

local function ease_out_quad(t)
  return 1 - ((1 - t) * (1 - t))
end

local function ease_in_out_quad(t)
  if t < 0.5 then
    return 2 * t * t
  end
  return 1 - (((-2 * t) + 2) ^ 2) * 0.5
end

local function ease_out_back(t)
  local c1 = 1.70158
  local c3 = c1 + 1
  local p = t - 1
  return 1 + (c3 * (p ^ 3)) + (c1 * (p ^ 2))
end

local function lerp(a, b, t)
  return a + (b - a) * t
end

TweenQueue.easings = {
  linear = ease_linear,
  in_quad = ease_in_quad,
  out_quad = ease_out_quad,
  in_out_quad = ease_in_out_quad,
  out_back = ease_out_back,
}

TweenQueue.presets = {
  ui_hover = { duration = 0.10, ease = "out_quad" },
  card_deal = { duration = 0.24, ease = "out_back", stagger = 0.018 },
  card_play = { duration = 0.18, ease = "in_quad", stagger = 0.014 },
  card_discard = { duration = 0.17, ease = "in_quad", stagger = 0.014 },
  card_reflow = { duration = 0.14, ease = "in_out_quad", stagger = 0.012 },
  modal_enter = { duration = 0.16, ease = "out_quad" },
  modal_exit = { duration = 0.12, ease = "in_quad" },
}

local function now_time()
  if love and love.timer and love.timer.getTime then
    return love.timer.getTime()
  end
  return os.clock()
end

function TweenQueue.new(opts)
  opts = opts or {}
  return setmetatable({
    queue = {},
    tweens = {},
    locked = false,
    reduced_motion = opts.reduced_motion == true,
    max_active_tweens = opts.max_active_tweens or 96,
    max_update_seconds = opts.max_update_seconds or (1 / 30),
    frame_budget_seconds = opts.frame_budget_seconds or 0.0028,
    stats = {
      update_ms = 0,
      processed = 0,
      active_tweens = 0,
      dropped_tweens = 0,
    },
  }, TweenQueue)
end

function TweenQueue:set_reduced_motion(enabled)
  self.reduced_motion = enabled == true
end

function TweenQueue:apply_preset(config)
  local preset_key = config and config.preset or nil
  local preset = (preset_key and TweenQueue.presets[preset_key]) or nil
  if not preset then
    return config
  end

  local merged = {}
  for key, value in pairs(preset) do
    merged[key] = value
  end
  for key, value in pairs(config) do
    merged[key] = value
  end
  return merged
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
  local resolved = self:apply_preset(config or {})
  if #self.tweens >= self.max_active_tweens then
    self.stats.dropped_tweens = self.stats.dropped_tweens + 1
    return nil
  end

  local duration = resolved.duration or 0.2
  local ease = resolved.ease or ease_out_quad
  if type(ease) == "string" then
    ease = TweenQueue.easings[ease] or ease_out_quad
  end

  local tween = {
    subject = resolved.subject,
    duration = duration,
    elapsed = 0,
    delay = resolved.delay or 0,
    ease = ease,
    to = resolved.to or {},
    from = {},
    on_complete = resolved.on_complete,
  }

  if not tween.subject then
    return nil
  end

  for key, _ in pairs(tween.to) do
    tween.from[key] = tween.subject[key]
    if tween.from[key] == nil then
      tween.from[key] = 0
      tween.subject[key] = 0
    end
  end

  if self.reduced_motion then
    for key, to_value in pairs(tween.to) do
      tween.subject[key] = to_value
    end
    if tween.on_complete then
      tween.on_complete()
    end
    return tween
  end

  self.tweens[#self.tweens + 1] = tween
  return tween
end

function TweenQueue:update(dt)
  local started_at = now_time()
  local clamped_dt = math.max(0, math.min(dt or 0, self.max_update_seconds))
  local processed = 0
  local i = 1

  while i <= #self.tweens do
    local tween = self.tweens[i]
    local skip_step = false
    if tween.delay and tween.delay > 0 then
      tween.delay = tween.delay - clamped_dt
      if tween.delay > 0 then
        i = i + 1
        skip_step = true
      end
      if not skip_step then
        tween.elapsed = tween.elapsed + math.abs(tween.delay)
        tween.delay = 0
      end
    end

    if not skip_step then
      tween.elapsed = tween.elapsed + clamped_dt
      local t = tween.elapsed / math.max(0.0001, tween.duration)
      if t > 1 then
        t = 1
      end

      local eased = tween.ease(t)
      for key, to_value in pairs(tween.to) do
        tween.subject[key] = lerp(tween.from[key], to_value, eased)
      end

      processed = processed + 1
      if tween.elapsed >= tween.duration then
        if tween.on_complete then
          tween.on_complete()
        end
        table.remove(self.tweens, i)
      else
        i = i + 1
      end
    end

    local elapsed = now_time() - started_at
    if elapsed >= self.frame_budget_seconds then
      break
    end
  end

  self.stats.active_tweens = #self.tweens
  self.stats.processed = processed
  self.stats.update_ms = (now_time() - started_at) * 1000
end

return TweenQueue
