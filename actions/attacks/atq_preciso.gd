class_name AtqPreciso
extends ActionData

func _init() -> void:
	label             = "Atq. Preciso"
	action_type       = Type.ATTACK
	shape             = SHAPE_SQUARE
	color_idx         = COLOR_ATTACK
	attack_range      = 4
	proj_color        = Color(1.0, 0.95, 0.60)
	damage_attribute  = DamageAttribute.DEX
	base_damage_min   = 5
	base_damage_max   = 9
	icon 			  = preload("res://assets/ui/icons/attacks/atq_preciso.png")
