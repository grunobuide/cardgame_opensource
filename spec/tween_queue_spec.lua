local TweenQueue = require("anim.tween_queue")

describe("tween_queue", function()
  describe("basic tweening", function()
    it("interpolates subject values over time", function()
      local tq = TweenQueue.new({ max_update_seconds = 10 })
      local obj = { x = 0 }
      tq:add_tween({ subject = obj, to = { x = 100 }, duration = 1.0, ease = "linear" })

      tq:update(0.5)
      assert.is_true(obj.x > 40 and obj.x < 60)

      tq:update(0.6)
      assert.are.equal(100, obj.x)
    end)

    it("calls on_complete when tween finishes", function()
      local tq = TweenQueue.new({ max_update_seconds = 10 })
      local obj = { y = 0 }
      local done = false
      tq:add_tween({
        subject = obj,
        to = { y = 10 },
        duration = 0.1,
        ease = "linear",
        on_complete = function() done = true end,
      })

      tq:update(0.2)
      assert.is_true(done)
    end)

    it("drops tweens when at max capacity", function()
      local tq = TweenQueue.new({ max_active_tweens = 2 })
      local a = { x = 0 }
      local b = { x = 0 }
      local c = { x = 0 }
      tq:add_tween({ subject = a, to = { x = 1 }, duration = 1 })
      tq:add_tween({ subject = b, to = { x = 1 }, duration = 1 })
      local result = tq:add_tween({ subject = c, to = { x = 1 }, duration = 1 })
      assert.is_nil(result)
      assert.are.equal(1, tq.stats.dropped_tweens)
    end)
  end)

  describe("reduced motion", function()
    it("snaps to final value immediately", function()
      local tq = TweenQueue.new({ reduced_motion = true })
      local obj = { x = 0 }
      local done = false
      tq:add_tween({
        subject = obj,
        to = { x = 50 },
        duration = 1.0,
        on_complete = function() done = true end,
      })
      assert.are.equal(50, obj.x)
      assert.is_true(done)
      assert.are.equal(0, #tq.tweens)
    end)
  end)

  describe("error resilience", function()
    it("survives on_complete error during update", function()
      local tq = TweenQueue.new({ max_update_seconds = 10 })
      local obj = { x = 0 }
      local second_done = false
      tq:add_tween({
        subject = obj,
        to = { x = 10 },
        duration = 0.1,
        ease = "linear",
        on_complete = function() error("callback crash!") end,
      })
      local obj2 = { y = 0 }
      tq:add_tween({
        subject = obj2,
        to = { y = 20 },
        duration = 0.1,
        ease = "linear",
        on_complete = function() second_done = true end,
      })

      -- Should not crash; both tweens complete
      tq:update(1.0)
      assert.are.equal(10, obj.x)
      assert.are.equal(20, obj2.y)
      assert.is_true(second_done)
      assert.are.equal(1, tq.stats.callback_errors)
    end)

    it("survives on_complete error in reduced motion", function()
      local tq = TweenQueue.new({ reduced_motion = true })
      local obj = { x = 0 }
      tq:add_tween({
        subject = obj,
        to = { x = 99 },
        duration = 1.0,
        on_complete = function() error("boom in reduced motion") end,
      })
      assert.are.equal(99, obj.x)
      assert.are.equal(1, tq.stats.callback_errors)
    end)

    it("run_next does not infinite-loop on malformed queue items", function()
      local tq = TweenQueue.new()
      -- Push items without .run
      for i = 1, 100 do
        tq:push({})
      end
      -- Should not stack-overflow; should drain safely
      tq:run_next()
      assert.is_false(tq.locked)
    end)

    it("run_next catches step.run errors", function()
      local tq = TweenQueue.new()
      tq:push({ run = function() error("step exploded") end })
      tq:run_next()
      assert.are.equal(1, tq.stats.step_errors)
    end)
  end)

  describe("presets", function()
    it("applies preset values merged with overrides", function()
      local tq = TweenQueue.new()
      local config = tq:apply_preset({ preset = "ui_hover", duration = 0.5 })
      assert.are.equal(0.5, config.duration) -- override wins
      assert.are.equal("out_quad", config.ease) -- from preset
    end)

    it("returns config unchanged for unknown preset", function()
      local tq = TweenQueue.new()
      local config = tq:apply_preset({ preset = "nonexistent", duration = 0.3 })
      assert.are.equal(0.3, config.duration)
    end)
  end)

  describe("stats tracking", function()
    it("tracks active tweens and processed count", function()
      local tq = TweenQueue.new({ max_update_seconds = 10 })
      local obj = { x = 0 }
      tq:add_tween({ subject = obj, to = { x = 10 }, duration = 1.0 })
      tq:update(0.01)
      assert.are.equal(1, tq.stats.active_tweens)
      assert.are.equal(1, tq.stats.processed)
    end)
  end)
end)
