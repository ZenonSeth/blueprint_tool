local SLOTS_PER_PAGE   = 8
local PLAYERS_PER_PAGE = 5
local W                = 10.5

local manage_state = {}  -- [callerName] = {target, page, player_page}

local function is_admin(playerName)
  local privs = minetest.get_player_privs(playerName)
  return privs.server or privs.blueprint_admin
end

local function get_state(callerName)
  if not manage_state[callerName] then
    manage_state[callerName] = { target = callerName, page = 1, player_page = 1 }
  end
  return manage_state[callerName]
end

local function build_formspec(callerName)
  local state  = get_state(callerName)
  local target = state.target
  local admin  = is_admin(callerName)
  local limit  = blueprint_tool.get_player_slot_limit(target)
  local used   = blueprint_tool.storage.count_used_slots(target)

  local slots = blueprint_tool.storage.get_player_slots(target)
  local filled = {}
  for idx, slot in pairs(slots) do
    if slot and slot.bp_id then
      filled[#filled + 1] = { index = idx, slot = slot }
    end
  end
  table.sort(filled, function(a, b) return a.index < b.index end)

  local total_pages = math.max(1, math.ceil(#filled / SLOTS_PER_PAGE))
  state.page = blueprint_tool.clamp(state.page, 1, total_pages)

  -- Layout constants
  local slots_y  = 1.0
  local row_h    = 0.72
  local nav_y    = slots_y + SLOTS_PER_PAGE * row_h + 0.1

  -- Admin section height (always allocated when admin so height is stable)
  local all_players     = admin and blueprint_tool.storage.get_players_with_blueprints() or nil
  local admin_section_h = 0
  if admin then
    admin_section_h = 0.6   -- "Players:" label
                    + 0.72  -- player buttons row
                    + 0.72  -- player list nav
                    + 0.75  -- name field + Go
  end

  local H = nav_y + 0.65 + 0.3 + admin_section_h + 0.4

  local fs = blueprint_tool.fs_header(W, H, {x=0.5, y=0.5}, {x=0.5, y=0.5}, "#00000033")

  -- Header
  local header = "Blueprints for: "..
    minetest.colorize(blueprint_tool.COLOR_ACCENT, target)..
    "  |  Slots "..
    minetest.colorize(blueprint_tool.COLOR_ACCENT, tostring(used)).."/"..tostring(limit)
  fs = fs..
    "label[0.3,0.35;"..minetest.formspec_escape(header).."]"

  -- Slot rows
  local start_i = (state.page - 1) * SLOTS_PER_PAGE + 1
  local end_i   = math.min(start_i + SLOTS_PER_PAGE - 1, #filled)
  local y = slots_y
  for i = start_i, end_i do
    local entry = filled[i]
    local bp    = blueprint_tool.storage.get_blueprint(entry.slot.bp_id)
    local name  = entry.slot.name ~= "" and entry.slot.name or "(unnamed)"
    local date  = bp and bp.captured_at and os.date("%Y-%m-%d", bp.captured_at) or ""
    local count = bp and #bp.nodes or 0
    local label = entry.index..".  "..name..
      (date ~= "" and "  "..date or "")..
      "  ("..blueprint_tool.format_count(count).." nodes)"
    fs = fs..
      "label[0.3,"..(y + 0.22)..";"..minetest.formspec_escape(label).."]"..
      "button["..(W - 2.1)..","..y..";1.8,0.6;del_"..entry.index..";Delete]"
    y = y + row_h
  end

  if #filled == 0 then
    fs = fs.."label[0.3,"..(slots_y + 0.22)..";"..
      minetest.formspec_escape(minetest.colorize(blueprint_tool.COLOR_WARN,
        "No blueprints captured yet")).."]"
  end

  -- Slot pagination
  if total_pages > 1 then
    if state.page > 1 then
      fs = fs.."button[0.3,"..nav_y..";4.5,0.6;prev_page;< Prev]"
    end
    fs = fs.."label["..(W/2 - 0.5)..",".. (nav_y + 0.2) ..";Page "..state.page.."/"..total_pages.."]"
    if state.page < total_pages then
      fs = fs.."button[5.7,"..nav_y..";4.5,0.6;next_page;Next >]"
    end
  end

  -- Admin section
  if admin then
    local total_player_pages = math.max(1, math.ceil(#all_players / PLAYERS_PER_PAGE))
    state.player_page = blueprint_tool.clamp(state.player_page, 1, total_player_pages)
    local pp  = state.player_page
    local ay  = nav_y + 0.65 + 0.3

    fs = fs.."label[0.3,"..ay..";Players with blueprints:]"
    ay = ay + 0.55

    local ps    = (pp - 1) * PLAYERS_PER_PAGE + 1
    local pe    = math.min(ps + PLAYERS_PER_PAGE - 1, #all_players)
    local btn_w = (W - 0.6) / PLAYERS_PER_PAGE
    for i = ps, pe do
      local pname = all_players[i]
      local bx    = 0.3 + (i - ps) * btn_w
      local lbl   = pname == target
        and minetest.colorize(blueprint_tool.COLOR_ACCENT, pname) or pname
      fs = fs.."button["..bx..","..ay..";"..btn_w..",0.6;player_"..i..";"..
        minetest.formspec_escape(lbl).."]"
    end
    ay = ay + 0.72

    if pp > 1 then
      fs = fs.."button[0.3,"..ay..";2.0,0.6;prev_player_page;< Prev]"
    end
    if pp < total_player_pages then
      fs = fs.."button["..(W - 2.3)..","..ay..";2.0,0.6;next_player_page;Next >]"
    end
    ay = ay + 0.72

    fs = fs..
      "field[0.3,"..ay..";8.0,0.65;player_name_field;;]"..
      "button[8.4,"..ay..";1.8,0.65;player_go;Go]"
  end

  return fs
end

----------------------------------------------------------------
-- Public API
----------------------------------------------------------------

function blueprint_tool.show_manage(callerName, targetName)
  local state = get_state(callerName)
  state.target      = targetName or callerName
  state.page        = 1
  state.player_page = 1
  minetest.show_formspec(callerName, "blueprint_tool:manage",
    build_formspec(callerName))
end

----------------------------------------------------------------
-- Field handler
----------------------------------------------------------------

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "blueprint_tool:manage" then return end

  local callerName = player:get_player_name()
  local state      = get_state(callerName)

  if fields.quit then
    manage_state[callerName] = nil
    return
  end

  if fields.prev_page then
    state.page = state.page - 1
    minetest.show_formspec(callerName, "blueprint_tool:manage", build_formspec(callerName))
    return
  end

  if fields.next_page then
    state.page = state.page + 1
    minetest.show_formspec(callerName, "blueprint_tool:manage", build_formspec(callerName))
    return
  end

  if is_admin(callerName) then
    if fields.prev_player_page then
      state.player_page = state.player_page - 1
      minetest.show_formspec(callerName, "blueprint_tool:manage", build_formspec(callerName))
      return
    end

    if fields.next_player_page then
      state.player_page = state.player_page + 1
      minetest.show_formspec(callerName, "blueprint_tool:manage", build_formspec(callerName))
      return
    end

    if fields.player_go then
      local name = (fields.player_name_field or ""):match("^%s*(.-)%s*$")
      if name ~= "" then
        blueprint_tool.show_manage(callerName, name)
      end
      return
    end

    local all_players = blueprint_tool.storage.get_players_with_blueprints()
    for k in pairs(fields) do
      local i = tonumber(k:match("^player_(%d+)$"))
      if i and all_players[i] then
        blueprint_tool.show_manage(callerName, all_players[i])
        return
      end
    end
  end

  -- Delete buttons
  for k in pairs(fields) do
    local idx = tonumber(k:match("^del_(%d+)$"))
    if idx then
      local target = state.target
      if target ~= callerName and not is_admin(callerName) then
        blueprint_tool.show_popup(callerName, "Permission denied")
        return
      end
      local slot = blueprint_tool.storage.get_player_slot(target, idx)
      if slot and slot.bp_id then
        blueprint_tool.storage.delete_blueprint(slot.bp_id)
      end
      blueprint_tool.storage.clear_player_slot(target, idx)
      minetest.show_formspec(callerName, "blueprint_tool:manage", build_formspec(callerName))
      return
    end
  end
end)

minetest.register_on_leaveplayer(function(objRef)
  if objRef:is_player() then
    manage_state[objRef:get_player_name()] = nil
  end
end)

----------------------------------------------------------------
-- Command
----------------------------------------------------------------

minetest.register_chatcommand("blueprint_manage", {
  description = "Open the blueprint manager",
  func = function(name)
    if not blueprint_tool.player_has_access(name) then
      return false, "You don't have permission to use blueprint tools."
    end
    local player = minetest.get_player_by_name(name)
    if not player then return false, "Player not found." end
    blueprint_tool.show_manage(name, name)
    return true
  end,
})
