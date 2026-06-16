-- All persistent state lives here.
--
-- Key scheme:
--   "next_bp_id"    -> integer counter (string)
--   "bp_<id>"       -> minetest.serialize(bp)
--   "player_index"  -> minetest.serialize({ [name] = last_login_timestamp })
--   "player_<name>" -> minetest.serialize({ slots = {[index]={name,bp_id}} })

local ms = minetest.get_mod_storage()

local blueprints    = {}  -- id -> bp (write-through cache)
local next_bp_id    = tonumber(ms:get_string("next_bp_id")) or 1
local player_index  = {}  -- playerName -> last_login_timestamp
local player_data   = {}  -- playerName -> { slots = {[index] = {name, bp_id}} } (online only)

do
  local str = ms:get_string("player_index")
  if str ~= "" then
    player_index = minetest.deserialize(str) or {}
  end
end

local function save_next_id()
  ms:set_string("next_bp_id", tostring(next_bp_id))
end

local function save_index()
  ms:set_string("player_index", minetest.serialize(player_index))
end

local function load_player(playerName)
  local str = ms:get_string("player_" .. playerName)
  if str ~= "" then
    player_data[playerName] = minetest.deserialize(str) or { slots = {} }
  else
    player_data[playerName] = { slots = {} }
  end
end

local function save_player(playerName)
  local data = player_data[playerName]
  if data then
    ms:set_string("player_" .. playerName, minetest.serialize(data))
  end
end

local function ensure_player(playerName)
  if not player_data[playerName] then
    load_player(playerName)
  end
end

----------------------------------------------------------------
-- Join / leave hooks
----------------------------------------------------------------

minetest.register_on_joinplayer(function(player)
  local name = player:get_player_name()
  player_index[name] = os.time()
  save_index()
  load_player(name)
end)

minetest.register_on_leaveplayer(function(player)
  local name = player:get_player_name()
  save_player(name)
  player_data[name] = nil
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
  ensure_player(playerName)
  return player_data[playerName].slots[index]
end

function blueprint_tool.storage.set_player_slot(playerName, index, slot)
  ensure_player(playerName)
  player_data[playerName].slots[index] = slot
  save_player(playerName)
end

function blueprint_tool.storage.clear_player_slot(playerName, index)
  ensure_player(playerName)
  player_data[playerName].slots[index] = nil
  save_player(playerName)
end

function blueprint_tool.storage.get_player_slots(playerName)
  ensure_player(playerName)
  return player_data[playerName].slots
end

function blueprint_tool.storage.count_used_slots(playerName)
  ensure_player(playerName)
  local count = 0
  for _, slot in pairs(player_data[playerName].slots) do
    if slot ~= nil then count = count + 1 end
  end
  return count
end

function blueprint_tool.storage.get_players_with_blueprints()
  local result = {}
  for name in pairs(player_index) do
    ensure_player(name)
    for _, slot in pairs(player_data[name].slots) do
      if slot and slot.bp_id then
        result[#result + 1] = name
        break
      end
    end
  end
  table.sort(result)
  return result
end

function blueprint_tool.storage.get_next_empty_slot(playerName, limit)
  ensure_player(playerName)
  local slots = player_data[playerName].slots
  for i = 1, limit do
    if slots[i] == nil then return i end
  end
  return nil
end

----------------------------------------------------------------
-- Clear operations
----------------------------------------------------------------

function blueprint_tool.storage.clear_player(playerName)
  ensure_player(playerName)
  for _, slot in pairs(player_data[playerName].slots) do
    if slot and slot.bp_id then
      blueprint_tool.storage.delete_blueprint(slot.bp_id)
    end
  end
  player_data[playerName].slots = {}
  save_player(playerName)
end

function blueprint_tool.storage.clear_all()
  for _, key in ipairs(ms:get_keys()) do
    ms:set_string(key, "")
  end
  blueprints   = {}
  player_index = {}
  player_data  = {}
  next_bp_id   = 1
  save_next_id()
end
