class_name AtqPreciso
extends ActionData

func _init() -> void:
	label             = "Atq. Preciso"
	action_type       = Type.ATTACK
	shape             = SHAPE_SQUARE
	color_idx         = COLOR_ATTACK
	attack_range      = 8
	proj_color        = Color(1.0, 0.95, 0.60)
	damage_attribute  = DamageAttribute.DEX
	damage_type       = DamageType.PHYSICAL
	is_weapon_attack  = true
	icon 			  = preload("res://assets/ui/icons/attacks/atq_preciso.png")
	sfx_cast           = "impact_arrow"
	sfx_impact         = "whoosh_bow"
