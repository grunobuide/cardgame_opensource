local Render = {}
local button_quads_cache = {}
local nine_slice_cache = {}
local icon_quads_cache = {}
-- Controlled rollout for UI asset integration:
-- 0 = clean fallback (no sprite UI except background)
-- 1 = buttons only
-- 2 = + panels/modal/tooltip frames
-- 3 = + card slot frame + hover glow
-- 4 = + dividers + CRT overlay
local ASSET_STAGE = 0

local VISUAL_PROFILE = {
  use_frame_assets = false,
  use_button_sheet = false,
  use_card_slot_frame = false,
  use_hover_glow = false,
  use_dividers = false,
  use_vignette = false,
  use_crt = false,
}

local function with_alpha(color, alpha)
  return { color[1], color[2], color[3], alpha }
end

local function draw_image_cover(ctx, path, alpha)
  local img = ctx.get_image(path)
  if not img then
    return false
  end

  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local sx = w / img:getWidth()
  local sy = h / img:getHeight()
  local scale = math.max(sx, sy)
  local draw_w = img:getWidth() * scale
  local draw_h = img:getHeight() * scale
  local offset_x = (w - draw_w) * 0.5
  local offset_y = (h - draw_h) * 0.5
  love.graphics.setColor(1, 1, 1, alpha or 1)
  love.graphics.draw(img, offset_x, offset_y, 0, scale, scale)
  return true
end

local function draw_tiled_overlay(ctx, path, alpha)
  local img = ctx.get_image(path)
  if not img then
    return false
  end
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local tw, th = img:getWidth(), img:getHeight()
  love.graphics.setColor(1, 1, 1, alpha or 0.08)
  for y = 0, h, th do
    for x = 0, w, tw do
      love.graphics.draw(img, x, y)
    end
  end
  return true
end

local function draw_frame_image(ctx, path, x, y, w, h, alpha)
  local img = ctx.get_image(path)
  if not img then
    return false
  end
  love.graphics.setColor(1, 1, 1, alpha or 1)
  love.graphics.draw(img, x, y, 0, w / img:getWidth(), h / img:getHeight())
  return true
end

local function get_nine_slice_meta(image, inset)
  local key = ("%dx%d:%d"):format(image:getWidth(), image:getHeight(), inset)
  if nine_slice_cache[key] then
    return nine_slice_cache[key]
  end

  local iw = image:getWidth()
  local ih = image:getHeight()
  local e = math.max(1, math.min(inset, math.floor(math.min(iw, ih) / 3)))
  local mw = math.max(1, iw - (2 * e))
  local mh = math.max(1, ih - (2 * e))

  local quads = {
    tl = love.graphics.newQuad(0, 0, e, e, iw, ih),
    tm = love.graphics.newQuad(e, 0, mw, e, iw, ih),
    tr = love.graphics.newQuad(e + mw, 0, e, e, iw, ih),
    ml = love.graphics.newQuad(0, e, e, mh, iw, ih),
    mm = love.graphics.newQuad(e, e, mw, mh, iw, ih),
    mr = love.graphics.newQuad(e + mw, e, e, mh, iw, ih),
    bl = love.graphics.newQuad(0, e + mh, e, e, iw, ih),
    bm = love.graphics.newQuad(e, e + mh, mw, e, iw, ih),
    br = love.graphics.newQuad(e + mw, e + mh, e, e, iw, ih),
    e = e,
    mw = mw,
    mh = mh,
  }
  nine_slice_cache[key] = quads
  return quads
end

