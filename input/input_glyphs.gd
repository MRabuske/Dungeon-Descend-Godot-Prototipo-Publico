class_name InputGlyphs
extends RefCounted

# Texto da dica de botão por ação e dispositivo. "" = a ação não tem equivalente nesse
# dispositivo e a dica some (ex.: Visão geral só tem botão no controle).
# Ações não listadas devolvem "". Esquema do BG3 (bg3.wiki "Controls"), ver docs/architecture/input.md.

const _GAMEPAD := {
	&"confirm": "A", &"back": "B", &"end_turn": "Y", &"examine": "X",
	&"tabs": "LB/RB", &"los": "RT", &"log": "View", &"pause": "Start",
	&"zoom": "R-stick", &"center": "LT", &"overview": "R3",
	&"pan": "L-stick",
	&"switch_hero": "L3", &"navigate": "D-pad", &"cursor": "L-stick",
	&"start_party": "",
}

const _KEYBOARD := {
	&"confirm": "Enter", &"back": "Esc", &"end_turn": "Space", &"examine": "Tab",
	&"tabs": "Q/E", &"los": "Shift", &"log": "", &"pause": "P",
	&"zoom": "Roda/PgUp/PgDn", &"center": "Home", &"overview": "",
	&"pan": "WASD",
	&"switch_hero": "H", &"navigate": "Setas", &"cursor": "",
	&"start_party": "F",
}

static func label(action: StringName, device: int) -> String:
	var table: Dictionary = _GAMEPAD if device == InputDeviceTracker.Device.GAMEPAD else _KEYBOARD
	return table.get(action, "")
