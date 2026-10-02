class_name SkillSmite
extends ActionData

func _init() -> void:
	label             = "Smite Divino"
	action_type       = Type.ATTACK
	shape             = SHAPE_HEXAGON
	color_idx         = COLOR_SPELL
	spell_slot_level  = 1
	icon              = preload("res://assets/ui/icons/skills/smite.png")
	attack_range      = 1
	damage_attribute  = DamageAttribute.STR
	damage_type       = DamageType.PHYSICAL
	damage_dice_count = 1
	damage_dice_sides = 8
	is_weapon_attack  = true   # força rolagem d20 vs AC e usa dados da arma (fallback 1d8)
	bonus_action      = false
	smite_dice_count  = 2
	smite_dice_sides  = 8
