class_name SpellTrovao
extends ActionData

func _init() -> void:
	label            = "Trovao"
	action_type      = Type.ATTACK
	shape            = SHAPE_HEXAGON
	color_idx        = COLOR_SPELL
	attack_range     = 8
	proj_color       = Color(0.90, 0.85, 0.20)
	aoe_radius       = 2
	aoe_cascade_delay = 0.08
	aoe_instant = true
	damage_attribute = DamageAttribute.INT
	damage_type      = DamageType.THUNDER
	damage_dice_count = 2
	damage_dice_sides = 6
	pp               = 6
	max_pp           = 8
	spell_slot_level = 2
	icon 			 = preload("res://assets/ui/icons/spells/trovao.png")
	sfx_cast           = "silent"
	sfx_impact         = "skill_thunder"
	impact_type = VFXEvent.Type.SKILL_LIGHTNING
	requires_saving_throw = true
	save_attribute        = DamageAttribute.DEX
	# Trovão eletrifica Água existente (ver _deposit_surface_after_attack).
	creates_surface       = SurfaceType.Type.ELECTRIFIED_WATER
