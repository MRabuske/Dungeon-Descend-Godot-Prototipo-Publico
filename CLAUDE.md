# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Dungeon Descend Prototype**: a 2D turn-based tactical combat game with an isometric grid and dungeon runs. Combat follows **Baldur's Gate 3** faithfully; characters, classes, spells and progression follow **D&D 5e (2024 revision)**; the grid follows tabletop D&D. BG3 and D&D are not identical, so never assume a rule from one for the other. Read `.claude/rules/game-rules.md` (the single source of truth) before any rules work.

- **Engine:** Godot 4.7.2 (`project.godot` features `4.7`), Forward Plus renderer, D3D12 on Windows.
- **Language:** GDScript only, with statically typed code (`: int`, `-> void`, `:=`). No C#, no addons.
- **Display:** 1280×720, nearest-neighbor texture filter (pixel art), pixel font `assets/fonts/PressStart2P-Regular.ttf`.
- Identifiers, comments and UI text are mostly in **Portuguese** (`acao_*`, `atq_*`, `Guerreiro`, `HABILIDADES`).

## Commands

`$GODOT` is the editor executable (set in the gitignored `.claude/settings.local.json`).

```bash
"$GODOT" --path .                                              # run the game (main scene: ui/main_menu.tscn)
"$GODOT" --headless --script tests/run_tests.gd 2>&1 | grep -E "FAIL|Results|SCRIPT ERROR"   # full suite, a few seconds
"$GODOT" --headless --check-only --script res://path/file.gd   # quick parse check of one script, <1 s
"$GODOT" --headless --path . --script .claude/skills/godot-gdscript/assets/check_scripts_compile.gd   # whole-project parse check (read-only)
"$GODOT" --headless --path . --import                          # after adding, removing or renaming a `class_name`, so the global class cache matches the files (a stale cache hides a missing class_name from the parse check and the suite until the editor reopens; `_test_class_registry` compares them)
```

Verified on 4.7.2: the suite reports `Results: 2663 passed, 0 failed` with no `SCRIPT ERROR`. The exit code only reflects `FAIL`: a runtime error aborts the test function it happens in and later assertions silently never run, so **any `SCRIPT ERROR` line is a failure**. Run the quick check after each edit and the full suite before saying a change works. `--check-only` on one file reports "Identifier not found" for any script that names an autoload (`SceneTransition`, `InputDevice`…) because autoloads are not registered in that mode; use the whole-project check for those.

## Layout

| Folder | Contents |
|---|---|
| `battle/` | `BattleScene` (orchestrator), `BattleState` (rules), `BattleArea` (isometric rendering), `AreaShape` (D&D 2024 area shapes, pure), `MapGenerator`, `SurfaceType`, `StatusDefinitions` |
| `battle/ui/` | HUD panels, all built in code |
| `actions/` | `ActionData` base + `attacks/`, `skills/`, `spells/`, `endturn/`, `tactical/`, `reactions/` |
| `heroes/`, `enemies/`, `items/` | `HeroData` (8 heroes), `EnemyData` (7 enemies), `WeaponData` subclasses |
| `dungeon/` | `DungeonState` (run/floor graph, save), `EventData`, `MysteryRegistry` |
| `ui/` | Menus, party select, dungeon map (`ui/map/`), event scene, autoload scripts |
| `tiles/` | `TerrainTile`, terrain object layer |
| `vfx/` | `core/` (VfxManager, VFXEvent), `components/` (shake, floaters, hit stop, SFX…), `effects/` (.tscn), `shaders/` |
| `input/` | Gamepad support: `InputDevice` autoload plus pure logic (`InputDeviceTracker`, `InputRumble`, `InputGlyphs`, `InputBindings`). See [docs/architecture/input.md](docs/architecture/input.md) |
| `tests/run_tests.gd` | The only test file |
| `docs/` | Design specs, plans, vision, architecture reference (see below) |

## Scenes and flow

The five `.tscn` scenes each hold **a single root node with a script**; the whole node tree is built in code from `_ready()`. The only content-heavy scenes are the VFX effects in `vfx/effects/`.

```text
ui/main_menu.tscn ── new run ──> ui/party_select.tscn ──> ui/dungeon_map.tscn ⇄ battle/battle_scene.tscn
        │                         (or straight to battle)          ⇅
        └── continue (load save) ──> dungeon_map / battle      ui/event_scene.tscn (EVENT/MYSTERY; may start a battle)
```

Every transition goes through `SceneTransition.fade_to("res://...")`.

## Autoloads

