-- Blueprint paste logic.
-- active_placements[playerName] = current task (at most one per player)
-- last_paste_result[playerName] = result of last finished/cancelled paste (in-memory only)

local active_placements = {}
local last_paste_result = {}

----------------------------------------------------------------
-- Virtual tool for estimating dig times
----------------------------------------------------------------

local VIRTUAL_TOOL = {
  full_punch_interval = 1.0,
  max_drop_level = 3,
  groupcaps = {
    cracky  = { maxlevel = 3, uses = 0, times = { [1] = 1.00, [2] = 0.50, [3] = 0.25 } },
    crumbly = { maxlevel = 3, uses = 0, times = { [1] = 0.75, [2] = 0.45, [3] = 0.25 } },
    choppy  = { maxlevel = 3, uses = 0, times = { [1] = 1.10, [2] = 0.70, [3] = 0.40 } },
    snappy  = { maxlevel = 3, uses = 0, times = { [1] = 0.25, [2] = 0.15, [3] = 0.10 } },
    oddly_breakable_by_hand = { maxlevel = 3, uses = 0, times = { [1] = 1.50, [2] = 0.75, [3] = 0.25 } },
  },
}

local ROTATIONAL_PARAM2 = {
  facedir = true, ["4dir"] = true, wallmounted = true, degrotate = true,
  colorfacedir = true, color4dir = true, colorwallmounted = true,
}

local DIG_COOLDOWN_DEFAULT = 0.5

local function get_dig_cooldown(node_name)
  local def = minetest.registered_nodes[node_name]
  if not def or not def.groups then return DIG_COOLDOWN_DEFAULT end
  local params = minetest.get_dig_params(def.groups, VIRTUAL_TOOL)
  if params.diggable and params.time > 0 then
    return params.time
  end
  return DIG_COOLDOWN_DEFAULT
end

----------------------------------------------------------------
-- nodes-per-tick calculation
-- Goal: place whole horizontal layers (x*z footprint) per tick so
-- the build grows cleanly bottom-to-top.
-- Cap is blueprint_tool.settings.nodes_per_tick (admin-configurable).
----------------------------------------------------------------

local function compute_nodes_per_tick(bp)
  local cap  = blueprint_tool.settings.nodes_per_tick
  -- size is stored as max-min (a 1-wide blueprint has size.x=0), so add 1 for node counts.
  local base = math.max(1, (bp.size.x + 1) * (bp.size.z + 1))
  -- Whole layer fits within cap: place one full layer per tick.
  if base <= cap then return base end
  -- Find largest clean divisor of base within cap.
  for k = cap, 2, -1 do
    if base % k == 0 then return k end
  end
  -- Fallback for prime (or otherwise indivisible) base > cap:
  -- find smallest d where ceil(base/d) <= cap. Last chunk of each layer will
  -- be smaller (remainder), but most chunks are equal.
  local d = 2
  while math.ceil(base / d) > cap do
    d = d + 1
  end
  return math.ceil(base / d)
end

----------------------------------------------------------------
-- Inventory helper
----------------------------------------------------------------

local function has_bypass(player)
  local name = player:get_player_name()
  return minetest.check_player_privs(name, { give = true }) or
         minetest.check_player_privs(name, { creative_mode = true })
end

-- Removes one unit of node_name from inventory. Always succeeds for creative/give players.
function blueprint_tool.logic.take_item(player, node_name)
  if has_bypass(player) then return true end
  local inv   = player:get_inventory()
  local stack = ItemStack(node_name .. " 1")
  if inv:contains_item("main", stack) then
    inv:remove_item("main", stack)
    return true
  end
  return false
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

function blueprint_tool.logic.get_paste_task(playerName)
  return active_placements[playerName]
end

function blueprint_tool.logic.get_last_paste_result(playerName)
  return last_paste_result[playerName]
end

