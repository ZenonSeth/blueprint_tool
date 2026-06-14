-- All persistent state lives here.
-- Blueprints are stored as serialized strings in mod_storage.
-- Player slot tables are serialized per player and loaded on join.
--
-- Key scheme:
--   "next_bp_id"          -> integer counter (string)
--   "bp_<id>"             -> minetest.serialize(bp)
--   "player_slots_<name>" -> minetest.serialize(slots_array)

local ms = minetest.get_mod_storage()

local blueprints  = {}  -- id -> bp (write-through cache)
local next_bp_id  = tonumber(ms:get_string("next_bp_id")) or 1
local player_slots = {}  -- playerName -> array[index] = {name, bp_id} or nil

----------------------------------------------------------------
-- Internal helpers
----------------------------------------------------------------

local function save_next_id()
  ms:set_string("next_bp_id", tostring(next_bp_id))
end

local function save_player_slots(playerName)
  local slots = player_slots[playerName]
  if slots then
    ms:set_string("player_slots_" .. playerName, minetest.serialize(slots))
  else
    ms:set_string("player_slots_" .. playerName, "")
  end
end

local function load_player_slots(playerName)
  local str = ms:get_string("player_slots_" .. playerName)
  if str == "" then
    player_slots[playerName] = {}
  else
    player_slots[playerName] = minetest.deserialize(str) or {}
  end
end

local function ensure_player_loaded(playerName)
  if not player_slots[playerName] then
    load_player_slots(playerName)
  end
end

----------------------------------------------------------------
-- Join / leave hooks
----------------------------------------------------------------

minetest.register_on_joinplayer(function(player)
  load_player_slots(player:get_player_name())
end)

minetest.register_on_leaveplayer(function(player)
  local name = player:get_player_name()
  save_player_slots(name)
  player_slots[name] = nil
end)

----------------------------------------------------------------
-- Blueprints
----------------------------------------------------------------

function blueprint_tool.storage.store_blueprint(bp)
  local id = next_bp_id
  next_bp_id = next_bp_id + 1
  blueprints[id] = bp
  ms:set_string("bp_" .. id, minetest.serialize(bp))
  save_next_id()
  return id
end

function blueprint_tool.storage.get_blueprint(id)
  if blueprints[id] then return blueprints[id] end
  local str = ms:get_string("bp_" .. id)
  if not str or str == "" then return nil end
  local bp = minetest.deserialize(str)
  if bp then blueprints[id] = bp end
  return bp
end

function blueprint_tool.storage.delete_blueprint(id)
  blueprints[id] = nil
  ms:set_string("bp_" .. id, "")
end

----------------------------------------------------------------
-- Player slots
----------------------------------------------------------------

function blueprint_tool.storage.get_player_slot(playerName, index)
  ensure_player_loaded(playerName)
  return player_slots[playerName][index]
end

function blueprint_tool.storage.set_player_slot(playerName, index, slot)
  ensure_player_loaded(playerName)
  player_slots[playerName][index] = slot
  save_player_slots(playerName)
end

function blueprint_tool.storage.clear_player_slot(playerName, index)
  ensure_player_loaded(playerName)
  player_slots[playerName][index] = nil
  save_player_slots(playerName)
end

function blueprint_tool.storage.get_player_slots(playerName)
  ensure_player_loaded(playerName)
  return player_slots[playerName] or {}
end

function blueprint_tool.storage.count_used_slots(playerName)
  ensure_player_loaded(playerName)
  local slots = player_slots[playerName]
  if not slots then return 0 end
  local count = 0
  for _, slot in pairs(slots) do
    if slot ~= nil then count = count + 1 end
  end
  return count
end

function blueprint_tool.storage.get_next_empty_slot(playerName, limit)
  ensure_player_loaded(playerName)
  local slots = player_slots[playerName] or {}
  for i = 1, limit do
    if slots[i] == nil then return i end
  end
  return nil
end

----------------------------------------------------------------
-- Clear operations (used by /blueprint_clear and /blueprint_clear_all)
----------------------------------------------------------------

-- Deletes all slots and blueprints belonging to one player.
function blueprint_tool.storage.clear_player(playerName)
  ensure_player_loaded(playerName)
  local slots = player_slots[playerName] or {}
  for _, slot in pairs(slots) do
    if slot and slot.bp_id then
      blueprint_tool.storage.delete_blueprint(slot.bp_id)
    end
  end
  player_slots[playerName] = {}
  ms:set_string("player_slots_" .. playerName, "")
end

-- Deletes ALL player slots and blueprints from storage.
-- Intended for /blueprint_clear_all (blueprint_admin priv only).
function blueprint_tool.storage.clear_all()
  -- Wipe every key we own.
  for _, key in ipairs(ms:get_keys()) do
    ms:set_string(key, "")
  end
  blueprints   = {}
  player_slots = {}
  next_bp_id   = 1
  save_next_id()
end
