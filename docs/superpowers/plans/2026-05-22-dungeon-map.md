# Dungeon Map Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar o Mapa do Dungeon roguelike com grafo visual de salas, progressão por andares, save/load em JSON e integração completa com o fluxo de batalha existente.

**Architecture:** `DungeonState` (dungeon/dungeon_state.gd) gerencia o grafo, geração procedural e save/load. `DungeonMapScreen` (ui/dungeon_map.gd) renderiza o mapa via `_draw()` e detecta cliques. Três arquivos existentes são modificados: `main_menu.gd` (botões Nova Run/Continuar), `party_select.gd` (navega para dungeon_map após seleção), `battle_scene.gd` (completa sala ao vencer, deleta save ao perder).

**Tech Stack:** GDScript 4.6, Godot 4.6. Sem editor ativo — verificação por inspeção de código. Save em `user://dungeon_save.json` via `FileAccess` + `JSON`.

---

## Arquivos

| Ação | Arquivo |
|---|---|
| Criar | `dungeon/dungeon_state.gd` |
| Criar | `ui/dungeon_map.gd` |
| Criar | `ui/dungeon_map.tscn` |
| Modificar | `ui/main_menu.gd` |
| Modificar | `ui/party_select.gd` |
| Modificar | `battle/battle_scene.gd` |
| Modificar | `tests/run_tests.gd` |

---

### Task 1: DungeonState — modelo, geração e save/load

**Files:**
- Create: `dungeon/dungeon_state.gd`
- Modify: `tests/run_tests.gd`

- [ ] **Step 1: Criar `dungeon/dungeon_state.gd` com conteúdo completo**

Crie o arquivo `dungeon/dungeon_state.gd` com o seguinte conteúdo:

