class_name AtqPesado
extends ActionData

func _init() -> void:
	label             = "Atq. Pesado"
	action_type       = Type.ATTACK
	shape             = SHAPE_SQUARE
	color_idx         = COLOR_ATTACK
	attack_range      = 1
	proj_color        = Color.WHITE
	damage_attribute   = DamageAttribute.STR
	damage_type        = DamageType.PHYSICAL
	is_weapon_attack   = true
	use_versatile_grip = true
	icon 			  = preload("res://assets/ui/icons/attacks/atq_pesado.png")
