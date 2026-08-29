class_name VFXEffectBase
extends Node2D

# ======================================================
# Classe base que todo efeito VFX deve estender.
# Garante a interface do pool (restart / is_active).
# ======================================================

signal effect_finished

var _active := false

# ──────────────────────────────────────────────────────
# Interface pública — chamada pelo VFXManager
# ──────────────────────────────────────────────────────
func _ready() -> void:
	z_index = 100

func restart() -> void:
	_active = true
	visible = true
	z_index = 100
	_on_restart()

func is_active() -> bool:
	return _active

# ──────────────────────────────────────────────────────
# Override nas subclasses
# ──────────────────────────────────────────────────────
func _on_restart() -> void:
	pass

# ──────────────────────────────────────────────────────
# Chame ao final da animação para devolver ao pool
# ──────────────────────────────────────────────────────
func _finish() -> void:
	_active  = false
	visible  = false
	rotation = 0.0
	scale    = Vector2.ONE
	effect_finished.emit()
