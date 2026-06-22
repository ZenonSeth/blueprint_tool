local SLOTS_PER_PAGE   = 8
local PLAYERS_PER_PAGE = 5
local W                = 10.5

----------------------------------------------------------------
-- Shared helpers
----------------------------------------------------------------

local function is_admin(playerName)
  local privs = minetest.get_player_privs(playerName)
  return privs.server or privs.blueprint_admin
end

local function read_ref_meta(itemstack)
  local meta          = itemstack:get_meta()
  local bp_id         = tonumber(meta:get_string("bp_id"))
  local captured_at   = tonumber(meta:get_string("captured_at"))
  local oc            = meta:get_string("oc")
  local disallow_copy = meta:get_string("disallow_copy") == "true" or nil
  local name          = meta:get_string("name")
  if oc == "" then oc = nil end
  if name == "" then name = nil end
  return bp_id, captured_at, oc, disallow_copy, name
end

----------------------------------------------------------------
-- Blueprint Reference view formspec (right-click blueprint_ref item)
----------------------------------------------------------------

local function show_ref_formspec(playerName, itemstack)
  local bp_id, captured_at, oc, disallow_copy, name = read_ref_meta(itemstack)
  local valid = blueprint_tool.logic.check_blueprint_ref_valid(bp_id, captured_at)

  local fs
  if not valid then
    local reason = bp_id and "Blueprint no longer exists or has been modified"
                          or "No blueprint linked"
    local W2, H2 = 7.0, 2.8
    fs = blueprint_tool.fs_header(W2, H2, {x=0.5, y=0.5}, {x=0.5, y=0.5})
    fs = fs ..
      "label[0.4,0.5;"  .. minetest.colorize(blueprint_tool.COLOR_WARN, "Invalid Reference") .. "]" ..
      "label[0.4,1.15;" .. minetest.formspec_escape(reason) .. "]"
  else
    local bp      = blueprint_tool.storage.get_blueprint(bp_id)
    local copy_h  = disallow_copy and 0.55 or 0.55
    local W2, H2  = 8.5, 5.35 + copy_h
    fs = blueprint_tool.fs_header(W2, H2, {x=0.5, y=0.5}, {x=0.5, y=0.5})
    local date    = os.date("%Y-%m-%d", bp.captured_at)
    local creator = minetest.colorize(blueprint_tool.COLOR_ACCENT, oc or "unknown")
    local sz      = bp.size
    local copy_label = disallow_copy
      and minetest.colorize(blueprint_tool.COLOR_WARN, "Once imported, you cannot create copies of this blueprint")
      or "Once imported, you can create copies of this blueprint"
    fs = fs ..
      "label[0.4,0.4;Blueprint Reference]" ..
      "label[0.4,1.0;Name: "           .. minetest.formspec_escape(name or "(unnamed)") .. "]" ..
      "label[0.4,1.55;Originally by: "  .. creator .. "]" ..
      "label[0.4,2.1;Captured: "      .. minetest.formspec_escape(date) .. "]" ..
      "label[0.4,2.65;Size: "           .. sz.x .. " x " .. sz.y .. " x " .. sz.z .. "]" ..
      "label[0.4,3.2;Nodes: "         .. blueprint_tool.format_count(#bp.nodes) .. "]" ..
      "label[0.4,3.75;" .. copy_label .. "]" ..
      "button[" .. (W2 / 2 - 1.5) .. ",4.7;3.0,0.75;import;Import Blueprint]"
  end

  minetest.show_formspec(playerName, "blueprint_tool:blueprint_ref_view", fs)
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "blueprint_tool:blueprint_ref_view" then return end
  if not fields.import then return end

  local playerName = player:get_player_name()
  local itemstack  = player:get_wielded_item()

  if itemstack:get_name() ~= "blueprint_tool:blueprint_ref" then
    blueprint_tool.show_popup(playerName, "Hold the reference item to import.")
    return
  end

  if not blueprint_tool.player_has_access(playerName) then
    blueprint_tool.show_popup(playerName, "You don't have permission to use blueprint tools.")
    return
  end

  local bp_id, captured_at, oc, disallow_copy, name = read_ref_meta(itemstack)
  local slot, err = blueprint_tool.logic.import_blueprint_ref(bp_id, captured_at, oc, disallow_copy, playerName, name)
  if not slot then
    blueprint_tool.show_popup(playerName, err)
    return
  end

  itemstack:take_item()
  player:set_wielded_item(itemstack)

  minetest.close_formspec(playerName, "blueprint_tool:blueprint_ref_view")
  blueprint_tool.show_popup(playerName, "Blueprint imported into slot " .. slot .. ".")
end)

