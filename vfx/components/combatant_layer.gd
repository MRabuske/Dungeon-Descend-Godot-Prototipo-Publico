class_name CombatantLayer
extends Node2D

# ======================================================
# Camada que sincroniza a transform (zoom + pan) do canvas
# com os CombatantNodes, mantendo os sprites sempre
# sobrepostos corretamente aos tiles mesmo ao dar zoom/pan.
#
# COMO FUNCIONA:
#   O BattleArea usa draw_set_transform(pivot*(1-zoom)+pan, 0, zoom)
#   no _draw(). Este nó replica exatamente essa transform
#   a cada frame, então os Sprite2D ficam no mesmo espaço
#   visual que o canvas desenhado.
#
# SETUP em battle_area.gd:
#   var _combatant_layer: CombatantLayer
#
#   func setup(...):
#       _combatant_layer = CombatantLayer.new()
#       add_child(_combatant_layer)   # filho do BattleArea
#       _combatant_layer.battle_area = self
#
#   E no _draw(), logo após draw_set_transform:
#       _combatant_layer.sync_transform(pivot, _zoom, _pan_offset)
#
# Os CombatantNodes são filhos desta camada.
# ======================================================

var battle_area: Control = null  # referência ao BattleArea

func _ready() -> void:
	# Combatentes ficam entre o chão e os objetos
	z_index = 1

# ======================================================
# PUBLIC — chame DENTRO do _draw() do BattleArea,
# logo após draw_set_transform(), com os mesmos parâmetros.
# ======================================================

func sync_transform(pivot: Vector2, zoom: float, pan_offset: Vector2) -> void:
	# Replica: draw_set_transform(pivot*(1-zoom)+pan, 0, zoom)
	var _translate := pivot * (1.0 - zoom) + pan_offset
	transform = Transform2D(0.0, Vector2(zoom, zoom), 0.0, _translate)

# ======================================================
# HELPERS — criação e acesso a CombatantNodes
# ======================================================
func add_combatant_node(node: CombatantNode) -> void:
	add_child(node)

func get_combatant_node(idx: int) -> CombatantNode:
	if idx < 0 or idx >= get_child_count():
		return null
	return get_child(idx) as CombatantNode

func clear_all() -> void:
	for child in get_children():
		child.queue_free()

# ======================================================
# NOVO MÉTODO: Criar combatentes a partir do state
# ======================================================
func create_combatants_from_state(state: BattleState) -> Array[CombatantNode]:
	# Limpa existentes
	for child in get_children():
		child.queue_free()

	var nodes: Array[CombatantNode] = []

	for i in range(state.combatant_positions.size()):
		var combatant: Dictionary = BattleState.TURN_QUEUE[i].duplicate()

		if combatant.get("is_player", false):
			var hero_name: String = combatant.get("name", "")
			if BattleState.ALL_HERO_DATA.has(hero_name):
				var hero_data: HeroData = BattleState.ALL_HERO_DATA[hero_name]
				combatant.merge(hero_data.to_combat_dict(), true)
		else:
			var enemy_type: String = combatant.get("type", "")
			if BattleState.ALL_ENEMIES.has(enemy_type):
				var enemy_data: EnemyData = BattleState.ALL_ENEMIES[enemy_type]
				combatant.merge(enemy_data.to_combat_dict(), true)

		var sprite: Texture2D = SpriteProvider.get_combatant_sprite(combatant, i)

		var node := CombatantNode.new()
		node.setup(
			i,
			combatant,
			sprite if sprite else SpriteProvider.create_fallback_texture(combatant, i)
		)

		add_combatant_node(node)
		nodes.append(node)

	return nodes

