class_name DungeonState
extends RefCounted

enum RoomType { BATTLE, ELITE, BOSS, EVENT, MYSTERY, REST }

class RoomNode:
	var id: int = 0
	var floor_idx: int = 0
	var type: int = 0
	var connections: Array = []
	var completed: bool = false
	var position: Vector2 = Vector2.ZERO

	func _init() -> void:
		connections = []

static var current_run: DungeonState = null

const SAVE_PATH   := "user://dungeon_save.json"
const FLOOR_COUNT := 6
const FLOOR_COUNT_MIN := 5
const FLOOR_COUNT_MAX := 7
var floor_count: int = FLOOR_COUNT

var nodes: Array = []
var current_node_id: int = -1
var run_seed: int = 0
var pending_room: bool = false
var party_names: Array = []
var pending_buffs: Array = []

# Névoa de guerra: ids visíveis (fonte da verdade) e ids já dissolvidos.
var revealed_ids: Dictionary = {}
var seen_ids: Dictionary = {}

# Cura cada membro vivo da party em `pct` do HP máximo (sem ultrapassar max_hp).
# Membros mortos (hp <= 0) são ignorados. Muta os dicionários in-place.
static func apply_rest_heal(players: Array, pct: float = 0.30) -> void:
	for p in players:
		var hp: int = int(p.get("hp", 0))
		if hp <= 0:
			continue
		var max_hp: int = int(p.get("max_hp", 0))
		var healed: int = hp + int(ceil(float(max_hp) * pct))
		p["hp"] = mini(max_hp, healed)

func generate(seed_val: int = -1) -> void:
	if seed_val >= 0:
		seed(seed_val)
		run_seed = seed_val
	else:
		run_seed = randi()
		seed(run_seed)
	var last_nodes: Array = []
	var last_fc: int = FLOOR_COUNT
	for attempt in range(100):
		floor_count = randi_range(FLOOR_COUNT_MIN, FLOOR_COUNT_MAX)
		nodes.clear()
		current_node_id = -1
		_build_graph()
		last_nodes = nodes.duplicate()
		last_fc = floor_count
		if _soft_guarantees_ok():
			_seed_reveal()
			return
	nodes = last_nodes
	floor_count = last_fc
	_seed_reveal()

func _soft_guarantees_ok() -> bool:
	var elite_floors := {}
	var has_event := false
	for n: RoomNode in nodes:
		if n.type == RoomType.ELITE:
			elite_floors[n.floor_idx] = true
		elif n.type == RoomType.EVENT:
			has_event = true
	for f in elite_floors.keys():
		if elite_floors.has(f + 1):
			return false
	return has_event

func is_revealed(node_id: int) -> bool:
	return revealed_ids.has(node_id)

func revealed_node_ids() -> Array:
	return revealed_ids.keys()

func newly_revealed_ids() -> Array:
	var result: Array = []
	for nid in revealed_ids.keys():
		if not seen_ids.has(nid):
			result.append(nid)
	return result

func acknowledge_revealed() -> void:
	for nid in revealed_ids.keys():
		seen_ids[nid] = true
	save()

func max_revealed_floor() -> int:
	var m := 0
	for nid in revealed_ids.keys():
		var n: RoomNode = get_node_by_id(nid)
		if n != null and n.floor_idx > m:
			m = n.floor_idx
	return m

# Reconstrói revealed/seen para saves antigos sem os campos de névoa.
# Coerente com "revelar ao completar": a entrada sempre aparece, e cada sala
# concluída revela a si mesma + seus vizinhos diretos. Marca tudo como já visto
# para não redisparar a animação de névoa.
func _rebuild_reveal_from_progress() -> void:
	revealed_ids.clear()
	seen_ids.clear()
	for n: RoomNode in nodes:
		if n.floor_idx == 0:
			revealed_ids[n.id] = true
		if n.completed:
			revealed_ids[n.id] = true
			for c: int in n.connections:
				revealed_ids[c] = true
	for nid in revealed_ids.keys():
		seen_ids[nid] = true

