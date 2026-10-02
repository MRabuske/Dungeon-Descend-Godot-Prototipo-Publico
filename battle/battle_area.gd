class_name BattleArea
extends Control

const TILE_HALF_W := 36.0
const TILE_HALF_H := 18.0
const BG_COLOR            := Color(0.07, 0.08, 0.12)
const GRID_LINE_COLOR     := Color(0.35, 0.37, 0.50, 0.5)
const ACTIVE_TILE_FILL    := Color(1.0, 0.85, 0.0, 0.25)
const ACTIVE_TILE_BORDER  := Color(1.0, 0.85, 0.0, 0.9)
const REACHABLE_COLOR     := Color(0.20, 0.50, 1.0, 0.18)
const MOVE_CURSOR_FILL    := Color(1.0, 1.0, 1.0, 0.30)
const MOVE_CURSOR_BORDER  := Color(1.0, 1.0, 1.0, 0.90)
const ATTACK_AREA_COLOR    := Color(1.0, 0.30, 0.15, 0.18)
const ATTACK_TARGET_COLOR  := Color(1.0, 0.25, 0.15, 0.30)
const ATTACK_CURSOR_FILL   := Color(1.0, 0.30, 0.15, 0.30)
const ATTACK_CURSOR_BORDER := Color(1.0, 0.50, 0.35, 0.90)
const HEAL_AREA_COLOR      := Color(0.20, 1.0, 0.40, 0.18)
const HEAL_TARGET_COLOR    := Color(0.20, 1.0, 0.40, 0.30)
const HEAL_CURSOR_FILL     := Color(0.25, 1.0, 0.45, 0.30)
const HEAL_CURSOR_BORDER   := Color(0.30, 1.0, 0.50, 0.90)
const LOS_RED              := Color(1.0, 0.15, 0.15, 0.22)
const JUMP_ARC_COLOR       := Color(0.5, 0.9, 1.0, 0.9)
const JUMP_LAND_COLOR      := Color(0.5, 0.9, 1.0, 0.5)
const JUMP_AREA_COLOR      := Color(0.5, 0.9, 1.0, 0.12)

signal tile_clicked(grid_pos: Vector2i)
signal tile_hovered(grid_pos: Vector2i)
# Emitted while in ATTACK_MODE when the hovered valid target changes.
# Carries the TURN_QUEUE index of the target, or -1 when none is hovered.
signal attack_hover_changed(combatant_idx: int)

const MAX_PAN := 320.0

const ANIM_PROJECTILE_DUR     := 0.18
const ANIM_AOE_PROJECTILE_DUR := 0.20
const ANIM_AOE_LUNGE_FWD      := 0.09
const ANIM_AOE_LUNGE_BCK      := 0.10
const ANIM_AOE_FADE_DUR       := 0.42
const ANIM_CASCADE_STEP_DELAY := 0.025

var _state: BattleState
var _active_index: int = 0
var _visual_positions: Array[Vector2] = []
var _spawn_markers_visible: bool = false
var _show_los_overlay: bool = false
var _los_tiles: Dictionary = {}
var _hero_spawns: Array[Vector2i] = []
var _enemy_spawns: Array[Vector2i] = []
var _projectile_active: bool = false
var _projectile_pos: Vector2 = Vector2.ZERO
var _projectile_color: Color = Color.WHITE

var _pan_offset: Vector2 = Vector2.ZERO
var _is_panning: bool = false
var _pan_start_mouse: Vector2 = Vector2.ZERO
var _pan_start_offset: Vector2 = Vector2.ZERO
var _left_dragged: bool = false

const PAN_DRAG_THRESHOLD := 6.0

var _hovered_grid: Vector2i = Vector2i(-1, -1)

# Hit-chance hover preview (shown in ATTACK_MODE over a valid target)
# Element A — minimal over-sprite preview: action icon + hit %.
var _hit_preview: Control = null
var _hit_chance_lbl: Label = null
var _hit_icon_rect: TextureRect = null
var _hit_advdis_lbl: Label = null
var _hit_preview_target: int = -1

# Aviso de Ataque de Oportunidade (mostrado em MOVE_MODE sobre o tile de destino).
var _oa_warn_lbl: Label = null

var _zoom: float = 1.0
const ZOOM_MIN := 0.45
const ZOOM_MAX := 2.50
const ZOOM_STEP := 0.12

var _pulse_time: float = 0.0
var _aoe_blast: Dictionary = {}

var use_terrain_textures: bool = true

var _ground_textures: Dictionary = {}
var _object_textures: Dictionary = {}
var _effect_textures: Dictionary = {}
var _void_textures: Dictionary = {}

var current_void_theme: int = VoidTheme.ThemeType.ABYSS
var _void_effects: Dictionary = {}

var _combatant_layer: CombatantLayer

var _terrain_object_layer: TerrainObjectLayer

var _first_frame_synced: bool = false

var _floater_mgr:     FloaterManager = null

var _last_hit_direction: Dictionary = {}

func load_terrain_textures() -> void:
	print("Carregando texturas do terreno...")
	
	var ground_textures = {
		TerrainTile.GroundType.NORMAL: "res://assets/textures/terrain/normal.png",
		TerrainTile.GroundType.MUD: "res://assets/textures/terrain/mud.png",
		TerrainTile.GroundType.STONE: "res://assets/textures/terrain/stone.png",
		TerrainTile.GroundType.GRASS: "res://assets/textures/terrain/grass.png",
		TerrainTile.GroundType.ELEVATED: "res://assets/textures/terrain/elevated.png",
	}
	
	for key in ground_textures:
		var path = ground_textures[key]
		if ResourceLoader.exists(path):
			_ground_textures[key] = load(path)
			print("✓ Textura de chão carregada: ", path)
		else:
			print("✗ Textura não encontrada: ", path)
	
	var object_textures = {
		TerrainTile.ObjectType.STATUE: "res://assets/textures/terrain/statue.png",
		TerrainTile.ObjectType.OBSTACLE: "res://assets/textures/terrain/obstacle.png",
		TerrainTile.ObjectType.COVER: "res://assets/textures/terrain/cover.png",
	}
	
	for key in object_textures:
		var path = object_textures[key]
		if ResourceLoader.exists(path):
			_object_textures[key] = load(path)
			print("✓ Textura de objeto carregada: ", path)
		else:
			print("✗ Textura não encontrada: ", path)
	
	var effect_textures = {
		TerrainTile.EffectType.TRAP_ACTIVE: "res://assets/textures/terrain/trap_active.png",
	}
	
	for key in effect_textures:
		var path = effect_textures[key]
		if ResourceLoader.exists(path):
			_effect_textures[key] = load(path)
			print("✓ Textura de efeito carregada: ", path)
		else:
			print("✗ Textura não encontrada: ", path)
	
	var void_textures = {
		VoidTheme.ThemeType.ABYSS: "res://assets/textures/terrain/void/void_abyss.png",
		VoidTheme.ThemeType.FIRE: "res://assets/textures/terrain/void/void_fire.png",
		VoidTheme.ThemeType.FOREST: "res://assets/textures/terrain/void/void_forest.png",
		VoidTheme.ThemeType.ICE: "res://assets/textures/terrain/void/void_ice.png",
		VoidTheme.ThemeType.HOLY: "res://assets/textures/terrain/void/void_holy.png",
		VoidTheme.ThemeType.POISON: "res://assets/textures/terrain/void/void_poison.png",
	}

	for key in void_textures:
		var path = void_textures[key]
		if ResourceLoader.exists(path):
			_void_textures[key] = load(path)
			print("✓ Textura VOID carregada: ", path)
		else:
			print("✗ Textura VOID não encontrada: ", path)

