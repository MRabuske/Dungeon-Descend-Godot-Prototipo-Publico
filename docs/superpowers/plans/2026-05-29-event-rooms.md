# Event Rooms Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement EVENT room type as a dedicated text-choice scene with mechanical consequences (HP/MP, buffs) and map effects (reveal connections).

**Architecture:** New `EventData` Resource + `EventRegistry` (follows existing ActionData/HeroData pattern). New `EventScene` dedicated screen. `DungeonState` gains `pending_buffs` and `reveal_extra_connections`. `BattleState` consumes buffs at battle start and wires `bonus_atk`/`bonus_def` into damage. `dungeon_map` routes EVENT rooms to the new scene.

**Tech Stack:** GDScript 4.6, Godot 4.6, code-only (no scene editor active).

---

## File Map

| File | Status | Responsibility |
|------|--------|----------------|
| `dungeon/event_data.gd` | **Create** | EventChoice class, EventData resource, EventRegistry with 6 events, `get_for_node()` |
| `ui/event_scene.gd` | **Create** | Full event screen: display, choice handling, consequence application, navigation |
| `ui/event_scene.tscn` | **Create** | Minimal scene file registering the script |
| `dungeon/dungeon_state.gd` | **Modify** | Add `pending_buffs`, update save/load, add `reveal_extra_connections()` |
| `battle/battle_state.gd` | **Modify** | Add `bonus_atk`/`bonus_def` to PLAYERS, consume `pending_buffs` in `setup()`, wire into damage calc |
| `ui/dungeon_map.gd` | **Modify** | Route EVENT rooms to `event_scene.tscn` instead of `battle_scene.tscn` |
| `tests/run_tests.gd` | **Modify** | Add assertions for EventData registry |

---

## Task 1: EventData resource and registry

**Files:**
- Create: `dungeon/event_data.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Create `dungeon/event_data.gd` with the complete implementation**

```gdscript
class_name EventData
extends Resource

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

# ── EventChoice ───────────────────────────────────────────────────────────────
# target semantics per consequence_type:
#   HEAL/DAMAGE_TARGET  → "random_hero" | "weakest_hero"
#   BUFF_NEXT_BATTLE    → "ATK_UP" | "DEF_UP"
#   everything else     → "party" | "none"
#
# is_random = true  → 50/50 between primary and secondary (mutually exclusive)
# is_random = false → primary always; secondary also applied if secondary_type != NOTHING
class EventChoice:
	var label: String
	var consequence_type: int
	var value: int
	var target: String
	var result_text: String
	var secondary_type: int    = ConsequenceType.NOTHING
	var secondary_value: int   = 0
	var secondary_target: String = "none"
	var secondary_text: String = ""
	var is_random: bool        = false

	func _init(
			l: String, ct: int, v: int, tgt: String, rt: String,
			sec_t: int = 0, sec_v: int = 0, sec_tgt: String = "none",
			sec_rt: String = "", rand: bool = false) -> void:
		label = l; consequence_type = ct; value = v; target = tgt; result_text = rt
		secondary_type = sec_t; secondary_value = sec_v; secondary_target = sec_tgt
		secondary_text = sec_rt; is_random = rand

# ── EventData ─────────────────────────────────────────────────────────────────
var id: String          = ""
var title: String       = ""
var description: String = ""
var choices: Array      = []   # Array[EventChoice]

func _init(p_id: String, p_title: String, p_desc: String, p_choices: Array) -> void:
	id = p_id; title = p_title; description = p_desc; choices = p_choices

# ── Registry ──────────────────────────────────────────────────────────────────
static var REGISTRY: Dictionary = {}

static func _static_init() -> void:
	_build_registry()

static func get_for_node(node_id: int) -> EventData:
	if REGISTRY.is_empty():
		_build_registry()
	var keys: Array = REGISTRY.keys()
	return REGISTRY[keys[abs(node_id) % keys.size()]]

