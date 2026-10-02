class_name AtqDivino
extends ActionData

func _init() -> void:
	label            = "Atq. Divino"
	action_type      = Type.ATTACK
	shape            = SHAPE_SQUARE
	color_idx        = COLOR_ATTACK
	attack_range     = 1
	proj_color       = Color(1.0, 0.95, 0.6)
	damage_attribute = DamageAttribute.WIS
	damage_type      = DamageType.RADIANT
	damage_dice_count = 1
	damage_dice_sides = 8
	icon 			 = preload("res://assets/ui/icons/attacks/atq_divino.png")
