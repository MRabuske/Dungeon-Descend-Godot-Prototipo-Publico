# Mystery Rooms Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement MYSTERY room type as a randomised outcome that reuses EventScene, with four deterministic outcomes per node: event (40%), treasure (30%), battle surprise (20%), curse (10%).

**Architecture:** A new `MysteryRegistry` resolves outcomes by seeded RNG from the node_id. `EventData.ConsequenceType` gains a `GO_TO_BATTLE` value handled in EventScene by skipping `complete_current_room()` and routing to battle. EventScene detects MYSTERY rooms and calls `MysteryRegistry.resolve()`. Dungeon map routes MYSTERY the same as EVENT.

**Tech Stack:** GDScript 4.6, Godot 4.6, code-only (no active editor). Branch: `feature/mystery-rooms`.

---

## File Map

| File | Status | Change |
|------|--------|--------|
| `dungeon/event_data.gd` | Modify | Add `GO_TO_BATTLE = 8` to `ConsequenceType` enum; update comment |
| `dungeon/mystery_registry.gd` | Create | `MysteryRegistry` class with `resolve()` + 4 outcome builders |
| `ui/event_scene.gd` | Modify | `_go_to_battle` flag; MYSTERY detection in `_ready()`; `GO_TO_BATTLE` in `_apply_one`; flag check in `_on_choice` |
| `ui/dungeon_map.gd` | Modify | Add `MYSTERY` to routing match alongside `EVENT` |
| `tests/run_tests.gd` | Modify | Assertions for `MysteryRegistry.resolve()` determinism and outcome coverage |

---

## Task 1: Add GO_TO_BATTLE to ConsequenceType

**Files:**
- Modify: `dungeon/event_data.gd`

The `ConsequenceType` enum currently ends at `REVEAL_CONNECTIONS = 7`. The comment block above it lists valid target strings for `BUFF_NEXT_BATTLE`.

- [ ] **Step 1: Add GO_TO_BATTLE to the enum**

Locate the enum block:
```gdscript
enum ConsequenceType {
	NOTHING           = 0,
	HEAL_PARTY        = 1,
	DAMAGE_PARTY      = 2,
	HEAL_TARGET       = 3,
	DAMAGE_TARGET     = 4,
	MP_RESTORE_PARTY  = 5,
	BUFF_NEXT_BATTLE  = 6,
	REVEAL_CONNECTIONS = 7,
}
```

Replace with:
```gdscript
enum ConsequenceType {
	NOTHING            = 0,
	HEAL_PARTY         = 1,
	DAMAGE_PARTY       = 2,
	HEAL_TARGET        = 3,
	DAMAGE_TARGET      = 4,
	MP_RESTORE_PARTY   = 5,
	BUFF_NEXT_BATTLE   = 6,
	REVEAL_CONNECTIONS = 7,
	GO_TO_BATTLE       = 8,
}
```

Also update the comment above the enum to document the new value:
```gdscript
# target semantics per consequence_type:
#   HEAL/DAMAGE_TARGET  → "random_hero" | "weakest_hero"
#   BUFF_NEXT_BATTLE    → "ATK_UP" | "DEF_UP"  (negative value = debuff)
#   GO_TO_BATTLE        → "none"  (routes to battle scene, skips complete_current_room)
#   everything else     → "party" | "none"
```

- [ ] **Step 2: Commit**

```
git add dungeon/event_data.gd
git commit -m "feat: add GO_TO_BATTLE to ConsequenceType enum"
git push
```

---

## Task 2: MysteryRegistry

**Files:**
- Create: `dungeon/mystery_registry.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Create `dungeon/mystery_registry.gd`**

```gdscript
class_name MysteryRegistry

# Outcome weights (out of 100):
#   0–39  → random event from EventData.REGISTRY  (40%)
#   40–69 → treasure (heal + MP restore)           (30%)
#   70–89 → battle surprise                        (20%)
#   90–99 → curse (damage + ATK debuff)            (10%)

static func resolve(node_id: int) -> EventData:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(node_id) * 31337 + 42
	var roll: int = rng.randi() % 100
	if roll < 40:
		return _random_event(rng)
	elif roll < 70:
		return _treasure_event()
	elif roll < 90:
		return _battle_event()
	else:
		return _curse_event()

static func _random_event(rng: RandomNumberGenerator) -> EventData:
	var keys: Array = EventData.REGISTRY.keys()
	var key: String = keys[rng.randi() % keys.size()]
	return EventData.REGISTRY[key]

