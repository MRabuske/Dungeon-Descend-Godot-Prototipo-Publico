class_name CombatantNode
extends Node2D

# ======================================================
# Representa visualmente um combatente.
# IMPORTANTE: este nó deve ser filho de um Node2D que
# recebe a mesma transform do draw_set_transform do canvas
# (zoom + pan). Ver CombatantLayer abaixo.
# ======================================================

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE FINO
# ──────────────────────────────────────────────────────
const SPRITE_SIZE         := Vector2(64, 64)
const SPRITE_OFFSET       := Vector2(-48, -72)   # topo do sprite em relação ao centro do tile
const ELEVATED_Y_OFFSET   := -14.0
const ELEVATED_X_OFFSET   := -6.0

const SQUASH_ATTACK       := Vector2(1.30, 0.75)
const STRETCH_ATTACK      := Vector2(0.75, 1.30)
const NORMAL_SCALE        := Vector2.ONE

const ANTICIPATION_DIST   := 8.0
const LUNGE_DIST          := 14.0

const HIT_FLASH_DURATION  := 0.14
const DISSOLVE_DURATION   := 1.4
const OUTLINE_WIDTH       := 1.5

const HP_BAR_WIDTH        := 38.0
const HP_BAR_HEIGHT       := 5.0
const HP_BAR_OFFSET_Y     := -48.0   # acima do sprite (relativo ao centro)
const HP_BAR_BG_COLOR     := Color(0.15, 0.15, 0.15)
const HP_BAR_PLAYER_HIGH  := Color(0.15, 0.75, 0.25)
const HP_BAR_PLAYER_LOW   := Color(0.90, 0.20, 0.20)
const HP_BAR_ENEMY_HIGH   := Color(0.80, 0.20, 0.20)
const HP_BAR_ENEMY_LOW    := Color(0.60, 0.10, 0.10)
const HP_BAR_LOW_THRESHOLD := 0.25

const STATUS_ICON_RADIUS  := 3.5
const STATUS_ICON_GAP     := 2.0
const STATUS_OFFSET_Y     := -75.0   # acima da HP bar
const STATUS_POISON_COLOR := Color(0.20, 0.85, 0.35)
const STATUS_STUN_COLOR   := Color(0.95, 0.80, 0.15)
const STATUS_BG_COLOR     := Color(0.0, 0.0, 0.0, 0.70)
const STATUS_BG_RADIUS    := 5.0     # STATUS_ICON_RADIUS + 1.5
# ──────────────────────────────────────────────────────

const HIT_FLASH_SHADER := preload("res://vfx/shaders/hit_flash.gdshader")
const OUTLINE_SHADER   := preload("res://vfx/shaders/outline.gdshader")
const DISSOLVE_SHADER  := preload("res://vfx/shaders/dissolve.gdshader")
const NOISE_TEXTURE    := preload("res://vfx/textures/noise_dissolve.png")
const BURN_SHADER      := preload("res://vfx/shaders/burn.gdshader")

# ======================================================
# NÓS FILHOS
# ======================================================
var sprite: Sprite2D        = null
var trail:  TrailRenderer   = null
var _ui_layer: Node2D       = null

# ══════════════════════════════════════════════════════
# Nós para UI (HP bar + status icons)
# ══════════════════════════════════════════════════════
var _hp_bar_bg: ColorRect = null
var _hp_bar_fill: ColorRect = null
var _status_container: Node2D = null
var _status_icons: Array[ColorRect] = []
var _concentration_icon: Label = null
var _prone_icon: Label = null

# ======================================================
# ESTADO
# ======================================================
var combatant_idx: int  = -1
var is_player:     bool = true
var _max_hp:       int  = 0
var _current_hp:   int  = 0

var _hit_mat:     ShaderMaterial = null
var _outline_mat: ShaderMaterial = null
var _dissolve_mat:ShaderMaterial = null
var _active_mat:  String         = ""   # "hit"|"outline"|"dissolve"|""
var _burn_mat: ShaderMaterial = null
var _combatant_frames: SpriteFrames = null
var _anim_sprite: AnimatedSprite2D = null
var _current_direction: String = "down_right"