----------------------------------------------------------------
-- Create Reference formspec (right-click blank blueprint item)
----------------------------------------------------------------

local create_ref_state = {}  -- [playerName] = { target, page, player_page, disallow_copy }

local function get_disallow_copy_pref(playerName)
  local player = minetest.get_player_by_name(playerName)
  if not player then return true end
  return player:get_meta():get_int("blueprint_disallow_copy") == 0
end

local function set_disallow_copy_pref(playerName, value)
  local player = minetest.get_player_by_name(playerName)
  if not player then return end
  player:get_meta():set_int("blueprint_disallow_copy", value and 0 or 1)
end

local function get_cr_state(playerName)
  if not create_ref_state[playerName] then
    create_ref_state[playerName] = {
      target        = playerName,
      page          = 1,
      player_page   = 1,
      disallow_copy = get_disallow_copy_pref(playerName),
      error         = nil,
    }
  end
  return create_ref_state[playerName]
end

local function build_create_ref_formspec(callerName)
  local state  = get_cr_state(callerName)
  local target = state.target
  local admin  = is_admin(callerName)

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

  local slots_y = 1.0
  local row_h   = 1.1
  local nav_y   = slots_y + SLOTS_PER_PAGE * row_h + 0.1

  local all_players     = admin and blueprint_tool.storage.get_players_with_blueprints() or nil
  local admin_section_h = 0
  if admin then
    admin_section_h = 0.6 + 0.72 + 0.72 + 0.75
  end

  local error_h = state.error and 0.55 or 0
  local H = nav_y + 0.65 + 0.3 + admin_section_h + 0.8 + error_h + 0.55 + 0.4

  local fs = blueprint_tool.fs_header(W, H, {x=0.5, y=0.5}, {x=0.5, y=0.5})

  local header = "Create Reference: " ..
    minetest.colorize(blueprint_tool.COLOR_ACCENT, target)
  fs = fs .. "label[0.3,0.35;" .. minetest.formspec_escape(header) .. "]"

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
    local restricted = entry.slot.disallow_copy

    local line1 = entry.index .. ".  " .. name
    local line2 = (date ~= "" and date .. "  " or "") ..
      blueprint_tool.format_count(count) .. " nodes" ..
      (restricted and "  " .. minetest.colorize(blueprint_tool.COLOR_WARN, "[no copy]") or "")

    fs = fs .. "label[0.3," .. (y + 0.1) .. ";" .. minetest.formspec_escape(line1) .. "]"
    fs = fs .. "label[0.3," .. (y + 0.55) .. ";" ..
      minetest.colorize("#EEEEEE", minetest.formspec_escape(line2)) .. "]"

    if not restricted then
      fs = fs .. "button[" .. (W - 2.8) .. "," .. (y + 0.1) .. ";2.5,0.7;ref_" .. entry.index .. ";Create Ref]"
    end

    fs = fs .. "box[0.3," .. (y + row_h - 0.1) .. ";" .. (W - 0.6) .. ",0.01;#999999]"

    y = y + row_h
  end

  if #filled == 0 then
    fs = fs .. "label[0.3," .. (slots_y + 0.22) .. ";" ..
      minetest.formspec_escape(minetest.colorize(blueprint_tool.COLOR_WARN,
        "No blueprints captured yet")) .. "]"
  end

  -- Pagination
  if total_pages > 1 then
    if state.page > 1 then
      fs = fs .. "button[0.3," .. nav_y .. ";4.5,0.6;prev_page;< Prev]"
    end
    fs = fs .. "label[" .. (W / 2 - 0.5) .. "," .. (nav_y + 0.2) ..
      ";Page " .. state.page .. "/" .. total_pages .. "]"
    if state.page < total_pages then
      fs = fs .. "button[5.7," .. nav_y .. ";4.5,0.6;next_page;Next >]"
    end
  end

  -- Admin section
  local ay = nav_y + 0.65 + 0.3
  if admin then
    local total_player_pages = math.max(1, math.ceil(#all_players / PLAYERS_PER_PAGE))
    state.player_page = blueprint_tool.clamp(state.player_page, 1, total_player_pages)
    local pp = state.player_page

    fs = fs .. "label[0.3," .. ay .. ";Players with blueprints:]"
    ay = ay + 0.55

    local ps    = (pp - 1) * PLAYERS_PER_PAGE + 1
    local pe    = math.min(ps + PLAYERS_PER_PAGE - 1, #all_players)
    local btn_w = (W - 0.6) / PLAYERS_PER_PAGE
    for i = ps, pe do
      local pname = all_players[i]
      local bx    = 0.3 + (i - ps) * btn_w
      local lbl   = pname == target
        and minetest.colorize(blueprint_tool.COLOR_ACCENT, pname) or pname
      fs = fs .. "button[" .. bx .. "," .. ay .. ";" .. btn_w .. ",0.6;player_" .. i .. ";" ..
        minetest.formspec_escape(lbl) .. "]"
    end
    ay = ay + 0.72

    if pp > 1 then
      fs = fs .. "button[0.3," .. ay .. ";2.0,0.6;prev_player_page;< Prev]"
    end
    if pp < total_player_pages then
      fs = fs .. "button[" .. (W - 2.3) .. "," .. ay .. ";2.0,0.6;next_player_page;Next >]"
    end
    ay = ay + 0.72

    fs = fs ..
      "field[0.3," .. ay .. ";8.0,0.65;player_name_field;;]" ..
      "button[8.4," .. ay .. ";1.8,0.65;player_go;Go]"
    ay = ay + 0.75
  end

  -- Disallow copy checkbox + error label (always at bottom)
  local dc_val = state.disallow_copy and "true" or "false"
  fs = fs .. "checkbox[6.0,0.4;disallow_copy;Create: Disallow copying;" .. dc_val .. "]"
  fs = fs .. "tooltip[disallow_copy;" ..
    minetest.formspec_escape("When checked, players who import this reference\nwon't be able to create copies of it") ..
    "]"

  if state.error then
    fs = fs .. "label[0.3," .. (ay + 0.55) .. ";" ..
      minetest.formspec_escape(minetest.colorize(blueprint_tool.COLOR_WARN, state.error)) .. "]"
  end

  local hint_y = ay + error_h + 0.55
  fs = fs .. "label[0.3," .. hint_y .. ";" ..
    minetest.formspec_escape(minetest.colorize("#888888", "Use /blueprint_manage to delete blueprints")) .. "]"

  return fs
end

local function show_create_ref(playerName)
  local state = get_cr_state(playerName)
  state.target      = playerName
  state.page        = 1
  state.player_page = 1
  minetest.show_formspec(playerName, "blueprint_tool:create_ref",
    build_create_ref_formspec(playerName))
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "blueprint_tool:create_ref" then return end

  local callerName = player:get_player_name()
  local state      = get_cr_state(callerName)

  if fields.quit then
    create_ref_state[callerName] = nil
    return
  end

  if fields.disallow_copy ~= nil then
    state.disallow_copy = fields.disallow_copy == "true"
    set_disallow_copy_pref(callerName, state.disallow_copy)
    return
  end

  if fields.prev_page then
    state.page  = state.page - 1
    state.error = nil
    minetest.show_formspec(callerName, "blueprint_tool:create_ref", build_create_ref_formspec(callerName))
    return
  end

  if fields.next_page then
    state.page  = state.page + 1
    state.error = nil
    minetest.show_formspec(callerName, "blueprint_tool:create_ref", build_create_ref_formspec(callerName))
    return
  end

  if is_admin(callerName) then
    if fields.prev_player_page then
      state.player_page = state.player_page - 1
      minetest.show_formspec(callerName, "blueprint_tool:create_ref", build_create_ref_formspec(callerName))
      return
    end

    if fields.next_player_page then
      state.player_page = state.player_page + 1
      minetest.show_formspec(callerName, "blueprint_tool:create_ref", build_create_ref_formspec(callerName))
      return
    end

    if fields.player_go then
      local name = (fields.player_name_field or ""):match("^%s*(.-)%s*$")
      if name ~= "" then
        state.target      = name
        state.page        = 1
        state.player_page = 1
        minetest.show_formspec(callerName, "blueprint_tool:create_ref", build_create_ref_formspec(callerName))
      end
      return
    end

    local all_players = blueprint_tool.storage.get_players_with_blueprints()
    for k in pairs(fields) do
      local i = tonumber(k:match("^player_(%d+)$"))
      if i and all_players[i] then
        state.target      = all_players[i]
        state.page        = 1
        minetest.show_formspec(callerName, "blueprint_tool:create_ref", build_create_ref_formspec(callerName))
        return
      end
    end
  end

  -- Create Ref buttons
  for k in pairs(fields) do
    local idx = tonumber(k:match("^ref_(%d+)$"))
    if idx then
      local target    = state.target
      local slot_data = blueprint_tool.storage.get_player_slot(target, idx)
      if not slot_data or not slot_data.bp_id or slot_data.disallow_copy then return end

      local bp = blueprint_tool.storage.get_blueprint(slot_data.bp_id)
      if not bp then return end

      -- Build the ref item
      local ref = ItemStack("blueprint_tool:blueprint_ref")
      local ref_meta = ref:get_meta()
      ref_meta:set_string("bp_id", tostring(slot_data.bp_id))
      ref_meta:set_string("captured_at", tostring(bp.captured_at))
      local oc = bp.oc or target
      ref_meta:set_string("oc", oc)
      ref_meta:set_string("name", slot_data.name or "")
      if state.disallow_copy then
        ref_meta:set_string("disallow_copy", "true")
      end

      local desc = minetest.colorize("#87CEEB", "Blueprint Reference")
      local display_name = (slot_data.name and slot_data.name ~= "") and slot_data.name or "(unnamed)"
      desc = desc .. "\nBlueprint: " .. display_name
      if state.disallow_copy then
        desc = desc .. "\n" .. minetest.colorize(blueprint_tool.COLOR_WARN, "No copy")
      end
      ref_meta:set_string("description", desc)

      local inv = player:get_inventory()

      -- Try to fit the ref item first before consuming the blank
      local leftover = inv:add_item("main", ref)
      if not leftover:is_empty() then
        state.error = "Inventory full, make room."
        minetest.show_formspec(callerName, "blueprint_tool:create_ref", build_create_ref_formspec(callerName))
        return
      end

      -- Take one blank blueprint
      local taken = inv:remove_item("main", ItemStack("blueprint_tool:blueprint"))
      if taken:is_empty() then
        -- No blank available; undo the ref we just gave
        inv:remove_item("main", ref)
        state.error = "You need a blank blueprint."
        minetest.show_formspec(callerName, "blueprint_tool:create_ref", build_create_ref_formspec(callerName))
        return
      end

      create_ref_state[callerName] = nil
      minetest.close_formspec(callerName, "blueprint_tool:create_ref")
      return
    end
  end
end)

minetest.register_on_leaveplayer(function(objRef)
  if objRef:is_player() then
    create_ref_state[objRef:get_player_name()] = nil
  end
end)

----------------------------------------------------------------
-- Items
----------------------------------------------------------------

minetest.register_craftitem("blueprint_tool:blueprint", {
  description = minetest.colorize("#87CEEB", "Blueprint") ..
    "\nUse to create a reference to one of your saved blueprints",
  inventory_image = "blueprint_blueprint.png",
  on_place = function(itemstack, user, _pointed_thing)
    if not user or not user:is_player() then return itemstack end
    local playerName = user:get_player_name()
    if not blueprint_tool.player_has_access(playerName) then return itemstack end
    show_create_ref(playerName)
    return itemstack
  end,
  on_secondary_use = function(itemstack, user, _pointed_thing)
    if not user or not user:is_player() then return itemstack end
    local playerName = user:get_player_name()
    if not blueprint_tool.player_has_access(playerName) then return itemstack end
    show_create_ref(playerName)
    return itemstack
  end,
})

minetest.register_craftitem("blueprint_tool:blueprint_ref", {
  description = minetest.colorize("#87CEEB", "Blueprint Reference") ..
    "\nUse to import the linked blueprint into your saved slots",
  inventory_image = "blueprint_blueprint_ref.png",
  groups = { not_in_creative_inventory = 1 },
  on_place = function(itemstack, user, _pointed_thing)
    if not user or not user:is_player() then return itemstack end
    show_ref_formspec(user:get_player_name(), itemstack)
    return itemstack
  end,
  on_secondary_use = function(itemstack, user, _pointed_thing)
    if not user or not user:is_player() then return itemstack end
    show_ref_formspec(user:get_player_name(), itemstack)
    return itemstack
  end,
})
