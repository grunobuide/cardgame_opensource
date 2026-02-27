local Layout = require("ui.layout")
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

local BUTTON_ART_MAP = {
  play = 1,       -- PLAY
  add_joker = 2,  -- SHOP
  sort_suit = 3,  -- DECK
  discard = 4,    -- DISCARD
  royal = 5,      -- BOSS
  new_run = 8,    -- RESET
  sort_rank = 9,  -- CONFIG
}

-- Bounding boxes in assets/buttons.png (1536x1024) discovered from alpha islands.
-- Each entry is { x, y, w, h } with 0-based x/y.
local BUTTON_ART_RECTS = {
  { 80, 128, 414, 129 },
  { 560, 128, 414, 129 },
  { 1041, 128, 435, 129 },
  { 83, 435, 409, 124 },
  { 562, 435, 411, 124 },
  { 1043, 435, 431, 124 },
  { 154, 756, 339, 106 },
  { 658, 740, 218, 147 },
  { 997, 749, 401, 144 },
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

local function draw_image_contain(image, x, y, w, h, alpha, quad, source_w, source_h)
  local iw = source_w or image:getWidth()
  local ih = source_h or image:getHeight()
  if iw <= 0 or ih <= 0 then
    return false
  end
  local scale = math.min(w / iw, h / ih)
  if scale <= 0 then
    return false
  end
  local dw = iw * scale
  local dh = ih * scale
  local dx = x + (w - dw) * 0.5
  local dy = y + (h - dh) * 0.5
  love.graphics.setColor(1, 1, 1, alpha or 1)
  if quad then
    love.graphics.draw(image, quad, dx, dy, 0, dw / iw, dh / ih)
  else
    love.graphics.draw(image, dx, dy, 0, dw / image:getWidth(), dh / image:getHeight())
  end
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
  love.graphics.setColor(color[1], color[2], color[3], alpha or 1.0)
  love.graphics.rectangle("line", x - 1, y - 1, w + 2, h + 2)
  love.graphics.setLineWidth(1)
end

local function message_severity(message)
  local text = string.lower(tostring(message or ""))
  if text == "" then
    return "none"
  end
  if text:find("bust", 1, true) or text:find("fail", 1, true) or text:find("no ", 1, true) then
    return "danger"
  end
  if text:find("not enough", 1, true) or text:find("max ", 1, true) or text:find("invalid", 1, true) then
    return "warn"
  end
  if text:find("cleared", 1, true) or text:find("added", 1, true) or text:find("bought", 1, true) then
    return "ok"
  end
  return "warn"
end

local function build_battle_layout()
  return Layout.columns(love.graphics.getWidth(), love.graphics.getHeight())
end

local function draw_vapor_background(ctx)
  local palette = ctx.palette
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  love.graphics.setColor(palette.bg_bottom or palette.bg)
  love.graphics.rectangle("fill", 0, 0, w, h)

  love.graphics.setColor(palette.bg_top or palette.panel_alt)
  love.graphics.rectangle("fill", 0, 0, w, math.floor(h * 0.44))

  local horizon_y = math.floor(h * 0.36)
  local grid_color = palette.grid or palette.border
  love.graphics.setColor(grid_color)
  for y = horizon_y, h, 16 do
    love.graphics.line(0, y, w, y)
  end
  local cx = w * 0.5
  for i = -14, 14 do
    local top_x = cx + i * 30
    local bottom_x = cx + i * 60
    love.graphics.line(top_x, horizon_y, bottom_x, h)
  end

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

  love.graphics.setColor(0, 0, 0, 0.5)
  love.graphics.rectangle("fill", x + 2, y + 2, w, h)
  love.graphics.setColor(palette.panel)
  love.graphics.rectangle("fill", x, y, w, h)
  love.graphics.setColor(palette.border)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", x, y, w, h)
  love.graphics.setLineWidth(1)

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

local function get_button_art_quad(image, index)
  local key = ("art:%dx%d"):format(image:getWidth(), image:getHeight())
  if not button_quads_cache[key] then
    local data = { count = #BUTTON_ART_RECTS }
    if image:getWidth() == 1536 and image:getHeight() == 1024 then
      for i, rect in ipairs(BUTTON_ART_RECTS) do
        local rx, ry, rw, rh = rect[1], rect[2], rect[3], rect[4]
        data[i] = {
          quad = love.graphics.newQuad(rx, ry, rw, rh, image:getWidth(), image:getHeight()),
          w = rw,
          h = rh,
        }
      end
    else
      local cols, rows = 3, 3
      local frame_w = math.floor(image:getWidth() / cols)
      local frame_h = math.floor(image:getHeight() / rows)
      for i = 1, cols * rows do
        local ix = (i - 1) % cols
        local iy = math.floor((i - 1) / cols)
        data[i] = {
          quad = love.graphics.newQuad(ix * frame_w, iy * frame_h, frame_w, frame_h, image:getWidth(), image:getHeight()),
          w = frame_w,
          h = frame_h,
        }
      end
    end
    button_quads_cache[key] = data
  end
  local meta = button_quads_cache[key]
  local idx = ((index - 1) % meta.count) + 1
  return meta[idx]
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
    "assets/cards/jkrs_nobg.png",
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
  local custom_sheet = ctx.get_image("assets/buttons.png")
  local button_sheet = VISUAL_PROFILE.use_button_sheet and ctx.get_image("assets/ui/buttons.png")
  local tier = button.tier or "tertiary"

  if custom_sheet and BUTTON_ART_MAP[button.id] then
    local art = get_button_art_quad(custom_sheet, BUTTON_ART_MAP[button.id])
    if art then
      local padding = 3
      local draw_alpha = button.hovered and 1.0 or 0.94
      draw_image_contain(
        custom_sheet,
        button.x + padding,
        button.y + padding,
        button.w - (padding * 2),
        button.h - (padding * 2),
        draw_alpha,
        art.quad,
        art.w,
        art.h
      )
      if button.hovered then
        draw_rim_glow(button.x, button.y, button.w, button.h, palette.accent_alt or { 0.21, 0.92, 0.97, 1.0 }, 0.9, 2)
      end
      local key_hint = tostring(button.key_hint or "")
      if key_hint ~= "" then
        local hint_w, hint_h = 34, 14
        local hx = button.x + button.w - hint_w - 2
        local hy = button.y + 2
        love.graphics.setColor(0, 0, 0, 0.65)
        love.graphics.rectangle("fill", hx, hy, hint_w, hint_h)
        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.rectangle("line", hx, hy, hint_w, hint_h)
        love.graphics.setColor(1, 1, 1, 0.92)
        love.graphics.setFont(fonts.small)
        local hw = fonts.small:getWidth(key_hint)
        love.graphics.print(key_hint, hx + math.floor((hint_w - hw) * 0.5), hy + 1)
      end
      return
    end
  end

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
    local fill = ctx.palette.panel_alt
    local border_color = ctx.palette.border
    local shadow_alpha = 0.35
    if tier == "primary" then
      fill = with_alpha(ctx.palette.accent, 0.92)
      border_color = ctx.palette.accent
      shadow_alpha = 0.48
    elseif tier == "secondary" then
      fill = with_alpha(ctx.palette.accent_alt, 0.35)
      border_color = ctx.palette.accent_alt
      shadow_alpha = 0.42
    else
      fill = with_alpha(ctx.palette.panel_alt, 0.82)
      border_color = with_alpha(ctx.palette.border, 0.65)
    end

    love.graphics.setColor(0, 0, 0, shadow_alpha)
    love.graphics.rectangle("fill", button.x + 2, button.y + 2, button.w, button.h)
    love.graphics.setColor(fill)
    love.graphics.rectangle("fill", button.x, button.y, button.w, button.h)
    love.graphics.setColor(border_color[1], border_color[2], border_color[3], border_color[4] or 0.72)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", button.x, button.y, button.w, button.h)
    love.graphics.setLineWidth(1)
  end

  if button.hovered then
    local hover_color = tier == "primary" and (palette.accent or { 1.0, 0.3, 0.85, 1.0 }) or (palette.accent_alt or { 0.21, 0.92, 0.97, 1.0 })
    draw_rim_glow(button.x, button.y, button.w, button.h, hover_color, 1.0, 2)
  end

  local label = tostring(button.label or ""):gsub("%s*\n%s*", " ")
  local icon = tostring(button.icon or "")
  local key_hint = tostring(button.key_hint or "")
  local text_color = palette.text
  if tier == "primary" and not button.hovered then
    text_color = { 0.06, 0.03, 0.12, 1.0 }
  end
  love.graphics.setColor(text_color)
  local font_to_use = fonts.body
  local left_icon_w = icon ~= "" and 36 or 0
  local right_hint_w = key_hint ~= "" and 46 or 0
  local text_padding = 10 + left_icon_w + right_hint_w
  if fonts.small and fonts.body:getWidth(label) > (button.w - text_padding) then
    font_to_use = fonts.small
  end

  local max_text_w = math.max(0, button.w - text_padding)
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
  local text_area_x = button.x + 6 + left_icon_w
  local text_area_w = button.w - 12 - left_icon_w - right_hint_w
  local text_x = text_area_x + math.floor((text_area_w - text_w) * 0.5)
  local text_y = button.y + math.floor((button.h - text_h) * 0.5) - 1

  if icon ~= "" then
    local badge_w, badge_h = 30, button.h - 12
    local bx = button.x + 6
    local by = button.y + 6
    love.graphics.setColor(0, 0, 0, 0.26)
    love.graphics.rectangle("fill", bx, by, badge_w, badge_h)
    love.graphics.setColor(palette.border[1], palette.border[2], palette.border[3], 0.35)
    love.graphics.rectangle("line", bx, by, badge_w, badge_h)
    love.graphics.setColor(text_color)
    love.graphics.setFont(fonts.small)
    local iw = fonts.small:getWidth(icon)
    local ix = bx + math.floor((badge_w - iw) * 0.5)
    local iy = by + math.floor((badge_h - fonts.small:getHeight()) * 0.5)
    love.graphics.print(icon, ix, iy)
  end

  if key_hint ~= "" then
    local hint_w, hint_h = 40, button.h - 14
    local hx = button.x + button.w - hint_w - 6
    local hy = button.y + 7
    love.graphics.setColor(0, 0, 0, 0.38)
    love.graphics.rectangle("fill", hx, hy, hint_w, hint_h)
    love.graphics.setColor(palette.border[1], palette.border[2], palette.border[3], 0.70)
    love.graphics.rectangle("line", hx, hy, hint_w, hint_h)
    love.graphics.setColor(text_color)
    love.graphics.setFont(fonts.small)
    local hw = fonts.small:getWidth(key_hint)
    local hy_text = hy + math.floor((hint_h - fonts.small:getHeight()) * 0.5)
    love.graphics.print(key_hint, hx + math.floor((hint_w - hw) * 0.5), hy_text)
  end

  love.graphics.setFont(font_to_use)
  love.graphics.print(label, text_x, text_y)
end

local function draw_top_stats(ctx, layout)
  local palette = ctx.palette
  local state = ctx.state
  local game = ctx.game
  local fonts = ctx.fonts
  local top = layout.top
  local logo = ctx.get_image("assets/game_logo.png")

  draw_panel(ctx, top.x, top.y, top.w, top.h, "base")

  local left_anchor = top.x + 12
  if logo then
    local logo_w = 188
    local logo_h = top.h - 14
    draw_image_contain(logo, top.x + 8, top.y + 7, logo_w, logo_h, 1.0)
    left_anchor = top.x + logo_w + 10
  else
    love.graphics.setColor(palette.text)
    love.graphics.setFont(fonts.title)
    love.graphics.print("OPEN BALATRO", top.x + 12, top.y + 10)
    left_anchor = top.x + 176
  end

  love.graphics.setColor(palette.warn)
  love.graphics.setFont(fonts.body)
  love.graphics.printf(("Blind: %s"):format(game.current_blind(state).label), top.x + top.w - 300, top.y + 14, 288, "right")

  local metrics = {
    ("TGT %d"):format(game.current_target(state)),
    ("SCR %d"):format(state.score),
    ("$ %d"):format(state.money or 0),
    ("HND %d"):format(state.hands),
    ("DSC %d"):format(state.discards),
  }
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.print(table.concat(metrics, "  |  "), left_anchor, top.y + 50)

  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.printf(("Seed: %s"):format(ctx.current_seed or "n/a"), top.x + top.w - 300, top.y + 50, 288, "right")
end

local function draw_left_sidebar(ctx, layout)
  local palette = ctx.palette
  local state = ctx.state
  local game = ctx.game
  local fonts = ctx.fonts

  draw_panel(ctx, layout.left.status.x, layout.left.status.y, layout.left.status.w, layout.left.status.h, "base")
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.print("RUN STATUS", layout.left.status.x + 10, layout.left.status.y + 8)

  local lines = {
    ("Ante: %d"):format(state.ante),
    ("Blind: %s"):format(game.current_blind(state).label),
    ("Target: %d"):format(game.current_target(state)),
    ("Score: %d"):format(state.score),
    ("Hands: %d"):format(state.hands),
    ("Discards: %d"):format(state.discards),
    ("Credits: $%d"):format(state.money or 0),
  }

  local y = layout.left.status.y + 30
  for _, line in ipairs(lines) do
    love.graphics.setColor(palette.text)
    love.graphics.setFont(fonts.body)
    love.graphics.print(line, layout.left.status.x + 12, y)
    y = y + 24
  end

  draw_panel(ctx, layout.left.upgrades.x, layout.left.upgrades.y, layout.left.upgrades.w, layout.left.upgrades.h, "base")
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.print("UPGRADES", layout.left.upgrades.x + 10, layout.left.upgrades.y + 8)
  love.graphics.setColor(palette.text)
  love.graphics.setFont(fonts.small)
  love.graphics.printf(
    "Deck editing and permanent upgrades arrive in M2/M3.",
    layout.left.upgrades.x + 10,
    layout.left.upgrades.y + 34,
    layout.left.upgrades.w - 20,
    "left"
  )

  draw_panel(ctx, layout.left.tools.x, layout.left.tools.y, layout.left.tools.w, layout.left.tools.h, "base")
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.print("TOOLS", layout.left.tools.x + 10, layout.left.tools.y + 8)
end

local function draw_center_lane(ctx, layout)
  local palette = ctx.palette
  local state = ctx.state
  local fonts = ctx.fonts

  draw_panel(ctx, layout.center.round.x, layout.center.round.y, layout.center.round.w, layout.center.round.h, "base")
  love.graphics.setColor(palette.text)
  love.graphics.setFont(fonts.body)
  love.graphics.printf(("ROUND A%d - %s"):format(state.ante, ctx.game.current_blind(state).label), layout.center.round.x, layout.center.round.y + 10, layout.center.round.w, "center")

  draw_panel(ctx, layout.center.enemies.x, layout.center.enemies.y, layout.center.enemies.w, layout.center.enemies.h, "base")
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.printf("Combat Lane", layout.center.enemies.x, layout.center.enemies.y + 8, layout.center.enemies.w, "center")
  love.graphics.setColor(palette.accent)
  love.graphics.setFont(fonts.body)
  love.graphics.printf(("Press Space to play up to 5 cards"), layout.center.enemies.x, layout.center.enemies.y + 28, layout.center.enemies.w, "center")
end

local function draw_preview(ctx, projection, area)
  local palette = ctx.palette
  local fonts = ctx.fonts

  draw_panel(ctx, area.x, area.y, area.w, area.h, "base")
  local compact = area.h <= 56
  love.graphics.setFont(compact and fonts.small or fonts.body)
  local projection_font = compact and fonts.body or fonts.title

  if not projection then
    love.graphics.setColor(palette.muted)
    love.graphics.print("Base: select 1 to 5 cards", area.x + 12, area.y + 8)
    love.graphics.setColor(palette.accent)
    love.graphics.setFont(projection_font)
    local py = area.y + area.h - projection_font:getHeight() - 6
    love.graphics.printf("Projected +0", area.x + 10, py, area.w - 20, "right")
    return
  end

  local base_line = ("Base: %s   x%d"):format(
    projection.hand_type.label,
    projection.base_mult
  )
  love.graphics.setColor(palette.text)
  love.graphics.print(base_line, area.x + 12, area.y + 8)

  if not compact then
    local joker_parts = {}
    for _, detail in ipairs(projection.joker_details) do
      local joker = ctx.game.JOKERS[detail.joker_key]
      local chips = detail.effect.chips or 0
      local mult = detail.effect.mult or 0
      joker_parts[#joker_parts + 1] = ("%s (+%dC +%dM)"):format(joker.name, chips, mult)
    end
    local joker_line = #joker_parts > 0 and ("Jokers: " .. table.concat(joker_parts, " | ")) or "Jokers: none"
    love.graphics.setColor(palette.muted)
    love.graphics.setFont(fonts.small)
    love.graphics.printf(joker_line, area.x + 12, area.y + 30, area.w - 170, "left")
  end

  love.graphics.setColor(palette.accent)
  love.graphics.setFont(projection_font)
  local py = area.y + area.h - projection_font:getHeight() - 6
  love.graphics.printf(("Projected +%d"):format(projection.total), area.x + 10, py, area.w - 20, "right")
end

local function draw_pressure(ctx, area)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local state = ctx.state
  local target = ctx.game.current_target(state)
  local progress = math.min(1, state.score / target)

  draw_panel(ctx, area.x, area.y, area.w, area.h, "base")
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.print("Blind Pressure", area.x + 12, area.y + 10)
  love.graphics.printf(("%d / %d"):format(state.score, target), area.x + area.w - 150, area.y + 10, 136, "right")

  local bar_x, bar_y, bar_w, bar_h = area.x + 12, area.y + 34, area.w - 24, area.h - 44
  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", bar_x, bar_y, bar_w, bar_h)
  love.graphics.setColor(palette.border[1], palette.border[2], palette.border[3], 0.45)
  love.graphics.setLineWidth(2)
  love.graphics.rectangle("line", bar_x, bar_y, bar_w, bar_h)
  love.graphics.setLineWidth(1)

  local fill_color = palette.ok
  if state.hands <= 1 and progress < 0.9 then
    fill_color = palette.danger
  elseif state.hands <= 2 and progress < 0.65 then
    fill_color = palette.warn
  end
  local segment_count = 20
  local gap = 2
  local seg_w = math.floor((bar_w - (segment_count - 1) * gap) / segment_count)
  local filled = math.floor(progress * segment_count + 0.0001)
  for i = 1, segment_count do
    local sx = bar_x + (i - 1) * (seg_w + gap)
    if i <= filled then
      love.graphics.setColor(fill_color)
      love.graphics.rectangle("fill", sx, bar_y + 2, seg_w, bar_h - 4)
    else
      love.graphics.setColor(palette.panel_alt)
      love.graphics.rectangle("fill", sx, bar_y + 2, seg_w, bar_h - 4)
    end
  end
end

local function draw_message(ctx, area)
  local message = ctx.state.message or ""
  draw_panel(ctx, area.x, area.y, area.w, area.h, "base")
  if message == "" then
    return
  end
  local severity = message_severity(message)
  local color = ctx.palette.warn
  if severity == "danger" then
    color = ctx.palette.danger
  elseif severity == "ok" then
    color = ctx.palette.ok
  end

  love.graphics.setColor(0, 0, 0, 0.45)
  love.graphics.rectangle("fill", area.x + 6, area.y + 4, area.w - 12, area.h - 8)
  love.graphics.setColor(color)
  love.graphics.setFont(ctx.fonts.small)
  local ty = area.y + math.floor((area.h - ctx.fonts.small:getHeight()) * 0.5)
  love.graphics.printf(message, area.x + 10, ty, area.w - 20, "center")
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

local function draw_shop_modal(ctx)
  local shop = ctx.state.shop
  if not (shop and shop.active) then
    return
  end

  local px, py, pw, ph = 90, 120, 780, 470
  draw_panel(ctx, px, py, pw, ph, "modal")
  love.graphics.setFont(ctx.fonts.title)
  love.graphics.setColor(ctx.palette.text)
  love.graphics.printf("Shop", px, py + 18, pw, "center")

  love.graphics.setFont(ctx.fonts.body)
  love.graphics.setColor(ctx.palette.muted)
  love.graphics.printf(
    ("Money: $%d   |   Reroll: $%d"):format(ctx.state.money or 0, shop.reroll_cost or 0),
    px + 24,
    py + 62,
    pw - 48,
    "left"
  )

  local card_w, card_h = 228, 230
  local gap = 20
  local start_x = px + 24
  local row_y = py + 98
  for i = 1, 3 do
    local offer = shop.offers[i]
    local x = start_x + (i - 1) * (card_w + gap)
    draw_panel(ctx, x, row_y, card_w, card_h, "base")
    love.graphics.setColor(ctx.palette.border[1], ctx.palette.border[2], ctx.palette.border[3], 0.2)
    love.graphics.rectangle("fill", x + 10, row_y + 10, 60, 60)

    love.graphics.setFont(ctx.fonts.small)
    if offer then
      local joker = ctx.game.JOKERS[offer.joker_key]
      local name = joker and joker.name or offer.joker_key
      love.graphics.setColor(ctx.palette.text)
      love.graphics.printf(("[%d] %s"):format(i, name), x + 78, row_y + 14, card_w - 88, "left")
      love.graphics.setColor(ctx.palette.muted)
      love.graphics.printf(("Rarity: %s"):format(offer.rarity), x + 78, row_y + 40, card_w - 88, "left")
      love.graphics.printf(joker and joker.formula or "", x + 12, row_y + 84, card_w - 24, "left")
      love.graphics.setColor(ctx.palette.accent)
      love.graphics.printf(("$%d"):format(offer.price), x + 12, row_y + card_h - 38, card_w - 24, "right")
    else
      love.graphics.setColor(ctx.palette.muted)
      love.graphics.printf(("[%d] Sold"):format(i), x + 12, row_y + 18, card_w - 24, "left")
    end
  end

  love.graphics.setColor(ctx.palette.warn)
  love.graphics.setFont(ctx.fonts.body)
  love.graphics.printf("[1][2][3] Buy  |  [E] Reroll  |  [C] Continue", px, py + ph - 44, pw, "center")
end

local function draw_hand(ctx, area)
  local palette = ctx.palette
  local state = ctx.state
  draw_panel(ctx, area.x, area.y, area.w, area.h, "elevated")
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(ctx.fonts.small)
  love.graphics.print("HAND", area.x + 10, area.y + 8)

  local slot_frame = VISUAL_PROFILE.use_card_slot_frame and ctx.get_image("assets/ui/card_slot_frame.png")
  local hover_glow = VISUAL_PROFILE.use_hover_glow and ctx.get_image("assets/ui/hover_glow.png")
  local mx = ctx.mouse_x or -9999
  local my = ctx.mouse_y or -9999

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
      love.graphics.rectangle("fill", draw_x, draw_y, visual.w, visual.h)
      love.graphics.setColor(0.15, 0.2, 0.3, visual.alpha * 0.8)
      love.graphics.setLineWidth(2)
      love.graphics.rectangle("line", draw_x, draw_y, visual.w, visual.h)
      love.graphics.setLineWidth(1)
      love.graphics.setColor(0.12, 0.16, 0.24, visual.alpha)
      love.graphics.printf(tostring(card.rank) .. card.suit, draw_x, draw_y + 56, visual.w, "center")
    end

    local is_hovered = mx >= draw_x and mx <= draw_x + visual.w and my >= draw_y and my <= draw_y + visual.h
    if state.selected[visual.index] then
      if hover_glow then
        love.graphics.setColor(1, 1, 1, math.max(visual.alpha, 0.42))
        love.graphics.draw(hover_glow, draw_x - 8, draw_y - 8, 0, (visual.w + 16) / hover_glow:getWidth(), (visual.h + 16) / hover_glow:getHeight())
      end
      draw_rim_glow(draw_x, draw_y, visual.w, visual.h, palette.select or { 0.95, 0.33, 1.0, 1.0 }, 1.0, 2)
    elseif is_hovered then
      draw_rim_glow(draw_x, draw_y, visual.w, visual.h, palette.accent_alt or { 0.21, 0.92, 0.97, 1.0 }, 1.0, 2)
    end
  end
end

local function draw_jokers(ctx, jokers_area, details_area, shop_area)
  local palette = ctx.palette
  draw_panel(ctx, jokers_area.x, jokers_area.y, jokers_area.w, jokers_area.h, "base")
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(ctx.fonts.small)
  love.graphics.print("JOKERS", jokers_area.x + 10, jokers_area.y + 8)

  local start_x = jokers_area.x + 10
  local start_y = jokers_area.y + 32
  local gap = 8
  local cols = 2
  local available_w = jokers_area.w - 20
  local w = math.floor((available_w - gap) * 0.5)
  w = math.max(72, math.min(96, w))
  local h = w + 8
  local mx = ctx.mouse_x or -9999
  local my = ctx.mouse_y or -9999
  local icon_sheet = get_joker_icon_sheet(ctx)
  local icon_cols, icon_rows = 4, 3
  local focus_joker = nil

  for i, joker_key in ipairs(ctx.state.jokers) do
    local joker = ctx.game.JOKERS[joker_key]
    if joker then
      local col = (i - 1) % cols
      local row = math.floor((i - 1) / cols)
      local x = start_x + col * (w + gap)
      local y = start_y + row * (h + gap)
      if y + h > (jokers_area.y + jokers_area.h - 10) then
        break
      end
      local hovered = (mx >= x and mx <= x + w and my >= y and my <= y + h)
      local card_x = x
      local card_y = y
      local card_w = w
      local card_h = h
      if hovered then
        focus_joker = joker
      elseif not focus_joker then
        focus_joker = joker
      end

      local rarity_color = palette.border
      if joker.rarity == "uncommon" then
        rarity_color = palette.accent
      elseif joker.rarity == "rare" then
        rarity_color = { 0.73, 1.0, 0.25, 1.0 }
      end

      draw_panel(ctx, card_x, card_y, card_w, card_h, "base")
      if hovered then
        draw_rim_glow(card_x, card_y, card_w, card_h, palette.accent_alt or { 0.21, 0.92, 0.97, 1.0 }, 1.0, 2)
      end
      if joker.rarity ~= "common" then
        draw_rim_glow(card_x, card_y, card_w, card_h, rarity_color, 1.0, 2)
      end

      local icon_x = card_x + 8
      local icon_size = math.floor(w * 0.62)
      local icon_y = card_y + 8
      icon_x = card_x + math.floor((w - icon_size) * 0.5)
      if icon_sheet then
        local icon_index = joker.sprite_index or i
        local quad, meta = get_icon_quad(icon_sheet, icon_index, icon_cols, icon_rows)
        love.graphics.setColor(1, 1, 1, 0.96)
        love.graphics.draw(icon_sheet, quad, icon_x, icon_y, 0, icon_size / meta.frame_w, icon_size / meta.frame_h)
      else
        love.graphics.setColor(palette.border[1], palette.border[2], palette.border[3], 0.45)
        love.graphics.rectangle("fill", icon_x, icon_y, icon_size, icon_size, 8, 8)
      end

      love.graphics.setColor(palette.text)
      love.graphics.setFont(ctx.fonts.small)
      love.graphics.printf(joker.name, card_x + 4, card_y + h - 20, card_w - 8, "center")
    end
  end

  draw_panel(ctx, details_area.x, details_area.y, details_area.w, details_area.h, "base")
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(ctx.fonts.small)
  love.graphics.print("DETAILS", details_area.x + 10, details_area.y + 8)
  if focus_joker then
    love.graphics.setColor(palette.text)
    love.graphics.setFont(ctx.fonts.body)
    love.graphics.print(focus_joker.name, details_area.x + 10, details_area.y + 28)
    love.graphics.setFont(ctx.fonts.small)
    love.graphics.setColor(palette.muted)
    love.graphics.printf(focus_joker.formula or "", details_area.x + 10, details_area.y + 50, details_area.w - 20, "left")
    love.graphics.setColor(palette.accent)
    love.graphics.print((focus_joker.rarity or "common"):upper(), details_area.x + 10, details_area.y + details_area.h - 22)
  else
    love.graphics.setColor(palette.muted)
    love.graphics.setFont(ctx.fonts.small)
    love.graphics.print("No jokers yet.", details_area.x + 10, details_area.y + 34)
  end

  draw_panel(ctx, shop_area.x, shop_area.y, shop_area.w, shop_area.h, "base")
  love.graphics.setColor(palette.muted)
  love.graphics.setFont(ctx.fonts.small)
  love.graphics.print("SHOP", shop_area.x + 10, shop_area.y + 8)
  love.graphics.setColor(palette.text)
  love.graphics.print(("Credits: $%d"):format(ctx.state.money or 0), shop_area.x + 10, shop_area.y + 28)
  if ctx.state.shop and ctx.state.shop.active then
    love.graphics.setColor(palette.accent)
    love.graphics.print("Shop open [1/2/3,E,C]", shop_area.x + 10, shop_area.y + 48)
  else
    love.graphics.setColor(palette.muted)
    love.graphics.print("Shop appears after blind clear.", shop_area.x + 10, shop_area.y + 48)
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
  local layout = build_battle_layout()
  draw_vapor_background(ctx)

  local divider = VISUAL_PROFILE.use_dividers and ctx.get_image("assets/ui/divider ornaments.png")
  if divider then
    love.graphics.setColor(1, 1, 1, 0.55)
    love.graphics.draw(divider, 20, 170, 0, 920 / divider:getWidth(), 28 / divider:getHeight())
    love.graphics.draw(divider, 20, 612, 0, 920 / divider:getWidth(), 28 / divider:getHeight())
  end

  draw_top_stats(ctx, layout)
  draw_left_sidebar(ctx, layout)
  draw_center_lane(ctx, layout)
  draw_hand(ctx, layout.center.hand)

  draw_panel(ctx, layout.center.actions.x, layout.center.actions.y, layout.center.actions.w, layout.center.actions.h, "base")
  for _, button in ipairs(ctx.buttons) do
    if button.group == "center_actions" then
      draw_button(ctx, button)
    end
  end
  for _, button in ipairs(ctx.buttons) do
    if button.group == "tools" then
      draw_button(ctx, button)
    end
  end

  draw_pressure(ctx, layout.center.pressure)
  draw_preview(ctx, ctx.projection, layout.center.preview)
  draw_message(ctx, layout.center.message)
  draw_jokers(ctx, layout.right.jokers, layout.right.details, layout.right.shop)
  draw_run_result(ctx)
  draw_seed_prompt(ctx)
  draw_shop_modal(ctx)

  love.graphics.setColor(ctx.palette.muted)
  love.graphics.setFont(ctx.fonts.small)
  love.graphics.print("Controls:", layout.left.tools.x + 10, layout.left.tools.y + layout.left.tools.h - 40)
  love.graphics.print("1..8 select  SPACE play", layout.left.tools.x + 10, layout.left.tools.y + layout.left.tools.h - 26)
  love.graphics.print("D discard  R run  K/G seed", layout.left.tools.x + 10, layout.left.tools.y + layout.left.tools.h - 14)

  if ctx.state.message == "" then
    love.graphics.setColor(ctx.palette.muted)
    love.graphics.setFont(ctx.fonts.small)
    love.graphics.printf(
      "Select up to 5 cards and play a poker hand.",
      layout.center.message.x + 12,
      layout.center.message.y + 8,
      layout.center.message.w - 24,
      "center"
    )
  end
end

return Render
