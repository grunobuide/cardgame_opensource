local M = {}
M.__index = M

M.SCHEMA_VERSION = 2
M.DEFAULT_PATH = "saves/run_state.lua"

local function trim(text)
  return tostring(text or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function shallow_copy_card(card)
  if type(card) ~= "table" then
    return nil
  end
  local copy = {
    rank = card.rank,
    suit = card.suit,
  }
  if card.enhancement then
    copy.enhancement = tostring(card.enhancement)
  end
  if card.face_down then
    copy.face_down = true
  end
  return copy
end

local function copy_cards(cards)
  local out = {}
  if type(cards) ~= "table" then
    return out
  end
  for i, card in ipairs(cards) do
    out[i] = shallow_copy_card(card)
  end
  return out
end

local function copy_string_array(items)
  local out = {}
  if type(items) ~= "table" then
    return out
  end
  for i, value in ipairs(items) do
    out[i] = tostring(value)
  end
  return out
end

local function copy_numeric_bool_map(source)
  local out = {}
  if type(source) ~= "table" then
    return out
  end
  for key, value in pairs(source) do
    local index = tonumber(key)
    if index and index >= 1 and value then
      out[index] = true
    end
  end
  return out
end

local function safe_deep_copy(value, seen)
  local value_type = type(value)
  if value_type == "number" or value_type == "string" or value_type == "boolean" or value_type == "nil" then
    return value
  end
  if value_type ~= "table" then
    return nil
  end

  seen = seen or {}
  if seen[value] then
    return seen[value]
  end

  local out = {}
  seen[value] = out
  for key, item in pairs(value) do
    local copied_key = safe_deep_copy(key, seen)
    local copied_item = safe_deep_copy(item, seen)
    if copied_key ~= nil and copied_item ~= nil then
      out[copied_key] = copied_item
    end
  end
  return out
end

local function copy_shop(shop)
  if type(shop) ~= "table" then
    return nil
  end

  local out = {
    active = shop.active == true,
    reroll_cost = tonumber(shop.reroll_cost) or 0,
    clear_event = shop.clear_event,
    offers = {},
  }

  if type(shop.offers) == "table" then
    for key, offer in pairs(shop.offers) do
      local idx = tonumber(key)
      if idx and type(offer) == "table" then
        if offer.type == "card" then
          out.offers[idx] = {
            type = "card",
            card = shallow_copy_card(offer.card),
            price = tonumber(offer.price) or 0,
            rarity = offer.rarity,
          }
        elseif offer.type == "consumable" then
          out.offers[idx] = {
            type = "consumable",
            consumable_key = offer.consumable_key,
            price = tonumber(offer.price) or 0,
            rarity = offer.rarity,
          }
        else
          out.offers[idx] = {
            type = "joker",
            joker_key = offer.joker_key,
            price = tonumber(offer.price) or 0,
            rarity = offer.rarity,
          }
        end
      end
    end
  end

  return out
end

local function copy_inventory(inv, fallback_schema)
  local source = type(inv) == "table" and inv or {}
  local ledger = type(source.ledger) == "table" and source.ledger or {}
  local history = {}
  if type(source.history) == "table" then
    for i, entry in ipairs(source.history) do
      history[i] = safe_deep_copy(entry) or {}
    end
  end

  return {
    schema = tonumber(source.schema) or fallback_schema,
    next_event_index = tonumber(source.next_event_index) or (#history + 1),
    ledger = {
      earned = tonumber(ledger.earned) or 0,
      spent = tonumber(ledger.spent) or 0,
    },
    history = history,
  }
end

local function encode_state(game, state)
  local inventory = copy_inventory(state.inventory, game.INVENTORY_SCHEMA)
  return {
    ante = tonumber(state.ante) or 1,
    blind_index = tonumber(state.blind_index) or 1,
    score = tonumber(state.score) or 0,
    money = tonumber(state.money) or 0,
    hands = tonumber(state.hands) or game.STARTING_HANDS,
    discards = tonumber(state.discards) or game.STARTING_DISCARDS,
    deck = copy_cards(state.deck),
    hand = copy_cards(state.hand),
    selected = copy_numeric_bool_map(state.selected),
    jokers = copy_string_array(state.jokers),
    consumables = copy_string_array(state.consumables or {}),
    hand_levels = safe_deep_copy(state.hand_levels or {}),
    boss_blind_key = state.boss_blind_key and tostring(state.boss_blind_key) or nil,
    last_hand_type = state.last_hand_type and tostring(state.last_hand_type) or nil,
    owned_cards = copy_cards(state.owned_cards),
    deck_cards = copy_cards(state.deck_cards),
    inventory = inventory,
    game_over = state.game_over == true,
    run_won = state.run_won == true,
    message = tostring(state.message or ""),
    seed = trim(state.seed),
    shop = copy_shop(state.shop),
  }
end

local function decode_state(game, encoded)
  if type(encoded) ~= "table" then
    return nil, "invalid_game_state"
  end

  local seed = trim(encoded.seed)
  if seed == "" then
    seed = "random"
  end
  local rng = game.make_seeded_rng(seed)
  local state = game.new_state(rng, { seed = seed })

  state.ante = math.max(1, tonumber(encoded.ante) or state.ante)
  state.blind_index = math.max(1, tonumber(encoded.blind_index) or state.blind_index)
  if game.BLINDS and #game.BLINDS > 0 and state.blind_index > #game.BLINDS then
    state.blind_index = #game.BLINDS
  end
  state.score = tonumber(encoded.score) or 0
  state.money = tonumber(encoded.money) or 0
  state.hands = math.max(0, tonumber(encoded.hands) or game.STARTING_HANDS)
  state.discards = math.max(0, tonumber(encoded.discards) or game.STARTING_DISCARDS)
  state.deck = copy_cards(encoded.deck)
  state.hand = copy_cards(encoded.hand)
  state.selected = copy_numeric_bool_map(encoded.selected)
  state.jokers = copy_string_array(encoded.jokers)
  state.consumables = copy_string_array(encoded.consumables or {})
  state.hand_levels = safe_deep_copy(encoded.hand_levels or {})
  state.boss_blind_key = encoded.boss_blind_key and tostring(encoded.boss_blind_key) or nil
  state.last_hand_type = encoded.last_hand_type and tostring(encoded.last_hand_type) or nil
  state.owned_cards = copy_cards(encoded.owned_cards)
  state.deck_cards = copy_cards(encoded.deck_cards)
  state.game_over = encoded.game_over == true
  state.run_won = encoded.run_won == true
  state.message = tostring(encoded.message or "")
  state.seed = seed
  state.shop = copy_shop(encoded.shop)
  state.rng = rng

  -- Drop stale selected indices that no longer match the current hand.
  for index, _ in pairs(state.selected) do
    if index > #state.hand then
      state.selected[index] = nil
    end
  end

  local inventory = copy_inventory(encoded.inventory, game.INVENTORY_SCHEMA)
  state.inventory = {
    schema = inventory.schema,
    next_event_index = inventory.next_event_index,
    jokers = state.jokers,
    deck_cards = state.deck_cards,
    owned_cards = state.owned_cards,
    ledger = inventory.ledger,
    history = inventory.history,
  }
  game.ensure_run_inventory(state)
  return state
end

local function sort_keys(tbl)
  local keys = {}
  for key in pairs(tbl) do
    keys[#keys + 1] = key
  end
  table.sort(keys, function(a, b)
    local ta, tb = type(a), type(b)
    if ta == tb then
      if ta == "number" or ta == "string" then
        return a < b
      end
      return tostring(a) < tostring(b)
    end
    return ta < tb
  end)
  return keys
end

local function is_array(tbl)
  local max_index = 0
  local count = 0
  for key in pairs(tbl) do
    if type(key) ~= "number" or key < 1 or key % 1 ~= 0 then
      return false
    end
    if key > max_index then
      max_index = key
    end
    count = count + 1
  end
  return max_index == count
end

local function serialize_value(value, seen)
  local value_type = type(value)
  if value_type == "nil" then
    return "nil"
  end
  if value_type == "boolean" then
    return value and "true" or "false"
  end
  if value_type == "number" then
    return tostring(value)
  end
  if value_type == "string" then
    return string.format("%q", value)
  end
  if value_type ~= "table" then
    error("unsupported value type in save payload: " .. value_type)
  end

  seen = seen or {}
  if seen[value] then
    error("cyclic table detected while serializing save payload")
  end
  seen[value] = true

  local parts = {}
  if is_array(value) then
    for i = 1, #value do
      parts[#parts + 1] = serialize_value(value[i], seen)
    end
  else
    local keys = sort_keys(value)
    for _, key in ipairs(keys) do
      local item = value[key]
      local key_repr
      if type(key) == "string" and key:match("^[_%a][_%w]*$") then
        key_repr = key
      else
        key_repr = "[" .. serialize_value(key, seen) .. "]"
      end
      parts[#parts + 1] = key_repr .. " = " .. serialize_value(item, seen)
    end
  end

  seen[value] = nil
  return "{ " .. table.concat(parts, ", ") .. " }"
end

local function compile_chunk(text, chunkname)
  if _VERSION == "Lua 5.1" then
    local fn, err = loadstring(text, chunkname)
    if not fn then
      return nil, err
    end
    setfenv(fn, {})
    return fn
  end
  return load(text, chunkname, "t", {})
end

local function deserialize_blob(blob)
  local fn, err = compile_chunk(blob, "save_blob")
  if not fn then
    return nil, err
  end
  local ok, value = pcall(fn)
  if not ok then
    return nil, value
  end
  if type(value) ~= "table" then
    return nil, "decoded save payload is not a table"
  end
  return value
end

local function love_filesystem_adapter()
  if not (love and love.filesystem) then
    return nil
  end
  return {
    write = function(path, data)
      local ok, err = love.filesystem.write(path, data)
      if not ok then
        return nil, err or "write_failed"
      end
      return true
    end,
    read = function(path)
      local data, size_or_err = love.filesystem.read(path)
      if not data then
        return nil, size_or_err or "read_failed"
      end
      return data
    end,
    exists = function(path)
      return love.filesystem.getInfo(path) ~= nil
    end,
    mkdir = function(path)
      local ok, err = love.filesystem.createDirectory(path)
      if not ok then
        return nil, err or "mkdir_failed"
      end
      return true
    end,
    remove = function(path)
      local ok, err = love.filesystem.remove(path)
      if not ok then
        return nil, err or "remove_failed"
      end
      return true
    end,
  }
end

local function migrate_payload(raw_payload, current_schema)
  if type(raw_payload) ~= "table" then
    return nil, "invalid_payload"
  end

  local schema = tonumber(raw_payload.schema_version)
  local payload = safe_deep_copy(raw_payload) or {}
  if not schema then
    local game_state = payload.game_state or payload.state or payload
    payload = {
      schema_version = 1,
      saved_at = payload.saved_at,
      game_state = game_state,
      meta = payload.meta or {},
    }
    schema = 1
  end

  if schema > current_schema then
    return nil, "unsupported_future_schema"
  end

  while schema < current_schema do
    if schema == 0 then
      payload = {
        schema_version = 1,
        saved_at = payload.saved_at,
        game_state = payload.game_state or payload.state or payload,
        meta = payload.meta or {},
      }
      schema = 1
    elseif schema == 1 then
      -- v1 → v2: add consumables, hand_levels, boss_blind_key, last_hand_type, card enhancements
      local gs = payload.game_state or {}
      gs.consumables = gs.consumables or {}
      gs.hand_levels = gs.hand_levels or {}
      gs.boss_blind_key = gs.boss_blind_key or nil
      gs.last_hand_type = gs.last_hand_type or nil
      payload.schema_version = 2
      schema = 2
    else
      return nil, ("missing_migration_%d_to_%d"):format(schema, schema + 1)
    end
  end

  payload.schema_version = schema
  payload.meta = type(payload.meta) == "table" and payload.meta or {}
  if type(payload.game_state) ~= "table" then
    return nil, "invalid_game_state"
  end
  return payload
end

function M.new(opts)
  opts = opts or {}
  local game = opts.game
  if not game then
    error("save_load.new requires opts.game")
  end
  local fs = opts.filesystem or love_filesystem_adapter()
  if not fs then
    error("save_load.new requires opts.filesystem when love.filesystem is unavailable")
  end
  local path = opts.path or M.DEFAULT_PATH
  return setmetatable({
    game = game,
    fs = fs,
    path = path,
  }, M)
end

function M:ensure_parent_dir()
  if not self.fs.mkdir then
    return true
  end
  local parent = self.path:match("^(.*)/[^/]+$")
  if not parent or parent == "" then
    return true
  end
  local ok, err = self.fs.mkdir(parent)
  if not ok then
    return nil, err
  end
  return true
end

function M:save(state, meta)
  if type(state) ~= "table" then
    return { ok = false, reason = "invalid_state", message = "Cannot save: missing run state." }
  end

  local payload = {
    schema_version = M.SCHEMA_VERSION,
    saved_at = os.time(),
    game_state = encode_state(self.game, state),
    meta = safe_deep_copy(meta or {}) or {},
  }

  local blob = "return " .. serialize_value(payload)
  local ok_dir, err_dir = self:ensure_parent_dir()
  if not ok_dir then
    return { ok = false, reason = "mkdir_failed", message = tostring(err_dir or "mkdir_failed") }
  end

  local ok, err = self.fs.write(self.path, blob)
  if not ok then
    return { ok = false, reason = "write_failed", message = tostring(err or "write_failed") }
  end

  return {
    ok = true,
    path = self.path,
    schema_version = M.SCHEMA_VERSION,
  }
end

function M:load()
  if self.fs.exists and not self.fs.exists(self.path) then
    return { ok = false, reason = "save_not_found", message = "No saved run found." }
  end

  local blob, read_err = self.fs.read(self.path)
  if not blob then
    return { ok = false, reason = "read_failed", message = tostring(read_err or "read_failed") }
  end

  local parsed, parse_err = deserialize_blob(blob)
  if not parsed then
    return { ok = false, reason = "decode_failed", message = tostring(parse_err or "decode_failed") }
  end

  local payload, migrate_err = migrate_payload(parsed, M.SCHEMA_VERSION)
  if not payload then
    return { ok = false, reason = "migration_failed", message = tostring(migrate_err or "migration_failed") }
  end

  local state, state_err = decode_state(self.game, payload.game_state)
  if not state then
    return { ok = false, reason = "invalid_state", message = tostring(state_err or "invalid_state") }
  end

  return {
    ok = true,
    path = self.path,
    schema_version = payload.schema_version,
    saved_at = payload.saved_at,
    state = state,
    meta = payload.meta,
  }
end

function M:clear()
  if self.fs.exists and not self.fs.exists(self.path) then
    return { ok = true, path = self.path, removed = false }
  end
  if not self.fs.remove then
    return { ok = false, reason = "remove_unsupported", message = "Filesystem adapter cannot remove files." }
  end
  local ok, err = self.fs.remove(self.path)
  if not ok then
    return { ok = false, reason = "remove_failed", message = tostring(err or "remove_failed") }
  end
  return { ok = true, path = self.path, removed = true }
end

return M