# ======================================================
# SETUP
# ======================================================
func setup(idx: int, combatant: Dictionary, texture: Texture2D) -> void:
	combatant_idx = idx
	is_player     = combatant.get("is_player", false)
	
	y_sort_enabled = true
	
	trail         = TrailRenderer.new()
	trail.target  = self
	trail.visible = false
	add_child(trail)
	
	sprite                 = Sprite2D.new()
	sprite.texture         = texture
	sprite.centered        = false
	sprite.offset          = SPRITE_OFFSET
	sprite.texture_filter  = CanvasItem.TEXTURE_FILTER_NEAREST
	var data_scale: float = combatant.get("sprite_scale", 1.0)
	if texture:
		var texture_size := texture.get_size() # Aqui será 86x90
		
		var scale_x := (SPRITE_SIZE.x / texture_size.x) * data_scale
		var scale_y := (SPRITE_SIZE.y / texture_size.y) * data_scale
		sprite.scale = Vector2(scale_x, scale_y)
		
		var base_offset_x := -(texture_size.x / 2.0)
		var base_offset_y := -texture_size.y
		
		var vfx_padding_x := 4.0
		var vfx_padding_y := 16.0
		sprite.offset = Vector2(base_offset_x + vfx_padding_x, base_offset_y + vfx_padding_y)
	add_child(sprite)

	_ui_layer = Node2D.new()
	_ui_layer.y_sort_enabled = false
	_ui_layer.z_index = 100
	add_child(_ui_layer)
	
	_create_status_container()
	_create_concentration_icon()
	_create_prone_icon()

	# Pré-cria ShaderMaterials — nunca aloca em runtime
	_hit_mat              = ShaderMaterial.new()
	_hit_mat.shader       = HIT_FLASH_SHADER

	_outline_mat          = ShaderMaterial.new()
	_outline_mat.shader   = OUTLINE_SHADER
	_outline_mat.set_shader_parameter("outline_width", OUTLINE_WIDTH)

	_dissolve_mat         = ShaderMaterial.new()
	_dissolve_mat.shader  = DISSOLVE_SHADER
	_dissolve_mat.set_shader_parameter("noise_texture", NOISE_TEXTURE)

	sprite.material = null

	_init_burn_material()
	
	_combatant_frames = combatant.get("sprite_frames", null)
	print("Combatant: ", combatant.get("name", "?"), " | sprite_frames: ", _combatant_frames != null)
	
	if _combatant_frames:
		_anim_sprite = AnimatedSprite2D.new()
		_anim_sprite.centered = false
		_anim_sprite.offset = sprite.offset
		_anim_sprite.scale = sprite.scale
		_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_anim_sprite.sprite_frames = _combatant_frames
		_anim_sprite.visible = false
		add_child(_anim_sprite)

# ======================================================
# UPDATE — posição a cada frame (chamado pelo BattleArea)
# Recebe posição já em "canvas space" (antes do zoom/pan)
# A transform do zoom/pan é aplicada no CombatantLayer pai.
# ======================================================
func update_canvas_position(canvas_pos: Vector2, is_elevated: bool) -> void:
	position = canvas_pos
	if is_elevated:
		position += Vector2(ELEVATED_X_OFFSET, ELEVATED_Y_OFFSET)

func update_texture(texture: Texture2D) -> void:
	if sprite:
		sprite.texture = texture

# ======================================================
# EFEITO — hit flash
# ======================================================
func play_hit_flash(color: Color = Color.WHITE) -> void:
	_set_mat(_hit_mat)
	_hit_mat.set_shader_parameter("flash_color", color)
	var tw := create_tween()
	tw.tween_method(
		func(v: float): _hit_mat.set_shader_parameter("flash_amount", v),
		1.0, 0.0, HIT_FLASH_DURATION
	).set_trans(Tween.TRANS_EXPO)
	# ↓ MUDA AQUI: só limpa se ainda for o hit_flash
	tw.tween_callback(func():
		if _active_mat == "hit_flash":
			_clear_mat()
	)
