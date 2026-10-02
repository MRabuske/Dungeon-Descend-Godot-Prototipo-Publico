# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Dungeon Descend Prototype** — tactical turn-based combat game in Godot 4.6 (GDScript), isometric perspective, 1280×720, D3D12 on Windows.

## Commands

**Run the game** (Godot Editor):
- Open project in Godot 4.6+, press **F5** or click **Play**

**Run via CLI:**
```
godot --path "C:/Users/matca/Desktop/VScode/Dungeon-Descend-Prototype"
```

**Run tests (headless):**
```
godot --headless --script tests/run_tests.gd
```
`tests/run_tests.gd` extends `SceneTree`, so it runs without a display. Exits 0 on all-pass, 1 on any failure.

## Architecture Overview

### Scene Flow

```
ui/main_menu.tscn
  → ui/party_select.tscn      (hero selection — calls BattleState.setup_party())
    → ui/dungeon_map.tscn      (dungeon navigation — reads DungeonState.current_run)
      → battle/battle_scene.tscn   (combat)
      → ui/event_scene.tscn        (EVENT / MYSTERY rooms)
```

All scene transitions go through the `SceneTransition` autoload (`ui/scene_transition.gd`) via `SceneTransition.fade_to("res://...")`.

### Autoloads (project.godot)

| Name | File | Purpose |
|------|------|---------|
| `SceneTransition` | `ui/scene_transition.gd` | Fade-to transitions |
| `GameTheme` | `ui/game_theme.gd` | Global UI Theme resource |
| `VfxManager` | `vfx/core/vfx_manager.gd` | Pooled VFX spawner — `VfxManager.spawn(type, pos, dir)` |
| `HitStop` | `vfx/components/hit_stop.gd` | Frame-freeze hit-stop effect |
| `SfxManager` | `vfx/components/sfx_manager.gd` | Sound playback |

### Global State (static vars, not autoloads)

`BattleState` uses static class-level vars that persist across scenes:
- `BattleState.PLAYERS` — Array of combat Dictionaries for the party (hp, mp, stats…)
- `BattleState.TURN_QUEUE` — ordered Array of all combatants (players + enemies)
- `BattleState.ALL_HERO_DATA` — Dictionary of `HeroData` resources keyed by hero name
- `BattleState.ALL_ENEMIES` — Dictionary of `EnemyData` resources keyed by enemy type key

`DungeonState.current_run` is a static var holding the active `DungeonState` instance. It is `null` when no run is active (e.g., quick-battle from main menu without going through the dungeon).

Call `BattleState.setup_party(hero_names)` before entering a run to populate `PLAYERS` and `TURN_QUEUE`. Call `BattleState.setup_enemies_for_room(room_type)` before each battle to swap in the correct enemies. Call `BattleState.reset_players()` to restore party HP/MP to base values.

### Battle System

`BattleScene` (`battle/battle_scene.gd`, extends `Control`):
- Orchestrates the entire battle — builds the full node tree in code from `_ready()` (no layout in .tscn)
- Holds `_animating: bool` — blocks all input while move/attack/death animations play
- Connects signals from `ActionPanel`, `BattleArea`, `PauseMenu`, `BattleResultScreen`

`BattleState` (`battle/battle_state.gd`, extends `RefCounted`):
- All combat logic; zero rendering. Owns the state machine (`State` enum: `PLAYER_TURN`, `ENEMY_TURN`, `MOVE_MODE`, `ATTACK_MODE`)
- `advance_turn()` handles poison ticks, stun skips, buff decrements, then loads the next combatant's actions
- `_apply_attack()` rolls damage with proficiency + attribute modifier + status bonuses (furtivo, fury, crit) plus per-action smite dice (`smite_dice_count`/`smite_dice_sides` on `ActionData`)
- Enemy AI lives in `_pick_enemy_action_idx()`, `get_enemy_move_path()`, `apply_enemy_attack()`

