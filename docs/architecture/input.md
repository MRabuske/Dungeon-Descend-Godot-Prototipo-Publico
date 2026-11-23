# Input and gamepad support

Companion to `CLAUDE.md`. One player: any connected gamepad commands the whole party. Local co-op and button remapping are out of scope, but nothing here locks a gamepad to the party: the tracker takes a `device_id` on every event, so binding one pad per hero later does not require redoing it.

## Pieces

| File | Role |
|---|---|
| `input/input_device_tracker.gd` | `InputDeviceTracker` (pure): active device ("last used wins"), stick dead zone, 4-way stick direction. |
| `input/input_device.gd` | `InputDevice` autoload: classifies every event, hides/shows the mouse cursor, bridges the gamepad to keys, exposes the left stick, the zoom axis, enemy view and `rumble()`. |
| `input/input_bindings.gd` | `InputBindings`: the `act_*` actions (see "Control scheme" below) and the button→key bridge table. |
| `input/input_rumble.gd` | `InputRumble` (pure): vibration profiles and the decision to vibrate (off, no pad, cooldown, priority). |
| `input/input_glyphs.gd` | `InputGlyphs.label(action, device)`: hint text per device, `""` = no equivalent (hint hidden). |
| `ui/hint_bar.gd` | `HintBar`: placeholder glyphs drawn in code; swaps by polling `InputDevice.active_device`, no signals. |
| `ui/focus_glow.gd`, `ui/focus_ring.gd` | `FocusGlow`: the one selection indicator of the game, a white 3 px border (`make_ring()`, and `attach(btn)` for buttons that take focus). `FocusRing` (what `make_ring()` returns) hides itself while the last input was the mouse; see "Selection ring" below. |
| `battle/ui/hud_nav.gd` | `HudNav` (pure): cursor movement over the visible HUD cells. |
| `battle/battle_camera.gd` | `BattleCamera` (static): edge-scroll velocity, map-limit filter, zoom levels. |

## How a gamepad press reaches the game

1. **Bridge.** A, B, D-pad, LB, RB and Start become synthetic `InputEventKey`s (Enter, Esc, arrows, Q, E, P) marked with the meta `bridged`; the tracker ignores them. Every screen that already reads `KEY_*` works on the gamepad unchanged, and keyboard behavior cannot regress. The real joypad events of bridged buttons (and left-stick motion) are consumed so Godot's own `ui_accept`/focus navigation does not fire twice. The left stick becomes arrows too, with hysteresis and key repeat, except while it drives the free grid cursor.
2. **Actions.** X, Y (also Tab), View, R3 and L3 are not bridged: `BattleScene._input` handles `act_end_turn` (Y), `act_examine` (X, Tab), `act_log`, `act_zoom_overview` (R3) and `act_switch_hero`.
3. **Polling.** Left stick, right stick Y, triggers, Page Up/Down: `InputDevice.cursor_axis()`, `zoom_axis()`, `is_los_held()` (RT/Shift) and `Input.is_action_just_pressed(act_center_camera)` (LT/Home), read per frame by `BattleArea` and `BattleScene._process`.

Scene `_input` runs **before** the autoload's (later tree nodes first), so the scene ignores joypad events while `InputDevice.is_gamepad()` is false: the first press only wakes the pad and switches the device.

`Input.parse_input_event` delivers on the next frame and keeps the event's meta, which is why the bridge marks with meta instead of a flag around the call.

## Grid cursor (combat)

`BattleState.cursor_tile` is the single cursor of MOVE_MODE and ATTACK_MODE. Mouse hover, the free stick cursor (`BattleArea.pointer_pos`, never `warp_mouse`: it would emit mouse events and flip the device back) and D-pad/arrows (`step_cursor`, elevation-blind, clamped at the edge) all write it. It may rest on any tile, even off the grid.

- `get_cursor_feedback()` → `{valid, reason}`: used on hover (red diamond + reason label) and on confirm.
- `apply_cursor_selection()` commits the cursor to `move_cursor` / `attack_tile_cursor` / `attack_cursor_idx` only when valid; invalid returns `false` and changes nothing, so no slot, Ki or action is spent.
- Single-target, ally and self targeting confirm only on a tile holding a valid target; area spells and Jump confirm on any valid tile in range. Validity rules (range, LOS, allowed targets) are the old ones.
- A click is `set_cursor_tile` + the same confirm path as Enter/A.
- **Sphere and cylinder areas aim at intersections** (`BattleState.attack_corner_mode`): `cursor_tile` then holds the corner (0..cols, 0..rows, the top-left vertex of square (x, y)). Mouse and stick snap to the nearest corner (`BattleArea._pointer_cell`), arrows and D-pad step corner by corner, the cursor is drawn as a cross, and the preview (`get_area_preview_tiles`) shows the squares the effect will hit. Cube areas and Jump aim at squares.
- **Shared turns:** each hero of a block ends his **own** turn. End Turn and Cancel End Turn are one command (bg3.wiki "Controls": Space; Y/Triangle on a pad): **Space** on the keyboard (in the neutral turn state; Enter keeps "use the HUD item"), the **FIM / VOLTAR** button with the mouse, and **Y** on the gamepad (`act_end_turn`). On a hero who still acts it ends his turn and control passes to the next hero who has not ended; on a hero who already ended (select him first) it cancels the end. Switching among heroes who have not ended: `act_switch_hero` (L3, key H), or a left click on a portrait or on the hero's square; clicking a hero who ended selects him so the same command can cancel (only with no action, aim or confirmation pending). Space does **not** go through an `act_*` action, because in MOVE/ATTACK mode it still confirms the cursor.

