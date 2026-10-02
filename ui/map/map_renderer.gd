class_name MapRenderer
extends RefCounted

const CHAIN_THICKNESS := 12.0
const NODE_ICON_SIZE := 30.0
const CHAIN_GLOW_COLOR := Color(0.55, 0.08, 0.08, 0.9)
const CHAIN_GLOW_INTENSITY := 1.0
const CHAIN_GLOW_PULSE_SPEED := 2.5
const CHAIN_GLOW_PARTICLE_SIZE := 10.0
const CHAIN_GLOW_PARTICLE_SPACING := 10.0
const BAND_COLOR_EVEN := Color(0.10, 0.11, 0.16, 0.35)
const BAND_COLOR_ODD  := Color(0.07, 0.08, 0.12, 0.35)
const BAND_SEP_COLOR  := Color(0.30, 0.33, 0.48, 0.35)
const BAND_LABEL_COLOR := Color(0.70, 0.76, 0.95, 0.85)
const BAND_LABEL_BG    := Color(0.12, 0.13, 0.20, 0.85)
const HERE_COLOR := Color(0.45, 0.85, 1.0)
const INTRO_FLOOR_DELAY := 0.12
const INTRO_DURATION := 0.35

func draw_all(ctx: Dictionary) -> void:
	_draw_connections(ctx)
	_draw_nodes(ctx)
	_draw_here_marker(ctx)

func _draw_here_marker(ctx: Dictionary) -> void:
	var state: DungeonState = ctx["state"]
	if state.current_node_id == -1:
		return
	var node: DungeonState.RoomNode = state.get_node_by_id(state.current_node_id)
	if node == null:
		return
	var pos := _node_center(ctx, node)
	var nsize: float = MapLayout.node_size_for(node)
	var pulse: float = sin(ctx["glow_time"] * 3.0) * 0.5 + 0.5
	var radius := nsize * 0.5 + 6.0 + pulse * 4.0
	var col := Color(HERE_COLOR.r, HERE_COLOR.g, HERE_COLOR.b, 0.5 + pulse * 0.5)
	(ctx["canvas"] as Control).draw_arc(pos, radius, 0.0, TAU, 48, col, 3.0)

func _node_center(ctx: Dictionary, node: DungeonState.RoomNode) -> Vector2:
	return MapLayout.node_center(node.position, (ctx["canvas"] as Control).size)

# Decide se um nó deve ser desenhado nesta passada.
# Requer estar revelado; se o ctx trouxer "draw_ids", restringe a esse conjunto.
func _should_draw(ctx: Dictionary, node: DungeonState.RoomNode) -> bool:
	var state: DungeonState = ctx["state"]
	if not state.is_revealed(node.id):
		return false
	var filt: Variant = ctx.get("draw_ids", null)
	if filt != null and not (filt as Dictionary).has(node.id):
		return false
	return true

func _intro_t(ctx: Dictionary, floor_idx: int) -> float:
	var start := floor_idx * INTRO_FLOOR_DELAY
	var elapsed: float = ctx["intro_time"]
	var t := (elapsed - start) / INTRO_DURATION
	return clampf(t, 0.0, 1.0)

func _draw_connections(ctx: Dictionary) -> void:
	var state: DungeonState = ctx["state"]
	# Desenha as correntes de SAÍDA de todo nó revelado, mesmo para vizinhos ainda
	# ocultos: o nó-alvo continua sob a névoa, mas a corrente vaza dando a dica do
	# caminho. (O nó de origem precisa estar revelado.)
	for node: DungeonState.RoomNode in state.nodes:
		if not state.is_revealed(node.id):
			continue
		var from_pos := _node_center(ctx, node)
		for conn_id: int in node.connections:
			var target: DungeonState.RoomNode = state.get_node_by_id(conn_id)
			if target == null:
				continue
			var it := minf(_intro_t(ctx, node.floor_idx), _intro_t(ctx, target.floor_idx))
			if it <= 0.0:
				continue
			var to_pos := _node_center(ctx, target)
			var key := "%d:%d" % [mini(node.id, conn_id), maxi(node.id, conn_id)]
			var segs: Array = ctx["chain_map"].get(key, [3])
			var should_glow: bool = ctx["lit"].has(key)
			_draw_chain(ctx, from_pos, to_pos, segs, should_glow)

