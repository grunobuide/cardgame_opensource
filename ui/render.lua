local Layout = require("ui.layout")
local PixelKit = require("ui.pixel_kit")
local Assets = require("ui.asset_loader")

local Render = {}
local icon_quads_cache = {}
local action_tooltips = {
  play = "Play selected cards and score the hand type.",
  discard = "Discard selected cards to draw new ones.",
  new_run = "Reset run state with a fresh seed/deck.",
  sort_suit = "Sort current hand by suit groups.",
  sort_rank = "Sort current hand by ascending rank.",
  add_joker = "Add a random joker to test interactions.",
  royal = "Debug helper: set hand to royal flush.",
}

local function clamp(value, min_v, max_v)
  if value < min_v then
    return min_v
  end
  if value > max_v then
    return max_v
  end
  return value
end

local function with_alpha(color, alpha)
  return { color[1], color[2], color[3], alpha }
end

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

local function severity_color(ctx, severity)
  local palette = ctx.palette
  if severity == "danger" or severity == "error" then
    return palette.danger
  end
  if severity == "warn" then
    return palette.warn
  end
  if severity == "ok" or severity == "success" then
    return palette.ok
  end
  return palette.muted
end

local function stage_alpha(time_value, start_t, duration)
  local t = (time_value - start_t) / math.max(0.001, duration)
  return clamp(t, 0, 1)
end

local function panel_transition(ctx, order)
  local intro = ctx.ui_panel_intro or 1
  if ctx.reduced_motion then
    intro = 1
  end
  local delay = (order - 1) * 0.08
  local denom = math.max(0.001, 1 - delay)
  local stage = clamp((intro - delay) / denom, 0, 1)
  local y_offset = 0
  local alpha = 0.6 + (stage * 0.4)
  return y_offset, alpha
end

local function shifted_rect(rect, y_offset)
  return {
    x = rect.x,
    y = rect.y + (y_offset or 0),
    w = rect.w,
    h = rect.h,
  }
end

local function short_number(value)
  local n = tonumber(value) or 0
  if n >= 1000000 then
    return ("%.1fM"):format(n / 1000000)
  end
  if n >= 1000 then
    return ("%.1fK"):format(n / 1000)
  end
  return tostring(math.floor(n))
end

