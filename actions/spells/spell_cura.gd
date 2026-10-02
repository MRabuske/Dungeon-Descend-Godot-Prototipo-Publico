class_name SpellCura
extends ActionData

func _init() -> void:
	label            = "Cura"
	action_type      = Type.ATTACK
	shape            = SHAPE_HEXAGON
	color_idx        = COLOR_SPELL
	attack_range     = 8
	proj_color       = Color(0.30, 1.00, 0.50)
	targets_allies   = true
	self_target      = true
	bonus_action     = true
	damage_attribute = DamageAttribute.WIS
	damage_type      = DamageType.HEALING
	damage_dice_count = 2
	damage_dice_sides = 4
	pp               = 10
	max_pp           = 10
	spell_slot_level = 1
	icon 			 = preload("res://assets/ui/icons/spells/curar.png")
	sfx_cast = "skill_holy"
	sfx_impact = "silent"
	impact_type = VFXEvent.Type.SKILL_HEAL
