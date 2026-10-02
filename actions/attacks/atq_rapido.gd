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
	damage_type       = DamageType.PHYSICAL
	damage_dice_count = 1
	damage_dice_sides = 4
	icon 			  = preload("res://assets/ui/icons/attacks/atq_rapido.png")
