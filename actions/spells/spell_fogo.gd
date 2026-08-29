class_name SpellFogo
extends ActionData

func _init() -> void:
	label            = "Fogo"
	action_type      = Type.ATTACK
	shape            = SHAPE_HEXAGON
	color_idx        = COLOR_SPELL
	attack_range     = 4
	proj_color       = Color(1.0, 0.45, 0.10)
	damage_attribute = DamageAttribute.INT
	base_damage_min  = 5
	base_damage_max  = 9
	pp               = 8
	max_pp           = 10
	mp_cost          = 20
	icon 			 = preload("res://assets/ui/icons/spells/fogo.png")
