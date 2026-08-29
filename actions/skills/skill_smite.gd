class_name SkillSmite
extends ActionData

func _init() -> void:
	label       = "Smite Divino"
	action_type = Type.END_TURN
	shape       = SHAPE_HEXAGON
	color_idx   = COLOR_SPELL
	self_target = true
	mp_cost     = 15
	icon 		= preload("res://assets/ui/icons/skills/smite.png")
