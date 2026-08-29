class_name DungeonState
extends RefCounted

enum RoomType { BATTLE, ELITE, BOSS, EVENT, MYSTERY }

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

var nodes: Array = []
var current_node_id: int = -1
var run_seed: int = 0
var pending_room: bool = false
var party_names: Array = []
var pending_buffs: Array = []

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
	entry.floor_idx = 0
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
			node.floor_idx = f
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
	boss.floor_idx = FLOOR_COUNT - 1
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

func _type_weights(floor_idx: int) -> Dictionary:
	match floor_idx:
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
	if get_node_by_id(node_id) == null:
		return
	current_node_id = node_id
	pending_room = true
	save()

func complete_current_room() -> void:
	if current_node_id == -1:
		return
	var n: RoomNode = get_node_by_id(current_node_id)
	if n != null:
		n.completed = true
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
		"current_node_id": current_node_id,
		"pending_room": pending_room,
		"party_names": party_names.duplicate(),
		"pending_buffs": pending_buffs.duplicate(),
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
	return state

func reveal_extra_connections(from_node_id: int) -> void:
	var from_node: RoomNode = get_node_by_id(from_node_id)
	if from_node == null:
		return
	var next_floor: int = from_node.floor_idx + 1
	if next_floor >= FLOOR_COUNT:
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
