class_name AcaoDesengajar
extends ActionData

# Desengajar (ação principal, D&D 5e): impede que mover dispare Ataque de
# Oportunidade neste turno. Gasta a ação principal (has_attacked).
func _init() -> void:
	label = "Desengajar"
	action_type = Type.END_TURN
	color_idx = COLOR_WAIT
	shape = SHAPE_TRIANGLE
