class_name AcaoDip
extends ActionData

# Mergulhar arma (Dip, BG3): Ação Bônus universal. Sobre uma superfície de Fogo,
# reveste a arma para +1d4 de Fogo nos próximos ataques. Instantâneo (sem alvo).
# Resolução em BattleState.resolve_dip().
func _init() -> void:
	label        = "Mergulhar"
	action_type  = Type.END_TURN
	shape        = SHAPE_TRIANGLE
	color_idx    = COLOR_ITEM
	bonus_action = true
	self_target  = true