# ======================================================
# EFEITO — outline
# ======================================================
func set_outline(active: bool, color: Color = Color(1.0, 0.85, 0.0)) -> void:
	if active:
		_set_mat(_outline_mat)
		_outline_mat.set_shader_parameter("outline_color", color)
		_outline_mat.set_shader_parameter("enabled", true)
	elif _active_mat == "outline":
		_clear_mat()

# ======================================================
# EFEITO — dissolve na morte
# ======================================================
func play_death(on_done: Callable = Callable(), death_dir: Vector2 = Vector2.ZERO) -> void:
	var tw_kill := create_tween()
	tw_kill.kill()
	_clear_mat()
	
	var dir_name := _current_direction
	if death_dir != Vector2.ZERO:
		dir_name = _get_direction(death_dir)
	
	var anim_name := "death_" + dir_name
	var has_death_anim := _anim_sprite and _combatant_frames and _combatant_frames.has_animation(anim_name)
	
	# ── Sempre aplica o dissolve shader ──
	_set_mat(_dissolve_mat)
	_dissolve_mat.set_shader_parameter("dissolve_amount", 0.0)
	_dissolve_mat.set_shader_parameter("edge_color", Color(1.0, 0.35, 0.08))
	_dissolve_mat.set_shader_parameter("edge_width", 0.08)
	
	var duration := DISSOLVE_DURATION
	
	# ── Se tem animação de morte, toca junto ──
	if has_death_anim:
		sprite.visible = false
		_anim_sprite.visible = true
		_anim_sprite.play(anim_name)
		var fps := _combatant_frames.get_animation_speed(anim_name)
		var frame_count := _combatant_frames.get_frame_count(anim_name)
		duration = float(frame_count) / fps if fps > 0 else DISSOLVE_DURATION
	
	# ── Tween do dissolve ──
	var tw := create_tween()
	tw.tween_method(
		func(v: float): 
			if is_instance_valid(self) and is_inside_tree():
				_dissolve_mat.set_shader_parameter("dissolve_amount", v),
		0.0, 1.0, duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(self) and is_inside_tree():
			visible = false
		if on_done.is_valid():
			on_done.call()
	)

# ======================================================
# ANIMAÇÃO — ataque (anticipation + lunge + recovery)
# FIX: usa position relativa ao nó — não mexe em _visual_positions
# O canvas position é restaurado no callback de done.
# ======================================================
func play_attack_animation(target_canvas_pos: Vector2,
		on_impact: Callable, on_done: Callable, is_ranged: bool = false) -> void:
	var origin := position
	var dir    := (target_canvas_pos - origin).normalized()
	_current_direction = _get_direction(dir)
	
	var anim_prefix := "ranged_" if is_ranged else "attack_"
	var anim_name := anim_prefix + _current_direction
	print("Tentando ataque: ", anim_name, " | is_ranged: ", is_ranged, " | _anim_sprite: ", _anim_sprite != null, " | Existe? ", _combatant_frames.has_animation(anim_name) if _combatant_frames else false)
	
	if _anim_sprite and _combatant_frames and _combatant_frames.has_animation(anim_name):
		sprite.visible = false
		_anim_sprite.visible = true
		_anim_sprite.play(anim_name)
		var fps := _combatant_frames.get_animation_speed(anim_name)
		var frame_count := _combatant_frames.get_frame_count(anim_name)
		var duration := float(frame_count) / fps if fps > 0 else 0.5
		var impact_timer := get_tree().create_timer(duration * 0.5)
		await impact_timer.timeout
		if is_instance_valid(self) and is_inside_tree():
			on_impact.call()
		var end_timer := get_tree().create_timer(duration * 0.5)
		await end_timer.timeout
		if is_instance_valid(self) and is_inside_tree():
			set_idle()
			if on_done.is_valid():
				on_done.call()
		return
	else: 
		print("Fallback: squash/stretch")

	var base_scale := sprite.scale

	var tw := create_tween()

	# 1. Squash + recuo
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale",base_scale * SQUASH_ATTACK, 0.07) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_property(self, "position",
		origin - dir * ANTICIPATION_DIST, 0.07) \
		.set_trans(Tween.TRANS_SINE)
	tw.set_parallel(false)

	# 2. Stretch + avanço
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale",base_scale * STRETCH_ATTACK, 0.08) \
		.set_trans(Tween.TRANS_EXPO)
	tw.tween_property(self, "position",
		origin + dir * LUNGE_DIST, 0.08) \
		.set_trans(Tween.TRANS_EXPO)
	tw.set_parallel(false)

	# 3. Impacto
	tw.tween_callback(on_impact)

	# 4. Recovery
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale",base_scale * NORMAL_SCALE, 0.14) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", origin, 0.14) \
		.set_trans(Tween.TRANS_SINE)
	tw.set_parallel(false)

	tw.tween_callback(on_done)