static func _build_registry() -> void:
	var C := ConsequenceType
	var events: Array = [
		# ── 1. Fonte Arcana ──────────────────────────────────────────────────
		EventData.new("arcane_fountain", "Fonte Arcana",
			"Água cristalina e brilhante pulsa numa fonte no corredor.",
			[
				EventChoice.new("Beber",
					C.MP_RESTORE_PARTY, 25, "party",
					"A party absorve a energia. Todos recuperam 25 MP."),
				EventChoice.new("Examinar",
					C.NOTHING, 0, "none",
					"A fonte parece inofensiva. A party segue em frente."),
			]),

		# ── 2. Altar Maldito ─────────────────────────────────────────────────
		EventData.new("cursed_altar", "Altar Maldito",
			"Runas sombrias pulsam num altar antigo. A energia é palpável.",
			[
				EventChoice.new("Ativar o Altar",
					C.BUFF_NEXT_BATTLE, 10, "ATK_UP",
					"O altar concede poder! ATK +10 na próxima batalha.",
					C.DAMAGE_TARGET, 25, "random_hero",
					"O altar reage violentamente, ferindo um herói!", true),
				EventChoice.new("Destruir",
					C.DAMAGE_PARTY, 10, "party",
					"O altar explode. A party sofre 10 de dano mas ganha DEF +8.",
					C.BUFF_NEXT_BATTLE, 8, "DEF_UP"),
				EventChoice.new("Ignorar",
					C.NOTHING, 0, "none",
					"A party segue em frente, prudentemente."),
			]),

		# ── 3. Prisioneiro ───────────────────────────────────────────────────
		EventData.new("prisoner", "Prisioneiro",
			"Um aventureiro agoniza preso numa gaiola enferrujada.",
			[
				EventChoice.new("Libertar",
					C.REVEAL_CONNECTIONS, 0, "none",
					"Grato, o aventureiro revela rotas secretas no próximo andar."),
				EventChoice.new("Ignorar",
					C.NOTHING, 0, "none",
					"A party deixa o prisioneiro para trás."),
			]),

		# ── 4. Baú Armadilhado ───────────────────────────────────────────────
		EventData.new("trapped_chest", "Baú Armadilhado",
			"Um baú reluzente no centro da sala. Claramente armadilhado.",
			[
				EventChoice.new("Abrir com Cuidado",
					C.HEAL_PARTY, 20, "party",
					"A party encontra poções. Todos curam 20 HP."),
				EventChoice.new("Arrombar",
					C.HEAL_PARTY, 35, "party",
					"A armadilha dispara! A party cura 35 HP, mas um herói leva 30 de dano.",
					C.DAMAGE_TARGET, 30, "random_hero"),
			]),

		# ── 5. Ritual Interrompido ───────────────────────────────────────────
		EventData.new("ritual", "Ritual Interrompido",
			"Energia residual de um ritual recente flutua no ar.",
			[
				EventChoice.new("Absorver a Energia",
					C.MP_RESTORE_PARTY, 40, "party",
					"A energia restaura o fôlego arcano. Todos recuperam 40 MP.",
					C.DAMAGE_PARTY, 15, "party",
					"A energia instável corrói a party. Todos perdem 15 HP.", true),
				EventChoice.new("Purificar",
					C.NOTHING, 0, "none",
					"A energia é dissipada com segurança. Sem efeitos."),
			]),

		# ── 6. Fogueira ──────────────────────────────────────────────────────
		EventData.new("campfire", "Fogueira",
			"Uma fogueira crepita num recanto protegido. Um raro momento de descanso.",
			[
				EventChoice.new("Descansar",
					C.HEAL_PARTY, 30, "party",
					"A party descansa junto à fogueira. Todos curam 30 HP e recuperam 25 MP.",
					C.MP_RESTORE_PARTY, 25, "party"),
				EventChoice.new("Manter Guarda",
					C.HEAL_TARGET, 60, "weakest_hero",
					"O herói mais fraco descansa enquanto os outros vigiam. Recupera 60 HP."),
			]),
	]
	for e: EventData in events:
		REGISTRY[e.id] = e