## Control scheme (BG3, bg3.wiki "Controls")

| Command | Gamepad | Keyboard | Mouse |
|---|---|---|---|
| Confirm / cancel | A / B | Enter / Esc | click / right-click |
| Navigate the action bar, filter, Confirmar/Voltar and the square cursor | **D-pad** | **arrows** (W/A/S/D no longer navigate in combat) | hover |
| Free world cursor (all of combat, neutral turn included; looks only on a neutral turn) | **left stick** | – | pointer |
| Move the camera | left stick to the screen edge | **W / A / S / D** (hold; combine for diagonals) | drag with the left button |
| Cancel mode (move / aim) | B | Esc | **right click on the map** |
| HUD filter | LB / RB | Q / E | – |
| End turn / cancel end turn | **Y** | Space | FIM / VOLTAR button |
| Examine (context menu, turn bar) | **X** | Tab | right-click on the turn bar |
| Switch hero (shared turn) | L3 | H | click portrait or hero |
| Zoom (continuous) | **right stick ↑/↓** (←/→ does nothing) | **Page Up / Page Down** | **wheel** |
| Center camera on the active character | **LT** | **Home** | drag to pan |
| Overview (whole map; again = back) | **R3** | – | – |
| Enemy line-of-sight view (hold) | **RT** | Shift | – |
| Combat log / pause | View / Start | – / P | log button |

**Stick and WASD rules.** In combat the left stick is the free world cursor in **every** state (neutral, move, aim, enemy turn, animations); it is bridged to arrows only where a modal panel needs navigation (pause, reaction, examine, result) and outside combat (`BattleScene._stick_drives_cursor` → `InputDevice.stick_drives_cursor`). On a neutral turn the cursor only looks (tile outline + the combatant under it in the info panel, `BattleScene._show_neutral_hover`, the same for the mouse); in move and aim it picks the square or target. W/A/S/D move only the camera in combat (`BattleArea._wasd_direction`, polled, `KEY_PAN_SPEED`, diagonals normalised, same pan limits, off while a text field has focus or Ctrl/Alt/Meta is held) and are no longer arrows in `BattleScene`, the pause menu or the reaction popup; outside combat (menus, options, party select, dungeon map) they navigate as before. Moving the camera by hand never touches the dynamic-camera option: it acts again on the next turn change. The cursor and the selection are not changed by WASD.


## Camera (`BattleCamera` pure math + `BattleArea` state)

- **Zoom** is continuous (`BattleCamera.zoom_step`, multiplicative, rate `ZOOM_RATE`), about the screen center (the pan is rescaled so the point at the center stays put). The **minimum zoom is whatever fits the whole map** on the actual area (`min_zoom` = `min(fit_zoom, 1.0)`, recomputed on every use, so any map size and any window size work); the maximum is `MAX_ZOOM` (2.5). The old fixed `ZOOM_LEVELS` and the stick pan are gone.
- **Pan limits** come from the map rectangle (`pan_limits`, `PAN_SLACK` 160 px of empty space past the map edge), not from a fixed number: at any zoom every corner tile can be brought on screen, and a map smaller than the screen stays centered. They apply to mouse drag, edge scroll and centering.
- **Overview (R3)** (`BattleArea.toggle_overview`) zooms out to the minimum and centers the map; a second press restores the previous zoom and pan. Any manual zoom or pan leaves the overview.
- **Center (LT / Home)** (`BattleScene.center_camera_on_active`) scrolls smoothly (`FOLLOW_RATE`) to the active combatant.
- **Dynamic combat camera (BG3):** `BattleScene._follow_active_camera` (called from `_refresh_ui`) watches `active_index`. On entering the battle the camera frames the first combatant instantly (always). Afterwards, when the active combatant changes (enemy turn, shared-turn hero switch) it scrolls to him **only if he is off screen** (`BattleCamera.tile_visible`). Controlled by the Options toggle "Câmera dinâmica" (`GameSettings.dynamic_camera_enabled`, saved as `gameplay/dynamic_camera`, default on).
- The cursor pushed into the screen edge still scrolls only while there is map beyond that edge (`BattleCamera.can_pan`); D-pad steps pan the minimum to keep the tile visible.
- `BattleArea.camera_input_enabled` is switched off by the scene during pause, reactions and the result screen.
- Hints: the combat `HintBar` has a second row with Mover câmera (L-stick / WASD), Zoom, Centralizar and Visão geral; `InputGlyphs` hides the ones a device has no key for (Visão geral on the keyboard).

