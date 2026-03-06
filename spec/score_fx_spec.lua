local ScoreFx = require("ui.score_fx")

describe("score_fx", function()
  describe("popup management", function()
    it("spawns and ages popups", function()
      local fx = ScoreFx.new()
      fx:spawn({ text = "+100", x = 50, y = 50, lifetime = 1.0 })
      assert.are.equal(1, #fx:active_popups())

      fx:update(0.5)
      assert.are.equal(1, #fx:active_popups())
      local p = fx:active_popups()[1]
      assert.is_true(p.y < 50) -- risen upward

      fx:update(0.6)
      assert.are.equal(0, #fx:active_popups()) -- expired
    end)

    it("respects max_popups cap", function()
      local fx = ScoreFx.new({ max_popups = 3 })
      for i = 1, 5 do
        fx:spawn({ text = "+" .. i, lifetime = 10 })
      end
      assert.are.equal(3, #fx:active_popups())
    end)

    it("spawn_score creates chips, mult, total popups", function()
      local fx = ScoreFx.new()
      fx:spawn_score(100, 5, 500, 200, 300)
      assert.are.equal(3, #fx:active_popups())
      local kinds = {}
      for _, p in ipairs(fx:active_popups()) do
        kinds[p.kind] = true
      end
      assert.is_true(kinds.chips)
      assert.is_true(kinds.mult)
      assert.is_true(kinds.total)
    end)
  end)

  describe("rolling score", function()
    it("ticks display score toward target", function()
      local fx = ScoreFx.new()
      fx:set_target_score(100)
      fx:update(0.1)
      assert.is_true(fx:get_display_score() > 0)
      assert.is_true(fx:get_display_score() <= 100)

      -- After enough time, reaches target
      for _ = 1, 50 do
        fx:update(0.1)
      end
      assert.are.equal(100, fx:get_display_score())
    end)

    it("snaps immediately in reduced motion", function()
      local fx = ScoreFx.new({ reduced_motion = true })
      fx:set_target_score(500)
      fx:update(0.01)
      assert.are.equal(500, fx:get_display_score())
    end)
  end)

  describe("reduced motion", function()
    it("skips popups entirely", function()
      local fx = ScoreFx.new({ reduced_motion = true })
      fx:spawn({ text = "+100", lifetime = 5 })
      -- Popup is marked as expired immediately
      fx:update(0.01)
      assert.are.equal(0, #fx:active_popups())
    end)

    it("can toggle reduced motion", function()
      local fx = ScoreFx.new()
      fx:spawn({ text = "+50", lifetime = 5 })
      assert.are.equal(1, #fx:active_popups())

      fx:set_reduced_motion(true)
      fx:update(0.01)
      assert.are.equal(0, #fx:active_popups())
    end)
  end)
end)