# Semeia a névoa apenas com a entrada (andar 0). Os vizinhos só são revelados
# quando o jogador completa a sala atual (ver complete_current_room).
func _seed_reveal() -> void:
	revealed_ids.clear()
	seen_ids.clear()
	for n: RoomNode in nodes:
		if n.floor_idx == 0:
			revealed_ids[n.id] = true

func _build_graph() -> void:
	var node_id := 0
	var floor_nodes: Array = []

	# Andar 0: entrada (BATALHA)
	var entry := RoomNode.new()
	entry.id = node_id
	entry.floor_idx = 0
	entry.type = RoomType.BATTLE
	entry.position = Vector2(0.5, 0.0)
	nodes.append(entry)
	floor_nodes.append([entry])
	node_id += 1

	# Andares do meio (1 .. floor_count-2)
	var pre_boss := floor_count - 2
	for f in range(1, floor_count - 1):
		var count: int = randi_range(2, 3)
		var floor_arr: Array = []
		var weights: Dictionary = _type_weights(f)
		for n in range(count):
			var node := RoomNode.new()
			node.id = node_id
			node.floor_idx = f
			node.type = _pick_type(weights)
			node.position = Vector2(
				float(n + 1) / float(count + 1),
				float(f) / float(maxi(1, floor_count - 1))
			)
			floor_arr.append(node)
			nodes.append(node)
			node_id += 1
		if f == pre_boss:
			floor_arr[0].type = RoomType.REST
		floor_nodes.append(floor_arr)

	_ensure_elite(floor_nodes, pre_boss)

	# Boss
	var boss := RoomNode.new()
	boss.id = node_id
	boss.floor_idx = floor_count - 1
	boss.type = RoomType.BOSS
	boss.position = Vector2(0.5, 1.0)
	nodes.append(boss)
	floor_nodes.append([boss])

	_connect_floors(floor_nodes)

func _ensure_elite(floor_nodes: Array, pre_boss: int) -> void:
	for fa: Array in floor_nodes:
		for n: RoomNode in fa:
			if n.type == RoomType.ELITE:
				return
	var candidates: Array = []
	for fi in range(1, pre_boss):
		for n: RoomNode in floor_nodes[fi]:
			if n.type == RoomType.BATTLE or n.type == RoomType.MYSTERY:
				candidates.append(n)
	if candidates.is_empty():
		for fi in range(1, pre_boss):
			for n: RoomNode in floor_nodes[fi]:
				if n.type != RoomType.REST:
					candidates.append(n)
	if not candidates.is_empty():
		candidates[randi() % candidates.size()].type = RoomType.ELITE

# Conecta cada andar ao próximo com matching monotônico (sem cruzamentos) + branch leve.
func _connect_floors(floor_nodes: Array) -> void:
	for f in range(floor_nodes.size() - 1):
		var curr: Array = floor_nodes[f].duplicate()
		var nxt: Array = floor_nodes[f + 1].duplicate()
		curr.sort_custom(func(a, b): return a.position.x < b.position.x)
		nxt.sort_custom(func(a, b): return a.position.x < b.position.x)
		var m := curr.size()
		var k := nxt.size()
		var targets: Array[int] = []
		for i in range(m):
			var j: int = int(round(float(i) * float(k - 1) / float(maxi(1, m - 1))))
			curr[i].connections.append(nxt[j].id)
			targets.append(j)
		for j in range(k):
			var has_in := false
			for i in range(m):
				if curr[i].connections.has(nxt[j].id):
					has_in = true
					break
			if not has_in:
				var best_i := 0
				var best_d := 1 << 30
				for i in range(m):
					var d: int = absi(targets[i] - j)
					if d < best_d:
						best_d = d
						best_i = i
				curr[best_i].connections.append(nxt[j].id)
		for i in range(m - 1):
			if targets[i + 1] > targets[i] and randf() < 0.5:
				var tid: int = nxt[targets[i + 1]].id
				if not curr[i].connections.has(tid):
					curr[i].connections.append(tid)

