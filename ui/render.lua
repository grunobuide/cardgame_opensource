local Layout = require("ui.layout")
local PixelKit = require("ui.pixel_kit")

local Render = {}
local icon_quads_cache = {}

local function clipped_text(font, text, max_width)
  local value = tostring(text or "")
  if max_width <= 0 or font:getWidth(value) <= max_width then
    return value
  end
  local clipped = value
  while #clipped > 0 and font:getWidth(clipped .. "...") > max_width do
    clipped = clipped:sub(1, -2)
  end
  if clipped == "" then
    return ""
  end
  return clipped .. "..."
end

local function draw_image_contain(image, x, y, w, h, alpha, quad, source_w, source_h)
  local iw = source_w or image:getWidth()
  local ih = source_h or image:getHeight()
  if iw <= 0 or ih <= 0 then
    return
  end
  local scale = math.min(w / iw, h / ih)
  if scale <= 0 then
    return
  end
  local draw_w = iw * scale
  local draw_h = ih * scale
  local draw_x = x + ((w - draw_w) * 0.5)
  local draw_y = y + ((h - draw_h) * 0.5)
  love.graphics.setColor(1, 1, 1, alpha or 1)
  if quad then
    love.graphics.draw(image, quad, draw_x, draw_y, 0, draw_w / iw, draw_h / ih)
  else
    love.graphics.draw(image, draw_x, draw_y, 0, draw_w / image:getWidth(), draw_h / image:getHeight())
  end
end

local function get_icon_quad(image, index, cols, rows)
  local key = ("%dx%d:%d:%d"):format(image:getWidth(), image:getHeight(), cols, rows)
  if not icon_quads_cache[key] then
    local frame_w = math.floor(image:getWidth() / cols)
    local frame_h = math.floor(image:getHeight() / rows)
    local cache = { frame_w = frame_w, frame_h = frame_h, total = cols * rows }
    for i = 1, cache.total do
      local ix = (i - 1) % cols
      local iy = math.floor((i - 1) / cols)
      cache[i] = love.graphics.newQuad(ix * frame_w, iy * frame_h, frame_w, frame_h, image:getWidth(), image:getHeight())
    end
    icon_quads_cache[key] = cache
  end
  local meta = icon_quads_cache[key]
  local safe_index = ((index - 1) % meta.total) + 1
  return meta[safe_index], meta
end

local function get_joker_icon_sheet(ctx)
  local candidates = {
    "assets/cards/jkrs_nobg.png",
    "assets/ui/jokers_icons.png",
    "assets/ui/joker_icons.png",
    "assets/ui/icon sheet.png",
  }
  for _, path in ipairs(candidates) do
    local image = ctx.get_image(path)
    if image then
      return image
    end
  end
  return nil
end

local function resolve_message(ctx)
  local ui_message = ctx.ui_state and ctx.ui_state.message or nil
  if ui_message and ui_message ~= "" then
    return ui_message
  end
  return ctx.state.message or ""
end

local function draw_background(ctx)
  local palette = ctx.palette
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  love.graphics.setColor(palette.bg_bottom or palette.bg)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local top_h = math.floor(h * 0.48)
  love.graphics.setColor(palette.bg_top or palette.panel_alt)
  love.graphics.rectangle("fill", 0, 0, w, top_h)

  local stripes = 20
  local stripe_h = math.max(4, math.floor(top_h / stripes))
  for i = 1, stripes do
    if i % 2 == 0 then
      love.graphics.setColor(palette.grid[1], palette.grid[2], palette.grid[3], 0.05)
      love.graphics.rectangle("fill", 0, (i - 1) * stripe_h, w, stripe_h)
    end
  end

  love.graphics.setColor(palette.grid[1], palette.grid[2], palette.grid[3], 0.08)
  for y = math.floor(h * 0.62), h, 24 do
    love.graphics.rectangle("fill", 0, y, w, 2)
  end
end

