class_name ReactionUncannyDodge
extends ActionData

# Esquiva Sobrenatural (Ladrão): ao ser atingido por um atacante visível,
# reduz o dano recebido à metade. Não consome recurso além da reação.
func _init() -> void:
	label = "Esquiva Sobrenatural"
	is_reaction = true
	reaction_trigger = "on_attacked_visible"
	color_idx = COLOR_DEFEND
	shape = SHAPE_HEXAGON