```

- [ ] **Step 2: Add tests to `tests/run_tests.gd` inside `_run_all()`**

Add at the end of `_run_all()`, before `quit()`:

```gdscript
# EventData registry
_eq("EventData registry has 6 events", EventData.REGISTRY.size(), 6)
_true("arcane_fountain exists", EventData.REGISTRY.has("arcane_fountain"))
_true("campfire exists",        EventData.REGISTRY.has("campfire"))
var ef: EventData = EventData.get_for_node(0)
_true("get_for_node returns non-null", ef != null)
_true("get_for_node is deterministic",
	EventData.get_for_node(7).id == EventData.get_for_node(7).id)
var altar: EventData = EventData.REGISTRY["cursed_altar"]
_eq("cursed_altar has 3 choices", altar.choices.size(), 3)
var ativar: EventData.EventChoice = altar.choices[0]
_true("Ativar is_random", ativar.is_random)
_eq("Ativar primary is BUFF_NEXT_BATTLE",
	ativar.consequence_type, EventData.ConsequenceType.BUFF_NEXT_BATTLE)
_eq("Ativar secondary is DAMAGE_TARGET",
	ativar.secondary_type, EventData.ConsequenceType.DAMAGE_TARGET)
```

- [ ] **Step 3: Commit**

```
git add dungeon/event_data.gd tests/run_tests.gd
git commit -m "feat: add EventData resource and registry with 6 events"
git push
```

---

## Task 2: DungeonState — pending_buffs + reveal_extra_connections

**Files:**
- Modify: `dungeon/dungeon_state.gd`

Current state of relevant sections (lines 22–27):
```gdscript
var nodes: Array = []
var current_node_id: int = -1
var run_seed: int = 0
var pending_room: bool = false
var party_names: Array = []
```

Current `save()` data dict (line 171):
```gdscript
var data: Dictionary = {
    "run_seed": run_seed,
    "current_node_id": current_node_id,
    "pending_room": pending_room,
    "party_names": party_names.duplicate(),
    "nodes": []
}
```

Current `load_save()` restore section (lines 209–213):
```gdscript
state.run_seed = int(data.get("run_seed", 0))
state.current_node_id = int(data.get("current_node_id", -1))
state.pending_room = bool(data.get("pending_room", false))
for pn in data.get("party_names", []):
    state.party_names.append(str(pn))
```

- [ ] **Step 1: Add `pending_buffs` field after `party_names`**

```gdscript
var party_names: Array = []
var pending_buffs: Array = []   # ← add this line
```

- [ ] **Step 2: Update `save()` — add pending_buffs to the data dict**

Replace:
```gdscript
var data: Dictionary = {
    "run_seed": run_seed,
    "current_node_id": current_node_id,
    "pending_room": pending_room,
    "party_names": party_names.duplicate(),
    "nodes": []
}
```
With:
```gdscript
var data: Dictionary = {
    "run_seed": run_seed,
    "current_node_id": current_node_id,
    "pending_room": pending_room,
    "party_names": party_names.duplicate(),
    "pending_buffs": pending_buffs.duplicate(),
    "nodes": []
}
```

- [ ] **Step 3: Update `load_save()` — restore pending_buffs**

After the `party_names` loop, add:
```gdscript
for pn in data.get("party_names", []):
    state.party_names.append(str(pn))
for buff in data.get("pending_buffs", []):   # ← add these 3 lines
    if buff is Dictionary:
        state.pending_buffs.append(buff)
```

- [ ] **Step 4: Add `reveal_extra_connections()` at the end of the file, before `delete_save()`**

```gdscript
func reveal_extra_connections(from_node_id: int) -> void:
    var from_node: RoomNode = get_node_by_id(from_node_id)
    if from_node == null:
        return
    var next_floor: int = from_node.floor + 1
    if next_floor >= FLOOR_COUNT:
        return
    var next_nodes: Array = []
    for n: RoomNode in nodes:
        if n.floor == next_floor and not n.completed:
            next_nodes.append(n)
    if next_nodes.is_empty():
        return
    var candidates: Array = next_nodes.filter(func(n: RoomNode) -> bool:
        return not from_node.connections.has(n.id))
    if candidates.is_empty():
        return
    var target: RoomNode = candidates[randi() % candidates.size()]
    from_node.connections.append(target.id)
    save()
