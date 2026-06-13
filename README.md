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
- **Clear** -- clear Corner 1 or Corner 2
- **Analyze** -- preview the node list and count before capturing
- **Capture** -- save the selected region into the active slot

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
