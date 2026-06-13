blueprint_tool.TRANSLATOR = minetest.get_translator(blueprint_tool.MODNAME)

-- formspec-escaped translation
blueprint_tool.FTRANSLATOR = function(...)
    return minetest.formspec_escape(blueprint_tool.TRANSLATOR(...))
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