```

- [ ] **Step 5: Commit**

```
git add dungeon/dungeon_state.gd
git commit -m "feat: add pending_buffs and reveal_extra_connections to DungeonState"
git push
```

---

## Task 3: BattleState — bonus_atk/bonus_def

**Files:**
- Modify: `battle/battle_state.gd`

- [ ] **Step 1: Initialize `bonus_atk` and `bonus_def` in `setup_party()`**

Current `setup_party()` ends at line 82. After the two `for` loops that build `PLAYERS` and `TURN_QUEUE`, add:

```gdscript
static func setup_party(hero_names: Array) -> void:
    PLAYERS = []
    TURN_QUEUE = []
    for hname in hero_names:
        var hero: HeroData = ALL_HERO_DATA.get(hname)
        if hero != null:
            PLAYERS.append(hero.to_combat_dict())
            TURN_QUEUE.append({"name": hname, "is_player": true})
    for edata: EnemyData in ALL_ENEMIES.values():
        TURN_QUEUE.append({
            "name": edata.enemy_name,
            "is_player": false,
            "type": edata.enemy_type,
            "ac": edata.ac,
        })
    for p in PLAYERS:            # ← add these two lines
        p["bonus_atk"] = 0
        p["bonus_def"] = 0
```

- [ ] **Step 2: Consume `pending_buffs` inside `setup()`**

Current `setup()` at line 162 ends around line 210. Add at the very end of `setup()`, after all existing code:

```gdscript
    # Apply and consume pending buffs from the dungeon run
    if DungeonState.current_run != null and \
            not DungeonState.current_run.pending_buffs.is_empty():
        for buff in DungeonState.current_run.pending_buffs:
            var btype: String = buff.get("type", "")
            var bval: int     = buff.get("value", 0)
            for p in PLAYERS:
                match btype:
                    "ATK_UP": p["bonus_atk"] = p.get("bonus_atk", 0) + bval
                    "DEF_UP": p["bonus_def"] = p.get("bonus_def", 0) + bval
        DungeonState.current_run.pending_buffs.clear()
        DungeonState.current_run.save()
```

- [ ] **Step 3: Wire `bonus_atk` into `_roll_player_damage()`**

Current function (line 1052):
```gdscript
func _roll_player_damage() -> int:
    var pidx := get_active_player_index()
    var prof: int = PLAYERS[pidx]["proficiency"] if pidx >= 0 else 2
    var modifier := _get_attr_modifier(current_damage_attribute)
    return randi_range(current_base_dmg_min, current_base_dmg_max) + modifier + prof
```

Replace with:
```gdscript
func _roll_player_damage() -> int:
    var pidx := get_active_player_index()
    var prof: int  = PLAYERS[pidx]["proficiency"] if pidx >= 0 else 2
    var bonus: int = PLAYERS[pidx].get("bonus_atk", 0) if pidx >= 0 else 0
    var modifier   := _get_attr_modifier(current_damage_attribute)
    return randi_range(current_base_dmg_min, current_base_dmg_max) + modifier + prof + bonus
```

- [ ] **Step 4: Wire `bonus_def` into `apply_enemy_attack()` after existing damage_reduction**

Locate this block (around line 756):
```gdscript
    if pidx >= 0:
        var tdata := ALL_HERO_DATA.get(target_name, null) as HeroData
        if tdata != null and tdata.damage_reduction > 0:
            var reduction: int = 2 if combatant_statuses[target_idx].get("fury", 0) > 0 else tdata.damage_reduction
            damage = maxi(1, damage - reduction)
    battle_stats["enemy_damage_dealt"] = ...
```

Replace that `if pidx >= 0` block with:
```gdscript
    if pidx >= 0:
        var tdata := ALL_HERO_DATA.get(target_name, null) as HeroData
        if tdata != null and tdata.damage_reduction > 0:
            var reduction: int = 2 if combatant_statuses[target_idx].get("fury", 0) > 0 else tdata.damage_reduction
            damage = maxi(1, damage - reduction)
        var def_bonus: int = PLAYERS[pidx].get("bonus_def", 0)
        if def_bonus > 0:
            damage = maxi(1, damage - def_bonus)
