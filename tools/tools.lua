local path = blueprint_tool.MODPATH.."/tools"

blueprint_tool.tools = {}

local SWAP_PAIR = {
  ["blueprint_tool:creation_tool"] = "blueprint_tool:placer_tool",
  ["blueprint_tool:placer_tool"]   = "blueprint_tool:creation_tool",
}

function blueprint_tool.tools.swap_tool(player, itemstack)
  local target = SWAP_PAIR[itemstack:get_name()]
  if not target then return false end
  local new_item = ItemStack(target)
  local fields = itemstack:get_meta():to_table().fields
  local new_meta = new_item:get_meta()
  for k, v in pairs(fields) do
    new_meta:set_string(k, v)
  end
  player:set_wielded_item(new_item)
  return true
end

dofile(path.."/creation_tool.lua")
dofile(path.."/placer_tool.lua")