local function draw_nine_slice(ctx, path, x, y, w, h, inset, alpha)
  local img = ctx.get_image(path)
  if not img then
    return false
  end

  local m = get_nine_slice_meta(img, inset or 36)
  local left = math.min(m.e, math.floor(w * 0.5))
  local right = math.min(m.e, w - left)
  local top = math.min(m.e, math.floor(h * 0.5))
  local bottom = math.min(m.e, h - top)
  local mid_w = math.max(0, w - left - right)
  local mid_h = math.max(0, h - top - bottom)

  love.graphics.setColor(1, 1, 1, alpha or 1)

  local function draw_quad(q, dx, dy, dw, dh, sw, sh)
    if dw <= 0 or dh <= 0 then
      return
    end
    love.graphics.draw(img, q, dx, dy, 0, dw / sw, dh / sh)
  end

  draw_quad(m.tl, x, y, left, top, m.e, m.e)
  draw_quad(m.tm, x + left, y, mid_w, top, m.mw, m.e)
  draw_quad(m.tr, x + left + mid_w, y, right, top, m.e, m.e)
  draw_quad(m.ml, x, y + top, left, mid_h, m.e, m.mh)
  draw_quad(m.mm, x + left, y + top, mid_w, mid_h, m.mw, m.mh)
  draw_quad(m.mr, x + left + mid_w, y + top, right, mid_h, m.e, m.mh)
  draw_quad(m.bl, x, y + top + mid_h, left, bottom, m.e, m.e)
  draw_quad(m.bm, x + left, y + top + mid_h, mid_w, bottom, m.mw, m.e)
  draw_quad(m.br, x + left + mid_w, y + top + mid_h, right, bottom, m.e, m.e)
  return true
end

local function draw_rim_glow(x, y, w, h, color, alpha, width)
  love.graphics.setLineWidth(width or 2)
  love.graphics.setColor(color[1], color[2], color[3], (alpha or 0.55) * 0.35)
  love.graphics.rectangle("line", x - 3, y - 3, w + 6, h + 6, 10, 10)
  love.graphics.setColor(color[1], color[2], color[3], alpha or 0.55)
  love.graphics.rectangle("line", x - 1, y - 1, w + 2, h + 2, 8, 8)
  love.graphics.setLineWidth(1)
end

local function draw_vapor_background(ctx)
  local palette = ctx.palette
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  love.graphics.setColor(palette.bg_bottom or palette.bg)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local top_overlay = with_alpha((palette.bg_top or palette.panel_alt), 0.45)
  love.graphics.setColor(top_overlay)
  love.graphics.rectangle("fill", 0, 0, w, h * 0.45)

  local horizon_y = h * 0.36
  local glow_a = with_alpha((palette.glow_a or palette.accent), 0.08)
  local glow_b = with_alpha((palette.glow_b or palette.accent_alt or palette.accent), 0.07)
  love.graphics.setColor(glow_a)
  love.graphics.circle("fill", w * 0.78, h * 0.17, 180)
  love.graphics.setColor(glow_b)
  love.graphics.circle("fill", w * 0.20, h * 0.24, 140)

  local grid_color = with_alpha((palette.grid or palette.border), 0.07)
  love.graphics.setColor(grid_color)
  for i = 0, 20 do
    local y = horizon_y + i * 24
    love.graphics.line(0, y, w, y)
  end
  local cx = w * 0.5
  for i = -13, 13 do
    local top_x = cx + i * 36
    local bottom_x = cx + i * 72
    love.graphics.line(top_x, horizon_y, bottom_x, h)
  end

  love.graphics.setColor(0.05, 0.03, 0.12, 0.75)
  love.graphics.rectangle("fill", 0, 0, w, h)

  if VISUAL_PROFILE.use_vignette then
    draw_image_cover(ctx, "assets/ui/vignette.png", 0.30)
  end
  if VISUAL_PROFILE.use_crt then
    draw_tiled_overlay(ctx, "assets/ui/crt_scanline.png", 0.025)
  end
end