func set_void_theme(new_theme: int) -> void:
	if current_void_theme == new_theme:
		return
	current_void_theme = new_theme
	for effect in _void_effects.values():
		effect.theme = new_theme
	print("Tema VOID alterado para: ", new_theme)
	queue_redraw()

func get_void_texture() -> Texture2D:
	if _void_textures.has(current_void_theme):
		return _void_textures[current_void_theme]
	return _void_textures.get(VoidTheme.ThemeType.ABYSS, null)

func get_ground_texture(ground_type: int) -> Texture2D:
	if _ground_textures.has(ground_type):
		return _ground_textures[ground_type]
	
	var color: Color
	match ground_type:
		TerrainTile.GroundType.NORMAL: color = Color(0.35, 0.55, 0.25)
		TerrainTile.GroundType.MUD: color = Color(0.45, 0.35, 0.20)
		TerrainTile.GroundType.STONE: color = Color(0.60, 0.55, 0.50)
		TerrainTile.GroundType.GRASS: color = Color(0.30, 0.50, 0.20)
		_: color = Color(0.35, 0.35, 0.35)
	
	return _create_colored_texture(color)

func get_object_texture(object_type: int) -> Texture2D:
	if _object_textures.has(object_type):
		return _object_textures[object_type]
	
	var color: Color
	match object_type:
		TerrainTile.ObjectType.STATUE: color = Color(0.70, 0.60, 0.50)
		TerrainTile.ObjectType.OBSTACLE: color = Color(0.40, 0.35, 0.30)
		TerrainTile.ObjectType.COVER: color = Color(0.25, 0.45, 0.20)
		_: color = Color(0.50, 0.45, 0.40)
	
	return _create_colored_texture(color)

func get_effect_texture(effect_type: int) -> Texture2D:
	if _effect_textures.has(effect_type):
		return _effect_textures[effect_type]
	
	var color: Color
	match effect_type:
		TerrainTile.EffectType.TRAP_ACTIVE: color = Color(0.80, 0.20, 0.15)
		_: color = Color(0.80, 0.30, 0.20)
	
	return _create_colored_texture(color)

func _create_colored_texture(color: Color) -> Texture2D:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return ImageTexture.create_from_image(image)

func _get_object_size_by_type(object_type: int) -> Vector2:
	match object_type:
		TerrainTile.ObjectType.STATUE:
			return Vector2(48, 64)
		TerrainTile.ObjectType.OBSTACLE:
			return Vector2(56, 64)
		TerrainTile.ObjectType.COVER:
			return Vector2(56, 38)
		_:
			return Vector2(48, 48)

func setup(state: BattleState) -> void:
	_state = state
	# ===== NOVO: Inicializar FloaterManager =====
	if _floater_mgr == null:
		_floater_mgr = FloaterManager.new()
		_floater_mgr.setup(self)
		add_child(_floater_mgr)
		print("DEBUG: FloaterManager inicializado como filho de BattleArea")
	# ============================================
	_hero_spawns = state.hero_spawns
	_enemy_spawns = state.enemy_spawns
	_spawn_markers_visible = true
	
	load_terrain_textures()
	_terrain_object_layer = TerrainObjectLayer.new()
	_terrain_object_layer.battle_area = self
	add_child(_terrain_object_layer)
	
	# Inicializa camada de combatentes
	_combatant_layer = CombatantLayer.new()
	_combatant_layer.battle_area = self
	_combatant_layer.y_sort_enabled = true
	add_child(_combatant_layer)
	
	# Cria CombatantNodes para todos os combatentes
	call_deferred("_create_terrain_objects_delegated")
	_combatant_layer.create_combatants_from_state(_state)
	_combatant_layer.sync_visual_positions(_state, _visual_positions, _get_offset())
	
	# Inicializa HP e status de todos os combatentes
	_combatant_layer.update_all_combatant_ui(_state)
	
	mouse_exited.connect(func() -> void:
		_hovered_grid = Vector2i(-1, -1)
		tile_hovered.emit(Vector2i(-1, -1))
		_update_hit_preview()
		queue_redraw()
	)
	_build_hit_preview_panel()
	_build_oa_warn_label()
	_initialize_void_effects()
	call_deferred("_initial_sync")

func _initial_sync() -> void:
	_combatant_layer.sync_visual_positions(_state, _visual_positions, _get_offset())
	_combatant_layer.update_all_combatant_ui(_state)
	queue_redraw()

func inject_vfx_references(cam_shake: CameraShake, scr_flash: ScreenFlash) -> void:
	_combatant_layer.camera_shake = cam_shake
	_combatant_layer.screen_flash = scr_flash

func _process(delta: float) -> void:
	_pulse_time += delta * 1.8
	for effect in _void_effects.values():
		effect.update(delta)
	if not _first_frame_synced and _combatant_layer.get_child_count() > 0:
		_combatant_layer.sync_visual_positions(_state, _visual_positions, _get_offset())
		_first_frame_synced = true
	# Hide the hit preview whenever we are no longer choosing an attack target.
	if _hit_preview != null and _hit_preview.visible:
		if _state == null or _state.current_state != BattleState.State.ATTACK_MODE:
			_hit_preview.visible = false
			_set_hover_target(-1)
	# Esconde o aviso de OA fora do MOVE_MODE e fora da mira do Pulo (ATTACK_MODE).
	if _oa_warn_lbl != null and _oa_warn_lbl.visible:
		var in_jump := _state != null and _state.current_state == BattleState.State.ATTACK_MODE \
			and _state._current_action is AcaoPular
		if _state == null or (_state.current_state != BattleState.State.MOVE_MODE and not in_jump):
			_oa_warn_lbl.visible = false
	queue_redraw()

