local POSITION_EXPIRY = 3600  -- 1 hour in seconds

local function clamp_to_anchor(anchor, other)
  local s = blueprint_tool.settings
  local limits = { x = s.max_size_x, y = s.max_size_y, z = s.max_size_z }
  local adjusted = vector.copy(other)
  for _, axis in ipairs({"x", "y", "z"}) do
    local diff = other[axis] - anchor[axis]
    local limit = limits[axis] - 1
    if diff > limit then
      adjusted[axis] = anchor[axis] + limit
    elseif diff < -limit then
      adjusted[axis] = anchor[axis] - limit
    end
  end
  return adjusted
end

local function meta_get_pos(itemstack, key)
  local meta = itemstack:get_meta()
  local s = meta:get_string(key)
  if s == "" then return nil end
  local t = meta:get_int(key.."_time")
  if t > 0 and (os.time() - t) > POSITION_EXPIRY then return nil end
  return minetest.string_to_pos(s)
end

local function meta_set_pos(itemstack, key, pos)
  local meta = itemstack:get_meta()
  meta:set_string(key, minetest.pos_to_string(pos))
  meta:set_int(key.."_time", os.time())
end

local function meta_clear_pos(itemstack, key)
  local meta = itemstack:get_meta()
  meta:set_string(key, "")
  meta:set_int(key.."_time", 0)
end

function blueprint_tool.logic.get_selection(itemstack)
  return meta_get_pos(itemstack, "pos1"), meta_get_pos(itemstack, "pos2")
end

function blueprint_tool.logic.clear_pos1(itemstack)
  meta_clear_pos(itemstack, "pos1")
end

function blueprint_tool.logic.clear_pos2(itemstack)
  meta_clear_pos(itemstack, "pos2")
end

function blueprint_tool.logic.set_raw_selection(itemstack, pos1, pos2)
  meta_set_pos(itemstack, "pos1", pos1)
  meta_set_pos(itemstack, "pos2", pos2)
end

-- Returns final pos1 (possibly clamped), whether it was adjusted, and the modified itemstack.
function blueprint_tool.logic.set_pos1(itemstack, pos)
  local _, pos2 = blueprint_tool.logic.get_selection(itemstack)
  local final = vector.copy(pos)
  local adjusted = false
  if pos2 then
    local clamped = clamp_to_anchor(pos2, pos)
    if not vector.equals(clamped, pos) then
      final = clamped
      adjusted = true
    end
  end
  meta_set_pos(itemstack, "pos1", final)
  return final, adjusted
end

-- Returns final pos2 (possibly clamped), whether it was adjusted, and the modified itemstack.
function blueprint_tool.logic.set_pos2(itemstack, pos)
  local pos1, _ = blueprint_tool.logic.get_selection(itemstack)
  local final = vector.copy(pos)
  local adjusted = false
  if pos1 then
    local clamped = clamp_to_anchor(pos1, pos)
    if not vector.equals(clamped, pos) then
      final = clamped
      adjusted = true
    end
  end
  meta_set_pos(itemstack, "pos2", final)
  return final, adjusted
end

----------------------------------------------------------------
-- Paste origin (placer tool)
----------------------------------------------------------------

function blueprint_tool.logic.get_origin(itemstack)
  return meta_get_pos(itemstack, "origin")
end

function blueprint_tool.logic.set_origin(itemstack, pos)
  meta_set_pos(itemstack, "origin", pos)
end

function blueprint_tool.logic.clear_origin(itemstack)
  meta_clear_pos(itemstack, "origin")
end