## Action HUD cursor

The HUD grid replaced the old ACTION/HABILIDADES/ITEMS tabs, so the cursor walks what is on screen: every cell with an action (left and right sides) plus the items bar, built by `ActionPanel._nav_entries()` with a visual (row, col). `HudNav.step()` moves it: left/right follow reading order with wrap, up/down go to the neighbouring row in the nearest column. Enter/A runs `nav_selected()`, the very item under the white ring (disabled items can be selected; they stay dimmed and `is_item_available` refuses them). Keys 1-6 pick the cell whose corner number is n. LB/RB (Q/E) cycle the grid **filter** (all, Action, Bonus, each visible spell-slot level, Ki), the HUD's surviving "tab"; the active filter's icon gets the same ring. A mouse click on an item makes it the cursor; hover does not move it (it only opens the details panel). Switching the active hero (shared turn) resets the cursor to the first item. `nav_enabled` turns the ring off while examine, pause or a reaction popup own the input. The Confirmar/Voltar bar uses focus: ←/→ move it and Enter/A triggers exactly the focused button.

The details panel (`ActionTooltipPanel`, the same one the mouse hover opens) follows the ring: `ActionPanel.grid_nav_selected(subject, anchor)` is emitted on every keyboard/gamepad move (disabled items too) and `BattleScene` shows the panel after the usual 0.3 s, next to the selected item (`ActionTooltipPanel.place`: above the item, else below, else beside; always on screen, never over the item). While it is visible a move swaps the content at once. It hides on confirm, on move/aim, examine, pause, reaction and end of turn (`_hud_tooltip_allowed`), and with a gamepad it reappears when the HUD gets the input back. The consumable (Poção) is a `Dictionary` item: the panel shows name, effect and quantity. The mouse path is unchanged (panel at the pointer, `grid_action_hovered`).

Mouse-only buttons (FIM, log, lock, +/-) have `focus_mode = NONE`: with focus they would also fire on Enter/A.

## Selection ring (all screens)

One rule: the white ring (`FocusGlow`) is shown **only with keyboard or gamepad**. `InputDeviceTracker.pointer_active` is true after the last mouse motion/click and false after a key, gamepad button or deliberate stick push. Every ring from `FocusGlow.make_ring()` is a `FocusRing` that sets its own alpha from `FocusGlow.rings_shown()` each frame; the owner still decides *which* item is selected (`visible`). So with the mouse the ring is hidden everywhere (HUD, party select, options, event buttons, reaction popup, result screen), and it comes back on the same item when a key/button is used.

The mouse must therefore leave the owner's cursor on the **last clicked item**, not on the hovered one: party select (`_focus_card`) and the action HUD (`_nav_set`, called on click) do this. The exception is the examine marker on the turn bar (`make_ring(false)`): it is state, opened by right-click too, so it stays visible. Not covered: the main menu, which marks its keyboard focus with the button texture (not a `FocusGlow` ring).

## Examine (X / Tab)

`BattleScene` state machine `ExamineFocus { NONE, BAR, MENU, PANEL }`: X/Tab → bar (starting at the active combatant) → Enter opens the "Examinar" context menu → Enter opens the panel → ←/→ steps through `BattleState.examine_step()` (turn order, dead skipped, always sanitized) → Esc/B backs out one level. A white border marks the slot (`TurnOrderBar.set_examine_highlight`) and the combatant's tile (`BattleArea.set_examine_highlight`). Right-click on the bar still opens the menu as before.

## Rumble

`BattleScene` asks `BattleState.hit_rumble_kind(last_attack_info)` (critical dealt/taken by a hero) and drains `BattleState.pending_downed` (hero Downed) in `_refresh_ui`, then calls `InputDevice.rumble(kind)`. `InputRumble.decide` returns nothing when the option is off (`GameSettings.vibration_enabled`), no pad is active, or inside the 250 ms cooldown unless the new event has higher priority (Downed > crit taken > crit dealt).

## Adding a hint or a command

- Hint: add the action to both tables in `InputGlyphs` (use `""` where a device has no equivalent), then pass `[[&"action", "Label"], …]` to a `HintBar`.
- Battle-only command: register it in `InputBindings.register()` and handle it in `BattleScene._handle_action_event` (keep the same blocks as the keyboard: pause, reaction, animation).
- Screen navigation needs nothing: read `KEY_ENTER`/`KEY_ESCAPE`/arrows as usual.
## BG3 audit (bg3.wiki "Controls", which redirects to the "Options" page, Keybinds section; read 2026-11-23)