static func _treasure_event() -> EventData:
	var C := EventData.ConsequenceType
	return EventData.new("mystery_treasure", "Tesouro Escondido",
		"Atrás de uma parede falsa, vocês encontram provisões escondidas.",
		[
			EventData.EventChoice.new("Pegar",
				C.HEAL_PARTY, 40, "party",
				"A party recolhe as provisões. Todos curam 40 HP.",
				C.MP_RESTORE_PARTY, 30, "party",
				"Todos recuperam 30 MP."),
		])

static func _battle_event() -> EventData:
	var C := EventData.ConsequenceType
	return EventData.new("mystery_battle", "Encontro Inesperado!",
		"Uma criatura surge das sombras. Não há tempo para negociar.",
		[
			EventData.EventChoice.new("Entrar em Combate",
				C.GO_TO_BATTLE, 0, "none",
				""),
		])

static func _curse_event() -> EventData:
	var C := EventData.ConsequenceType
	return EventData.new("mystery_curse", "Armadilha Arcana",
		"Uma armadilha mágica dispara ao pisarem na sala. Energia negativa envolve a party.",
		[
			EventData.EventChoice.new("Aceitar o destino",
				C.DAMAGE_PARTY, 20, "party",
				"A armadilha debilita a party. Todos perdem 20 HP.",
				C.BUFF_NEXT_BATTLE, -5, "ATK_UP",
				"ATK -5 na próxima batalha."),
		])
```

- [ ] **Step 2: Add tests to `tests/run_tests.gd` inside `_run_all()`**

Add at the end of `_run_all()`, after the existing EventData assertions:

```gdscript
	# MysteryRegistry — determinism and outcome coverage
	var m0: EventData = MysteryRegistry.resolve(0)
	_true("MysteryRegistry returns non-null for node 0",  m0 != null)
	_true("MysteryRegistry is deterministic",
		MysteryRegistry.resolve(7).id == MysteryRegistry.resolve(7).id)
	# Verify each outcome is reachable by testing known node_ids
	# resolve(0): seed=42,  roll=randi()%100 — find a node that gives each outcome
	# (we test the 4 known ids that the registry produces)
	var ids_seen: Dictionary = {}
	for test_id in range(200):
		var ev: EventData = MysteryRegistry.resolve(test_id)
		ids_seen[ev.id] = true
	_true("mystery_treasure reachable", ids_seen.has("mystery_treasure"))
	_true("mystery_battle reachable",   ids_seen.has("mystery_battle"))
	_true("mystery_curse reachable",    ids_seen.has("mystery_curse"))
	# Verify battle event uses GO_TO_BATTLE
	var battle_ev: EventData = EventData.new("t", "t", "t",
		[EventData.EventChoice.new("t", EventData.ConsequenceType.GO_TO_BATTLE, 0, "none", "")])
	_eq("GO_TO_BATTLE enum value is 8",
		EventData.ConsequenceType.GO_TO_BATTLE, 8)
	_eq("battle choice has GO_TO_BATTLE",
		(battle_ev.choices[0] as EventData.EventChoice).consequence_type,
		EventData.ConsequenceType.GO_TO_BATTLE)
```

- [ ] **Step 3: Commit**

```
git add dungeon/mystery_registry.gd tests/run_tests.gd
git commit -m "feat: add MysteryRegistry with 4 deterministic outcomes"
git push
```

---

## Task 3: EventScene — GO_TO_BATTLE handling and MYSTERY detection

**Files:**
- Modify: `ui/event_scene.gd`

Current `_ready()` (lines 13–22):
```gdscript
func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	var node_id: int = -1
	if DungeonState.current_run != null:
		node_id = DungeonState.current_run.current_node_id
	_event = EventData.get_for_node(node_id)
	if _event == null:
		_finish()
		return
	_build_ui()
```

Current `_on_choice()` ending (the last 5 lines):
```gdscript
	for btn in _choice_buttons:
		btn.visible = false
	_result_lbl.text = result
	_result_lbl.visible = true
	_continue_btn.visible = true
```

Current `_apply_one()` last branch before `return ""`:
```gdscript
		C.REVEAL_CONNECTIONS:
			if DungeonState.current_run != null:
				DungeonState.current_run.reveal_extra_connections(
					DungeonState.current_run.current_node_id)
	return ""
