local defaults = require("config.tunables")

local Config = {}

local function deep_copy(value)
  if type(value) ~= "table" then
    return value
  end
  local out = {}
  for k, v in pairs(value) do
    out[k] = deep_copy(v)
  end
  return out
end

local function deep_merge(base, override)
  if type(base) ~= "table" or type(override) ~= "table" then
    return deep_copy(override)
  end
  local out = deep_copy(base)
  for key, value in pairs(override) do
    if type(value) == "table" and type(out[key]) == "table" then
      out[key] = deep_merge(out[key], value)
    else
      out[key] = deep_copy(value)
    end
  end
  return out
end

function Config.defaults()
  return deep_copy(defaults)
end

function Config.load(overrides)
  local base = Config.defaults()
  if type(overrides) == "table" then
    return deep_merge(base, overrides)
  end
  return base
end

return Config
