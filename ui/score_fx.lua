local ScoreFx = {}
ScoreFx.__index = ScoreFx

local MAX_POPUPS = 24

function ScoreFx.new(opts)
  opts = opts or {}
  return setmetatable({
    popups = {},
    max_popups = opts.max_popups or MAX_POPUPS,
    reduced_motion = opts.reduced_motion == true,
    display_score = 0,
    target_score = 0,
    score_tick_speed = 0,
  }, ScoreFx)
end

function ScoreFx:set_reduced_motion(enabled)
  self.reduced_motion = enabled == true
end

function ScoreFx:spawn(config)
  if #self.popups >= self.max_popups then
    table.remove(self.popups, 1)
  end

  local popup = {
    text = config.text or "+0",
    x = config.x or 0,
    y = config.y or 0,
    color = config.color or { 1, 1, 1, 1 },
    lifetime = config.lifetime or 1.2,
    elapsed = 0,
    rise_speed = config.rise_speed or 40,
    scale = config.scale or 1.0,
    kind = config.kind or "chips",
  }

  if self.reduced_motion then
    popup.elapsed = popup.lifetime
  end

  self.popups[#self.popups + 1] = popup
  return popup
end

function ScoreFx:spawn_score(chips, mult, total, x, y)
  local cy = y or 0
  self:spawn({
    text = ("+ %d"):format(chips),
    x = x or 0,
    y = cy,
    color = { 0.0, 0.898, 1.0, 1.0 },
    kind = "chips",
    lifetime = 1.2,
  })
  self:spawn({
    text = ("x %d"):format(mult),
    x = (x or 0) + 80,
    y = cy,
    color = { 1.0, 0.180, 0.820, 1.0 },
    kind = "mult",
    lifetime = 1.2,
  })
  self:spawn({
    text = ("= %d"):format(total),
    x = (x or 0) + 40,
    y = cy + 22,
    color = { 0.957, 0.957, 1.0, 1.0 },
    kind = "total",
    lifetime = 1.4,
    scale = 1.2,
  })
end

function ScoreFx:set_target_score(score)
  self.target_score = score
  local delta = math.abs(self.target_score - self.display_score)
  self.score_tick_speed = math.max(delta * 3.5, 50)
end

function ScoreFx:update(dt)
  if self.reduced_motion then
    self.display_score = self.target_score
    self.popups = {}
    return
  end

  -- Tick display score toward target
  if self.display_score < self.target_score then
    self.display_score = math.min(self.target_score, self.display_score + self.score_tick_speed * dt)
  elseif self.display_score > self.target_score then
    self.display_score = self.target_score
  end

  -- Age popups
  local i = 1
  while i <= #self.popups do
    local p = self.popups[i]
    p.elapsed = p.elapsed + dt
    p.y = p.y - p.rise_speed * dt
    if p.elapsed >= p.lifetime then
      table.remove(self.popups, i)
    else
      i = i + 1
    end
  end
end

function ScoreFx:active_popups()
  return self.popups
end

function ScoreFx:get_display_score()
  return math.floor(self.display_score)
end

return ScoreFx
