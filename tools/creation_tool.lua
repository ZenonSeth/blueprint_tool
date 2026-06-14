local S = blueprint_tool.TRANSLATOR
local SLOTS_PER_PAGE = 10

local picker_page   = {}  -- [playerName] = current page (transient)
local analysis_cache = {}  -- [playerName] = last analysis result (transient)

local function notify(playerName, msg)
  blueprint_tool.show_popup(playerName, msg)
end

local function player_can_use_pos(playerName, pos)
  if minetest.check_player_privs(playerName, { allow_capture_protected = true }) then
    return true
  end
  return not minetest.is_protected(pos, playerName)
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
-- Fine-tune face adjustment
----------------------------------------------------------------

-- face buttons: {axis, is_max_face, delta}
-- is_max_face=true  means the face sits at the max bound of that axis (front=+Z, up=+Y, right=+X)
-- is_max_face=false means the face sits at the min bound             (back=-Z, down=-Y, left=-X)
-- delta: +1 = extend outward, -1 = shrink inward (from the perspective of that face)
local FACE_BUTTONS = {
  ft_front_plus  = {"z", true,   1},
  ft_front_minus = {"z", true,  -1},
  ft_back_plus   = {"z", false, -1},
  ft_back_minus  = {"z", false,  1},
  ft_up_plus     = {"y", true,   1},
  ft_up_minus    = {"y", true,  -1},
  ft_down_plus   = {"y", false, -1},
  ft_down_minus  = {"y", false,  1},
  ft_right_plus  = {"x", true,   1},
  ft_right_minus = {"x", true,  -1},
  ft_left_plus   = {"x", false, -1},
  ft_left_minus  = {"x", false,  1},
}

local function apply_face_adjust(itemstack, axis, is_max_face, delta)
  local pos1, pos2 = blueprint_tool.logic.get_selection(itemstack)
  if not pos1 or not pos2 then return false end

  local limits = {
    x = blueprint_tool.settings.max_size_x,
    y = blueprint_tool.settings.max_size_y,
    z = blueprint_tool.settings.max_size_z,
  }
  local limit = limits[axis]

  local mn = vector.new(
    math.min(pos1.x, pos2.x), math.min(pos1.y, pos2.y), math.min(pos1.z, pos2.z))
  local mx = vector.new(
    math.max(pos1.x, pos2.x), math.max(pos1.y, pos2.y), math.max(pos1.z, pos2.z))

  if is_max_face then
    mx[axis] = blueprint_tool.clamp(mx[axis] + delta, mn[axis], mn[axis] + limit - 1)
  else
    mn[axis] = blueprint_tool.clamp(mn[axis] + delta, mx[axis] - limit + 1, mx[axis])
  end

  blueprint_tool.logic.set_raw_selection(itemstack, mn, mx)
  return true
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
    slot_line = "Will save Blueprint to slot "..
      minetest.colorize(blueprint_tool.COLOR_ACCENT, tostring(slot_idx))..
      " out of "..
      minetest.colorize(blueprint_tool.COLOR_ACCENT, tostring(limit))
  else
    slot_line = minetest.colorize(blueprint_tool.COLOR_WARN, "No Empty Slot Available")
  end

  local current_name = (slot_data and slot_data.name) or ""

  local override_line = ""
  if slot_data and slot_data.bp_id then
    override_line = "label[0.3,2.5;"..
      minetest.formspec_escape(minetest.colorize(blueprint_tool.COLOR_WARN, "Will override existing blueprint"))..
      "]"
  end

  local pos1, pos2 = blueprint_tool.logic.get_selection(itemstack)
  local pos1_str = pos1 and minetest.pos_to_string(pos1) or "not set"
  local pos2_str = pos2 and minetest.pos_to_string(pos2) or "not set"

  local volume_btn
  if blueprint_tool.entity.is_area_visible(playerName) then
    volume_btn = "button[0.3,4.7;3.8,0.7;hide_volume;Hide Volume]"
  else
    volume_btn = "button[0.3,4.7;3.8,0.7;show_volume;Show Volume]"
  end

  local finetune_btn = ""
  if pos1 and pos2 then
    finetune_btn = "button[4.4,4.7;3.8,0.7;finetune;Adjust Volume]"
  end

  return blueprint_tool.fs_header(8.5, 7.0)..
    "button_exit[7.8,0.1;0.6,0.6;close;X]"..
    "label[0.3,0.6;"..minetest.formspec_escape(slot_line).."]"..
    "button[5.5,0.2;2.0,0.7;pick_slot;Pick Slot]"..
    "label[0.3,1.6;Name:]"..
    "field[1.3,1.3;4.5,0.6;slot_name;;"..minetest.formspec_escape(current_name).."]"..
    "button[6.0,1.3;2.2,0.6;rename;Rename]"..
    override_line..
    "label[0.3,3.4;Corner 1: "..minetest.formspec_escape(pos1_str).."]"..
    "button[6.0,3.1;2.2,0.6;clear_pos1;Clear]"..
    "label[0.3,4.0;Corner 2: "..minetest.formspec_escape(pos2_str).."]"..
    "button[6.0,3.7;2.2,0.6;clear_pos2;Clear]"..
    volume_btn..
    finetune_btn..
    "button[0.3,5.7;3.8,0.8;capture;Capture]"..
    "button[4.4,5.7;3.8,0.8;analyze;Analyze]"
