local S = blueprint_tool.TRANSLATOR
local SLOTS_PER_PAGE = 10

local picker_page = {}  -- [playerName] = current page (transient)

local function notify(playerName, msg)
  blueprint_tool.show_popup(playerName, msg)
end

local function sanitize_name(name)
  return (name or ""):gsub("[^A-Za-z0-9 _]", ""):sub(1, 32)
end

local function get_active_slot(itemstack)
  local slot = itemstack:get_meta():get_int("active_slot")
  return slot > 0 and slot or nil
end

local function set_active_slot(itemstack, slot_idx)
  itemstack:get_meta():set_int("active_slot", slot_idx or 0)
end

-- Returns slot_idx (possibly just assigned) and whether it was auto-assigned.
-- Modifies itemstack in place if auto-assigning.
local function get_or_assign_slot(playerName, itemstack)
  local slot = get_active_slot(itemstack)
  if slot then return slot, false end
  local limit = blueprint_tool.get_player_slot_limit(playerName)
  local next_slot = blueprint_tool.storage.get_next_empty_slot(playerName, limit)
  if next_slot then
    set_active_slot(itemstack, next_slot)
    return next_slot, true
  end
  return nil, false
end

----------------------------------------------------------------
-- Formspecs
----------------------------------------------------------------

local function build_main_formspec(playerName, itemstack)
  local limit = blueprint_tool.get_player_slot_limit(playerName)
  local slot_idx = get_active_slot(itemstack)
  local slot_data = slot_idx and blueprint_tool.storage.get_player_slot(playerName, slot_idx)

  local slot_line
  if slot_idx then
    local name = (slot_data and slot_data.name) or ""
    slot_line = "Slot "..slot_idx.." / "..limit..": "..name
  else
    slot_line = minetest.colorize("#FF8800", "No Empty Slot Available")
  end

  local current_name = (slot_data and slot_data.name) or ""

  local override_line = ""
  if slot_data and slot_data.bp_id then
    override_line = "label[0.3,2.5;"..
      minetest.formspec_escape(minetest.colorize("#FF8800", "Will override existing blueprint"))..
      "]"
  end

  local pos1, pos2 = blueprint_tool.logic.get_selection(itemstack)
  local pos1_str = pos1 and minetest.pos_to_string(pos1) or "not set"
  local pos2_str = pos2 and minetest.pos_to_string(pos2) or "not set"

  return "formspec_version[4]"..
    "size[8.5,7.0]"..
    "label[0.3,0.6;"..minetest.formspec_escape(slot_line).."]"..
    "button[6.0,0.2;2.2,0.7;pick_slot;Pick Slot]"..
    "label[0.3,1.6;Name:]"..
    "field[1.3,1.3;4.5,0.6;slot_name;;"..minetest.formspec_escape(current_name).."]"..
    "button[6.0,1.3;2.2,0.6;rename;Rename]"..
    override_line..
    "label[0.3,3.4;Corner 1: "..minetest.formspec_escape(pos1_str).."]"..
    "label[0.3,4.0;Corner 2: "..minetest.formspec_escape(pos2_str).."]"..
    "button[0.3,5.5;3.8,0.8;capture;Capture Selection]"..
    "button_exit[4.4,5.5;3.8,0.8;close;Close]"
end

local function build_slot_picker_formspec(playerName, page)
  local limit = blueprint_tool.get_player_slot_limit(playerName)
  local total_pages = math.max(1, math.ceil(limit / SLOTS_PER_PAGE))
  page = blueprint_tool.clamp(page, 1, total_pages)

  local start_slot = (page - 1) * SLOTS_PER_PAGE + 1
  local end_slot = math.min(start_slot + SLOTS_PER_PAGE - 1, limit)

  local fs = "formspec_version[4]"..
    "size[8.5,9.5]"..
    "label[0.3,0.6;Select Slot  -  Page "..page.." / "..total_pages.."]"..
    "button[7.3,0.1;1.0,1.0;back;X]"

  local y = 1.1
  for i = start_slot, end_slot do
    local slot_data = blueprint_tool.storage.get_player_slot(playerName, i)
    local label
    if slot_data then
      local status = slot_data.bp_id and "(Filled)" or "(Empty)"
      label = i..". "..status.." "..slot_data.name
    else
      label = i..". (Empty)"
    end
    fs = fs.."button[0.3,"..y..";7.9,0.65;slot_"..i..";"..minetest.formspec_escape(label).."]"
    y = y + 0.72
  end

  local nav_y = y + 0.2
  if page > 1 then
    fs = fs.."button[0.3,"..nav_y..";3.8,0.7;prev_page;< Prev]"
  end
  if page < total_pages then
    fs = fs.."button[4.4,"..nav_y..";3.8,0.7;next_page;Next >]"
  end

  return fs
end

local function show_main(playerName, itemstack)
  minetest.show_formspec(playerName, "blueprint_tool:creation_main",
    build_main_formspec(playerName, itemstack))
end

local function show_slot_picker(playerName)
  local page = picker_page[playerName] or 1
  minetest.show_formspec(playerName, "blueprint_tool:slot_picker",
    build_slot_picker_formspec(playerName, page))
end

