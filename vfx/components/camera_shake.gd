class_name CameraShake
extends Node

# ======================================================
# Câmera shake baseado em trauma (0..1).
# Adicione como filho da Camera2D ou do BattleArea.
#
# Uso:
#   CameraShake.add_trauma(0.4)   # hit leve
#   CameraShake.add_trauma(0.7)   # hit pesado
#   CameraShake.add_trauma(1.0)   # crit / morte / explosão
# ======================================================

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE
# ──────────────────────────────────────────────────────
@export var max_offset_x    := 14.0   # px — deslocamento máximo horizontal
@export var max_offset_y    := 9.0    # px — deslocamento máximo vertical
@export var trauma_decay    := 2.2    # unidades/seg — quão rápido o shake some
@export var trauma_power    := 2.0    # expoente — 2 = quadrático (mais orgânico)
# ──────────────────────────────────────────────────────

# Referência ao BattleArea — injetada pelo BattleScene
var battle_area: BattleArea = null

var _trauma: float = 0.0
var _rng := RandomNumberGenerator.new()
var _base_pan: Vector2 = Vector2.ZERO

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	_rng.randomize()
	set_process(false) 

# ======================================================
# PUBLIC
# ======================================================
func add_trauma(amount: float) -> void:
	if _trauma <= 0.0 and battle_area:
		_base_pan = battle_area._pan_offset
	_trauma = minf(_trauma + amount, 1.0)
	set_process(true)

# ======================================================
# PROCESS
# ======================================================
func _process(delta: float) -> void:
	if battle_area == null:
		set_process(false)
		return

	var shake: float = pow(_trauma, trauma_power)
	battle_area._pan_offset = _base_pan + Vector2(
		_rng.randf_range(-1.0, 1.0) * max_offset_x * shake,
		_rng.randf_range(-1.0, 1.0) * max_offset_y * shake,
	)
	battle_area.queue_redraw()

	_trauma = maxf(0.0, _trauma - trauma_decay * delta)

	if _trauma <= 0.0:
		battle_area._pan_offset = _base_pan
		battle_area.queue_redraw()
		set_process(false)

# ======================================================
# HELPER
# ======================================================
func _find_camera() -> Camera2D:
	var cameras := get_tree().get_nodes_in_group("camera")
	if cameras.size() > 0:
		return cameras[0] as Camera2D
	# Fallback: busca na árvore
	return get_viewport().get_camera_2d()
