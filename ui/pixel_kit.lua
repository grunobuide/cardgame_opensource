local PixelKit = {}

local function rgba(color, alpha_override)
  local c = color or { 1, 1, 1, 1 }
  return c[1] or 1, c[2] or 1, c[3] or 1, alpha_override or c[4] or 1
end

local function clamp(value, min_value, max_value)
  if value < min_value then
    return min_value
  end
  if value > max_value then
    return max_value
  end
  return value
end

local function rect_border(x, y, w, h, width, color)
  local bw = math.max(1, width or 2)
  love.graphics.setColor(rgba(color))
  love.graphics.rectangle("fill", x, y, w, bw)
  love.graphics.rectangle("fill", x, y + h - bw, w, bw)
  love.graphics.rectangle("fill", x, y + bw, bw, h - (bw * 2))
  love.graphics.rectangle("fill", x + w - bw, y + bw, bw, h - (bw * 2))
end

local function clipped_label(font, text, max_w)
  local value = tostring(text or "")
  if max_w <= 0 or font:getWidth(value) <= max_w then
    return value
  end
  local clipped = value
  while #clipped > 0 and font:getWidth(clipped .. "...") > max_w do
    clipped = clipped:sub(1, -2)
  end
  if clipped == "" then
    return ""
  end
  return clipped .. "..."
end

function PixelKit.outline(x, y, w, h, color, width)
  rect_border(x, y, w, h, width or 2, color or { 1, 1, 1, 1 })
end

function PixelKit.draw_panel(x, y, w, h, opts)
  opts = opts or {}
  local border_width = opts.border_width or 2
  local shadow = opts.shadow == nil and 4 or opts.shadow
  local fill = opts.fill or { 0.12, 0.08, 0.22, 1.0 }
  local border = opts.border or { 0.0, 0.90, 1.0, 1.0 }
  local shadow_color = opts.shadow_color or { 0.0, 0.0, 0.0, 0.75 }

  if shadow > 0 then
    love.graphics.setColor(rgba(shadow_color))
    love.graphics.rectangle("fill", x + shadow, y + shadow, w, h)
  end

  love.graphics.setColor(rgba(fill))
  love.graphics.rectangle("fill", x, y, w, h)
  rect_border(x, y, w, h, border_width, border)

  if opts.title and opts.fonts then
    local title_font = opts.title_font or opts.fonts.small or opts.fonts.ui
    local title_color = opts.title_color or border
    local title_padding = opts.title_padding or 12
    love.graphics.setColor(rgba(title_color))
    love.graphics.setFont(title_font)
    love.graphics.print(tostring(opts.title), x + title_padding, y + 8)
  end
end

function PixelKit.draw_button(x, y, w, h, state, label, opts)
  opts = opts or {}
  local current_state = state or "normal"
  local fonts = opts.fonts or {}
  local palette = opts.palette or {}

  local states = opts.states or {
    normal = {
      fill = palette.panel_alt or { 0.16, 0.11, 0.30, 1.0 },
      border = palette.border or { 0.0, 0.90, 1.0, 1.0 },
      text = palette.text or { 0.96, 0.96, 1.0, 1.0 },
    },
    hover = {
      fill = palette.panel or { 0.18, 0.13, 0.35, 1.0 },
      border = palette.accent_alt or palette.border or { 0.0, 0.90, 1.0, 1.0 },
      text = palette.text or { 0.96, 0.96, 1.0, 1.0 },
    },
    active = {
      fill = palette.accent or { 1.0, 0.18, 0.82, 1.0 },
      border = palette.accent or { 1.0, 0.18, 0.82, 1.0 },
      text = opts.active_text or { 0.08, 0.03, 0.12, 1.0 },
    },
    disabled = {
      fill = { 0.20, 0.18, 0.28, 1.0 },
      border = { 0.36, 0.34, 0.44, 1.0 },
      text = { 0.64, 0.64, 0.72, 1.0 },
    },
  }

  local visual = states[current_state] or states.normal
  PixelKit.draw_panel(x, y, w, h, {
    fill = visual.fill,
    border = visual.border,
    border_width = 2,
    shadow = opts.shadow == nil and 4 or opts.shadow,
    shadow_color = opts.shadow_color,
  })

  if current_state == "hover" or current_state == "active" then
    local neon = opts.neon_color or visual.border
    PixelKit.outline(x - 1, y - 1, w + 2, h + 2, { neon[1], neon[2], neon[3], 0.9 }, 1)
  end

  local key_hint = opts.key_hint and tostring(opts.key_hint) or ""
  local compact_font = fonts.small or fonts.ui or fonts.medium
  local font = opts.font or ((h <= 30) and compact_font or (fonts.ui or fonts.medium or fonts.small))
  local small = fonts.small or font
  local text = tostring(label or "")

  if key_hint ~= "" and h >= 28 then
    local badge_w = 40
    PixelKit.draw_panel(x + w - badge_w - 8, y + 8, badge_w, h - 16, {
      fill = { 0.08, 0.06, 0.16, 1.0 },
      border = visual.border,
      border_width = 2,
      shadow = 0,
    })
    love.graphics.setFont(small)
    love.graphics.setColor(rgba(visual.text))
    love.graphics.printf(key_hint, x + w - badge_w - 8, y + math.floor((h - small:getHeight()) * 0.5), badge_w, "center")
    text = clipped_label(font, text, w - badge_w - 28)
    love.graphics.setFont(font)
    love.graphics.setColor(rgba(visual.text))
    love.graphics.printf(text, x + 12, y + math.floor((h - font:getHeight()) * 0.5), w - badge_w - 22, "left")
    return
  end

  if key_hint ~= "" then
    text = ("%s (%s)"):format(text, key_hint)
  end

  text = clipped_label(font, text, w - 20)
  love.graphics.setFont(font)
  love.graphics.setColor(rgba(visual.text))
  love.graphics.printf(text, x + 10, y + math.floor((h - font:getHeight()) * 0.5), w - 20, "center")
