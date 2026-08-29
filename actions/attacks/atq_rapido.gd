class_name AtqRapido
extends ActionData

func _init() -> void:
	label             = "Atq. Rapido"
	action_type       = Type.ATTACK
	shape             = SHAPE_SQUARE
	color_idx         = COLOR_ATTACK
	attack_range      = 1
	bonus_action      = true
	proj_color        = Color.WHITE
	damage_attribute  = DamageAttribute.DEX
	base_damage_min   = 2
	base_damage_max   = 5
	icon 			  = preload("res://assets/ui/icons/attacks/atq_rapido.png")