| Name | Script | API |
|---|---|---|
| `SceneTransition` | `ui/scene_transition.gd` | `fade_to(scene_path)` |
| `GameTheme` | `ui/game_theme.gd` | Builds the global `Theme` (pixel font, outline, shadow) on start |
| `VfxManager` | `vfx/core/vfx_manager.gd` | `spawn(VFXEvent.Type, pos, dir)`, pooled; only types registered in `EFFECT_SCENES` render |
| `HitStop` | `vfx/components/hit_stop.gd` | `trigger_light/medium/heavy/death()` |
| `SfxManager` | `vfx/components/sfx_manager.gd` | `play(bank, pos)` over `SFX_BANKS` |
| `InputDevice` | `input/input_device.gd` | `active_device`, `is_gamepad()`, `cursor_axis()`, `camera_axis()`, `is_los_held()`, `rumble(kind)`; bridges the gamepad to keys |

These six scripts (and `tests/run_tests.gd`) have no `class_name`; every other script declares one.

## Global state (static vars, not autoloads)

- `BattleState.ALL_HERO_DATA` / `ALL_ENEMIES`: one instance of each `HeroData` / `EnemyData` subclass, keyed by name or type.
- `BattleState.PLAYERS`: party combat Dictionaries built by `HeroData.to_combat_dict()`. `BattleState.TURN_QUEUE`: all combatants. `TAB_ITEMS`: consumable item Dictionaries.
- `DungeonState.current_run`: the active run, or `null` for a quick battle without a dungeon.
- Save: `DungeonState.save()` writes `DungeonState.SAVE_PATH` (temp file + rename) with `"version": SAVE_VERSION`. A save without the field is legacy v0 and loads as before; a higher version is `SaveStatus.NEWER` (not loaded, file untouched); a malformed one is `CORRUPT` and the menu moves it to `*.corrupt.json` instead of deleting it. Changing the format means bumping `SAVE_VERSION`, migrating in `_read_save` and adding a test. Tests never touch the player save (see Commands).

