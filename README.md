# Blueprint Tool

A [Luanti](https://www.luanti.org/) mod for capturing and pasting structures.

There's a single tool that switches between two modes: Creation, for selecting an area and capturing it into a blueprint, and Placer, for choosing a saved blueprint and placing it down (with rotation and fine positioning). Sneak+Right-click swaps between the two modes at any time.

Each player has their own persistent set of blueprint slots, so captures stick around between sessions.

Blueprints can also be packaged as physical items. A blank Blueprint item lets you create a Blueprint Reference to one of your saved blueprints, which can then be given or traded to other players. Whoever holds the reference can import it into their own blueprint slots. If you don't want a reference copied further once it's been traded away, you can mark it so it can't be re-shared.

> An in-game guide covering the tool usages is available via the **Help** button on either tool's menu, or by running `/blueprint_help`.

---

## Tools

### Blueprint Creation Tool

Used to select a region and capture it as a blueprint.

**Controls:**
- **Punch** a node : set Corner 1 (the **front** of your blueprint)
- **Sneak + Punch** a node : set Corner 2 (the **back-opposite** corner)
- **Right-click** : open the blueprint menu
- **Sneak + Right-click** : switch to the Placer Tool

The selection volume displays a colored overlay entity showing all six faces labeled.
The face labels reflect fixed world directions: F/B along the Z axis, L/R along the X axis, U/D along the Y axis.
Use them as a reference when planning which way to orient your structure before capturing.

Face labels and colors:
- **F** (Front) / **B** (Back) : shades of blue (cyan to deeper blue)
- **L** (Left) / **R** (Right) : shades of orange/red
- **U** (Up) / **D** (Down) : shades of green to yellow-green (most muted, least directionally important)

**Menu options:**
- **Pick Slot** : choose which blueprint slot to save into
- **Rename** : name the slot
- **Front / Back / Top / Bottom / Left / Right +/-** : nudge each face of the selection +/- 1 node at a time (only shown when both corners are set)
- **Clear Pos** : clear both corner positions
- **Analyze** : preview the node list and count before capturing
- **Capture** : save the selected region into the active slot

> Corner positions expire after **5 minutes**. Punch nodes again if the positions show as unset.

---

### Blueprint Placer Tool

Used to select a captured blueprint and place it into the world.

**Controls:**
- **Punch** a node : set the place origin (bottom-left-front corner of where the blueprint will land); requires a blueprint to be selected first
- **Right-click** : open the placer menu
- **Sneak + Right-click** : switch to the Creation Tool

**Menu options:**
- **Pick Slot** : choose from your captured blueprints (empty slots are hidden)
- **X / Y / Z +/-** : shift the paste origin one node at a time along each axis (only shown when origin is set)
- **Rotation** : rotate the blueprint around the Y axis before placing: `0°` `90°` `180°` `270°` (active angle shown in angle brackets)
- **Place** : begin placing the blueprint into the world
- **Analyze** : open a detailed breakdown of the blueprint contents and placement impact

**Analyze panel** (opened via the Analyze button):

Shows two side-by-side panels:

- **Blueprint Analysis** (left) : the node contents of the selected blueprint: total node count, liquid node count, and a scrollable breakdown by node type
- **Placement Analysis** (right) : a live scan of the destination, computed each time the panel opens:
  - *Protected* : positions blocked by area protection
  - *Already in place* : nodes that are already correct at the destination
  - *Will replace* : buildable-to nodes (liquids etc.) that will be overwritten
  - *Needs digging* : solid nodes that must be dug before placing
  - *Undiggable* : nodes with no standard dig groups (bedrock-equivalents); these positions will be skipped
  - *Cannot be dug* : nodes that are diggable in principle but blocked by a callback (e.g. full chests); skipped
  - *Will place* : nodes the player has in inventory and can place (or all nodes if creative/give priv)
  - *Missing* : nodes not in inventory (hidden if zero)

> The place origin expires after **5 minutes**. Punch a node again to reset it.

Placement runs in the background at a rate of `nodes_per_tick` nodes per server tick, bottom-to-top.
Use `/blueprint_cancel` to abort an active placement.

---

### Sharing Blueprints

Blueprints can also be packaged as items and traded between players. A blank **Blueprint** item, right-clicked, lets you create a **Blueprint Reference** linked to one of your saved slots (consuming the blank item in the process). Give or trade the reference to another player, and right-clicking it lets them Import the blueprint into their own slots. If you don't want it shared any further once it's out of your hands, check "Disallow further copying" when creating the reference : imported copies inherit that restriction too.

---

## Blueprint Slots

Each player has a number of blueprint slots determined by their privileges:

| Privilege | Slots |
|---|---|
| `basic_blueprints` *(or open access)* | 10 |
| `more_blueprints` | 100 |
| `even_more_blueprints` or `server` | 500 |

Slot counts are configurable in server settings (see below).

---

## Privileges

| Privilege | Description |
|---|---|
| `basic_blueprints` | Allows using blueprint tools (default slot limit). Not required when `blueprint_tool_open_access = true` (the default). |
| `more_blueprints` | Raises the player's blueprint slot limit (also grants basic access) |
| `even_more_blueprints` | Raises the slot limit further (also grants basic access) |
| `allow_capture_protected` | Allows capturing nodes inside protected areas |
| `blueprint_admin` | Allows running `/blueprint_clear_all`, and grants access to other players' blueprints in `/blueprint_manage` and the Create Reference menu |

---

## Chat Commands

| Command | Description |
|---|---|
| `/blueprint_cancel` | Cancel your active blueprint placement |
| `/blueprint_clear` | Delete all your saved blueprints and slots |
| `/blueprint_clear_all` | Delete **all** players' blueprints (requires `blueprint_admin` or `server` priv) |
| `/blueprint_manage` | Open the blueprint manager (view/delete saved slots; admins can manage other players') |
| `/blueprint_help` | Open the in-game guide |

---

## Server Settings

All settings are prefixed `blueprint_tool_`.

| Setting | Default | Description |
|---|---|---|
| `open_access` | true | When true, all players may use blueprint tools without needing `basic_blueprints` priv |
| `max_size_x` | 32 | Maximum blueprint width (X axis) |
| `max_size_y` | 32 | Maximum blueprint height (Y axis) |
| `max_size_z` | 32 | Maximum blueprint depth (Z axis) |
| `nodes_per_tick` | 8 | Nodes placed per server tick during placement |
| `default_slots` | 10 | Blueprint slots for players with `basic_blueprints` (or when open access is on) |
| `more_slots` | 100 | Slots for players with `more_blueprints` |
| `even_more_slots` | 500 | Slots for players with `even_more_blueprints` |

---

## Notes

- Air and unloaded (`ignore`) nodes are not captured
- Liquid nodes are captured but flagged with a warning in the analysis view
- Blueprints persist across server restarts (stored via mod_storage)
- The selection is clamped to the configured max size : if a corner is placed too far from the other, it will snap to the limit

---

## Uninstallation

Before removing the mod, it is recommended to run `/blueprint_clear_all` (requires `blueprint_admin` or `server` priv) to wipe all blueprint data from mod_storage. Skipping this step leaves orphaned data in the world's storage that cannot be cleaned up without the mod present.