# Element A — minimal preview floating over the enemy sprite: just the action
# icon and the hit-chance %. No name, HP or elaborate border (BG3 style).
func _build_hit_preview_panel() -> void:
	if _hit_preview != null:
		return
	_hit_preview = HBoxContainer.new()
	_hit_preview.visible = false
	_hit_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hit_preview.z_index = 100
	(_hit_preview as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
	(_hit_preview as HBoxContainer).add_theme_constant_override("separation", 4)

	# Icon to the LEFT of the percentage — roughly the text height.
	# EXPAND_IGNORE_SIZE makes it honor custom_minimum_size instead of the
	# texture's (much larger) natural size.
	_hit_icon_rect = TextureRect.new()
	_hit_icon_rect.custom_minimum_size = Vector2(18, 18)
	_hit_icon_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_hit_icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_hit_icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_hit_icon_rect.visible = false
	_hit_preview.add_child(_hit_icon_rect)

	var text_col := VBoxContainer.new()
	text_col.alignment = BoxContainer.ALIGNMENT_CENTER
	text_col.add_theme_constant_override("separation", 0)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hit_chance_lbl = Label.new()
	_hit_chance_lbl.add_theme_font_size_override("font_size", 13)
	_hit_chance_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hit_chance_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hit_chance_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_hit_chance_lbl.add_theme_constant_override("outline_size", 4)
	text_col.add_child(_hit_chance_lbl)

	_hit_advdis_lbl = Label.new()
	_hit_advdis_lbl.add_theme_font_size_override("font_size", 10)
	_hit_advdis_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hit_advdis_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_hit_advdis_lbl.add_theme_constant_override("outline_size", 3)
	_hit_advdis_lbl.visible = false
	text_col.add_child(_hit_advdis_lbl)

	_hit_preview.add_child(text_col)

	add_child(_hit_preview)

func _build_oa_warn_label() -> void:
	if _oa_warn_lbl != null:
		return
	_oa_warn_lbl = Label.new()
	_oa_warn_lbl.visible = false
	_oa_warn_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_oa_warn_lbl.z_index = 100
	_oa_warn_lbl.text = "⚠ Ataque de Oportunidade!"
	_oa_warn_lbl.add_theme_font_size_override("font_size", 12)
	_oa_warn_lbl.add_theme_color_override("font_color", Color(1.0, 0.55, 0.15))
	_oa_warn_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	_oa_warn_lbl.add_theme_constant_override("outline_size", 4)
	add_child(_oa_warn_lbl)

# Refreshes the over-sprite preview (Element A) and notifies listeners (Element B)
# via attack_hover_changed. Shows over a valid enemy target while in ATTACK_MODE.
func _update_hit_preview() -> void:
	if _state == null or _hit_preview == null:
		return
	if _state.current_state != BattleState.State.ATTACK_MODE:
		_hit_preview.visible = false
		_set_hover_target(-1)
		return

	# Find a living combatant under the hovered tile that is a valid attack target.
	var cidx := -1
	for i in range(_state.TURN_QUEUE.size()):
		if _state.combatant_positions[i] == _hovered_grid and not _state.dead_indices.has(i):
			cidx = i
			break
	if cidx < 0 or not _state.attack_target_indices.has(cidx):
		_hit_preview.visible = false
		_set_hover_target(-1)
		return

	# Selected action icon
	var action := _state.get_current_action()
	if action != null and action.has_icon():
		_hit_icon_rect.texture = action.icon
		_hit_icon_rect.visible = true
	else:
		_hit_icon_rect.visible = false

	# Hit chance + Advantage/Disadvantage (BG3 style)
	var chance := _state.calc_hit_chance(cidx)
	var pidx := _state.get_active_player_index()
	var adv := 0
	var dis := 0
	if pidx >= 0:
		var rm: Dictionary = _state.get_attack_roll_mods(pidx, cidx, _state.current_attack_range)
		adv = int(rm.get("adv", 0))
		dis = int(rm.get("dis", 0))

	if chance >= 1.0:
		_hit_chance_lbl.text = "100%"
	else:
		_hit_chance_lbl.text = "%d%%" % int(round(chance * 100.0))

	# Vantagem e Desvantagem simultâneas se cancelam → tratar como neutro.
	if adv > 0 and dis == 0:
		_hit_chance_lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 0.3))
		_hit_advdis_lbl.text = "Vantagem"
		_hit_advdis_lbl.add_theme_color_override("font_color", Color(0.3, 0.95, 0.3))
		_hit_advdis_lbl.visible = true
	elif dis > 0 and adv == 0:
		_hit_chance_lbl.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
		_hit_advdis_lbl.text = "Desvantagem"
		_hit_advdis_lbl.add_theme_color_override("font_color", Color(0.95, 0.3, 0.3))
		_hit_advdis_lbl.visible = true
	else:
		_hit_chance_lbl.add_theme_color_override("font_color", Color.WHITE)
		_hit_advdis_lbl.visible = false

	# Position above the hovered tile, accounting for zoom/pan transform.
	_hit_preview.visible = true
	_hit_preview.reset_size()
	var canvas_pos := _tile_center_f(_hovered_grid.x, _hovered_grid.y, _get_offset())
	var pivot: Vector2 = size * 0.5
	var translate: Vector2 = pivot * (1.0 - _zoom) + _pan_offset
	var screen_pos: Vector2 = canvas_pos * _zoom + translate
	var psize := _hit_preview.size
	_hit_preview.position = screen_pos - Vector2(psize.x * 0.5, psize.y + 56.0 * _zoom)

	_set_hover_target(cidx)

