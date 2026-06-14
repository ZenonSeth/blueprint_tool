local S = blueprint_tool.TRANSLATOR
local SLOTS_PER_PAGE = 10

local picker_page    = {}  -- [playerName] = current page (transient)
local analysis_cache = {}  -- [playerName] = last analysis result (transient)

local function notify(playerName, msg)
  blueprint_tool.show_popup(playerName, msg)
end

local function get_active_slot(itemstack)
  local slot = itemstack:get_meta():get_int("active_slot")
  return slot > 0 and slot or nil
end

local function set_active_slot(itemstack, slot_idx)
  itemstack:get_meta():set_int("active_slot", slot_idx or 0)
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

local LEFT_X  = 0.3
local RIGHT_X = 8.4
local LIST_W  = 7.4
local PANEL_Y = 3.1
local ROW_H   = 0.62

local function build_main_formspec(playerName, itemstack, placement)
  local slot_idx  = get_active_slot(itemstack)
  local slot_data = slot_idx and blueprint_tool.storage.get_player_slot(playerName, slot_idx)
  local bp_ana    = analysis_cache[playerName]

  local slot_line
  if slot_idx and slot_data and slot_data.bp_id then
    slot_line = "Slot "..
      minetest.colorize(blueprint_tool.COLOR_ACCENT, tostring(slot_idx))..
      ": "..minetest.formspec_escape(slot_data.name ~= "" and slot_data.name or "(unnamed)")
  else
    slot_line = minetest.colorize(blueprint_tool.COLOR_WARN, "No blueprint selected")
  end

  local origin     = blueprint_tool.logic.get_origin(itemstack)
  local origin_str = origin and minetest.pos_to_string(origin)
    or minetest.colorize(blueprint_tool.COLOR_WARN, "not set")

  local has_bp    = slot_data and slot_data.bp_id
  local paste_btn = (has_bp and origin)
    and "button[11.5,1.4;3.5,0.7;paste;Paste]"
    or  ""
  local vol_btn
  if has_bp then
    if blueprint_tool.entity.is_area_visible(playerName) then
      vol_btn = "button[0.3,2.2;3.8,0.7;hide_volume;Hide Volume]"
    else
      vol_btn = "button[0.3,2.2;3.8,0.7;show_volume;Show Volume]"
    end
  else
    vol_btn = ""
  end

  local fs = blueprint_tool.fs_header(16.0, 9.5)..
    "button_exit[15.3,0.1;0.6,0.6;close;X]"..
    "label[0.3,0.6;"..minetest.formspec_escape(slot_line).."]"..
    "button[11.5,0.2;3.5,0.7;pick_slot;Pick Blueprint]"..
    "label[0.3,1.6;Origin: "..minetest.formspec_escape(origin_str).."]"..
    paste_btn..
    vol_btn..
    "label["..LEFT_X..","..PANEL_Y..";Blueprint Analysis]"..
    "label["..RIGHT_X..","..PANEL_Y..";Placement Analysis]"

  ----------------------------------------------------------------
  -- Left panel: blueprint analysis
  ----------------------------------------------------------------
  if bp_ana then
    local y = PANEL_Y + 0.7

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
    fs = fs.."textlist["..LEFT_X..","..y..";"..LIST_W..",4.5;node_list;"..
      table.concat(entries, ",")..";0;false]"
  else
    fs = fs.."label["..LEFT_X..","..(PANEL_Y + 0.7)..";Pick a blueprint to see analysis]"
  end

  ----------------------------------------------------------------
  -- Right panel: placement analysis
  ----------------------------------------------------------------
  if placement then
    local y = PANEL_Y + 0.7

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

    y = y + 0.2  -- gap before inventory summary

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
    if not has_bp and not origin then
      placeholder = "Select a blueprint and set an origin"
    elseif not has_bp then
      placeholder = "Select a blueprint to analyse placement"
    else
      placeholder = "Punch a node to set paste origin"
    end
    fs = fs.."label["..RIGHT_X..","..(PANEL_Y + 0.7)..";"..
      minetest.formspec_escape(minetest.colorize(blueprint_tool.COLOR_WARN, placeholder)).."]"
  end

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
      local label = entry.index..". "..
        (entry.slot.name ~= "" and entry.slot.name or "(unnamed)")
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
  local placement
  local slot_idx  = get_active_slot(itemstack)
  local slot_data = slot_idx and blueprint_tool.storage.get_player_slot(playerName, slot_idx)
  local origin    = blueprint_tool.logic.get_origin(itemstack)
  if slot_data and slot_data.bp_id and origin then
    local bp = blueprint_tool.storage.get_blueprint(slot_data.bp_id)
    if bp then
      placement = blueprint_tool.logic.analyze_placement(bp, origin, playerName)
    end
  end
  minetest.show_formspec(playerName, "blueprint_tool:placer_main",
    build_main_formspec(playerName, itemstack, placement))
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
  and formname ~= "blueprint_tool:placer_picker" then return end

  local playerName = player:get_player_name()
  local itemstack  = player:get_wielded_item()
  if itemstack:get_name() ~= "blueprint_tool:placer_tool" then return end

  if formname == "blueprint_tool:placer_main" then
    if fields.pick_slot then
      show_slot_picker(playerName)
      return
    end

    if fields.show_volume then
      local origin    = blueprint_tool.logic.get_origin(itemstack)
      local slot_idx  = get_active_slot(itemstack)
      local slot_data = slot_idx and blueprint_tool.storage.get_player_slot(playerName, slot_idx)
      local bp        = slot_data and slot_data.bp_id and blueprint_tool.storage.get_blueprint(slot_data.bp_id)
      if not origin then
        notify(playerName, "No origin set - punch a node to set paste origin")
      elseif bp then
        blueprint_tool.entity.show_area(playerName, origin, vector.add(origin, bp.size))
      end
      show_main(playerName, itemstack)
      return
    end

    if fields.hide_volume then
      blueprint_tool.entity.hide_area(playerName)
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

        set_active_slot(itemstack, idx)
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
  description = S("Blueprint Placer Tool\nPunch to set origin for placing\nRight-click to select a blueprint"),
  short_description = S("Blueprint Placer Tool"),
  inventory_image = "placer_tool.png",
  wield_image = "placer_tool.png",
  stack_max = 1,

  on_use = function(itemstack, user, pointed_thing)
    if not user or not user:is_player() then return end
    local playerName = user:get_player_name()

    local slot_idx  = get_active_slot(itemstack)
    local slot_data = slot_idx and blueprint_tool.storage.get_player_slot(playerName, slot_idx)
    local bp        = slot_data and slot_data.bp_id and blueprint_tool.storage.get_blueprint(slot_data.bp_id)

    if not bp then
      notify(playerName, "No blueprint picked yet")
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
    blueprint_tool.entity.show_area(playerName, pos, vector.add(pos, bp.size))
    notify(playerName, "Paste origin set: "..minetest.pos_to_string(pos))
    return itemstack
  end,

  on_place = function(itemstack, placer, pointed_thing)
    if not placer or not placer:is_player() then return end
    show_main(placer:get_player_name(), itemstack)
  end,

  on_secondary_use = function(itemstack, user, pointed_thing)
    if not user or not user:is_player() then return end
    show_main(user:get_player_name(), itemstack)
  end,
})

minetest.register_on_leaveplayer(function(objRef)
  if objRef:is_player() then
    local name = objRef:get_player_name()
    picker_page[name]    = nil
    analysis_cache[name] = nil
  end
end)