# ======================================================
# ANIMAÇÃO — movimento
# FIX: recebe lista de posições canvas já calculadas.
# _visual_positions é atualizado ANTES de iniciar o tween
# para que o canvas de HP bars já esteja correto desde
# o primeiro frame — elimina o flick.
# ======================================================
func play_move_animation(canvas_path: Array[Vector2], on_step: Callable, on_done: Callable) -> void:
	trail.visible = true
	trail.start()

	var tw := create_tween()
	for i in range(canvas_path.size()):
		var dest: Vector2 = canvas_path[i]
		var dir := (dest - position).normalized()
		_current_direction = _get_direction(dir)
		var walk_anim := "walk_" + _current_direction
		if _anim_sprite and _combatant_frames and _combatant_frames.has_animation(walk_anim):
			sprite.visible = false
			_anim_sprite.visible = true
			_anim_sprite.play(walk_anim)
		tw.tween_property(self, "position", dest, 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Chama on_step ao chegar em cada tile
		tw.tween_callback(on_step.bind(i))

	tw.tween_callback(func():
		set_idle()
		trail.stop()
		if SfxManager:
			SfxManager.stop_all()
		await get_tree().create_timer(trail.fade_out_sec + 0.01).timeout
		trail.visible = false
		on_done.call()
	)

# ======================================================
# ANIMAÇÃO — hit reaction
# ======================================================
func play_hit_reaction(knockback_dir: Vector2 = Vector2.ZERO) -> void:
	var origin := position
	var base_scale := sprite.scale
	var tw     := create_tween().set_parallel(true)

	tw.tween_property(sprite, "scale",base_scale * Vector2(0.85, 1.15), 0.05) \
		.set_trans(Tween.TRANS_EXPO)
	if knockback_dir != Vector2.ZERO:
		tw.tween_property(self, "position",
			origin + knockback_dir * 5.0, 0.05) \
			.set_trans(Tween.TRANS_EXPO)

	tw.set_parallel(false)
	tw.set_parallel(true)
	tw.tween_property(sprite, "scale",base_scale * NORMAL_SCALE, 0.12) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "position", origin, 0.12) \
		.set_trans(Tween.TRANS_SINE)

# ======================================================
# ANIMAÇÃO —  Burn
# ======================================================
func play_burn(duration: float = 2.0, on_done: Callable = Callable()) -> void:
	_set_mat(_burn_mat)
	_burn_mat.set_shader_parameter("edge_color", Color(1.0, 0.0, 0.0))
	_burn_mat.set_shader_parameter("edge_width", 0.04)
	_burn_mat.set_shader_parameter("burn_amount", 0.0)
	_burn_mat.set_shader_parameter("time", 0.0)
	
	var time_tween := create_tween()
	time_tween.tween_method(
		func(v: float):
			if is_instance_valid(self) and is_inside_tree():
				_burn_mat.set_shader_parameter("time", v),
		0.0, duration, duration
	)
	
	var tw := create_tween()
	tw.tween_method(
		func(v: float):
			if is_instance_valid(self) and is_inside_tree():
				_burn_mat.set_shader_parameter("burn_amount", v),
		0.0, 0.8, duration * 0.2
	).set_trans(Tween.TRANS_SINE)
	tw.tween_method(
		func(v: float):
			if is_instance_valid(self) and is_inside_tree():
				_burn_mat.set_shader_parameter("burn_amount", v),
		0.8, 0.0, duration * 0.8
	).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func():
		if is_instance_valid(self) and is_inside_tree():
			if _active_mat == "burn":
				_clear_mat()
		if on_done.is_valid():
			on_done.call()
	)
