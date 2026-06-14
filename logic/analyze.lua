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

local function is_diggable(def)
  if not def then return false end
  local g = def.groups or {}
  return (g.cracky or 0) > 0 or (g.crumbly or 0) > 0
      or (g.choppy or 0) > 0 or (g.snappy  or 0) > 0
end

-- Exposed for use by paste logic to check the same condition at place-time.
function blueprint_tool.logic.is_diggable(def)
  return is_diggable(def)
end

local function count_inventory(playerName)
  local counts = {}
  local player = minetest.get_player_by_name(playerName)
  if not player then return counts end
  for _, stack in ipairs(player:get_inventory():get_list("main") or {}) do
    if not stack:is_empty() then
      local name = stack:get_name()
      counts[name] = (counts[name] or 0) + stack:get_count()
    end
  end
  return counts
end

-- Analyses what placing bp at origin would do to the world.
-- Only call when both bp and origin are known.
-- Returns:
--   {
--     protected        = N,   -- blueprint positions blocked by protection
--     already_correct  = N,   -- destination already has the right node (param2 TBD)
--     will_be_replaced = N,   -- buildable_to destination, not air (informational)
--     needs_digging    = N,   -- solid node that can be dug
--     undiggable       = N,   -- solid node with no standard dig groups (warning)
--     will_place       = N,   -- nodes player can actually place (has in inv / creative)
--     missing          = N,   -- nodes needed but not in inventory
--     missing_nodes    = sorted {name, display_name, count},
--     inventory_skipped = bool,  -- true when give/creative_mode bypassed inventory check
--   }
function blueprint_tool.logic.analyze_placement(bp, origin, playerName)
  local protected       = 0
  local already_correct = 0
  local will_be_replaced = 0
  local needs_digging   = 0
  local undiggable      = 0
  local needed          = {}  -- name -> count needed from inventory

  for _, entry in ipairs(bp.nodes) do
    local dest_pos = vector.add(origin, entry.offset)

    -- 1. Protected: also blocks param2 adjustment, so checked before already_correct.
    if minetest.is_protected(dest_pos, playerName) then
      protected = protected + 1
      goto continue
    end

    local dest_node = minetest.get_node(dest_pos)
    if dest_node.name == "ignore" then
      blueprint_tool.load_position(dest_pos)
      dest_node = minetest.get_node(dest_pos)
    end

    -- 2. Already correct.
    -- TODO: also compare param2 once rotation/param2 adjustment is implemented.
    if dest_node.name == entry.name then
      already_correct = already_correct + 1
      goto continue
    end

    local dest_def = minetest.registered_nodes[dest_node.name]

    -- 3. Buildable_to: safely overwritable (air, liquids, etc.).
    if dest_def and dest_def.buildable_to then
      if dest_node.name ~= "air" then
        will_be_replaced = will_be_replaced + 1
      end
      needed[entry.name] = (needed[entry.name] or 0) + 1
      goto continue
    end

    -- 4. Solid node: diggable or undiggable.
    if is_diggable(dest_def) then
      needs_digging = needs_digging + 1
      needed[entry.name] = (needed[entry.name] or 0) + 1
    else
      undiggable = undiggable + 1
      -- won't attempt to place, so no inventory needed
    end

    ::continue::
  end

  -- 5. Inventory check.
  local has_bypass = playerName and (
    minetest.check_player_privs(playerName, { give          = true }) or
    minetest.check_player_privs(playerName, { creative_mode = true })
  )

  local will_place   = 0
  local missing      = 0
  local missing_nodes = {}

  if has_bypass then
    for _, count in pairs(needed) do
      will_place = will_place + count
    end
  else
    local inv = count_inventory(playerName)
    for name, count in pairs(needed) do
      local have      = inv[name] or 0
      local placeable = math.min(have, count)
      local absent    = count - placeable
      will_place = will_place + placeable
      if absent > 0 then
        missing = missing + absent
        missing_nodes[#missing_nodes + 1] = {
          name         = name,
          display_name = get_display_name(name),
          count        = absent,
        }
      end
    end
    table.sort(missing_nodes, function(a, b)
      if a.count ~= b.count then return a.count > b.count end
      return a.display_name < b.display_name
    end)
  end

  return {
    protected         = protected,
    already_correct   = already_correct,
    will_be_replaced  = will_be_replaced,
    needs_digging     = needs_digging,
    undiggable        = undiggable,
    will_place        = will_place,
    missing           = missing,
    missing_nodes     = missing_nodes,
    inventory_skipped = has_bypass,
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
