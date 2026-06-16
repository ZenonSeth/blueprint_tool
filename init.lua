blueprint_tool = {}

blueprint_tool.MODNAME = minetest.get_current_modname() or "blueprint_tool"
blueprint_tool.MODPATH = minetest.get_modpath(blueprint_tool.MODNAME)

dofile(blueprint_tool.MODPATH.."/version.lua")
dofile(blueprint_tool.MODPATH.."/util/util.lua")
dofile(blueprint_tool.MODPATH.."/entity/entity.lua")
dofile(blueprint_tool.MODPATH.."/logic/logic.lua")
dofile(blueprint_tool.MODPATH.."/tools/tools.lua")
dofile(blueprint_tool.MODPATH.."/ui/manage.lua")
dofile(blueprint_tool.MODPATH.."/ui/help.lua")
dofile(blueprint_tool.MODPATH.."/items/items.lua")