end

local function build_slot_picker_formspec(playerName, page)
  local limit = blueprint_tool.get_player_slot_limit(playerName)
  local total_pages = math.max(1, math.ceil(limit / SLOTS_PER_PAGE))
  page = blueprint_tool.clamp(page, 1, total_pages)

  local start_slot = (page - 1) * SLOTS_PER_PAGE + 1
  local end_slot = math.min(start_slot + SLOTS_PER_PAGE - 1, limit)

  local fs = blueprint_tool.fs_header(8.5, 9.5)..
    "label[0.3,0.6;Select Slot  -  Page "..page.." / "..total_pages.."]"..
    "button[7.3,0.1;1.0,1.0;back;X]"

  local y = 1.1
  for i = start_slot, end_slot do
    local slot_data = blueprint_tool.storage.get_player_slot(playerName, i)
    local label
    if slot_data and slot_data.bp_id then
      local bp   = blueprint_tool.storage.get_blueprint(slot_data.bp_id)
      local name = slot_data.name ~= "" and slot_data.name or "(unnamed)"
      local date = bp and bp.captured_at and os.date("%Y-%m-%d %H:%M", bp.captured_at) or ""
      label = i..". "..name..(date ~= "" and "  ["..date.."]" or "")
    elseif slot_data then
      label = i..". (empty)  "..slot_data.name
    else
      label = i..". (empty)"
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

