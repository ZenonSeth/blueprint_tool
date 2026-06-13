blueprint_tool.settings = {}

local function L(key) return "blueprint_tool_"..key end

local function get_int(key, default, min, max)
  local val = tonumber(minetest.settings:get(L(key))) or default
  if min then val = math.max(min, val) end
  if max then val = math.min(max, val) end
  return val
end

blueprint_tool.settings.max_size_x      = get_int("max_size_x",      32, 1, 128)
blueprint_tool.settings.max_size_y      = get_int("max_size_y",      32, 1, 128)
blueprint_tool.settings.max_size_z      = get_int("max_size_z",      32, 1, 128)
blueprint_tool.settings.nodes_per_tick  = get_int("nodes_per_tick",   8, 1, 100)
blueprint_tool.settings.default_slots   = get_int("default_slots",   10, 1, 128)
blueprint_tool.settings.more_slots      = get_int("more_slots",      100, 1, 500)
blueprint_tool.settings.even_more_slots = get_int("even_more_slots", 500, 1, 10000)