# ======================================================
# HELPERS
# ======================================================
func _set_mat(mat: ShaderMaterial) -> void:
	if sprite:
		sprite.material = mat

	if _anim_sprite:
		_anim_sprite.material = mat

	_active_mat = mat.shader.resource_path.get_file().get_basename()

func _clear_mat() -> void:
	if sprite:
		sprite.material = null

	if _anim_sprite:
		_anim_sprite.material = null

	_active_mat = ""

# ══════════════════════════════════════════════════════
# NOVO: Criação da barra de HP
# ══════════════════════════════════════════════════════
func _create_hp_bar() -> void:
	var data_scale: float = 1.0
	if sprite and sprite.texture:
		data_scale = sprite.scale.x / (SPRITE_SIZE.x / sprite.texture.get_size().x)

	# Posição Vertical: sobe ou desce baseada na escala do personagem
	var current_offset_y := HP_BAR_OFFSET_Y * data_scale

	# Posição Horizontal: Compensação do centro do sprite
	var vfx_padding_x := 4.0 
	var current_offset_x := (-HP_BAR_WIDTH / 2.0) + (vfx_padding_x * data_scale)

	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_bg.color = HP_BAR_BG_COLOR
	_hp_bar_bg.position = Vector2(current_offset_x, current_offset_y)
	_ui_layer.add_child(_hp_bar_bg)
	
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_fill.color = _get_hp_color(1.0)
	_hp_bar_fill.position = _hp_bar_bg.position
	_ui_layer.add_child(_hp_bar_fill)
# ══════════════════════════════════════════════════════
# NOVO: Cria container para ícones de status
# ══════════════════════════════════════════════════════
func _create_status_container() -> void:
	var data_scale: float = 1.0
	if sprite and sprite.texture:
		data_scale = sprite.scale.x / (SPRITE_SIZE.x / sprite.texture.get_size().x)
	_status_container = Node2D.new()
	_status_container.position = Vector2(0, STATUS_OFFSET_Y * data_scale)
	_ui_layer.add_child(_status_container)

# ══════════════════════════════════════════════════════
# NOVO: Ícone de concentração (◆) — visível enquanto o caster concentra
# ══════════════════════════════════════════════════════
func _create_concentration_icon() -> void:
	_concentration_icon = Label.new()
	_concentration_icon.text = "◆"
	_concentration_icon.add_theme_font_size_override("font_size", 12)
	_concentration_icon.add_theme_color_override("font_color", Color(0.65, 0.20, 0.95))
	_concentration_icon.position = Vector2(10, STATUS_OFFSET_Y - 8)
	_concentration_icon.visible = false
	_ui_layer.add_child(_concentration_icon)

func set_concentrating(value: bool, spell_name: String = "") -> void:
	if _concentration_icon:
		_concentration_icon.visible = value
		if value and spell_name != "":
			_concentration_icon.text = "◆ " + spell_name.left(4)
		elif not value:
			_concentration_icon.text = "◆"

# ══════════════════════════════════════════════════════
# Indicador TEMPORÁRIO de Prone (sem animação/sprite ainda) — tag de texto
# acima do token para saber, em teste, quem está Prostrado.
# ══════════════════════════════════════════════════════
func _create_prone_icon() -> void:
	_prone_icon = Label.new()
	_prone_icon.text = "⤓ PRONE"
	_prone_icon.add_theme_font_size_override("font_size", 11)
	_prone_icon.add_theme_color_override("font_color", Color(1.0, 0.75, 0.2))
	_prone_icon.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_prone_icon.add_theme_constant_override("outline_size", 3)
	_prone_icon.position = Vector2(-12, STATUS_OFFSET_Y - 22)
	_prone_icon.visible = false
	_ui_layer.add_child(_prone_icon)