```

- [ ] **Step 5: Commit**

```
git add battle/battle_state.gd
git commit -m "feat: bonus_atk/bonus_def fields in PLAYERS, consumed from pending_buffs on battle start"
git push
```

---

## Task 4: EventScene — tscn + gd

**Files:**
- Create: `ui/event_scene.tscn`
- Create: `ui/event_scene.gd`

- [ ] **Step 1: Create `ui/event_scene.tscn`**

```
[gd_scene format=3 uid="uid://dv3xnp8a9m4e7"]

[ext_resource type="Script" uid="uid://bv5n2kq8m1d9x" path="res://ui/event_scene.gd" id="1"]

[node name="EventScene" type="Control"]
script = ExtResource("1")
```

- [ ] **Step 2: Create `ui/event_scene.gd`**

```gdscript
class_name EventScene
extends Control

const BG_COLOR    := Color(0.04, 0.05, 0.09)
const TITLE_COLOR := Color(0.90, 0.78, 0.20)

var _event: EventData
var _choice_buttons: Array = []
var _result_lbl: Label
var _continue_btn: Button

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

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COLOR
	add_child(bg)

	var center := VBoxContainer.new()
	center.anchor_left   = 0.5
	center.anchor_right  = 0.5
	center.anchor_top    = 0.5
	center.anchor_bottom = 0.5
	center.offset_left   = -320
	center.offset_right  =  320
	center.offset_top    = -280
	center.offset_bottom =  280
	center.add_theme_constant_override("separation", 16)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	var title := Label.new()
	title.text = _event.title
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(title)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.22, 0.22, 0.30))
	center.add_child(sep)

	var desc := Label.new()
	desc.text = _event.description
	desc.add_theme_font_size_override("font_size", 11)
	desc.add_theme_color_override("font_color", Color(0.78, 0.78, 0.88))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	center.add_child(desc)

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.22, 0.22, 0.30))
	center.add_child(sep2)

	for choice: EventData.EventChoice in _event.choices:
		var btn := _make_button(choice.label)
		var c := choice
		btn.pressed.connect(func() -> void: _on_choice(c))
		_choice_buttons.append(btn)
		center.add_child(btn)

	_result_lbl = Label.new()
	_result_lbl.add_theme_font_size_override("font_size", 11)
	_result_lbl.add_theme_color_override("font_color", Color(0.70, 0.92, 0.70))
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_lbl.visible = false
	center.add_child(_result_lbl)

	_continue_btn = _make_button("Continuar")
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_finish)
	center.add_child(_continue_btn)

func _on_choice(choice: EventData.EventChoice) -> void:
	var result: String
	if choice.is_random:
		if randi() % 2 == 0:
			var extra := _apply_one(choice.consequence_type, choice.value, choice.target)
			result = choice.result_text + (" " + extra if extra != "" else "")
		else:
			var extra := _apply_one(choice.secondary_type, choice.secondary_value, choice.secondary_target)
			result = choice.secondary_text + (" " + extra if extra != "" else "")
	else:
		_apply_one(choice.consequence_type, choice.value, choice.target)
		if choice.secondary_type != EventData.ConsequenceType.NOTHING:
			var extra := _apply_one(choice.secondary_type, choice.secondary_value, choice.secondary_target)
			result = choice.result_text + (" " + extra if extra != "" else "")
		else:
			result = choice.result_text

	for btn in _choice_buttons:
		btn.visible = false
	_result_lbl.text = result
	_result_lbl.visible = true
	_continue_btn.visible = true