```

- [ ] **Step 1: Add `_go_to_battle` field to the class vars block**

The current class vars are:
```gdscript
var _event: EventData
var _choice_buttons: Array = []
var _result_lbl: Label
var _continue_btn: Button
```

Replace with:
```gdscript
var _event: EventData
var _choice_buttons: Array = []
var _result_lbl: Label
var _continue_btn: Button
var _go_to_battle: bool = false
```

- [ ] **Step 2: Update `_ready()` to detect MYSTERY rooms**

Replace the current `_ready()` with:
```gdscript
func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	var node_id: int = -1
	if DungeonState.current_run != null:
		node_id = DungeonState.current_run.current_node_id

	var node: DungeonState.RoomNode = null
	if DungeonState.current_run != null:
		node = DungeonState.current_run.get_node_by_id(node_id)

	if node != null and node.type == DungeonState.RoomType.MYSTERY:
		_event = MysteryRegistry.resolve(node_id)
	else:
		_event = EventData.get_for_node(node_id)

	if _event == null:
		_finish()
		return
	_build_ui()
```

- [ ] **Step 3: Add `GO_TO_BATTLE` branch to `_apply_one()`**

Replace the last branch + return in `_apply_one()`:
```gdscript
		C.REVEAL_CONNECTIONS:
			if DungeonState.current_run != null:
				DungeonState.current_run.reveal_extra_connections(
					DungeonState.current_run.current_node_id)
	return ""
```

With:
```gdscript
		C.REVEAL_CONNECTIONS:
			if DungeonState.current_run != null:
				DungeonState.current_run.reveal_extra_connections(
					DungeonState.current_run.current_node_id)
		C.GO_TO_BATTLE:
			_go_to_battle = true
	return ""
```

- [ ] **Step 4: Add `_go_to_battle` flag check in `_on_choice()`**

Replace the last 5 lines of `_on_choice()`:
```gdscript
	for btn in _choice_buttons:
		btn.visible = false
	_result_lbl.text = result
	_result_lbl.visible = true
	_continue_btn.visible = true
```

With:
```gdscript
	if _go_to_battle:
		SceneTransition.fade_to("res://battle/battle_scene.tscn")
		return

	for btn in _choice_buttons:
		btn.visible = false
	_result_lbl.text = result
	_result_lbl.visible = true
	_continue_btn.visible = true
```

- [ ] **Step 5: Commit**

```
git add ui/event_scene.gd
git commit -m "feat: MYSTERY detection and GO_TO_BATTLE handling in EventScene"
git push
```

---

## Task 4: dungeon_map routing for MYSTERY

**Files:**
- Modify: `ui/dungeon_map.gd`

Current routing match in `_on_enter_room()`:
```gdscript
	match node.type:
		DungeonState.RoomType.EVENT:
			SceneTransition.fade_to("res://ui/event_scene.tscn")
		_:
			SceneTransition.fade_to("res://battle/battle_scene.tscn")
```

- [ ] **Step 1: Add MYSTERY to the match**

Replace the match block with:
```gdscript
	match node.type:
		DungeonState.RoomType.EVENT, DungeonState.RoomType.MYSTERY:
			SceneTransition.fade_to("res://ui/event_scene.tscn")
		_:
			SceneTransition.fade_to("res://battle/battle_scene.tscn")
```

- [ ] **Step 2: Commit**

```
git add ui/dungeon_map.gd
git commit -m "feat: route MYSTERY rooms to event_scene"
git push
```

---

## Self-Review

- [x] GO_TO_BATTLE = 8 is one above REVEAL_CONNECTIONS = 7 — no collision
- [x] `_build_registry()` assert on consequence_type will accept 8 (GO_TO_BATTLE) since it's in the enum values
- [x] `_go_to_battle` flag is checked AFTER `_apply_one` runs but BEFORE result display — correct order
- [x] Battle surprise bypasses `complete_current_room()` — battle scene calls it on win via `_on_continue_requested()`
- [x] Curse uses `BUFF_NEXT_BATTLE value=-5 target="ATK_UP"` — existing `setup()` code does `p["bonus_atk"] += bval` which handles negative values correctly; `_roll_player_damage` adds `bonus_atk` which subtracts when negative
- [x] `MysteryRegistry._random_event()` uses a seeded rng passed from `resolve()` — same seed → same event selection
- [x] Tests verify all 3 named outcomes are reachable across 200 node_ids (event outcome has no fixed id so untestable by id — covered implicitly)
- [x] Task order: ConsequenceType → Registry → EventScene → dungeon_map — each task compiles independently
