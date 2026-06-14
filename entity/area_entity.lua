local ENAME = "blueprint_tool:area_entity"
local LIFETIME = 30

-- Texture indices: +Y, -Y, +X, -X, +Z, -Z  (top, bottom, right, left, front, back)
-- Texture indices: +Y, -Y, +X, -X, +Z, -Z  (top, bottom, right, left, front, back)
local TEX_TOP   = "blueprint_area_entity_u.png"
local TEX_BOT   = "blueprint_area_entity_d.png"
local TEX_RIGHT = "blueprint_area_entity_r.png"
local TEX_LEFT  = "blueprint_area_entity_l.png"
local TEX_FRONT = "blueprint_area_entity_f.png"
local TEX_BACK  = "blueprint_area_entity_b.png"

-- [playerName] = entity object ref
local active_entities = {}

minetest.register_entity(ENAME, {
  physical = false,
  collide_with_objects = false,
  visual = "cube",
  collisionbox = {0, 0, 0, 0, 0, 0},
  selectionbox = {0, 0, 0, 0, 0, 0},
  backface_culling = false,
  glow = 14,
  visual_size = {x = 1, y = 1, z = 1},
  static_save = false,
  textures = {TEX_TOP, TEX_BOT, TEX_RIGHT, TEX_LEFT, TEX_FRONT, TEX_BACK},
  lifetime = 0,
  player_name = "",
  on_activate = function(self, staticdata)
    self.player_name = staticdata or ""
  end,
  on_punch = function(self)
    active_entities[self.player_name] = nil
    self.object:remove()
  end,
  on_step = function(self, dtime)
    self.lifetime = self.lifetime + dtime
    if self.lifetime > LIFETIME then
      active_entities[self.player_name] = nil
      self.object:remove()
    end
  end,
})

-- Shows (or updates) the area entity for a player.
-- pos2 is always the UNROTATED end (origin + bp.size) — visual_size stays in entity local frame.
-- angle: Y-axis CW rotation in degrees (0/90/180/270). The center is adjusted for 90/270 since
-- swapping x/z extents shifts it, and yaw handles the visual rotation.
function blueprint_tool.entity.show_area(playerName, pos1, pos2, angle)
  if not pos1 then return end

  local existing = active_entities[playerName]
  if existing then
    existing:remove()
    active_entities[playerName] = nil
  end

  local center, sx, sy, sz
  if pos2 then
    local rx = math.abs(pos2.x - pos1.x)
    local ry = math.abs(pos2.y - pos1.y)
    local rz = math.abs(pos2.z - pos1.z)
    local mn = vector.new(math.min(pos1.x, pos2.x), math.min(pos1.y, pos2.y), math.min(pos1.z, pos2.z))

    -- For 90/270 the world-space x/z extents swap, so the center shifts accordingly.
    local cx_half = (angle == 90 or angle == 270) and rz / 2 or rx / 2
    local cz_half = (angle == 90 or angle == 270) and rx / 2 or rz / 2
    center = vector.new(mn.x + cx_half, mn.y + ry / 2, mn.z + cz_half)

    sx = rx + 1.1
    sy = ry + 1.1
    sz = rz + 1.1
  else
    center = vector.copy(pos1)
    sx, sy, sz = 1.1, 1.1, 1.1
  end

  local ent = minetest.add_entity(center, ENAME, playerName)
  if ent then
    ent:set_properties({visual_size = {x = sx, y = sy, z = sz}})
    ent:set_yaw((angle or 0) * math.pi / 180)
    active_entities[playerName] = ent
  end
end

function blueprint_tool.entity.hide_area(playerName)
  local existing = active_entities[playerName]
  if existing then
    existing:remove()
    active_entities[playerName] = nil
  end
end

function blueprint_tool.entity.is_area_visible(playerName)
  return active_entities[playerName] ~= nil
end

minetest.register_on_leaveplayer(function(objRef)
  if objRef:is_player() then
    blueprint_tool.entity.hide_area(objRef:get_player_name())
  end
end)
