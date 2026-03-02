local Palette = {}

Palette.values = {
  dark = {
    -- Alien Vaporwave palette (hard-edged pixel UI, no soft blur)
    bg = { 0.051, 0.008, 0.129, 1.0 },      -- #0D0221
    bg_top = { 0.071, 0.039, 0.184, 1.0 },
    bg_bottom = { 0.039, 0.004, 0.102, 1.0 },
    panel = { 0.106, 0.071, 0.251, 1.0 },   -- #1B1240
    panel_alt = { 0.129, 0.090, 0.290, 1.0 },
    border = { 0.0, 0.898, 1.0, 1.0 },      -- #00E5FF
    text = { 0.957, 0.957, 1.0, 1.0 },      -- #F4F4FF
    muted = { 0.710, 0.796, 0.914, 1.0 },
    accent = { 1.0, 0.180, 0.820, 1.0 },    -- #FF2ED1
    accent_alt = { 0.0, 0.898, 1.0, 1.0 },  -- cyan reuse to reduce accent noise
    warn = { 1.0, 0.180, 0.820, 1.0 },
    select = { 1.0, 0.180, 0.820, 1.0 },
    danger = { 1.0, 0.180, 0.820, 1.0 },
    ok = { 0.447, 1.0, 0.353, 1.0 },        -- #72FF5A
    glow_a = { 1.0, 0.180, 0.820, 0.0 },
    glow_b = { 0.0, 0.898, 1.0, 0.0 },
    grid = { 0.0, 0.898, 1.0, 0.10 },
    shadow = { 0.0, 0.0, 0.0, 0.75 },
  },
  light = {
    bg = { 0.10, 0.09, 0.17, 1.0 },
    panel = { 0.16, 0.13, 0.27, 1.0 },
    panel_alt = { 0.20, 0.16, 0.32, 1.0 },
    border = { 0.0, 0.898, 1.0, 1.0 },
    text = { 0.957, 0.957, 1.0, 1.0 },
    muted = { 0.74, 0.82, 0.94, 1.0 },
    accent = { 1.0, 0.180, 0.820, 1.0 },
    accent_alt = { 0.0, 0.898, 1.0, 1.0 },
    warn = { 1.0, 0.180, 0.820, 1.0 },
    select = { 1.0, 0.180, 0.820, 1.0 },
    danger = { 1.0, 0.180, 0.820, 1.0 },
    ok = { 0.447, 1.0, 0.353, 1.0 },
    bg_top = { 0.18, 0.14, 0.28, 1.0 },
    bg_bottom = { 0.08, 0.07, 0.14, 1.0 },
    glow_a = { 1.0, 0.180, 0.820, 0.0 },
    glow_b = { 0.0, 0.898, 1.0, 0.0 },
    grid = { 0.0, 0.898, 1.0, 0.08 },
    shadow = { 0.0, 0.0, 0.0, 0.75 },
  },
}

function Palette.get(theme)
  return Palette.values[theme] or Palette.values.dark
end

return Palette