```gdscript
class_name DungeonState
extends RefCounted

enum RoomType { BATTLE, ELITE, BOSS, EVENT, MYSTERY }

class RoomNode:
	var id: int = 0
	var floor: int = 0
	var type: int = 0
	var connections: Array = []
	var completed: bool = false
	var position: Vector2 = Vector2.ZERO

static var current_run: DungeonState = null

const SAVE_PATH   := "user://dungeon_save.json"
const FLOOR_COUNT := 6

var nodes: Array = []
var current_node_id: int = -1
var run_seed: int = 0

func generate(seed_val: int = -1) -> void:
	if seed_val >= 0:
		seed(seed_val)
		run_seed = seed_val
	else:
		run_seed = randi()
		seed(run_seed)
	nodes.clear()
	current_node_id = -1
	_build_graph()

func _build_graph() -> void:
	var node_id := 0
	var floor_nodes: Array = []

	var entry := RoomNode.new()
	entry.id = node_id
	entry.floor = 0
	entry.type = RoomType.BATTLE
	entry.position = Vector2(0.5, 0.0)
	nodes.append(entry)
	floor_nodes.append([entry])
	node_id += 1

	for f in range(1, 5):
		var count: int = randi_range(2, 3)
		var floor_arr: Array = []
		var weights: Dictionary = _type_weights(f)
		for n in range(count):
			var node := RoomNode.new()
			node.id = node_id
			node.floor = f
			node.type = _pick_type(weights)
			node.position = Vector2(
				float(n + 1) / float(count + 1),
				float(f) / float(FLOOR_COUNT - 1)
			)
			nodes.append(node)
			floor_arr.append(node)
			node_id += 1
		floor_nodes.append(floor_arr)

	var boss := RoomNode.new()
	boss.id = node_id
	boss.floor = 5
	boss.type = RoomType.BOSS
	boss.position = Vector2(0.5, 1.0)
	nodes.append(boss)
	floor_nodes.append([boss])

	for f in range(floor_nodes.size() - 1):
		var curr_floor: Array = floor_nodes[f]
		var next_floor: Array = floor_nodes[f + 1]

		for curr: RoomNode in curr_floor:
			var tgt: RoomNode = next_floor[randi() % next_floor.size()]
			if not curr.connections.has(tgt.id):
				curr.connections.append(tgt.id)

		for nxt: RoomNode in next_floor:
			var has_incoming := false
			for curr: RoomNode in curr_floor:
				if curr.connections.has(nxt.id):
					has_incoming = true
					break
			if not has_incoming:
				var src: RoomNode = curr_floor[randi() % curr_floor.size()]
				if not src.connections.has(nxt.id):
					src.connections.append(nxt.id)

		if next_floor.size() > 1:
			for curr: RoomNode in curr_floor:
				if randf() < 0.4:
					var extra: RoomNode = next_floor[randi() % next_floor.size()]
					if not curr.connections.has(extra.id):
						curr.connections.append(extra.id)

func _type_weights(floor: int) -> Dictionary:
	match floor:
		1: return {RoomType.BATTLE: 70, RoomType.MYSTERY: 30}
		2: return {RoomType.BATTLE: 50, RoomType.EVENT: 20, RoomType.MYSTERY: 30}
		3: return {RoomType.BATTLE: 40, RoomType.ELITE: 30, RoomType.MYSTERY: 30}
		4: return {RoomType.ELITE: 40, RoomType.EVENT: 30, RoomType.MYSTERY: 30}
		_: return {RoomType.BATTLE: 100}

func _pick_type(weights: Dictionary) -> int:
	var total := 0
	for w: int in weights.values():
		total += w
	var roll: int = randi() % total
	var cumulative := 0
	for t: int in weights.keys():
		cumulative += weights[t]
		if roll < cumulative:
			return t
	return RoomType.BATTLE

func get_available_rooms() -> Array:
	if current_node_id == -1:
		var result: Array = []
		for n: RoomNode in nodes:
			if n.floor == 0:
				result.append(n)
		return result
	var curr: RoomNode = get_node_by_id(current_node_id)
	if curr == null:
		return []
	var result: Array = []
	for conn_id: int in curr.connections:
		var n: RoomNode = get_node_by_id(conn_id)
		if n != null and not n.completed:
			result.append(n)
	return result

func get_node_by_id(node_id: int) -> RoomNode:
	for n: RoomNode in nodes:
		if n.id == node_id:
			return n
	return null

func enter_room(node_id: int) -> void:
	current_node_id = node_id
	save()

func complete_current_room() -> void:
	var n: RoomNode = get_node_by_id(current_node_id)
	if n != null:
		n.completed = true
	save()

func is_run_complete() -> bool:
	for n: RoomNode in nodes:
		if n.type == RoomType.BOSS and n.completed:
			return true
	return false

func save() -> void:
	var data: Dictionary = {
		"run_seed": run_seed,
		"current_node_id": current_node_id,
		"nodes": []
	}
	for n: RoomNode in nodes:
		(data["nodes"] as Array).append({
			"id": n.id,
			"floor": n.floor,
			"type": n.type,
			"connections": n.connections.duplicate(),
			"completed": n.completed,
			"pos_x": n.position.x,
			"pos_y": n.position.y
		})
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

static func load_save() -> DungeonState:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return null
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		return null
	var data: Dictionary = json.get_data()
	var state := DungeonState.new()
	state.run_seed = int(data.get("run_seed", 0))
	state.current_node_id = int(data.get("current_node_id", -1))
	for nd: Dictionary in data.get("nodes", []):
		var node := RoomNode.new()
		node.id = int(nd["id"])
		node.floor = int(nd["floor"])
		node.type = int(nd["type"])
		node.completed = bool(nd["completed"])
		node.position = Vector2(float(nd["pos_x"]), float(nd["pos_y"]))
		for c in nd["connections"]:
			node.connections.append(int(c))
		state.nodes.append(node)
	return state

static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("dungeon_save.json")
```

- [ ] **Step 2: Adicionar testes em `tests/run_tests.gd`**

Leia `tests/run_tests.gd`. O arquivo usa `_true(label, bool)` e `_eq(label, actual, expected)` dentro de `_run_all()`. Localize o final da função `_run_all()` (antes do fechamento `}`) e adicione:

