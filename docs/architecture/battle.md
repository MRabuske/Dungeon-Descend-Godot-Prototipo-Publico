# Battle System — Detailed Reference

Companion to `CLAUDE.md`. Covers combat rules, action data, the battle UI and VFX in more depth. Function names point into `battle/battle_state.gd` unless stated otherwise. Rules sources and decisions: `.claude/rules/game-rules.md`.

## Combat rules (`BattleState`)

- **State machine:** `State { PLAYER_TURN, ENEMY_TURN, MOVE_MODE, ATTACK_MODE }`. `advance_turn()` closes the turn block, runs the start-of-turn effects of each creature of the next block (`_start_turn_effects`, then `_begin_member`) and activates its first able member (`_activate_member`, which loads the hero's actions).
- **Shared turns (BG3):** consecutive living **heroes** in the initiative queue form one block of up to 10 (`block_from`, `MAX_SHARED_TURN`; bg3.wiki "Combat": "Adjacent creatures in the turn order share their turn order position and can act interchangeably"); enemies act one at a time (project decision: the wiki is silent on enemies). `turn_block` holds the block. The block is one *position* in the initiative order, but **each hero ends his own turn**: `end_member_turn()` ends only the active hero's turn (`EndResult.SWITCHED`: control passes automatically to the next hero of the block who has not ended and can act), and only when the last available hero ends does it return `EndResult.BLOCK_DONE` and the caller runs `advance_turn()`. While the block lasts, a hero who ended can be selected (portrait, hero on the map) and `cancel_member_end()` gives him control back with the movement, Action and Bonus Action he still had (nothing is reset); once the block is over the markers are cleared and nothing can be cancelled. An ended hero has no actions (`active_ended()` makes `is_item_available`, `enter_move_mode` and `enter_attack_mode` refuse). `pass_control_if_incapable()` hands control to the next available hero when the active one becomes unable to act (Downed, Stunned, Paralyzed) in mid block, or reports that nobody is left (`BattleScene._refresh_ui` then advances the turn). Free switching (`switch_active_member`, `cycle_active_member`) cycles only heroes who have not ended; a hero who lost the turn at block start (Stunned, Paralyzed, Downed: `_lost_turn`) is never offered. Each hero has his own movement, Action and Bonus Action: the `has_attacked`, `has_used_bonus_action`, `move_points_remaining`… fields are the *active* hero's, saved to `_member_turn` on a swap. Start-of-turn effects (poison, burning, stun/paralysis skip, death save, surface tick, condition decay, Prone stand-up, reaction and Disengage reset, Barbarian rage) run **per creature** at the start of the block. `begin_turn()` forms the first block. Controls: End Turn and Cancel End Turn are the **same command** (bg3.wiki "Controls": Space; Y/Triangle on a pad): Space on the keyboard, the "FIM"/"VOLTAR" button, and X on the gamepad (the game's Y is Examine, so the pad keeps X); the same press ends the active hero's turn or, on a hero who already ended, cancels it. Switch: left-click a portrait or the hero on the map, `H` / L3 (`act_switch_hero`). The turn bar shows no "shared turn" indicator (the player reads it from the portraits' order, as in BG3): allies have a blue frame, enemies a red one, and a hero who ended his turn is dimmed with a small "FIM" (the wiki does not describe how BG3 marks it; provisional art). Initiative stays d20 + DEX (`roll_initiative`, bonus entry point `_initiative_bonus`).
- **Attacks:** `_apply_attack()` rolls d20 + proficiency + attribute modifier, plus status bonuses (furtivo, fury, crit) and per-action smite dice. Advantage and disadvantage come from `_get_attack_roll_mods()`. The result is written to `last_attack_info`. **Spells** (`ActionData.is_spell`) do not add the attribute modifier to damage; weapon attacks and physical attacks (Soco, Flurry, Atq. Rápido) do. Sneak Attack dice double on a crit.
- **Damage:** every damage source goes through `_deal_damage_to_combatant(idx, amount, type, is_crit, extra)`. It mitigates each component by its own type (`extra` = `{DamageType: amount}`, e.g. Smite radiant, Dip fire), skips HP, concentration and Death Saves when the applied total is 0, writes HP, rolls concentration (DC max(10, damage/2); natural 20 passes, natural 1 fails), handles Downed (1 failure, crit 2) or death, ends Invisibility, and returns the applied amount. Callers keep stats, floaters, logs and `last_attack_info`, using that return value. Mitigation lookup is `_apply_damage_type_mods()` (target `resistances` / `vulnerabilities` / `immunities` as enum-name strings like `"FIRE"`). `wet` (BG3) gives vulnerability to Lightning and Cold and resistance to Fire. Weapon attacks deal the weapon's `WeaponData.damage_type`; enemies use `EnemyData.attack_damage_type`, overridable per behavior with `"damage_type"`.
- **Combatant access:** identity is the `TURN_QUEUE` index. `player_index_of(idx)`, `get_hp(idx)`, `get_max_hp(idx)` and `_set_hp(idx, v)` hide the `PLAYERS` / `enemy_hp` split; `_append_enemy()` gives duplicate enemies unique names ("Goblin Scout 2").
- **Conditions:** `apply_condition()` / `remove_condition()` are the only entry points (companion keys such as `charmed_by` and `marked_*` leave with the condition). Stunned, Paralyzed and Prone break concentration; Wet removes Burning and Invisibility and blocks Burning; Prone on the creature's own turn ends the turn (`turn_forced_end`, consumed by `BattleScene._end_turn_if_forced`). `_begin_member()` decays `StatusDefinitions.DECAY_AT_TURN_START` at turn start through `_decay_condition()`; Burning and poison decay in their own tick; Stunned and Paralyzed decay when the turn is skipped.
- **Attack math:** `_effective_ac()`, `_player_attack_bonus()` and `_enemy_attack_profile()` are shared by the real roll and the preview. `calc_hit_chance()` uses `_hit_probability()`, which enumerates the d20 exactly (no dice rolled). Enemy attacks and enemy Opportunity Attacks go through `_resolve_enemy_attack(attacker, target, range, behavior)`. Automatic crits (`_auto_crit`): melee on a Downed target; any attack from within 3 m (2 squares) on a Paralyzed one.
- **Reaction window:** with `hold_hits_for_reactions`, single-target attacks keep the hit in `pending_hit`; Uncanny Dodge, Deflect Missiles and Smite (as a Radiant component) modify it, and `commit_pending_hit()` applies the damage once. BattleScene opens the window for single player attacks and enemy attacks, and commits after the reaction queue.
- **Economy:** `is_item_available()` and `spend_action_cost()` cover Action and Bonus Action (tactical), slots with upcast (`has_slot_at_or_above` / `_consume_slot`), Ki, per-combat uses (`_uses_spent`, never on the shared Resource) and pools. Also `use_second_wind()`, `use_step_of_the_wind()` and `spend_ki()`. Spending an Action or Bonus Action ends Invisibility.
- **Tests:** `DiceRoller.force_next([...])` / `clear_forced()` force specific die results.
- **Saving throws:** `_resolve_saving_throw()` and `_spell_save_dc()`.
- **Concentration:** one spell per caster; damage forces a check that can break it (`_check_concentration_after_damage`).
- **Downed / death saves:** `_enter_downed`, `_process_death_save`, `_check_death_saves`.
- **Movement:** one pathfinder for heroes and enemies. `_search_movement(mover_idx, budget)` returns cost and parent maps; `get_reachable_tiles()` (hero), `get_path_to()` and the AI all read it, so path, cost, animation and stepped-on surfaces agree. 8 directions, each square entered costs 1 (diagonals too); difficult terrain (mud, Ice surface) costs 2 (`_tile_cost`); a diagonal cannot cross the corner of a square an object fills (`_fills_square`: Obstacle, Statue, Cover; creatures and holes do not block the diagonal). Obstacle, Statue and Cover block movement; heroes and enemies pass through allies (never end on one) and never through the other side (`_creature_blocks_step`). Frightened, Restrained, Grappled and Paralyzed cannot move.
- **Distance:** one metric, Chebyshev (`BattleState.king_dist`, diagonal = 1), for ranges, melee reach, Opportunity Attacks, Disengage, Sneak Attack's adjacent ally, AI target choice and teleport. (`MapGenerator` keeps Manhattan only for spawn separation, which is map generation, not a rule.)
- **Opportunity attacks:** `check_opportunity_attacks()` for one step, `check_opportunity_attacks_along()` for a whole path (each reactor once; checked **per step**). Disengage lasts the whole turn against everyone. The orange "⚠ Ataque de Oportunidade!" preview (`BattleArea._draw_move_path`, `_draw_jump_arc`) and the executed move or jump (`BattleScene._enqueue_opportunity_attacks`) call the **same** rule, `check_opportunity_attacks_along` (a jump is a single step), so a warning always means an OA happens and no warning means none; the text is placed in screen space for any zoom and pan (`_place_oa_warning`, `_canvas_to_screen`: the map is drawn under `draw_set_transform`, child Labels are not). Who does not react (bg3.wiki "Opportunity Attack"): wielding a ranged weapon (`WeaponData.is_ranged`, `EnemyData.ranged_weapon`), Prone, Incapacitated, Blinded, no reaction left; an Invisible mover does not provoke. Restrained and Charmed-by-the-mover are inherited rules not in the wiki.
- **Areas:** see "Areas of effect" below.
- **Line of sight:** `_has_los()`. Enemy vision for Hide: `get_enemy_vision_tiles()` (`ENEMY_SIGHT_RANGE` = 8 tiles, Chebyshev distance). Obstacle, Statue and Cover block it; the Chest does not.
- **Tactical actions** (`actions/tactical/`): `resolve_shove` (2 squares fixed), `resolve_hide`, `resolve_jump` (fixed `JUMP_MOVE_COST`), `resolve_dip` (a Fire surface within 2 squares), `resolve_throw`, `resolve_potion_throw`. A target shoved onto a VOID tile dies (`_fall_into_void`). Hide is denied while any enemy has line of sight (there is no obscurity system); out of every enemy's sight it rolls Stealth against DC 10.
- **Items:** a single consumable, the Potion of Healing (`TAB_ITEMS`, Dictionaries, not `ActionData`): 2d4+2, Bonus Action to drink (`use_item`), removes Burning and Downed; throwing it is the action `AcaoArremessarPocao` (Action, range 12, a 5 ft sphere heals everyone in it, ally or enemy, one roll). There is no "give" action: heal an ally by throwing it. Items are not in the save (`TAB_ITEMS` is rebuilt in `setup()`).
- **Enemy AI:** `_pick_enemy_action_idx()`, `get_enemy_move_path()` (approach / flee / reposition over the shared pathfinder, preferring squares with line of sight), `apply_enemy_attack()` (`_pick_enemy_target`), plus self-buffs, emanation AoEs and teleport behaviors. Target choice: the lowest-HP hero in reach; when a Downed and a standing hero are both in reach, 50% chance (a `DiceRoller` d2) to pick the Downed one. This 50% is a **project decision** (bg3.wiki is silent on AI target priority; forum reports suggest the BG3 AI does attack Downed characters, unconfirmed).
- **Dice:** `DiceRoller` (`dice_roller.gd`) uses Godot's global RNG; `seed(n)` makes rolls deterministic.

## Areas of effect (`battle/area_shape.gd`, `BattleState.area_footprint`)

D&D 2024 shapes on the grid (SRD 5.2 Rules Glossary "Area of Effect"; DMG 2024 "Areas of Effect"): the origin is an **intersection** of squares and a square is affected if the area covers **at least half** of it (exactly half counts). `AreaShape` is pure (no nodes): `sphere`, `cylinder` (same footprint seen from above), `emanation` (the creature's square grown by a disc; origin square excluded unless `include_origin`), `cube_square` (aligned block), `cube`, `cone`, `line` (free direction, exact polygon coverage), `self_origin` (the corner of the caster's square nearest the aimed direction: a project convention, the books only say "an intersection"). Sizes are in **feet**; 5 ft = 1 square.

`ActionData.area_kind` / `area_size_ft` / `area_width_ft` / `area_includes_origin` describe an action's area (`has_area()`, `aims_at_corner()`, `aims_at_ground()`, `area_text()`); `BattleState.area_footprint(action, aim, caster_idx)` is the **only** footprint function: the preview (`get_area_preview_tiles`), the animation (`last_area_tiles`) and the effect (`apply_area_at`, `resolve_throw`, `resolve_potion_throw`) all use it, so the preview is what gets hit. Every creature in the footprint (the caster excluded) takes the damage with its own saving throw; surfaces cover the whole footprint. `aim` is the intersection for spheres, the square for cubes, the origin creature's square for emanations.

Aiming: sphere and cylinder aim at intersections. In ATTACK_MODE with `attack_corner_mode`, `cursor_tile` holds the corner (0..cols, 0..rows; corner (x, y) is the top-left vertex of square (x, y)); the mouse and the stick snap to the nearest corner (`BattleArea._pointer_cell`), D-pad steps corner by corner, and the cursor is drawn as a cross. A corner is valid when one of the squares touching it is in range and (at range) in line of sight.

| Ability | Shape | Notes |
|---|---|---|
| Fogo, Gelo, Chuva de Flechas, Arremessar | sphere, 5 ft | provisional: these will be redone with the D&D 2024 spells in the class review |
| Trovão | sphere, 10 ft | idem |
| Nuvem de Adagas | cube, 5 ft | one square, no save, concentration |
| Cura em Área | emanation, 5 ft, includes origin | around the chosen ally |
| Arremessar Poção | sphere, 5 ft | the BG3 cloud has a 1 m radius, accepted as 1 square |
| Enemy Sweeping Strike / Frost Nova | emanation, 5 ft | from the enemy's square |
| Enemy Ice Storm / Shockwave | emanation, 10 ft | loses the 4 corner squares (they cover under half) |

## Surfaces (`battle/surface_type.gd`)

Types: FIRE, ICE, WATER, ELECTRIFIED_WATER, ACID, POISON, STEAM, CLOUD_OF_DAGGERS. Actions create them through `ActionData.creates_surface`, and they are tracked in `BattleState.tile_surfaces` (`{type, turns, dc}`), not on `TerrainTile`.

- Combining surfaces follows `_resolve_surface_interaction`: fire + water → steam, fire + ice → water, water + ice → ice, water + electrified → electrified water. Otherwise the new surface replaces the old one.
- `DURATION` counts **rounds**, not individual turns. WATER is `PERMANENT` (bg3.wiki "Water"); ELECTRIFIED_WATER lasts 2 and then **turns back into Water**.
- FIRE has no entry in `TICK_DAMAGE`: it applies the `burning` condition, and burning deals the per-turn damage.
- POISON (cloud): a CON save (DC 11, `POISON_CLOUD_DC`) when entering and at the start of each turn, or Poisoned for 1 turn; no damage. ICE: a DEX save or Prone on entering **and when created under a creature** (not over another surface), with the caster's spell save DC stored on the surface (`dc`; 12 when there is no caster, e.g. a trap); half speed. STEAM applies Wet. ACID: -2 AC condition on entering. ELECTRIFIED_WATER and CLOUD_OF_DAGGERS tick damage at the start of the turn (`TICK_DAMAGE`).

## Reactions

- `HeroData.reactions` holds `ActionData` with `is_reaction = true` and a `reaction_trigger`: `on_attacked_ranged`, `on_melee_hit_self` or `on_attacked_visible` (see `actions/reactions/`).
- `BattleScene` appends triggered reactions to `_pending_reaction_queue`. `_process_next_reaction()` shows a `ReactionPopup`, which emits `reaction_decided(chosen)`.
- `BattleState` resolves the effect: `apply_uncanny_dodge`, `apply_deflect_missiles`, `apply_divine_smite_reaction`, `apply_stunning_strike`, `apply_opportunity_attack`.
- One reaction per combatant, tracked by the `reaction_used` status and reset at the start of their own turn. Toggles go through `set_reaction_setting` / `get_reaction_setting`; only `"OA_enabled"` exists today (no UI).

## Terrain (`tiles/terrain_tile.gd`)

- `ground`: NORMAL, MUD, STONE, GRASS, ELEVATED, VOID
- `object`: NONE, STATUE, OBSTACLE, CHEST, COVER
- `effect`: NONE, TRAP_INACTIVE, TRAP_ACTIVE, POISON_CLOUD, HEAL_ZONE

MUD and the Ice surface cost 2 movement (diagonals too); everything else costs 1. **Obstacle, Statue and Cover block movement and sight** (and the diagonal past their corner); the Chest is low and blocks neither. **Cover is just an object now**: it no longer changes the attack roll (BG3 has no cover rule) and gives no Hide exception; the old 30% miss chance and the Disadvantage are gone. ELEVATED gives a flat ±2 to **every** attack roll (melee included, bg3.wiki "High ground") when only one side is elevated, never Advantage, and ranged attackers on it get +1 range (see pending rules).

`MapGenerator` (`battle/map_generator.gd`) erodes the borders and checks connectivity with a flood fill that treats VOID, Obstacle and Cover as walls (it stays 4-directional, which is conservative for 8-direction movement), retrying up to 100 times before falling back to a flat map. Spawns are never on a wall. `generate(seed_val)` is deterministic.

## Action data (`actions/action_data.gd`)

- `action_type`: ATTACK, MOVE, END_TURN, DASH
- `damage_attribute`: NONE, STR, DEX, INT, WIS, CON
- `damage_type`: the 13 BG3 types (SLASHING, PIERCING, BLUDGEONING, ACID, COLD, FIRE, FORCE, LIGHTNING, NECROTIC, POISON, PSYCHIC, RADIANT, THUNDER) plus HEALING (never mitigated)
- Cost and economy: `spell_slot_level` (0 = cantrip, 1–6 = slot level), `ki_cost`, `pp`/`max_pp`, `bonus_action`, `pool_key`/`pool_cost` (a named pool on the player dict, e.g. `lay_on_hands`), `grants_extra_action`
- Targeting: `attack_range`, `area_kind` / `area_size_ft` / `area_width_ft` / `area_includes_origin` (see "Areas of effect"), `targets_allies`, `self_target`, `hit_count`
- Generic effects handled by `BattleState` without per-action code: `is_weapon_attack` (uses `WeaponData` dice), `is_spell` (no attribute modifier on damage), `requires_saving_throw`/`save_attribute`, `applies_condition` (+ save, duration, DC), `creates_surface`, `requires_concentration`, `revives_downed`, `clears_conditions`, smite dice
- Visuals and audio: projectile frames, `impact_type`, AoE cascade fields, `sfx_cast`/`sfx_impact`

Items are not `ActionData`: they are Dictionaries in `BattleState.TAB_ITEMS` (only the Poção), consumed by `use_item()`.

## Battle UI (`battle/ui/`)

Every node is built in code; `BattleScene._build_hud()` assembles the layout:

```text
VBoxContainer (full screen)
├─ TurnOrderBar
├─ BattleArea               (expands)
└─ HBoxContainer            HUD_HEIGHT = 200 (default; dynamic via _hud_h)
   ├─ StatusPanel           STATUS_WIDTH = 280
   ├─ ActionPanel           SIZE_EXPAND_FILL
   └─ End Turn button
Floating: CombatLogPanel (toggled by 💬), ReactionPopup, ExaminePanel, ContextMenu
```

Each panel receives `setup(state)` in `BattleScene._initialize_state()` and is refreshed from `_refresh_ui()`.

| Class | Signals | Refresh / entry point |
|---|---|---|
| `ActionPanel` | `grid_action_clicked(action)`, `grid_action_hovered(action)`, `end_turn_pressed`, `cancel_action`, `confirm_action`, `content_height_changed(h)` | `refresh()` |
| `TurnOrderBar` | `slot_right_clicked(slot_index, global_mouse_pos)`, `slot_clicked(slot_index)` | `refresh(queue, active_index, state)` |
| `StatusPanel` | `concentration_cancel_requested(queue_idx)` | `refresh(active_index)` |
| `ReactionPopup` | `reaction_decided(chosen)` | `show_for(text, options, callback)` |
| `ContextMenu` | `examine_requested(slot_index)` | spawned at the cursor; frees itself |
| `ExaminePanel` | — | `show_for(state, idx)` |
| `CombatLogPanel` | — | `refresh()` reads `combat_log` |
| `BattleResultScreen` | `continue_requested`, `restart_requested` | `show_result(won, stats)` |
| `PauseMenu` | `resume_requested`, `menu_requested` | `show_menu()` / `hide_menu()` |
| `TurnTransitionLayer` | — | `show_turn(title, subtitle, on_done)` |

`BattleArea` emits `tile_clicked(grid_pos)`, `tile_hovered(grid_pos)` and `attack_hover_changed(combatant_idx)`. It draws the isometric grid and hands sprites, damage numbers, shake and flash to `CombatantLayer`, `FloaterManager`, `CameraShake` and `ScreenFlash` (`vfx/components/`).

### ActionPanel

- The 14-column grid (`GRID_COLS`) is split by a draggable divider. Left side: normal actions. Right side: bonus actions, spells (`spell_slot_level > 0`), Ki skills and END_TURN.
- Dragging within a side reorders slots (`_left_order` / `_right_order`). Dragging across sides records `_side_overrides`, which is lost when the panel is recreated. The 🔒 button sets `_grid_locked`.
- `_update_visibility()`: in PLAYER_TURN the grid is shown; in other states an overlay with a status message and a "Voltar" button replaces it. `_filter_mode` (0 none, 1 Action, 2 Bonus) resets when the grid is hidden.

### Examine flow

`TurnOrderBar.slot_right_clicked` → `ContextMenu` → `examine_requested` → `ExaminePanel.show_for()`, which shows stats, statuses (via `StatusDefinitions`), resistances and passives, with 4-angle sprite rotation. Y (gamepad) or Tab reaches the same menu through the turn-order bar; see [input.md](input.md#examine-y--tab).

### Aiming and the grid cursor

MOVE_MODE and ATTACK_MODE share `BattleState.cursor_tile`. Arrows and D-pad step one tile (elevation ignored); mouse hover and the stick set it directly. Any tile can be selected; `get_cursor_feedback()` says whether confirming there is valid and why not, and `apply_cursor_selection()` only commits valid tiles. This replaced the old locked navigation (`move_cursor_grid`, `cycle_attack_target`, `move_attack_tile_cursor`). Details in [input.md](input.md#grid-cursor-combat).

Clicking (or Enter/A on) any targeted attack, spell or skill **always** enters ATTACK_MODE and shows the range, even when no target is valid right now (`BattleScene._execute_action` never cancels the aim on its own). Aiming at an invalid target shows the reason beside the cursor ("Fora de alcance", "Sem linha de visão", "Sem alvo"…), executes nothing and spends nothing; Esc/B or the Voltar button leaves. The line-of-sight and range rules are unchanged. End-to-end coverage: `_test_hero_actions_e2e` (every hero action, click and keyboard) and `_test_enemy_actions_e2e` (every enemy behavior).

### Combat log

`BattleState._log(text, type)` prepends to `combat_log` (capped at 60); the panel shows the latest 25. Types: `dmg` (red), `heal` (green), `miss` (tan), `status` (purple), `crit` (gold), `system` (gray, the default).

## VFX and audio

- `VfxManager.spawn(type: VFXEvent.Type, pos: Vector2, dir := 0.0)` uses pooled effects. Only types with a scene in `EFFECT_SCENES` render: SLASH_LIGHT, IMPACT_LIGHT, IMPACT_CRIT, SKILL_FIRE, SKILL_ICE, SKILL_LIGHTNING, SKILL_HEAL. To add one, create the `.tscn` under `vfx/effects/` (extending `VFXEffectBase`, which emits `effect_finished`) and register it.
- `HitStop.trigger_light/medium/heavy/death()` briefly freezes the game on hits.
- `SfxManager.play(bank, pos)` plays from `SFX_BANKS`, avoiding immediate repeats.
- Shaders: `vfx/shaders/` (burn, dissolve, hit_flash, outline).

## BG3 conformance (audited 2026-11-13, rechecked 2026-11-15)

Pages read on bg3.wiki: Actions, Dash, Disengage, Jump, Shove, Hide, Help, Dip, Throw, Opportunity Attack, Potion of Healing, Combat, Initiative, Turn-based mode, Falling damage, Critical hit, Dice rolls, Sneak Attack (Critical Hit) and (Melee), High ground, Damage, Damage types, Saving throw, Concentration, Death saving throw, Downed, Resistance, and the condition pages (Burning, Wet, Blinded, Frightened, Paralysed, Stunned, Restrained, Invisible, Charmed, Prone, Poisoned) and surface pages (Fire, Water, Ice, Electrified Water, Acid, Poison Cloud, Steam Cloud, Cloud of Daggers). Tests: `_test_bg3_rules_audit`, `_test_phase5_bg3_fixes` and the per-phase tests in `tests/run_tests.gd`. D&D 2024 grid rules: SRD 5.2 (Playing on a Grid, Rules Glossary) and the DMG 2024 area rule (half-square, intersection; read from a forum quote of the book, medium confidence).

| Rule | Implementation | Status |
|---|---|---|
| Resistance halves (rounded down), vulnerability doubles, both cancel, immunity wins, per damage type | `_mitigate` | matches |
| Each damage type dealt separately | `_deal_damage_to_combatant` | matches |
| Concentration save DC = max(10, half the damage); natural 20 passes and natural 1 fails (the only saves with that rule); broken by Incapacitated, Downed, Prone; no save if the damage is 0 | `_check_concentration_after_damage` | matches (natural 20/1 fixed in the 2026-11-15 pass) |
| Death save DC 10, 3 successes stabilize, 3 failures kill; damage while Downed = 1 failure, crit = 2; melee on Downed is a crit; any healing removes Downed; Help gives 1 HP | `_process_death_save`, `_add_death_save_failure`, `_auto_crit` | matches |
| Burning: 1d4 Fire per turn; Help, a Healing Potion or Wet removes it | `_start_turn_effects`, `HELP_CLEARS`, `_heal_creature` | matches (duration: the wiki gives no turn count; the code uses 2) |
| Critical hit: damage dice rolled twice, modifiers not; Sneak Attack dice double too | `_apply_attack` | matches (Sneak crit fixed) |
| Advantage and Disadvantage cancel out | `DiceRoller.roll_d20_adv_dis`, `_hit_probability` | matches |
| High ground: +2 / -2 on every attack roll, melee included | `_get_attack_roll_mods` | matches (melee fixed) |
| Spells do not add the ability modifier to damage; weapon attacks do | `ActionData.is_spell`, `_apply_attack`, `apply_area_at`, `get_damage_range` | matches (fixed; see the classification below) |
| Saving throws: no auto success or failure on 1 / 20 (except concentration) | `_resolve_saving_throw` | matches |
| Poisoned: Disadvantage on attacks and ability checks, not on saves | `_get_attack_roll_mods` | matches |
| Stunned / Paralyzed: auto-fail STR and DEX saves | `_resolve_saving_throw` | matches |
| Prone: Advantage on attacks within 3 m, no Disadvantage at range, stand up costs half the speed, Disadvantage on STR/DEX saves; falling Prone on your own turn ends it | `_get_attack_roll_mods`, `_begin_member`, `turn_forced_end` | matches (turn end fixed) |
| Blinded: Disadvantage, Advantage against, attacks and spells limited to 3 m (2 squares), no Opportunity Attacks | `_blind_capped_range`, `check_opportunity_attacks` | matches (range cap fixed) |
| Frightened: cannot move; Disadvantage on attacks and ability checks | `get_reachable_tiles`, `get_enemy_move_path` | matches (was "cannot approach the source") |
| Paralyzed: attacks from within 3 m always crit | `_auto_crit` | matches (the wiki card says "melee"; the listed rule says 3 m) |
| Invisible: ends on attack, cast, Action or Bonus Action, damage, Wet | `finalize_attack`, `spend_action_cost`, `_apply_hp_damage`, `apply_condition` | matches |
| Sneak Attack: advantage or an adjacent ally (Chebyshev 1) with no net Disadvantage, finesse or ranged weapon, 1d6 + 1d6 per 2 levels | `_can_sneak_attack` | matches |
| Opportunity Attack: leaving melee reach (8 squares) of a hostile; per step; not for ranged-weapon wielders, Prone, Incapacitated, Blinded, or an Invisible mover; Disengage prevents it for the turn | `check_opportunity_attacks(_along)` | matches |
| Action economy: Dash, Disengage, Help, Hide, Throw = Action; Jump, Shove, Dip, drinking a Potion = Bonus Action | `is_item_available`, `spend_action_cost` | matches |
| Potion of Healing: 2d4+2, Bonus Action to drink, Action to throw (18 m), the cloud heals everyone in it | `use_item`, `resolve_potion_throw` | matches |
| Jump: Bonus Action + 3 m of movement; reach grows with STR | `resolve_jump`, `jump_reach` | matches |
| Dip: Bonus Action, range 3 m, a dippable surface | `resolve_dip` | matches |
| Shared turns: adjacent allies in the order act interchangeably, max 10; End Turn and Cancel End Turn share one key; each hero ends his own turn | `block_from`, `end_member_turn`, `cancel_member_end`, `switch_active_member` | matches for heroes (enemies: wiki silent; the pad keeps X because Y is Examine) |
| Surfaces: Water permanent; Electrified Water 2 turns, back to Water; Poison cloud CON save or Poisoned 1 turn; Ice DEX save with the caster's DC, also on creation; Steam applies Wet; Cloud of Daggers 4d4 per turn, no save | `surface_type.gd`, `apply_surface_on_enter`, `_apply_surface_tick`, `_deposit_surface_after_attack` | matches |
| A shoved or fallen creature into a chasm / off the map dies | `_fall_into_void` | matches |

**Spell / weapon classification (damage modifier).** Spells (no attribute modifier on damage): Raio Arcano, Atq. Divino (a WIS melee cantrip with no weapon or slot), Chuva de Flechas (not a weapon attack in the code: it spends a slot and asks a DEX save), Fogo, Gelo, Trovão, Nuvem de Adagas. Physical attacks (modifier added): Atq. Normal, Pesado, Preciso, Smite Divino (a weapon attack), Atq. Rápido, Soco, Flurry of Blows. Healing keeps the casting modifier (it is not damage).

**Approved exception to BG3 (not a conformance failure):** initiative is 1d20 + DEX modifier (+ applicable bonuses through `_initiative_bonus`), higher DEX breaks ties, as in D&D 2024. BG3 uses 1d4 + DEX. See `.claude/rules/game-rules.md`.

**Project decisions on top of BG3** (kept on purpose): spell slots instead of mana, Ki for the Monk, "Esperar" (pass) and "Fugir" (flee) as actions, enemies dying at 0 HP, a Jump that provokes Opportunity Attacks (the Jump page is silent), a natural 20 on a death save not reviving and a natural 1 counting as one failure (the wiki is silent), 2 squares of Shove (the game has no weight), the 50% AI preference for Downed heroes, heroes-only shared turns, no obscurity system (Hide needs no enemy line of sight), area spells measured in D&D 2024 feet.

## Downed heroes and enemy targeting

**Rule kept (confirmed on bg3.wiki, Death saving throw):** a melee attack that hits a Downed target is always a critical hit, and a critical hit against a Downed target counts as 2 failed death saves; damage in general counts as 1. Code: `_auto_crit`, `_apply_hp_damage`, `_add_death_save_failure`.

**Target choice (project decision, BG3 unverified):** among the heroes in reach the enemy picks the lowest-HP one (a Downed hero has 0 HP). When both a Downed and a standing hero are in reach, it picks the Downed one with 50% probability (a `DiceRoller` d2 in `_pick_enemy_target`), otherwise the lowest-HP standing hero. bg3.wiki says nothing about AI target priority; forum and mod reports suggest the BG3 AI does attack Downed characters, with no official statement. A Downed hero rolls his death save at the start of his block; a melee enemy next to him can still finish him before that roll.

## Pending rules (divergences and open decisions; not changed in code)

Each item is recorded, not fixed. Ask the user before changing any of them.

| # | Area | Current code | Pending |
|---|---|---|---|
| 1 | Spell slots above level 12 | `_FULL_SLOTS` and `_HALF_SLOTS` in `heroes/hero_data.gd` have 12 rows and `get_spell_slots_max()` clamps to level 12. | Levels 13–20 need D&D 2024 values. The half-caster table matches the 2014 table; check it against PHB 2024. |
| 2 | Monk resource | Monk uses Ki. | D&D 2024 names it Focus Points. Decide the name and check the Monk features. |
| 3 | Movement values | `speed` is in squares (6–10), no feet or metre conversion. | 30 ft = 6 squares, 35 ft = 7, 40 ft = 8; what the Monk's extra speed becomes. |
| 4 | Levels | Every hero is level 4; no progression. | Levels 13–20 and the cap; above 20 needs approval. |
| 5 | Class features | Not reviewed one by one. | Review each class feature and resource name against D&D 2024. |
| 6 | Shove | Fixed 2 squares, an STR contest against the passive. | BG3 pushes 1–6 m by the shover's STR and the target's weight, and shoving an ally needs no check; the game has no weight data. |
| 7 | Reaction settings | Only `OA_enabled` exists, with no UI. | BG3 offers an enable box per reaction plus "ask before use". Out of scope for now. |
| 8 | High ground range | Ranged attackers on an ELEVATED square get +1 range against any target, enemies too (the bug that disabled it for enemies is fixed). | BG3 extends the range by the elevation difference only when the **target is lower**, and gives no penalty against a higher one. |
| 9 | Areas and cover | Areas ignore walls: a square behind an Obstacle can be hit. | D&D 2024: Total Cover from the origin blocks a location. Not implemented. |
| 10 | Caster inside his own area | The caster is excluded from his own spells' areas. | bg3.wiki is silent on whether BG3 includes him. |
| 11 | Burning duration | Applied for 2 turns. | The wiki gives no number ("Loses duration: start of turn"). |
| 12 | Dip target | The nearest Fire surface within 2 squares, no aiming. | A proper target pick; "burning object" targets do not exist. |
| 13 | Help clears | `HELP_CLEARS` = prone, restrained, burning. | The wiki lists Burning, Ensnared, Entangled, Enwebbed, Prone, Sleeping, Dazed, Downed...; Restrained generic is not listed. |
| 14 | Save-half damage | Half rounds down with a minimum of 1. | The wiki does not state rounding or the minimum. |
| 15 | Grappled, crit-negating armor | Grappled only blocks movement; no equipment exists. | Out of scope (the Grappled page is a stub). |
| 16 | Emanation exclusions | Enemy emanations never hit the origin square. | Nothing to do today; noted for spells like Spirit Guardians. |
