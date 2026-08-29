class_name ImpactCritEffect
extends VFXEffectBase

# ======================================================
# Impacto crítico — maior, mais dramático, com anel duplo.
# ======================================================

const DURATION      := 0.26
const BURST_LINES   := 12
const LINE_LEN_MIN  := 14.0
const LINE_LEN_MAX  := 36.0
const LINE_WIDTH    := 3.0
const RING_RADIUS   := 28.0
const COLOR_CORE    := Color(1.00, 0.85, 0.20, 1.0)   # amarelo dourado
const COLOR_RING    := Color(1.00, 0.50, 0.10, 0.7)   # laranja
const COLOR_RING2   := Color(1.00, 0.95, 0.60, 0.4)   # anel secundário

var _t   := 0.0
var _rng := RandomNumberGenerator.new()
var _angles: Array[float] = []

func _ready() -> void:
	set_process(false)

func _on_restart() -> void:
	_t = 0.0
	_rng.seed = int(global_position.x * 997 + global_position.y * 3)
	_angles.clear()
	for i in BURST_LINES:
		_angles.append((TAU / BURST_LINES) * i + _rng.randf_range(-0.2, 0.2))
	set_process(true)

func _process(delta: float) -> void:
	_t = minf(_t + delta / DURATION, 1.0)
	queue_redraw()
	if _t >= 1.0:
		set_process(false)
		await get_tree().create_timer(0.03).timeout
		_finish()

func _draw() -> void:
	if not is_active():
		return
	var ease_t := 1.0 - pow(1.0 - _t, 2.2)
	var alpha  := 1.0 - pow(_t, 1.4)

	# Anel externo
	draw_arc(Vector2.ZERO, RING_RADIUS * ease_t, 0.0, TAU, 40,
		Color(COLOR_RING.r, COLOR_RING.g, COLOR_RING.b, COLOR_RING.a * alpha),
		LINE_WIDTH + 1.0)
	# Anel interno (delay menor)
	var inner_t := minf(ease_t * 1.4, 1.0)
	draw_arc(Vector2.ZERO, RING_RADIUS * 0.5 * inner_t, 0.0, TAU, 32,
		Color(COLOR_RING2.r, COLOR_RING2.g, COLOR_RING2.b, COLOR_RING2.a * alpha),
		LINE_WIDTH)

	# Linhas radiais
	for angle: float in _angles:
		var sd := RING_RADIUS * ease_t * 0.25
		var ed := LINE_LEN_MIN + (LINE_LEN_MAX - LINE_LEN_MIN) * ease_t
		draw_line(
			Vector2(cos(angle), sin(angle)) * sd,
			Vector2(cos(angle), sin(angle)) * (sd + ed),
			Color(COLOR_CORE.r, COLOR_CORE.g, COLOR_CORE.b, alpha),
			LINE_WIDTH, true)

	# Flash central dourado
	var fa := maxf(0.0, 1.0 - _t * 3.5)
	if fa > 0.0:
		draw_circle(Vector2.ZERO, 10.0 * (1.0 - ease_t * 0.6),
			Color(1.0, 0.95, 0.5, fa))
