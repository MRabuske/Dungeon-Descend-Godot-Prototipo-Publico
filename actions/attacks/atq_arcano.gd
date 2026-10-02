class_name AtqArcano
extends ActionData

func _init() -> void:
	label            = "Raio Arcano"
	action_type      = Type.ATTACK
	shape            = SHAPE_SQUARE
	color_idx        = COLOR_ATTACK
	attack_range     = 10
	proj_color       = Color(0.6, 0.4, 1.0)
	damage_attribute = DamageAttribute.INT
	damage_type      = DamageType.ARCANE
	damage_dice_count = 1
	damage_dice_sides = 10
	icon	 		 = preload("res://assets/ui/icons/attacks/atq_arcano.png")
	sfx_cast = "whoosh_magic"
	sfx_impact = "silent"
