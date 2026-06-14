# Blueprint Tool

A Luanti mod for capturing and pasting structures.

---

## Tools

### Blueprint Creation Tool

Used to select a region and capture it as a blueprint.

**Controls:**
- **Punch** a node -- set Corner 1 (the **front** of your blueprint)
- **Sneak + Punch** a node -- set Corner 2 (the **back-opposite** corner)
- **Right-click** -- open the blueprint menu

The selection volume displays a colored overlay entity showing all six faces labeled.
The face labels reflect fixed world directions: F/B along the Z axis, L/R along the X axis, U/D along the Y axis.
Use them as a reference when planning which way to orient your structure before capturing.

Face labels and colors:
- **F** (Front) / **B** (Back) -- shades of blue (cyan to deeper blue)
- **L** (Left) / **R** (Right) -- shades of orange/red
- **U** (Up) / **D** (Down) -- shades of green to yellow-green (most muted, least directionally important)

**Menu options:**
- **Pick Slot** -- choose which blueprint slot to save into
- **Rename** -- name the slot
- **Show / Hide Volume** -- toggle the area overlay entity
- **Adjust Volume** -- open a floating panel to nudge each face ±1 node at a time
- **Clear** -- clear Corner 1 or Corner 2
- **Analyze** -- preview the node list and count before capturing
- **Capture** -- save the selected region into the active slot

> Corner positions expire after **1 hour**. Punch nodes again if the positions show as unset.

---

### Blueprint Placer Tool

Used to select a captured blueprint and place it into the world.

**Controls:**
- **Punch** a node -- set the paste origin (bottom-left-front corner of where the blueprint will land); requires a blueprint to be selected first
- **Right-click** -- open the placer menu

**Menu options:**
- **Pick Blueprint** -- choose from your captured blueprints (empty slots are hidden)
- **Show / Hide Volume** -- toggle the area overlay showing where the blueprint will land
- **Adjust Volume** -- open a floating panel to shift the paste origin along X / Y / Z one node at a time
- **Paste** -- place the blueprint *(not yet implemented)*

**Placer menu panels:**

The menu shows two side-by-side analysis panels whenever a blueprint is selected:

- **Blueprint Analysis** (left) -- the node contents of the selected blueprint: total node count, liquid node count, and a scrollable breakdown by node type
- **Placement Analysis** (right) -- a live scan of the destination, computed each time the menu opens:
  - *Protected* -- positions blocked by area protection
  - *Already in place* -- nodes that are already correct at the destination
  - *Will replace* -- buildable-to nodes (liquids etc.) that will be overwritten
  - *Needs digging* -- solid nodes that must be dug before placing
  - *Undiggable* -- nodes with no standard dig groups (bedrock-equivalents); these positions will be skipped
  - *Will place* -- nodes the player has in inventory and can place (or all nodes if creative/give priv)
  - *Missing* -- nodes not in inventory (hidden if zero)

> The paste origin expires after **1 hour**. Punch a node again to reset it.

---

## Blueprint Slots

Each player has a number of blueprint slots determined by their privileges:

| Privilege | Slots |
|---|---|
| *(default)* | 10 |
| `more_blueprints` | 100 |
| `even_more_blueprints` or `server` | 500 |

Slot counts are configurable in server settings (see below).

---

## Privileges

| Privilege | Description |
|---|---|
| `allow_capture_protected` | Allows capturing nodes inside protected areas |
| `more_blueprints` | Raises the player's blueprint slot limit |
| `even_more_blueprints` | Raises the slot limit further |

---

## Server Settings

All settings are prefixed `blueprint_tool_`.

| Setting | Default | Description |
|---|---|---|
| `max_size_x` | 32 | Maximum blueprint width (X axis) |
| `max_size_y` | 32 | Maximum blueprint height (Y axis) |
| `max_size_z` | 32 | Maximum blueprint depth (Z axis) |
| `nodes_per_tick` | 8 | Nodes placed per tick during paste |
| `default_slots` | 10 | Blueprint slots for normal players |
| `more_slots` | 100 | Slots for players with `more_blueprints` |
| `even_more_slots` | 500 | Slots for players with `even_more_blueprints` |

---

## Notes

- Air and unloaded (`ignore`) nodes are not captured
- Liquid nodes are captured but flagged with a warning in the analysis view
- Blueprints are stored in memory and **do not persist across server restarts** (persistence is planned)
- The selection is clamped to the configured max size -- if a corner is placed too far from the other, it will snap to the limit