local function draw_header(ctx, layout)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local state = ctx.state
  local game = ctx.game
  local header = layout.top

  PixelKit.draw_panel(header.x, header.y, header.w, header.h, {
    fill = palette.panel,
    border = palette.border,
    border_width = 2,
    shadow = 4,
  })

  local logo = ctx.get_image("assets/game_logo.png")
  local left = header.x + 16
  if logo then
    draw_image_contain(logo, header.x + 8, header.y + 8, 84, header.h - 16, 1.0)
    left = header.x + 100
  end

  love.graphics.setColor(palette.text)
  love.graphics.setFont(fonts.title)
  love.graphics.print("ALIEN VAPOR TABLE", left, header.y + 10)

  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  local stats_line = ("TARGET %d   SCORE %d   HANDS %d   DISCARDS %d   CREDITS $%d"):format(
    game.current_target(state),
    state.score,
    state.hands,
    state.discards,
    state.money or 0
  )
  love.graphics.print(stats_line, left, header.y + 48)

  love.graphics.setColor(palette.accent)
  love.graphics.setFont(fonts.ui)
  love.graphics.printf(
    game.current_blind(state).label,
    header.x + 12,
    header.y + 42,
    header.w - 24,
    "right"
  )
end

local function draw_feedback(ctx, layout)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local game = ctx.game
  local state = ctx.state
  local area = layout.feedback
  local projection = ctx.projection

  PixelKit.draw_panel(area.x, area.y, area.w, area.h, {
    fill = palette.panel_alt,
    border = palette.border,
    border_width = 2,
    shadow = 4,
    title = "FEEDBACK",
    fonts = fonts,
    title_font = fonts.small,
  })

  local pad = 16
  local bar_x = area.x + pad
  local bar_y = area.y + 30
  local bar_w = math.floor(area.w * 0.54)
  local bar_h = area.h - 40

  PixelKit.draw_progress_segmented(bar_x, bar_y, bar_w, bar_h, state.score, game.current_target(state), {
    segments = 20,
    gap = 2,
    fill = palette.ok,
    empty = { 0.14, 0.10, 0.26, 1.0 },
    border = palette.border,
    shadow = 0,
  })

  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.print("BLIND PRESSURE", bar_x + 10, bar_y + 8)
  love.graphics.printf(
    ("%d / %d"):format(state.score, game.current_target(state)),
    bar_x,
    bar_y + 8,
    bar_w - 10,
    "right"
  )

  local info_x = bar_x + bar_w + 24
  local base_label = projection and projection.hand_type and projection.hand_type.label or "No Hand Selected"
  local projected_total = projection and projection.total or 0

  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.print("BASE HAND", info_x, area.y + 14)
  love.graphics.setColor(palette.text)
  love.graphics.setFont(fonts.ui)
  love.graphics.print(base_label, info_x, area.y + 30)

  local proj_text = projected_total > 0 and ("PROJECTED +%d"):format(projected_total) or "PROJECTED +0"
  love.graphics.setColor(palette.accent)
  love.graphics.setFont(fonts.ui)
  love.graphics.printf(proj_text, info_x, area.y + 30, area.x + area.w - info_x - 16, "right")
end