```gdscript
	# --- DungeonState tests ---
	var ds := DungeonState.new()
	ds.generate(42)

	var ds_floor_counts: Dictionary = {}
	for dn in ds.nodes:
		ds_floor_counts[dn.floor] = ds_floor_counts.get(dn.floor, 0) + 1
	_eq("DungeonState: floor 0 has 1 node",  ds_floor_counts.get(0, 0), 1)
	_eq("DungeonState: floor 5 has 1 node",  ds_floor_counts.get(5, 0), 1)
	_true("DungeonState: floor 1 has 2-3 nodes",
		ds_floor_counts.get(1, 0) >= 2 and ds_floor_counts.get(1, 0) <= 3)
	_true("DungeonState: floor 4 has 2-3 nodes",
		ds_floor_counts.get(4, 0) >= 2 and ds_floor_counts.get(4, 0) <= 3)

	var ds_entry_ok := true
	for dn in ds.nodes:
		if dn.floor == 0 and dn.type != DungeonState.RoomType.BATTLE:
			ds_entry_ok = false
	_true("DungeonState: floor 0 node is BATTLE", ds_entry_ok)

	var ds_boss_ok := true
	for dn in ds.nodes:
		if dn.floor == 5 and dn.type != DungeonState.RoomType.BOSS:
			ds_boss_ok = false
	_true("DungeonState: floor 5 node is BOSS", ds_boss_ok)

	var ds_avail := ds.get_available_rooms()
	_eq("DungeonState: get_available_rooms at start returns 1 room", ds_avail.size(), 1)
	_eq("DungeonState: available room at start is floor 0", ds_avail[0].floor, 0)

	ds.enter_room(0)
	_eq("DungeonState: enter_room sets current_node_id", ds.current_node_id, 0)

	ds.complete_current_room()
	var ds_n0: DungeonState.RoomNode = ds.get_node_by_id(0)
	_true("DungeonState: complete_current_room marks node completed",
		ds_n0 != null and ds_n0.completed)

	var ds2 := DungeonState.new()
	ds2.generate(42)
	_true("DungeonState: is_run_complete false initially", not ds2.is_run_complete())

	var ds_boss_id := -1
	for dn in ds2.nodes:
		if dn.type == DungeonState.RoomType.BOSS:
			ds_boss_id = dn.id
	_true("DungeonState: boss node exists", ds_boss_id >= 0)
	ds2.current_node_id = ds_boss_id
	ds2.complete_current_room()
	_true("DungeonState: is_run_complete true after boss completed", ds2.is_run_complete())

	var ds3 := DungeonState.new()
	ds3.generate(42)
	var ds_reachable: Array = []
	for dn in ds3.nodes:
		if dn.floor == 0:
			ds_reachable.append(dn.id)
	var ds_visited: Dictionary = {}
	while not ds_reachable.is_empty():
		var nid: int = ds_reachable.pop_back()
		if ds_visited.has(nid): continue
		ds_visited[nid] = true
		var dn3: DungeonState.RoomNode = ds3.get_node_by_id(nid)
		if dn3 == null: continue
		for c in dn3.connections:
			if not ds_visited.has(c):
				ds_reachable.append(c)
	_eq("DungeonState: all nodes reachable from floor 0",
		ds_visited.size(), ds3.nodes.size())
```

- [ ] **Step 3: Verificar inspeção de código**

- `DungeonState.RoomNode` tem todos os campos: id, floor, type, connections, completed, position ✅
- `generate()` reseta `nodes` e `current_node_id = -1` ✅
- Floor 0 sempre BATTLE, floor 5 sempre BOSS ✅
- Cada nó tem ao menos uma saída (outgoing) e uma entrada (incoming) ✅
- `get_available_rooms()` retorna floor 0 quando `current_node_id == -1` ✅
- `save()` usa `FileAccess.open(SAVE_PATH, FileAccess.WRITE)` ✅
- `load_save()` é `static func` (pode ser chamada sem instância) ✅
- `delete_save()` é `static func`, usa `DirAccess.open("user://")` ✅
- `static var current_run: DungeonState = null` ✅

- [ ] **Step 4: Commit e push**

```
git add dungeon/dungeon_state.gd tests/run_tests.gd
git commit -m "feat: add DungeonState — graph generation, save/load, roguelike run state"
git push
```

---

### Task 2: DungeonMapScreen — rendering e interação

**Files:**
- Create: `ui/dungeon_map.gd`
- Create: `ui/dungeon_map.tscn`

- [ ] **Step 1: Criar `ui/dungeon_map.gd`**

