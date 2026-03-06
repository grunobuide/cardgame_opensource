local game = require("src.game_logic")
local EventBus = require("src.event_bus")
local SaveLoad = require("src.save_load")
local TweenQueue = require("anim.tween_queue")
local Palette = require("ui.palette")
local Typography = require("ui.typography")
local Render = require("ui.render")
local Layout = require("ui.layout")
local UiState = require("ui.ui_state")
local ScoreFx = require("ui.score_fx")
local ParticleEmitter = require("anim.particles")
local CardVisuals = require("scene.card_visuals")
local Actions = require("scene.actions")
local Input = require("scene.input")

local GameScene = {}
GameScene.__index = GameScene

local function trim(text)
  return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function approach(current, target, speed)
  if current < target then
    return math.min(target, current + speed)
  end
  if current > target then
    return math.max(target, current - speed)
  end
  return current
end

local function shallow_copy_table(source)
  if type(source) ~= "table" then
    return source
  end
  local out = {}
  for key, value in pairs(source) do
    out[key] = value
  end
  return out
end

local function clone_shop_snapshot(shop)
  if not shop then
    return nil
  end
  local snapshot = shallow_copy_table(shop)
  snapshot.offers = {}
  for i, offer in ipairs(shop.offers or {}) do
    if type(offer) == "table" then
      local cloned = shallow_copy_table(offer)
      if offer.card then
        cloned.card = shallow_copy_table(offer.card)
      end
      snapshot.offers[i] = cloned
    else
      snapshot.offers[i] = offer
    end
  end
  return snapshot
end

function GameScene.new()
  return setmetatable({
    state = nil,
    theme = "dark",
    typography = nil,
    fonts = {},
    buttons = {},
    card_slots = {},
    card_visuals = {},
    next_uid = 1,
    anim = TweenQueue.new(),
    image_cache = {},
    event_bus = nil,
    ui_state = nil,
    save_store = nil,
    run_stats = nil,
    run_result = nil,
    seed_input_mode = false,
    seed_buffer = "",
    current_seed = "",
    reduced_motion = false,
    ui_panel_intro = 0,
    overlay_alpha = {
      shop = 0,
      run_result = 0,
      seed_prompt = 0,
    },
    overlay_snapshots = {
      shop = nil,
      run_result = nil,
      seed_buffer = "",
    },
    score_fx = ScoreFx.new(),
    particles = ParticleEmitter.new(),
    joker_flash = {},
    phase_transition = nil,
    base_width = 1366,
    base_height = 768,
    viewport_scale = 1,
    viewport_offset_x = 0,
    viewport_offset_y = 0,
    mouse_x = 0,
    mouse_y = 0,
  }, GameScene)
end

function GameScene:save_run()
  if not self.save_store then
    return { ok = false, reason = "save_unavailable", message = "Save system is unavailable." }
  end

  local meta = {
    current_seed = self.current_seed,
    run_stats = self.run_stats,
    run_result = self.run_result,
    theme = self.theme,
    reduced_motion = self.reduced_motion,
  }
  return self.save_store:save(self.state, meta)
end

function GameScene:load_run()
  if not self.save_store then
    return { ok = false, reason = "save_unavailable", message = "Save system is unavailable." }
  end

  local result = self.save_store:load()
  if not result.ok then
    return result
  end

  self.state = result.state
  local meta = result.meta or {}
  self.current_seed = trim(meta.current_seed or self.state.seed or self.current_seed)
  if self.current_seed == "" then
    self.current_seed = self:generate_seed()
  end
  self.theme = meta.theme or self.theme
  self.run_stats = meta.run_stats or nil
  self.run_result = meta.run_result or nil
  self.reduced_motion = meta.reduced_motion == true
  if self.anim and self.anim.set_reduced_motion then
    self.anim:set_reduced_motion(self.reduced_motion)
  end
  self.score_fx:set_reduced_motion(self.reduced_motion)
  self.particles:set_reduced_motion(self.reduced_motion)

  if not self.run_stats and not self.state.game_over then
    self:init_run_stats()
  end
  if self.state.game_over and not self.run_result then
    self:build_run_result()
  end

  self.seed_input_mode = false
  self.seed_buffer = ""
  self.ui_panel_intro = 0
  self:rebuild_visuals("snap")

  return result
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
    self.ui_panel_intro = 0
    self:rebuild_visuals("deal")
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
    joker_contributions = {},
    best_play = nil,
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

  local projection = result and result.projection
  local gained = (projection and projection.total) or 0
  self.run_stats.total_score = self.run_stats.total_score + gained
  self.run_stats.total_plays = self.run_stats.total_plays + 1
  round.score_gained = round.score_gained + gained
  round.plays = round.plays + 1
  round.last_selected = selected_count

  if projection then
    for _, detail in ipairs(projection.joker_details or {}) do
      local key = detail.joker_key
      local mult = (detail.effect and detail.effect.mult) or 0
      local chips = (detail.effect and detail.effect.chips) or 0
      self.run_stats.joker_contributions[key] = (self.run_stats.joker_contributions[key] or 0) + mult + chips
    end
    local best = self.run_stats.best_play
    if not best or gained > best.score then
      self.run_stats.best_play = {
        score = gained,
        hand_type = projection.hand_type and projection.hand_type.label or "Unknown",
      }
    end
  end

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

  -- Find MVP joker (highest total contribution)
  local mvp_joker_key, mvp_joker_score = nil, 0
  if self.run_stats and self.run_stats.joker_contributions then
    for key, total in pairs(self.run_stats.joker_contributions) do
      if total > mvp_joker_score then
        mvp_joker_key = key
        mvp_joker_score = total
      end
    end
  end
  local mvp_joker_name = nil
  if mvp_joker_key then
    local joker_def = game.JOKERS[mvp_joker_key]
    mvp_joker_name = joker_def and joker_def.name or mvp_joker_key
  end

  local best_play = self.run_stats and self.run_stats.best_play or nil

  self.run_result = {
    won = self.state.run_won == true,
    ante_reached = self.state.ante,
    blind_reached = game.current_blind(self.state).label,
    total_score = self.run_stats and self.run_stats.total_score or 0,
    total_plays = self.run_stats and self.run_stats.total_plays or 0,
    total_discards = self.run_stats and self.run_stats.total_discards or 0,
    blind_clears = self.run_stats and self.run_stats.blind_clears or 0,
    seed = self.current_seed or "",
    mvp_joker = mvp_joker_name,
    mvp_joker_score = mvp_joker_score,
    best_play = best_play,
    rounds = rounds,
  }
