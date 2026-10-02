class_name SkillFlurry
extends ActionData

func _init() -> void:
	label             = "Flurry of Blows"
	action_type       = Type.ATTACK
	bonus_action      = true   # BG3: gasta a Ação Bônus (não a ação principal)
	shape             = SHAPE_HEXAGON
	color_idx         = COLOR_SPELL
	ki_cost           = 1
	hit_count         = 2
	attack_range      = 1
	damage_attribute  = DamageAttribute.DEX
	damage_type       = DamageType.PHYSICAL
	damage_dice_count = 1
	damage_dice_sides = 6
	icon 		      = preload("res://assets/ui/icons/skills/flurry.png")
