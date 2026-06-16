-- Help guide, opened via the Help button on tool forms or /blueprint_help.
-- Topics are a simple ordered list; each entry is { title = "...", text = [[...]] }.
-- text is optional - topics without it just show a blank panel for now.

local TOPICS = {
  { title = "Overview", text = [[The blueprint tool lets you capture an area of the world as a reusable blueprint, and place it again anywhere else.

There's a single tool that switches between two modes: Creation, for selecting an area and capturing it into a blueprint, and Placer, for choosing a saved blueprint and placing it down (with rotation and fine positioning). Sneak+Right-click swaps between the two modes at any time.

Each player has their own persistent set of blueprint slots, so captures stick around between sessions.

Blueprints can also be packaged as physical items. A blank Blueprint item lets you create a Blueprint Reference to one of your saved blueprints, which can then be given or traded to other players. Whoever holds the reference can import it into their own blueprint slots. If you don't want a reference copied further once it's been traded away, you can mark it so it can't be re-shared.]] },
  { title = "Creation Tool", text = [[Used to select an area and capture it into a blueprint slot.

Punch a node to set Pos 1 (the origin corner). Sneak+Punch a node to set Pos 2, defining the opposite corner of the selection box. Once both corners are set, the menu shows the box's size and a set of +/- buttons for each face (Front/Back/Top/Bottom/Left/Right) to fine-tune the selection one node at a time without having to re-punch.

Right-click opens the menu, where you can pick which slot to capture into, rename it, and Clear Pos to start a new selection. Analyze shows a breakdown of what the capture would contain (node counts, anything skipped due to protection, liquids) before you commit. Capture saves the selected area into the chosen slot, overwriting whatever was there before.]] },
  { title = "Placer Tool", text = [[Used to take a saved blueprint and place it back into the world.

Right-click opens the menu, where Pick Slot selects which saved blueprint to place. Punch a node to set the placement origin. Once a blueprint and an origin are both set, +/- buttons let you nudge the origin along X/Y/Z, and rotation buttons (0/90/180/270 degrees) let you orient the blueprint before placing.

Preview shows the blueprint's outline with particles at the target location without placing anything, so you can check positioning first. Analyze reports what placing would actually do at that location, e.g. nodes you have available to place vs. ones you're missing. Place commits the blueprint to the world, consuming matching nodes from your inventory as it builds (unless you have the give or creative_mode privilege).]] },
  { title = "Blueprint Item", text = [[A blank, craftable item used to package one of your saved blueprints for sharing.

Right-click (or use) it to open the Create Reference menu, which lists your saved blueprint slots. Pick one and hit Create Ref to produce a Blueprint Reference item linked to that blueprint, consuming the blank Blueprint item in the process (this always happens, regardless of give/creative privileges).

There's also a "Disallow further copying" checkbox in that menu. Check it before creating the reference if you don't want whoever receives it to be able to create further references from the blueprint it points to.]] },
  { title = "Blueprint Reference Item", text = [[The item produced by the Blueprint item's Create Reference menu - it's how you actually give or trade a blueprint to another player.

Right-click (or use) it to see who originally captured the blueprint, when, its size and node count, and an Import Blueprint button. Importing copies the referenced blueprint into one of your own free slots and consumes the reference item, so it only works once per reference.

If the original blueprint it points to no longer exists (or was overwritten), the reference shows as invalid and can't be imported. If it was created with "Disallow further copying", you can still import and use it yourself, but you won't be able to create a new reference from your imported copy.]] },
  { title = "Managing Blueprints", text = [[Run /blueprint_manage to open the blueprint manager - currently the only way to access it.

It lists your saved blueprint slots with their name, capture date, and node count, and lets you Delete any of them to free up the slot. If you have the blueprint_admin (or server) privilege, the formspec also shows a paginated list of every player who has saved blueprints, plus a name field to jump straight to one; selecting a player lets you view and delete their slots the same way you would your own.]] },
}

local help_state = {}  -- [playerName] = selected topic index

local W, H = 12, 10
local PAD = 0.5
local GAP = 0.25
local CONTENT_W, CONTENT_H = W - PAD * 2, H - PAD * 2
local LIST_W = CONTENT_W / 3
local TEXT_W = CONTENT_W - LIST_W - GAP

local function build_help_formspec(playerName)
  local selected = help_state[playerName] or 1

  local titles = {}
  for i, topic in ipairs(TOPICS) do
    titles[i] = minetest.formspec_escape(topic.title)
  end

  local text = TOPICS[selected] and TOPICS[selected].text or ""

  return blueprint_tool.fs_header(W, H)..
    "textlist["..PAD..","..PAD..";"..LIST_W..","..CONTENT_H..";topics;"..
      table.concat(titles, ",")..";"..selected..";false]"..
    "hypertext["..(PAD + LIST_W + GAP)..","..PAD..";"..TEXT_W..","..CONTENT_H..";topic_text;"..
      minetest.formspec_escape(text).."]"
end

function blueprint_tool.show_help(playerName)
  if not help_state[playerName] then help_state[playerName] = 1 end
  minetest.show_formspec(playerName, "blueprint_tool:help", build_help_formspec(playerName))
end

minetest.register_on_player_receive_fields(function(player, formname, fields)
  if formname ~= "blueprint_tool:help" then return end

  local playerName = player:get_player_name()

  local idx = fields.topics and fields.topics:match("^CHG:(%d+)")
  if idx then
    help_state[playerName] = tonumber(idx)
    minetest.show_formspec(playerName, "blueprint_tool:help", build_help_formspec(playerName))
  end
end)

minetest.register_on_leaveplayer(function(player)
  help_state[player:get_player_name()] = nil
end)

minetest.register_chatcommand("blueprint_help", {
  description = "Open the blueprint tool guide",
  func = function(name)
    blueprint_tool.show_help(name)
    return true
  end,
})
