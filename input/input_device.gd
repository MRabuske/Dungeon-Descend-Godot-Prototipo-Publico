extends Node

# Autoload "InputDevice" (sem class_name, como os outros autoloads).
#
# - Dispositivo ativo: o último a ser usado manda (InputDeviceTracker). Com o controle
#   ativo o cursor do mouse fica oculto; mexer o mouse ou apertar tecla o devolve.
# - Ponte: A/B/D-pad/LB/RB/Start (e o analógico esquerdo, fora do combate e nos painéis modais) viram teclas
#   sintéticas (Enter/Esc/setas/Q/E/P), então toda tela que já lê KEY_* funciona no
#   controle sem reescrita. As teclas sintéticas levam a meta "bridged": o rastreador
#   as ignora. (Verificado: parse_input_event entrega o evento no frame seguinte,
#   mantendo a meta; por isso a marca é meta e não uma flag ao redor da chamada.)
# - No combate o analógico esquerdo é o cursor livre do mundo (stick_drives_cursor, ligado pela cena)
#   e NÃO vira setas; a barra de ações, o filtro e Confirmar/Voltar são do D-pad.
# - Os eventos reais dos botões ponteados são consumidos para não acionar ui_accept
#   duas vezes. X/Y/View/R3 seguem como actions (InputBindings) tratadas pela cena.
# - Ordem de _input no Godot: nós mais tarde na árvore primeiro; a cena roda ANTES
#   deste autoload. Por isso a cena ignora eventos de joypad enquanto is_gamepad() é
#   falso: o botão que "acorda" o controle só troca o dispositivo.

const BRIDGE_META := &"bridged"
const REPEAT_DELAY := 0.35
const REPEAT_RATE := 0.12
const STICK_RELEASE := 0.3

var tracker := InputDeviceTracker.new()
# A cena de combate liga isto quando o analógico esquerdo deve mover o cursor livre do
# grid (e não navegar menus/HUD).
var stick_drives_cursor: bool = false

var active_device: int:
	get:
		return tracker.active

var _held: Dictionary = {}   # origem -> {"key": int, "t": float, "echoing": bool}
var _stick_dir := Vector2i.ZERO
var _last_rumble_ms: int = -100000
var _last_rumble_priority: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputBindings.register()
	GameSettings.vibration_enabled = bool(GameSettings.load_settings().get("vibration", true))
	Input.joy_connection_changed.connect(_on_joy_connection_changed)

func is_gamepad() -> bool:
	return tracker.active == InputDeviceTracker.Device.GAMEPAD

# Analógico esquerdo com zona morta (zero sem controle ativo).
func cursor_axis() -> Vector2:
	return _stick(JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y)

# Zoom contínuo (BG3): analógico direito para cima aproxima (+), para baixo afasta (-), com zona
# morta. O eixo horizontal não faz nada (jogo isométrico, sem rotação). Teclado: Page Up/Down.
func zoom_axis() -> float:
	var v: float = -_stick(JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y).y
	return v + Input.get_action_strength(InputBindings.ZOOM_IN) - Input.get_action_strength(InputBindings.ZOOM_OUT)

# Visão de linha de visão dos inimigos: Shift ou gatilho direito (RT), segurado.
func is_los_held() -> bool:
	return Input.is_action_pressed(InputBindings.ENEMY_VIEW)

# Vibra o controle ativo. Sem controle, desligado nas opções ou em cooldown: nada acontece.
func rumble(kind: StringName) -> void:
	var now := Time.get_ticks_msec()
	var p: Dictionary = InputRumble.decide(kind, GameSettings.vibration_enabled,
		is_gamepad(), now, _last_rumble_ms, _last_rumble_priority)
	if p.is_empty():
		return
	_last_rumble_ms = now
	_last_rumble_priority = int(p["priority"])
	Input.start_joy_vibration(tracker.gamepad_id, p["weak"], p["strong"], p["duration"])

func _stick(axis_x: JoyAxis, axis_y: JoyAxis) -> Vector2:
	if not is_gamepad():
		return Vector2.ZERO
	return InputDeviceTracker.apply_deadzone(Vector2(
		Input.get_joy_axis(tracker.gamepad_id, axis_x),
		Input.get_joy_axis(tracker.gamepad_id, axis_y)))