local function draw_hand(ctx, area)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local state = ctx.state
  local mx = ctx.mouse_x or -9999
  local my = ctx.mouse_y or -9999

  PixelKit.draw_panel(area.x, area.y, area.w, area.h, {
    fill = palette.panel,
    border = palette.border,
    border_width = 2,
    shadow = 4,
    title = "HAND",
    fonts = fonts,
    title_font = fonts.small,
  })

  for _, visual in ipairs(ctx.card_visuals) do
    local draw_x = visual.x
    local draw_y = visual.y + visual.lift
    local card = visual.card
    local sprite = ctx.game.card_sprite_path(card, ctx.theme)
    local image = ctx.get_image(sprite)
    local selected = state.selected[visual.index] == true
    local hovered = (mx >= draw_x and mx <= draw_x + visual.w and my >= draw_y and my <= draw_y + visual.h)
    local border = palette.border

    if selected then
      border = palette.accent
    elseif hovered then
      border = palette.accent_alt
    end

    PixelKit.draw_panel(draw_x - 2, draw_y - 2, visual.w + 4, visual.h + 4, {
      fill = { 0.02, 0.02, 0.05, 1.0 },
      border = border,
      border_width = 2,
      shadow = selected and 4 or 2,
      shadow_color = palette.shadow,
    })

    love.graphics.setColor(1, 1, 1, visual.alpha)
    if image then
      local sx = visual.w / image:getWidth()
      local sy = visual.h / image:getHeight()
      love.graphics.draw(image, draw_x, draw_y, visual.rotation, sx * visual.scale, sy * visual.scale)
    else
      love.graphics.setColor(0.96, 0.96, 1.0, visual.alpha)
      love.graphics.rectangle("fill", draw_x, draw_y, visual.w, visual.h)
      love.graphics.setColor(0.1, 0.1, 0.18, visual.alpha)
      love.graphics.printf(ctx.game.card_label(card), draw_x, draw_y + (visual.h * 0.5) - 10, visual.w, "center")
    end

    if selected then
      PixelKit.outline(draw_x - 1, draw_y - 1, visual.w + 2, visual.h + 2, { palette.accent[1], palette.accent[2], palette.accent[3], 0.90 }, 1)
    end
  end
end

local function button_state_for(ctx, button, selected_count)
  local in_shop = ctx.state.shop and ctx.state.shop.active
  if in_shop then
    return "disabled"
  end
  if button.id == "play" and (ctx.state.hands <= 0 or selected_count == 0) then
    return "disabled"
  end
  if button.id == "discard" and (ctx.state.discards <= 0 or selected_count == 0) then
    return "disabled"
  end
  if button.hovered then
    return "hover"
  end
  return "normal"
end

local function draw_actions(ctx, area)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local selected_count = ctx.game.selected_count(ctx.state)
  local message = resolve_message(ctx)
  if message == "" then
    message = "Select up to 5 cards, then PLAY."
  end

  PixelKit.draw_panel(area.x, area.y, area.w, area.h, {
    fill = palette.panel_alt,
    border = palette.border,
    border_width = 2,
    shadow = 4,
    title = "ACTIONS",
    fonts = fonts,
    title_font = fonts.small,
  })

  for _, button in ipairs(ctx.buttons) do
    if button.group == "center_actions" then
      local visual_state = button_state_for(ctx, button, selected_count)
      PixelKit.draw_button(button.x, button.y, button.w, button.h, visual_state, button.label, {
        fonts = fonts,
        palette = palette,
        key_hint = button.key_hint,
        neon_color = button.id == "play" and palette.accent or palette.accent_alt,
        states = button.tier == "primary" and {
          normal = { fill = { 0.78, 0.22, 0.68, 1.0 }, border = palette.accent, text = { 0.09, 0.03, 0.14, 1.0 } },
          hover = { fill = palette.accent, border = palette.accent, text = { 0.09, 0.03, 0.14, 1.0 } },
          active = { fill = palette.accent, border = palette.accent, text = { 0.09, 0.03, 0.14, 1.0 } },
          disabled = { fill = { 0.22, 0.18, 0.28, 1.0 }, border = { 0.38, 0.35, 0.46, 1.0 }, text = { 0.68, 0.68, 0.74, 1.0 } },
        } or nil,
      })
    end
  end

  for _, button in ipairs(ctx.buttons) do
    if button.group == "tools" then
      local visual_state = button_state_for(ctx, button, selected_count)
      PixelKit.draw_button(button.x, button.y, button.w, button.h, visual_state, button.label, {
        fonts = fonts,
        palette = palette,
        key_hint = button.key_hint,
        neon_color = palette.accent_alt,
      })
    end
  end

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(palette.muted)
  love.graphics.printf(clipped_text(fonts.small, message, area.w - 40), area.x + 20, area.y + area.h - 18, area.w - 40, "center")
end