# Emits attack_hover_changed only when the hovered target actually changes.
func _set_hover_target(cidx: int) -> void:
	if cidx == _hit_preview_target:
		return
	_hit_preview_target = cidx
	attack_hover_changed.emit(cidx)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					_zoom = clampf(_zoom + ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
					queue_redraw()
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					_zoom = clampf(_zoom - ZOOM_STEP, ZOOM_MIN, ZOOM_MAX)
					queue_redraw()
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					# Botao esquerdo: inicia um possivel pan. So vira pan de fato
					# se arrastar alem do threshold; senao, no release, conta como
					# clique no tile sob o cursor.
					_is_panning = true
					_left_dragged = false
					_pan_start_mouse  = mb.position
					_pan_start_offset = _pan_offset
				else:
					if _is_panning and not _left_dragged and _state != null:
						var gp := _screen_to_grid(mb.position)
						if gp.x >= 0 and gp.x < _state.grid_cols \
						and gp.y >= 0 and gp.y < _state.grid_rows:
							tile_clicked.emit(gp)
					_is_panning = false
					_left_dragged = false
					mouse_default_cursor_shape = Control.CURSOR_ARROW
	elif event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _is_panning:
			var delta: Vector2 = motion.position - _pan_start_mouse
			if not _left_dragged and delta.length() < PAN_DRAG_THRESHOLD:
				return
			if not _left_dragged:
				_left_dragged = true
				mouse_default_cursor_shape = Control.CURSOR_DRAG
			_pan_offset = (_pan_start_offset + delta).clamp(
				Vector2(-MAX_PAN, -MAX_PAN), Vector2(MAX_PAN, MAX_PAN))
			queue_redraw()
		else:
			var gp := _screen_to_grid(motion.position)
			if gp != _hovered_grid:
				_hovered_grid = gp
				tile_hovered.emit(gp)
				_update_hit_preview()
				queue_redraw()
			# No modo Pulo, o aviso "Pulo impossível" acompanha o mouse em tempo real.
			elif _state != null and _state.current_state == BattleState.State.ATTACK_MODE \
					and _state._current_action is AcaoPular:
				queue_redraw()

func refresh(active_index: int) -> void:
	_active_index = active_index
	_spawn_markers_visible = false
	queue_redraw()

func animate_ranged_attack(attacker_idx: int, target_grid: Vector2i, action: ActionData, on_done: Callable, is_crit: bool = false) -> void:
	var offset := _get_offset()
	var target_pos := _tile_center_f(target_grid.x, target_grid.y, offset)
	var from_world := _tile_center_f(
		_visual_positions[attacker_idx].x,
		_visual_positions[attacker_idx].y, offset)
	
	_combatant_layer.play_attack_animation(attacker_idx, target_pos,
		func(): pass,
		func(): pass,
		true
	)
	
	# SFX: Whoosh ao disparar
	if SfxManager:
		if not action.sfx_cast.is_empty():
			SfxManager.play(action.sfx_cast, from_world)
		else:
			SfxManager.play_whoosh(from_world)
	
	# Projétil visual
	var proj: CanvasItem
	if action.projectile_frames:
		var anim := AnimatedSprite2D.new()
		anim.sprite_frames = action.projectile_frames
		anim.scale = action.projectile_scale
		anim.centered = true
		anim.z_index = 10
		anim.play("default")
		proj = anim
	elif action.projectile_texture:
		var sprite := Sprite2D.new()
		sprite.texture = action.projectile_texture
		sprite.scale = action.projectile_scale
		sprite.centered = true
		sprite.z_index = 10
		proj = sprite
	else:
		var rect := ColorRect.new()
		rect.size = Vector2(14, 5)
		rect.color = action.proj_color
		proj = rect

	proj.position = from_world
	proj.rotation = (target_pos - from_world).angle()
	add_child(proj)

	var duration := ANIM_PROJECTILE_DUR / action.projectile_speed
	
	var tween := create_tween()
	tween.tween_property(proj, "position", target_pos, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	tween.tween_callback(func() -> void:
		proj.queue_free()
		
		# Impact VFX (sem slash!)
		_combatant_layer.trigger_impact_vfx(target_pos, is_crit, action.impact_type)
		
		# SFX de impacto
		if SfxManager:
			if not action.sfx_impact.is_empty():
				SfxManager.play(action.sfx_impact, target_pos)
			elif is_crit:
				SfxManager.play_impact_crit(target_pos)
			else:
				SfxManager.play_impact_light(target_pos)
		
		# Hit flash + reaction no alvo
		var target_node := _get_combatant_node_at(target_grid)

		if not target_node:
			var target_idx := -1
			for i in range(_state.combatant_positions.size()):
				if _state.combatant_positions[i] == target_grid:
					target_idx = i
					break
			if target_idx >= 0:
				target_node = _combatant_layer.get_node_at(target_idx)

		if target_node:
			var hit_dir := (target_pos - from_world).normalized()
			var target_idx := -1
			for i in range(_state.combatant_positions.size()):
				if _state.combatant_positions[i] == target_grid:
					target_idx = i
					break
			if target_idx >= 0:
				_last_hit_direction[target_idx] = hit_dir
			var hit_color := Color(1.0, 0.85, 0.3) if is_crit else Color.WHITE
			target_node.play_hit_flash(hit_color)
			target_node.play_hit_reaction(
				(target_pos - from_world).normalized()
			)
		
		on_done.call()

		if target_node and action.damage_type == ActionData.DamageType.FIRE:
			target_node.call_deferred("play_burn", action.impact_vfx_dur)
	)

func animate_aoe_attack(attacker_idx: int, target_grid: Vector2i, action: ActionData, on_done: Callable) -> void:
	print("animate_aoe_attack chamado | impact_type: ", action.impact_type, " | aoe_cascade_type: ", action.aoe_cascade_type)
	var offset := _get_offset()
	var target_pos := _tile_center_f(target_grid.x, target_grid.y, offset)
	var radius := action.aoe_radius
	var is_ranged := action.attack_range > 1
	var proj_color := action.proj_color

	# ── Animação de ataque ──
	_combatant_layer.play_attack_animation(attacker_idx, target_pos,
		func(): pass,
		func(): pass,
		is_ranged
	)

	var aoe_tiles: Array[Vector2i] = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if maxi(absi(dx), absi(dy)) <= radius:
				var tile_pos := Vector2i(target_grid.x + dx, target_grid.y + dy)
				if tile_pos.x >= 0 and tile_pos.x < _state.grid_cols and tile_pos.y >= 0 and tile_pos.y < _state.grid_rows:
					var t: TerrainTile = _state.tile_data_map[tile_pos.x][tile_pos.y]
					if not t.is_void() and t.object != TerrainTile.ObjectType.OBSTACLE:
						aoe_tiles.append(tile_pos)

	var do_explosion := func() -> void:
		
		print("do_explosion | impact_type: ", action.impact_type)
		_combatant_layer.trigger_impact_vfx(target_pos, false, action.impact_type)
		if SfxManager:
			if not action.sfx_impact.is_empty():
				SfxManager.play(action.sfx_impact, target_pos)
			else:
				SfxManager.play_impact_heavy(target_pos)
		_apply_aoe_cascade(aoe_tiles, offset, target_pos, action.impact_type, action)
		_aoe_blast = {"pos": target_grid, "radius": radius, "color": proj_color, "alpha": 1.0}
		queue_redraw()
		var fade_tween := create_tween()
		fade_tween.tween_method(
			func(t: float): _aoe_blast["alpha"] = 1.0 - t; queue_redraw(),
			0.0, 1.0, ANIM_AOE_FADE_DUR
		)
		fade_tween.tween_callback(func():
			_aoe_blast.clear()
			queue_redraw()
			on_done.call()
		)

	var cast_pos := _tile_center_f(_visual_positions[attacker_idx].x, _visual_positions[attacker_idx].y, offset)
	if SfxManager:
		if not action.sfx_cast.is_empty():
			SfxManager.play(action.sfx_cast, cast_pos)
		elif not is_ranged:
			SfxManager.play_whoosh(cast_pos)

	if is_ranged and not action.aoe_instant:
		var from_world := _tile_center_f(_visual_positions[attacker_idx].x, _visual_positions[attacker_idx].y, offset)
		var proj: CanvasItem
		if action.aoe_projectile_frames:
			var anim := AnimatedSprite2D.new()
			anim.sprite_frames = action.aoe_projectile_frames
			anim.scale = action.projectile_scale
			anim.centered = true
			anim.z_index = 10
			anim.play("default")
			proj = anim
		else:
			var rect := ColorRect.new()
			rect.size = Vector2(18, 6)
			rect.color = proj_color
			proj = rect
		
		proj.position = from_world
		proj.rotation = (target_pos - from_world).angle()
		add_child(proj)
		
		var tween := create_tween()
		tween.tween_property(proj, "position", target_pos, ANIM_AOE_PROJECTILE_DUR / action.projectile_speed)
		tween.tween_callback(func(): proj.queue_free(); do_explosion.call())
	else:
		var origin: Vector2 = _visual_positions[attacker_idx]
		var lunge: Vector2 = origin.lerp(Vector2(target_grid), 0.30)
		var tween := create_tween()
		tween.tween_method(
			func(v: Vector2): _visual_positions[attacker_idx] = v; queue_redraw(),
			origin, lunge, ANIM_AOE_LUNGE_FWD
		)
		tween.tween_method(
			func(v: Vector2): _visual_positions[attacker_idx] = v; queue_redraw(),
			lunge, origin, ANIM_AOE_LUNGE_BCK
		)
		tween.tween_callback(func(): do_explosion.call())

func _apply_aoe_cascade(tiles: Array[Vector2i], offset: Vector2, epicenter: Vector2, impact_type: int = -1, action: ActionData = null) -> void:
	for i in tiles.size():
		if not is_inside_tree(): return
		var timer := get_tree().create_timer(i * ANIM_CASCADE_STEP_DELAY)
		await timer.timeout
		if not is_inside_tree() or not is_instance_valid(_combatant_layer): return
		var tile := tiles[i]
		var tw_pos := _tile_center_f(tile.x, tile.y, offset)
		_combatant_layer.trigger_impact_vfx(tw_pos, false, impact_type)
		var target_node := _get_combatant_node_at(tile)
		if target_node:
			var hit_dir := (tw_pos - epicenter).normalized()
			var target_idx := -1
			for j in range(_state.combatant_positions.size()):
				if _state.combatant_positions[j] == tile:
					target_idx = j
					break
			if target_idx >= 0:
				_last_hit_direction[target_idx] = hit_dir
			target_node.play_hit_flash(Color.WHITE)
			target_node.play_hit_reaction((tw_pos - epicenter).normalized())
			if action and action.damage_type == ActionData.DamageType.FIRE:
				target_node.call_deferred("play_burn", action.impact_vfx_dur)

func _draw_aoe_blast(offset: Vector2) -> void:
	if _state == null:
		return
	var center_pos: Vector2i = _aoe_blast["pos"]
	var radius: int = _aoe_blast["radius"]
	var col: Color = _aoe_blast["color"]
	var alpha: float = _aoe_blast["alpha"]
	for c in range(_state.grid_cols):
		for r in range(_state.grid_rows):
			var d: int = maxi(absi(c - center_pos.x), absi(r - center_pos.y))
			if d > radius:
				continue
			var t: TerrainTile = _state.tile_data_map[c][r]
			if t.is_void() or t.object == TerrainTile.ObjectType.OBSTACLE:
				continue
			var falloff := 1.0 - float(d) / float(radius + 1)
			var fill := Color(col.r, col.g, col.b, alpha * falloff * 0.72)
			draw_polygon(_tile_diamond(c, r, offset), PackedColorArray([fill]))
			if d == 0:
				var ring := Color(1.0, 1.0, 1.0, alpha * 0.55)
				var pts := _tile_diamond(c, r, offset)
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), ring, 2.0)

