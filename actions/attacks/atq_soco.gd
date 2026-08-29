class_name AtqSoco
extends ActionData

func _init() -> void:
	label            = "Soco"
	action_type      = Type.ATTACK
	shape            = SHAPE_SQUARE
	color_idx        = COLOR_ATTACK
	attack_range     = 1
	proj_color       = Color(0.8, 0.6, 0.3)
	damage_attribute = DamageAttribute.DEX
	base_damage_min  = 2
	base_damage_max  = 5
	icon 			 = preload("res://assets/ui/icons/attacks/atq_soco.png")
