-- Blueprint paste logic.
-- active_placements[playerName] = current task (at most one per player)
-- last_paste_result[playerName] = result of last finished/cancelled paste (in-memory only)

local active_placements = {}
local last_paste_result = {}

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
function blueprint_tool.logic.start_paste(playerName, bp, origin)
  if active_placements[playerName] then
    return nil, "A placement is already in progress"
  end

  -- Copy and sort nodes bottom-to-top by Y offset.
  local nodes = {}
  for i, entry in ipairs(bp.nodes) do nodes[i] = entry end
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
    local player = minetest.get_player_by_name(playerName)
    if not player then
      -- Player logged out between ticks: cancel silently.
      active_placements[playerName] = nil
    else
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

        -- 4. Already correct: nothing to do, don't consume an item.
        if dest_node.name == entry.name then
          goto continue
        end

        -- 5. Undiggable solid: cannot clear the way, skip without consuming an item.
        local dest_def = minetest.registered_nodes[dest_node.name]
        if dest_def and not dest_def.buildable_to
           and not blueprint_tool.logic.is_diggable(dest_def) then
          goto continue
        end

        -- 6. Inventory check: consume item before modifying the world.
        if not blueprint_tool.logic.take_item(player, entry.name) then
          result.skipped_no_item[entry.name] = (result.skipped_no_item[entry.name] or 0) + 1
          goto continue
        end

        -- 7. Dig existing solid node.
        if dest_def and not dest_def.buildable_to then
          minetest.remove_node(dest_pos)
        end

        -- 8. Place the node.
        minetest.set_node(dest_pos, { name = entry.name, param2 = entry.param2 })
        result.placed = result.placed + 1

        ::continue::
      end

      if task.index > #task.nodes then
        active_placements[playerName] = nil
        blueprint_tool.show_popup(playerName,
          "Placement finished! " .. result.placed .. " node(s) placed.")
      end
    end
  end
end)

----------------------------------------------------------------
-- Cleanup on logout: discard task and result (player can re-place at same origin)
----------------------------------------------------------------

minetest.register_on_leaveplayer(function(objRef)
  if objRef:is_player() then
    local name = objRef:get_player_name()
    active_placements[name] = nil
    last_paste_result[name] = nil
  end
end)

----------------------------------------------------------------
-- /blueprint_cancel: lets players abort a stuck or unwanted placement
----------------------------------------------------------------

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
