class_name AtqArcano
extends ActionData

func _init() -> void:
	label            = "Raio Arcano"
	action_type      = Type.ATTACK
	shape            = SHAPE_SQUARE
	color_idx        = COLOR_ATTACK
	attack_range     = 4
	proj_color       = Color(0.6, 0.4, 1.0)
	damage_attribute = DamageAttribute.INT
	base_damage_min  = 2
	base_damage_max  = 6
	icon	 		 = preload("res://assets/ui/icons/attacks/atq_arcano.png")
