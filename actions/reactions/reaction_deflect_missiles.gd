class_name ReactionDeflectMissiles
extends ActionData

# Defletir Projéteis (Monge): ao ser atingido por um ataque à distância,
# reduz o dano em 1d10 + mod DEX + nível do Monge. Se zerar, pode gastar 1 Ki
# para devolver o projétil (tratado no fluxo de BattleScene).
func _init() -> void:
	label = "Defletir Projéteis"
	is_reaction = true
	reaction_trigger = "on_attacked_ranged"
	color_idx = COLOR_DEFEND
	shape = SHAPE_HEXAGON