# Returns dynamic info string (hero name for TARGET consequences, else "").
func _apply_one(ctype: int, value: int, target: String) -> String:
	var C := EventData.ConsequenceType
	match ctype:
		C.HEAL_PARTY:
			for p in BattleState.PLAYERS:
				p["hp"] = mini(p["max_hp"], p["hp"] + value)
		C.DAMAGE_PARTY:
			for p in BattleState.PLAYERS:
				p["hp"] = maxi(1, p["hp"] - value)
		C.HEAL_TARGET:
			var pidx := _resolve_target(target)
			if pidx >= 0:
				var p: Dictionary = BattleState.PLAYERS[pidx]
				p["hp"] = mini(p["max_hp"], p["hp"] + value)
				return "(%s +%dHP)" % [p["name"], value]
		C.DAMAGE_TARGET:
			var pidx := _resolve_target(target)
			if pidx >= 0:
				var p: Dictionary = BattleState.PLAYERS[pidx]
				p["hp"] = maxi(1, p["hp"] - value)
				return "(%s -%dHP)" % [p["name"], value]
		C.MP_RESTORE_PARTY:
			for p in BattleState.PLAYERS:
				p["mp"] = mini(p["max_mp"], p["mp"] + value)
		C.BUFF_NEXT_BATTLE:
			if DungeonState.current_run != null:
				DungeonState.current_run.pending_buffs.append({"type": target, "value": value})
		C.REVEAL_CONNECTIONS:
			if DungeonState.current_run != null:
				DungeonState.current_run.reveal_extra_connections(
					DungeonState.current_run.current_node_id)
	return ""

func _resolve_target(target: String) -> int:
	if BattleState.PLAYERS.is_empty():
		return -1
	if target == "random_hero":
		return randi() % BattleState.PLAYERS.size()
	if target == "weakest_hero":
		var min_hp := 999999
		var idx    := 0
		for i in range(BattleState.PLAYERS.size()):
			if BattleState.PLAYERS[i]["hp"] < min_hp:
				min_hp = BattleState.PLAYERS[i]["hp"]
				idx = i
		return idx
	return -1

func _finish() -> void:
	if DungeonState.current_run != null:
		DungeonState.current_run.complete_current_room()
	SceneTransition.fade_to("res://ui/dungeon_map.tscn")

func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(400, 46)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var sn := StyleBoxFlat.new()
	sn.bg_color = Color(0.12, 0.16, 0.28)
	sn.corner_radius_top_left     = 5
	sn.corner_radius_top_right    = 5
	sn.corner_radius_bottom_left  = 5
	sn.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("normal", sn)

	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.18, 0.24, 0.42)
	btn.add_theme_stylebox_override("hover", sh)

	var sp := sn.duplicate() as StyleBoxFlat
	sp.bg_color = Color(0.08, 0.12, 0.20)
	btn.add_theme_stylebox_override("pressed", sp)

	return btn
```

- [ ] **Step 3: Commit**

```
git add ui/event_scene.tscn ui/event_scene.gd
git commit -m "feat: add EventScene dedicated screen for EVENT rooms"
git push
```

---

## Task 5: dungeon_map — route EVENT rooms to EventScene

**Files:**
- Modify: `ui/dungeon_map.gd`

- [ ] **Step 1: Update `_on_enter_room()` to route by room type**

Locate `_on_enter_room()`. Current last lines:
```gdscript
    _state.enter_room(_selected_node_id)
    SceneTransition.fade_to("res://battle/battle_scene.tscn")
```

Replace those two lines with:
```gdscript
    _state.enter_room(_selected_node_id)
    match node.type:
        DungeonState.RoomType.EVENT:
            SceneTransition.fade_to("res://ui/event_scene.tscn")
        _:
            SceneTransition.fade_to("res://battle/battle_scene.tscn")
```

- [ ] **Step 2: Commit**

```
git add ui/dungeon_map.gd
git commit -m "feat: route EVENT rooms to event_scene instead of battle"
git push
```

---

## Self-Review Checklist (already verified)

- [x] All 6 events implemented with choices and result texts
- [x] All ConsequenceType values handled in `_apply_one()`
- [x] `pending_buffs` persisted in save/load
- [x] `bonus_atk`/`bonus_def` initialized to 0 in `setup_party()` so existing battles are unaffected
- [x] `reveal_extra_connections()` guards against last floor (boss)
- [x] `get_for_node()` has empty-registry fallback
- [x] `_apply_one()` for BUFF_NEXT_BATTLE returns `""` (no dynamic text needed, `result_text` covers it)
- [x] Tasks are independent and can be committed separately
