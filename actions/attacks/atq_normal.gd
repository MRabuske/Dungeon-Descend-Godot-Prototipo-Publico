class_name AtqNormal
extends ActionData

func _init() -> void:
	label             = "Atq. Normal"
	action_type       = Type.ATTACK
	shape             = SHAPE_SQUARE
	color_idx         = COLOR_ATTACK
	attack_range      = 1
	proj_color        = Color.WHITE
	damage_attribute  = DamageAttribute.STR
	damage_type       = DamageType.PHYSICAL
	is_weapon_attack  = true
	icon 			  = preload("res://assets/ui/icons/attacks/atq_normal.png")
