class_name FocusRing
extends Panel

# Anel de seleção que some enquanto o último input foi do mouse (FocusGlow.rings_shown).
# O dono controla `visible` (qual item está selecionado); este nó só controla o alfa.

func _ready() -> void:
	_sync()

func _process(_delta: float) -> void:
	_sync()

func _sync() -> void:
	modulate.a = 1.0 if FocusGlow.rings_shown() else 0.0
