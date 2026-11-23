# Input and gamepad support

Companion to `CLAUDE.md`. One player: any connected gamepad commands the whole party. Local co-op and button remapping are out of scope, but nothing here locks a gamepad to the party: the tracker takes a `device_id` on every event, so binding one pad per hero later does not require redoing it.

## Pieces

| File | Role |
|---|---|
| `input/input_device_tracker.gd` | `InputDeviceTracker` (pure): active device ("last used wins"), stick dead zone, 4-way stick direction. |
| `input/input_device.gd` | `InputDevice` autoload: classifies every event, hides/shows the mouse cursor, bridges the gamepad to keys, exposes stick axes, LT and `rumble()`. |
| `input/input_bindings.gd` | `InputBindings`: the `act_*` actions (X end / cancel end turn, Y/Tab examine, View log, R3 zoom, L3/H switch hero in a shared turn) and the button→key bridge table. |
| `input/input_rumble.gd` | `InputRumble` (pure): vibration profiles and the decision to vibrate (off, no pad, cooldown, priority). |
| `input/input_glyphs.gd` | `InputGlyphs.label(action, device)`: hint text per device, `""` = no equivalent (hint hidden). |
| `ui/hint_bar.gd` | `HintBar`: placeholder glyphs drawn in code; swaps by polling `InputDevice.active_device`, no signals. |
| `ui/focus_glow.gd`, `ui/focus_ring.gd` | `FocusGlow`: the one selection indicator of the game, a white 3 px border (`make_ring()`, and `attach(btn)` for buttons that take focus). `FocusRing` (what `make_ring()` returns) hides itself while the last input was the mouse; see "Selection ring" below. |
| `battle/ui/hud_nav.gd` | `HudNav` (pure): cursor movement over the visible HUD cells. |
| `battle/battle_camera.gd` | `BattleCamera` (static): edge-scroll velocity, map-limit filter, zoom levels. |

## How a gamepad press reaches the game

1. **Bridge.** A, B, D-pad, LB, RB and Start become synthetic `InputEventKey`s (Enter, Esc, arrows, Q, E, P) marked with the meta `bridged`; the tracker ignores them. Every screen that already reads `KEY_*` works on the gamepad unchanged, and keyboard behavior cannot regress. The real joypad events of bridged buttons (and left-stick motion) are consumed so Godot's own `ui_accept`/focus navigation does not fire twice. The left stick becomes arrows too, with hysteresis and key repeat, except while it drives the free grid cursor.
2. **Actions.** X, Y (also Tab), View and R3 are not bridged: `BattleScene._input` handles `act_end_turn`, `act_examine`, `act_log` and `act_zoom_cycle`.
3. **Polling.** Left/right stick, LT: `InputDevice.cursor_axis()`, `camera_axis()`, `is_los_held()`.

Scene `_input` runs **before** the autoload's (later tree nodes first), so the scene ignores joypad events while `InputDevice.is_gamepad()` is false: the first press only wakes the pad and switches the device.

`Input.parse_input_event` delivers on the next frame and keeps the event's meta, which is why the bridge marks with meta instead of a flag around the call.

## Grid cursor (combat)

`BattleState.cursor_tile` is the single cursor of MOVE_MODE and ATTACK_MODE. Mouse hover, the free stick cursor (`BattleArea.pointer_pos`, never `warp_mouse`: it would emit mouse events and flip the device back) and D-pad/arrows (`step_cursor`, elevation-blind, clamped at the edge) all write it. It may rest on any tile, even off the grid.

