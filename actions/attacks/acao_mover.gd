class_name AcaoMover
extends ActionData

func _init() -> void:
	label       = "Mover"
	action_type = Type.MOVE
	shape       = SHAPE_ARROW
	color_idx   = COLOR_MOVE
	icon 		= preload("res://assets/ui/icons/acoes/acao_mover.png")