----------------------------------------------------------------
-- Field handler
----------------------------------------------------------------

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "blueprint_tool:creation_main"
  and formname ~= "blueprint_tool:slot_picker" then return end

  local playerName = player:get_player_name()
  local itemstack = player:get_wielded_item()
  if itemstack:get_name() ~= "blueprint_tool:creation_tool" then return end

  if formname == "blueprint_tool:creation_main" then
    if fields.pick_slot then
      show_slot_picker(playerName)
      return
    end

    local slot_idx = get_active_slot(itemstack)

    if fields.rename then
      if not slot_idx then
        notify(playerName, "No slot selected")
        return
      end
      local name = sanitize_name(fields.slot_name)
      local slot_data = blueprint_tool.storage.get_player_slot(playerName, slot_idx) or {}
      slot_data.name = name
      blueprint_tool.storage.set_player_slot(playerName, slot_idx, slot_data)
      notify(playerName, "Slot "..slot_idx.." renamed to: "..name)
      show_main(playerName, itemstack)
      return
    end

    if fields.capture then
      if not slot_idx then
        notify(playerName, "No slot selected - pick one first")
        return
      end
      local bp, err = blueprint_tool.logic.capture(itemstack)
      if not bp then
        notify(playerName, "Capture failed: "..err)
        return
      end
      local existing = blueprint_tool.storage.get_player_slot(playerName, slot_idx)
      if existing and existing.bp_id then
        blueprint_tool.storage.delete_blueprint(existing.bp_id)
      end
      local id = blueprint_tool.storage.store_blueprint(bp)
      local name = sanitize_name(fields.slot_name)
      blueprint_tool.storage.set_player_slot(playerName, slot_idx, { name = name, bp_id = id })
      notify(playerName, "Captured into slot "..slot_idx.." ("..#bp.nodes.." nodes)")
      show_main(playerName, itemstack)
      return
    end
  end

  if formname == "blueprint_tool:slot_picker" then
    if fields.back then
      show_main(playerName, itemstack)
      return
    end

    if fields.prev_page then
      picker_page[playerName] = math.max(1, (picker_page[playerName] or 1) - 1)
      show_slot_picker(playerName)
      return
    end

    if fields.next_page then
      local limit = blueprint_tool.get_player_slot_limit(playerName)
      local total_pages = math.ceil(limit / SLOTS_PER_PAGE)
      picker_page[playerName] = math.min(total_pages, (picker_page[playerName] or 1) + 1)
      show_slot_picker(playerName)
      return
    end

    for k in pairs(fields) do
      local idx = tonumber(k:match("^slot_(%d+)$"))
      if idx then
        set_active_slot(itemstack, idx)
        player:set_wielded_item(itemstack)
        show_main(playerName, itemstack)
        return
      end
    end
  end
end)

----------------------------------------------------------------
-- Tool registration
----------------------------------------------------------------

minetest.register_tool("blueprint_tool:creation_tool", {
  description = S("Blueprint Creation Tool\nPunch to set corner 1\nSneak + punch to set corner 2\nRight-click for options"),
  short_description = S("Blueprint Creation Tool"),
  inventory_image = "creation_tool.png",
  wield_image = "creation_tool.png",
  stack_max = 1,

  on_use = function(itemstack, user, pointed_thing)
    if not user or not user:is_player() then return end
    if pointed_thing.type ~= "node" then return end
    local playerName = user:get_player_name()
    local pos = pointed_thing.under

    local slot_idx, was_assigned = get_or_assign_slot(playerName, itemstack)

    if user:get_player_control().sneak then
      local final, adjusted = blueprint_tool.logic.set_pos2(itemstack, pos)
      if not slot_idx then
        notify(playerName, "No empty slot available - open menu to pick one")
      else
        local msg = (was_assigned and ("Slot "..slot_idx.." assigned. ") or "")..
          "Corner 2: "..minetest.pos_to_string(final)
        if adjusted then msg = msg.." (clamped)" end
        notify(playerName, msg)
      end
    else
      local final, adjusted = blueprint_tool.logic.set_pos1(itemstack, pos)
      if not slot_idx then
        notify(playerName, "No empty slot available - open menu to pick one")
      else
        local msg = (was_assigned and ("Slot "..slot_idx.." assigned. ") or "")..
          "Corner 1: "..minetest.pos_to_string(final)
        if adjusted then msg = msg.." (clamped)" end
        notify(playerName, msg)
      end
    end
    return itemstack
  end,

  on_place = function(itemstack, placer, pointed_thing)
    if not placer or not placer:is_player() then return end
    local playerName = placer:get_player_name()
    local _, was_assigned = get_or_assign_slot(playerName, itemstack)
    if was_assigned then placer:set_wielded_item(itemstack) end
    show_main(playerName, itemstack)
  end,

  on_secondary_use = function(itemstack, user, pointed_thing)
    if not user or not user:is_player() then return end
    local playerName = user:get_player_name()
    local _, was_assigned = get_or_assign_slot(playerName, itemstack)
    if was_assigned then user:set_wielded_item(itemstack) end
    show_main(playerName, itemstack)
  end,
})

minetest.register_on_leaveplayer(function(objRef)
  if objRef:is_player() then
    picker_page[objRef:get_player_name()] = nil
  end
end)
