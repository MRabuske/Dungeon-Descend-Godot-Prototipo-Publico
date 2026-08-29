class_name SpellCura
extends ActionData

func _init() -> void:
	label            = "Cura"
	action_type      = Type.ATTACK
	shape            = SHAPE_HEXAGON
	color_idx        = COLOR_SPELL
	attack_range     = 3
	proj_color       = Color(0.30, 1.00, 0.50)
	targets_allies   = true
	self_target      = true
	bonus_action     = true
	damage_attribute = DamageAttribute.WIS
	base_damage_min  = 8
	base_damage_max  = 14
	pp               = 10
	max_pp           = 10
	mp_cost          = 15
	icon 			 = preload("res://assets/ui/icons/spells/curar.png")
