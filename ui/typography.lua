local Typography = {}

Typography.scale = {
  small = 14,
  ui = 22,
  title = 30,
}

Typography.grid = 8

Typography.font_stack = {
  "assets/fonts/PixelOperatorMonoHB.ttf",
  "assets/fonts/PressStart2P-Regular.ttf",
  "assets/fonts/pixel_operator.ttf",
}

local function try_load_font(path, size)
  local ok, font = pcall(love.graphics.newFont, path, size)
  if ok and font then
    return font
  end
  return nil
end

local function load_from_stack(size)
  for _, path in ipairs(Typography.font_stack) do
    local font = try_load_font(path, size)
    if font then
      return font, path
    end
  end
  return love.graphics.newFont(size), "default"
end

function Typography.load()
  local small, source = load_from_stack(Typography.scale.small)
  local ui = load_from_stack(Typography.scale.ui)
  local title = load_from_stack(Typography.scale.title)

  local fonts = {
    small = small,
    ui = ui,
    title = title,
    -- compatibility aliases for migrated UI modules
    tiny = small,
    medium = ui,
    body = ui,
  }

  return {
    fonts = fonts,
    grid = Typography.grid,
    scale = Typography.scale,
    font_source = source,
  }
end

return Typography