local function draw_panel(ctx, x, y, w, h, style)
  local palette = ctx.palette
  local frame = "assets/ui/ui panel.png"
  local inset = 36
  local frame_alpha = 0.24
  if style == "elevated" then
    frame = "assets/ui/panel_elevated.png"
    inset = 40
    frame_alpha = 0.28
  elseif style == "modal" then
    frame = "assets/ui/modal_frame.png"
    inset = 44
    frame_alpha = 0.30
  elseif style == "tooltip" then
    frame = "assets/ui/tooltip_bubble.png"
    inset = 32
    frame_alpha = 0.20
  elseif style == "slot" then
    frame = "assets/ui/card_slot_frame.png"
    inset = 34
    frame_alpha = 0.18
  end

  love.graphics.setColor(0, 0, 0, 0.40)
  love.graphics.rectangle("fill", x + 4, y + 4, w, h, 10, 10)
  love.graphics.setColor(palette.panel)
  love.graphics.rectangle("fill", x, y, w, h, 10, 10)
  love.graphics.setColor(palette.border)
  love.graphics.rectangle("line", x, y, w, h, 10, 10)

  if VISUAL_PROFILE.use_frame_assets then
    draw_nine_slice(ctx, frame, x, y, w, h, inset, frame_alpha)
  end
end

local function get_button_quad(image, index)
  local key = ("%dx%d"):format(image:getWidth(), image:getHeight())
  if not button_quads_cache[key] then
    local frame_w = math.floor(image:getWidth() / 4)
    local frame_h = image:getHeight()
    button_quads_cache[key] = {
      love.graphics.newQuad(0, 0, frame_w, frame_h, image:getWidth(), image:getHeight()),
      love.graphics.newQuad(frame_w, 0, frame_w, frame_h, image:getWidth(), image:getHeight()),
      love.graphics.newQuad(frame_w * 2, 0, frame_w, frame_h, image:getWidth(), image:getHeight()),
      love.graphics.newQuad(frame_w * 3, 0, frame_w, frame_h, image:getWidth(), image:getHeight()),
      frame_w = frame_w,
      frame_h = frame_h,
    }
  end
  return button_quads_cache[key][index], button_quads_cache[key]
end

local function get_icon_quad(image, index, cols, rows)
  local key = ("%dx%d:%d:%d"):format(image:getWidth(), image:getHeight(), cols, rows)
  if not icon_quads_cache[key] then
    local frame_w = math.floor(image:getWidth() / cols)
    local frame_h = math.floor(image:getHeight() / rows)
    local frames = {
      frame_w = frame_w,
      frame_h = frame_h,
      total = cols * rows,
    }
    for i = 1, frames.total do
      local ix = (i - 1) % cols
      local iy = math.floor((i - 1) / cols)
      frames[i] = love.graphics.newQuad(ix * frame_w, iy * frame_h, frame_w, frame_h, image:getWidth(), image:getHeight())
    end
    icon_quads_cache[key] = frames
  end

  local meta = icon_quads_cache[key]
  local safe_index = ((index - 1) % meta.total) + 1
  return meta[safe_index], meta
end

local function get_joker_icon_sheet(ctx)
  local candidates = {
    "assets/ui/jokers_icons.png",
    "assets/ui/joker_icons.png",
    "assets/ui/icon sheet.png",
  }
  for _, path in ipairs(candidates) do
    local img = ctx.get_image(path)
    if img then
      return img
    end
  end
  return nil
end