end

function PixelKit.draw_progress_segmented(x, y, w, h, value, max_value, opts)
  opts = opts or {}
  local max_v = math.max(1, tonumber(max_value) or 1)
  local val = clamp(tonumber(value) or 0, 0, max_v)
  local ratio = val / max_v
  local segments = math.max(4, opts.segments or 20)
  local gap = opts.gap == nil and 2 or opts.gap
  local fill = opts.fill or { 0.447, 1.0, 0.353, 1.0 }
  local empty = opts.empty or { 0.15, 0.10, 0.28, 1.0 }
  local track = opts.track_fill or { 0.08, 0.06, 0.16, 1.0 }
  local border = opts.border or { 0.0, 0.90, 1.0, 1.0 }

  PixelKit.draw_panel(x, y, w, h, {
    fill = track,
    border = border,
    border_width = 2,
    shadow = opts.shadow == nil and 4 or opts.shadow,
  })

  local inner_x = x + 8
  local inner_y = y + 8
  local inner_w = math.max(1, w - 16)
  local inner_h = math.max(1, h - 16)
  local seg_w = math.max(1, math.floor((inner_w - ((segments - 1) * gap)) / segments))
  local filled = math.floor((ratio * segments) + 0.0001)

  for i = 1, segments do
    local sx = inner_x + ((i - 1) * (seg_w + gap))
    if i <= filled then
      love.graphics.setColor(rgba(fill))
    else
      love.graphics.setColor(rgba(empty))
    end
    love.graphics.rectangle("fill", sx, inner_y, seg_w, inner_h)
  end
end

-- Compatibility wrappers while UI migrates to the explicit component API.
function PixelKit.panel(x, y, w, h, opts)
  PixelKit.draw_panel(x, y, w, h, opts)
end

function PixelKit.badge(x, y, w, h, text, fonts, opts)
  opts = opts or {}
  PixelKit.draw_panel(x, y, w, h, {
    fill = opts.fill or { 0.08, 0.06, 0.16, 1.0 },
    border = opts.border or { 0.0, 0.90, 1.0, 1.0 },
    border_width = 2,
    shadow = opts.shadow == nil and 2 or opts.shadow,
  })
  local font = opts.font or fonts.small or fonts.ui or fonts.medium
  local label = clipped_label(font, text or "", w - 8)
  love.graphics.setColor(rgba(opts.text_color or { 1, 1, 1, 1 }))
  love.graphics.setFont(font)
  love.graphics.print(label, x + math.floor((w - font:getWidth(label)) * 0.5), y + math.floor((h - font:getHeight()) * 0.5))
end

function PixelKit.slot(x, y, w, h, opts)
  PixelKit.draw_panel(x, y, w, h, opts)
end

function PixelKit.bar(x, y, w, h, ratio, opts)
  opts = opts or {}
  PixelKit.draw_progress_segmented(x, y, w, h, ratio or 0, 1, opts)
end

function PixelKit.button(button, palette, fonts, opts)
  opts = opts or {}
  local tier = button.tier or "utility"
  local state = "normal"
  if opts.disabled then
    state = "disabled"
  elseif opts.active then
    state = "active"
  elseif opts.hovered then
    state = "hover"
  end

  local states = {
    normal = {
      fill = palette.panel_alt,
      border = palette.border,
      text = palette.text,
    },
    hover = {
      fill = { palette.panel_alt[1] + 0.04, palette.panel_alt[2] + 0.04, palette.panel_alt[3] + 0.04, 1.0 },
      border = palette.accent_alt,
      text = palette.text,
    },
    active = {
      fill = palette.accent,
      border = palette.accent,
      text = { 0.08, 0.03, 0.12, 1.0 },
    },
    disabled = {
      fill = { 0.20, 0.18, 0.28, 1.0 },
      border = { 0.36, 0.34, 0.44, 1.0 },
      text = { 0.64, 0.64, 0.72, 1.0 },
    },
  }

  if tier == "primary" then
    states.normal.fill = { 0.78, 0.22, 0.68, 1.0 }
    states.normal.border = palette.accent
    states.normal.text = { 0.08, 0.03, 0.12, 1.0 }
    states.hover.fill = palette.accent
    states.hover.border = palette.accent
    states.hover.text = { 0.08, 0.03, 0.12, 1.0 }
  elseif tier == "secondary" then
    states.normal.fill = { 0.12, 0.14, 0.34, 1.0 }
    states.normal.border = palette.accent_alt
    states.hover.fill = { 0.16, 0.18, 0.38, 1.0 }
    states.hover.border = palette.accent_alt
  end

  PixelKit.draw_button(button.x, button.y, button.w, button.h, state, button.label, {
    fonts = fonts,
    palette = palette,
    key_hint = button.key_hint,
    states = states,
    neon_color = tier == "primary" and palette.accent or palette.accent_alt,
  })
end

return PixelKit
