-- All persistent state lives here. Swap this file's internals to add mod_storage/DB later.

local blueprints = {}
local next_bp_id = 1

-- [playerName] = array of slots, each slot is nil (empty) or {name=string, bp_id=int}
local player_slots = {}

----------------------------------------------------------------
-- Blueprints
----------------------------------------------------------------

function blueprint_tool.storage.store_blueprint(bp)
  local id = next_bp_id
  next_bp_id = next_bp_id + 1
  blueprints[id] = bp
  return id
end

function blueprint_tool.storage.get_blueprint(id)
  return blueprints[id]
end

function blueprint_tool.storage.delete_blueprint(id)
  blueprints[id] = nil
end

----------------------------------------------------------------
-- Player slots
----------------------------------------------------------------

local function ensure_player(playerName)
  if not player_slots[playerName] then
    player_slots[playerName] = {}
  end
end

function blueprint_tool.storage.get_player_slot(playerName, index)
  if not player_slots[playerName] then return nil end
  return player_slots[playerName][index]
end

function blueprint_tool.storage.set_player_slot(playerName, index, slot)
  ensure_player(playerName)
  player_slots[playerName][index] = slot
end

function blueprint_tool.storage.clear_player_slot(playerName, index)
  if not player_slots[playerName] then return end
  player_slots[playerName][index] = nil
end

function blueprint_tool.storage.get_player_slots(playerName)
  return player_slots[playerName] or {}
end

function blueprint_tool.storage.count_used_slots(playerName)
  local slots = player_slots[playerName]
  if not slots then return 0 end
  local count = 0
  for _, slot in pairs(slots) do
    if slot ~= nil then count = count + 1 end
  end
  return count
end

-- Returns the index of the first empty slot within limit, or nil if all full.
function blueprint_tool.storage.get_next_empty_slot(playerName, limit)
  local slots = player_slots[playerName] or {}
  for i = 1, limit do
    if slots[i] == nil then return i end
  end
  return nil
end
