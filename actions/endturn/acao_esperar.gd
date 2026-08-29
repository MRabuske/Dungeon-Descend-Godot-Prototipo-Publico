class_name AcaoEsperar
extends ActionData

func _init() -> void:
	label       = "Esperar"
	action_type = Type.END_TURN
	shape       = SHAPE_TRIANGLE
	color_idx   = COLOR_WAIT
	icon 		= preload("res://assets/ui/icons/acoes/acao_esperar.png")
