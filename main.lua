local game = require("src.game_logic")

local state
local theme = "dark"

local fonts = {}
local ui = {
  buttons = {},
  hand_rects = {},
}

local image_cache = {}

local palette = {
  dark = {
    bg = { 0.05, 0.08, 0.12, 1.0 },
    panel = { 0.11, 0.15, 0.21, 0.95 },
    panel_alt = { 0.16, 0.21, 0.30, 0.95 },
    border = { 0.44, 0.55, 0.72, 0.5 },
    text = { 0.92, 0.95, 0.99, 1.0 },
    muted = { 0.67, 0.74, 0.86, 1.0 },
    accent = { 0.21, 0.82, 0.74, 1.0 },
    warn = { 0.97, 0.80, 0.41, 1.0 },
    select = { 0.96, 0.75, 0.24, 1.0 },
  },
  light = {
    bg = { 0.88, 0.92, 0.97, 1.0 },
    panel = { 0.96, 0.97, 0.99, 0.95 },
    panel_alt = { 0.90, 0.93, 0.98, 0.95 },
    border = { 0.37, 0.48, 0.66, 0.4 },
    text = { 0.12, 0.18, 0.27, 1.0 },
    muted = { 0.28, 0.39, 0.56, 1.0 },
    accent = { 0.09, 0.57, 0.57, 1.0 },
    warn = { 0.70, 0.44, 0.07, 1.0 },
    select = { 0.82, 0.57, 0.13, 1.0 },
  },
}

local function p()
  return palette[theme] or palette.dark
end

local function set_message_if_present(result)
  if result and result.message then
    state.message = result.message
  end
end

local function get_image(path)
  if image_cache[path] ~= nil then
    return image_cache[path]
  end

  local ok, img = pcall(love.graphics.newImage, path)
  if ok then
    image_cache[path] = img
  else
    image_cache[path] = false
  end
  return image_cache[path]
end

local function is_selected(index)
  return state.selected[index] == true
end

local function draw_panel(x, y, w, h)
  love.graphics.setColor(p().panel)
  love.graphics.rectangle("fill", x, y, w, h, 10, 10)
  love.graphics.setColor(p().border)
  love.graphics.rectangle("line", x, y, w, h, 10, 10)
end

local function draw_button(btn)
  local hovered = btn.hovered
  if hovered then
    love.graphics.setColor(p().accent)
  else
    love.graphics.setColor(p().panel_alt)
  end
  love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 8, 8)
  love.graphics.setColor(p().border)
  love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 8, 8)

  love.graphics.setColor(hovered and { 0.05, 0.1, 0.1, 1.0 } or p().text)
  love.graphics.setFont(fonts.body)
  love.graphics.printf(btn.label, btn.x, btn.y + 10, btn.w, "center")
end

local function layout_buttons()
  local y = 180
  local x = 30
  local w = 150
  local h = 42
  local gap = 12

  ui.buttons = {
    { id = "play", label = "Play Selected", x = x + 0 * (w + gap), y = y, w = w, h = h },
    { id = "discard", label = "Discard Selected", x = x + 1 * (w + gap), y = y, w = w, h = h },
    { id = "new_run", label = "New Run", x = x + 2 * (w + gap), y = y, w = w, h = h },
    { id = "add_joker", label = "Add Joker", x = x + 3 * (w + gap), y = y, w = w, h = h },
    { id = "royal", label = "Set Royal", x = x + 4 * (w + gap), y = y, w = w, h = h },
  }
end

local function handle_button_click(id)
  if id == "play" then
    set_message_if_present(game.play_selected(state))
    return
  end
  if id == "discard" then
    set_message_if_present(game.discard_selected(state))
    return
  end
  if id == "new_run" then
    game.new_run(state)
    return
  end
  if id == "add_joker" then
    set_message_if_present(game.add_joker(state))
    return
  end
  if id == "royal" then
    game.set_hand_to_royal_flush(state)
    return
  end
end

local function draw_stats()
  draw_panel(20, 20, 920, 140)

  love.graphics.setColor(p().text)
  love.graphics.setFont(fonts.title)
  love.graphics.print("Open Balatro (Lua + LOVE)", 34, 30)

  love.graphics.setFont(fonts.body)
  love.graphics.setColor(p().muted)
  love.graphics.print(("Ante: %d"):format(state.ante), 36, 72)
  love.graphics.print(("Target: %d"):format(game.target_score(state.ante)), 170, 72)
  love.graphics.print(("Score: %d"):format(state.score), 320, 72)
  love.graphics.print(("Hands: %d"):format(state.hands), 450, 72)
  love.graphics.print(("Discards: %d"):format(state.discards), 560, 72)

  local chosen = game.selected_cards(state)
  local selected_count = #chosen
  local projection = selected_count > 0 and game.calculate_projection(state, chosen) or nil
  local preview = projection and ("%s  +%d"):format(projection.hand_type.label, projection.total) or "No cards selected"

  love.graphics.setColor(p().warn)
  love.graphics.print(("Preview: %s"):format(preview), 36, 104)
end

