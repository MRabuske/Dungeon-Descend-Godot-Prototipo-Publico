class_name InputGlyphs
extends RefCounted

# Texto da dica de botão por ação e dispositivo. "" = a ação não tem equivalente nesse
# dispositivo e a dica some (ex.: Fim de turno só tem botão no mouse/controle).
# Ações não listadas devolvem "".

const _GAMEPAD := {
	&"confirm": "A", &"back": "B", &"end_turn": "X", &"examine": "Y",
	&"tabs": "LB/RB", &"los": "LT", &"log": "View", &"pause": "Start",
	&"zoom": "R3", &"switch_hero": "L3", &"camera": "R-stick", &"navigate": "D-pad", &"cursor": "L-stick",
	&"start_party": "",
}

const _KEYBOARD := {
	&"confirm": "Enter", &"back": "Esc", &"end_turn": "Space", &"examine": "Tab",
	&"tabs": "Q/E", &"los": "Shift", &"log": "", &"pause": "P",
	&"zoom": "", &"switch_hero": "H", &"camera": "", &"navigate": "Setas", &"cursor": "",
	&"start_party": "F",
}

static func label(action: StringName, device: int) -> String:
	var table: Dictionary = _GAMEPAD if device == InputDeviceTracker.Device.GAMEPAD else _KEYBOARD
	return table.get(action, "")
