# Elite/Boss Scaling Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** ELITE rooms spawn 2 powerful enemies (EliteWarrior + EliteMage); BOSS rooms spawn 1 massive guardian with AOE and self-buff mechanics. Composition is determined before each battle via a new static method.

**Architecture:** Three new `EnemyData` subclasses define ELITE/BOSS enemies with calibrated stats. `BattleState.setup_enemies_for_room(room_type)` rebuilds the enemy section of `TURN_QUEUE` before `BattleState.new()` is called — this is required because `_init()` reads `TURN_QUEUE` to initialise `enemy_hp` and `combatant_positions`. `BattleScene` calls this method and updates the context panel per room type.

**Tech Stack:** GDScript 4.6, Godot 4.6, code-only. Branch: `feature/elite-boss-scaling`.

---

## File Map

| File | Status | Responsibility |
|------|--------|----------------|
| `enemies/elite_warrior.gd` | Create | EliteWarriorData — tank, sweep AOE, charge stun, enrage |
| `enemies/elite_mage.gd` | Create | EliteMageData — long-range bolt, AOE ice storm, enrage |
| `enemies/dungeon_guardian.gd` | Create | DungeonGuardianData — boss, massive HP, shockwave AOE, ground slam |
| `battle/battle_state.gd` | Modify | Add 3 types to ALL_ENEMIES; add `setup_enemies_for_room()` |
| `battle/battle_scene.gd` | Modify | Call `setup_enemies_for_room()` before `new()`; update context panel; add `_get_current_room_type()` |
| `tests/run_tests.gd` | Modify | Assertions for setup_enemies_for_room compositions |

---

## Task 1: EliteWarriorData

**Files:**
- Create: `enemies/elite_warrior.gd`

Pattern: copy structure from `enemies/orc_warrior.gd` — same `extends EnemyData` with `func _init()`.

- [ ] **Step 1: Create `enemies/elite_warrior.gd`**

```gdscript
class_name EliteWarriorData
extends EnemyData

func _init() -> void:
	enemy_name   = "Elite Warrior"
	enemy_type   = "EliteWarrior"
	sprite       = preload("res://assets/sprites/enemy/orc_warrior/orc_warrior.png")
	portrait     = preload("res://assets/ui/portraits/enemy/orc_warrior/orc_warrior.png")
	ac           = 17
	max_hp       = 70
	speed        = 4
	attack_bonus = 7
	action_pool = [
		"Crushing Blow on %s...",
		"Crushing Blow on %s...",
		"Sweeping Strike!",
		"Charging at %s...",
		"Enraging!",
	]
	action_behaviors = [
		{"range": 1, "damage_mult": 1.4, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.4, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.0, "aoe_radius": 1, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 2, "damage_mult": 1.6, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.25, "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "raging","buff_value": 4, "buff_turns": 2},
	]
```

- [ ] **Step 2: Commit**

```
git add enemies/elite_warrior.gd
git commit -m "feat: add EliteWarriorData enemy"
git push
```

---

## Task 2: EliteMageData

**Files:**
- Create: `enemies/elite_mage.gd`

- [ ] **Step 1: Create `enemies/elite_mage.gd`**

```gdscript
class_name EliteMageData
extends EnemyData

func _init() -> void:
	enemy_name   = "Elite Mage"
	enemy_type   = "EliteMage"
	sprite       = preload("res://assets/sprites/enemy/dark_mage/dark_mage.png")
	portrait     = preload("res://assets/ui/portraits/enemy/dark_mage/dark_mage.png")
	ac           = 13
	max_hp       = 55
	speed        = 5
	attack_bonus = 8
	action_pool = [
		"Casting Arcane Bolt at %s...",
		"Casting Arcane Bolt at %s...",
		"Casting Ice Storm!",
		"Casting Ice Storm!",
		"Channeling dark power...",
	]
	action_behaviors = [
		{"range": 6, "damage_mult": 1.4, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 6, "damage_mult": 1.4, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 2, "damage_mult": 1.0, "aoe_radius": 2, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.30, "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 2, "damage_mult": 1.0, "aoe_radius": 2, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.30, "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "raging","buff_value": 3, "buff_turns": 2},
	]
```

- [ ] **Step 2: Commit**

```
git add enemies/elite_mage.gd
git commit -m "feat: add EliteMageData enemy"
git push
```

---

## Task 3: DungeonGuardianData

**Files:**
- Create: `enemies/dungeon_guardian.gd`

- [ ] **Step 1: Create `enemies/dungeon_guardian.gd`**