func _draw_chain(ctx: Dictionary, from: Vector2, to: Vector2, seg_indices: Array, apply_glow: bool) -> void:
	var canvas: Control = ctx["canvas"]
	var diff := to - from
	var length := diff.length()
	var angle := diff.angle()
	if length < 1.0 or seg_indices.is_empty():
		return
	var seg_len := length / seg_indices.size()
	if apply_glow:
		var pulse: float = sin(ctx["glow_time"] * CHAIN_GLOW_PULSE_SPEED) * 0.5 + 0.5
		var particle_alpha := CHAIN_GLOW_INTENSITY * (0.4 + pulse * 0.6)
		var particle_color := Color(CHAIN_GLOW_COLOR.r, CHAIN_GLOW_COLOR.g, CHAIN_GLOW_COLOR.b, particle_alpha)
		var half_particle := CHAIN_GLOW_PARTICLE_SIZE * 0.5
		var total_length := seg_len * seg_indices.size()
		var num_particles := maxi(1, int(total_length / CHAIN_GLOW_PARTICLE_SPACING))
		var particle_spacing := total_length / num_particles
		for p_idx in num_particles:
			var dist := particle_spacing * p_idx
			var particle_pos := from + diff.normalized() * dist
			canvas.draw_set_transform_matrix(Transform2D(0.0, particle_pos))
			canvas.draw_texture_rect(ctx["chain_glow_texture"],
				Rect2(-half_particle, -half_particle, CHAIN_GLOW_PARTICLE_SIZE, CHAIN_GLOW_PARTICLE_SIZE),
				false, particle_color)
	for i in seg_indices.size():
		var tex: Texture2D = ctx["chain_textures"][seg_indices[i]]
		var origin := from + diff.normalized() * (seg_len * i)
		canvas.draw_set_transform_matrix(Transform2D(angle, origin))
		canvas.draw_texture_rect(tex, Rect2(0.0, -CHAIN_THICKNESS * 0.5, seg_len, CHAIN_THICKNESS), false)
	canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_nodes(ctx: Dictionary) -> void:
	var state: DungeonState = ctx["state"]
	var canvas: Control = ctx["canvas"]
	for node: DungeonState.RoomNode in state.nodes:
		if not _should_draw(ctx, node):
			continue
		var it := _intro_t(ctx, node.floor_idx)
		if it <= 0.0:
			continue
		var eased := it * it * (3.0 - 2.0 * it)
		var pos := _node_center(ctx, node)
		var is_boss := node.type == DungeonState.RoomType.BOSS
		var textures: Array = ctx["boss_node_textures"] if is_boss \
			else ctx["node_textures"].get(ctx["node_type_key"].get(node.type, "battle"), ctx["node_textures"]["battle"])
		var base_size: float = MapLayout.NODE_SIZE_BOSS if is_boss else MapLayout.NODE_SIZE
		var scale := eased
		if node.id == ctx["hovered_id"] and not node.completed:
			scale *= ctx["hover_scale"]
		var nsize := base_size * scale
		var half := nsize * 0.5
		var tex_idx := 0
		if node.completed:
			tex_idx = 2
		elif node.id == ctx["selected_id"]:
			tex_idx = 2
		elif node.id == ctx["hovered_id"]:
			tex_idx = 1
		var color := Color(1, 1, 1, eased)
		if node.type == DungeonState.RoomType.REST:
			color = Color(0.55, 1.0, 0.6, eased)   # placeholder esverdeado até haver arte
		canvas.draw_texture_rect(textures[tex_idx], Rect2(pos - Vector2.ONE * half, Vector2.ONE * nsize), false, color)
		if not is_boss and ctx["node_icons"].has(node.type):
			var icon: Texture2D = ctx["node_icons"][node.type]
			var icon_size := NODE_ICON_SIZE * scale
			var icon_half := icon_size * 0.5
			canvas.draw_texture_rect(icon, Rect2(pos - Vector2.ONE * icon_half, Vector2.ONE * icon_size), false, color)
		if node.id == ctx["selected_id"] and ctx["available_ids"].has(node.id) and not node.completed:
			canvas.draw_arc(pos, half + 3.0, 0.0, TAU, 48, Color(0.90, 0.78, 0.20), 3.0)
