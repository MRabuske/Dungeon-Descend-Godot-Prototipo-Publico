class_name ReactionStunningStrike
extends ActionData

# Golpe Atordoante (Monge): após acertar um ataque corpo-a-corpo, gasta 1 Ki;
# o alvo faz um save de CON ou fica atordoado até o próximo turno do Monge.
func _init() -> void:
	label = "Golpe Atordoante"
	is_reaction = true
	reaction_trigger = "on_melee_hit_self"
	ki_cost = 1
	color_idx = COLOR_ATTACK
	shape = SHAPE_HEXAGON
