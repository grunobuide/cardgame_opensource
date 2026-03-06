local ParticleEmitter = {}
ParticleEmitter.__index = ParticleEmitter

local MAX_PARTICLES = 128

function ParticleEmitter.new(opts)
  opts = opts or {}
  return setmetatable({
    particles = {},
    max_particles = opts.max_particles or MAX_PARTICLES,
    reduced_motion = opts.reduced_motion == true,
  }, ParticleEmitter)
end

function ParticleEmitter:set_reduced_motion(enabled)
  self.reduced_motion = enabled == true
  if self.reduced_motion then
    self.particles = {}
  end
end

function ParticleEmitter:emit(config)
  if self.reduced_motion then
    return
  end

  local count = config.count or 6
  local x = config.x or 0
  local y = config.y or 0
  local color = config.color or { 1, 1, 1, 1 }
  local spread = config.spread or 30
  local lifetime = config.lifetime or 0.8
  local speed = config.speed or 60
  local size = config.size or 3

  for _ = 1, count do
    if #self.particles >= self.max_particles then
      table.remove(self.particles, 1)
    end

    local angle = math.random() * math.pi * 2
    local spd = speed * (0.4 + math.random() * 0.6)
    local lt = lifetime * (0.6 + math.random() * 0.4)

    self.particles[#self.particles + 1] = {
      x = x + (math.random() - 0.5) * spread,
      y = y + (math.random() - 0.5) * spread,
      vx = math.cos(angle) * spd,
      vy = -math.abs(math.sin(angle) * spd) - 20,
      color = { color[1], color[2], color[3], color[4] or 1 },
      lifetime = lt,
      elapsed = 0,
      size = size * (0.5 + math.random() * 0.5),
    }
  end
end

function ParticleEmitter:emit_chips(x, y)
  self:emit({
    x = x, y = y,
    color = { 0.0, 0.898, 1.0, 1.0 },
    count = 8,
    spread = 20,
    speed = 55,
    lifetime = 0.7,
    size = 3,
  })
end

function ParticleEmitter:emit_mult(x, y)
  self:emit({
    x = x, y = y,
    color = { 1.0, 0.180, 0.820, 1.0 },
    count = 8,
    spread = 20,
    speed = 55,
    lifetime = 0.7,
    size = 3,
  })
end

function ParticleEmitter:emit_joker(x, y)
  self:emit({
    x = x, y = y,
    color = { 0.447, 1.0, 0.353, 1.0 },
    count = 5,
    spread = 14,
    speed = 40,
    lifetime = 0.5,
    size = 2,
  })
end

function ParticleEmitter:update(dt)
  if self.reduced_motion then
    return
  end

  local i = 1
  while i <= #self.particles do
    local p = self.particles[i]
    p.elapsed = p.elapsed + dt
    if p.elapsed >= p.lifetime then
      table.remove(self.particles, i)
    else
      p.x = p.x + p.vx * dt
      p.y = p.y + p.vy * dt
      p.vy = p.vy + 30 * dt
      i = i + 1
    end
  end
end

function ParticleEmitter:active_particles()
  return self.particles
end

function ParticleEmitter:count()
  return #self.particles
end

return ParticleEmitter