- `get_cursor_feedback()` → `{valid, reason}`: used on hover (red diamond + reason label) and on confirm.
- `apply_cursor_selection()` commits the cursor to `move_cursor` / `attack_tile_cursor` / `attack_cursor_idx` only when valid; invalid returns `false` and changes nothing, so no slot, Ki or action is spent.
- Single-target, ally and self targeting confirm only on a tile holding a valid target; area spells and Jump confirm on any valid tile in range. Validity rules (range, LOS, allowed targets) are the old ones.
- A click is `set_cursor_tile` + the same confirm path as Enter/A.
- **Sphere and cylinder areas aim at intersections** (`BattleState.attack_corner_mode`): `cursor_tile` then holds the corner (0..cols, 0..rows, the top-left vertex of square (x, y)). Mouse and stick snap to the nearest corner (`BattleArea._pointer_cell`), arrows and D-pad step corner by corner, the cursor is drawn as a cross, and the preview (`get_area_preview_tiles`) shows the squares the effect will hit. Cube areas and Jump aim at squares.
- **Shared turns:** each hero of a block ends his **own** turn. End Turn and Cancel End Turn are one command (bg3.wiki "Controls": Space; Y/Triangle on a pad): **Space** on the keyboard (in the neutral turn state; Enter keeps "use the HUD item"), the **FIM / VOLTAR** button with the mouse, and **X** on the gamepad (`act_end_turn`; the game's Y is Examine, so the pad keeps X). On a hero who still acts it ends his turn and control passes to the next hero who has not ended; on a hero who already ended (select him first) it cancels the end. Switching among heroes who have not ended: `act_switch_hero` (L3, key H), or a left click on a portrait or on the hero's square; clicking a hero who ended selects him so the same command can cancel (only with no action, aim or confirmation pending). Space does **not** go through an `act_*` action, because in MOVE/ATTACK mode it still confirms the cursor.

Camera: right stick pans (same `MAX_PAN` clamp as mouse drag); the cursor pushed into the screen edge scrolls only while there is map beyond that edge (`BattleCamera.can_pan`); D-pad steps pan the minimum to keep the tile visible; R3 cycles `ZOOM_LEVELS`.

## Action HUD cursor

The HUD grid replaced the old ACTION/HABILIDADES/ITEMS tabs, so the cursor walks what is on screen: every cell with an action (left and right sides) plus the items bar, built by `ActionPanel._nav_entries()` with a visual (row, col). `HudNav.step()` moves it: left/right follow reading order with wrap, up/down go to the neighbouring row in the nearest column. Enter/A runs `nav_selected()`, the very item under the white ring (disabled items can be selected; they stay dimmed and `is_item_available` refuses them). Keys 1-6 pick the cell whose corner number is n. LB/RB (Q/E) cycle the grid **filter** (all, Action, Bonus, each visible spell-slot level, Ki), the HUD's surviving "tab"; the active filter's icon gets the same ring. A mouse click on an item makes it the cursor; hover does not move it (it only opens the details panel). Switching the active hero (shared turn) resets the cursor to the first item. `nav_enabled` turns the ring off while examine, pause or a reaction popup own the input. The Confirmar/Voltar bar uses focus: ←/→ move it and Enter/A triggers exactly the focused button.

The details panel (`ActionTooltipPanel`, the same one the mouse hover opens) follows the ring: `ActionPanel.grid_nav_selected(subject, anchor)` is emitted on every keyboard/gamepad move (disabled items too) and `BattleScene` shows the panel after the usual 0.3 s, next to the selected item (`ActionTooltipPanel.place`: above the item, else below, else beside; always on screen, never over the item). While it is visible a move swaps the content at once. It hides on confirm, on move/aim, examine, pause, reaction and end of turn (`_hud_tooltip_allowed`), and with a gamepad it reappears when the HUD gets the input back. The consumable (Poção) is a `Dictionary` item: the panel shows name, effect and quantity. The mouse path is unchanged (panel at the pointer, `grid_action_hovered`).

Mouse-only buttons (FIM, log, lock, +/-) have `focus_mode = NONE`: with focus they would also fire on Enter/A.

## Selection ring (all screens)

One rule: the white ring (`FocusGlow`) is shown **only with keyboard or gamepad**. `InputDeviceTracker.pointer_active` is true after the last mouse motion/click and false after a key, gamepad button or deliberate stick push. Every ring from `FocusGlow.make_ring()` is a `FocusRing` that sets its own alpha from `FocusGlow.rings_shown()` each frame; the owner still decides *which* item is selected (`visible`). So with the mouse the ring is hidden everywhere (HUD, party select, options, event buttons, reaction popup, result screen), and it comes back on the same item when a key/button is used.

The mouse must therefore leave the owner's cursor on the **last clicked item**, not on the hovered one: party select (`_focus_card`) and the action HUD (`_nav_set`, called on click) do this. The exception is the examine marker on the turn bar (`make_ring(false)`): it is state, opened by right-click too, so it stays visible. Not covered: the main menu, which marks its keyboard focus with the button texture (not a `FocusGlow` ring).

## Examine (Y / Tab)

`BattleScene` state machine `ExamineFocus { NONE, BAR, MENU, PANEL }`: Y/Tab → bar (starting at the active combatant) → Enter opens the "Examinar" context menu → Enter opens the panel → ←/→ steps through `BattleState.examine_step()` (turn order, dead skipped, always sanitized) → Esc/B backs out one level. A white border marks the slot (`TurnOrderBar.set_examine_highlight`) and the combatant's tile (`BattleArea.set_examine_highlight`). Right-click on the bar still opens the menu as before.

## Rumble

`BattleScene` asks `BattleState.hit_rumble_kind(last_attack_info)` (critical dealt/taken by a hero) and drains `BattleState.pending_downed` (hero Downed) in `_refresh_ui`, then calls `InputDevice.rumble(kind)`. `InputRumble.decide` returns nothing when the option is off (`GameSettings.vibration_enabled`), no pad is active, or inside the 250 ms cooldown unless the new event has higher priority (Downed > crit taken > crit dealt).

## Adding a hint or a command

- Hint: add the action to both tables in `InputGlyphs` (use `""` where a device has no equivalent), then pass `[[&"action", "Label"], …]` to a `HintBar`.
- Battle-only command: register it in `InputBindings.register()` and handle it in `BattleScene._handle_action_event` (keep the same blocks as the keyboard: pause, reaction, animation).
- Screen navigation needs nothing: read `KEY_ENTER`/`KEY_ESCAPE`/arrows as usual.
