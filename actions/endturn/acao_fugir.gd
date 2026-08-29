class_name AcaoFugir
extends ActionData

func _init() -> void:
	label       = "Fugir"
	action_type = Type.END_TURN
	shape       = SHAPE_TRIANGLE
	color_idx   = COLOR_FLEE
	icon 		= preload("res://assets/ui/icons/acoes/acao_fugir.png")