`BattleArea` (`battle/battle_area.gd`):
- Isometric rendering of the tile grid and combatant sprites
- Delegates to sub-components: `CombatantLayer` (sprites, HP bars), `FloaterManager` (damage numbers), `CameraShake`, `ScreenFlash`

`MapGenerator` (`battle/map_generator.gd`):
- Procedural map via border erosion + flood-fill connectivity check; retries up to 100× then falls back to flat map
- Fixed-seed generation is deterministic (`generate(seed_val)`)

### Battle UI Sub-system (`battle/ui/`)

All UI nodes are built entirely in code — no `.tscn` layout files in this folder.

**HUD layout** (constructed in `BattleScene._build_hud()`):
```
VBoxContainer (full screen)
├─ TurnOrderBar          (top bar)
├─ BattleArea            (expands to fill height)
└─ HBoxContainer  HUD_HEIGHT = 200
   ├─ StatusPanel        STATUS_WIDTH = 280
   ├─ ActionPanel        SIZE_EXPAND_FILL
   └─ End Turn Button    80×80, circular StyleBoxFlat, green

Floating (anchored independently, outside the HBox):
   CombatLogPanel        220×300, bottom-right above HUD, toggled by 💬 button
```

**Component signal contracts:**

| Class | Signals emitted | Refresh call |
|---|---|---|
| `ActionPanel` | `grid_action_clicked(action)`, `grid_action_hovered(action)`, `end_turn_pressed`, `cancel_action`, `confirm_action` | `refresh()` inside `BattleScene._refresh_ui()` |
| `TurnOrderBar` | `slot_right_clicked(slot_index, global_pos)` | `refresh(queue, active_index)` |
| `StatusPanel` | — | `refresh(active_index)` |
| `CombatLogPanel` | — | `refresh()` reads `BattleState.combat_log` |
| `ExaminePanel` | — | `show_for(state, idx)` |
| `ContextMenu` | `examine_requested(slot_index)` | spawned at cursor, calls `queue_free()` on dismiss |
| `BattleResultScreen` | `continue_requested`, `restart_requested` | `show_result(won, stats)` |
| `TurnTransitionLayer` | — | `show_turn(title, subtitle, on_done)` |
| `PauseMenu` | `resume_requested`, `menu_requested` | `show_menu()` / `hide_menu()` |

Every panel receives `setup(state)` during `BattleScene._initialize_state()`, then is refreshed on each state change via `_refresh_ui()`.

#### ActionPanel internals

The grid is 14 columns (`GRID_COLS = 14`) split by a draggable red divider:
- **Left side** (default 7 cols): normal actions — `bonus_action == false`, `spell_slot_level == 0`, `ki_cost == 0`, not `END_TURN`
- **Right side** (default 7 cols): spells, skills, END_TURN — `bonus_action == true`, `spell_slot_level > 0`, `ki_cost > 0`, or `END_TURN`

Within-side drag reorders slots (stored in `_left_order` / `_right_order` label arrays, applied each `refresh()`). Cross-side drag records the override in `_side_overrides: Dictionary` (action label → `"left"/"right"`), which persists across refreshes but resets when `ActionPanel` is recreated. The lock button (`🔒/🔓`) sets `_grid_locked` to prevent accidental reorders.

**State-driven visibility** (`_update_visibility()` driven by `BattleState.current_state`):
- `PLAYER_TURN` → grid, resource bar, and items bar are visible
- `MOVE_MODE` / `ATTACK_MODE` / `ENEMY_TURN` → grid hidden; action bar overlay replaces it with a status message and Voltar button

`_filter_mode` (0 = none, 1 = Action only, 2 = Bonus only) is toggled by clicking the Action dot or Bonus arrow resource indicators above the grid, and resets to 0 whenever the grid is hidden.

#### Right-click examine flow

