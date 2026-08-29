class_name AcaoDefender
extends ActionData

func _init() -> void:
	label       = "Defender"
	action_type = Type.END_TURN
	shape       = SHAPE_TRIANGLE
	color_idx   = COLOR_DEFEND
	icon 		= preload("res://assets/ui/icons/acoes/acao_defender.png")