```gdscript
class_name DungeonGuardianData
extends EnemyData

func _init() -> void:
	enemy_name   = "Dungeon Guardian"
	enemy_type   = "DungeonGuardian"
	sprite       = preload("res://assets/sprites/enemy/orc_warrior/orc_warrior.png")
	portrait     = preload("res://assets/ui/portraits/enemy/orc_warrior/orc_warrior.png")
	ac           = 18
	max_hp       = 180
	speed        = 3
	attack_bonus = 9
	action_pool = [
		"Guardian Smash on %s...",
		"Guardian Smash on %s...",
		"Shockwave!",
		"Shockwave!",
		"Enraging!",
		"Ground Slam at %s...",
	]
	action_behaviors = [
		{"range": 1, "damage_mult": 1.6, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.6, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.2, "aoe_radius": 2, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.2, "aoe_radius": 2, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "",        "status_chance": 0.0,  "buff_type": "raging","buff_value": 5, "buff_turns": 3},
		{"range": 2, "damage_mult": 2.0, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.40, "buff_type": "",      "buff_value": 0, "buff_turns": 0},
	]
```

- [ ] **Step 2: Commit**

```
git add enemies/dungeon_guardian.gd
git commit -m "feat: add DungeonGuardianData boss enemy"
git push
```

---

## Task 4: BattleState — ALL_ENEMIES + setup_enemies_for_room

**Files:**
- Modify: `battle/battle_state.gd`
- Modify: `tests/run_tests.gd`

Current `ALL_ENEMIES` (read the file to confirm exact text):
```gdscript
static var ALL_ENEMIES: Dictionary = {
	"Goblin": GoblinScoutData.new(),
	"Orc":    OrcWarriorData.new(),
	"Mage":   DarkMageData.new(),
	"Undead": SkeletonArcherData.new(),
}
```

Current `setup_party()` ends with:
```gdscript
	for p in PLAYERS:
		p["bonus_atk"] = 0
		p["bonus_def"] = 0
```

- [ ] **Step 1: Extend ALL_ENEMIES**

Replace the `ALL_ENEMIES` block with:
```gdscript
static var ALL_ENEMIES: Dictionary = {
	"Goblin":          GoblinScoutData.new(),
	"Orc":             OrcWarriorData.new(),
	"Mage":            DarkMageData.new(),
	"Undead":          SkeletonArcherData.new(),
	"EliteWarrior":    EliteWarriorData.new(),
	"EliteMage":       EliteMageData.new(),
	"DungeonGuardian": DungeonGuardianData.new(),
}
```

- [ ] **Step 2: Add `setup_enemies_for_room()` after `reset_players()`**

Find `static func reset_players() -> void:` and add the new method immediately after its closing brace:

```gdscript
static func setup_enemies_for_room(room_type: int) -> void:
	TURN_QUEUE = TURN_QUEUE.filter(func(e: Dictionary) -> bool:
		return e.get("is_player", false))

	var enemy_keys: Array
	match room_type:
		DungeonState.RoomType.ELITE:
			enemy_keys = ["EliteWarrior", "EliteMage"]
		DungeonState.RoomType.BOSS:
			enemy_keys = ["DungeonGuardian"]
		_:
			enemy_keys = ["Goblin", "Orc", "Mage", "Undead"]

	for key in enemy_keys:
		var edata: EnemyData = ALL_ENEMIES.get(key, null)
		if edata != null:
			TURN_QUEUE.append({
				"name":      edata.enemy_name,
				"is_player": false,
				"type":      edata.enemy_type,
				"ac":        edata.ac,
			})
```

- [ ] **Step 3: Add tests to `tests/run_tests.gd` at end of `_run_all()`**

After the last existing assertions, add:
```gdscript
	# setup_enemies_for_room compositions
	BattleState.setup_party(["Guerreiro"])
	BattleState.setup_enemies_for_room(DungeonState.RoomType.BATTLE)
	var tq_battle: Array = BattleState.TURN_QUEUE.filter(func(e): return not e.get("is_player", false))
	_eq("BATTLE has 4 enemies", tq_battle.size(), 4)

	BattleState.setup_enemies_for_room(DungeonState.RoomType.ELITE)
	var tq_elite: Array = BattleState.TURN_QUEUE.filter(func(e): return not e.get("is_player", false))
	_eq("ELITE has 2 enemies", tq_elite.size(), 2)
	_eq("ELITE first enemy is Elite Warrior", tq_elite[0]["name"], "Elite Warrior")
	_eq("ELITE second enemy is Elite Mage",   tq_elite[1]["name"], "Elite Mage")

	BattleState.setup_enemies_for_room(DungeonState.RoomType.BOSS)
	var tq_boss: Array = BattleState.TURN_QUEUE.filter(func(e): return not e.get("is_player", false))
	_eq("BOSS has 1 enemy", tq_boss.size(), 1)
	_eq("BOSS enemy is Dungeon Guardian", tq_boss[0]["name"], "Dungeon Guardian")

	# Verify new enemy stats in ALL_ENEMIES
	var guardian: EnemyData = BattleState.ALL_ENEMIES.get("DungeonGuardian", null)
	_true("DungeonGuardian registered", guardian != null)
	_eq("DungeonGuardian max_hp is 180", guardian.max_hp, 180)
	_eq("DungeonGuardian has 6 behaviors", guardian.action_behaviors.size(), 6)
```

