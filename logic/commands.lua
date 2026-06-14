-- Chat commands for blueprint management.

minetest.register_chatcommand("blueprint_clear", {
  description = "Delete all your saved blueprints and slots",
  func = function(name)
    if not blueprint_tool.player_has_access(name) then
      return false, "You don't have permission to use blueprint tools."
    end
    blueprint_tool.logic.cancel_paste(name, false)
    blueprint_tool.storage.clear_player(name)
    return true, "All your blueprints have been cleared."
  end,
})

minetest.register_chatcommand("blueprint_clear_all", {
  description = "Delete ALL players' blueprints (blueprint_admin priv required)",
  privs = {},  -- checked manually so we can also accept server priv
  func = function(name)
    local privs = minetest.get_player_privs(name)
    if not (privs.blueprint_admin or privs.server) then
      return false, "You need the blueprint_admin priv to run this command."
    end
    -- Cancel every active placement before wiping storage.
    for _, player in ipairs(minetest.get_connected_players()) do
      local pname = player:get_player_name()
      blueprint_tool.logic.cancel_paste(pname, false)
    end
    blueprint_tool.storage.clear_all()
    minetest.log("action", "[blueprint_tool] " .. name .. " ran /blueprint_clear_all")
    return true, "All blueprint data has been wiped."
  end,
})
