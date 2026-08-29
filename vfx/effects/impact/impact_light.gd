class_name ImpactLightEffect
extends VFXEffectBase

# ======================================================
# Efeito de impacto leve — procedural.
# Burst de linhas radiais + círculo que expande e some.
# ======================================================

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE FINO
# ──────────────────────────────────────────────────────
const DURATION      := 0.18
const BURST_LINES   := 8       # número de linhas radiais
const LINE_LEN_MIN  := 8.0
const LINE_LEN_MAX  := 22.0
const LINE_WIDTH    := 2.5
const RING_RADIUS   := 18.0    # raio máximo do anel
const COLOR_CORE    := Color(1.00, 0.92, 0.60, 1.0)
const COLOR_RING    := Color(1.00, 0.75, 0.30, 0.6)
# ──────────────────────────────────────────────────────

var _t    := 0.0
var _rng  := RandomNumberGenerator.new()
var _line_angles: Array[float] = []   # ângulos sorteados no restart

func _ready() -> void:
	set_process(false)

func _on_restart() -> void:
	_t = 0.0
	_rng.seed = int(global_position.x * 1000 + global_position.y)
	_line_angles.clear()
	# Distribui as linhas com variação aleatória para não serem perfeitamente uniformes
	for i in BURST_LINES:
		var base := (TAU / BURST_LINES) * i
		_line_angles.append(base + _rng.randf_range(-0.25, 0.25))
	set_process(true)

func _process(delta: float) -> void:
	if not is_inside_tree():
		set_process(false)
		return
	
	_t = minf(_t + delta / DURATION, 1.0)
	queue_redraw()
	if _t >= 1.0:
		set_process(false)
		await get_tree().create_timer(0.02).timeout
		if is_inside_tree():
			_finish()

func _draw() -> void:
	if not is_active():
		return

	var ease_t := 1.0 - pow(1.0 - _t, 2.0)
	var alpha  := 1.0 - pow(_t, 1.5)

	# Anel que expande
	var ring_r := RING_RADIUS * ease_t
	draw_arc(Vector2.ZERO, ring_r, 0.0, TAU, 32,
		Color(COLOR_RING.r, COLOR_RING.g, COLOR_RING.b, COLOR_RING.a * alpha),
		LINE_WIDTH)

	# Linhas radiais que se afastam do centro
	for angle: float in _line_angles:
		var start_dist := ring_r * 0.3
		var end_dist   := LINE_LEN_MIN + (LINE_LEN_MAX - LINE_LEN_MIN) * ease_t
		var p1 := Vector2(cos(angle), sin(angle)) * start_dist
		var p2 := Vector2(cos(angle), sin(angle)) * (start_dist + end_dist)
		draw_line(p1, p2,
			Color(COLOR_CORE.r, COLOR_CORE.g, COLOR_CORE.b, alpha),
			LINE_WIDTH, true)

	# Flash central (desaparece rápido)
	var flash_alpha := maxf(0.0, 1.0 - _t * 4.0)
	if flash_alpha > 0.0:
		draw_circle(Vector2.ZERO, 7.0 * (1.0 - ease_t * 0.5),
			Color(1.0, 1.0, 1.0, flash_alpha))