- [ ] **Step 4: Commit**

```
git add battle/battle_state.gd tests/run_tests.gd
git commit -m "feat: register elite/boss enemies in ALL_ENEMIES and add setup_enemies_for_room"
git push
```

---

## Task 5: BattleScene — room-aware setup and context panel

**Files:**
- Modify: `battle/battle_scene.gd`

Current `_ready()` begins:
```gdscript
func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	_state = BattleState.new()
```

Current `_initialize_state()`:
```gdscript
func _initialize_state() -> void:
	var map_gen  := MapGenerator.new()
	var map_data := map_gen.generate()
	_state.setup(map_data)

	_battle_area.setup(_state)
	_battle_area.set_void_theme(VoidTheme.ThemeType.ABYSS)

	_action_panel.setup(_state)
	_status_panel.setup(_state)
	_log_panel.setup(_state)
	_context_panel.setup("Battle Arena", "Procedural Map", "Explore the terrain.")
```

- [ ] **Step 1: Add `_get_current_room_type()` helper**

Add this method anywhere in the file (after `_initialize_state()` is a good spot):
```gdscript
func _get_current_room_type() -> int:
	if DungeonState.current_run == null:
		return DungeonState.RoomType.BATTLE
	var node: DungeonState.RoomNode = DungeonState.current_run.get_node_by_id(
		DungeonState.current_run.current_node_id)
	if node == null:
		return DungeonState.RoomType.BATTLE
	return node.type
```

- [ ] **Step 2: Call `setup_enemies_for_room` before `BattleState.new()` in `_ready()`**

Replace:
```gdscript
	_state = BattleState.new()
```
With:
```gdscript
	BattleState.setup_enemies_for_room(_get_current_room_type())
	_state = BattleState.new()
```

- [ ] **Step 3: Update `_initialize_state()` context panel**

Replace the hardcoded `_context_panel.setup(...)` line with:
```gdscript
	const ROOM_TITLES: Dictionary = {
		DungeonState.RoomType.BATTLE: "Batalha",
		DungeonState.RoomType.ELITE:  "Batalha Elite",
		DungeonState.RoomType.BOSS:   "CHEFE DO DUNGEON",
	}
	var rtype := _get_current_room_type()
	var floor_lbl := "Dungeon"
	if DungeonState.current_run != null:
		var _node := DungeonState.current_run.get_node_by_id(
			DungeonState.current_run.current_node_id)
		if _node != null:
			floor_lbl = "Boss" if _node.floor == DungeonState.FLOOR_COUNT - 1 \
				else "Andar %d" % (_node.floor + 1)
	_context_panel.setup(
		ROOM_TITLES.get(rtype, "Batalha"),
		floor_lbl,
		"Prepare-se para o combate.")
```

- [ ] **Step 4: Commit**

```
git add battle/battle_scene.gd
git commit -m "feat: room-aware enemy setup and context panel in BattleScene"
git push
```

---

## Self-Review

- [x] `setup_enemies_for_room()` uses `TURN_QUEUE.filter()` which returns a new `Array` — assigned back to `TURN_QUEUE`. GDScript 4 `Array.filter()` returns `Array` (untyped), compatible with `static var TURN_QUEUE: Array`. ✓
- [x] Called BEFORE `BattleState.new()` so `_init()` reads the correct TURN_QUEUE. ✓
- [x] `enemy_hp` in `_init()` uses `entry.get("type", "")` → looks up in `ALL_ENEMIES` by type key (e.g. "EliteWarrior") → finds `EliteWarriorData` → reads `max_hp = 70`. ✓
- [x] `_get_current_room_type()` defined before it's called in `_ready()` — GDScript resolves method calls at runtime, order doesn't matter. ✓
- [x] AOE action_pool strings for Sweep and Shockwave have no `%s` — avoids String.format() crash when AOE has no single target. ✓
- [x] `const ROOM_TITLES` inside a func is valid GDScript 4. ✓
- [x] Tests use `setup_party(["Guerreiro"])` to ensure players are in TURN_QUEUE before `setup_enemies_for_room()` filters. ✓
- [x] Task order: enemy data files (1-3) → BattleState (4) → BattleScene (5) — each can compile independently. ✓