func animate_attack(attacker_idx: int, target_grid: Vector2i, on_done: Callable, is_crit: bool = false) -> void:
	var target_pos := _tile_center_f(target_grid.x, target_grid.y, _get_offset())
	var node := _combatant_layer.get_node_at(attacker_idx) if _combatant_layer else null
	var impact_called := false

	# Fallback se não tiver CombatantNode
	if node == null:
		_fallback_attack(attacker_idx, target_grid, on_done)
		return
	
	# SFX: Whoosh ao iniciar o ataque
	if SfxManager:
		SfxManager.play_whoosh(node.position)
	
	_combatant_layer.play_attack_animation(attacker_idx, target_pos,
		func():
			if not impact_called:

				# ── Frame do impacto ──
				# VFX visual (slash + impacto) com direção
				var slash_dir := (target_pos - node.position).angle()
				_combatant_layer.trigger_attack_vfx(target_pos, is_crit, slash_dir)

				# SFX de impacto
				if SfxManager:
					if is_crit:
						SfxManager.play_impact_crit(target_pos)
					else:
						SfxManager.play_impact_light(target_pos)

				# Hit flash + reaction no alvo
				var target_node := _get_combatant_node_at(target_grid)
				if target_node:
					var hit_dir := (target_pos - node.position).normalized()
					var target_idx := -1
					for i in range(_state.combatant_positions.size()):
						if _state.combatant_positions[i] == target_grid:
							target_idx = i
							break
					if target_idx >= 0:
						_last_hit_direction[target_idx] = hit_dir
					var hit_color := Color(1.0, 0.85, 0.3) if is_crit else Color.WHITE
					target_node.play_hit_flash(hit_color)
					target_node.play_hit_reaction(
						(target_pos - node.position).normalized()
					)
	,
		func(): on_done.call(),
		false
	)

func _fallback_attack(_attacker_idx: int, target_grid: Vector2i, on_done: Callable) -> void:
	# Fallback simples: só chama o callback
	var target_pos := _tile_center_f(target_grid.x, target_grid.y, _get_offset())
	_combatant_layer.trigger_attack_vfx(target_pos, false, 0.0)
	on_done.call()

func show_floater(grid_pos: Vector2i, amount: int, is_heal: bool, is_crit: bool = false,
		color_override: Color = Color(-1, -1, -1)) -> void:
	if _floater_mgr == null:
		return

	var canvas_pos := _tile_center_f(grid_pos.x, grid_pos.y, _get_offset())

	# Converte canvas space → screen space (igual aos VFXs)
	var pivot: Vector2 = size * 0.5
	var zoom: float = _zoom
	var pan: Vector2 = _pan_offset
	var translate: Vector2 = pivot * (1.0 - zoom) + pan
	var screen_pos: Vector2 = canvas_pos * zoom + translate
	var global_pos: Vector2 = global_position + screen_pos

	_floater_mgr.spawn(global_pos, amount, is_heal, is_crit, false, color_override)

# Floats arbitrary text (e.g. "Miss!") above a grid tile, same arc as damage numbers.
func show_text_floater(grid_pos: Vector2i, text: String, color: Color,
		font_size: int = 16, big_scale: bool = false) -> void:
	if _floater_mgr == null:
		return
	var canvas_pos := _tile_center_f(grid_pos.x, grid_pos.y, _get_offset())
	var pivot: Vector2 = size * 0.5
	var translate: Vector2 = pivot * (1.0 - _zoom) + _pan_offset
	var screen_pos: Vector2 = canvas_pos * _zoom + translate
	var global_pos: Vector2 = global_position + screen_pos
	_floater_mgr.spawn_text(global_pos, text, color, font_size, big_scale)

func animate_move(idx: int, path: Array[Vector2i], on_done: Callable) -> void:
	var canvas_path: Array[Vector2] = []
	for tile in path:
		var canvas_pos := _tile_center_f(tile.x, tile.y, _get_offset())
		canvas_path.append(canvas_pos)

	var node := _combatant_layer.get_node_at(idx)
	if not node:
		on_done.call()
		return

	# Callback chamado a cada tile do caminho
	var on_step := func(step_idx: int) -> void:
		if step_idx >= path.size():
			return
		var tile := path[step_idx]
		# Atualiza z_index
		node.z_index = tile.x + tile.y
		# Atualiza elevated
		if tile.x >= 0 and tile.x < _state.grid_cols and tile.y >= 0 and tile.y < _state.grid_rows:
			var terrain: TerrainTile = _state.tile_data_map[tile.x][tile.y]
			var is_elevated := terrain.ground == TerrainTile.GroundType.ELEVATED
			var is_cover := terrain.object == TerrainTile.ObjectType.COVER
			node.update_canvas_position(canvas_path[step_idx], is_elevated)
			node.set_ui_visible(not is_cover)
			if SfxManager:
				var tile_center := _tile_center_f(tile.x, tile.y, _get_offset())
				SfxManager.play("step_stone", tile_center, SfxManager.PITCH_NORMAL, -6.0)

	_combatant_layer.play_move_animation(idx, canvas_path, on_step, func():
		if not path.is_empty():
			_visual_positions[idx] = Vector2(path[-1])
		on_done.call()
	)

func show_hit_flash(idx: int) -> void:
	_combatant_layer.show_hit_flash(idx)

func start_death_animation(idx: int) -> void:
	var node := _combatant_layer.get_node_at(idx) if _combatant_layer else null
	var combatant: Dictionary = BattleState.TURN_QUEUE[idx]
	if combatant.get("is_player", false):
		if SfxManager:
			SfxManager.play_death_hero(node.position if node else Vector2.ZERO)
	else:
		if SfxManager:
			SfxManager.play_death_enemy(node.position if node else Vector2.ZERO)
	
	var death_dir: Vector2 = _last_hit_direction.get(idx, Vector2.ZERO)
	_last_hit_direction.erase(idx)
	
	_combatant_layer.start_death_animation(idx, func():
		if node:
			node.visible = false
	, death_dir)
func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var pivot := size * 0.5
	var world := (screen_pos - (pivot * (1.0 - _zoom) + _pan_offset)) / _zoom
	var off := _get_offset()
	var dx := (world.x - off.x) / TILE_HALF_W
	var dy := (world.y - off.y - TILE_HALF_H) / TILE_HALF_H
	return Vector2i(int(round((dx + dy) / 2.0)), int(round((dy - dx) / 2.0)))