local function draw_button(ctx, button)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local button_sheet = VISUAL_PROFILE.use_button_sheet and ctx.get_image("assets/ui/buttons.png")
  if button_sheet then
    local frame_index = button.hovered and 2 or 1
    local quad, meta = get_button_quad(button_sheet, frame_index)
    love.graphics.setColor(1, 1, 1, 0.97)
    love.graphics.draw(
      button_sheet,
      quad,
      button.x,
      button.y,
      0,
      button.w / meta.frame_w,
      button.h / meta.frame_h
    )
  else
    love.graphics.setColor(0, 0, 0, 0.40)
    love.graphics.rectangle("fill", button.x + 3, button.y + 3, button.w, button.h, 8, 8)
    love.graphics.setColor(ctx.palette.panel_alt)
    love.graphics.rectangle("fill", button.x, button.y, button.w, button.h, 8, 8)
    local border_color = ctx.palette.border
    if button.id == "play" then
      border_color = ctx.palette.accent
    end
    love.graphics.setColor(border_color[1], border_color[2], border_color[3], 0.72)
    love.graphics.rectangle("line", button.x, button.y, button.w, button.h, 8, 8)
  end

  if button.hovered then
    draw_rim_glow(button.x, button.y, button.w, button.h, palette.accent_alt or { 0.21, 0.92, 0.97, 1.0 }, 0.62, 2)
  end

  local label = tostring(button.label or ""):gsub("%s*\n%s*", " ")
  love.graphics.setColor(button.hovered and { 0.06, 0.03, 0.12, 1.0 } or palette.text)
  local font_to_use = fonts.body
  if fonts.small and fonts.body:getWidth(label) > (button.w - 12) then
    font_to_use = fonts.small
  end

  local max_text_w = math.max(0, button.w - 12)
  if font_to_use:getWidth(label) > max_text_w then
    local clipped = label
    while #clipped > 0 and font_to_use:getWidth(clipped .. "...") > max_text_w do
      clipped = clipped:sub(1, -2)
    end
    label = clipped ~= "" and (clipped .. "...") or ""
  end

  love.graphics.setFont(font_to_use)
  local text_w = font_to_use:getWidth(label)
  local text_h = font_to_use:getHeight()
  local text_x = button.x + math.floor((button.w - text_w) * 0.5)
  local text_y = button.y + math.floor((button.h - text_h) * 0.5) - 1
  love.graphics.print(label, text_x, text_y)
end

local function draw_top_stats(ctx)
  local palette = ctx.palette
  local state = ctx.state
  local game = ctx.game
  local fonts = ctx.fonts

  love.graphics.setColor(palette.text)
  love.graphics.setFont(fonts.title)
  love.graphics.print("Open Balatro", 28, 22)

  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.body)
  local metrics_line = ("Target %d   |   Score %d   |   Hands %d   |   Discards %d"):format(
    game.current_target(state),
    state.score,
    state.hands,
    state.discards
  )
  love.graphics.print(metrics_line, 28, 58)

  love.graphics.setColor(palette.border)
  love.graphics.setLineWidth(1)
  love.graphics.line(24, 92, 936, 92)

  love.graphics.setColor(palette.warn)
  love.graphics.printf(("Blind: %s"):format(game.current_blind(state).label), 700, 22, 228, "right")
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.printf(("Seed: %s"):format(ctx.current_seed or "n/a"), 560, 58, 368, "right")
end

local function draw_preview(ctx, projection)
  local palette = ctx.palette
  local fonts = ctx.fonts

  love.graphics.setFont(fonts.body)

  if not projection then
    love.graphics.setColor(palette.muted)
    love.graphics.print("Base: select 1 to 5 cards", 28, 610)
    love.graphics.setColor(palette.accent)
    love.graphics.setFont(fonts.title)
    love.graphics.printf("Projected +0", 670, 600, 260, "right")
    return
  end

  local base_line = ("Base: %s   x%d"):format(
    projection.hand_type.label,
    projection.base_mult
  )
  love.graphics.setColor(palette.text)
  love.graphics.print(base_line, 28, 610)

  local joker_parts = {}
  for _, detail in ipairs(projection.joker_details) do
    local joker = ctx.game.JOKERS[detail.joker_key]
    local chips = detail.effect.chips or 0
    local mult = detail.effect.mult or 0
    joker_parts[#joker_parts + 1] = ("%s (+%dC +%dM)"):format(joker.name, chips, mult)
  end
  local joker_line = #joker_parts > 0 and ("Jokers: " .. table.concat(joker_parts, " | ")) or "Jokers: none"
  love.graphics.setColor(palette.muted)
  love.graphics.printf(joker_line, 28, 634, 600, "left")

  love.graphics.setColor(palette.accent)
  love.graphics.setFont(fonts.title)
  love.graphics.printf(("Projected +%d"):format(projection.total), 650, 600, 280, "right")
end

local function draw_pressure(ctx)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local state = ctx.state
  local target = ctx.game.current_target(state)
  local progress = math.min(1, state.score / target)

  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.body)
  love.graphics.print("Blind Pressure", 28, 566)
  love.graphics.printf(("%d / %d"):format(state.score, target), 760, 566, 170, "right")

  local bar_x, bar_y, bar_w, bar_h = 188, 570, 540, 16
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h, 8, 8)
  love.graphics.setColor(palette.border[1], palette.border[2], palette.border[3], 0.45)
  love.graphics.rectangle("line", bar_x, bar_y, bar_w, bar_h, 8, 8)

  local fill_color = palette.ok
  if state.hands <= 1 and progress < 0.9 then
    fill_color = palette.danger
  elseif state.hands <= 2 and progress < 0.65 then
    fill_color = palette.warn
  end
  love.graphics.setColor(fill_color)
  love.graphics.rectangle("fill", bar_x, bar_y, bar_w * progress, bar_h, 8, 8)