func _type_weights(floor_idx: int) -> Dictionary:
	match floor_idx:
		1: return {RoomType.BATTLE: 70, RoomType.MYSTERY: 30}
		2: return {RoomType.BATTLE: 45, RoomType.EVENT: 20, RoomType.MYSTERY: 25, RoomType.REST: 10}
		3: return {RoomType.BATTLE: 35, RoomType.ELITE: 25, RoomType.MYSTERY: 25, RoomType.REST: 15}
		_: return {RoomType.BATTLE: 30, RoomType.ELITE: 30, RoomType.EVENT: 25, RoomType.REST: 15}

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
	var result: Array
	if current_node_id == -1:
		result = []
		for n: RoomNode in nodes:
			if n.floor_idx == 0:
				result.append(n)
		return result
	var curr: RoomNode = get_node_by_id(current_node_id)
	if curr == null:
		return []
	
	result = []
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
	var node := get_node_by_id(node_id)
	if node == null:
		return
	current_node_id = node_id
	pending_room = true
	revealed_ids[node_id] = true
	save()

func complete_current_room() -> void:
	if current_node_id == -1:
		return
	var n: RoomNode = get_node_by_id(current_node_id)
	if n != null:
		n.completed = true
		# Completar a sala dissipa a névoa das salas seguintes (vizinhos diretos).
		for c: int in n.connections:
			revealed_ids[c] = true
	pending_room = false
	save()

func is_run_complete() -> bool:
	for n: RoomNode in nodes:
		if n.type == RoomType.BOSS and n.completed:
			return true
	return false

func save() -> void:
	var data: Dictionary = {
		"run_seed": run_seed,
		"floor_count": floor_count,
		"current_node_id": current_node_id,
		"pending_room": pending_room,
		"party_names": party_names.duplicate(),
		"pending_buffs": pending_buffs.duplicate(),
		"revealed": revealed_ids.keys(),
		"seen": seen_ids.keys(),
		"nodes": []
	}
	for n: RoomNode in nodes:
		(data["nodes"] as Array).append({
			"id": n.id,
			"floor": n.floor_idx,
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
	var raw: Variant = json.get_data()
	if not raw is Dictionary:
		return null
	var data: Dictionary = raw
	var state := DungeonState.new()
	state.run_seed = int(data.get("run_seed", 0))
	state.floor_count = int(data.get("floor_count", DungeonState.FLOOR_COUNT))
	state.current_node_id = int(data.get("current_node_id", -1))
	state.pending_room = bool(data.get("pending_room", false))
	for pn in data.get("party_names", []):
		state.party_names.append(str(pn))
	for buff in data.get("pending_buffs", []):
		if buff is Dictionary:
			state.pending_buffs.append(buff)
	for nd: Dictionary in data.get("nodes", []):
		var node := RoomNode.new()
		node.id = int(nd["id"])
		node.floor_idx = int(nd["floor"])
		node.type = int(nd["type"])
		node.completed = bool(nd["completed"])
		node.position = Vector2(float(nd["pos_x"]), float(nd["pos_y"]))
		for c in nd["connections"]:
			node.connections.append(int(c))
		state.nodes.append(node)
	# Névoa: restaura sets persistidos ou reconstrói saves legados.
	if data.has("revealed"):
		for rid in data.get("revealed", []):
			state.revealed_ids[int(rid)] = true
		for sid in data.get("seen", []):
			state.seen_ids[int(sid)] = true
	else:
		state._rebuild_reveal_from_progress()
	return state

func reveal_extra_connections(from_node_id: int) -> void:
	var from_node: RoomNode = get_node_by_id(from_node_id)
	if from_node == null:
		return
	var next_floor: int = from_node.floor_idx + 1
	if next_floor >= floor_count:
		return
	var next_nodes: Array = []
	for n: RoomNode in nodes:
		if n.floor_idx == next_floor and not n.completed:
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

static func delete_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var dir := DirAccess.open("user://")
		if dir:
			dir.remove("dungeon_save.json")
