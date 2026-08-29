class_name SkillPassoVento
extends ActionData

func _init() -> void:
	label       = "Passo do Vento"
	action_type = Type.END_TURN
	shape       = SHAPE_HEXAGON
	color_idx   = COLOR_SPELL
	self_target = true
	mp_cost     = 1
	icon 		= preload("res://assets/ui/icons/skills/passo_vento.png")
