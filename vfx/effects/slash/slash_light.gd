class_name SlashLightEffect
extends VFXEffectBase

# ======================================================
# Efeito de slash leve — 100% procedural via _draw().
# Não precisa de spritesheet para funcionar.
# Quando tiver o asset, basta:
#   1. Adicionar AnimatedSprite2D como filho
#   2. Descomentar as linhas marcadas com [SPRITE]
#   3. Comentar o bloco _draw()
# ======================================================

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE FINO
# ──────────────────────────────────────────────────────
const DURATION       := 0.22   # segundos do efeito completo
const ARC_RADIUS     := 28.0   # raio do arco do slash
const ARC_WIDTH      := 5.0    # espessura da linha do arco
const ARC_START_DEG  := -60.0  # ângulo inicial do arco (graus)
const ARC_END_DEG    :=  60.0  # ângulo final  do arco (graus)
const ARC_SEGMENTS   := 18     # suavidade do arco
const COLOR_CORE     := Color(1.00, 0.95, 0.85, 1.0)   # branco quente
const COLOR_GLOW     := Color(1.00, 0.80, 0.40, 0.45)  # glow amarelo
const GLOW_EXTRA_R   := 8.0    # raio extra do glow
# ──────────────────────────────────────────────────────

# [SPRITE] var _sprite: AnimatedSprite2D

var _t := 0.0      # progresso 0..1

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	# [SPRITE] _sprite = $AnimatedSprite2D
	# [SPRITE] _sprite.animation_finished.connect(_on_sprite_done)
	set_process(false)

# ======================================================
# RESTART — chamado pelo VFXManager ao spawnar
# ======================================================
func _on_restart() -> void:
	_t = 0.0
	set_process(true)
	# [SPRITE] _sprite.play("slash_light")

# ======================================================
# PROCESS — anima o progresso do arco
# ======================================================
func _process(delta: float) -> void:
	if not is_inside_tree():
		set_process(false)
		return
	
	_t = minf(_t + delta / DURATION, 1.0)
	queue_redraw()
	if _t >= 1.0:
		set_process(false)
		await get_tree().create_timer(0.04).timeout
		if is_inside_tree():
			_finish()

# ======================================================
# DRAW — arco procedural
# ======================================================
func _draw() -> void:
	if not is_active():
		return

	# Curva de easing: rápido no início, suave no fim
	var ease_t := 1.0 - pow(1.0 - _t, 2.5)
	var alpha   := 1.0 - pow(_t, 1.8)   # fade out

	# Ângulos do arco em radianos, progredindo com o tempo
	var start_rad := deg_to_rad(ARC_START_DEG)
	var end_rad   := deg_to_rad(ARC_END_DEG)
	var span      := end_rad - start_rad

	# O arco "varre" de start até a posição atual
	var current_end := start_rad + span * ease_t

	# Glow externo (mais grosso, mais transparente)
	_draw_arc_line(ARC_RADIUS + GLOW_EXTRA_R,
		start_rad, current_end, ARC_SEGMENTS,
		Color(COLOR_GLOW.r, COLOR_GLOW.g, COLOR_GLOW.b, COLOR_GLOW.a * alpha),
		ARC_WIDTH + 6.0)

	# Arco principal
	_draw_arc_line(ARC_RADIUS,
		start_rad, current_end, ARC_SEGMENTS,
		Color(COLOR_CORE.r, COLOR_CORE.g, COLOR_CORE.b, COLOR_CORE.a * alpha),
		ARC_WIDTH)

	# Ponta brilhante na extremidade do arco
	var tip := Vector2(cos(current_end), sin(current_end)) * ARC_RADIUS
	draw_circle(tip, ARC_WIDTH * 0.9,
		Color(1.0, 1.0, 1.0, alpha * 0.9))

func _draw_arc_line(radius: float, from_rad: float, to_rad: float,
		segments: int, color: Color, width: float) -> void:
	if abs(to_rad - from_rad) < 0.001:
		return
	var pts := PackedVector2Array()
	for i in segments + 1:
		var a := from_rad + (to_rad - from_rad) * (float(i) / float(segments))
		pts.append(Vector2(cos(a), sin(a)) * radius)
	draw_polyline(pts, color, width, true)

# ======================================================
# [SPRITE] Callback quando o spritesheet terminar
# ======================================================
# func _on_sprite_done() -> void:
#     _finish()
