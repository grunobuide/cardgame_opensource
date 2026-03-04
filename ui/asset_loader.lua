--- Centralized asset loader with fallback support.
-- Loads image assets and builds NinePatch objects, returning nil gracefully
-- when files are missing so the renderer can fall back to procedural drawing.

local NinePatch = require("ui.nine_patch")

local Assets = {}
Assets.__index = Assets

-- Singleton cache shared across the application.
local image_cache = {}
local nine_patch_cache = {}

--- Asset manifest: maps logical names to file paths and 9-slice corner sizes.
-- When art files are dropped into assets/ui/ or assets/icons/, they are
-- picked up automatically. Until then every lookup returns nil and the
-- renderer falls back to PixelKit procedural drawing.
Assets.manifest = {
  -- Backgrounds (512x512 tileable)
  bg_felt          = { path = "assets/ui/bg_felt.png" },
  bg_felt_combat   = { path = "assets/ui/bg_felt_combat.png" },
  bg_felt_shop     = { path = "assets/ui/bg_felt_shop.png" },
  bg_felt_gameover = { path = "assets/ui/bg_felt_gameover.png" },

  -- Panels (9-slice)
  panel_primary    = { path = "assets/ui/panel_primary.png",   corner = 12 },
  panel_secondary  = { path = "assets/ui/panel_secondary.png", corner = 12 },
  panel_inset      = { path = "assets/ui/panel_inset.png",     corner = 12 },
  panel_highlight  = { path = "assets/ui/panel_highlight.png", corner = 12 },
  panel_tooltip    = { path = "assets/ui/panel_tooltip.png",   corner = 8  },
  panel_shop       = { path = "assets/ui/panel_shop.png",      corner = 12 },
  panel_result     = { path = "assets/ui/panel_result.png",    corner = 16 },
  overlay_bg       = { path = "assets/ui/overlay_bg.png" },

  -- Buttons (9-slice, 3 tiers x 4 states)
  btn_primary          = { path = "assets/ui/btn_primary.png",          corner = 10 },
  btn_primary_hover    = { path = "assets/ui/btn_primary_hover.png",    corner = 10 },
  btn_primary_pressed  = { path = "assets/ui/btn_primary_pressed.png",  corner = 10 },
  btn_primary_disabled = { path = "assets/ui/btn_primary_disabled.png", corner = 10 },

  btn_secondary          = { path = "assets/ui/btn_secondary.png",          corner = 10 },
  btn_secondary_hover    = { path = "assets/ui/btn_secondary_hover.png",    corner = 10 },
  btn_secondary_pressed  = { path = "assets/ui/btn_secondary_pressed.png",  corner = 10 },
  btn_secondary_disabled = { path = "assets/ui/btn_secondary_disabled.png", corner = 10 },

  btn_utility          = { path = "assets/ui/btn_utility.png",          corner = 10 },
  btn_utility_hover    = { path = "assets/ui/btn_utility_hover.png",    corner = 10 },
  btn_utility_pressed  = { path = "assets/ui/btn_utility_pressed.png",  corner = 10 },
  btn_utility_disabled = { path = "assets/ui/btn_utility_disabled.png", corner = 10 },

  btn_reroll          = { path = "assets/ui/btn_reroll.png",          corner = 10 },
  btn_reroll_hover    = { path = "assets/ui/btn_reroll_hover.png",    corner = 10 },
  btn_reroll_pressed  = { path = "assets/ui/btn_reroll_pressed.png",  corner = 10 },
  btn_reroll_disabled = { path = "assets/ui/btn_reroll_disabled.png", corner = 10 },

  -- Joker frames (9-slice)
  joker_frame_common   = { path = "assets/ui/joker_frame_common.png",   corner = 8 },
  joker_frame_uncommon = { path = "assets/ui/joker_frame_uncommon.png", corner = 8 },
  joker_frame_rare     = { path = "assets/ui/joker_frame_rare.png",     corner = 8 },
  joker_slot_empty     = { path = "assets/ui/joker_slot_empty.png",     corner = 8 },

  -- Joker icon spritesheet (4x4 grid, 64x64 cells)
  joker_icons = { path = "assets/ui/joker_icons.png" },

  -- Scoring
  score_popup_bg     = { path = "assets/ui/score_popup_bg.png",     corner = 8 },
  badge_chips        = { path = "assets/ui/badge_chips.png" },
  badge_mult         = { path = "assets/ui/badge_mult.png" },
  badge_total        = { path = "assets/ui/badge_total.png" },
  joker_trigger_flash = { path = "assets/ui/joker_trigger_flash.png" },

  -- Rarity badges
  badge_common   = { path = "assets/ui/badge_common.png" },
  badge_uncommon = { path = "assets/ui/badge_uncommon.png" },
  badge_rare     = { path = "assets/ui/badge_rare.png" },

  -- Card interaction overlays
  card_slot_empty  = { path = "assets/cards/card_slot_empty.png" },
  card_select_glow = { path = "assets/cards/card_select_glow.png" },
  card_hover_glow  = { path = "assets/cards/card_hover_glow.png" },
  card_foil_overlay = { path = "assets/cards/card_foil_overlay.png" },
  card_seal_red    = { path = "assets/cards/card_seal_red.png" },
  card_seal_blue   = { path = "assets/cards/card_seal_blue.png" },

  -- Shop
  shop_item_frame      = { path = "assets/ui/shop_item_frame.png",      corner = 12 },
  shop_item_frame_sold = { path = "assets/ui/shop_item_frame_sold.png", corner = 12 },
  price_tag            = { path = "assets/ui/price_tag.png" },

  -- Headers / Banners
  header_victory = { path = "assets/ui/header_victory.png" },
  header_defeat  = { path = "assets/ui/header_defeat.png" },
  banner_bg      = { path = "assets/ui/banner_bg.png", corner = 8 },

  -- Input / Settings
  input_field = { path = "assets/ui/input_field.png", corner = 6 },
  toggle_on   = { path = "assets/ui/toggle_on.png" },
  toggle_off  = { path = "assets/ui/toggle_off.png" },

  -- Stat block
  stat_block      = { path = "assets/ui/stat_block.png",      corner = 8 },
  stat_block_warn = { path = "assets/ui/stat_block_warn.png", corner = 8 },
  stat_block_ok   = { path = "assets/ui/stat_block_ok.png",   corner = 8 },

  -- Progress bar parts
  bar_fill      = { path = "assets/ui/bar_fill.png" },
  bar_track     = { path = "assets/ui/bar_track.png", corner = 8 },
  bar_threshold = { path = "assets/ui/bar_threshold.png" },
}

