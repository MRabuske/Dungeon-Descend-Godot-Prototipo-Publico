class_name ReactionDivineSmite
extends ActionData

# Smite Divino via Reação (Paladino): após acertar um ataque corpo-a-corpo,
# consome um spell slot e adiciona dano radiante ao acerto.
func _init() -> void:
	label = "Smite Divino"
	is_reaction = true
	reaction_trigger = "on_melee_hit_self"
	spell_slot_level = 1
	damage_type = DamageType.RADIANT
	color_idx = COLOR_SPELL
	shape = SHAPE_HEXAGON
