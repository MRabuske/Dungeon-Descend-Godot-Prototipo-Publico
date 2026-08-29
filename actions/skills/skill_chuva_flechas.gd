class_name SkillChuvaFlechas
extends ActionData

func _init() -> void:
	label            = "Chuva de Flechas"
	action_type      = Type.ATTACK
	shape            = SHAPE_HEXAGON
	color_idx        = COLOR_SPELL
	attack_range     = 3
	aoe_radius       = 1
	proj_color       = Color(0.6, 1.0, 0.5)
	damage_attribute = DamageAttribute.DEX
	base_damage_min  = 2
	base_damage_max  = 5
	mp_cost          = 15
	icon 			 = preload("res://assets/ui/icons/skills/chuva_flechas.png")
