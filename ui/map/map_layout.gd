class_name MapLayout
extends RefCounted

# Tamanhos (fonte única; a tela e o renderer referenciam daqui)
const NODE_SIZE      := 64.0
const NODE_SIZE_BOSS := 88.0
const MARGIN_PAD     := 8.0

static func _margin() -> float:
	return NODE_SIZE * 0.5 + MARGIN_PAD

# Converte posição normalizada (0..1) do nó em pixel dentro do canvas.
static func node_center(node_pos: Vector2, canvas_size: Vector2) -> Vector2:
	var m := _margin()
	return Vector2(
		m + node_pos.x * (canvas_size.x - m * 2.0),
		m + node_pos.y * (canvas_size.y - m * 2.0)
	)

static func node_size_for(node: DungeonState.RoomNode) -> float:
	return NODE_SIZE_BOSS if node.type == DungeonState.RoomType.BOSS else NODE_SIZE

# Retorna o id do nó sob `pos`, ou -1.
static func node_id_at(state: DungeonState, pos: Vector2, canvas_size: Vector2) -> int:
	for node: DungeonState.RoomNode in state.nodes:
		var r := node_size_for(node) * 0.5
		if pos.distance_to(node_center(node.position, canvas_size)) <= r:
			return node.id
	return -1

# Conjunto (Dictionary usado como set) de chaves "min:max" das arestas do trajeto percorrido.
static func lit_connections(state: DungeonState) -> Dictionary:
	var result: Dictionary = {}
	for node: DungeonState.RoomNode in state.nodes:
		if not node.completed:
			continue
		for conn_id: int in node.connections:
			var target: DungeonState.RoomNode = state.get_node_by_id(conn_id)
			if target == null:
				continue
			if target.completed or target.id == state.current_node_id:
				var key := "%d:%d" % [mini(node.id, conn_id), maxi(node.id, conn_id)]
				result[key] = true
	return result

# Andar atual (1-based) e total, para o indicador de progresso.
static func run_progress(state: DungeonState) -> Dictionary:
	var floor_idx := 0
	if state.current_node_id != -1:
		var cur: DungeonState.RoomNode = state.get_node_by_id(state.current_node_id)
		if cur != null:
			floor_idx = cur.floor_idx
	return {
		"current_floor": floor_idx + 1,
	}

# y central de um andar dentro do canvas (mesma base usada por node_center).
static func floor_center_y(floor_idx: int, canvas_size: Vector2, floor_count: int) -> float:
	var m := _margin()
	var avail_h := canvas_size.y - m * 2.0
	var t := float(floor_idx) / float(maxi(1, floor_count - 1))
	return m + t * avail_h

# Retângulo da faixa de fundo do andar: do ponto médio com o andar anterior
# até o ponto médio com o próximo. Bordas grudam no topo/base do canvas.
static func floor_band_rect(floor_idx: int, canvas_size: Vector2, floor_count: int) -> Rect2:
	var y := floor_center_y(floor_idx, canvas_size, floor_count)
	var top: float
	var bottom: float
	if floor_idx == 0:
		top = 0.0
	else:
		top = (floor_center_y(floor_idx - 1, canvas_size, floor_count) + y) * 0.5
	if floor_idx == floor_count - 1:
		bottom = canvas_size.y
	else:
		bottom = (y + floor_center_y(floor_idx + 1, canvas_size, floor_count)) * 0.5
	return Rect2(0.0, top, canvas_size.x, bottom - top)

static func floor_label(floor_idx: int, floor_count: int) -> String:
	return "Boss" if floor_idx == floor_count - 1 else "Andar %d" % (floor_idx + 1)
