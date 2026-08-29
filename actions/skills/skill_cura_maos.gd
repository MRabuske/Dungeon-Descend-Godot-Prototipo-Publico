class_name SkillCuraMaos
extends ActionData

func _init() -> void:
	label            = "Cura das Mãos"
	action_type      = Type.ATTACK
	shape            = SHAPE_HEXAGON
	color_idx        = COLOR_SPELL
	attack_range     = 1
	proj_color       = Color(0.30, 1.00, 0.50)
	targets_allies   = true
	self_target      = true
	damage_attribute = DamageAttribute.WIS
	base_damage_min  = 15
	base_damage_max  = 25
	mp_cost          = 20
	icon 		= preload("res://assets/ui/icons/skills/cura_maos.png")
