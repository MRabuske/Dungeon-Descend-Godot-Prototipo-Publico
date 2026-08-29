class_name AtqPesado
extends ActionData

func _init() -> void:
	label             = "Atq. Pesado"
	action_type       = Type.ATTACK
	shape             = SHAPE_SQUARE
	color_idx         = COLOR_ATTACK
	attack_range      = 1
	proj_color        = Color.WHITE
	damage_attribute  = DamageAttribute.STR
	base_damage_min   = 6
	base_damage_max   = 12
	icon 			  = preload("res://assets/ui/icons/attacks/atq_pesado.png")