local function draw_metric_block(ctx, x, y, w, h, title, value, opts)
  opts = opts or {}
  local palette = ctx.palette
  local fonts = ctx.fonts
  local border = opts.border or palette.border
  local fill = opts.fill or { 0.08, 0.06, 0.16, 1.0 }

  PixelKit.draw_panel(x, y, w, h, {
    asset = "stat_block",
    fill = fill,
    border = border,
    border_width = 2,
    shadow = 2,
  })

  -- Draw stat icon if available (left-aligned before title)
  local icon_name = opts.icon
  local text_x = x + 8
  if icon_name then
    local icon_img = Assets.icon(icon_name)
    if icon_img then
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(icon_img, x + 6, y + 4)
      text_x = x + 24
    end
  end

  love.graphics.setColor(opts.title_color or palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.print(tostring(title or ""), text_x, y + 4)

  love.graphics.setColor(opts.value_color or palette.text)
  love.graphics.setFont(opts.value_font or fonts.ui)
  love.graphics.printf(tostring(value or ""), x + 8, y + math.floor((h - fonts.ui:getHeight()) * 0.5), w - 16, "left")
end

local function blind_special_rule(blind)
  local bid = blind and blind.id or ""
  if bid == "small" then
    return "Rule: Baseline blind."
  end
  if bid == "big" then
    return "Rule: Elevated target multiplier."
  end
  if bid == "boss" then
    return "Rule: Highest blind pressure this ante."
  end
  return "Rule: Standard blind."
end

local function urgency_state(ctx, projection)
  local state = ctx.state
  local target = ctx.game.current_target(state)
  local score_ratio = clamp(state.score / math.max(1, target), 0, 1)
  local projected_ratio = score_ratio
  if projection and projection.total then
    projected_ratio = clamp((state.score + projection.total) / math.max(1, target), 0, 1)
  end

  local low_hands = (state.hands or 0) <= 1
  local low_discards = (state.discards or 0) <= 0
  local near_bust = low_hands and projected_ratio < 1.0
  return {
    score_ratio = score_ratio,
    projected_ratio = projected_ratio,
    low_hands = low_hands,
    low_discards = low_discards,
    near_bust = near_bust,
  }
end

local function draw_tooltip(ctx, tooltip)
  if not tooltip then
    return
  end

  local fonts = ctx.fonts
  local palette = ctx.palette
  local lines = tooltip.lines or {}
  local title = tostring(tooltip.title or "")
  local width = 200

  if title ~= "" then
    width = math.max(width, fonts.small:getWidth(title) + 22)
  end
  for _, line in ipairs(lines) do
    width = math.max(width, fonts.small:getWidth(tostring(line)) + 22)
  end

  local height = 18 + (#lines * 18) + 10
  local mx = math.floor((ctx.mouse_x or 0) + 16)
  local my = math.floor((ctx.mouse_y or 0) + 12)
  local max_x = love.graphics.getWidth() - width - 8
  local max_y = love.graphics.getHeight() - height - 8
  local x = math.max(8, math.min(mx, max_x))
  local y = math.max(8, math.min(my, max_y))

  PixelKit.draw_panel(x, y, width, height, {
    asset = "panel_tooltip",
    fill = { 0.07, 0.05, 0.15, 0.98 },
    border = palette.accent_alt,
    border_width = 2,
    shadow = 4,
  })

  local row_y = y + 8
  if title ~= "" then
    love.graphics.setColor(palette.text)
    love.graphics.setFont(fonts.small)
    love.graphics.print(title, x + 10, row_y)
    row_y = row_y + 18
  end

  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  for _, line in ipairs(lines) do
    love.graphics.print(tostring(line), x + 10, row_y)
    row_y = row_y + 18
  end
end

local function draw_major_event_effect(ctx)
  if ctx.reduced_motion then
    return
  end
  if not (ctx.ui_state and ctx.ui_state.get_major_fx) then
    return
  end

  local fx = ctx.ui_state:get_major_fx()
  if not fx then
    return
  end

  local now = love.timer.getTime()
  local remaining = math.max(0, (fx.expires_at or now) - now)
  local alpha = clamp(remaining / 0.95, 0, 1) * 0.14
  local color = severity_color(ctx, fx.severity)
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  love.graphics.setColor(color[1], color[2], color[3], alpha)
  love.graphics.rectangle("fill", 0, 0, w, h)

  if fx.kind == "victory" then
    love.graphics.setColor(ctx.palette.ok[1], ctx.palette.ok[2], ctx.palette.ok[3], alpha * 0.8)
    for y = 0, h, 18 do
      love.graphics.rectangle("fill", 0, y, w, 2)
    end
  elseif fx.kind == "danger" then
    love.graphics.setColor(ctx.palette.accent[1], ctx.palette.accent[2], ctx.palette.accent[3], alpha * 0.9)
    love.graphics.rectangle("fill", 0, 0, w, 10)
    love.graphics.rectangle("fill", 0, h - 10, w, 10)
  end
end

local function draw_event_banner(ctx, top_area)
  if not (ctx.ui_state and ctx.ui_state.get_active_banner) then
    return
  end

  local banner = ctx.ui_state:get_active_banner()
  if not banner or banner.text == "" then
    return
  end

  local fonts = ctx.fonts
  local border = severity_color(ctx, banner.severity)
  local text = tostring(banner.text)
  local width = clamp(fonts.ui:getWidth(text) + 40, 260, 820)
  local height = 36
  local x = math.floor((love.graphics.getWidth() - width) * 0.5)
  local y = top_area.y + top_area.h + 8

  PixelKit.draw_panel(x, y, width, height, {
    fill = { 0.07, 0.05, 0.14, 0.95 },
    border = border,
    border_width = 2,
    shadow = 4,
  })

  love.graphics.setColor(border)
  love.graphics.setFont(fonts.ui)
  love.graphics.printf(text, x + 10, y + math.floor((height - fonts.ui:getHeight()) * 0.5), width - 20, "center")
end

local function draw_background(ctx)
  local palette = ctx.palette
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()

  -- Try tileable background image
  local bg_key = Assets.bg_key_for_state(ctx.state)
  local bg_img = Assets.image(bg_key) or Assets.image("bg_felt")
  if bg_img then
    bg_img:setWrap("repeat", "repeat")
    local quad = love.graphics.newQuad(0, 0, w, h, bg_img:getWidth(), bg_img:getHeight())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bg_img, quad, 0, 0)
    return
  end

  -- Fallback: procedural gradient + grid
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

local function draw_header(ctx, header, panel_alpha)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local state = ctx.state
  local game = ctx.game
  local blind = game.current_blind(state)
  local urgent = urgency_state(ctx, ctx.projection)

  PixelKit.draw_panel(header.x, header.y, header.w, header.h, {
    asset = "panel_primary",
    fill = with_alpha(palette.panel, panel_alpha or 1),
    border = with_alpha(palette.border, panel_alpha or 1),
    border_width = 2,
    shadow = 4,
    alpha = panel_alpha or 1,
  })

  local logo = ctx.get_image("assets/game_logo.png")
  local left = header.x + 12
  if logo then
    draw_image_contain(logo, header.x + 8, header.y + 8, 72, header.h - 16, panel_alpha or 1)
    left = header.x + 84
  end

  love.graphics.setColor(palette.text[1], palette.text[2], palette.text[3], panel_alpha or 1)
  love.graphics.setFont(fonts.ui)
  love.graphics.print("ALIEN VAPOR TABLE", left, header.y + 10)

  love.graphics.setColor(palette.muted[1], palette.muted[2], palette.muted[3], panel_alpha or 1)
  love.graphics.setFont(fonts.small)
  love.graphics.print(("A%d  %s"):format(state.ante or 1, blind.label or "Blind"), left, header.y + 40)

  local metrics = {
    { title = "TARGET", value = short_number(game.current_target(state)), border = palette.border, value_color = palette.text, icon = "target" },
    { title = "SCORE", value = short_number(state.score), border = palette.accent_alt, value_color = palette.text, icon = "score" },
    {
      title = "HANDS",
      value = tostring(state.hands or 0),
      border = urgent.low_hands and palette.warn or palette.ok,
      value_color = urgent.low_hands and palette.warn or palette.text,
      icon = "hand",
    },
    {
      title = "DISCARDS",
      value = tostring(state.discards or 0),
      border = urgent.low_discards and palette.warn or palette.border,
      value_color = urgent.low_discards and palette.warn or palette.text,
      icon = "discard",
    },
    { title = "CREDITS", value = ("$%d"):format(state.money or 0), border = palette.ok, value_color = palette.text, icon = "coin" },
  }

  local gap = 8
  local available_w = header.x + header.w - left - 12
  local block_w = math.floor((available_w - (gap * (#metrics - 1))) / #metrics)
  block_w = math.max(80, block_w)
  local block_h = header.h - 16
  local mx = header.x + header.w - ((block_w * #metrics) + (gap * (#metrics - 1))) - 12
  local my = header.y + 8

  for i, metric in ipairs(metrics) do
    local bx = mx + ((i - 1) * (block_w + gap))
    draw_metric_block(ctx, bx, my, block_w, block_h, metric.title, metric.value, {
      border = with_alpha(metric.border, panel_alpha or 1),
      value_color = with_alpha(metric.value_color, panel_alpha or 1),
      title_color = with_alpha(palette.muted, panel_alpha or 1),
      fill = { 0.07, 0.05, 0.15, 1.0 },
      icon = metric.icon,
    })
  end
end

local function draw_feedback(ctx, area, panel_alpha)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local game = ctx.game
  local state = ctx.state
  local projection = ctx.projection
  local blind = game.current_blind(state)
  local urgent = urgency_state(ctx, projection)
  local now = love.timer.getTime()
  local target = game.current_target(state)
  local ratio = urgent.score_ratio
  local pulse = 0.78 + (math.sin(now * 8.5) * 0.22)
  local outer_border = urgent.near_bust and palette.warn or palette.border

  PixelKit.draw_panel(area.x, area.y, area.w, area.h, {
    asset = "panel_secondary",
    fill = with_alpha(palette.panel_alt, panel_alpha or 1),
    border = with_alpha(outer_border, panel_alpha or 1),
    border_width = 2,
    shadow = 4,
    alpha = panel_alpha or 1,
    title = "FEEDBACK",
    fonts = fonts,
    title_font = fonts.small,
  })

  local compact_feedback = area.h <= 96
  local pad = 16
  local bar_x = area.x + pad
  local bar_y = area.y + 24
  local bar_w = math.floor(area.w * 0.46)
  local bar_h = compact_feedback and 28 or 30
  local info_x = bar_x + bar_w + 20
  local info_w = area.x + area.w - info_x - 16

  local bar_fill = palette.ok
  if ratio >= 0.90 then
    bar_fill = { palette.accent[1], palette.accent[2], palette.accent[3], pulse }
  elseif urgent.near_bust then
    bar_fill = { palette.warn[1], palette.warn[2], palette.warn[3], 1.0 }
  elseif ratio >= 0.75 then
    bar_fill = {
      (palette.ok[1] * 0.5) + (palette.accent[1] * 0.5),
      (palette.ok[2] * 0.5) + (palette.accent[2] * 0.5),
      (palette.ok[3] * 0.5) + (palette.accent[3] * 0.5),
      1.0,
    }
  end

  PixelKit.draw_progress_segmented(bar_x, bar_y, bar_w, bar_h, state.score, target, {
    segments = 20,
    gap = 2,
    fill = bar_fill,
    empty = { 0.14, 0.10, 0.26, 1.0 },
    border = palette.border,
    shadow = 0,
  })

  local inner_x = bar_x + 8
  local inner_w = bar_w - 16
  for _, threshold in ipairs({ 0.5, 0.75, 1.0 }) do
    local tx = inner_x + math.floor(inner_w * threshold)
    local t_alpha = threshold >= 1.0 and 0.92 or 0.55
    love.graphics.setColor(palette.border[1], palette.border[2], palette.border[3], t_alpha)
    love.graphics.rectangle("fill", tx, bar_y + 5, 2, bar_h - 10)
  end

  love.graphics.setColor(palette.muted)
  love.graphics.setFont(fonts.small)
  love.graphics.print("BLIND PRESSURE", bar_x + 10, bar_y + 8)
  love.graphics.printf(
    ("%d / %d"):format(state.score, target),
    bar_x,
    bar_y + 8,
    bar_w - 10,
    "right"
  )

  local preview_y = bar_y - 2
  local preview_h = 40
  PixelKit.draw_panel(info_x, preview_y, info_w, preview_h, {
    fill = { 0.08, 0.06, 0.16, 1.0 },
    border = urgent.near_bust and palette.warn or palette.border,
    border_width = 2,
    shadow = 0,
  })
  local base_label = projection and projection.hand_type and projection.hand_type.label or "No Hand Selected"
  local projected_total = projection and projection.total or 0

  love.graphics.setColor(palette.muted[1], palette.muted[2], palette.muted[3], panel_alpha or 1)
  love.graphics.setFont(fonts.small)
  love.graphics.print("PREVIEW", info_x + 8, area.y + 16)
  love.graphics.setColor(palette.text[1], palette.text[2], palette.text[3], panel_alpha or 1)
  love.graphics.setFont(fonts.ui)
  love.graphics.print(clipped_text(fonts.ui, base_label, math.max(80, info_w - 236)), info_x + 92, area.y + 20)

  local proj_text = projected_total > 0 and ("PROJECTED +%d"):format(projected_total) or "PROJECTED +0"
  love.graphics.setColor(palette.accent[1], palette.accent[2], palette.accent[3], panel_alpha or 1)
  love.graphics.setFont(fonts.ui)
  love.graphics.printf(proj_text, info_x + 8, area.y + 20, info_w - 16, "right")

  local blind_y = preview_y + preview_h + 4
  local blind_h = math.max(20, (area.y + area.h) - blind_y - 8)
  PixelKit.draw_panel(info_x, blind_y, info_w, blind_h, {
    fill = { 0.07, 0.05, 0.15, 1.0 },
    border = palette.accent_alt,
    border_width = 2,
    shadow = 0,
  })
  local blind_rule = blind_special_rule(blind):gsub("^Rule:%s*", "")
  local blind_line = ("%s  |  Target %s  |  %s"):format(
    (blind.id or "small"):upper(),
    short_number(target),
    blind_rule
  )
  love.graphics.setColor(palette.muted[1], palette.muted[2], palette.muted[3], panel_alpha or 1)
  love.graphics.setFont(fonts.small)
  if blind_h >= 32 then
    love.graphics.print("BLIND CONTEXT", info_x + 8, blind_y + 4)
    love.graphics.setColor(palette.text[1], palette.text[2], palette.text[3], panel_alpha or 1)
    love.graphics.printf(clipped_text(fonts.small, blind_line, info_w - 16), info_x + 8, blind_y + 20, info_w - 16, "left")
  else
    love.graphics.setColor(palette.text[1], palette.text[2], palette.text[3], panel_alpha or 1)
    love.graphics.printf(clipped_text(fonts.small, blind_line, info_w - 16), info_x + 8, blind_y + math.floor((blind_h - fonts.small:getHeight()) * 0.5), info_w - 16, "left")
  end
  if urgent.near_bust and blind_h >= 46 then
    love.graphics.setColor(palette.warn[1], palette.warn[2], palette.warn[3], panel_alpha or 1)
    love.graphics.setFont(fonts.small)
    love.graphics.printf("Priority: low hands, score pressure high.", info_x + 8, blind_y + blind_h - 18, info_w - 16, "left")
  end

  local strip_x = area.x + 16
  local strip_w = bar_w

  if projection then
    local base_total = projection.base_chips * projection.base_mult
    local joker_chips = projection.total_chips - projection.base_chips
    local joker_mult = projection.total_mult - projection.base_mult
    local delta_total = projection.total - base_total
    local formula = ("(%d %+d) x (%d %+d) = %d"):format(
      projection.base_chips,
      joker_chips,
      projection.base_mult,
      joker_mult,
      projection.total
    )
    local sequenced_alpha = 1
    if not ctx.reduced_motion then
      local seq = now % 1.8
      sequenced_alpha = 0.55 + (stage_alpha(seq, 0.0, 0.28) * 0.45)
    end

    if compact_feedback then
      local compact_breakdown = ("Base %d  |  Jokers %+d  |  Total %d"):format(base_total, delta_total, projection.total)
      love.graphics.setColor(palette.muted[1], palette.muted[2], palette.muted[3], sequenced_alpha)
      love.graphics.setFont(fonts.small)
      love.graphics.printf(clipped_text(fonts.small, compact_breakdown, strip_w), strip_x, area.y + area.h - 18, strip_w, "left")
    else
      local strip_y = area.y + area.h - 30
      local strip_h = 22
      PixelKit.draw_panel(strip_x, strip_y, strip_w, strip_h, {
        fill = { 0.06, 0.05, 0.14, 1.0 },
        border = palette.border,
        border_width = 2,
        shadow = 0,
      })
      love.graphics.setColor(palette.muted[1], palette.muted[2], palette.muted[3], sequenced_alpha)
      love.graphics.setFont(fonts.small)
      love.graphics.printf(("BASE %d x %d = %d"):format(projection.base_chips, projection.base_mult, base_total), strip_x + 8, strip_y + 4, strip_w - 16, "left")
      love.graphics.setColor(palette.accent_alt[1], palette.accent_alt[2], palette.accent_alt[3], sequenced_alpha)
      love.graphics.printf(("JOKERS %+dC %+dM  %+d"):format(joker_chips, joker_mult, delta_total), strip_x + 132, strip_y + 4, strip_w - 16, "left")
      love.graphics.setColor(palette.accent[1], palette.accent[2], palette.accent[3], sequenced_alpha)
      love.graphics.printf(("TOTAL %d"):format(projection.total), strip_x + strip_w - 132, strip_y + 4, 124, "right")
      love.graphics.setColor(palette.text[1], palette.text[2], palette.text[3], sequenced_alpha)
      love.graphics.printf(clipped_text(fonts.small, formula, strip_w - 20), strip_x + 8, strip_y - 16, strip_w - 16, "left")
    end
  else
    love.graphics.setColor(palette.muted)
    love.graphics.setFont(fonts.small)
    if compact_feedback then
      love.graphics.printf("Breakdown: select cards for base -> jokers -> total", strip_x, area.y + area.h - 18, strip_w, "left")
    else
      local strip_y = area.y + area.h - 30
      local strip_h = 22
      PixelKit.draw_panel(strip_x, strip_y, strip_w, strip_h, {
        fill = { 0.06, 0.05, 0.14, 1.0 },
        border = palette.border,
        border_width = 2,
        shadow = 0,
      })
      love.graphics.printf("Breakdown: select cards to preview base -> jokers -> total", strip_x + 8, strip_y + 4, strip_w - 16, "center")
    end
  end
end

local function draw_hand(ctx, area, panel_alpha)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local state = ctx.state
  local mx = ctx.mouse_x or -9999
  local my = ctx.mouse_y or -9999

  PixelKit.draw_panel(area.x, area.y, area.w, area.h, {
    asset = "panel_primary",
    fill = with_alpha(palette.panel, panel_alpha or 1),
    border = with_alpha(palette.border, panel_alpha or 1),
    border_width = 2,
    shadow = 4,
    alpha = panel_alpha or 1,
    title = "HAND",
    fonts = fonts,
    title_font = fonts.small,
  })

  local select_glow = Assets.image("card_select_glow")
  local hover_glow = Assets.image("card_hover_glow")
  local hover_tooltip = nil
  for _, visual in ipairs(ctx.card_visuals) do
    local draw_x = visual.x
    local base_y = visual.y + visual.lift
    local card = visual.card
    local sprite = ctx.game.card_sprite_path(card, ctx.theme)
    local image = ctx.get_image(sprite)
    local selected = state.selected[visual.index] == true
    local hovered = (mx >= draw_x and mx <= draw_x + visual.w and my >= (base_y - 8) and my <= base_y + visual.h)
    local hover_lift = hovered and (selected and 2 or 6) or 0
    local draw_y = base_y - hover_lift
    local border = palette.border

    if selected then
      border = palette.accent
    elseif hovered then
      border = palette.accent_alt
    end

    -- Draw glow behind card if art available, else procedural border
    if selected and select_glow then
      local gw = visual.w + 20
      local gh = visual.h + 20
      love.graphics.setColor(1, 1, 1, 0.9 * visual.alpha)
      love.graphics.draw(select_glow, draw_x - 10, draw_y - 10, 0, gw / select_glow:getWidth(), gh / select_glow:getHeight())
    elseif hovered and not selected and hover_glow then
      local gw = visual.w + 16
      local gh = visual.h + 16
      love.graphics.setColor(1, 1, 1, 0.7 * visual.alpha)
      love.graphics.draw(hover_glow, draw_x - 8, draw_y - 8, 0, gw / hover_glow:getWidth(), gh / hover_glow:getHeight())
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
      if not select_glow then
        -- Fallback: procedural selection outline
        PixelKit.outline(draw_x - 1, draw_y - 1, visual.w + 2, visual.h + 2, { palette.accent[1], palette.accent[2], palette.accent[3], 0.90 }, 1)
        PixelKit.outline(draw_x + 2, draw_y + 2, visual.w - 4, visual.h - 4, { palette.accent_alt[1], palette.accent_alt[2], palette.accent_alt[3], 0.75 }, 1)
      end
      love.graphics.setColor(palette.accent)
      love.graphics.setFont(fonts.small)
      love.graphics.print("SEL", draw_x + 8, draw_y + 6)
    elseif hovered then
      if not hover_glow then
        PixelKit.outline(draw_x - 1, draw_y - 1, visual.w + 2, visual.h + 2, { palette.accent_alt[1], palette.accent_alt[2], palette.accent_alt[3], 0.80 }, 1)
      end
    end

    if hovered then
      local label = ctx.game.card_label and ctx.game.card_label(card) or (tostring(card.rank) .. tostring(card.suit))
      hover_tooltip = {
        title = ("CARD %d  %s"):format(visual.index, label),
        lines = {
          selected and "Selected for next action." or "Click to toggle selection.",
          ("Hotkey: %d"):format(visual.index),
        },
      }
    end
  end

  return hover_tooltip
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

local function draw_actions(ctx, area, panel_alpha)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local compact_actions = area.h <= 156
  local selected_count = ctx.game.selected_count(ctx.state)
  local message = resolve_message(ctx)
  local message_severity = ctx.ui_state and ctx.ui_state.message_severity or "info"
  local hover_tooltip = nil
  local min_tool_y = nil
  local max_center_bottom = area.y + 34
  local max_tool_bottom = nil
  if message == "" then
    message = "Select up to 5 cards, then PLAY."
  end

  PixelKit.draw_panel(area.x, area.y, area.w, area.h, {
    asset = "panel_secondary",
    fill = with_alpha(palette.panel_alt, panel_alpha or 1),
    border = with_alpha(palette.border, panel_alpha or 1),
    border_width = 2,
    shadow = 4,
    alpha = panel_alpha or 1,
    title = "ACTIONS",
    fonts = fonts,
    title_font = fonts.small,
  })

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(palette.muted)
  love.graphics.print("COMBAT", area.x + 16, area.y + 18)
  love.graphics.printf("Cards: 1..8  |  SPACE PLAY  |  D DISCARD", area.x + 16, area.y + 18, area.w - 32, "right")

  for _, button in ipairs(ctx.buttons) do
    if button.group == "center_actions" then
      local visual_state = button_state_for(ctx, button, selected_count)
      max_center_bottom = math.max(max_center_bottom, button.y + button.h)
      PixelKit.draw_button(button.x, button.y, button.w, button.h, visual_state, button.label, {
        fonts = fonts,
        palette = palette,
        key_hint = button.key_hint,
        tier = button.tier,
        neon_color = button.id == "play" and palette.accent or palette.accent_alt,
        states = button.tier == "primary" and {
          normal = { fill = { 0.78, 0.22, 0.68, 1.0 }, border = palette.accent, text = { 0.09, 0.03, 0.14, 1.0 } },
          hover = { fill = palette.accent, border = palette.accent, text = { 0.09, 0.03, 0.14, 1.0 } },
          active = { fill = palette.accent, border = palette.accent, text = { 0.09, 0.03, 0.14, 1.0 } },
          disabled = { fill = { 0.22, 0.18, 0.28, 1.0 }, border = { 0.38, 0.35, 0.46, 1.0 }, text = { 0.68, 0.68, 0.74, 1.0 } },
        } or nil,
      })
      if button.hovered then
        local tip_lines = {
          action_tooltips[button.id] or "Run action.",
          ("Hotkey: %s"):format(button.key_hint or "-"),
        }
        if visual_state == "disabled" then
          if button.id == "play" and selected_count == 0 then
            tip_lines[#tip_lines + 1] = "Requires at least 1 selected card."
          elseif button.id == "discard" and selected_count == 0 then
            tip_lines[#tip_lines + 1] = "Requires at least 1 selected card."
          elseif button.id == "play" and ctx.state.hands <= 0 then
            tip_lines[#tip_lines + 1] = "No hands left this ante."
          elseif button.id == "discard" and ctx.state.discards <= 0 then
            tip_lines[#tip_lines + 1] = "No discards left this ante."
          elseif ctx.state.shop and ctx.state.shop.active then
            tip_lines[#tip_lines + 1] = "Shop must be resolved first."
          end
        end
        hover_tooltip = {
          title = button.label,
          lines = tip_lines,
        }
      end
    end
  end

  for _, button in ipairs(ctx.buttons) do
    if button.group == "tools" then
      if not min_tool_y or button.y < min_tool_y then
        min_tool_y = button.y
      end
      max_tool_bottom = math.max(max_tool_bottom or 0, button.y + button.h)
      local visual_state = button_state_for(ctx, button, selected_count)
      PixelKit.draw_button(button.x, button.y, button.w, button.h, visual_state, button.label, {
        fonts = fonts,
        palette = palette,
        key_hint = button.key_hint,
        tier = button.tier or "utility",
        neon_color = button.id == "new_run" and palette.accent or palette.accent_alt,
        states = button.id == "new_run" and {
          normal = { fill = { 0.22, 0.11, 0.24, 1.0 }, border = palette.accent, text = palette.text },
          hover = { fill = { 0.31, 0.14, 0.32, 1.0 }, border = palette.accent, text = palette.text },
          active = { fill = palette.accent, border = palette.accent, text = { 0.09, 0.03, 0.14, 1.0 } },
          disabled = { fill = { 0.22, 0.18, 0.28, 1.0 }, border = { 0.38, 0.35, 0.46, 1.0 }, text = { 0.68, 0.68, 0.74, 1.0 } },
        } or nil,
      })
      if button.hovered then
        hover_tooltip = {
          title = button.label,
          lines = {
            action_tooltips[button.id] or "Run action.",
            ("Hotkey: %s"):format(button.key_hint or "-"),
          },
        }
      end
    end
  end

  local msg_baseline = area.y + area.h - 18
  local msg_y = msg_baseline
  if min_tool_y then
    local gap_above_tools = min_tool_y - max_center_bottom
    local band_h = fonts.small:getHeight()
    if (not compact_actions) and gap_above_tools >= (band_h + 3) then
      local section_y = min_tool_y - band_h - 2
      section_y = math.max(section_y, max_center_bottom + 1)
      love.graphics.setFont(fonts.small)
      love.graphics.setColor(palette.muted)
      love.graphics.print("DECK TOOLS", area.x + 16, section_y)
      love.graphics.printf("RUN / DEBUG", area.x + 16, section_y, area.w - 16, "right")
      love.graphics.setColor(palette.muted[1], palette.muted[2], palette.muted[3], 0.85)
      love.graphics.printf("F1 debug  |  F2 theme  |  F3 motion", area.x + 16, min_tool_y + 24, area.w - 24, "right")
    end
    if max_tool_bottom then
      msg_y = math.max(msg_y, max_tool_bottom + 2)
    end
  end
  local msg_max_y = area.y + area.h - fonts.small:getHeight() - 4
  msg_y = math.min(msg_y, msg_max_y)
  if msg_y >= (area.y + 42) and msg_y > max_center_bottom and (not max_tool_bottom or msg_y > max_tool_bottom) then
    love.graphics.setFont(fonts.small)
    love.graphics.setColor(severity_color(ctx, message_severity))
    love.graphics.printf(clipped_text(fonts.small, message, area.w - 40), area.x + 20, msg_y, area.w - 40, "center")
  end
  return hover_tooltip
end

local function draw_run_summary(ctx, area, panel_alpha)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local state = ctx.state
  local game = ctx.game
  local compact = area.h <= 78
  local urgent = urgency_state(ctx, ctx.projection)
  local blind = game.current_blind(state)
  local border = urgent.near_bust and palette.warn or palette.border

  PixelKit.draw_panel(area.x, area.y, area.w, area.h, {
    asset = "panel_inset",
    fill = with_alpha(palette.panel, panel_alpha or 1),
    border = with_alpha(border, panel_alpha or 1),
    border_width = 2,
    shadow = 4,
    alpha = panel_alpha or 1,
    title = "RUN SUMMARY",
    fonts = fonts,
    title_font = fonts.small,
  })

  local x = area.x + 10
  local y = area.y + 20
  local w = area.w - 20

  love.graphics.setFont(fonts.small)
  love.graphics.setColor(palette.muted[1], palette.muted[2], palette.muted[3], panel_alpha or 1)
  love.graphics.printf(("Ante A%d  |  Blind %s"):format(state.ante or 1, (blind.id or "small"):upper()), x, y, w, "left")
  y = y + 14
  if not compact then
    love.graphics.setColor(palette.text[1], palette.text[2], palette.text[3], panel_alpha or 1)
    love.graphics.printf(clipped_text(fonts.small, blind.label or "Blind", w), x, y, w, "left")
    y = y + 14
  end

  local econ = ("Jokers %d/%d   Deck %d   $%d"):format(
    #(state.jokers or {}),
    game.MAX_JOKERS or 5,
    #(state.deck_cards or {}),
    state.money or 0
  )
  love.graphics.setColor(palette.muted[1], palette.muted[2], palette.muted[3], panel_alpha or 1)
  love.graphics.printf(clipped_text(fonts.small, econ, w), x, y, w, "left")

  if urgent.low_hands or urgent.low_discards or urgent.near_bust then
    local urgency_text = "Priority: "
    if urgent.near_bust then
      urgency_text = urgency_text .. "near bust"
    elseif urgent.low_hands then
      urgency_text = urgency_text .. "low hands"
    else
      urgency_text = urgency_text .. "no discards"
    end
    love.graphics.setColor(palette.warn[1], palette.warn[2], palette.warn[3], panel_alpha or 1)
    love.graphics.printf(urgency_text, x, area.y + area.h - 16, w, "left")
  end
end

local function draw_joker_dock(ctx, area, panel_alpha)
  local palette = ctx.palette
  local fonts = ctx.fonts
  local icon_sheet = get_joker_icon_sheet(ctx)
  local compact = area.h <= 82
  local pad = 10
  local slots = ctx.game.MAX_JOKERS or 5
  local gap = 6
  local slot_w = math.floor((area.w - (pad * 2) - ((slots - 1) * gap)) / slots)
  local slot_h = math.max(32, area.h - (compact and 32 or 42))
  local start_x = area.x + pad
  local start_y = area.y + 24
  local mx = ctx.mouse_x or -9999
  local my = ctx.mouse_y or -9999
  local focus_text = "Hover a joker for details."
  local hover_tooltip = nil

  PixelKit.draw_panel(area.x, area.y, area.w, area.h, {
    asset = "panel_primary",
    fill = with_alpha(ctx.palette.panel, panel_alpha or 1),
    border = with_alpha(palette.border, panel_alpha or 1),
    border_width = 2,
    shadow = 4,
    alpha = panel_alpha or 1,
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
    local draw_y = hovered and (y - 3) or y
    local border = joker and (hovered and palette.accent or palette.border) or { palette.border[1], palette.border[2], palette.border[3], 0.45 }

    -- Determine joker frame asset by rarity
    local frame_asset = nil
    if joker then
      frame_asset = Assets.joker_frame_key(joker.rarity or "common")
    else
      frame_asset = "joker_slot_empty"
    end

    PixelKit.draw_panel(x, draw_y, slot_w, slot_h, {
      asset = frame_asset,
      fill = { 0.06, 0.05, 0.14, 1.0 },
      border = border,
      border_width = 2,
      shadow = 2,
      shadow_color = palette.shadow,
    })

    if joker then
      local icon_size = math.min(slot_w - 10, slot_h - 20)
      if icon_sheet then
        local index = joker.sprite_index or i
        local quad, meta = get_icon_quad(icon_sheet, index, 4, 3)
        draw_image_contain(icon_sheet, x + 5, draw_y + 4, icon_size, icon_size, 1.0, quad, meta.frame_w, meta.frame_h)
      else
        love.graphics.setColor(palette.border[1], palette.border[2], palette.border[3], 0.25)
        love.graphics.rectangle("fill", x + 5, draw_y + 4, icon_size, icon_size)
      end

      if not compact then
        local label = clipped_text(fonts.small, joker.name or joker_key, slot_w - 6)
        love.graphics.setColor(palette.text)
        love.graphics.setFont(fonts.small)
        love.graphics.printf(label, x + 3, draw_y + slot_h - 14, slot_w - 6, "center")
      end
      if hovered then
        focus_text = ("%s: %s"):format(joker.name or joker_key, joker.formula or "")
        hover_tooltip = {
          title = joker.name or joker_key,
          lines = {
            ("Rarity: %s"):format((joker.rarity or "common"):upper()),
            joker.formula or "",
          },
        }
      end
    else
      love.graphics.setColor(palette.muted)
      love.graphics.setFont(fonts.small)
      love.graphics.printf("--", x, draw_y + math.floor(slot_h * 0.5) - 8, slot_w, "center")
    end
  end

  if area.h >= 92 then
    love.graphics.setColor(palette.muted)
    love.graphics.setFont(fonts.small)
    love.graphics.printf(clipped_text(fonts.small, focus_text, area.w - 20), area.x + 10, area.y + area.h - 18, area.w - 20, "left")
  end
  return hover_tooltip
end

local function draw_seed_prompt(ctx)
  local overlay_alpha = (ctx.overlay_alpha and ctx.overlay_alpha.seed_prompt) or 0
  if overlay_alpha <= 0.001 then
    return
  end
  local palette = ctx.palette
  local fonts = ctx.fonts
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  local panel_w, panel_h = 760, 96
  local x = math.floor((w - panel_w) * 0.5)
  local y = math.floor((h - panel_h) * 0.5)

  PixelKit.draw_panel(x, y, panel_w, panel_h, {
    asset = "panel_highlight",
    fill = with_alpha(palette.panel_alt, overlay_alpha),
    border = with_alpha(palette.accent, overlay_alpha),
    border_width = 2,
    shadow = 4,
    alpha = overlay_alpha,
    title = "SEED ENTRY",
    fonts = fonts,
    title_font = fonts.small,
  })
  local shown_seed = ctx.seed_input_mode and ctx.seed_buffer or ((ctx.overlay_snapshots and ctx.overlay_snapshots.seed_buffer) or "")
  love.graphics.setColor(palette.text[1], palette.text[2], palette.text[3], overlay_alpha)
  love.graphics.setFont(fonts.small)
  love.graphics.printf("Type seed and press Enter. Esc cancels.", x + 16, y + 36, panel_w - 32, "left")
  love.graphics.setColor(palette.accent[1], palette.accent[2], palette.accent[3], overlay_alpha)
  love.graphics.printf(shown_seed .. "_", x + 16, y + 58, panel_w - 32, "left")
end

local function draw_run_result(ctx)
  local overlay_alpha = (ctx.overlay_alpha and ctx.overlay_alpha.run_result) or 0
  local result = ctx.run_result or (ctx.overlay_snapshots and ctx.overlay_snapshots.run_result) or nil
  if overlay_alpha <= 0.001 then
    return
  end
  if not result then
    return
  end

  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  love.graphics.setColor(0, 0, 0, 0.72 * overlay_alpha)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local panel_w = math.min(1040, w - 160)
  local panel_h = math.min(620, h - 120)
  local x = math.floor((w - panel_w) * 0.5)
  local y = math.floor((h - panel_h) * 0.5)

  PixelKit.draw_panel(x, y, panel_w, panel_h, {
    asset = "panel_result",
    fill = with_alpha(ctx.palette.panel, overlay_alpha),
    border = with_alpha(ctx.palette.accent, overlay_alpha),
    border_width = 2,
    shadow = 4,
    alpha = overlay_alpha,
  })

  -- Try header art for victory/defeat
  local header_key = result.won and "header_victory" or "header_defeat"
  local header_img = Assets.image(header_key)
  love.graphics.setFont(ctx.fonts.title)
  local title_color = result.won and ctx.palette.ok or ctx.palette.accent
  love.graphics.setColor(title_color[1], title_color[2], title_color[3], overlay_alpha)
  if header_img then
    local hsx = math.min((panel_w - 48) / header_img:getWidth(), 1)
    local hsy = hsx
    local hx = x + math.floor((panel_w - header_img:getWidth() * hsx) * 0.5)
    love.graphics.setColor(1, 1, 1, overlay_alpha)
    love.graphics.draw(header_img, hx, y + 12, 0, hsx, hsy)
  else
    love.graphics.printf(result.won and "RUN COMPLETE" or "RUN OVER", x, y + 18, panel_w, "center")
  end

  love.graphics.setFont(ctx.fonts.ui)
  love.graphics.setColor(ctx.palette.text[1], ctx.palette.text[2], ctx.palette.text[3], overlay_alpha)
  love.graphics.print(("Ante reached: %d"):format(result.ante_reached), x + 24, y + 70)
  love.graphics.print(("Final blind: %s"):format(result.blind_reached), x + 24, y + 96)
  love.graphics.print(("Total score: %d"):format(result.total_score), x + 24, y + 122)

  love.graphics.setFont(ctx.fonts.small)
  love.graphics.print(("Plays: %d  Discards: %d  Clears: %d"):format(result.total_plays, result.total_discards, result.blind_clears), x + 24, y + 152)

  -- Highlights: MVP joker + best hand
  local highlight_y = y + 178
  if result.mvp_joker then
    love.graphics.setColor(ctx.palette.ok[1], ctx.palette.ok[2], ctx.palette.ok[3], overlay_alpha)
    love.graphics.setFont(ctx.fonts.small)
    love.graphics.print(("MVP Joker: %s (+%d)"):format(result.mvp_joker, result.mvp_joker_score or 0), x + 24, highlight_y)
    highlight_y = highlight_y + 22
  end
  if result.best_play then
    love.graphics.setColor(ctx.palette.ok[1], ctx.palette.ok[2], ctx.palette.ok[3], overlay_alpha)
    love.graphics.setFont(ctx.fonts.small)
    love.graphics.print(("Best hand: %s (%d pts)"):format(result.best_play.hand_type, result.best_play.score), x + 24, highlight_y)
    highlight_y = highlight_y + 22
  end

  -- Seed
  love.graphics.setColor(ctx.palette.muted[1], ctx.palette.muted[2], ctx.palette.muted[3], overlay_alpha)
  love.graphics.setFont(ctx.fonts.small)
  local seed_text = result.seed and result.seed ~= "" and result.seed or "n/a"
  love.graphics.print(("Seed: %s"):format(seed_text), x + 24, highlight_y)
  highlight_y = highlight_y + 28

  -- Separator
  love.graphics.setColor(ctx.palette.muted[1], ctx.palette.muted[2], ctx.palette.muted[3], 0.3 * overlay_alpha)
  love.graphics.rectangle("fill", x + 24, highlight_y, panel_w - 48, 1)
  highlight_y = highlight_y + 8

  love.graphics.setColor(ctx.palette.muted[1], ctx.palette.muted[2], ctx.palette.muted[3], overlay_alpha)
  love.graphics.setFont(ctx.fonts.small)
  love.graphics.print("Per-round stats", x + 24, highlight_y)

  local row_y = highlight_y + 22
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
    love.graphics.setColor(ctx.palette.text[1], ctx.palette.text[2], ctx.palette.text[3], overlay_alpha)
    love.graphics.printf(line, x + 24, row_y, panel_w - 48, "left")
    row_y = row_y + 24
  end

  love.graphics.setColor(ctx.palette.accent[1], ctx.palette.accent[2], ctx.palette.accent[3], overlay_alpha)
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
    ("Reduced Motion: %s (F3)"):format(ctx.reduced_motion and "ON" or "OFF"),
    ("Anim: %.2fms | processed %d | active %d | dropped %d"):format(
      (ctx.anim_stats and ctx.anim_stats.update_ms) or 0,
      (ctx.anim_stats and ctx.anim_stats.processed) or 0,
      (ctx.anim_stats and ctx.anim_stats.active_tweens) or 0,
      (ctx.anim_stats and ctx.anim_stats.dropped_tweens) or 0
    ),
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
  local overlay_alpha = (ctx.overlay_alpha and ctx.overlay_alpha.shop) or 0
  if overlay_alpha <= 0.001 then
    return
  end
  local shop = (ctx.state.shop and ctx.state.shop.active and ctx.state.shop) or (ctx.overlay_snapshots and ctx.overlay_snapshots.shop) or nil
  if not shop then
    return
  end

  local palette = ctx.palette
  local fonts = ctx.fonts
  local w, h = love.graphics.getWidth(), love.graphics.getHeight()
  love.graphics.setColor(0, 0, 0, 0.74 * overlay_alpha)
  love.graphics.rectangle("fill", 0, 0, w, h)

  local panel_w = math.min(1040, w - 160)
  local panel_h = math.min(560, h - 120)
  local x = math.floor((w - panel_w) * 0.5)
  local y = math.floor((h - panel_h) * 0.5)
  PixelKit.draw_panel(x, y, panel_w, panel_h, {
    asset = "panel_shop",
    fill = with_alpha(palette.panel, overlay_alpha),
    border = with_alpha(palette.accent_alt, overlay_alpha),
    border_width = 2,
    shadow = 4,
    alpha = overlay_alpha,
  })

  love.graphics.setColor(palette.accent[1], palette.accent[2], palette.accent[3], overlay_alpha)
  love.graphics.setFont(fonts.title)
  love.graphics.printf("SHOP", x, y + 18, panel_w, "center")

  love.graphics.setColor(palette.text[1], palette.text[2], palette.text[3], overlay_alpha)
  love.graphics.setFont(fonts.ui)
  love.graphics.print(("Credits: $%d"):format(ctx.state.money or 0), x + 24, y + 74)
  love.graphics.setColor(palette.muted[1], palette.muted[2], palette.muted[3], overlay_alpha)
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
      fill = { 0.08, 0.06, 0.16, overlay_alpha },
      border = with_alpha(border, overlay_alpha),
      border_width = 2,
      shadow = 2,
    })

    if offer then
      love.graphics.setColor(palette.accent_alt[1], palette.accent_alt[2], palette.accent_alt[3], overlay_alpha)
      love.graphics.setFont(fonts.ui)
      love.graphics.print(("[%d]"):format(i), row_x + 14, row_y + 16)

      if offer.type == "card" then
        local label = ctx.game.card_label and ctx.game.card_label(offer.card) or "Card"
        love.graphics.setColor(palette.text[1], palette.text[2], palette.text[3], overlay_alpha)
        love.graphics.setFont(fonts.ui)
        love.graphics.print(("Card %s"):format(label), row_x + 88, row_y + 16)
        love.graphics.setColor(palette.muted[1], palette.muted[2], palette.muted[3], overlay_alpha)
        love.graphics.setFont(fonts.small)
        love.graphics.print("Adds this card to your run deck.", row_x + 88, row_y + 48)
      else
        local joker = ctx.game.JOKERS[offer.joker_key]
        local name = joker and joker.name or offer.joker_key
        love.graphics.setColor(palette.text[1], palette.text[2], palette.text[3], overlay_alpha)
        love.graphics.setFont(fonts.ui)
        love.graphics.print(("Joker %s"):format(name), row_x + 88, row_y + 16)
        love.graphics.setColor(palette.muted[1], palette.muted[2], palette.muted[3], overlay_alpha)
        love.graphics.setFont(fonts.small)
        love.graphics.print(joker and joker.formula or "", row_x + 88, row_y + 48)
      end

      love.graphics.setColor(palette.ok[1], palette.ok[2], palette.ok[3], overlay_alpha)
      love.graphics.setFont(fonts.ui)
      love.graphics.printf(("$%d"):format(offer.price), row_x, row_y + 16, row_w - 16, "right")
    else
      love.graphics.setColor(palette.muted[1], palette.muted[2], palette.muted[3], overlay_alpha)
      love.graphics.setFont(fonts.ui)
      love.graphics.printf(("[%d] Sold"):format(i), row_x + 14, row_y + 32, row_w - 28, "left")
    end

    row_y = row_y + row_h + 12
  end

  local controls = "1/2/3 buy | E reroll | Z/X/V deck edit | Q..Y sell jokers | A..G sell cards | C continue"
  love.graphics.setColor(palette.warn[1], palette.warn[2], palette.warn[3], overlay_alpha)
  love.graphics.setFont(fonts.small)
  love.graphics.printf(clipped_text(fonts.small, controls, panel_w - 48), x + 24, y + panel_h - 56, panel_w - 48, "center")
end

function Render.draw(ctx)
  local layout = Layout.columns(love.graphics.getWidth(), love.graphics.getHeight())
  local top_offset, top_alpha = panel_transition(ctx, 1)
  local feedback_offset, feedback_alpha = panel_transition(ctx, 2)
  local hand_offset, hand_alpha = panel_transition(ctx, 3)
  local actions_offset, actions_alpha = panel_transition(ctx, 4)
  local summary_offset, summary_alpha = panel_transition(ctx, 5)
  local joker_offset, joker_alpha = panel_transition(ctx, 6)

  local top_area = shifted_rect(layout.top, top_offset)
  local feedback_area = shifted_rect(layout.feedback, feedback_offset)
  local hand_area = shifted_rect(layout.hand, hand_offset)
  local actions_area = shifted_rect(layout.actions, actions_offset)
  local summary_area = shifted_rect(layout.run_summary, summary_offset)
  local joker_area = shifted_rect(layout.jokers, joker_offset)

  draw_background(ctx)
  draw_major_event_effect(ctx)
  draw_header(ctx, top_area, top_alpha)
  draw_event_banner(ctx, top_area)
  draw_feedback(ctx, feedback_area, feedback_alpha)
  local hand_tooltip = draw_hand(ctx, hand_area, hand_alpha)
  local action_tooltip = draw_actions(ctx, actions_area, actions_alpha)
  draw_run_summary(ctx, summary_area, summary_alpha)
  local joker_tooltip = draw_joker_dock(ctx, joker_area, joker_alpha)

  draw_shop_modal(ctx)
  draw_seed_prompt(ctx)
  draw_run_result(ctx)
  draw_debug_overlay(ctx)

  if not (ctx.state.shop and ctx.state.shop.active) and not ctx.run_result and not ctx.seed_input_mode then
    draw_tooltip(ctx, hand_tooltip or action_tooltip or joker_tooltip)
  end
end

return Render