func _get_offset() -> Vector2:
	var cols: int = _state.grid_cols if _state != null else 12
	var rows: int = _state.grid_rows if _state != null else 7
	var total_w: float = (cols + rows) * TILE_HALF_W
	var total_h: float = (cols + rows) * TILE_HALF_H
	var pad := TILE_HALF_H
	return Vector2(
		(size.x - total_w) / 2.0 + rows * TILE_HALF_W,
		maxf((size.y - total_h) / 2.0, pad)
	)

func _iso_to_screen(col: int, row: int, offset: Vector2) -> Vector2:
	return offset + Vector2((col - row) * TILE_HALF_W, (col + row) * TILE_HALF_H)

func _tile_diamond(col: int, row: int, offset: Vector2) -> PackedVector2Array:
	var top := _iso_to_screen(col, row, offset)
	return PackedVector2Array([
		top,
		top + Vector2(TILE_HALF_W, TILE_HALF_H),
		top + Vector2(0.0, TILE_HALF_H * 2.0),
		top + Vector2(-TILE_HALF_W, TILE_HALF_H),
	])

func _tile_center(col: int, row: int, offset: Vector2) -> Vector2:
	return _iso_to_screen(col, row, offset) + Vector2(0.0, TILE_HALF_H)

func _tile_center_f(col: float, row: float, offset: Vector2) -> Vector2:
	return offset + Vector2((col - row) * TILE_HALF_W, (col + row) * TILE_HALF_H) + Vector2(0.0, TILE_HALF_H)

func _draw() -> void:
	var pivot := size * 0.5
	draw_set_transform(pivot * (1.0 - _zoom) + _pan_offset, 0.0, Vector2(_zoom, _zoom))
	
	if _terrain_object_layer:
		_terrain_object_layer.sync_transform(pivot, _zoom, _pan_offset)
	if _combatant_layer:
		_combatant_layer.sync_transform(pivot, _zoom, _pan_offset)
	
	var offset := _get_offset()
	_draw_ground_only(offset)
	_draw_surfaces(offset)
	if _show_los_overlay:
		_draw_los_overlay(offset)

	# REMOVIDO: render queue de objetos e combatentes
	# Os objetos agora são Sprite2D no TerrainObjectLayer
	# Os combatentes são Sprite2D no CombatantLayer
	# A ordenação é feita automaticamente pelo y_sort_enabled
	
	if not _aoe_blast.is_empty():
		_draw_aoe_blast(offset)

	if _state != null:
		for row in range(_state.grid_rows):
			for col in range(_state.grid_cols):
				var tile: TerrainTile = _state.tile_data_map[col][row]
				if tile != null and tile.effect != TerrainTile.EffectType.NONE and tile.effect != TerrainTile.EffectType.TRAP_ACTIVE:
					_draw_effect_layer(col, row, offset, tile.effect)
	
	_draw_hover_highlight(offset)
	_draw_active_highlight(offset)
	
	if _state != null and _state.current_state == BattleState.State.MOVE_MODE:
		_draw_reachable_tiles(offset)
		_draw_move_path(offset)
		_draw_move_cursor(offset)
	
	if _state != null and _state.current_state == BattleState.State.ATTACK_MODE:
		if _state._current_action is AcaoPular:
			_draw_jump_landing(offset)
			_draw_jump_arc(offset)
		else:
			_draw_attack_area(offset)
			_draw_attack_cursor(offset)
			if _state.current_aoe_radius > 0:
				_draw_aoe_splash(offset)
	
	if _spawn_markers_visible:
		_draw_spawn_markers(offset)
	if _projectile_active:
		_draw_projectile(offset)

	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	# Aviso "Pulo impossível" perto do cursor (espaço de tela, após reset de transform).
	if _state != null and _state.current_state == BattleState.State.ATTACK_MODE \
			and _state._current_action is AcaoPular \
			and not _state.is_valid_jump_landing(_state.active_index, _hovered_grid):
		var f := get_theme_default_font()
		var fs := get_theme_default_font_size()
		var at := get_local_mouse_position() + Vector2(14, -10)
		draw_string(f, at + Vector2(1, 1), "Pulo impossível", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0, 0, 0, 0.8))
		draw_string(f, at, "Pulo impossível", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1.0, 0.4, 0.35))

func _draw_surfaces(offset: Vector2) -> void:
	if _state == null:
		return
	for pos in _state.tile_surfaces:
		var s_type: int = _state.tile_surfaces[pos].get("type", SurfaceType.Type.NONE)
		if s_type == SurfaceType.Type.NONE:
			continue
		var tint: Color = SurfaceType.TINT.get(s_type, Color(1, 1, 1, 0.3))
		var diamond := _tile_diamond(pos.x, pos.y, offset)
		draw_polygon(diamond, PackedColorArray([tint]))
		# Contorno destacado para a Nuvem de Adagas (visual mais legível).
		if s_type == SurfaceType.Type.CLOUD_OF_DAGGERS:
			var border := PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]])
			draw_polyline(border, Color(0.8, 0.3, 1.0, 0.9), 1.5)

func _draw_ground_only(offset: Vector2) -> void:
	if _state == null or _state.tile_data_map.is_empty():
		return
	for row in range(_state.grid_rows):
		for col in range(_state.grid_cols):
			var tile: TerrainTile = _state.tile_data_map[col][row]
			if tile == null: 
				continue
			if tile.is_void():
				if _void_effects.has(Vector2i(col, row)):
					_void_effects[Vector2i(col, row)].draw(col, row, offset, self)
				continue
			if tile.effect == TerrainTile.EffectType.TRAP_ACTIVE:
				_draw_trap_as_ground(col, row, offset)
			else:
				var ground_type := tile.ground
				if ground_type == TerrainTile.GroundType.ELEVATED:
					_draw_ground_tile(col, row, offset, TerrainTile.GroundType.NORMAL)
				_draw_ground_tile(col, row, offset, ground_type)

func _draw_trap_as_ground(col: int, row: int, offset: Vector2) -> void:
	var texture := get_effect_texture(TerrainTile.EffectType.TRAP_ACTIVE)
	if texture:
		var diamond := _tile_diamond(col, row, offset)
		var texture_size := texture.get_size()
		var diamond_rect := _get_texture_rect_from_diamond(diamond)
		draw_texture_rect_region(texture, diamond_rect, Rect2(Vector2.ZERO, texture_size))
	else:
		var color := Color(0.55, 0.15, 0.10)
		draw_polygon(_tile_diamond(col, row, offset), PackedColorArray([color]))
		var center := _tile_center(col, row, offset)
		var pulse := sin(_pulse_time * 5) * 0.3 + 0.5
		for i in range(8):
			var angle := i * PI * 2 / 8
			var x := center.x + cos(angle) * 12
			var y := center.y + sin(angle) * 6
			draw_circle(Vector2(x, y), 3, Color(0.8, 0.2, 0.1, pulse))

func _get_texture_rect_from_diamond(diamond: PackedVector2Array) -> Rect2:
	var min_x := diamond[0].x
	var min_y := diamond[0].y
	var max_x := diamond[0].x
	var max_y := diamond[0].y
	for point in diamond:
		min_x = min(min_x, point.x)
		min_y = min(min_y, point.y)
		max_x = max(max_x, point.x)
		max_y = max(max_y, point.y)
	return Rect2(min_x, min_y, max_x - min_x, max_y - min_y)

