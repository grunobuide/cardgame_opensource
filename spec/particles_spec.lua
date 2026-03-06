local ParticleEmitter = require("anim.particles")

describe("particle_emitter", function()
  describe("emission", function()
    it("spawns particles at a position", function()
      local emitter = ParticleEmitter.new()
      emitter:emit({ x = 100, y = 200, count = 5 })
      assert.are.equal(5, emitter:count())
    end)

    it("ages and removes expired particles", function()
      local emitter = ParticleEmitter.new()
      emitter:emit({ x = 0, y = 0, count = 3, lifetime = 0.5 })
      assert.are.equal(3, emitter:count())

      emitter:update(0.3)
      assert.are.equal(3, emitter:count()) -- still alive

      emitter:update(0.4)
      assert.are.equal(0, emitter:count()) -- all expired
    end)

    it("enforces max particle cap", function()
      local emitter = ParticleEmitter.new({ max_particles = 10 })
      emitter:emit({ x = 0, y = 0, count = 8, lifetime = 10 })
      emitter:emit({ x = 0, y = 0, count = 8, lifetime = 10 })
      assert.is_true(emitter:count() <= 10)
    end)

    it("convenience emitters create correct particle counts", function()
      local emitter = ParticleEmitter.new()
      emitter:emit_chips(100, 100)
      assert.are.equal(8, emitter:count())

      emitter = ParticleEmitter.new()
      emitter:emit_mult(100, 100)
      assert.are.equal(8, emitter:count())

      emitter = ParticleEmitter.new()
      emitter:emit_joker(100, 100)
      assert.are.equal(5, emitter:count())
    end)
  end)

  describe("reduced motion", function()
    it("does not emit in reduced motion", function()
      local emitter = ParticleEmitter.new({ reduced_motion = true })
      emitter:emit({ x = 0, y = 0, count = 10 })
      assert.are.equal(0, emitter:count())
    end)

    it("clears particles when reduced motion is enabled", function()
      local emitter = ParticleEmitter.new()
      emitter:emit({ x = 0, y = 0, count = 5, lifetime = 10 })
      assert.are.equal(5, emitter:count())

      emitter:set_reduced_motion(true)
      assert.are.equal(0, emitter:count())
    end)
  end)

  describe("physics", function()
    it("moves particles over time", function()
      local emitter = ParticleEmitter.new()
      emitter:emit({ x = 100, y = 100, count = 1, lifetime = 5, speed = 60, spread = 0 })
      local p = emitter:active_particles()[1]
      local initial_y = p.y

      emitter:update(0.5)
      -- Particle should have moved
      assert.is_true(p.y ~= initial_y)
    end)
  end)
end)