end

local function draw_message(ctx)
  love.graphics.setColor(ctx.palette.warn)
  love.graphics.setFont(ctx.fonts.body)
  love.graphics.printf(ctx.state.message or "", 24, 744, 912, "center")
end

local function draw_seed_prompt(ctx)
  if not ctx.seed_input_mode then
    return
  end

  local px, py, pw, ph = 170, 340, 620, 120
  draw_panel(ctx, px, py, pw, ph, "modal")
  love.graphics.setFont(ctx.fonts.body)
  love.graphics.setColor(ctx.palette.text)
  love.graphics.printf("Enter Seed", px, py + 16, pw, "center")
  love.graphics.setColor(ctx.palette.muted)
  love.graphics.printf(ctx.seed_buffer ~= "" and ctx.seed_buffer or "_", px + 20, py + 52, pw - 40, "center")
  love.graphics.printf("Enter apply | Esc cancel", px, py + 86, pw, "center")
end

local function draw_hand(ctx)
  local palette = ctx.palette
  local state = ctx.state
  love.graphics.setColor(palette.border[1], palette.border[2], palette.border[3], 0.38)
  love.graphics.line(24, 170, 936, 170)
  love.graphics.line(24, 548, 936, 548)
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(ctx.fonts.body)
  love.graphics.print("Hand", 28, 182)

  local slot_frame = VISUAL_PROFILE.use_card_slot_frame and ctx.get_image("assets/ui/card_slot_frame.png")
  local hover_glow = VISUAL_PROFILE.use_hover_glow and ctx.get_image("assets/ui/hover_glow.png")
  local mx, my = love.mouse.getPosition()

  for _, visual in ipairs(ctx.card_visuals) do
    local card = visual.card
    local draw_x = visual.x
    local draw_y = visual.y + visual.lift
    local sprite = ctx.game.card_sprite_path(card, ctx.theme)
    local img = ctx.get_image(sprite)

    if slot_frame then
      love.graphics.setColor(1, 1, 1, 0.20)
      love.graphics.draw(slot_frame, draw_x - 4, draw_y - 4, 0, (visual.w + 8) / slot_frame:getWidth(), (visual.h + 8) / slot_frame:getHeight())
    end

    love.graphics.setColor(1, 1, 1, visual.alpha)
    if img then
      local sx = visual.w / img:getWidth()
      local sy = visual.h / img:getHeight()
      love.graphics.draw(img, draw_x, draw_y, visual.rotation, sx * visual.scale, sy * visual.scale)
    else
      love.graphics.setColor(0.95, 0.95, 0.98, visual.alpha)
      love.graphics.rectangle("fill", draw_x, draw_y, visual.w, visual.h, 8, 8)
      love.graphics.setColor(0.15, 0.2, 0.3, visual.alpha)
      love.graphics.rectangle("line", draw_x, draw_y, visual.w, visual.h, 8, 8)
      love.graphics.setColor(0.12, 0.16, 0.24, visual.alpha)
      love.graphics.printf(tostring(card.rank) .. card.suit, draw_x, draw_y + 56, visual.w, "center")
    end

    local is_hovered = mx >= draw_x and mx <= draw_x + visual.w and my >= draw_y and my <= draw_y + visual.h
    if state.selected[visual.index] then
      if hover_glow then
        love.graphics.setColor(1, 1, 1, math.max(visual.alpha, 0.42))
        love.graphics.draw(hover_glow, draw_x - 8, draw_y - 8, 0, (visual.w + 16) / hover_glow:getWidth(), (visual.h + 16) / hover_glow:getHeight())
      end
      draw_rim_glow(draw_x, draw_y, visual.w, visual.h, palette.select or { 0.95, 0.33, 1.0, 1.0 }, math.max(visual.alpha, 0.45), 3)
    elseif is_hovered then
      draw_rim_glow(draw_x, draw_y, visual.w, visual.h, palette.accent_alt or { 0.21, 0.92, 0.97, 1.0 }, math.max(visual.alpha, 0.42), 2)
    end
  end
