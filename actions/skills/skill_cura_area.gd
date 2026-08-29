class_name SkillCuraArea
extends ActionData

func _init() -> void:
	label            = "Cura em Área"
	action_type      = Type.ATTACK
	shape            = SHAPE_HEXAGON
	color_idx        = COLOR_SPELL
	attack_range     = 1
	aoe_radius       = 1
	proj_color       = Color(0.30, 1.00, 0.50)
	targets_allies   = true
	damage_attribute = DamageAttribute.WIS
	base_damage_min  = 8
	base_damage_max  = 12
	mp_cost          = 25
	icon 		= preload("res://assets/ui/icons/skills/cura_area.png")
