class_name SpellTrovao
extends ActionData

func _init() -> void:
	label            = "Trovao"
	action_type      = Type.ATTACK
	shape            = SHAPE_HEXAGON
	color_idx        = COLOR_SPELL
	attack_range     = 4
	proj_color       = Color(0.90, 0.85, 0.20)
	aoe_radius       = 2
	damage_attribute = DamageAttribute.INT
	base_damage_min  = 6
	base_damage_max  = 11
	pp               = 6
	max_pp           = 8
	mp_cost          = 30
	icon 			 = preload("res://assets/ui/icons/spells/trovao.png")
