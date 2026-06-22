local S = blueprint_tool.TRANSLATOR
local SLOTS_PER_PAGE = 10

local picker_page    = {}  -- [playerName] = current page (transient)
local analysis_cache = {}  -- [playerName] = last analysis result (transient)

local function notify(playerName, msg)
  blueprint_tool.show_popup(playerName, msg)
end

local function get_p_active_slot(itemstack)
  local slot = itemstack:get_meta():get_int("p_active_slot")
  return slot > 0 and slot or nil
end

local function set_p_active_slot(itemstack, slot_idx)
  itemstack:get_meta():set_int("p_active_slot", slot_idx or 0)
end

local function get_rotation(itemstack)
  return itemstack:get_meta():get_int("p_rotation")  -- 0/90/180/270, default 0
end

local function set_rotation(itemstack, angle)
  itemstack:get_meta():set_int("p_rotation", angle % 360)
end

local function get_dig_enabled(itemstack)
  return itemstack:get_meta():get_int("p_dig_disabled") ~= 1
end

local function set_dig_enabled(itemstack, enabled)
  itemstack:get_meta():set_int("p_dig_disabled", enabled and 0 or 1)
end

----------------------------------------------------------------
-- Filled-slot helpers
----------------------------------------------------------------

local function get_filled_slots(playerName, limit)
  local filled = {}
  for i = 1, limit do
    local slot = blueprint_tool.storage.get_player_slot(playerName, i)
    if slot and slot.bp_id then
      filled[#filled + 1] = { index = i, slot = slot }
    end
  end
  return filled
end

----------------------------------------------------------------
-- Formspecs
----------------------------------------------------------------

local function build_main_formspec(playerName, itemstack)
  local slot_idx  = get_p_active_slot(itemstack)
  local slot_data = slot_idx and blueprint_tool.storage.get_player_slot(playerName, slot_idx)
  local has_bp    = slot_data and slot_data.bp_id

  local slot_label
  if slot_idx and has_bp then
    slot_label = "Slot "..
      minetest.colorize(blueprint_tool.COLOR_ACCENT, tostring(slot_idx))..
      ": "..minetest.formspec_escape(slot_data.name ~= "" and slot_data.name or "(unnamed)")
  else
    slot_label = minetest.colorize(blueprint_tool.COLOR_WARN, "No blueprint selected")
  end

  local origin = blueprint_tool.logic.get_origin(itemstack)
  local bp     = has_bp and blueprint_tool.storage.get_blueprint(slot_data.bp_id)
  local pos2   = origin and bp and vector.add(origin, bp.size)
  local origin_str = origin and minetest.pos_to_string(origin) or "not set"
  local pos2_str   = pos2   and minetest.pos_to_string(pos2)   or "not set"

  local bw, bh = 0.6, 0.6
  local y1 = 0.3

  local function axis_group(gx, lbl, minus_name, plus_name)
    return "label["..gx..",".. (y1 + 0.3) ..";"..lbl.."]"..
      "button["..(gx+0.6)..","..y1..";"..bw..","..bh..";"..minus_name..";-]"..
      "button["..(gx+1.3)..","..y1..";"..bw..","..bh..";"..plus_name..";+]"
  end

  local axis_btns = ""
  if origin then
    axis_btns =
      axis_group(4.7, "X:", "pa_x_minus", "pa_x_plus")..
      axis_group(7.0, "Y:", "pa_y_minus", "pa_y_plus")..
      axis_group(9.3, "Z:", "pa_z_minus", "pa_z_plus")
  end

  local angle = get_rotation(itemstack)
  local function rot_label(deg)
    local lbl = deg .. "\xc2\xb0"  -- degree sign UTF-8
    return deg == angle and ("<" .. lbl .. ">") or lbl
  end
  local rot_btns =
    "label[4.7,1.37;Rotation:]"..
    "button[6.2,1.1;1.2,0.6;rot_0;"   ..rot_label(0)  .."]"..
    "button[7.5,1.1;1.2,0.6;rot_90;"  ..rot_label(90) .."]"..
    "button[8.8,1.1;1.2,0.6;rot_180;" ..rot_label(180).."]"..
    "button[10.1,1.1;1.2,0.6;rot_270;"..rot_label(270).."]"

  local dig_btn = ""
  if blueprint_tool.settings.allow_placer_dig and has_bp and origin then
    local dig_on = get_dig_enabled(itemstack)
    local dig_label = dig_on and "Dig Nodes: On" or "Dig Nodes: Off"
    local dig_tip = dig_on
      and "Nodes in the way of the blueprint will be dug up"
      or  "Nodes in the way of the blueprint will be skipped over"
    dig_btn = "button[3.1,1.7;2.7,0.6;toggle_dig;"..dig_label.."]"..
      "tooltip[toggle_dig;"..minetest.formspec_escape(dig_tip).."]"
  end

  local place_btn = (has_bp and origin)
    and "button[11.5,1.7;2.7,0.6;pa_place;Place]"
    or  ""

  local analyze_btn = (has_bp and origin)
    and "button[14.3,1.7;2.7,0.6;analyze;Analyze]"
    or  ""

  local preview_btn = (has_bp and origin)
    and "button[0.2,1.7;2.7,0.6;pa_preview;Preview]"
    or  ""

  return blueprint_tool.fs_header(17.5, 2.8, {x=0.5, y=0.85}, {x=0.5, y=0.5}, "#00000033")..
    "label[0.2,0.5;"..minetest.formspec_escape(slot_label).."]"..
    "button[3.1,0.2;1.5,0.65;pick_slot;Pick Slot]"..
    "button[16.1,0.1;1.2,0.6;help;"..minetest.colorize(blueprint_tool.COLOR_WARN, "Help").."]"..
    axis_btns..
    rot_btns..
    "label[11.5,0.4;Origin: "..minetest.formspec_escape(origin_str).."]"..
    "label[11.5,0.95;End: "..minetest.formspec_escape(pos2_str).."]"..
    dig_btn..
    place_btn..
    analyze_btn..
    preview_btn
end

local function build_analyze_formspec(playerName, bp_ana, placement, has_bp, has_origin)
  local LEFT_X = 0.3
  local RIGHT_X = 8.4
  local LIST_W  = 7.4
  local PANEL_Y = 0.9
  local ROW_H   = 0.62

  local fs = blueprint_tool.fs_header(16.0, 9.0)..
    "label["..LEFT_X..",0.4;Blueprint Analysis]"..
    "label["..RIGHT_X..",0.4;Placement Analysis]"

  ----------------------------------------------------------------
  -- Left panel: blueprint analysis
  ----------------------------------------------------------------
  if bp_ana then
    local y = PANEL_Y

    local summary
    if bp_ana.total_captured == 0 then
      summary = minetest.colorize(blueprint_tool.COLOR_WARN, "Blueprint is empty")
    else
      summary = "Contains "..
        minetest.colorize(blueprint_tool.COLOR_ACCENT, tostring(bp_ana.total_captured)).." nodes"
      if bp_ana.total_liquid and bp_ana.total_liquid > 0 then
        summary = summary.."  ("..
          minetest.colorize(blueprint_tool.COLOR_WARN, bp_ana.total_liquid.." liquid")..")"
      end
    end

    fs = fs.."label["..LEFT_X..","..y..";"..minetest.formspec_escape(summary).."]"
    y = y + 0.7

    local entries = {}
    for _, entry in ipairs(bp_ana.nodes) do
      entries[#entries + 1] = minetest.formspec_escape(entry.count.."x  "..entry.display_name)
    end
    fs = fs.."image["..(LEFT_X-0.1)..","..(y-0.1)..";"..(LIST_W+0.2)..",5.7;blueprint_button.png;10]"..
      "textlist["..LEFT_X..","..y..";"..LIST_W..",5.5;node_list;"..
      table.concat(entries, ",")..";0;true]"
  else
    fs = fs.."label["..LEFT_X..","..PANEL_Y..";"..
      minetest.formspec_escape(minetest.colorize(blueprint_tool.COLOR_WARN, "No blueprint selected")).."]"
  end

  ----------------------------------------------------------------
  -- Right panel: placement analysis
  ----------------------------------------------------------------
  if placement then
    local y = PANEL_Y

    local function row(text)
      fs = fs.."label["..RIGHT_X..","..y..";"..minetest.formspec_escape(text).."]"
      y = y + ROW_H
    end

    local accent = blueprint_tool.COLOR_ACCENT
    local warn   = blueprint_tool.COLOR_WARN

    row("Protected: "..minetest.colorize(
      placement.protected > 0 and warn or accent,
      tostring(placement.protected)).." positions")

    row("Already in place: "..
      minetest.colorize(accent, tostring(placement.already_correct)).." nodes")

    if placement.will_be_replaced > 0 then
      row("Will replace: "..
        minetest.colorize(accent, tostring(placement.will_be_replaced)).." nodes")
    end

    if placement.needs_digging > 0 then
      row("Needs digging: "..
        minetest.colorize(accent, tostring(placement.needs_digging)).." nodes")
    end

    if placement.undiggable > 0 then
      row(minetest.colorize(warn,
        "Undiggable: "..tostring(placement.undiggable).." nodes (cannot place)"))
    end

    if placement.cannot_dig_nodes and #placement.cannot_dig_nodes > 0 then
      row(minetest.colorize(warn, "Nodes that don't allow being dug up:"))
      for _, entry in ipairs(placement.cannot_dig_nodes) do
        row("  "..entry.count.."x  "..entry.display_name)
      end
    end

    y = y + 0.2

    if placement.inventory_skipped then
      row("Will place: "..minetest.colorize(accent, tostring(placement.will_place))..
        " nodes (creative)")
    else
      row("Will place: "..minetest.colorize(accent, tostring(placement.will_place)).." nodes")
      if placement.missing > 0 then
        row(minetest.colorize(warn, "Missing: "..tostring(placement.missing).." nodes"))
      end
    end
  else
    local placeholder
    if not has_bp and not has_origin then
      placeholder = "Select a blueprint and set an origin"
    elseif not has_bp then
      placeholder = "Select a blueprint to analyse placement"
    else
      placeholder = "Punch a node to set paste origin"
    end
    fs = fs.."label["..RIGHT_X..","..PANEL_Y..";"..
      minetest.formspec_escape(minetest.colorize(blueprint_tool.COLOR_WARN, placeholder)).."]"
  end

  fs = fs.."button[0.3,8.1;3.8,0.7;analyze_back;Back]"
  return fs
end

local function build_slot_picker_formspec(playerName, page)
  local limit       = blueprint_tool.get_player_slot_limit(playerName)
  local filled      = get_filled_slots(playerName, limit)
  local total_pages = math.max(1, math.ceil(#filled / SLOTS_PER_PAGE))
  page = blueprint_tool.clamp(page, 1, total_pages)

  local start_i = (page - 1) * SLOTS_PER_PAGE + 1
  local end_i   = math.min(start_i + SLOTS_PER_PAGE - 1, #filled)

  local fs = blueprint_tool.fs_header(8.5, 9.5)..
    "label[0.3,0.6;Select Blueprint  -  Page "..page.." / "..total_pages.."]"..
    "button[7.8,0.1;0.6,0.6;back;X]"

  if #filled == 0 then
    fs = fs.."label[0.3,1.5;"..
      minetest.formspec_escape(minetest.colorize(blueprint_tool.COLOR_WARN, "No blueprints captured yet"))..
      "]"
  else
    local y = 1.1
    for i = start_i, end_i do
      local entry = filled[i]
      local bp   = blueprint_tool.storage.get_blueprint(entry.slot.bp_id)
      local name = entry.slot.name ~= "" and entry.slot.name or "(unnamed)"
      local date = bp and bp.captured_at and os.date("%Y-%m-%d %H:%M", bp.captured_at) or ""
      local label = entry.index..". "..name..(date ~= "" and "  ["..date.."]" or "")
      fs = fs.."button[0.3,"..y..";7.9,0.65;slot_"..entry.index..";"..
        minetest.formspec_escape(label).."]"
      y = y + 0.72
    end

    local nav_y = 1.1 + SLOTS_PER_PAGE * 0.72 + 0.2
    if page > 1 then
      fs = fs.."button[0.3,"..nav_y..";3.8,0.7;prev_page;< Prev]"
    end
    if page < total_pages then
      fs = fs.."button[4.4,"..nav_y..";3.8,0.7;next_page;Next >]"
    end
  end

  return fs
end

local function show_main(playerName, itemstack)
  local slot_idx  = get_p_active_slot(itemstack)
  local slot_data = slot_idx and blueprint_tool.storage.get_player_slot(playerName, slot_idx)
  local bp        = slot_data and slot_data.bp_id and blueprint_tool.storage.get_blueprint(slot_data.bp_id)
  local origin    = blueprint_tool.logic.get_origin(itemstack)
  if bp and origin then
    blueprint_tool.entity.show_area(playerName, origin, vector.add(origin, bp.size), get_rotation(itemstack))
  end
  minetest.show_formspec(playerName, "blueprint_tool:placer_main",
    build_main_formspec(playerName, itemstack))
end

local function show_analyze(playerName, itemstack)
  local slot_idx  = get_p_active_slot(itemstack)
  local slot_data = slot_idx and blueprint_tool.storage.get_player_slot(playerName, slot_idx)
  local has_bp    = slot_data and slot_data.bp_id
  local bp        = has_bp and blueprint_tool.storage.get_blueprint(slot_data.bp_id)
  local origin    = blueprint_tool.logic.get_origin(itemstack)
  if bp and not analysis_cache[playerName] then
    analysis_cache[playerName] = blueprint_tool.logic.analyze_blueprint(bp)
  end
  local placement
  if bp and origin then
    placement = blueprint_tool.logic.analyze_placement(bp, origin, playerName)
  end
  minetest.show_formspec(playerName, "blueprint_tool:placer_analyze",
    build_analyze_formspec(playerName, analysis_cache[playerName], placement, has_bp, origin ~= nil))
end

local function show_slot_picker(playerName)
  local page = picker_page[playerName] or 1
  minetest.show_formspec(playerName, "blueprint_tool:placer_picker",
    build_slot_picker_formspec(playerName, page))
end

----------------------------------------------------------------
-- Field handler
----------------------------------------------------------------

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "blueprint_tool:placer_main"
  and formname ~= "blueprint_tool:placer_picker"
  and formname ~= "blueprint_tool:placer_analyze" then return end

  local playerName = player:get_player_name()
  local itemstack  = player:get_wielded_item()
  if itemstack:get_name() ~= "blueprint_tool:placer_tool" then return end

  if not blueprint_tool.player_has_access(playerName) then
    minetest.close_formspec(playerName, formname)
    notify(playerName, "You don't have permission to use blueprint tools")
    return
  end

  if formname == "blueprint_tool:placer_main" then
    if fields.help then
      blueprint_tool.show_help(playerName)
      return
    end

    if fields.pick_slot then
      show_slot_picker(playerName)
      return
    end

    if fields.analyze then
      show_analyze(playerName, itemstack)
      return
    end

    local ROT_BTNS = { rot_0 = 0, rot_90 = 90, rot_180 = 180, rot_270 = 270 }
    for btn, deg in pairs(ROT_BTNS) do
      if fields[btn] then
        set_rotation(itemstack, deg)
        player:set_wielded_item(itemstack)
        show_main(playerName, itemstack)
        return
      end
    end

    if fields.toggle_dig then
      set_dig_enabled(itemstack, not get_dig_enabled(itemstack))
      player:set_wielded_item(itemstack)
      show_main(playerName, itemstack)
      return
    end

    if fields.pa_preview then
      local slot_idx  = get_p_active_slot(itemstack)
      local slot_data = slot_idx and blueprint_tool.storage.get_player_slot(playerName, slot_idx)
      local bp        = slot_data and slot_data.bp_id and
                        blueprint_tool.storage.get_blueprint(slot_data.bp_id)
      local origin    = blueprint_tool.logic.get_origin(itemstack)
      if bp and origin then
        local angle = get_rotation(itemstack)
        blueprint_tool.entity.hide_area(playerName)
        blueprint_tool.logic.show_preview(playerName, slot_data.bp_id, bp, origin, angle)
      end
      minetest.close_formspec(playerName, "blueprint_tool:placer_main")
      return
    end

    if fields.pa_place then
      local slot_idx  = get_p_active_slot(itemstack)
      local slot_data = slot_idx and blueprint_tool.storage.get_player_slot(playerName, slot_idx)
      local bp        = slot_data and slot_data.bp_id and
                        blueprint_tool.storage.get_blueprint(slot_data.bp_id)
      local origin    = blueprint_tool.logic.get_origin(itemstack)

      if not bp or not origin then
        notify(playerName, "Select a blueprint and set an origin first")
        return
      end

      if blueprint_tool.logic.get_paste_task(playerName) then
        minetest.close_formspec(playerName, "blueprint_tool:placer_main")
        notify(playerName, "A placement is already in progress. Use /blueprint_cancel to stop it.")
        return
      end

      local angle = get_rotation(itemstack)
      local dig_nodes = get_dig_enabled(itemstack)
      local ok, err = blueprint_tool.logic.start_paste(playerName, bp, origin, angle, dig_nodes)
      if not ok then
        notify(playerName, err)
        return
      end

      blueprint_tool.entity.hide_area(playerName)
      minetest.close_formspec(playerName, "blueprint_tool:placer_main")
      notify(playerName, "Starting placement...")
      return
    end

    local AXIS_DELTAS = {
      pa_x_plus  = vector.new( 1, 0, 0),
      pa_x_minus = vector.new(-1, 0, 0),
      pa_y_plus  = vector.new( 0, 1, 0),
      pa_y_minus = vector.new( 0,-1, 0),
      pa_z_plus  = vector.new( 0, 0, 1),
      pa_z_minus = vector.new( 0, 0,-1),
    }
    for btn, delta in pairs(AXIS_DELTAS) do
      if fields[btn] then
        local origin = blueprint_tool.logic.get_origin(itemstack)
        if origin then
          local new_origin = vector.add(origin, delta)
          blueprint_tool.logic.set_origin(itemstack, new_origin)
          player:set_wielded_item(itemstack)
          local slot_idx  = get_p_active_slot(itemstack)
          local slot_data = slot_idx and blueprint_tool.storage.get_player_slot(playerName, slot_idx)
          local bp        = slot_data and slot_data.bp_id and blueprint_tool.storage.get_blueprint(slot_data.bp_id)
          if bp then
            blueprint_tool.entity.show_area(playerName, new_origin, vector.add(new_origin, bp.size), get_rotation(itemstack))
          end
        end
        show_main(playerName, itemstack)
        return
      end
    end
  end

  if formname == "blueprint_tool:placer_analyze" then
    if fields.analyze_back then
      show_main(playerName, itemstack)
      return
    end
  end

  if formname == "blueprint_tool:placer_picker" then
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
      local limit       = blueprint_tool.get_player_slot_limit(playerName)
      local filled      = get_filled_slots(playerName, limit)
      local total_pages = math.max(1, math.ceil(#filled / SLOTS_PER_PAGE))
      picker_page[playerName] = math.min(total_pages, (picker_page[playerName] or 1) + 1)
      show_slot_picker(playerName)
      return
    end

    for k in pairs(fields) do
      local idx = tonumber(k:match("^slot_(%d+)$"))
      if idx then
        local slot_data = blueprint_tool.storage.get_player_slot(playerName, idx)
        if not slot_data or not slot_data.bp_id then
          notify(playerName, "That slot has no blueprint")
          show_slot_picker(playerName)
          return
        end

        set_p_active_slot(itemstack, idx)
        player:set_wielded_item(itemstack)

        local bp = blueprint_tool.storage.get_blueprint(slot_data.bp_id)
        if bp then
          analysis_cache[playerName] = blueprint_tool.logic.analyze_blueprint(bp)
        else
          analysis_cache[playerName] = nil
          notify(playerName, "Blueprint data missing for slot "..idx)
        end

        show_main(playerName, itemstack)
        return
      end
    end
  end
end)

----------------------------------------------------------------
-- Tool registration
----------------------------------------------------------------

minetest.register_tool("blueprint_tool:placer_tool", {
  description = minetest.colorize("#55FF55", S("Blueprint Placer Tool")) ..
    S("\nPunch to set origin for placing\nRight-click: Menu\nSneak+Right-click to switch mode"),
  short_description = S("Blueprint Placer Tool"),
  inventory_image = "placer_tool.png",
  wield_image = "placer_tool.png",
  stack_max = 1,

  on_use = function(itemstack, user, pointed_thing)
    if not user or not user:is_player() then return end
    local playerName = user:get_player_name()
    if not blueprint_tool.player_has_access(playerName) then
      notify(playerName, "You don't have permission to use blueprint tools")
      return itemstack
    end

    local slot_idx  = get_p_active_slot(itemstack)
    local slot_data = slot_idx and blueprint_tool.storage.get_player_slot(playerName, slot_idx)
    local bp        = slot_data and slot_data.bp_id and blueprint_tool.storage.get_blueprint(slot_data.bp_id)

    if not bp then
      notify(playerName, "No blueprint picked yet - right-click to Pick Slot")
      return itemstack
    end

    local pos
    if pointed_thing.type == "node" then
      pos = pointed_thing.under
    else
      local p = user:get_pos()
      pos = vector.new(blueprint_tool.round(p.x), blueprint_tool.round(p.y) + 1, blueprint_tool.round(p.z))
    end

    blueprint_tool.logic.set_origin(itemstack, pos)
    blueprint_tool.entity.show_area(playerName, pos, vector.add(pos, bp.size), get_rotation(itemstack))
    notify(playerName, "Paste origin set: "..minetest.pos_to_string(pos))
    return itemstack
  end,

  on_place = function(itemstack, placer, pointed_thing)
    if not placer or not placer:is_player() then return end
    local playerName = placer:get_player_name()
    if not blueprint_tool.player_has_access(playerName) then
      notify(playerName, "You don't have permission to use blueprint tools")
      return itemstack
    end
    if placer:get_player_control().sneak then
      blueprint_tool.tools.swap_tool(placer, itemstack)
      return
    end
    show_main(playerName, itemstack)
  end,

  on_secondary_use = function(itemstack, user, pointed_thing)
    if not user or not user:is_player() then return end
    local playerName = user:get_player_name()
    if not blueprint_tool.player_has_access(playerName) then
      notify(playerName, "You don't have permission to use blueprint tools")
      return itemstack
    end
    if user:get_player_control().sneak then
      blueprint_tool.tools.swap_tool(user, itemstack)
      return
    end
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
