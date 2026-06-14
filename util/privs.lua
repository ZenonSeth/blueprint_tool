minetest.register_privilege("basic_blueprints", {
  description = "Allows using blueprint tools (default slot limit)",
  give_to_singleplayer = true,
})

minetest.register_privilege("more_blueprints", {
  description = "Allows storing up to the 'more' blueprint slot limit",
  give_to_singleplayer = false,
})

minetest.register_privilege("even_more_blueprints", {
  description = "Allows storing up to the 'even more' blueprint slot limit",
  give_to_singleplayer = false,
})

minetest.register_privilege("allow_capture_protected", {
  description = "Allows capturing nodes in protected areas",
  give_to_singleplayer = false,
})

minetest.register_privilege("blueprint_admin", {
  description = "Allows running /blueprint_clear_all to wipe all blueprint data",
  give_to_singleplayer = false,
})

-- Returns true if the player may use blueprint tools at all.
-- When open_access = true this always returns true.
-- Otherwise the player needs basic_blueprints, more_blueprints,
-- even_more_blueprints, or the built-in server priv.
function blueprint_tool.player_has_access(playerName)
  if blueprint_tool.settings.open_access then return true end
  local privs = minetest.get_player_privs(playerName)
  return privs.server             or
         privs.basic_blueprints   or
         privs.more_blueprints    or
         privs.even_more_blueprints or
         false
end

function blueprint_tool.get_player_slot_limit(playerName)
  local privs = minetest.get_player_privs(playerName)
  local s = blueprint_tool.settings
  if privs.server or privs.even_more_blueprints then
    return s.even_more_slots
  elseif privs.more_blueprints then
    return s.more_slots
  end
  return s.default_slots
end