Who calls what:
- `setup_party(names)`: party select / main menu (continue).
- `setup_enemies_for_room(room_type)`: `BattleScene._ready()`, using the current room (BATTLE when there's no run).
- `reset_players()`: when a run ends; it restores HP, spell slots, Ki and resource pools.

`BattleState.setup()` consumes `DungeonState.pending_buffs`.

## Resources (data model)

Content is defined **in code**: each hero, enemy, action and weapon is a GDScript subclass of a `Resource` base that sets its fields in `_init()`. There are no `.tres` data files for content; the only `.tres` files are `SpriteFrames` animations (`assets/sprites/**`, `vfx/effects/**`).

- `ActionData`: cost (`spell_slot_level`, `ki_cost`, `bonus_action`, `pool_key`), targeting (including the area shape: `area_kind`, `area_size_ft`), damage dice/attribute/type, and **generic effect fields** (saving throw, `applies_condition`, `creates_surface`, concentration, revive…). `BattleState` handles these fields, so most new abilities need data only.
- `HeroData`: stats, `actions`, `skills`, `reactions`, `weapon`, aura, and `caster_type` + `level` → D&D 2024 spell slots (`get_spell_slots_max()`; the table currently stops at level 12, see "Pending rules" in `docs/architecture/battle.md`). There is no MP: spells use slots, the Monk uses Ki (`ki_per_level × level`).
- `EnemyData`: stats, resistances, and the AI's actions (`action_pool`, `action_behaviors`).

## Signals

Signals are only used **from child to parent** inside the battle UI and VFX: panels emit, and `BattleScene` connects in `_build_hud()` / `_initialize_state()`. `BattleState` emits nothing; `BattleScene` calls it and then reads its results (`last_attack_info`, floater queues) and calls `_refresh_ui()`. The full signal table is in [docs/architecture/battle.md](docs/architecture/battle.md#battle-ui-battleui).

## Code conventions

- **Logic and rendering are separate:** `BattleState` (RefCounted) never touches nodes. `BattleScene` orchestrates, sets `_animating` to block input during animations, and calls `_refresh_ui()` after every state change.
- **Combatants are identified by their index in `TURN_QUEUE`.** Find players in `PLAYERS` by name with `_player_index_by_name()` / `get_active_player_index()`; never assume the indexes line up.
- `combatant_statuses[idx]` (parallel to `TURN_QUEUE`) holds both visible conditions and internal keys (`reaction_used`, `disengage`, `death_saves_*`…). HUD display data (name, color, description) lives **only** in `StatusDefinitions.REGISTRY`/`ORDER`.
- `last_attack_info` is ephemeral, read by `BattleScene` right after each attack.
- `combat_log` entries use `_log(text, type)` with type `dmg`, `heal`, `miss`, `status`, `crit` or `system`.
- Resistances, vulnerabilities and immunities are stored as strings of `ActionData.DamageType` names (`"FIRE"`).
- Rolls go through `DiceRoller` (global RNG), so tests make them deterministic with `seed()` / `_find_seed_for_d20()`.
- When you add a field to `HeroData`, also add it to `to_combat_dict()`.
- Settings: only through `GameSettings` (`load_settings`, `save_settings`, `apply_settings`), never by writing `user://settings.cfg` directly. Tests redirect `GameSettings.PATH` to the sandbox.
- Input: screens keep reading `KEY_*`; the gamepad is bridged to synthetic keys by `InputDevice`, and battle-only commands are `act_*` actions (`InputBindings`). In combat the grid cursor is `BattleState.cursor_tile` (mouse, stick and D-pad/arrows all write it); validity is checked only on confirm (`get_cursor_feedback`, `apply_cursor_selection`). The action-HUD cursor walks the **visible** grid cells (`ActionPanel.nav_*`, `HudNav`); there is no hidden tab model. Every selected item, on every screen, is marked with the same white 3 px ring: `FocusGlow.make_ring()` / `FocusGlow.attach()`.
- Files are UTF-8 with LF line endings (`.editorconfig`, `.gitattributes`); GDScript uses tabs.
- Tests: add to `_run_all()` with `_eq` / `_true`. Tests write saves only under `user://test_sandbox/` (`TEST_SAVE_DIR`) and never name the real save file. A top-level test function must end with `_reached.append("<name>")` and be listed in `EXPECTED_TO_FINISH`, so a runtime error that aborts it fails the suite. The `_battlefield()` fixture has fixed positions (Guerreiro (2,3), Goblin Scout (9,1)…) that the movement and AI tests depend on.

## Change policy

- Small, testable, reversible changes. No refactors outside the requested scope.
- Reuse existing systems (generic `ActionData` fields, `StatusDefinitions`, `SurfaceType`, `DiceRoller`) before adding new ones.
- Preserve scenes, resources and signals; changing a signal or a save-format field is an architecture decision (see the delegation table).
- Never commit or push unless the user asks.

## Further documentation

- [docs/architecture/battle.md](docs/architecture/battle.md): combat rules, surfaces, reactions, terrain, `ActionData` fields, UI and signals, VFX.
- `docs/superpowers/specs/` and `docs/superpowers/plans/`: designs and plans for past features (dated; the code may have changed since).
- `docs/vision/dungeon-run-longa.md`: planned vision for long runs (not implemented).
- `README.md` is out of date (it lists 4 heroes and an old file layout).

## Team Workflow & Prompt Convention

This project follows a team model:
- **Developer (Claude Code + user):** writes and edits code.
- **Consultant (Cowork assistant):** analyzes code, writes documentation, and creates prompts for Claude Code.

Prompts from the consultant follow this structure:
1. **Context**: game reference (BG3 for combat, D&D 2024 for characters), session scope
2. **Expected deliverable**: plan only, or plan + implementation
3. **Problems**: current behavior vs. correct behavior (BG3 or D&D 2024 reference, as `game-rules.md` assigns), without dictating code
4. **Constraints**: what must not break, known dependencies

The consultant describes *what*; Claude Code decides *how*. **Session scope is always explicit**: if it says "plan only", produce a structured plan and do not modify files. Prompts may open with a Superpowers directive naming the target skill (e.g. `writing-plans`, `systematic-debugging`); still judge whether the spec is complete enough or whether a clarifying question is needed first.

## Agent skills

### Issue tracker

Issues live in GitHub Issues for `Lucas-AV/Dungeon-Descend-Godot-Prototype`, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

The five default triage labels (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`), each label string equal to its role. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `GLOSSARY.md` plus `docs/adr/`, both created lazily. See `docs/agents/domain.md`.

### Delegation (subagents)

This section is the standing instruction that allows subagents and sets their model/effort. Default: **do the work inline.** Delegate only when it keeps a large amount of reading or test output out of the main context, or when the task needs a different model tier. Never delegate a one-file read, a single grep, or an edit you can make directly. Who plans and who optimizes (Superpowers, Ponytail, AutoMode) is in `.claude/rules/workflow.md`.

| Need | Agent | Model / effort |
|---|---|---|
| Symbol lookup, "who calls X" (provisional) | `codebase-memory-scout` | haiku / low |
| Broad search across many files | `Explore` (built-in) | built-in default |
| Verified call-graph / impact answer | `codebase-memory` | sonnet / medium |
| Bounded audit of a subsystem | `codebase-memory-auditor` | opus / high |
| Bounded GDScript change with a full spec + tests | `godot-implementer` | sonnet / medium |
| Complex multi-system bug, or one a first fix didn't solve | `godot-debugger` | opus / high |
| Critical, hard-to-reverse architecture decision | `architecture-advisor` | fable / high |

- Do not use the built-in `Plan` agent or the agents above as a second planning flow. Inside `subagent-driven-development`, map tasks to haiku/low (mechanical, 1-2 files), sonnet/medium (integration), opus/high (design judgment and reviews of risky changes).
- The `automode:*` agents belong to AutoMode's own pipeline (off here); for project work use the agents above.
- Pass `model`/`effort` on the Agent call only to override an agent's frontmatter, e.g. escalate a failed sonnet task to opus.
