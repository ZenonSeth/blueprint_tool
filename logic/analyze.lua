local function get_display_name(node_name)
  return ItemStack(node_name):get_short_description() or node_name
end

local function build_sorted_list(counts)
  local list = {}
  for name, count in pairs(counts) do
    list[#list + 1] = { name = name, display_name = get_display_name(name), count = count }
  end
  table.sort(list, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.display_name < b.display_name
  end)
  return list
end

-- Walks the volume, respects protection, loads unloaded chunks.
-- Returns:
--   {
--     total_captured, total_skipped,
--     nodes     = sorted {name, display_name, count} for display,
--     raw_nodes = {offset, name, param2} list ready for capture,
--     size      = max - min vector,
--   }
-- or nil + error string.
function blueprint_tool.logic.analyze_selection(pos1, pos2, playerName)
  if not pos1 or not pos2 then return nil, "No selection set" end

  local can_bypass = playerName and
    minetest.check_player_privs(playerName, { allow_capture_protected = true })

  local min = vector.new(
    math.min(pos1.x, pos2.x), math.min(pos1.y, pos2.y), math.min(pos1.z, pos2.z))
  local max = vector.new(
    math.max(pos1.x, pos2.x), math.max(pos1.y, pos2.y), math.max(pos1.z, pos2.z))

  local counts     = {}
  local raw_nodes  = {}
  local total_captured = 0
  local total_skipped  = 0
  local total_liquid   = 0

  for x = min.x, max.x do
    for y = min.y, max.y do
      for z = min.z, max.z do
        local pos = vector.new(x, y, z)
        if not can_bypass and minetest.is_protected(pos, playerName) then
          total_skipped = total_skipped + 1
        else
          local node = minetest.get_node(pos)
          if node.name == "ignore" then
            blueprint_tool.load_position(pos)
            node = minetest.get_node(pos)
          end
          if node.name ~= "air" and node.name ~= "ignore" then
            counts[node.name] = (counts[node.name] or 0) + 1
            total_captured = total_captured + 1
            raw_nodes[#raw_nodes + 1] = {
              offset = vector.subtract(pos, min),
              name   = node.name,
              param2 = node.param2,
            }
            local def = minetest.registered_nodes[node.name]
            if def and def.liquidtype and def.liquidtype ~= "none" then
              total_liquid = total_liquid + 1
            end
          end
        end
      end
    end
  end

  return {
    total_captured = total_captured,
    total_skipped  = total_skipped,
    total_liquid   = total_liquid,
    nodes          = build_sorted_list(counts),
    raw_nodes      = raw_nodes,
    size           = vector.subtract(max, min),
  }
end

-- Analysis of an already-captured blueprint (display only, no raw_nodes needed).
function blueprint_tool.logic.analyze_blueprint(bp)
  local counts = {}
  local total_liquid = 0
  for _, entry in ipairs(bp.nodes) do
    counts[entry.name] = (counts[entry.name] or 0) + 1
    local def = minetest.registered_nodes[entry.name]
    if def and def.liquidtype and def.liquidtype ~= "none" then
      total_liquid = total_liquid + 1
    end
  end
  return {
    total_captured = #bp.nodes,
    total_skipped  = 0,
    total_liquid   = total_liquid,
    nodes          = build_sorted_list(counts),
  }
end