-- Starts a paste task. Returns true, or nil + error string.
-- angle: Y-axis rotation in degrees (0/90/180/270), default 0.
function blueprint_tool.logic.start_paste(playerName, bp, origin, angle)
  if active_placements[playerName] then
    return nil, "A placement is already in progress"
  end

  angle = (angle or 0) % 360

  -- Build rotated node list, sorted bottom-to-top.
  local nodes = {}
  for _, entry in ipairs(bp.nodes) do
    local new_offset, _ = blueprint_tool.logic.rotate_offset(entry.offset, angle, bp.size)
    local new_param2 = blueprint_tool.logic.rotate_param2(entry.name, entry.param2, angle)
    nodes[#nodes + 1] = { offset = new_offset, name = entry.name, param2 = new_param2 }
  end
  table.sort(nodes, function(a, b) return a.offset.y < b.offset.y end)

  active_placements[playerName] = {
    bp     = bp,
    origin = origin,
    nodes  = nodes,
    index  = 1,
    npt    = compute_nodes_per_tick(bp),
  }

  last_paste_result[playerName] = {
    placed            = 0,
    skipped_protected = 0,
    skipped_no_item   = {},  -- node_name -> count
    unknown_nodes     = {},  -- node_name -> count
    cannot_dig        = {},  -- node_name -> count
    cancelled         = false,
  }

  return true
end

-- Cancels the player's active task.
-- Pass save_result=true to mark the partial result as cancelled (e.g. via chat command).
-- Pass save_result=false/nil to discard the result entirely (e.g. on logout).
function blueprint_tool.logic.cancel_paste(playerName, save_result)
  if not active_placements[playerName] then return end
  active_placements[playerName] = nil
  if save_result and last_paste_result[playerName] then
    last_paste_result[playerName].cancelled = true
  else
    last_paste_result[playerName] = nil
  end
end

----------------------------------------------------------------
-- Globalstep: process active placements
----------------------------------------------------------------

minetest.register_globalstep(function(dtime)
  for playerName, task in pairs(active_placements) do
    -- Re-fetch player at the start of each batch; cancel silently if offline.
    local player = minetest.get_player_by_name(playerName)
    if not player then
      active_placements[playerName] = nil
    else
      -- Dig cooldown: wait out remaining time before resuming placement.
      if task.dig_cooldown and task.dig_cooldown > 0 then
        task.dig_cooldown = task.dig_cooldown - dtime
        goto next_player
      end

      local result = last_paste_result[playerName]
      local count  = 0

      while count < task.npt and task.index <= #task.nodes do
        local entry    = task.nodes[task.index]
        local dest_pos = vector.add(task.origin, entry.offset)
        task.index = task.index + 1
        count = count + 1

        -- 1. Unknown/unregistered node: skip and record by name.
        if not minetest.registered_nodes[entry.name] then
          result.unknown_nodes[entry.name] = (result.unknown_nodes[entry.name] or 0) + 1
          goto continue
        end

        -- 2. Protection check (re-evaluated at place-time, not just at analysis time).
        if minetest.is_protected(dest_pos, playerName) then
          result.skipped_protected = result.skipped_protected + 1
          goto continue
        end

        -- 3. Load chunk if not yet in memory.
        local dest_node = minetest.get_node(dest_pos)
        if dest_node.name == "ignore" then
          blueprint_tool.load_position(dest_pos)
          dest_node = minetest.get_node(dest_pos)
        end

        -- 4. Already correct: fix param2 if needed (rotation), no dig or item consumed.
        if dest_node.name == entry.name then
          if dest_node.param2 ~= entry.param2 then
            local pt2 = (minetest.registered_nodes[entry.name] or {}).paramtype2 or ""
            if ROTATIONAL_PARAM2[pt2] then
              minetest.swap_node(dest_pos, { name = entry.name, param2 = entry.param2 })
            end
          end
          goto continue
        end

        -- 5. Solid node checks: skip without consuming an item if we can't clear the way.
        local dest_def = minetest.registered_nodes[dest_node.name]
        if dest_def and not dest_def.buildable_to then
          if not blueprint_tool.settings.allow_placer_dig then
            result.needs_digging = (result.needs_digging or 0) + 1
            goto continue
          end
          if not blueprint_tool.logic.is_diggable(dest_def) then
            goto continue
          end
          local dig_params = minetest.get_dig_params(dest_def.groups or {}, VIRTUAL_TOOL)
          if not dig_params.diggable then
            result.cannot_dig[dest_node.name] = (result.cannot_dig[dest_node.name] or 0) + 1
            goto continue
          end
          if dest_def.can_dig and not dest_def.can_dig(dest_pos, player) then
            result.cannot_dig[dest_node.name] = (result.cannot_dig[dest_node.name] or 0) + 1
            goto continue
          end
        end

        -- 6. Inventory check: consume item before modifying the world.
        if not blueprint_tool.logic.take_item(player, entry.name) then
          result.skipped_no_item[entry.name] = (result.skipped_no_item[entry.name] or 0) + 1
          goto continue
        end

        -- 7. Dig existing solid node; creative/give players get no drops.
        local did_dig = false
        if dest_def and not dest_def.buildable_to then
          did_dig = true
          if has_bypass(player) then
            minetest.remove_node(dest_pos)
          else
            local drops = minetest.get_node_drops(dest_node.name, "")
            minetest.remove_node(dest_pos)
            local inv = player:get_inventory()
            for _, drop in ipairs(drops) do
              local leftover = inv:add_item("main", drop)
              if not leftover:is_empty() then
                minetest.add_item(player:get_pos(), leftover)
              end
            end
          end
        end

        -- 8. Place the node (fires on_construct, after_place_node, etc.).
        blueprint_tool.place_node(dest_pos, { name = entry.name, param2 = entry.param2 }, player)
        -- after_place_node callbacks (e.g. stairs) may override param2 with the player's
        -- facing direction, so force the correct value back in immediately.
        minetest.swap_node(dest_pos, { name = entry.name, param2 = entry.param2 })
        result.placed = result.placed + 1

        -- After digging+placing, enter cooldown based on the dug node's dig time.
        if did_dig then
          task.dig_cooldown = get_dig_cooldown(dest_node.name)
          break
        end

        ::continue::
      end

      if task.index > #task.nodes then
        active_placements[playerName] = nil
        blueprint_tool.show_popup(playerName,
          "Placement finished! " .. result.placed .. " node(s) placed.")
      end
    end
    ::next_player::
  end
end)

----------------------------------------------------------------
-- Preview helpers
----------------------------------------------------------------

local NEIGHBORS = {
  vector.new( 1, 0, 0), vector.new(-1, 0, 0),
  vector.new( 0, 1, 0), vector.new( 0,-1, 0),
  vector.new( 0, 0, 1), vector.new( 0, 0,-1),
}

local exposed_cache = {}  -- [playerName] = {bp_id, offsets}

----------------------------------------------------------------
-- Cleanup on logout: discard task and result (player can re-place at same origin)
----------------------------------------------------------------

minetest.register_on_leaveplayer(function(objRef)
  if objRef:is_player() then
    local name = objRef:get_player_name()
    active_placements[name] = nil
    last_paste_result[name] = nil
    exposed_cache[name] = nil
  end
end)

----------------------------------------------------------------
-- /blueprint_cancel: lets players abort a stuck or unwanted placement
----------------------------------------------------------------

-- Returns a list of offsets (relative to blueprint origin) for non-air nodes
-- that have at least one air or out-of-bounds neighbor.
function blueprint_tool.logic.get_exposed_offsets(playerName, bp_id, bp)
  local cached = exposed_cache[playerName]
  if cached and cached.bp_id == bp_id then return cached.offsets end

  local solid = {}
  for _, entry in ipairs(bp.nodes) do
    if entry.name ~= "air" then
      solid[minetest.pos_to_string(entry.offset)] = true
    end
  end

  local result = {}
  for _, entry in ipairs(bp.nodes) do
    if entry.name ~= "air" then
      for _, dir in ipairs(NEIGHBORS) do
        if not solid[minetest.pos_to_string(vector.add(entry.offset, dir))] then
          result[#result + 1] = entry.offset
          break
        end
      end
    end
  end

  exposed_cache[playerName] = {bp_id = bp_id, offsets = result}
  return result
end

----------------------------------------------------------------
-- Preview: spawn one particle per non-air node at its world position
----------------------------------------------------------------

function blueprint_tool.logic.show_preview(playerName, bp_id, bp, origin, angle)
  angle = (angle or 0) % 360
  local offsets = blueprint_tool.logic.get_exposed_offsets(playerName, bp_id, bp)
  for _, raw_offset in ipairs(offsets) do
    local offset    = blueprint_tool.logic.rotate_offset(raw_offset, angle, bp.size)
    local world_pos = vector.add(origin, offset)
    minetest.add_particle({
      pos            = vector.add(world_pos, vector.new(0.5, 0.5, 0.5)),
      velocity       = vector.new(0, 0, 0),
      acceleration   = vector.new(0, 0, 0),
      expirationtime = 5,
      size           = 10,
      vertical       = true,
      texture        = "blueprint_preview_part.png",
      playername     = playerName,
      glow           = 5,
    })
  end
end

minetest.register_chatcommand("blueprint_cancel", {
  description = "Cancel your active blueprint placement",
  func = function(name, param)
    if active_placements[name] then
      blueprint_tool.logic.cancel_paste(name, true)
      return true, "Blueprint placement cancelled."
    else
      return false, "No active placement to cancel."
    end
  end,
})