`TurnOrderBar.slot_right_clicked` → `BattleScene` spawns `ContextMenu` at cursor → `ContextMenu.examine_requested` → `BattleScene` calls `ExaminePanel.show_for(state, idx)`. `ExaminePanel` shows stats, statuses, resistances, and passives; arrow buttons rotate the sprite preview across 4 isometric angles.

#### Combat log protocol

`BattleState._log(text, type)` prepends to `combat_log: Array` (capped at 60). `CombatLogPanel` renders the latest 25 entries. Valid type keys and colors:

| type | color |
|------|-------|
| `"dmg"` | red |
| `"heal"` | green |
| `"miss"` | tan |
| `"status"` | purple |
| `"crit"` | gold |
| `"system"` | gray (default) |

### Actions System

`ActionData` (`actions/action_data.gd`, extends `Resource`) is the base for all player actions:
- `action_type`: `ATTACK | MOVE | END_TURN`
- `damage_attribute`: `NONE | STR | DEX | INT | WIS` — determines which stat modifier applies
- `spell_slot_level` (0 = no slot/cantrip; 1-6 = D&D 5e spell slot level consumed), `ki_cost` (Monk-only), `pp` / `max_pp`, `aoe_radius`, `attack_range`, `targets_allies`, `bonus_action`

Concrete action classes live in `actions/attacks/`, `actions/skills/`, `actions/spells/`, `actions/endturn/`. Each is a plain GDScript class that `extends ActionData` and sets its fields in `_init()`.

`HeroData` (`heroes/hero_data.gd`, extends `Resource`) defines hero stats and carries:
- `actions: Array[ActionData]` — shown in the ACTION tab
- `skills: Array[ActionData]` — shown in the HABILIDADES tab
- `caster_type` (`NONE`/`HALF`/`FULL`) + `level` drive `get_spell_slots_max()` — a D&D 5e lookup (levels 1-12) returning a 6-element array `[1st…6th]`. `ki_per_level` × `level` = `ki_max()` (Monk). No MP system exists; spells consume spell slots (restored on rest), Monk skills consume Ki.

Each hero has a concrete `HeroData` subclass in `heroes/` (e.g., `GuerreiroData`, `MagoData`). These are instantiated once in `BattleState.ALL_HERO_DATA`. `BattleState._load_hero_actions(player_name)` duplicates the actions/skills from `ALL_HERO_DATA` into `tab_action` / `tab_habilidades` at the start of each hero's turn.

### Dungeon System

`DungeonState` (`dungeon/dungeon_state.gd`, extends `RefCounted`):
- Generates a floor graph (`FLOOR_COUNT = 6`): floor 0 is always BATTLE, floor 5 is always BOSS; middle floors are weighted random (BATTLE, ELITE, EVENT, MYSTERY)
- Persists to `user://dungeon_save.json` via `save()` / `load_save()` / `delete_save()`
- `pending_buffs` accumulates stat buffs from events; `BattleState.setup()` consumes them

`EventData` (`dungeon/event_data.gd`) and `MysteryRegistry` (`dungeon/mystery_registry.gd`) define the `EventData.REGISTRY` of named events and deterministic mystery resolution.

### VFX System

`VfxManager` uses object pooling. To spawn an effect:
```gdscript
VfxManager.spawn(VFXEvent.Type.SLASH_LIGHT, global_position, rotation)
```

Registered effect types: `SLASH_LIGHT`, `IMPACT_LIGHT`, `IMPACT_CRIT`. New effect types require a `.tscn` scene and an entry in `VfxManager.EFFECT_SCENES`.

### Terrain

`TerrainTile` (`tiles/terrain_tile.gd`) holds `ground` (GroundType: NORMAL, MUD, ELEVATED, STONE, GRASS) and `object` (ObjectType: NONE, STATUE, OBSTACLE, COVER) and `effect` (EffectType: NONE, TRAP_INACTIVE, TRAP_ACTIVE).

