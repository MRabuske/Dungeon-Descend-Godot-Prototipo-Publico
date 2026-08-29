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
		var texture_size := texture.get_size()
		var scale_x := (SPRITE_SIZE.x / texture_size.x) * data_scale
		var scale_y := (SPRITE_SIZE.y / texture_size.y) * data_scale
		sprite.scale = Vector2(scale_x, scale_y)
		if data_scale != 1.0:
			var scaled_width  := SPRITE_SIZE.x * data_scale
			var scaled_height := SPRITE_SIZE.y * data_scale
			sprite.offset = Vector2(-(scaled_width / 2.0) + 18.0, -(scaled_height) + 58)
		else:
			sprite.offset = SPRITE_OFFSET
	add_child(sprite)

	_ui_layer = Node2D.new()
	_ui_layer.y_sort_enabled = false
	_ui_layer.z_index = 100
	add_child(_ui_layer)
	
	_create_hp_bar()
	_create_status_container()

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
func play_death(on_done: Callable = Callable()) -> void:
	# Mata tweens anteriores que possam chamar _clear_mat
	var tw_kill := create_tween()
	tw_kill.kill()
	
	_clear_mat()
	_set_mat(_dissolve_mat)
	_dissolve_mat.set_shader_parameter("dissolve_amount", 0.0)
	_dissolve_mat.set_shader_parameter("edge_color", Color(1.0, 0.35, 0.08))
	_dissolve_mat.set_shader_parameter("edge_width", 0.08)

	var tw := create_tween()
	tw.tween_method(
		func(v: float): _dissolve_mat.set_shader_parameter("dissolve_amount", v),
		0.0, 1.0, DISSOLVE_DURATION
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
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
		on_impact: Callable, on_done: Callable) -> void:
	var origin := position
	var dir    := (target_canvas_pos - origin).normalized()

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
		tw.tween_property(self, "position", dest, 0.14) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		# Chama on_step ao chegar em cada tile
		tw.tween_callback(on_step.bind(i))

	tw.tween_callback(func():
		trail.stop()
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
# HELPERS
# ======================================================
func _set_mat(mat: ShaderMaterial) -> void:
	if sprite:
		sprite.material = mat
		_active_mat     = mat.shader.resource_path.get_file().get_basename()

func _clear_mat() -> void:
	if sprite:
		sprite.material = null
		_active_mat     = ""

# ══════════════════════════════════════════════════════
# NOVO: Criação da barra de HP
# ══════════════════════════════════════════════════════
func _create_hp_bar() -> void:
	# Fundo da barra
	_hp_bar_bg = ColorRect.new()
	_hp_bar_bg.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_bg.color = HP_BAR_BG_COLOR
	_hp_bar_bg.position = Vector2(
		-HP_BAR_WIDTH / 2.0 + 8.0,  # centraliza (ajuste fino)
		HP_BAR_OFFSET_Y
	)
	_ui_layer.add_child(_hp_bar_bg)
	
	# Preenchimento da barra
	_hp_bar_fill = ColorRect.new()
	_hp_bar_fill.size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	_hp_bar_fill.color = _get_hp_color(1.0)  # começa cheia
	_hp_bar_fill.position = _hp_bar_bg.position
	_ui_layer.add_child(_hp_bar_fill) 

# ══════════════════════════════════════════════════════
# NOVO: Cria container para ícones de status
# ══════════════════════════════════════════════════════
func _create_status_container() -> void:
	_status_container = Node2D.new()
	_status_container.position = Vector2(0, STATUS_OFFSET_Y)
	_ui_layer.add_child(_status_container)

# ══════════════════════════════════════════════════════
# NOVO: Atualiza HP bar
# ══════════════════════════════════════════════════════
func update_hp(current_hp: int, max_hp: int) -> void:
	_current_hp = current_hp
	_max_hp = max_hp
	
	if not _hp_bar_fill:
		return
	
	var ratio := float(current_hp) / float(max_hp) if max_hp > 0 else 0.0
	_hp_bar_fill.size.x = HP_BAR_WIDTH * ratio
	_hp_bar_fill.color = _get_hp_color(ratio)

# ══════════════════════════════════════════════════════
# NOVO: Atualiza ícones de status
# ══════════════════════════════════════════════════════
func update_status(status_dict: Dictionary) -> void:
	# Limpa ícones anteriores
	for icon in _status_icons:
		icon.queue_free()
	_status_icons.clear()
	
	# Coleta cores dos status ativos
	var active_colors: Array[Color] = []
	
	if status_dict.get("poison", 0) > 0:
		active_colors.append(STATUS_POISON_COLOR)
	if status_dict.get("stun", 0) > 0:
		active_colors.append(STATUS_STUN_COLOR)
	# Adicione mais status aqui conforme necessário
	
	if active_colors.is_empty():
		return
	
	# Calcula posições dos ícones
	var total_width := active_colors.size() * (STATUS_BG_RADIUS * 2.0 + STATUS_ICON_GAP) - STATUS_ICON_GAP
	var start_x := -total_width / 2.0 + STATUS_BG_RADIUS
	
	for i in range(active_colors.size()):
		# Círculo de fundo
		var bg := ColorRect.new()
		bg.size = Vector2(STATUS_BG_RADIUS * 2, STATUS_BG_RADIUS * 2)
		bg.position = Vector2(
			start_x + i * (STATUS_BG_RADIUS * 2.0 + STATUS_ICON_GAP) - STATUS_BG_RADIUS,
			-STATUS_BG_RADIUS
		)
		bg.color = STATUS_BG_COLOR
		_status_container.add_child(bg)
		_status_icons.append(bg)
		
		# Círculo colorido (ícone)
		var icon := ColorRect.new()
		icon.size = Vector2(STATUS_ICON_RADIUS * 2, STATUS_ICON_RADIUS * 2)
		icon.position = Vector2(
			start_x + i * (STATUS_BG_RADIUS * 2.0 + STATUS_ICON_GAP) - STATUS_ICON_RADIUS,
			-STATUS_ICON_RADIUS
		)
		icon.color = active_colors[i]
		_status_container.add_child(icon)
		_status_icons.append(icon)

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
