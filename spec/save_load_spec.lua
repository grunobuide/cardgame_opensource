local game = require("src.game_logic")
local SaveLoad = require("src.save_load")

local function memory_fs()
  local files = {}
  return {
    _files = files,
    write = function(path, data)
      files[path] = data
      return true
    end,
    read = function(path)
      local data = files[path]
      if data == nil then
        return nil, "not_found"
      end
      return data
    end,
    exists = function(path)
      return files[path] ~= nil
    end,
    mkdir = function(_path)
      return true
    end,
    remove = function(path)
      files[path] = nil
      return true
    end,
  }
end

describe("save_load", function()
  it("saves and restores run state with schema v1 payload", function()
    local fs = memory_fs()
    local store = SaveLoad.new({
      game = game,
      filesystem = fs,
      path = "saves/test_run.lua",
    })

    local state = game.new_state(game.make_seeded_rng("save-seed-1"), { seed = "save-seed-1" })
    state.ante = 2
    state.blind_index = 2
    state.score = 123
    state.money = 45
    state.hands = 3
    state.discards = 1
    state.deck = {
      { rank = 2, suit = "S" },
      { rank = 3, suit = "H" },
    }
    state.hand = {
      { rank = "A", suit = "D" },
      { rank = 7, suit = "C" },
      { rank = "Q", suit = "S" },
    }
    state.selected = { [1] = true, [3] = true }
    state.jokers = { "JOKER" }
    state.owned_cards = { { rank = "K", suit = "H" } }
    state.deck_cards = {
      { rank = 2, suit = "S" },
      { rank = 4, suit = "D" },
      { rank = "K", suit = "H" },
    }
    state.shop = {
      active = true,
      reroll_cost = 6,
      clear_event = "next_blind",
      offers = {
        [2] = { type = "joker", joker_key = "GREEDY_JOKER", price = 7, rarity = "uncommon" },
        [3] = { type = "card", card = { rank = 10, suit = "H" }, price = 5, rarity = "card" },
      },
    }
    state.message = "Round in progress"
    state.inventory = {
      schema = game.INVENTORY_SCHEMA,
      next_event_index = 3,
      jokers = state.jokers,
      deck_cards = state.deck_cards,
      owned_cards = state.owned_cards,
      ledger = { earned = 20, spent = 8 },
      history = {
        { index = 1, event = "blind_clear_payout", payload = { amount = 4 } },
        { index = 2, event = "shop_buy", payload = { price = 8 } },
      },
    }
    game.ensure_run_inventory(state)

    local save = store:save(state, {
      current_seed = "save-seed-1",
      run_stats = { total_score = 999, blind_clears = 2 },
      theme = "dark",
    })
    assert.is_true(save.ok)
    assert.are.equal(SaveLoad.SCHEMA_VERSION, save.schema_version)

    local loaded = store:load()
    assert.is_true(loaded.ok)
    assert.are.equal(SaveLoad.SCHEMA_VERSION, loaded.schema_version)
    assert.are.equal(2, loaded.state.ante)
    assert.are.equal(2, loaded.state.blind_index)
    assert.are.equal(123, loaded.state.score)
    assert.are.equal(45, loaded.state.money)
    assert.are.equal(3, loaded.state.hands)
    assert.are.equal(1, loaded.state.discards)
    assert.are.equal("Round in progress", loaded.state.message)
    assert.are.equal("save-seed-1", loaded.state.seed)
    assert.is_true(loaded.state.selected[1])
    assert.is_true(loaded.state.selected[3])
    assert.are.equal(1, #loaded.state.jokers)
    assert.are.equal("JOKER", loaded.state.jokers[1])
    assert.are.equal("GREEDY_JOKER", loaded.state.shop.offers[2].joker_key)
    assert.are.equal("card", loaded.state.shop.offers[3].type)
    assert.are.equal(20, loaded.state.inventory.ledger.earned)
    assert.are.equal(8, loaded.state.inventory.ledger.spent)
    assert.are.equal(2, #loaded.state.inventory.history)
    assert.is_true(loaded.state.inventory.jokers == loaded.state.jokers)
    assert.are.equal("save-seed-1", loaded.meta.current_seed)
    assert.are.equal("dark", loaded.meta.theme)
    assert.are.equal(999, loaded.meta.run_stats.total_score)
  end)

  it("migrates legacy payloads without schema_version", function()
    local fs = memory_fs()
    local store = SaveLoad.new({
      game = game,
      filesystem = fs,
      path = "saves/legacy.lua",
    })

    fs.write("saves/legacy.lua", [[
      return {
        state = {
          ante = 3,
          blind_index = 1,
          score = 77,
          money = 11,
          hands = 2,
          discards = 0,
          seed = "legacy-seed",
          deck = {},
          hand = {},
          selected = {},
          jokers = {},
          owned_cards = {},
          deck_cards = {}
        },
        meta = {
          note = "legacy"
        }
      }
    ]])

    local loaded = store:load()
    assert.is_true(loaded.ok)
    assert.are.equal(SaveLoad.SCHEMA_VERSION, loaded.schema_version)
    assert.are.equal(3, loaded.state.ante)
    assert.are.equal("legacy-seed", loaded.state.seed)
    assert.are.equal("legacy", loaded.meta.note)
  end)

  it("rejects future schema versions", function()
    local fs = memory_fs()
    local store = SaveLoad.new({
      game = game,
      filesystem = fs,
      path = "saves/future.lua",
    })

    fs.write("saves/future.lua", [[
      return {
        schema_version = 999,
        game_state = {}
      }
    ]])

    local loaded = store:load()
    assert.is_false(loaded.ok)
    assert.are.equal("migration_failed", loaded.reason)
  end)
end)
