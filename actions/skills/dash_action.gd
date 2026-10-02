class_name DashAction
extends ActionData

# Dash (estilo DnD/BG3): gasta a Action do turno e dobra os pontos de movimento
# (soma a velocidade base do heroi aos pontos restantes). Disponivel para todos
# os herois como um icone fixo no grid de acoes. NAO usa Type.ATTACK para evitar
# entrar em modo de selecao de alvo — usa o proprio Type.DASH.
func _init() -> void:
	label        = "Dash"
	action_type  = Type.DASH
	shape        = SHAPE_ARROW
	color_idx    = COLOR_MOVE
	bonus_action = false
	icon         = preload("res://assets/ui/icons/acoes/acao_fugir.png")
