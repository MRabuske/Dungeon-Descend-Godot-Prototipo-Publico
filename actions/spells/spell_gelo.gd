class_name SpellGelo
extends ActionData

func _init() -> void:
	label            = "Gelo"
	action_type      = Type.ATTACK
	shape            = SHAPE_HEXAGON
	color_idx        = COLOR_SPELL
	attack_range     = 3
	proj_color       = Color(0.40, 0.80, 1.00)
	aoe_radius       = 1
	damage_attribute = DamageAttribute.INT
	base_damage_min  = 4
	base_damage_max  = 7
	pp               = 5
	max_pp           = 10
	mp_cost          = 25
	icon 			 = preload("res://assets/ui/icons/spells/gelo.png")