# ======================================================
# NOVO MÉTODO: Sincronizar posições visuais dos combatentes
# ======================================================
func sync_visual_positions(state: BattleState, visual_positions: Array, offset: Vector2) -> void:
	# Atualiza o array de posições visuais
	visual_positions.clear()
	for pos in state.combatant_positions:
		visual_positions.append(Vector2(pos))
	
	var nodes := get_children()
	if nodes.is_empty():
		return
	
	for i in range(min(visual_positions.size(), nodes.size())):
		var node := nodes[i] as CombatantNode
		if not node:
			continue
			
		if state.dead_indices.has(i):
			node.visible = false
			continue
		
		node.visible = true
		
		var canvas_pos := _tile_center_f(
			visual_positions[i].x,
			visual_positions[i].y,
			offset
		)
		
		var pos_x := int(round(visual_positions[i].x))
		var pos_y := int(round(visual_positions[i].y))
		var is_elevated := false
		if pos_x >= 0 and pos_x < state.grid_cols and pos_y >= 0 and pos_y < state.grid_rows:
			var tile: TerrainTile = state.tile_data_map[pos_x][pos_y]
			is_elevated = tile.ground == TerrainTile.GroundType.ELEVATED
		
		node.update_canvas_position(canvas_pos, is_elevated)
		node.z_index = pos_x + pos_y

# ======================================================
# HELPER: Calcula centro do tile isométrico (float)
# ======================================================
func _tile_center_f(col: float, row: float, offset: Vector2) -> Vector2:
	const TILE_HALF_W := 36.0
	const TILE_HALF_H := 18.0
	return offset + Vector2((col - row) * TILE_HALF_W, (col + row) * TILE_HALF_H) + Vector2(0.0, TILE_HALF_H)

# ======================================================
# NOVO: Atualizar UI de todos os combatentes
# ======================================================
func update_all_combatant_ui(state: BattleState) -> void:
	var nodes := get_children()
	for i in range(min(state.combatant_positions.size(), nodes.size())):
		if state.dead_indices.has(i):
			continue
		
		var node := nodes[i] as CombatantNode
		if not node:
			continue
		
		var combatant: Dictionary = BattleState.TURN_QUEUE[i]
		
		if combatant["is_player"]:
			var player_idx := _find_player_index(combatant["name"])
			if player_idx >= 0:
				var player: Dictionary = BattleState.PLAYERS[player_idx]
				node.update_hp(player["hp"], player["max_hp"])
		else:
			var cname: String = combatant["name"]
			var hp: int = state.enemy_hp.get(cname, 0)
			var max_hp: int = state.get_enemy_max_hp(i)
			node.update_hp(hp, max_hp)
		
		if i < state.combatant_statuses.size():
			node.update_status(state.combatant_statuses[i])

# ======================================================
# NOVO: Atualizar HP de um combatente específico
# ======================================================
func update_single_combatant_hp(idx: int, hp: int, max_hp: int) -> void:
	var nodes := get_children()
	if idx < nodes.size():
		var node := nodes[idx] as CombatantNode
		if node:
			node.update_hp(hp, max_hp)

# ======================================================
# HELPER PRIVADO
# ======================================================
func _find_player_index(player_name: String) -> int:
	for i in range(BattleState.PLAYERS.size()):
		if BattleState.PLAYERS[i]["name"] == player_name:
			return i
	return -1

# ======================================================
# WRAPPERS DE ANIMAÇÃO
# ======================================================

func get_node_at(idx: int) -> CombatantNode:
	var nodes := get_children()
	if idx >= 0 and idx < nodes.size():
		return nodes[idx] as CombatantNode
	return null

func play_attack_animation(idx: int, target_canvas_pos: Vector2, 
						   on_impact: Callable, on_done: Callable) -> void:
	var node := get_node_at(idx)
	if node:
		node.play_attack_animation(target_canvas_pos, on_impact, on_done)

func play_move_animation(idx: int, canvas_path: Array[Vector2],
						 on_step: Callable, on_done: Callable) -> void:
	var node := get_node_at(idx)
	if node:
		node.play_move_animation(canvas_path, on_step, on_done)