func _draw_ground_tile(col: int, row: int, offset: Vector2, ground_type: int) -> void:
	var texture := get_ground_texture(ground_type)
	var y_offset := 0.0
	if ground_type == TerrainTile.GroundType.ELEVATED:
		y_offset = -10.0
	if texture and use_terrain_textures:
		var diamond := _tile_diamond(col, row, offset)
		var texture_size := texture.get_size()
		var diamond_rect := _get_texture_rect_from_diamond(diamond)
		diamond_rect.position.y += y_offset
		draw_texture_rect_region(texture, diamond_rect, Rect2(Vector2.ZERO, texture_size))
		if ground_type == TerrainTile.GroundType.ELEVATED:
			var shadow_rect := Rect2(
				diamond_rect.position.x,
				diamond_rect.position.y + diamond_rect.size.y - 4,
				diamond_rect.size.x,
				4
			)
			draw_rect(shadow_rect, Color(0, 0, 0, 0.3))
	else:
		var color: Color
		match ground_type:
			TerrainTile.GroundType.NORMAL: color = Color(0.35, 0.55, 0.25)
			TerrainTile.GroundType.MUD: color = Color(0.45, 0.35, 0.20)
			TerrainTile.GroundType.STONE: color = Color(0.60, 0.55, 0.50)
			TerrainTile.GroundType.GRASS: color = Color(0.30, 0.50, 0.20)
			_: color = Color(0.35, 0.35, 0.35)
		var points := _tile_diamond(col, row, offset)
		for i in range(points.size()):
			points[i].y += y_offset
		draw_polygon(points, PackedColorArray([color]))

func _draw_effect_layer(col: int, row: int, offset: Vector2, effect_type: int) -> void:
	if effect_type == TerrainTile.EffectType.TRAP_ACTIVE:
		var texture := get_effect_texture(effect_type)
		if texture:
			var diamond := _tile_diamond(col, row, offset)
			var texture_size := texture.get_size()
			var diamond_rect := _get_texture_rect_from_diamond(diamond)
			draw_texture_rect_region(texture, diamond_rect, Rect2(Vector2.ZERO, texture_size))
		else:
			var center := _tile_center(col, row, offset)
			var pulse := sin(_pulse_time * 5) * 0.3 + 0.5
			draw_circle(center, 12, Color(0.9, 0.2, 0.1, pulse))

func _draw_hover_highlight(offset: Vector2) -> void:
	if _state == null:
		return
	var gp := _hovered_grid
	if gp.x < 0 or gp.x >= _state.grid_cols or gp.y < 0 or gp.y >= _state.grid_rows:
		return
	var tile: TerrainTile = _state.tile_data_map[gp.x][gp.y]
	if tile == null or tile.is_void():
		return
	var pts := _tile_diamond(gp.x, gp.y, offset)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		Color(1.0, 1.0, 1.0, 0.28), 1.5)

func _draw_move_path(offset: Vector2) -> void:
	if _state == null:
		return
	# Preview de trajeto: a linha segue a tile sob o mouse enquanto ela for
	# alcancavel. Se o mouse nao estiver sobre uma tile valida (ex.: navegacao
	# por teclado), cai de volta para o cursor de movimento.
	var target: Vector2i = _state.move_cursor
	if _hovered_grid.x >= 0 and _state.get_reachable_tiles().has(_hovered_grid):
		target = _hovered_grid
	# Aviso preemptivo de Ataque de Oportunidade (BG3): se mover o personagem
	# para o tile hovereado o tiraria do alcance corpo-a-corpo de um inimigo
	# com reação, marca o destino em laranja e mostra um aviso. Não bloqueia.
	var mover := _state.active_index
	var cur_pos: Vector2i = _state.combatant_positions[mover]
	var provokes := false
	if _hovered_grid.x >= 0 and _hovered_grid != cur_pos and _state.get_reachable_tiles().has(_hovered_grid):
		provokes = not _state.check_opportunity_attacks(mover, cur_pos, _hovered_grid).is_empty()
	if provokes:
		var warn_pts := _tile_diamond(target.x, target.y, offset)
		draw_polygon(warn_pts, PackedColorArray([Color(1.0, 0.45, 0.10, 0.30)]))
		draw_polyline(PackedVector2Array([warn_pts[0], warn_pts[1], warn_pts[2], warn_pts[3], warn_pts[0]]),
			Color(1.0, 0.55, 0.15, 0.95), 2.0)
		var warn_center := _tile_center(target.x, target.y, offset)
		_oa_warn_lbl.reset_size()
		_oa_warn_lbl.position = warn_center - Vector2(_oa_warn_lbl.size.x * 0.5, _oa_warn_lbl.size.y + 26.0)
		_oa_warn_lbl.visible = true
	else:
		_oa_warn_lbl.visible = false
	var path: Array[Vector2i] = _state.get_path_to(target)
	if path.is_empty():
		return
	var origin: Vector2i = _state.combatant_positions[_state.active_index]
	var prev := _tile_center(origin.x, origin.y, offset)
	for i in range(path.size()):
		var tile := path[i]
		var center := _tile_center(tile.x, tile.y, offset)
		draw_line(prev, center, Color(0.60, 0.82, 1.0, 0.50), 2.0)
		var is_last := i == path.size() - 1
		draw_circle(center,
			5.5 if is_last else 3.0,
			Color(0.65, 0.88, 1.0, 0.88) if is_last else Color(0.60, 0.82, 1.0, 0.55))
		prev = center

func _draw_active_highlight(offset: Vector2) -> void:
	if _state == null or _active_index < 0 or _active_index >= _state.combatant_positions.size():
		return
	if _state.dead_indices.has(_active_index):
		return
	var pos: Vector2i = _state.combatant_positions[_active_index]
	var tile: TerrainTile = _state.tile_data_map[pos.x][pos.y]
	if tile == null or tile.is_void():
		return
	var pulse := sin(_pulse_time) * 0.5 + 0.5
	var pts := _tile_diamond(pos.x, pos.y, offset)
	var fill := Color(ACTIVE_TILE_FILL.r, ACTIVE_TILE_FILL.g, ACTIVE_TILE_FILL.b,
		0.16 + pulse * 0.12)
	var border := Color(ACTIVE_TILE_BORDER.r, ACTIVE_TILE_BORDER.g, ACTIVE_TILE_BORDER.b,
		0.65 + pulse * 0.25)
	draw_polygon(pts, PackedColorArray([fill]))
	draw_polyline(
		PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		border, 2.0
	)

func _draw_reachable_tiles(offset: Vector2) -> void:
	for pos in _state.get_reachable_tiles().keys():
		draw_polygon(_tile_diamond(pos.x, pos.y, offset), PackedColorArray([REACHABLE_COLOR]))

# Overlay de LOS (Left Shift): pinta de vermelho os tiles que os inimigos veem.
func set_los_overlay(on: bool, tiles: Dictionary = {}) -> void:
	_show_los_overlay = on
	_los_tiles = tiles
	queue_redraw()

func _draw_los_overlay(offset: Vector2) -> void:
	for pos in _los_tiles:
		draw_polygon(_tile_diamond(pos.x, pos.y, offset), PackedColorArray([LOS_RED]))

# Prévia do Pulo: realce sutil dos tiles de pouso válidos (fonte única
# get_jump_landing_tiles — bate exatamente com o que resolve_jump aceita).
func _draw_jump_landing(offset: Vector2) -> void:
	if _state == null:
		return
	for pos in _state.get_jump_landing_tiles(_state.active_index):
		draw_polygon(_tile_diamond(pos.x, pos.y, offset), PackedColorArray([JUMP_AREA_COLOR]))