```gdscript
class_name DungeonMapScreen
extends Control
# Expected lifecycle: one instance per run entry. Reads DungeonState.current_run on _ready().

const BG_COLOR    := Color(0.04, 0.05, 0.09)
const TITLE_COLOR := Color(0.90, 0.78, 0.20)

const NODE_COLORS := {
	DungeonState.RoomType.BATTLE:  Color(0.35, 0.45, 0.70),
	DungeonState.RoomType.ELITE:   Color(0.80, 0.50, 0.15),
	DungeonState.RoomType.BOSS:    Color(0.80, 0.20, 0.20),
	DungeonState.RoomType.EVENT:   Color(0.25, 0.70, 0.40),
	DungeonState.RoomType.MYSTERY: Color(0.55, 0.30, 0.75),
}

const NODE_LABELS := {
	DungeonState.RoomType.BATTLE:  "B",
	DungeonState.RoomType.ELITE:   "E",
	DungeonState.RoomType.BOSS:    "!",
	DungeonState.RoomType.EVENT:   "V",
	DungeonState.RoomType.MYSTERY: "?",
}

const NODE_NAMES := {
	DungeonState.RoomType.BATTLE:  "Batalha",
	DungeonState.RoomType.ELITE:   "Batalha Elite",
	DungeonState.RoomType.BOSS:    "BOSS",
	DungeonState.RoomType.EVENT:   "Evento",
	DungeonState.RoomType.MYSTERY: "Mistério",
}

const NODE_RADIUS := 24.0

var _state: DungeonState
var _selected_node_id: int = -1
var _canvas: Control
var _info_name: Label
var _info_floor: Label
var _enter_btn: Button

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	_state = DungeonState.current_run
	if _state == null:
		SceneTransition.fade_to("res://ui/main_menu.tscn")
		return

	var bg := ColorRect.new()
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.color = BG_COLOR
	add_child(bg)

	var title := Label.new()
	title.text = "MAPA DO DUNGEON"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	title.offset_bottom = 52
	add_child(title)

	_setup_canvas()
	_setup_info_panel()
	_setup_bottom_bar()

func _setup_canvas() -> void:
	_canvas = Control.new()
	_canvas.anchor_left   = 0.0
	_canvas.anchor_right  = 0.70
	_canvas.anchor_top    = 0.0
	_canvas.anchor_bottom = 1.0
	_canvas.offset_top    = 60
	_canvas.offset_bottom = -56
	_canvas.mouse_filter  = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_on_canvas_draw)
	_canvas.gui_input.connect(_on_canvas_input)
	add_child(_canvas)

func _setup_info_panel() -> void:
	var panel := PanelContainer.new()
	panel.anchor_left   = 0.70
	panel.anchor_right  = 1.0
	panel.anchor_top    = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_top    = 60
	panel.offset_bottom = -56
	var panel_bg := StyleBoxFlat.new()
	panel_bg.bg_color          = Color(0.06, 0.07, 0.12)
	panel_bg.border_color      = Color(0.22, 0.22, 0.28)
	panel_bg.border_width_left = 1
	panel.add_theme_stylebox_override("panel", panel_bg)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   16)
	margin.add_theme_constant_override("margin_right",  16)
	margin.add_theme_constant_override("margin_top",    20)
	margin.add_theme_constant_override("margin_bottom", 20)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_info_name = Label.new()
	_info_name.text = "Selecione uma sala"
	_info_name.add_theme_font_size_override("font_size", 16)
	_info_name.add_theme_color_override("font_color", Color(0.90, 0.90, 0.95))
	_info_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_info_name)

	_info_floor = Label.new()
	_info_floor.add_theme_font_size_override("font_size", 12)
	_info_floor.add_theme_color_override("font_color", Color(0.55, 0.62, 0.80))
	vbox.add_child(_info_floor)

	_enter_btn = Button.new()
	_enter_btn.text = "Entrar"
	_enter_btn.add_theme_font_size_override("font_size", 14)
	_enter_btn.custom_minimum_size = Vector2(0, 40)
	_enter_btn.visible = false
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color                   = Color(0.18, 0.30, 0.52)
	btn_style.corner_radius_top_left     = 5
	btn_style.corner_radius_top_right    = 5
	btn_style.corner_radius_bottom_left  = 5
	btn_style.corner_radius_bottom_right = 5
	_enter_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.25, 0.42, 0.68)
	_enter_btn.add_theme_stylebox_override("hover", btn_hover)
	_enter_btn.pressed.connect(_on_enter_room)
	vbox.add_child(_enter_btn)

func _setup_bottom_bar() -> void:
	var bar := HBoxContainer.new()
	bar.anchor_left   = 0.0
	bar.anchor_right  = 1.0
	bar.anchor_top    = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top    = -52
	bar.offset_bottom = -4
	bar.alignment     = BoxContainer.ALIGNMENT_CENTER
	add_child(bar)

	var back_btn := Button.new()
	back_btn.text = "Voltar ao Menu"
	back_btn.add_theme_font_size_override("font_size", 13)
	back_btn.custom_minimum_size = Vector2(200, 42)
	var sn := StyleBoxFlat.new()
	sn.bg_color                   = Color(0.22, 0.10, 0.10)
	sn.corner_radius_top_left     = 5
	sn.corner_radius_top_right    = 5
	sn.corner_radius_bottom_left  = 5
	sn.corner_radius_bottom_right = 5
	back_btn.add_theme_stylebox_override("normal", sn)
	var sh := sn.duplicate() as StyleBoxFlat
	sh.bg_color = Color(0.32, 0.14, 0.14)
	back_btn.add_theme_stylebox_override("hover", sh)
	back_btn.pressed.connect(_on_back_to_menu)
	bar.add_child(back_btn)

func _node_screen_pos(node: DungeonState.RoomNode) -> Vector2:
	var sz := _canvas.size
	var margin := 60.0
	return Vector2(
		margin + node.position.x * (sz.x - margin * 2.0),
		margin + node.position.y * (sz.y - margin * 2.0)
	)

func _on_canvas_draw() -> void:
	if _state == null:
		return
	var available_ids: Array = []
	for n in _state.get_available_rooms():
		available_ids.append(n.id)

	# Draw connections
	for node: DungeonState.RoomNode in _state.nodes:
		var from_pos := _node_screen_pos(node)
		for conn_id: int in node.connections:
			var target: DungeonState.RoomNode = _state.get_node_by_id(conn_id)
			if target != null:
				_canvas.draw_line(from_pos, _node_screen_pos(target),
					Color(0.28, 0.28, 0.36), 2.0)

	# Draw nodes
	for node: DungeonState.RoomNode in _state.nodes:
		var pos := _node_screen_pos(node)
		var base_color: Color = NODE_COLORS.get(node.type, Color.GRAY)
		var alpha := 0.35 if node.completed else 1.0
		_canvas.draw_circle(pos, NODE_RADIUS,
			Color(base_color.r, base_color.g, base_color.b, alpha))

		if not node.completed:
			if node.id == _selected_node_id:
				_canvas.draw_arc(pos, NODE_RADIUS, 0.0, TAU, 32,
					Color(0.90, 0.78, 0.20), 3.0)
			elif available_ids.has(node.id):
				_canvas.draw_arc(pos, NODE_RADIUS, 0.0, TAU, 32,
					Color(0.90, 0.90, 0.90), 2.0)

		var lbl: String = NODE_LABELS.get(node.type, "?")
		_canvas.draw_string(ThemeDB.fallback_font,
			pos + Vector2(-6.0, 6.0), lbl,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 16,
			Color(1.0, 1.0, 1.0, alpha))

func _on_canvas_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	if _state == null:
		return
	var available_ids: Array = []
	for n in _state.get_available_rooms():
		available_ids.append(n.id)

	for node: DungeonState.RoomNode in _state.nodes:
		if node.completed or not available_ids.has(node.id):
			continue
		if mb.position.distance_to(_node_screen_pos(node)) <= NODE_RADIUS:
			_selected_node_id = node.id
			_info_name.text = NODE_NAMES.get(node.type, "Sala")
			_info_floor.text = "Boss" if node.floor == 5 else "Andar %d" % node.floor
			_enter_btn.visible = true
			_canvas.queue_redraw()
			return

	_selected_node_id = -1
	_info_name.text = "Selecione uma sala"
	_info_floor.text = ""
	_enter_btn.visible = false
	_canvas.queue_redraw()

func _on_enter_room() -> void:
	if _selected_node_id < 0 or _state == null:
		return
	_state.enter_room(_selected_node_id)
	SceneTransition.fade_to("res://battle/battle_scene.tscn")

func _on_back_to_menu() -> void:
	DungeonState.delete_save()
	DungeonState.current_run = null
	BattleState.reset_players()
	SceneTransition.fade_to("res://ui/main_menu.tscn")
```