local function draw_joker_dock(ctx, area)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local icon_sheet = get_joker_icon_sheet(ctx)
  local pad = 16
  local slots = ctx.game.MAX_JOKERS or 5
  local gap = 8
  local slot_w = math.floor((area.w - (pad * 2) - ((slots - 1) * gap)) / slots)
  local slot_h = 92
  local start_x = area.x + pad
  local start_y = area.y + 32
  local mx = ctx.mouse_x or -9999
  local my = ctx.mouse_y or -9999
  local focus_text = "No jokers yet."

  PixelKit.draw_panel(area.x, area.y, area.w, area.h, {
    fill = ctx.palette.panel,
    border = palette.border,
    border_width = 2,
    shadow = 4,
    title = "JOKER DOCK",
    fonts = fonts,
    title_font = fonts.small,
  })

  for i = 1, slots do
    local x = start_x + ((i - 1) * (slot_w + gap))
    local y = start_y
    local joker_key = ctx.state.jokers[i]
    local joker = joker_key and ctx.game.JOKERS[joker_key] or nil
    local hovered = (mx >= x and mx <= x + slot_w and my >= y and my <= y + slot_h)
    local border = joker and (hovered and palette.accent or palette.border) or { palette.border[1], palette.border[2], palette.border[3], 0.45 }

    PixelKit.draw_panel(x, y, slot_w, slot_h, {
      fill = { 0.06, 0.05, 0.14, 1.0 },
      border = border,
      border_width = 2,
      shadow = 2,
      shadow_color = palette.shadow,
    })

    if joker then
      local icon_size = math.min(slot_w - 14, slot_h - 34)
      if icon_sheet then
        local index = joker.sprite_index or i
        local quad, meta = get_icon_quad(icon_sheet, index, 4, 3)
        draw_image_contain(icon_sheet, x + 7, y + 7, icon_size, icon_size, 1.0, quad, meta.frame_w, meta.frame_h)
      else
        love.graphics.setColor(palette.border[1], palette.border[2], palette.border[3], 0.25)
        love.graphics.rectangle("fill", x + 8, y + 8, icon_size, icon_size)
      end

      local label = clipped_text(fonts.small, joker.name or joker_key, slot_w - 8)
      love.graphics.setColor(palette.text)
      love.graphics.setFont(fonts.small)
      love.graphics.printf(label, x + 4, y + slot_h - 22, slot_w - 8, "center")
      if hovered then
        focus_text = ("%s  |  %s"):format(joker.name or joker_key, joker.formula or "")
      end
    else
      love.graphics.setColor(palette.muted)
      love.graphics.setFont(fonts.small)
      love.graphics.printf("--", x, y + 38, slot_w, "center")
    end
  end

  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.printf(clipped_text(fonts.small, focus_text, area.w - 20), area.x + 10, area.y + area.h - 26, area.w - 20, "left")
end

local function draw_seed_prompt(ctx)
  if not ctx.seed_input_mode then
    return
  end
  local palette = ctx.palette
  local fonts = ctx.fonts
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local panel_w, panel_h = 760, 96
  local x = math.floor((w - panel_w) * 0.5)
  local y = math.floor((h - panel_h) * 0.5)

  PixelKit.draw_panel(x, y, panel_w, panel_h, {
    fill = palette.panel_alt,
    border = palette.accent,
    border_width = 2,
    shadow = 4,
    title = "SEED ENTRY",
    fonts = fonts,
    title_font = fonts.small,
  })
  love.graphics.setColor(palette.text)
  love.graphics.setFont(fonts.small)
  love.graphics.printf("Type seed and press Enter. Esc cancels.", x + 16, y + 36, panel_w - 32, "left")
  love.graphics.setColor(palette.accent)
  love.graphics.printf(ctx.seed_buffer .. "_", x + 16, y + 58, panel_w - 32, "left")
end

