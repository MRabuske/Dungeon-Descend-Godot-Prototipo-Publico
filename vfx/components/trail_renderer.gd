class_name TrailRenderer
extends Line2D

# ======================================================
# Trail de movimento — Line2D que segue um Node2D alvo.
# ======================================================


const TRAIL_OFFSET := Vector2(05, 20) 
# ──────────────────────────────────────────────────────
# 🔧 AJUSTE
# ──────────────────────────────────────────────────────
@export var max_points   := 14
@export var fade_out_sec := 0.22
@export var trail_width  := 6.0
@export var trail_color  := Color(1.0, 1.0, 1.0, 0.55)
# ──────────────────────────────────────────────────────

@export var target: Node2D = null

var _tracking := false
var _combatant_layer: Node2D = null

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	default_color = trail_color
	z_index       = 11
	clear_points()
	_apply_gradient()
	
	top_level = true
	
	# Busca o CombatantLayer
	var parent := get_parent()
	while parent:
		if parent is CombatantLayer:
			_combatant_layer = parent
			break
		parent = parent.get_parent()

# ======================================================
# PUBLIC
# ======================================================
func start() -> void:
	_tracking = true
	clear_points()
	modulate.a = 1.0
	set_process(true)

func stop() -> void:
	_tracking = false
	set_process(false)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, fade_out_sec) \
		.set_trans(Tween.TRANS_SINE)
	tw.tween_callback(clear_points)
	tw.tween_callback(func(): modulate.a = 1.0)

# ======================================================
# PROCESS
# ======================================================
func _process(_delta: float) -> void:
	if target == null or not _tracking:
		return
	
	# Pega o zoom do CombatantLayer
	var zoom := 1.0
	if _combatant_layer:
		zoom = _combatant_layer.transform.get_scale().x
	
	# Ajusta largura
	width = trail_width * zoom
	
	# Centro do sprite no espaço global
	var sprite_center := target.global_position
	sprite_center += TRAIL_OFFSET * zoom
	
	var s: Sprite2D = null
	if target is CombatantNode:
		s = (target as CombatantNode).sprite
	
	if s:
		# 👇 Aplica zoom no offset do sprite também
		sprite_center += (s.position + s.offset) * zoom
		if s.texture:
			var tex_size: Vector2 = s.texture.get_size()
			sprite_center += tex_size * s.scale * zoom * 0.5
	
	add_point(sprite_center)
	
	if get_point_count() > max_points:
		remove_point(0)

# ======================================================
# HELPER
# ======================================================
func _apply_gradient() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(trail_color.r, trail_color.g, trail_color.b, 0.0))
	g.set_color(1, trail_color)
	gradient = g
