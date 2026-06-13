local mcl = minetest.get_modpath("mcl_core")

blueprint_tool.sound_mod = mcl and mcl_sounds or default

-- Returns a player's inventory formspec list elements with correct layout for the current game
function blueprint_tool.player_inv_formspec(x, y)
  if mcl then
    return "list[current_player;main;"..x..","..y..";9,3;9]"..
         "list[current_player;main;"..x..","..(y + 4)..";9,1]"
  else
    return "list[current_player;main;"..x..","..y..";8,1]"..
         "list[current_player;main;"..x..","..(y + 1.25)..";8,3;8]"
  end
end

local formspec_width_extra = (mcl and 1 or 0) + 0.25
blueprint_tool.inv_size = function(w, h)
  return tostring(w + formspec_width_extra)..","..tostring(h)
end
blueprint_tool.inv_width = (mcl and 9 or 8) + 0.25

blueprint_tool.itemstrings = {
  steel  = mcl and "mcl_core:iron_ingot" or "default:steel_ingot",
  wood   = mcl and "mcl_core:wood"     or "default:wood",
  paper  = mcl and "mcl_core:paper"    or "default:paper",
  chest  = mcl and "mcl_chests:chest"  or "default:chest",
  glass  = mcl and "mcl_core:glass"    or "default:glass",
  cobble = mcl and "mcl_core:cobble"   or "default:cobble",
}
