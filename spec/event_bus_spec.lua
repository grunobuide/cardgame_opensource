local EventBus = require("src.event_bus")
local UiState = require("ui.ui_state")

describe("event_bus", function()
  it("emits payloads to subscribers", function()
    local bus = EventBus.new()
    local received = nil

    bus:on("test:event", function(payload)
      received = payload
    end)
    bus:emit("test:event", { value = 42 })

    assert.is_truthy(received)
    assert.are.equal(42, received.value)
  end)

  it("supports once subscriptions", function()
    local bus = EventBus.new()
    local count = 0

    bus:once("tick", function()
      count = count + 1
    end)

    bus:emit("tick")
    bus:emit("tick")

    assert.are.equal(1, count)
  end)

  it("supports unsubscribe returned by on()", function()
    local bus = EventBus.new()
    local count = 0

    local unsubscribe = bus:on("evt", function()
      count = count + 1
    end)
    bus:emit("evt")
    unsubscribe()
    bus:emit("evt")

    assert.are.equal(1, count)
  end)

  it("continues to next handler when one throws", function()
    local bus = EventBus.new()
    local second_called = false
    bus:on("boom", function() error("handler 1 failed!") end)
    bus:on("boom", function() second_called = true end)
    bus:emit("boom")
    assert.is_true(second_called)
  end)

  it("records errors for inspection via last_error", function()
    local bus = EventBus.new()
    bus:on("err", function() error("oops") end)
    bus:emit("err")
    local last = bus:last_error()
    assert.is_truthy(last)
    assert.are.equal("err", last.event)
    assert.is_truthy(last.error:find("oops"))
  end)

  it("drain_errors returns and clears the error log", function()
    local bus = EventBus.new()
    bus:on("e", function() error("fail") end)
    bus:emit("e")
    bus:emit("e")
    local errs = bus:drain_errors()
    assert.are.equal(2, #errs)
    assert.is_nil(bus:last_error())
  end)

  it("once handler error does not leave listener registered", function()
    local bus = EventBus.new()
    local count = 0
    bus:once("x", function()
      count = count + 1
      error("once handler failed")
    end)
    bus:emit("x")
    bus:emit("x")
    assert.are.equal(1, count)
  end)
end)

describe("ui_state", function()
  it("updates message from ui:message events and tracks action events", function()
    local bus = EventBus.new()
    local ui_state = UiState.new(bus, { max_recent_events = 5 })

    bus:emit("ui:message", { message = "hello", severity = "warn" })
    bus:emit("action:result", { action_id = "play", event = "played" })
    bus:emit("action:blocked", { action_id = "discard", reason = "no_discards" })

    assert.are.equal("hello", ui_state.message)
    assert.are.equal("warn", ui_state.message_severity)
    assert.are.equal(2, #ui_state.recent_events)
    assert.are.equal("action:result", ui_state.recent_events[1].kind)
    assert.are.equal("action:blocked", ui_state.recent_events[2].kind)
  end)
end)