func show_hit_flash(idx: int) -> void:
	var node := get_node_at(idx)
	if node:
		node.play_hit_flash(Color.WHITE)

func start_death_animation(idx: int, on_done: Callable) -> void:
	var node := get_node_at(idx)
	if node:
		node.play_death(on_done)

func show_hit_reaction(idx: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	var node := get_node_at(idx)
	if node:
		node.play_hit_reaction(knockback_dir)

func set_outline(idx: int, active: bool, color: Color = Color(1.0, 0.85, 0.0)) -> void:
	var node := get_node_at(idx)
	if node:
		node.set_outline(active, color)

func set_ui_visible(idx: int, visible_state: bool) -> void:
	var node := get_node_at(idx)
	if node:
		node.set_ui_visible(visible_state)

func trigger_attack_vfx(target_pos: Vector2, is_crit: bool, slash_dir: float = 0.0) -> void:
	if not VfxManager:
		return

	var screen_pos := canvas_to_screen(target_pos)

	# Slash VFX com direção (corpo a corpo)
	VfxManager.spawn(VFXEvent.Type.SLASH_LIGHT, screen_pos, slash_dir)

	# Impact VFX
	if is_crit:
		VfxManager.spawn(VFXEvent.Type.IMPACT_CRIT, screen_pos)
	else:
		VfxManager.spawn(VFXEvent.Type.IMPACT_LIGHT, screen_pos)

	# Efeitos globais
	_apply_impact_effects(is_crit)

func trigger_impact_vfx(target_pos: Vector2, is_crit: bool) -> void:
	if not VfxManager:
		return

	var screen_pos := canvas_to_screen(target_pos)

	# Apenas Impact VFX (ranged)
	if is_crit:
		VfxManager.spawn(VFXEvent.Type.IMPACT_CRIT, screen_pos)
	else:
		VfxManager.spawn(VFXEvent.Type.IMPACT_LIGHT, screen_pos)

	# Efeitos globais
	_apply_impact_effects(is_crit)

func trigger_aoe_vfx(target_pos: Vector2, _radius: int) -> void:
	if not VfxManager:
		return

	var screen_pos := canvas_to_screen(target_pos)
	
	# Impacto central mais forte
	VfxManager.spawn(VFXEvent.Type.IMPACT_CRIT, screen_pos)
	
	# Efeitos globais (mais intensos para AoE)
	var scene := get_tree().current_scene
	if scene:
		for child in scene.get_children():
			if child is CameraShake:
				child.add_trauma(0.55)
			elif child is ScreenFlash:
				child.flash_white(0.07)
	
	if HitStop:
		HitStop.trigger_medium()

func _apply_impact_effects(is_crit: bool) -> void:
	# Camera Shake
	var scene := get_tree().current_scene
	if scene:
		for child in scene.get_children():
			if child is CameraShake:
				child.add_trauma(0.60 if is_crit else 0.35)
			elif child is ScreenFlash:
				if is_crit:
					child.flash_white(0.10)
				else:
					child.flash_white(0.05)
	
	# HitStop
	if HitStop:
		if is_crit:
			HitStop.trigger_heavy()
		else:
			HitStop.trigger_light()

# Converte posição canvas para screen space
# (o que o draw_set_transform faz visualmente)
func canvas_to_screen(canvas_pos: Vector2) -> Vector2:
	if not battle_area:
		return canvas_pos
	var pivot: Vector2      = battle_area.size * 0.5
	var zoom: float         = battle_area._zoom
	var pan: Vector2        = battle_area._pan_offset
	# Replica exatamente o draw_set_transform:
	# screen = canvas * zoom + (pivot * (1 - zoom) + pan)
	var _translate: Vector2   = pivot * (1.0 - zoom) + pan
	var screen_pos: Vector2  = canvas_pos * zoom + _translate
	# Converte de local do BattleArea para global
	return battle_area.global_position + screen_pos
