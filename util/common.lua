blueprint_tool.TRANSLATOR = minetest.get_translator(blueprint_tool.MODNAME)

local BG_ASPECT = 1  -- background image width/height ratio

function blueprint_tool.fs_header(w, h, pos, anchor)
  local px = pos    and pos.x    or 0.5
  local py = pos    and pos.y    or 0.5
  local ax = anchor and anchor.x or 0.5
  local ay = anchor and anchor.y or 0.5

  local rw, rh
  if (w / h) > BG_ASPECT then
    rw = w
    rh = w / BG_ASPECT
  else
    rh = h
    rw = h * BG_ASPECT
  end

  return "formspec_version[4]size["..w..","..h.."]"..
    "position["..px..","..py.."]"..
    "anchor["..ax..","..ay.."]"..
    "no_prepend[]bgcolor[#00000000;neither]"..
    "image[0,0;"..rw..","..rh..";blueprint_formspec_bg.png]"..
    "style_type[button;bgimg=blueprint_button.png;bgimg_middle=6;border=false]"..
    "style_type[button:hovered;bgimg=blueprint_button_hovered.png]"..
    "style_type[button:pressed;bgimg=blueprint_button_pressed.png]"
end

blueprint_tool.COLOR_ACCENT = "#99FF99"
blueprint_tool.COLOR_WARN   = "#FF8800"

-- formspec-escaped translation
blueprint_tool.FTRANSLATOR = function(...)
  return minetest.formspec_escape(blueprint_tool.TRANSLATOR(...))
end

-- Wrapper around core.place_node that corrects for item_place_node's buildable_to
-- redirect. core.place_node hardcodes under = pos - {0,1,0}; if that block is
-- buildable_to, item_place_node redirects placement there instead of pos. This
-- function detects that case and passes pos + {0,1,0} so the redirect lands at pos.
function blueprint_tool.place_node(pos, node, placer)
  local below_pos = vector.new(pos.x, pos.y - 1, pos.z)
  local below_node = minetest.get_node_or_nil(below_pos)
  local below_def  = below_node and minetest.registered_nodes[below_node.name]
  local place_pos  = (below_def and below_def.buildable_to)
    and vector.new(pos.x, pos.y + 1, pos.z)
    or  pos
  blueprint_tool.load_position(place_pos)
  minetest.place_node(place_pos, node, placer)
end

function blueprint_tool.load_position(pos)
  if pos.x < -30912 or pos.y < -30912 or pos.z < -30912 or
     pos.x >  30927 or pos.y >  30927 or pos.z >  30927 then return end
  if minetest.get_node_or_nil(pos) then return pos end
  local vm = minetest.get_voxel_manip()
  vm:read_from_map(pos, pos)
  return pos
end

function blueprint_tool.swap_node(pos, newName)
  local node = minetest.get_node(pos)
  if node.name ~= newName then
    node.name = newName
    minetest.swap_node(pos, node)
  end
end

function blueprint_tool.set_infotext(pos, txt)
  local meta = minetest.get_meta(pos)
  meta:set_string("infotext", txt)
end

function blueprint_tool.clamp(v, min, max)
  if v < min then return min end
  if v > max then return max end
  return v
end

function blueprint_tool.round(x)
  if x >= 0 then return math.floor(x + 0.5) end
  return math.ceil(x - 0.5)
end

function blueprint_tool.table_is_empty(t)
  return t == nil or (next(t) == nil)
end

function blueprint_tool.table_map(t, func)
  local r = {}
  for k, v in pairs(t) do r[k] = func(v) end
  return r
end

function blueprint_tool.table_to_list_indexed(t, func)
  local r = {}
  local index = 0
  for k, v in pairs(t) do index = index + 1; r[index] = func(k, v, index) end
  return r
end

-- selectFunc(v) must return true to keep the element
function blueprint_tool.list_filter(t, selectFunc)
  local r = {}
  local index = 0
  for _, v in ipairs(t) do
    if selectFunc(v) then index = index + 1; r[index] = v end
  end
  return r
end

function blueprint_tool.random_chance(percent)
  return percent >= math.random(1, 100)
end

function blueprint_tool.format_count(n)
  if n >= 1000000 then
    local v = n / 1000000
    if v >= 10 then return math.floor(v + 0.5).."M" end
    return string.format("%.1f", v).."M"
  elseif n >= 1000 then
    local v = n / 1000
    if v >= 10 then return math.floor(v + 0.5).."k" end
    return string.format("%.1f", v).."k"
  end
  return tostring(n)
end

-- serialization helpers for inventories
function blueprint_tool.inv_list_to_table(list)
  local t = {}
  for k, v in ipairs(list) do t[k] = v and v:to_string() or "" end
  return t
end

function blueprint_tool.table_to_inv_list(t)
  local list = {}
  for k, v in ipairs(t) do
    list[k] = v == nil and ItemStack("") or ItemStack(v)
  end
  return list
end

function blueprint_tool.serialize_inv(inv)
  local lists = inv:get_lists()
  local invTable = {}
  for name, list in pairs(lists) do
    invTable[name] = blueprint_tool.inv_list_to_table(list)
  end
  return minetest.serialize(invTable)
end

function blueprint_tool.deserialize_inv(serializedInv)
  local strTable = minetest.deserialize(serializedInv)
  if not strTable then return {} end
  local liveTable = {}
  for name, listStrTable in pairs(strTable) do
    liveTable[name] = blueprint_tool.table_to_inv_list(listStrTable)
  end
  return liveTable
end

-- debug: table-to-string
function blueprint_tool.ttos(val, name, skipnewlines, depth)
  skipnewlines = skipnewlines ~= false
  depth = depth or 0
  local tmp = string.rep(" ", depth)
  local newline = skipnewlines and "" or "\n"
  if name then tmp = tmp..name.." = " end
  if type(val) == "table" then
    tmp = tmp.."{"..newline
    for k, v in pairs(val) do
      tmp = tmp..blueprint_tool.ttos(v, k, skipnewlines, depth + 1)..","..newline
    end
    tmp = tmp..string.rep(" ", depth).."}"
  elseif type(val) == "number" then tmp = tmp..tostring(val)
  elseif type(val) == "string" then tmp = tmp..string.format("%q", val)
  elseif type(val) == "boolean" then tmp = tmp..(val and "true" or "false")
  else tmp = tmp.."\"[unserializable:"..type(val).."]\"" end
  return tmp
end