end

local function draw_jokers(ctx)
  local palette = ctx.palette
  love.graphics.setColor(0.04, 0.03, 0.12, 0.86)
  love.graphics.rectangle("fill", 0, 676, 960, 114)
  love.graphics.setColor(palette.border[1], palette.border[2], palette.border[3], 0.25)
  love.graphics.line(24, 676, 936, 676)
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(ctx.fonts.body)
  love.graphics.print("Jokers", 30, 686)

  local start_x = 30
  local y = 708
  local w = 172
  local h = 84
  local gap = 10
  local mx, my = love.mouse.getPosition()
  local time_s = love.timer.getTime()
  local icon_sheet = get_joker_icon_sheet(ctx)
  local icon_cols, icon_rows = 4, 3
  local icon_index_by_key = {
    JOKER = 1,
    GREEDY_JOKER = 2,
    PAIR_JOKER = 3,
  }
  for i, joker_key in ipairs(ctx.state.jokers) do
    local joker = ctx.game.JOKERS[joker_key]
    if joker then
      local x = start_x + (i - 1) * (w + gap)
      local hovered = (mx >= x and mx <= x + w and my >= y and my <= y + h)
      local hover_scale = hovered and 1.05 or 1.0
      local card_x = x - ((w * hover_scale) - w) * 0.5
      local card_y = y - ((h * hover_scale) - h) * 0.5
      local card_w = w * hover_scale
      local card_h = h * hover_scale

      local rarity_color = palette.border
      if joker.rarity == "uncommon" then
        rarity_color = palette.accent
      elseif joker.rarity == "rare" then
        rarity_color = { 0.73, 1.0, 0.25, 1.0 }
      end

      draw_panel(ctx, card_x, card_y, card_w, card_h, "base")
      local pulse = 0.5 + 0.5 * math.sin((time_s * 3.2) + (i * 0.4))
      local glow_alpha = (hovered and 0.18 or 0.08) + pulse * 0.12
      draw_rim_glow(card_x, card_y, card_w, card_h, palette.accent_alt or { 0.21, 0.92, 0.97, 1.0 }, glow_alpha, hovered and 2 or 1.5)

      if joker.rarity == "uncommon" then
        draw_rim_glow(card_x, card_y, card_w, card_h, rarity_color, 0.28 + pulse * 0.10, 2)
      end
      if joker.rarity == "rare" then
        draw_rim_glow(card_x, card_y, card_w, card_h, rarity_color, 0.35 + pulse * 0.20, 3)
      end

      local icon_x = card_x + 8
      local icon_y = card_y + 10
      local icon_size = 56 * hover_scale
      if icon_sheet then
        local icon_index = icon_index_by_key[joker_key] or i
        local quad, meta = get_icon_quad(icon_sheet, icon_index, icon_cols, icon_rows)
        love.graphics.setColor(1, 1, 1, 0.96)
        love.graphics.draw(icon_sheet, quad, icon_x, icon_y, 0, icon_size / meta.frame_w, icon_size / meta.frame_h)
      else
        love.graphics.setColor(palette.border[1], palette.border[2], palette.border[3], 0.45)
        love.graphics.rectangle("fill", icon_x, icon_y, icon_size, icon_size, 8, 8)
      end

      love.graphics.setColor(palette.text)
      love.graphics.setFont(ctx.fonts.small)
      love.graphics.print(joker.name .. " [" .. joker.rarity .. "]", card_x + 70, card_y + 10)
      love.graphics.setColor(palette.muted)
      love.graphics.printf(joker.formula, card_x + 70, card_y + 32, card_w - 78, "left")
    end
  end