**Nota sobre `NODE_LABELS`:** Os labels usam letras simples (B, E, !, V, ?) em vez de símbolos Unicode (⚔, ☠, etc.) para garantir compatibilidade com a fonte padrão do Godot. Se o projeto tiver uma fonte customizada com suporte a Unicode, os labels podem ser substituídos.

- [ ] **Step 2: Criar `ui/dungeon_map.tscn`**

Crie o arquivo `ui/dungeon_map.tscn` com o seguinte conteúdo:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://ui/dungeon_map.gd" id="1"]

[node name="DungeonMapScreen" type="Control"]
script = ExtResource("1")
```

- [ ] **Step 3: Verificar inspeção de código**

- `_state = DungeonState.current_run` em `_ready()` ✅
- Se `_state == null`, navega de volta ao menu ✅
- `_canvas.draw.connect(_on_canvas_draw)` ✅
- `_on_canvas_draw()` desenha linhas de conexão antes dos círculos ✅
- Nó selecionado: borda dourada; disponível: borda branca; completado: alpha 0.35 ✅
- `_on_canvas_input()` detecta clique por distância ao centro do nó ✅
- Apenas nós `available_ids` são clicáveis (não completados, não bloqueados) ✅
- `_on_enter_room()` chama `_state.enter_room()` antes de navegar ✅
- `_on_back_to_menu()` chama `DungeonState.delete_save()` e reset ✅

- [ ] **Step 4: Commit e push**

```
git add ui/dungeon_map.gd ui/dungeon_map.tscn
git commit -m "feat: add DungeonMapScreen — node graph rendering, click selection, enter room"
git push
```

---

### Task 3: Integração — main_menu, party_select, battle_scene

**Files:**
- Modify: `ui/main_menu.gd`
- Modify: `ui/party_select.gd`
- Modify: `battle/battle_scene.gd`

- [ ] **Step 1: Atualizar `ui/main_menu.gd`**

Leia `ui/main_menu.gd`. Faça as seguintes mudanças:

**1a. Alterar `_add_button` para retornar `Button`:**

Localize:
```gdscript
func _add_button(parent: Control, label: String, normal_col: Color, hover_col: Color, cb: Callable) -> void:
```
Substitua por:
```gdscript
func _add_button(parent: Control, label: String, normal_col: Color, hover_col: Color, cb: Callable) -> Button:
```

Localize o final da função `_add_button` (após `parent.add_child(btn)`):
```gdscript
	btn.pressed.connect(cb)
	parent.add_child(btn)
