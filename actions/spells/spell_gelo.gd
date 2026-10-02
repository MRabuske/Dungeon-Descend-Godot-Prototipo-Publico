class_name SpellGelo
extends ActionData

func _init() -> void:
	label            = "Gelo"
	action_type      = Type.ATTACK
	shape            = SHAPE_HEXAGON
	color_idx        = COLOR_SPELL
	attack_range     = 8
	proj_color       = Color(0.40, 0.80, 1.00)
	aoe_radius       = 1
	damage_attribute = DamageAttribute.INT
	damage_type      = DamageType.COLD
	damage_dice_count = 2
	damage_dice_sides = 6
	pp               = 5
	max_pp           = 10
	spell_slot_level = 2
	icon 			 = preload("res://assets/ui/icons/spells/gelo.png")
	projectile_frames  = preload("res://vfx/effects/projectile/ice/iceshard_anim.tres")
	sfx_cast           = "silent"
	sfx_impact         = "skill_ice"
	impact_type = VFXEvent.Type.SKILL_ICE
	requires_saving_throw = true
	save_attribute        = DamageAttribute.DEX
	creates_surface       = SurfaceType.Type.ICE
