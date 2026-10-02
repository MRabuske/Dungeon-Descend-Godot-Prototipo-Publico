class_name SpellCloudOfDaggers
extends ActionData

# Nuvem de Adagas (BG3): spell de nível 2, escola Conjuração, requer Concentração.
# Cria uma nuvem persistente no tile alvo. Qualquer combatente que entrar ou
# iniciar o turno na nuvem sofre 4d4 de dano Slashing (sem save). A nuvem persiste
# enquanto o caster mantiver concentração (ver _break_concentration em BattleState).
func _init() -> void:
	label                  = "Nuvem de Adagas"
	action_type            = Type.ATTACK
	shape                  = SHAPE_HEXAGON
	color_idx              = COLOR_SPELL
	spell_slot_level       = 2
	attack_range           = 10
	aoe_radius             = 0
	proj_color             = Color(0.6, 0.1, 0.9)
	damage_dice_count      = 4
	damage_dice_sides      = 4
	damage_attribute       = DamageAttribute.NONE
	damage_type            = DamageType.PHYSICAL
	requires_concentration = true
	creates_surface        = SurfaceType.Type.CLOUD_OF_DAGGERS
	requires_saving_throw  = false
	is_weapon_attack       = false
