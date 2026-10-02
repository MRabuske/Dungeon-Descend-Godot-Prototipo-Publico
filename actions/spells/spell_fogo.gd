class_name SpellFogo
extends ActionData

func _init() -> void:
	label              = "Fogo"
	action_type        = Type.ATTACK
	shape              = SHAPE_HEXAGON
	color_idx          = COLOR_SPELL
	attack_range       = 10
	aoe_radius         = 1
	proj_color         = Color(1.0, 0.45, 0.10)
	damage_attribute   = DamageAttribute.INT
	damage_type        = DamageType.FIRE
	damage_dice_count  = 2
	damage_dice_sides  = 6
	pp                 = 8
	max_pp             = 10
	spell_slot_level   = 2
	icon               = preload("res://assets/ui/icons/spells/fogo.png")
	projectile_frames  = preload("res://vfx/effects/projectile/fire/fireball_anim.tres")
	projectile_scale   = Vector2(1.4, 1.4)
	projectile_speed   = 0.6
	impact_type        = VFXEvent.Type.SKILL_FIRE
	sfx_cast           = "whoosh_magic"
	sfx_impact         = "skill_fire"
	impact_vfx_dur     = 2.0
	requires_saving_throw = true
	save_attribute        = DamageAttribute.DEX
	creates_surface       = SurfaceType.Type.FIRE