local function draw_run_result(ctx)
  local result = ctx.run_result
  if not result then
    return
  end

  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  love.graphics.setColor(0, 0, 0, 0.72)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local panel_w = math.min(1040, w - 160)
  local panel_h = math.min(620, h - 120)
  local x = math.floor((w - panel_w) * 0.5)
  local y = math.floor((h - panel_h) * 0.5)

  PixelKit.draw_panel(x, y, panel_w, panel_h, {
    fill = ctx.palette.panel,
    border = ctx.palette.accent,
    border_width = 2,
    shadow = 4,
  })

  love.graphics.setFont(ctx.fonts.title)
  love.graphics.setColor(result.won and ctx.palette.ok or ctx.palette.accent)
  love.graphics.printf(result.won and "RUN COMPLETE" or "RUN OVER", x, y + 18, panel_w, "center")

  love.graphics.setFont(ctx.fonts.ui)
  love.graphics.setColor(ctx.palette.text)
  love.graphics.print(("Ante reached: %d"):format(result.ante_reached), x + 24, y + 90)
  love.graphics.print(("Final blind: %s"):format(result.blind_reached), x + 24, y + 124)
  love.graphics.print(("Total score: %d"):format(result.total_score), x + 24, y + 158)
  love.graphics.setFont(ctx.fonts.small)
  love.graphics.print(("Plays: %d  Discards: %d  Clears: %d"):format(result.total_plays, result.total_discards, result.blind_clears), x + 24, y + 196)

  love.graphics.setColor(ctx.palette.muted)
  love.graphics.setFont(ctx.fonts.small)
  love.graphics.print("Per-round stats", x + 24, y + 236)

  local row_y = y + 262
  local max_rows = 10
  local start_i = math.max(1, #result.rounds - max_rows + 1)
  for i = start_i, #result.rounds do
    local round = result.rounds[i]
    local line = ("A%d %s | target %d | +%d | plays %d | discards %d | %s"):format(
      round.ante,
      round.blind,
      round.target,
      round.score_gained,
      round.plays,
      round.discards,
      round.outcome
    )
    love.graphics.setColor(ctx.palette.text)
    love.graphics.printf(line, x + 24, row_y, panel_w - 48, "left")
    row_y = row_y + 24
  end

  love.graphics.setColor(ctx.palette.accent)
  love.graphics.setFont(ctx.fonts.ui)
  love.graphics.printf("Press Enter/Space or click to start a new run", x, y + panel_h - 44, panel_w, "center")
end

local function draw_debug_overlay(ctx)
  if not (ctx.ui_state and ctx.ui_state.debug_overlay) then
    return
  end

  local palette = ctx.palette
  local fonts = ctx.fonts
  local w = 436
  local h = 208
  local x = love.graphics.getWidth() - w - 24
  local y = 24

  PixelKit.draw_panel(x, y, w, h, {
    fill = palette.panel_alt,
    border = palette.border,
    border_width = 2,
    shadow = 4,
    title = "DEBUG (F1)",
    fonts = fonts,
    title_font = fonts.small,
  })

  local lines = {
    ("Seed: %s"):format(tostring(ctx.current_seed or "n/a")),
    ("Viewport: %dx%d"):format(love.graphics.getWidth(), love.graphics.getHeight()),
    ("Selected: %d / %d"):format(ctx.game.selected_count(ctx.state), ctx.game.MAX_SELECT or 5),
    ("Deck: %d  Hand: %d  Jokers: %d"):format(#(ctx.state.deck_cards or {}), #(ctx.state.hand or {}), #(ctx.state.jokers or {})),
    "Controls: SPACE play | D discard | R new run | F2 theme",
    "Save/Load: F5/F9  Seed input: K  Random seed: G",
  }

  love.graphics.setColor(palette.text)
  love.graphics.setFont(fonts.small)
  local row_y = y + 34
  for _, line in ipairs(lines) do
    love.graphics.print(line, x + 12, row_y)
    row_y = row_y + 22
  end
end

local function draw_shop_modal(ctx)
  local shop = ctx.state.shop
  if not (shop and shop.active) then
    return
  end

  local palette = ctx.palette
  local fonts = ctx.fonts
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  love.graphics.setColor(0, 0, 0, 0.74)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local panel_w = math.min(1040, w - 160)
  local panel_h = math.min(560, h - 120)
  local x = math.floor((w - panel_w) * 0.5)
  local y = math.floor((h - panel_h) * 0.5)
  PixelKit.draw_panel(x, y, panel_w, panel_h, {
    fill = palette.panel,
    border = palette.accent_alt,
    border_width = 2,
    shadow = 4,
  })

  love.graphics.setColor(palette.accent)
  love.graphics.setFont(fonts.title)
  love.graphics.printf("SHOP", x, y + 18, panel_w, "center")

  love.graphics.setColor(palette.text)
  love.graphics.setFont(fonts.ui)
  love.graphics.print(("Credits: $%d"):format(ctx.state.money or 0), x + 24, y + 74)
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.print(("Reroll cost: $%d"):format(shop.reroll_cost or 0), x + 24, y + 104)

  local row_y = y + 138
  local row_h = 108
  for i = 1, 3 do
    local offer = shop.offers and shop.offers[i] or nil
    local row_x = x + 24
    local row_w = panel_w - 48
    local border = offer and palette.border or { palette.border[1], palette.border[2], palette.border[3], 0.45 }
    PixelKit.draw_panel(row_x, row_y, row_w, row_h, {
      fill = { 0.08, 0.06, 0.16, 1.0 },
      border = border,
      border_width = 2,
      shadow = 2,
    })

    if offer then
      love.graphics.setColor(palette.accent_alt)
      love.graphics.setFont(fonts.ui)
      love.graphics.print(("[%d]"):format(i), row_x + 14, row_y + 16)

      if offer.type == "card" then
        local label = ctx.game.card_label and ctx.game.card_label(offer.card) or "Card"
        love.graphics.setColor(palette.text)
        love.graphics.setFont(fonts.ui)
        love.graphics.print(("Card %s"):format(label), row_x + 88, row_y + 16)
        love.graphics.setColor(palette.muted)
        love.graphics.setFont(fonts.small)
        love.graphics.print("Adds this card to your run deck.", row_x + 88, row_y + 48)
      else
        local joker = ctx.game.JOKERS[offer.joker_key]
        local name = joker and joker.name or offer.joker_key
        love.graphics.setColor(palette.text)
        love.graphics.setFont(fonts.ui)
        love.graphics.print(("Joker %s"):format(name), row_x + 88, row_y + 16)
        love.graphics.setColor(palette.muted)
        love.graphics.setFont(fonts.small)
        love.graphics.print(joker and joker.formula or "", row_x + 88, row_y + 48)
      end

      love.graphics.setColor(palette.ok)
      love.graphics.setFont(fonts.ui)
      love.graphics.printf(("$%d"):format(offer.price), row_x, row_y + 16, row_w - 16, "right")
    else
      love.graphics.setColor(palette.muted)
      love.graphics.setFont(fonts.ui)
      love.graphics.printf(("[%d] Sold"):format(i), row_x + 14, row_y + 32, row_w - 28, "left")
    end

    row_y = row_y + row_h + 12
  end

  local controls = "1/2/3 buy | E reroll | Z/X/V deck edit | Q..Y sell jokers | A..G sell cards | C continue"
  love.graphics.setColor(palette.warn)
  love.graphics.setFont(fonts.small)
  love.graphics.printf(clipped_text(fonts.small, controls, panel_w - 48), x + 24, y + panel_h - 56, panel_w - 48, "center")
end

function Render.draw(ctx)
  local layout = Layout.columns(love.graphics.getWidth(), love.graphics.getHeight())

  draw_background(ctx)
  draw_header(ctx, layout)
  draw_feedback(ctx, layout)
  draw_hand(ctx, layout.hand)
  draw_actions(ctx, layout.actions)
  draw_joker_dock(ctx, layout.jokers)

  draw_shop_modal(ctx)
  draw_seed_prompt(ctx)
  draw_run_result(ctx)
  draw_debug_overlay(ctx)
end

return Render
