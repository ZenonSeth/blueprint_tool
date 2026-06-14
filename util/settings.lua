blueprint_tool.settings = {}

local function L(key) return "blueprint_tool_"..key end

local function get_int(key, default, min, max)
  local val = tonumber(minetest.settings:get(L(key))) or default
  if min then val = math.max(min, val) end
  if max then val = math.min(max, val) end
  return val
end

local function get_bool(key, default)
  local raw = minetest.settings:get(L(key))
  if raw == nil then return default end
  return raw == "true"
end

blueprint_tool.settings.max_size_x      = get_int("max_size_x",      32, 1, 128)
blueprint_tool.settings.max_size_y      = get_int("max_size_y",      32, 1, 128)
blueprint_tool.settings.max_size_z      = get_int("max_size_z",      32, 1, 128)
blueprint_tool.settings.nodes_per_tick  = get_int("nodes_per_tick",   8, 1, 100)
blueprint_tool.settings.default_slots   = get_int("default_slots",   10, 1, 128)
blueprint_tool.settings.more_slots      = get_int("more_slots",      100, 1, 500)
blueprint_tool.settings.even_more_slots = get_int("even_more_slots", 500, 1, 10000)
-- When true (default), all players may use blueprint tools without needing basic_blueprints priv.
-- Set to false to require explicit priv grants.
blueprint_tool.settings.open_access     = get_bool("open_access", true)