Status: **same** = already equal, **fixed now** = changed in this round, **no equivalent** = the feature does not exist in this game, **decision** = diverges and needs the owner's decision (not applied).

| BG3 command | BG3 input (keyboard / controller) | Input in this game | Status |
|---|---|---|---|
| Camera Forward / Backward / Left / Right | W A S D, arrows / left stick | **WASD = camera only**; left stick = free cursor, edge scrolls the camera. **Arrows keep their HUD and grid-cursor job.** | WASD **fixed now**. Arrows = **decision** (BG3 arrows also pan the camera; kept by the owner's order) |
| Camera Zoom In / Out | Page Up / Page Down, mouse wheel / right stick up / down | Page Up / Page Down, wheel / right stick up / down | same |
| Center Camera On Character | Home / LT | Home / LT | same |
| Toggle Tactical Camera | O / hold right stick down (exit: up) | R3 = overview (own decision) | **decision**: BG3 has the tactical camera on the right stick, here it is a one-press toggle on R3 |
| Camera Rotate Left / Right / Rotate | Q E (Delete, End), middle mouse / right stick left-right | none | no equivalent (2D isometric). Q/E are the HUD filter here (LB/RB) |
| Edge Panning (option, default off) | cursor at the window edge, option | only the gamepad free cursor scrolls at the edge; the mouse does not | **decision**: needs a new option in Options |
| Dynamic Combat Camera (option, default on) | option | option "Câmera dinâmica", default on | same |
| Follow Flying Creatures (option) | option | none | no equivalent |
| End Turn / Cancel End Turn | Space / Y | Space / Y | same |
| Context Menu | Ctrl + left click, right click / ? | right click on a turn-bar portrait, X on the pad opens the same menu | **decision**: right click / Ctrl+click on a tile or creature opens no menu here |
| Cancel Action | Esc, right mouse / ? | Esc, B, **right click on the map** (MOVE/ATTACK) | **fixed now** |
| Examine / Pin Tooltip | T / ? | Tab, X | **decision**: BG3 Tab is "Party View" and T is examine; Tab is the existing examine key, kept |
| In-Game Menu | Esc / ? | P, Start; Esc on an idle turn also opens it | same (Esc at idle) |
| Select Next / Previous Character | ] / [ | **] / [** (also H, L3 for next) | **fixed now** |
| Select Character at Position 1-4 | F1-F4 | **F1-F4** (n-th party hero) | **fixed now** |
| Select Slot 1-10 / 11 / 12 | 1-0 (Numpad), - , = | 1-6 pick the HUD cell with that corner number; 7-12 and the numpad do not exist | partly the same. **decision**: 7-12 depend on how many cells the redrawn bar has |
| Highlight Characters | backtick / press right stick | none (R3 is overview here) | **decision**: R3 cannot be both; RT/Shift is the enemy-vision overlay |
| Show Item Labels / Show Sneak Cones | Left Alt, Left Shift / press right stick | none (Shift = enemy line-of-sight overlay) | no equivalent / **decision** for Shift |
| Interact | left click / A | left click, A | same |
| Jump, Shove, Throw, Hide, Toggle Group Hide, Weapon Set, Dual Wielding, Sheathe, Climbing | Z, V, X, C, Shift+C, F, R, U, Left Shift / (blank) | HUD cells only | **decision**: hotkeys would need a binding layer on the action bar that will be redrawn |
| Prepare Main Attack | Left Ctrl / (blank) | HUD cell | **decision** (same reason) |
| Enter / Leave Turn-Based Mode, Flee From Combat | Shift + Space | Flee is an HUD action; no real-time mode | no equivalent |
| Short Rest, Toggle Group Mode, Party View, Inventory, Spellbook, Journal, Map, Character sheet... | Y, G, Tab, I, K, J, M, N... | none in combat | no equivalent (screens that do not exist in combat) |
| Quicksave / Quickload | F5 / F8 | none | no equivalent |
| Ping | Alt + right click / RT+LT+A | none | no equivalent |
| Show / Hide UI | F10 | none | **decision** (new feature) |
| Skip (cutscene) | Space, right click | n/a | no equivalent |

Not on the wiki page, taken from the owner's brief: X = context menu / Examine, left stick = free cursor, RT held = enemy vision, R3 = overview. The page lists no free-cursor behaviour, no overview and no log binding.

**Radial menu (LB/RB = Character Actions, RT = shortcut menu): not implemented**, as ordered. Here LB/RB switch the HUD filter and RT is the enemy-vision overlay; both will be revisited when the action bar is redrawn.
