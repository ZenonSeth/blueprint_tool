# Blueprint Tool

A [Luanti](https://www.luanti.org/) mod for capturing and pasting structures.

## Using The Tool

A single tool switches between two modes with Sneak+Right-click: **Creation** (select an area and capture it) and **Placer** (choose a saved blueprint and place it down with rotation).

- **Creation:** Punch to set corners, right-click for the menu. Select a slot, adjust the selection, then Capture. Optionally press Analyze to see what will be captured.
- **Placer:** Pick a saved blueprint, punch to set the paste origin, choose a rotation, then Place. Placement runs in the background; use `/blueprint_cancel` to abort.

Placing consumes items from your inventory (unless you have `creative` or `give` privileges). The **Analyze** panel shows exactly what's needed and what's missing before you commit.

Blueprints can be shared as physical items: right-click a blank **Blueprint** to create a **Blueprint Reference** linked to one of your slots. Other players can import it into their own slots.

Each player gets a set of persistent blueprint slots (count depends on privileges). An in-game guide is available via the **Help** button or `/blueprint_help`.

---

## Server Configuration

| Setting | Default | Description |
|---|---|---|
| `blueprint_tool_open_access` | true | When true, all players may use blueprint tools without needing `basic_blueprints` priv |
| `blueprint_tool_allow_placer_dig` | true | When true, the placer tool can dig existing nodes to make room |
| `blueprint_tool_max_size_x` | 32 | Maximum blueprint width (X axis) |
| `blueprint_tool_max_size_y` | 32 | Maximum blueprint height (Y axis) |
| `blueprint_tool_max_size_z` | 32 | Maximum blueprint depth (Z axis) |
| `blueprint_tool_nodes_per_tick` | 8 | Nodes placed per server tick during placement |
| `blueprint_tool_default_slots` | 10 | Blueprint slots for players with `basic_blueprints` (or when open access is on) |
| `blueprint_tool_more_slots` | 100 | Slots for players with `more_blueprints` |
| `blueprint_tool_even_more_slots` | 500 | Slots for players with `even_more_blueprints` |

### Privileges

| Privilege | Description |
|---|---|
| `basic_blueprints` | Allows using blueprint tools. Not required when `open_access = true` (the default). |
| `more_blueprints` | Raises the player's slot limit (also grants basic access) |
| `even_more_blueprints` | Raises the slot limit further (also grants basic access) |
| `allow_capture_protected` | Allows capturing nodes inside protected areas |
| `blueprint_admin` | Allows `/blueprint_clear_all` and access to other players' blueprints in management UIs |

### Chat Commands

| Command | Description |
|---|---|
| `/blueprint_cancel` | Cancel your active blueprint placement |
| `/blueprint_clear` | Delete all your saved blueprints and slots |
| `/blueprint_clear_all` | Delete ALL PLAYERS' blueprints (requires `blueprint_admin` or `server`) |
| `/blueprint_manage` | Open the blueprint manager (admins can manage other players) |
| `/blueprint_help` | Open the in-game guide |

### Uninstallation

Run `/blueprint_clear_all` before removing the mod to avoid leaving orphaned data in mod_storage.
