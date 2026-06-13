local player_hud = {}

local SHORT_TIME = 3
local LONG_TIME = 10

function blueprint_tool.show_popup(playerName, text, time, atBottom, scale)
  if not time then time = SHORT_TIME end
  local player = minetest.get_player_by_name(playerName)
  if not player then return end

  local position = {x = 0.5, y = 0.5}
  local offset   = {x = 0,   y = 40}
  if atBottom then
    position = {x = 0.5, y = 1}
    offset   = {x = 0,   y = -100}
  end
  if not scale then scale = 1 end

  if player_hud[playerName] then
    player:hud_remove(player_hud[playerName].hud_id)
    player_hud[playerName].job:cancel()
    player_hud[playerName] = nil
  end

  local hud_id = player:hud_add({
    hud_elem_type = "text",
    type          = "text",
    style         = 1,
    position      = position,
    offset        = offset,
    text          = text,
    size          = {x = scale, y = scale},
    scale         = {x = 1, y = 1},
    alignment     = {x = 0, y = 0},
    number        = 0xDFDFDF,
  })

  player_hud[playerName] = { hud_id = hud_id }
  player_hud[playerName].job = minetest.after(time, function()
    local pl = minetest.get_player_by_name(playerName)
    if not pl or not player_hud[playerName] then return end
    pl:hud_remove(player_hud[playerName].hud_id)
    player_hud[playerName] = nil
  end)
end

blueprint_tool.POPUP_SHORT = SHORT_TIME
blueprint_tool.POPUP_LONG  = LONG_TIME