Movement cost: MUD costs 2, all others cost 1. ELEVATED tiles grant +1 attack range for ranged actions. Additionally, elevation difference applies a flat modifier to the attack roll for ranged actions: attacker elevated, target not → +2; target elevated, attacker not → -2; same level or melee → 0. This is a flat bonus (not Advantage), matching BG3 behavior. COVER tiles have a 30% chance to cause a miss.

### Testing (`tests/run_tests.gd`)

Single 1180-line file extending `SceneTree`. All tests live in `_run_all()`; no separate test files or test classes exist.

**Assertion helpers:** `_eq(label, actual, expected)` and `_true(label, value)`.

**Shared fixture:** `_battlefield()` returns a `BattleState` with combatants at fixed positions (Guerreiro at (2,3), Goblin Scout at (9,1), etc.). Movement and enemy AI tests depend on these coordinates — do not change them without updating dependent cases.

**Coverage by subsystem:** BattleState initial state → Movement (speed, blocking, terrain cost) → Enemy AI (pathfinding, action selection) → MapGenerator (connectivity, determinism) → Terrain effects (traps, mud, cover) → All 8 hero action sequences → Status effects (poison, stun, buff stacking) → DungeonState floor graph + save/load → EventData/MysteryRegistry → UI smoke tests (TurnOrderBar, ExaminePanel, ContextMenu).

To add a test, append to `_run_all()` and use the existing assertion helpers. Run with `godot --headless --script tests/run_tests.gd`.

## Key Conventions

- `BattleScene` is the only file that directly mutates `BattleState` static vars during a battle; `BattleState` methods return data or mutate internal state — they do not call rendering code.
- Combatants are identified by their index in `TURN_QUEUE`. Player data is looked up separately in `PLAYERS` by name. Always use `_player_index_by_name()` / `get_active_player_index()` rather than assuming index alignment.
- `combatant_statuses` is an Array parallel to `TURN_QUEUE`, where each element is a Dictionary of active status effects (keys: `"poison"`, `"stun"`, `"raging"`, `"fury"`, `"furtivo"`).
- `last_attack_info` Dictionary is set by `_apply_attack()` / `apply_enemy_attack()` and read by `BattleScene` immediately after to trigger floaters and hit-flash — it is ephemeral per-attack.
- Save data path: `user://dungeon_save.json`. Settings path: `user://settings.cfg`. `GameSettings` (`game_settings.gd`) is the static-only class that owns settings — call `GameSettings.load_settings()`, `save_settings(dict)`, `apply_settings(dict)` (sets window mode/vsync/size). Do not write `settings.cfg` directly.

## Team Workflow & Prompt Convention

This project follows a team model:
- **Developer (Claude Code + user):** writes and edits code.
- **Consultant (Cowork assistant):** analyzes code, writes documentation, and creates prompts for Claude Code.

When a prompt arrives from the Cowork assistant it will follow this structure:
1. **Context** — game reference (BG3 90%, D&D 5e 10%), session scope
2. **Expected deliverable** — what to produce (plan only, or plan + implementation)
3. **Problems** — each item describes *what the current behavior is* and *what the correct behavior should be* (BG3/D&D reference), without dictating specific code changes
4. **Constraints** — what must not break, what already works, known dependencies

**Your job as Claude Code:** read the codebase, locate the relevant code, plan (and implement if the session scope says so). The consultant describes *what*, you decide *how*.

**Session scope is always declared explicitly in the prompt.** If it says "plan only", produce a structured plan and do not modify any files.

**Superpowers plugin is installed.** Prompts from the consultant will include a Superpowers directive at the top declaring which skill to use as the target (e.g., `writing-plans`, `systematic-debugging`, `subagent-driven-development`). The consultant provides a detailed spec, but you should still use your own judgment on whether the spec is complete enough to proceed directly to planning, or whether a clarifying question is warranted first.