# Prévia do Pulo: arco (parábola) do ativo até o tile sob o mouse, só se o pouso
# for válido (is_valid_jump_landing). Sem realce de área — só a trajetória.
func _draw_jump_arc(offset: Vector2) -> void:
	var dest: Vector2i = _hovered_grid
	if _state == null or not _state.is_valid_jump_landing(_state.active_index, dest):
		if _oa_warn_lbl != null:
			_oa_warn_lbl.visible = false
		return
	var src: Vector2i = _state.combatant_positions[_state.active_index]
	var from := _tile_center(src.x, src.y, offset)
	var to := _tile_center(dest.x, dest.y, offset)
	var pts := PackedVector2Array()
	for i in range(0, 17):
		var t := i / 16.0
		var p := from.lerp(to, t)
		p.y -= 42.0 * sin(PI * t)
		pts.append(p)
	draw_polyline(pts, JUMP_ARC_COLOR, 2.5)
	# Aviso de Ataque de Oportunidade (igual ao movimento): pular para fora do
	# alcance corpo-a-corpo de um inimigo com reação provoca OA.
	var provokes := not _state.check_opportunity_attacks(_state.active_index, src, dest).is_empty()
	var di := _tile_diamond(dest.x, dest.y, offset)
	if provokes:
		draw_polygon(di, PackedColorArray([Color(1.0, 0.45, 0.10, 0.30)]))
		draw_polyline(PackedVector2Array([di[0], di[1], di[2], di[3], di[0]]),
			Color(1.0, 0.55, 0.15, 0.95), 2.0)
		if _oa_warn_lbl != null:
			var warn_center := _tile_center(dest.x, dest.y, offset)
			_oa_warn_lbl.reset_size()
			_oa_warn_lbl.position = warn_center - Vector2(_oa_warn_lbl.size.x * 0.5, _oa_warn_lbl.size.y + 26.0)
			_oa_warn_lbl.visible = true
	else:
		draw_polyline(PackedVector2Array([di[0], di[1], di[2], di[3], di[0]]), JUMP_LAND_COLOR, 2.0)
		if _oa_warn_lbl != null:
			_oa_warn_lbl.visible = false

func _draw_move_cursor(offset: Vector2) -> void:
	var pos: Vector2i = _state.move_cursor
	var pts := _tile_diamond(pos.x, pos.y, offset)
	draw_polygon(pts, PackedColorArray([MOVE_CURSOR_FILL]))
	draw_polyline(
		PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		MOVE_CURSOR_BORDER, 2.0
	)

func _draw_attack_area(offset: Vector2) -> void:
	var heal_mode: bool = _state._attack_targets_allies
	var area_color: Color = HEAL_AREA_COLOR if heal_mode else ATTACK_AREA_COLOR
	var target_color: Color = HEAL_TARGET_COLOR if heal_mode else ATTACK_TARGET_COLOR
	var target_set: Dictionary = {}
	for pos in _state.get_attack_target_positions():
		target_set[pos] = true
	for pos in _state.get_attack_area_tiles():
		var fill: Color = target_color if target_set.has(pos) else area_color
		draw_polygon(_tile_diamond(pos.x, pos.y, offset), PackedColorArray([fill]))

func _draw_aoe_splash(offset: Vector2) -> void:
	# Em mira de AoE em tile, o cursor é um ponto livre (pode não haver criatura).
	if _state.attack_target_indices.is_empty() and not _state.attack_tile_mode:
		return
	var cursor_pos: Vector2i = _state.get_attack_cursor_pos()
	var radius: int = _state.current_aoe_radius
	var splash_color := Color(1.0, 0.55, 0.10, 0.22)
	var splash_border := Color(1.0, 0.65, 0.20, 0.70)
	for col in range(_state.grid_cols):
		for row in range(_state.grid_rows):
			var d: int = maxi(absi(col - cursor_pos.x), absi(row - cursor_pos.y))
			if d > 0 and d <= radius:
				var t: TerrainTile = _state.tile_data_map[col][row]
				if t.is_void():
					continue
				if t.object == TerrainTile.ObjectType.OBSTACLE:
					continue
				var pts := _tile_diamond(col, row, offset)
				draw_polygon(pts, PackedColorArray([splash_color]))
				draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
					splash_border, 1.5)

func _draw_attack_cursor(offset: Vector2) -> void:
	if _state.attack_target_indices.is_empty() and not _state.attack_tile_mode:
		return
	var heal_mode: bool = _state._attack_targets_allies
	var cursor_fill: Color = HEAL_CURSOR_FILL if heal_mode else ATTACK_CURSOR_FILL
	var cursor_border: Color = HEAL_CURSOR_BORDER if heal_mode else ATTACK_CURSOR_BORDER
	var pos: Vector2i = _state.get_attack_cursor_pos()
	var pts := _tile_diamond(pos.x, pos.y, offset)
	draw_polygon(pts, PackedColorArray([cursor_fill]))
	draw_polyline(
		PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]),
		cursor_border, 2.0
	)

func _draw_projectile(offset: Vector2) -> void:
	var screen_pos := _tile_center_f(_projectile_pos.x, _projectile_pos.y, offset)
	draw_circle(screen_pos, 9.0, Color(_projectile_color.r, _projectile_color.g, _projectile_color.b, 0.30))
	draw_circle(screen_pos, 5.0, _projectile_color)

func _draw_spawn_markers(offset: Vector2) -> void:
	for pos in _hero_spawns:
		draw_circle(_tile_center(pos.x, pos.y, offset), 4.0, Color(0.30, 0.55, 1.00, 0.40))
	for pos in _enemy_spawns:
		draw_circle(_tile_center(pos.x, pos.y, offset), 4.0, Color(0.85, 0.25, 0.25, 0.40))

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_sync_after_resize()
		queue_redraw()

func _sync_after_resize() -> void:
	if _state == null:
		return
	var offset := _get_offset()
	_combatant_layer.sync_visual_positions(_state, _visual_positions, offset)
	_combatant_layer.update_all_combatant_ui(_state)
	if _terrain_object_layer:
		_terrain_object_layer.sync_positions(_state, offset)

func _initialize_void_effects() -> void:
	_void_effects.clear()
	for row in range(_state.grid_rows):
		for col in range(_state.grid_cols):
			var tile = _state.tile_data_map[col][row]
			if tile and tile.is_void():
				var effect = VoidEffect.new()
				effect.theme = current_void_theme
				_void_effects[Vector2i(col, row)] = effect

func _create_terrain_objects_delegated() -> void:
	_terrain_object_layer.create_objects_from_state(
		_state,
		_get_offset(),
		get_object_texture,
		_get_object_size_by_type
	)

func _get_combatant_node_at(grid_pos: Vector2i) -> CombatantNode:
	if not _state or not _combatant_layer:
		return null
	
	for i in range(_state.combatant_positions.size()):
		if _state.combatant_positions[i] == grid_pos and not _state.dead_indices.has(i):
			return _combatant_layer.get_node_at(i)
	return null

func update_combatant_outlines(available_targets: Array, selected_idx: int = -1) -> void:
	if _combatant_layer == null:
		return
	for i in BattleState.TURN_QUEUE.size():
		var node := _combatant_layer.get_node_at(i)
		if node == null:
			continue
		if i == selected_idx:
			node.set_outline(true, Color(1.0, 0.85, 0.0))  # Amarelo = selecionado
		elif available_targets.has(i):
			node.set_outline(true, Color(0.90, 0.90, 0.90))  # Branco = disponível
		else:
			node.set_outline(false)