end

function GameScene:load()
  love.window.setMode(1366, 768, {
    resizable = true,
    minwidth = 1280,
    minheight = 720,
    vsync = 1,
  })
  love.window.setTitle("Open Balatro Lua Prototype")
  love.math.setRandomSeed(os.time())
  love.graphics.setDefaultFilter("nearest", "nearest")

  self.typography = Typography.load()
  self.fonts = self.typography.fonts

  self.current_seed = self:generate_seed()
  self.state = game.new_state(game.make_seeded_rng(self.current_seed), { seed = self.current_seed })
  self.event_bus = EventBus.new()
  self.ui_state = UiState.new(self.event_bus)
  self.save_store = SaveLoad.new({ game = game })
  self.anim:set_reduced_motion(self.reduced_motion)
  self.score_fx:set_reduced_motion(self.reduced_motion)
  self.particles:set_reduced_motion(self.reduced_motion)

  self.buttons = Layout.buttons()
  Layout.position_buttons(self.buttons, self.base_width, self.base_height)
  self:update_viewport()
  self.ui_panel_intro = 0
  self:rebuild_visuals("snap")
  self:init_run_stats()
  if self.state.message and self.state.message ~= "" then
    self:publish_message(self.state.message, "info", "bootstrap")
  end
end

function GameScene:update(dt)
  local step_dt = math.max(0, math.min(dt or 0, 1 / 24))
  self:update_viewport()
  Layout.position_buttons(self.buttons, self.base_width, self.base_height)
  self.anim:update(step_dt)
  self.score_fx:update(step_dt)
  self.particles:update(step_dt)
  self:update_selection_lifts(step_dt)

  -- Tick joker flash timers
  for slot, timer in pairs(self.joker_flash) do
    self.joker_flash[slot] = timer - step_dt
    if self.joker_flash[slot] <= 0 then
      self.joker_flash[slot] = nil
    end
  end

  -- Tick phase transition
  if self.phase_transition then
    self.phase_transition.elapsed = self.phase_transition.elapsed + step_dt
    if self.phase_transition.elapsed >= self.phase_transition.duration then
      self.phase_transition = nil
    end
  end

  -- Keep display score in sync
  self.score_fx:set_target_score(self.state.score or 0)
  if self.reduced_motion then
    self.ui_panel_intro = 1
    self.overlay_alpha.shop = (self.state.shop and self.state.shop.active) and 1 or 0
    self.overlay_alpha.run_result = self.run_result and 1 or 0
    self.overlay_alpha.seed_prompt = self.seed_input_mode and 1 or 0
  else
    self.ui_panel_intro = approach(self.ui_panel_intro, 1, step_dt * 3.4)
    self.overlay_alpha.shop = approach(self.overlay_alpha.shop, (self.state.shop and self.state.shop.active) and 1 or 0, step_dt * 7.2)
    self.overlay_alpha.run_result = approach(self.overlay_alpha.run_result, self.run_result and 1 or 0, step_dt * 6.4)
    self.overlay_alpha.seed_prompt = approach(self.overlay_alpha.seed_prompt, self.seed_input_mode and 1 or 0, step_dt * 8.0)
  end

  if self.state.shop and self.state.shop.active then
    self.overlay_snapshots.shop = clone_shop_snapshot(self.state.shop)
  elseif self.overlay_alpha.shop <= 0.001 then
    self.overlay_snapshots.shop = nil
  end

  if self.run_result then
    self.overlay_snapshots.run_result = shallow_copy_table(self.run_result)
  elseif self.overlay_alpha.run_result <= 0.001 then
    self.overlay_snapshots.run_result = nil
  end

  if self.seed_input_mode then
    self.overlay_snapshots.seed_buffer = self.seed_buffer
  elseif self.overlay_alpha.seed_prompt <= 0.001 then
    self.overlay_snapshots.seed_buffer = ""
  end

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
    typography = self.typography,
    fonts = self.fonts,
    buttons = self.buttons,
    card_visuals = self.card_visuals,
    projection = self:get_projection(),
    ui_state = self.ui_state,
    run_result = self.run_result,
    current_seed = self.current_seed,
    seed_input_mode = self.seed_input_mode,
    seed_buffer = self.seed_buffer,
    reduced_motion = self.reduced_motion,
    ui_panel_intro = self.ui_panel_intro,
    overlay_alpha = self.overlay_alpha,
    overlay_snapshots = self.overlay_snapshots,
    anim_stats = self.anim.stats,
    mouse_x = self.mouse_x,
    mouse_y = self.mouse_y,
    score_fx = self.score_fx,
    particles = self.particles,
    joker_flash = self.joker_flash,
    phase_transition = self.phase_transition,
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
