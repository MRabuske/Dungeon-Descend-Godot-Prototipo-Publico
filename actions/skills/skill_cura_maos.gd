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
	damage_type      = DamageType.HEALING
	damage_dice_count = 2
	damage_dice_sides = 8
	spell_slot_level = 1
	icon 		= preload("res://assets/ui/icons/skills/cura_maos.png")
	sfx_cast = "skill_holy"
	sfx_impact = "silent"
	impact_type = VFXEvent.Type.SKILL_HEAL