-- Icon manifest: 16x16 icons loaded individually.
Assets.icons = {
  hand           = "assets/icons/icon_hand.png",
  discard        = "assets/icons/icon_discard.png",
  target         = "assets/icons/icon_target.png",
  score          = "assets/icons/icon_score.png",
  coin           = "assets/icons/icon_coin.png",
  deck           = "assets/icons/icon_deck.png",
  ante           = "assets/icons/icon_ante.png",
  blind          = "assets/icons/icon_blind.png",
  sort_suit      = "assets/icons/icon_sort_suit.png",
  sort_rank      = "assets/icons/icon_sort_rank.png",
  new_run        = "assets/icons/icon_new_run.png",
  play           = "assets/icons/icon_play.png",
  discard_action = "assets/icons/icon_discard_action.png",
  chip           = "assets/icons/icon_chip.png",
  mult           = "assets/icons/icon_mult.png",
  joker_add      = "assets/icons/icon_joker_add.png",
  seed           = "assets/icons/icon_seed.png",
  settings       = "assets/icons/icon_settings.png",
  -- 24x24 banner icons
  blind_cleared  = "assets/icons/icon_blind_cleared.png",
  ante_up        = "assets/icons/icon_ante_up.png",
  victory        = "assets/icons/icon_victory.png",
  busted         = "assets/icons/icon_busted.png",
}

--- Try to load a raw LOVE2D Image. Returns the image or nil.
function Assets.image(name)
  -- check manifest first
  local entry = Assets.manifest[name]
  local path = entry and entry.path or nil
  if not path then
    return nil
  end
  return Assets.image_by_path(path)
end

--- Load an image by direct file path. Returns image or nil.
function Assets.image_by_path(path)
  if image_cache[path] ~= nil then
    return image_cache[path] or nil
  end
  local ok, img = pcall(love.graphics.newImage, path)
  image_cache[path] = ok and img or false
  return ok and img or nil
end

--- Load a 16x16 icon by logical name. Returns image or nil.
function Assets.icon(name)
  local path = Assets.icons[name]
  if not path then
    return nil
  end
  return Assets.image_by_path(path)
end

--- Get a NinePatch for a manifest entry. Returns NinePatch or nil.
function Assets.nine_patch(name)
  if nine_patch_cache[name] ~= nil then
    return nine_patch_cache[name] or nil
  end
  local entry = Assets.manifest[name]
  if not entry or not entry.corner then
    nine_patch_cache[name] = false
    return nil
  end
  local img = Assets.image(name)
  if not img then
    nine_patch_cache[name] = false
    return nil
  end
  local np = NinePatch.new(img, entry.corner)
  nine_patch_cache[name] = np
  return np
end

--- Resolve which background key to use for the current game state.
-- @param state  game state table
-- @return string  manifest key like "bg_felt" or "bg_felt_combat"
function Assets.bg_key_for_state(state)
  if state.game_over then
    return "bg_felt_gameover"
  end
  if state.shop and state.shop.active then
    return "bg_felt_shop"
  end
  return "bg_felt_combat"
end

--- Resolve button asset key for a given tier and state.
-- @param tier   "primary", "secondary", or "utility"
-- @param state  "normal", "hover", "active"/"pressed", or "disabled"
-- @return string  manifest key like "btn_primary_hover"
function Assets.button_key(tier, state)
  local t = tier or "utility"
  if state == "normal" or state == nil then
    return "btn_" .. t
  end
  local s = state == "active" and "pressed" or state
  return "btn_" .. t .. "_" .. s
end

--- Resolve joker frame key for a given rarity.
-- @param rarity  "common", "uncommon", or "rare"
-- @return string  manifest key
function Assets.joker_frame_key(rarity)
  local r = rarity or "common"
  return "joker_frame_" .. r
end

--- Clear all caches (useful on theme switch or hot-reload).
function Assets.clear_cache()
  image_cache = {}
  nine_patch_cache = {}
end

return Assets