```
Substitua por:
```gdscript
	btn.pressed.connect(cb)
	parent.add_child(btn)
	return btn
```

**1b. Substituir "Nova Batalha" por "Nova Run" e adicionar "Continuar" em `_ready()`:**

Localize:
```gdscript
	_add_button(center, "Nova Batalha", Color(0.18, 0.30, 0.52), Color(0.25, 0.42, 0.68), _on_nova_batalha)
	_add_button(center, "Opcoes",       Color(0.14, 0.16, 0.24), Color(0.20, 0.22, 0.32), _on_opcoes)
	_add_button(center, "Sair",         Color(0.22, 0.10, 0.10), Color(0.32, 0.14, 0.14), _on_sair)
```
Substitua por:
```gdscript
	_add_button(center, "Nova Run",  Color(0.18, 0.30, 0.52), Color(0.25, 0.42, 0.68), _on_nova_run)
	var continuar := _add_button(center, "Continuar", Color(0.12, 0.28, 0.18), Color(0.18, 0.40, 0.26), _on_continuar)
	continuar.visible = FileAccess.file_exists(DungeonState.SAVE_PATH)
	_add_button(center, "Opcoes", Color(0.14, 0.16, 0.24), Color(0.20, 0.22, 0.32), _on_opcoes)
	_add_button(center, "Sair",   Color(0.22, 0.10, 0.10), Color(0.32, 0.14, 0.14), _on_sair)