-- show_capture_btn: true when analyzing a live selection (false for existing blueprints)
local function build_analysis_formspec(playerName, analysis, show_capture_btn)
  local fs = blueprint_tool.fs_header(8.5, 9.0)..
    "button[7.3,0.1;1.0,1.0;analysis_back;X]"..
    "label[0.3,0.6;Blueprint Analysis]"

  local y = 1.2
  if analysis.total_captured == 0 then
    fs = fs.."label[0.3,"..y..";"..
      minetest.formspec_escape(minetest.colorize(blueprint_tool.COLOR_WARN, "No nodes to be captured"))..
      "]"
    y = y + 0.6
  else
    fs = fs.."label[0.3,"..y..";Will capture "..
      minetest.formspec_escape(minetest.colorize(blueprint_tool.COLOR_ACCENT, tostring(analysis.total_captured)))..
      " nodes]"
    y = y + 0.6
  end

  if analysis.total_skipped > 0 then
    fs = fs.."label[0.3,"..y..";"..
      minetest.formspec_escape(minetest.colorize(blueprint_tool.COLOR_WARN,
        "Skipped "..analysis.total_skipped.." nodes (protected)"))..
      "]"
    y = y + 0.6
  end

  if analysis.total_liquid and analysis.total_liquid > 0 then
    fs = fs.."label[0.3,"..y..";"..
      minetest.formspec_escape("Blueprint contains "..
        minetest.colorize(blueprint_tool.COLOR_ACCENT, tostring(analysis.total_liquid))..
        " liquid nodes")..
      "]"
    y = y + 0.6
  end

  -- node list as textlist
  local entries = {}
  for _, entry in ipairs(analysis.nodes) do
    entries[#entries + 1] = minetest.formspec_escape(entry.count.."x  "..entry.display_name)
  end
  local list_str = table.concat(entries, ",")
  fs = fs.."textlist[0.3,"..y..";7.9,5.0;node_list;"..list_str..";0;false]"

  local btn_y = 8.1
  if show_capture_btn then
    fs = fs.."button[0.3,"..btn_y..";3.8,0.7;analysis_capture;Capture]"
    fs = fs.."button_exit[4.4,"..btn_y..";3.8,0.7;analysis_close;Close]"
  else
    fs = fs.."button_exit[2.5,"..btn_y..";3.5,0.7;analysis_close;Close]"
  end

  return fs
end

local function build_finetune_formspec(playerName, itemstack)
  local pos1, pos2 = blueprint_tool.logic.get_selection(itemstack)
  local size_str = "N/A"
  if pos1 and pos2 then
    local w = math.abs(pos2.x - pos1.x) + 1
    local h = math.abs(pos2.y - pos1.y) + 1
    local d = math.abs(pos2.z - pos1.z) + 1
    size_str = w.."x"..h.."x"..d
  end

  local bw, bh = 0.6, 0.6
  local y1, y2 = 0.2, 1.0

  local function face_group(gx, gy, lbl, minus_name, plus_name)
    return "label["..gx..","..gy..";"..lbl.."]"..
      "button["..(gx+1.2)..","..gy..";"..bw..","..bh..";"..minus_name..";-]"..
      "button["..(gx+1.85)..","..gy..";"..bw..","..bh..";"..plus_name..";+]"
  end

  return blueprint_tool.fs_header(10.5, 2.0, {x=0.5, y=0.85}, {x=0.5, y=0.5}, "#00000033")..
    face_group(0.2, y1, "Front:", "ft_front_minus", "ft_front_plus")..
    face_group(3.2, y1, "Up:",    "ft_up_minus",    "ft_up_plus")..
    face_group(6.2, y1, "Left:",  "ft_left_minus",  "ft_left_plus")..
    face_group(0.2, y2, "Back:",  "ft_back_minus",  "ft_back_plus")..
    face_group(3.2, y2, "Down:",  "ft_down_minus",  "ft_down_plus")..
    face_group(6.2, y2, "Right:", "ft_right_minus", "ft_right_plus")..
    "label[9.0,"..(y1+0.1)..";Size: "..minetest.formspec_escape(size_str).."]"..
    "button[9.0,"..y2..";1.3,"..bh..";ft_return;< Back]"
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

local function show_finetune(playerName, itemstack)
  minetest.show_formspec(playerName, "blueprint_tool:finetune",
    build_finetune_formspec(playerName, itemstack))
end

local function show_analysis(playerName, analysis, show_capture_btn)
  analysis_cache[playerName] = analysis
  minetest.show_formspec(playerName, "blueprint_tool:analysis",
    build_analysis_formspec(playerName, analysis, show_capture_btn))
end

----------------------------------------------------------------
-- Field handler
----------------------------------------------------------------

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "blueprint_tool:creation_main"
  and formname ~= "blueprint_tool:slot_picker"
  and formname ~= "blueprint_tool:analysis"
  and formname ~= "blueprint_tool:finetune" then return end

  local playerName = player:get_player_name()
  local itemstack = player:get_wielded_item()
  if itemstack:get_name() ~= "blueprint_tool:creation_tool" then return end

  if formname == "blueprint_tool:creation_main" then
    if fields.pick_slot then
      show_slot_picker(playerName)
      return
    end

    if fields.show_volume then
      local pos1, pos2 = blueprint_tool.logic.get_selection(itemstack)
      blueprint_tool.entity.show_area(playerName, pos1, pos2)
      minetest.show_formspec(playerName, "blueprint_tool:creation_main", "")
      return
    end

    if fields.hide_volume then
      blueprint_tool.entity.hide_area(playerName)
      show_main(playerName, itemstack)
      return
    end

    if fields.clear_pos1 then
      blueprint_tool.logic.clear_pos1(itemstack)
      player:set_wielded_item(itemstack)
      local _, pos2 = blueprint_tool.logic.get_selection(itemstack)
      blueprint_tool.entity.show_area(playerName, pos2, nil)
      show_main(playerName, itemstack)
      return
    end

    if fields.clear_pos2 then
      blueprint_tool.logic.clear_pos2(itemstack)
      player:set_wielded_item(itemstack)
      local pos1, _ = blueprint_tool.logic.get_selection(itemstack)
      blueprint_tool.entity.show_area(playerName, pos1, nil)
      show_main(playerName, itemstack)
      return
    end

    if fields.finetune then
      show_finetune(playerName, itemstack)
      return
    end

    if fields.analyze then
      local pos1, pos2 = blueprint_tool.logic.get_selection(itemstack)
      local result, err = blueprint_tool.logic.analyze_selection(pos1, pos2, playerName)
      if not result then
        notify(playerName, "Cannot analyze: "..err)
        return
      end
      show_analysis(playerName, result, true)
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
      local bp, err = blueprint_tool.logic.capture(itemstack, playerName)
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

  if formname == "blueprint_tool:analysis" then
    if fields.analysis_back then
      analysis_cache[playerName] = nil
      show_main(playerName, itemstack)
      return
    end

    if fields.analysis_capture then
      local slot_idx = get_active_slot(itemstack)
      if not slot_idx then
        notify(playerName, "No slot selected - pick one first")
        return
      end
      local bp, err = blueprint_tool.logic.capture(itemstack, playerName)
      if not bp then
        notify(playerName, "Capture failed: "..err)
        return
      end
      local existing = blueprint_tool.storage.get_player_slot(playerName, slot_idx)
      if existing and existing.bp_id then
        blueprint_tool.storage.delete_blueprint(existing.bp_id)
      end
      local id = blueprint_tool.storage.store_blueprint(bp)
      local slot_data = blueprint_tool.storage.get_player_slot(playerName, slot_idx) or {}
      blueprint_tool.storage.set_player_slot(playerName, slot_idx, { name = slot_data.name or "", bp_id = id })
      analysis_cache[playerName] = nil
      notify(playerName, "Captured into slot "..slot_idx.." ("..#bp.nodes.." nodes)")
      show_main(playerName, itemstack)
      return
    end
  end

  if formname == "blueprint_tool:finetune" then
    if fields.ft_return then
      show_main(playerName, itemstack)
      return
    end

    for btn, def in pairs(FACE_BUTTONS) do
      if fields[btn] then
        local axis, is_max_face, delta = def[1], def[2], def[3]
        if apply_face_adjust(itemstack, axis, is_max_face, delta) then
          player:set_wielded_item(itemstack)
          local pos1, pos2 = blueprint_tool.logic.get_selection(itemstack)
          blueprint_tool.entity.show_area(playerName, pos1, pos2)
        end
        show_finetune(playerName, itemstack)
        return
      end
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
    local playerName = user:get_player_name()
    local pos
    if pointed_thing.type == "node" then
      pos = pointed_thing.under
    else
      local p = user:get_pos()
      pos = vector.new(blueprint_tool.round(p.x), blueprint_tool.round(p.y) + 1, blueprint_tool.round(p.z))
    end

    local slot_idx, was_assigned = get_or_assign_slot(playerName, itemstack)

    if not player_can_use_pos(playerName, pos) then
      notify(playerName, "You can't place blueprint positions in a protected area")
      return itemstack
    end

    if user:get_player_control().sneak then
      local final, adjusted = blueprint_tool.logic.set_pos2(itemstack, pos)
      local pos1, _ = blueprint_tool.logic.get_selection(itemstack)
      blueprint_tool.entity.show_area(playerName, pos1, final)
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
      local _, pos2 = blueprint_tool.logic.get_selection(itemstack)
      blueprint_tool.entity.show_area(playerName, final, pos2)
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
    local name = objRef:get_player_name()
    picker_page[name]    = nil
    analysis_cache[name] = nil
  end
end)
