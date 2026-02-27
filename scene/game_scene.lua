local game = require("src.game_logic")
local TweenQueue = require("anim.tween_queue")
local Palette = require("ui.palette")
local Render = require("ui.render")
local Layout = require("ui.layout")
local CardVisuals = require("scene.card_visuals")
local Actions = require("scene.actions")
local Input = require("scene.input")

local GameScene = {}
GameScene.__index = GameScene

local function trim(text)
  return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

function GameScene.new()
  return setmetatable({
    state = nil,
    theme = "dark",
    fonts = {},
    buttons = {},
    card_slots = {},
    card_visuals = {},
    next_uid = 1,
    anim = TweenQueue.new(),
    image_cache = {},
    run_stats = nil,
    run_result = nil,
    seed_input_mode = false,
    seed_buffer = "",
    current_seed = "",
    base_width = 960,
    base_height = 790,
    viewport_scale = 1,
    viewport_offset_x = 0,
    viewport_offset_y = 0,
    mouse_x = 0,
    mouse_y = 0,
  }, GameScene)
end

function GameScene:palette()
  return Palette.get(self.theme)
end

function GameScene:generate_seed()
  local millis = math.floor((love.timer.getTime() * 1000) % 1000000)
  return tostring(os.time()) .. "-" .. tostring(millis)
end

function GameScene:apply_seed(seed, start_new_run)
  local normalized = trim(seed)
  if normalized == "" then
    normalized = self:generate_seed()
  end
  self.current_seed = normalized
  game.set_seed(self.state, normalized, game.make_seeded_rng(normalized))

  if start_new_run then
    game.new_run(self.state)
    self:init_run_stats()
    self:rebuild_visuals(false)
  end
end

function GameScene:get_image(path)
  if self.image_cache[path] ~= nil then
    return self.image_cache[path]
  end
  local ok, img = pcall(love.graphics.newImage, path)
  self.image_cache[path] = ok and img or false
  return self.image_cache[path]
end

function GameScene:update_viewport()
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local sx = w / self.base_width
  local sy = h / self.base_height
  self.viewport_scale = math.min(sx, sy)
  local draw_w = self.base_width * self.viewport_scale
  local draw_h = self.base_height * self.viewport_scale
  self.viewport_offset_x = math.floor((w - draw_w) * 0.5)
  self.viewport_offset_y = math.floor((h - draw_h) * 0.5)
end

function GameScene:to_virtual(x, y)
  local vx = (x - self.viewport_offset_x) / self.viewport_scale
  local vy = (y - self.viewport_offset_y) / self.viewport_scale
  return vx, vy
end

function GameScene:init_run_stats()
  self.run_result = nil
  self.run_stats = {
    started_at = os.time(),
    total_score = 0,
    total_plays = 0,
    total_discards = 0,
    blind_clears = 0,
    rounds = {},
    current_round = {
      ante = self.state.ante,
      blind = game.current_blind(self.state).label,
      target = game.current_target(self.state),
      score_gained = 0,
      plays = 0,
      discards = 0,
      outcome = "in_progress",
    },
  }
end

