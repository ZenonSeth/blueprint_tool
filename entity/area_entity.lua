local ENAME = "blueprint_tool:area_entity"
local TEX = "blueprint_area_entity.png"
local LIFETIME = 30

-- [playerName] = entity object ref
local active_entities = {}

minetest.register_entity(ENAME, {
  physical = false,
  collide_with_objects = false,
  visual = "cube",
  collisionbox = {0, 0, 0, 0, 0, 0},
  selectionbox = {0, 0, 0, 0, 0, 0},
  backface_culling = false,
  glow = 5,
  visual_size = {x = 1, y = 1, z = 1},
  static_save = false,
  textures = {TEX, TEX, TEX, TEX, TEX, TEX},
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
-- If only pos1 is provided, shows a 1x1x1 marker at that position.
-- If both are provided, shows the full volume.
function blueprint_tool.entity.show_area(playerName, pos1, pos2)
  if not pos1 then return end

  local existing = active_entities[playerName]
  if existing then
    existing:remove()
    active_entities[playerName] = nil
  end

  local center, sx, sy, sz
  if pos2 then
    center = vector.new(
      (pos1.x + pos2.x) / 2,
      (pos1.y + pos2.y) / 2,
      (pos1.z + pos2.z) / 2
    )
    sx = math.abs(pos2.x - pos1.x) + 1.1
    sy = math.abs(pos2.y - pos1.y) + 1.1
    sz = math.abs(pos2.z - pos1.z) + 1.1
  else
    center = vector.copy(pos1)
    sx, sy, sz = 1.1, 1.1, 1.1
  end

  local ent = minetest.add_entity(center, ENAME, playerName)
  if ent then
    ent:set_properties({visual_size = {x = sx, y = sy, z = sz}})
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