end

local function draw_run_result(ctx)
  local result = ctx.run_result
  if not result then
    return
  end

  love.graphics.setColor(0, 0, 0, 0.68)
  love.graphics.rectangle("fill", 0, 0, love.graphics.getWidth(), love.graphics.getHeight())

  local px, py, pw, ph = 120, 90, 720, 600
  draw_panel(ctx, px, py, pw, ph, "modal")

  love.graphics.setFont(ctx.fonts.title)
  love.graphics.setColor(result.won and ctx.palette.ok or ctx.palette.danger)
  love.graphics.printf(result.won and "Run Complete" or "Run Over", px, py + 18, pw, "center")

  love.graphics.setFont(ctx.fonts.body)
  love.graphics.setColor(ctx.palette.text)
  love.graphics.print(("Ante reached: %d"):format(result.ante_reached), px + 24, py + 74)
  love.graphics.print(("Final blind: %s"):format(result.blind_reached), px + 24, py + 100)
  love.graphics.print(("Total score gained: %d"):format(result.total_score), px + 24, py + 126)
  love.graphics.print(("Plays: %d   Discards: %d   Blind clears: %d"):format(
    result.total_plays,
    result.total_discards,
    result.blind_clears
  ), px + 24, py + 152)

  love.graphics.setColor(ctx.palette.muted)
  love.graphics.printf("Per-round stats", px + 24, py + 186, pw - 48, "left")

  local y = py + 214
  local max_rows = 11
  local start_index = math.max(1, #result.rounds - max_rows + 1)
  for i = start_index, #result.rounds do
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
    love.graphics.printf(line, px + 24, y, pw - 48, "left")
    y = y + 24
  end

  love.graphics.setColor(ctx.palette.warn)
  love.graphics.printf("Press Enter/Space or click to start a new run", px, py + ph - 42, pw, "center")
end

function Render.draw(ctx)
  draw_vapor_background(ctx)

  local divider = VISUAL_PROFILE.use_dividers and ctx.get_image("assets/ui/divider ornaments.png")
  if divider then
    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.draw(divider, 20, 170, 0, 920 / divider:getWidth(), 28 / divider:getHeight())
    love.graphics.draw(divider, 20, 612, 0, 920 / divider:getWidth(), 28 / divider:getHeight())
  end

  draw_top_stats(ctx)
  for _, button in ipairs(ctx.buttons) do
    draw_button(ctx, button)
  end
  draw_preview(ctx, ctx.projection)
  draw_pressure(ctx)
  draw_message(ctx)
  draw_hand(ctx)
  draw_jokers(ctx)
  draw_run_result(ctx)
  draw_seed_prompt(ctx)

  love.graphics.setColor(ctx.palette.muted)
  love.graphics.setFont(ctx.fonts.small)
  love.graphics.print(
    "Controls: mouse/1..8 select | Space play | D discard | R run | J joker | F royal | S suit | N rank | T theme | K seed | G new seed",
    20,
    772
  )
end

return Render
