class_name SkillSegundoVento
extends ActionData

func _init() -> void:
	label       = "Segundo Vento"
	action_type = Type.END_TURN
	shape       = SHAPE_HEXAGON
	color_idx   = COLOR_SPELL
	self_target = true
	pp          = 1
	max_pp      = 1
	icon 		= preload("res://assets/ui/icons/skills/segundo_vento.png")