# ── Classificação dos eventos ────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event.has_meta(BRIDGE_META):
		return
	if event is InputEventKey:
		if (event as InputEventKey).pressed:
			_after_note(tracker.note_key())
	elif event is InputEventMouseMotion:
		_after_note(tracker.note_mouse_motion((event as InputEventMouseMotion).relative))
	elif event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			_after_note(tracker.note_mouse_button())
	elif event is InputEventJoypadButton:
		_on_joy_button(event as InputEventJoypadButton)
	elif event is InputEventJoypadMotion:
		_on_joy_motion(event as InputEventJoypadMotion)

func _on_joy_button(event: InputEventJoypadButton) -> void:
	var was_gamepad := is_gamepad()
	if event.pressed:
		_after_note(tracker.note_joy_button(event.device))
	var keycode: int = InputBindings.bridge_key(event.button_index)
	if keycode == 0:
		return
	get_viewport().set_input_as_handled()   # evita ui_accept/ui_cancel nativos em dobro
	if not was_gamepad:
		return   # o botão que acorda o controle só troca o dispositivo
	var origin := "btn%d" % event.button_index
	if event.pressed:
		_press(origin, keycode)
	else:
		_release(origin)

func _on_joy_motion(event: InputEventJoypadMotion) -> void:
	_after_note(tracker.note_joy_axis(event.device, event.axis_value))
	# O analógico esquerdo é tratado por _process (ponte ou cursor); o evento nativo
	# moveria o foco da GUI em dobro.
	if event.axis == JOY_AXIS_LEFT_X or event.axis == JOY_AXIS_LEFT_Y:
		get_viewport().set_input_as_handled()

func _after_note(changed: bool) -> void:
	if not changed:
		return
	if is_gamepad():
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	else:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_release_all()
		Input.stop_joy_vibration(maxi(0, tracker.gamepad_id))

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if not connected:
		_after_note(tracker.note_joy_disconnected(device_id))

# ── Ponte de teclas ──────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	_poll_stick()
	for origin: String in _held.keys():
		var h: Dictionary = _held[origin]
		if not InputBindings.repeats(h["key"]):
			continue
		h["t"] += delta
		if h["t"] >= (REPEAT_RATE if h["echoing"] else REPEAT_DELAY):
			h["t"] = 0.0
			h["echoing"] = true
			_send_key(h["key"], true, true)

# Analógico esquerdo -> setas (4 vias, com histerese e repetição), exceto quando ele
# move o cursor livre do grid.
func _poll_stick() -> void:
	var dir := Vector2i.ZERO
	if is_gamepad() and not stick_drives_cursor:
		var raw := Vector2(
			Input.get_joy_axis(tracker.gamepad_id, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(tracker.gamepad_id, JOY_AXIS_LEFT_Y))
		dir = InputDeviceTracker.stick_dir4(raw,
			STICK_RELEASE if _stick_dir != Vector2i.ZERO else InputDeviceTracker.AXIS_SWITCH_THRESHOLD)
	if dir == _stick_dir:
		return
	_stick_dir = dir
	_release("stick")
	if dir != Vector2i.ZERO:
		_press("stick", _dir_key(dir))

func _dir_key(dir: Vector2i) -> int:
	if dir.x != 0:
		return KEY_RIGHT if dir.x > 0 else KEY_LEFT
	return KEY_DOWN if dir.y > 0 else KEY_UP

func _press(origin: String, keycode: int) -> void:
	_release(origin)
	_held[origin] = {"key": keycode, "t": 0.0, "echoing": false}
	_send_key(keycode, true)

func _release(origin: String) -> void:
	if not _held.has(origin):
		return
	_send_key(_held[origin]["key"], false)
	_held.erase(origin)

func _release_all() -> void:
	for origin: String in _held.keys():
		_release(origin)
	_stick_dir = Vector2i.ZERO

func _send_key(keycode: int, pressed: bool, echo: bool = false) -> void:
	var ev := InputEventKey.new()
	ev.keycode = keycode as Key
	ev.physical_keycode = keycode as Key
	ev.pressed = pressed
	ev.echo = echo
	ev.set_meta(BRIDGE_META, true)
	Input.parse_input_event(ev)