```

**1c. Substituir `_on_nova_batalha` e adicionar novos handlers:**

Localize:
```gdscript
func _on_nova_batalha() -> void:
	SceneTransition.fade_to("res://ui/party_select.tscn")
```
Substitua por:
```gdscript
func _on_nova_run() -> void:
	DungeonState.current_run = DungeonState.new()
	DungeonState.current_run.generate()
	DungeonState.current_run.save()
	SceneTransition.fade_to("res://ui/party_select.tscn")

func _on_continuar() -> void:
	DungeonState.current_run = DungeonState.load_save()
	if DungeonState.current_run == null:
		return
	SceneTransition.fade_to("res://ui/dungeon_map.tscn")
```

- [ ] **Step 2: Atualizar `ui/party_select.gd` — navegação pós-seleção**

Leia `ui/party_select.gd`. Localize `_on_start()` ao final do arquivo:

```gdscript
func _on_start() -> void:
	var selected_names: Array = []
	for hname in BattleState.ALL_HERO_DATA.keys():
		if _selected.get(hname, false):
			selected_names.append(hname)
	if selected_names.is_empty():
		return
	BattleState.setup_party(selected_names)
	SceneTransition.fade_to("res://battle/battle_scene.tscn")
```

Substitua por:

```gdscript
func _on_start() -> void:
	var selected_names: Array = []
	for hname in BattleState.ALL_HERO_DATA.keys():
		if _selected.get(hname, false):
			selected_names.append(hname)
	if selected_names.is_empty():
		return
	BattleState.setup_party(selected_names)
	if DungeonState.current_run != null:
		SceneTransition.fade_to("res://ui/dungeon_map.tscn")
	else:
		SceneTransition.fade_to("res://battle/battle_scene.tscn")
```

- [ ] **Step 3: Atualizar `battle/battle_scene.gd` — handlers de resultado**

Leia `battle/battle_scene.gd`. Localize ao final do arquivo:

```gdscript
func _on_continue_requested() -> void:
	# TODO: dungeon_map.tscn criado no Sub-projeto 2 (Mapa do Dungeon)
	if ResourceLoader.exists("res://ui/dungeon_map.tscn"):
		SceneTransition.fade_to("res://ui/dungeon_map.tscn")
	else:
		BattleState.reset_players()
		SceneTransition.fade_to("res://ui/main_menu.tscn")

func _on_restart_requested() -> void:
	BattleState.reset_players()
	SceneTransition.fade_to("res://ui/main_menu.tscn")
```

Substitua por:

```gdscript
func _on_continue_requested() -> void:
	if DungeonState.current_run != null:
		DungeonState.current_run.complete_current_room()
		if DungeonState.current_run.is_run_complete():
			DungeonState.delete_save()
			DungeonState.current_run = null
			BattleState.reset_players()
			SceneTransition.fade_to("res://ui/main_menu.tscn")
			return
	SceneTransition.fade_to("res://ui/dungeon_map.tscn")

func _on_restart_requested() -> void:
	if DungeonState.current_run != null:
		DungeonState.delete_save()
		DungeonState.current_run = null
	BattleState.reset_players()
	SceneTransition.fade_to("res://ui/main_menu.tscn")
```

- [ ] **Step 4: Verificar inspeção de código**

**main_menu.gd:**
- `_add_button` retorna `Button` ✅
- "Nova Run" → `_on_nova_run()` → cria DungeonState → gera → salva → party_select ✅
- "Continuar" → visível apenas se save existe → carrega → dungeon_map ✅
- `_on_nova_batalha` removido, sem referências órfãs ✅

**party_select.gd:**
- `_on_start()`: se `DungeonState.current_run != null` → dungeon_map, senão → battle_scene ✅
- Backward compatibility mantida (sem dungeon run ativo, vai direto para battle_scene) ✅

**battle_scene.gd:**
- `_on_continue_requested()`: chama `complete_current_room()`, verifica `is_run_complete()`, trata boss concluído → main menu ✅
- `_on_restart_requested()`: deleta save, reseta `current_run = null`, reset players ✅
- TODO comment removido (implementado) ✅

- [ ] **Step 5: Commit e push**

```
git add ui/main_menu.gd ui/party_select.gd battle/battle_scene.gd
git commit -m "feat: integrate DungeonState into main_menu, party_select, and battle_scene"
git push
```