func set_prone(value: bool) -> void:
	if _prone_icon:
		_prone_icon.visible = value

# ══════════════════════════════════════════════════════
# NOVO: Estado Downed (caído) — sprite cinza e deitado
# Downed e Invisible compõem o mesmo modulate via _apply_visual_state().
# ══════════════════════════════════════════════════════
var _is_downed_state: bool = false
var _is_invisible_state: bool = false

func set_downed(value: bool) -> void:
	_is_downed_state = value
	_apply_visual_state()

func set_invisible(value: bool) -> void:
	_is_invisible_state = value
	_apply_visual_state()

func _apply_visual_state() -> void:
	if sprite == null:
		return
	var col := Color.WHITE
	if _is_downed_state:
		col = Color(0.35, 0.35, 0.35, 0.85)
	if _is_invisible_state:
		col.a = 0.35   # Invisível: bem translúcido (compõe com Downed)
	var rot := 90.0 if _is_downed_state else 0.0
	sprite.modulate = col
	sprite.rotation_degrees = rot
	if _anim_sprite:
		_anim_sprite.modulate = col
		_anim_sprite.rotation_degrees = rot

# ══════════════════════════════════════════════════════
# NOVO: Atualiza HP bar
# ══════════════════════════════════════════════════════
func update_hp(current_hp: int, max_hp: int) -> void:
	_current_hp = current_hp
	_max_hp = max_hp
	
	if not _hp_bar_fill or not _hp_bar_bg:
		return
	
	var ratio := float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	_hp_bar_fill.size.x = HP_BAR_WIDTH * ratio
	_hp_bar_fill.color = _get_hp_color(ratio)

# ══════════════════════════════════════════════════════
# NOVO: Atualiza ícones de status
# ══════════════════════════════════════════════════════
func update_status(status_dict: Dictionary) -> void:
	for icon in _status_icons:
		icon.queue_free()
	_status_icons.clear()

# ══════════════════════════════════════════════════════
# NOVO: Helper para cor da HP bar
# ══════════════════════════════════════════════════════
func _get_hp_color(ratio: float) -> Color:
	if is_player:
		return HP_BAR_PLAYER_LOW if ratio < HP_BAR_LOW_THRESHOLD else HP_BAR_PLAYER_HIGH
	else:
		return HP_BAR_ENEMY_LOW if ratio < HP_BAR_LOW_THRESHOLD else HP_BAR_ENEMY_HIGH

# ══════════════════════════════════════════════════════
# NOVO: Mostra/esconde UI (útil durante animações)
# ══════════════════════════════════════════════════════
func set_ui_visible(visible_state: bool) -> void:
	if _ui_layer:
		_ui_layer.visible = visible_state

func _init_burn_material() -> void:
	_burn_mat = ShaderMaterial.new()
	_burn_mat.shader = BURN_SHADER
	_burn_mat.set_shader_parameter("noise_texture", NOISE_TEXTURE)

func set_idle() -> void:
	if not _anim_sprite:
		return
	_anim_sprite.visible = false
	_anim_sprite.stop()
	sprite.visible = true

func _get_direction(screen_vec: Vector2) -> String:
	if screen_vec == Vector2.ZERO:
		return _current_direction
	const HW := 36.0
	const HH := 18.0
	var grid_x := (screen_vec.x / HW + screen_vec.y / HH) / 2.0
	var grid_y := (screen_vec.y / HH - screen_vec.x / HW) / 2.0
	if abs(grid_x) > abs(grid_y):
		if grid_x > 0:
			return "down_right"
		else:
			return "up_left"
	else:
		if grid_y > 0:
			return "down_left"
		else:
			return "up_right"
