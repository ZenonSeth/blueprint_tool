minetest.register_privilege("more_blueprints", {
  description = "Allows storing up to the 'more' blueprint slot limit",
  give_to_singleplayer = false,
})

minetest.register_privilege("even_more_blueprints", {
  description = "Allows storing up to the 'even more' blueprint slot limit",
  give_to_singleplayer = false,
})

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
