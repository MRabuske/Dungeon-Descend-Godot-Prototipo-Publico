class_name InputBindings
extends RefCounted

# Comandos exclusivos do combate como actions do InputMap, registradas em código (sem
# serializar eventos à mão no project.godot). A navegação comum (A/B/D-pad/LB/RB/Start)
# NÃO é action: o autoload InputDevice a converte em teclas, que todas as telas já leem.

const END_TURN := &"act_end_turn"      # X
const EXAMINE := &"act_examine"        # Y e Tab
const LOG := &"act_log"                # View/Back
const ZOOM_CYCLE := &"act_zoom_cycle"  # R3
const SWITCH_HERO := &"act_switch_hero"  # L3 e H: próximo herói do turno compartilhado

static func register() -> void:
	_bind(END_TURN, [_joy_button(JOY_BUTTON_X)])
	_bind(EXAMINE, [_joy_button(JOY_BUTTON_Y), _key(KEY_TAB)])
	_bind(LOG, [_joy_button(JOY_BUTTON_BACK)])
	_bind(ZOOM_CYCLE, [_joy_button(JOY_BUTTON_RIGHT_STICK)])
	_bind(SWITCH_HERO, [_joy_button(JOY_BUTTON_LEFT_STICK), _key(KEY_H)])

# Botão do controle -> tecla equivalente da ponte. 0 = o botão não é ponteado.
static func bridge_key(button_index: int) -> int:
	match button_index:
		JOY_BUTTON_A: return KEY_ENTER
		JOY_BUTTON_B: return KEY_ESCAPE
		JOY_BUTTON_DPAD_UP: return KEY_UP
		JOY_BUTTON_DPAD_DOWN: return KEY_DOWN
		JOY_BUTTON_DPAD_LEFT: return KEY_LEFT
		JOY_BUTTON_DPAD_RIGHT: return KEY_RIGHT
		JOY_BUTTON_LEFT_SHOULDER: return KEY_Q
		JOY_BUTTON_RIGHT_SHOULDER: return KEY_E
		JOY_BUTTON_START: return KEY_P
	return 0

# Setas e direções que repetem enquanto seguradas (menus longos, passos no grid).
static func repeats(keycode: int) -> bool:
	return keycode == KEY_UP or keycode == KEY_DOWN or keycode == KEY_LEFT or keycode == KEY_RIGHT

static func _bind(action: StringName, events: Array) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for e in events:
		InputMap.action_add_event(action, e)

static func _joy_button(index: int) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = index as JoyButton
	return e

static func _key(keycode: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = keycode as Key
	return e
