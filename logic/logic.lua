local path = blueprint_tool.MODPATH.."/logic"

blueprint_tool.logic = {}
blueprint_tool.storage = {}

dofile(path.."/storage.lua")
dofile(path.."/blueprint.lua")
dofile(path.."/capture.lua")