local function draw_message()
  draw_panel(20, 235, 920, 52)
  love.graphics.setColor(p().warn)
  love.graphics.setFont(fonts.body)
  love.graphics.print(state.message or "", 32, 252)
end

local function draw_hand()
  local x = 30
  local y = 320
  local card_w = 96
  local card_h = 134
  local overlap = 42

  ui.hand_rects = {}

  draw_panel(20, 300, 920, 210)
  love.graphics.setColor(p().muted)
  love.graphics.setFont(fonts.body)
  love.graphics.print("Hand", 30, 310)

  for i, card in ipairs(state.hand) do
    local card_x = x + (i - 1) * overlap
    local card_y = y
    if is_selected(i) then
      card_y = card_y - 18
    end

    ui.hand_rects[i] = { x = card_x, y = card_y, w = card_w, h = card_h }

    local sprite = game.card_sprite_path(card, theme)
    local img = get_image(sprite)

    if img then
      love.graphics.setColor(1, 1, 1, 1)
      local sx = card_w / img:getWidth()
      local sy = card_h / img:getHeight()
      love.graphics.draw(img, card_x, card_y, 0, sx, sy)
    else
      love.graphics.setColor(0.96, 0.96, 0.98, 1.0)
      love.graphics.rectangle("fill", card_x, card_y, card_w, card_h, 8, 8)
      love.graphics.setColor(0.15, 0.2, 0.3, 1.0)
      love.graphics.rectangle("line", card_x, card_y, card_w, card_h, 8, 8)
      love.graphics.setFont(fonts.body)
      love.graphics.printf(tostring(card.rank) .. card.suit, card_x, card_y + 52, card_w, "center")
    end

    if is_selected(i) then
      love.graphics.setColor(p().select)
      love.graphics.setLineWidth(3)
      love.graphics.rectangle("line", card_x - 1, card_y - 1, card_w + 2, card_h + 2, 8, 8)
      love.graphics.setLineWidth(1)
    end
  end
end

local function draw_jokers()
  draw_panel(20, 530, 920, 170)
  love.graphics.setColor(p().muted)
  love.graphics.setFont(fonts.body)
  love.graphics.print("Jokers", 30, 540)

  local start_x = 30
  local y = 570
  local w = 170
  local h = 112
  local gap = 12

  for i, joker_key in ipairs(state.jokers) do
    local joker = game.JOKERS[joker_key]
    if joker then
      local x = start_x + (i - 1) * (w + gap)
      love.graphics.setColor(p().panel_alt)
      love.graphics.rectangle("fill", x, y, w, h, 8, 8)
      love.graphics.setColor(p().border)
      love.graphics.rectangle("line", x, y, w, h, 8, 8)

      love.graphics.setColor(p().text)
      love.graphics.print(joker.name, x + 10, y + 10)
      love.graphics.setColor(p().muted)
      love.graphics.printf(joker.formula, x + 10, y + 36, w - 20, "left")
    end
  end
end

function love.load()
  love.window.setMode(960, 730, { resizable = false, vsync = 1 })
  love.window.setTitle("Open Balatro Lua Prototype")
  love.math.setRandomSeed(os.time())

  fonts.title = love.graphics.newFont(28)
  fonts.body = love.graphics.newFont(18)
  fonts.small = love.graphics.newFont(14)

  state = game.new_state(function(min, max)
    return love.math.random(min, max)
  end)

  layout_buttons()
end

function love.update()
  local mx, my = love.mouse.getPosition()
  for _, btn in ipairs(ui.buttons) do
    btn.hovered = mx >= btn.x and mx <= btn.x + btn.w and my >= btn.y and my <= btn.y + btn.h
  end
end

function love.mousepressed(x, y, button)
  if button ~= 1 then
    return
  end

  for i = #ui.hand_rects, 1, -1 do
    local r = ui.hand_rects[i]
    if x >= r.x and x <= r.x + r.w and y >= r.y and y <= r.y + r.h then
      local ok, msg = game.toggle_selection(state, i)
      if not ok and msg then
        state.message = msg
      end
      return
    end
  end

  for _, btn in ipairs(ui.buttons) do
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
      handle_button_click(btn.id)
      return
    end
  end
end

function love.keypressed(key)
  if key == "t" then
    theme = (theme == "dark") and "light" or "dark"
    return
  end

  if key == "space" then
    handle_button_click("play")
    return
  end

  if key == "d" then
    handle_button_click("discard")
    return
  end

  if key == "r" then
    handle_button_click("new_run")
    return
  end

  local n = tonumber(key)
  if n and n >= 1 and n <= #state.hand then
    local ok, msg = game.toggle_selection(state, n)
    if not ok and msg then
      state.message = msg
    end
  end
end

function love.draw()
  love.graphics.clear(p().bg)

  draw_stats()

  for _, btn in ipairs(ui.buttons) do
    draw_button(btn)
  end

  draw_message()
  draw_hand()
  draw_jokers()

  love.graphics.setColor(p().muted)
  love.graphics.setFont(fonts.small)
  love.graphics.print("Controls: mouse click cards/buttons | 1..8 select cards | Space play | D discard | R new run | T toggle theme", 20, 708)
end