function GameScene:finalize_current_round(outcome)
  local round = self.run_stats and self.run_stats.current_round
  if not round then
    return
  end
  round.outcome = outcome
  self.run_stats.rounds[#self.run_stats.rounds + 1] = round
  self.run_stats.current_round = nil
end

function GameScene:start_next_round()
  if not self.run_stats then
    return
  end
  self.run_stats.current_round = {
    ante = self.state.ante,
    blind = game.current_blind(self.state).label,
    target = game.current_target(self.state),
    score_gained = 0,
    plays = 0,
    discards = 0,
    outcome = "in_progress",
  }
end

function GameScene:record_play(selected_count, result)
  if not self.run_stats then
    return
  end
  local round = self.run_stats.current_round
  if not round then
    self:start_next_round()
    round = self.run_stats.current_round
  end

  local gained = (result and result.projection and result.projection.total) or 0
  self.run_stats.total_score = self.run_stats.total_score + gained
  self.run_stats.total_plays = self.run_stats.total_plays + 1
  round.score_gained = round.score_gained + gained
  round.plays = round.plays + 1
  round.last_selected = selected_count

  if result and (result.event == "next_blind" or result.event == "next_ante" or result.event == "run_won") then
    self.run_stats.blind_clears = self.run_stats.blind_clears + 1
    self:finalize_current_round("cleared")
    if not self.state.game_over then
      self:start_next_round()
    end
  elseif result and result.event == "game_over" then
    self:finalize_current_round("busted")
  end
end

function GameScene:record_discard()
  if not self.run_stats then
    return
  end
  local round = self.run_stats.current_round
  if not round then
    self:start_next_round()
    round = self.run_stats.current_round
  end
  self.run_stats.total_discards = self.run_stats.total_discards + 1
  round.discards = round.discards + 1
end

function GameScene:build_run_result()
  local rounds = {}
  if self.run_stats then
    for i, round in ipairs(self.run_stats.rounds) do
      rounds[i] = {
        ante = round.ante,
        blind = round.blind,
        target = round.target,
        score_gained = round.score_gained,
        plays = round.plays,
        discards = round.discards,
        outcome = round.outcome,
      }
    end
  end

  self.run_result = {
    won = self.state.run_won == true,
    ante_reached = self.state.ante,
    blind_reached = game.current_blind(self.state).label,
    total_score = self.run_stats and self.run_stats.total_score or 0,
    total_plays = self.run_stats and self.run_stats.total_plays or 0,
    total_discards = self.run_stats and self.run_stats.total_discards or 0,
    blind_clears = self.run_stats and self.run_stats.blind_clears or 0,
    rounds = rounds,
  }
end

function GameScene:load()
  love.window.setMode(960, 790, {
    resizable = true,
    minwidth = 960,
    minheight = 640,
    vsync = 1,
  })
  love.window.setTitle("Open Balatro Lua Prototype")
  love.math.setRandomSeed(os.time())
  love.graphics.setDefaultFilter("nearest", "nearest")

  self.fonts.title = love.graphics.newFont(22)
  self.fonts.body = love.graphics.newFont(15)
  self.fonts.small = love.graphics.newFont(11)

  self.current_seed = self:generate_seed()
  self.state = game.new_state(game.make_seeded_rng(self.current_seed), { seed = self.current_seed })

  self.buttons = Layout.buttons()
  Layout.position_buttons(self.buttons, self.base_width, self.base_height)
  self:update_viewport()
  self:rebuild_visuals(false)
  self:init_run_stats()
end

function GameScene:update(dt)
  self:update_viewport()
  Layout.position_buttons(self.buttons, self.base_width, self.base_height)
  self.anim:update(dt)
  self:update_selection_lifts(dt)

  local i = 1
  while i <= #self.card_visuals do
    if self.card_visuals[i].to_remove then
      table.remove(self.card_visuals, i)
    else
      i = i + 1
    end
  end

  local mx, my = love.mouse.getPosition()
  mx, my = self:to_virtual(mx, my)
  self.mouse_x = mx
  self.mouse_y = my
  for _, button in ipairs(self.buttons) do
    button.hovered = (mx >= button.x and mx <= button.x + button.w and my >= button.y and my <= button.y + button.h and not self.anim.locked)
  end
end

function GameScene:draw()
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.push()
  love.graphics.translate(self.viewport_offset_x, self.viewport_offset_y)
  love.graphics.scale(self.viewport_scale, self.viewport_scale)
  Render.draw({
    game = game,
    state = self.state,
    theme = self.theme,
    palette = self:palette(),
    fonts = self.fonts,
    buttons = self.buttons,
    card_visuals = self.card_visuals,
    projection = self:get_projection(),
    run_result = self.run_result,
    current_seed = self.current_seed,
    seed_input_mode = self.seed_input_mode,
    seed_buffer = self.seed_buffer,
    mouse_x = self.mouse_x,
    mouse_y = self.mouse_y,
    get_image = function(path)
      return self:get_image(path)
    end,
  })
  love.graphics.pop()
end

CardVisuals.install(GameScene, game)
Actions.install(GameScene, game)
Input.install(GameScene, game)

return GameScene
