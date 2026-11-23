class_name InputBindings
extends RefCounted

# Comandos exclusivos do combate como actions do InputMap, registradas em código (sem
# serializar eventos à mão no project.godot). A navegação comum (A/B/D-pad/LB/RB/Start)
# NÃO é action: o autoload InputDevice a converte em teclas, que todas as telas já leem.

# Esquema do BG3 (bg3.wiki "Controls"): Y encerra/cancela o turno, X abre o menu de contexto (Examinar).
const END_TURN := &"act_end_turn"      # Y (Space e o botão FIM tratam o teclado/mouse)
const EXAMINE := &"act_examine"        # X e Tab
const LOG := &"act_log"                # View/Back
const ZOOM_OVERVIEW := &"act_zoom_overview"  # R3: afasta até caber o mapa; de novo, volta
const SWITCH_HERO := &"act_switch_hero"  # L3 e H: próximo herói do turno compartilhado
const SELECT_NEXT := &"act_select_next"  # ] (BG3 "Select Next Character")
const SELECT_PREV := &"act_select_prev"  # [ (BG3 "Select Previous Character")
const SELECT_POS := [&"act_select_pos1", &"act_select_pos2", &"act_select_pos3", &"act_select_pos4"]  # F1-F4 (BG3 "Select Character at Position n")
# Consultadas por polling (seguradas ou por borda de subida), não por evento:
const ZOOM_IN := &"act_zoom_in"        # Page Up (o analógico direito é lido por InputDevice.zoom_axis)
const ZOOM_OUT := &"act_zoom_out"      # Page Down
const CENTER_CAMERA := &"act_center_camera"  # LT e Home: centraliza no personagem ativo
const ENEMY_VIEW := &"act_enemy_view"  # RT e Shift (segurado): visão dos inimigos

static func register() -> void:
	_bind(END_TURN, [_joy_button(JOY_BUTTON_Y)])
	_bind(EXAMINE, [_joy_button(JOY_BUTTON_X), _key(KEY_TAB)])
	_bind(LOG, [_joy_button(JOY_BUTTON_BACK)])
	_bind(ZOOM_OVERVIEW, [_joy_button(JOY_BUTTON_RIGHT_STICK)])
	_bind(SWITCH_HERO, [_joy_button(JOY_BUTTON_LEFT_STICK), _key(KEY_H)])
	_bind(SELECT_NEXT, [_key(KEY_BRACKETRIGHT)])
	_bind(SELECT_PREV, [_key(KEY_BRACKETLEFT)])
	for i in range(SELECT_POS.size()):
		_bind(SELECT_POS[i], [_key(KEY_F1 + i)])
	_bind(ZOOM_IN, [_key(KEY_PAGEUP)])
	_bind(ZOOM_OUT, [_key(KEY_PAGEDOWN)])
	_bind(CENTER_CAMERA, [_joy_axis(JOY_AXIS_TRIGGER_LEFT), _key(KEY_HOME)])
	_bind(ENEMY_VIEW, [_joy_axis(JOY_AXIS_TRIGGER_RIGHT), _key(KEY_SHIFT)])

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

static func _joy_axis(axis: int) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis as JoyAxis
	e.axis_value = 1.0
	return e

static func _key(keycode: int) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = keycode as Key
	return e
