class_name AcaoEsconder
extends ActionData

# Esconder (Hide, BG3): Ação universal. Teste de Furtividade; sucesso deixa o
# combatante Oculto (Vantagem + habilita Furtivo) até atacar ou ser avistado.
# Gasta a Ação principal mas NÃO encerra o turno (pode mover depois).
# A versão Ação Bônus é feature de Rogue/Ranger (build) — fora daqui.
# Resolução em BattleState.resolve_hide().
func _init() -> void:
	label       = "Esconder"
	action_type = Type.END_TURN
	shape       = SHAPE_TRIANGLE
	color_idx   = COLOR_WAIT
	self_target = true
