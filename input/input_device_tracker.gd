class_name InputDeviceTracker
extends RefCounted

# Dispositivo ativo ("o último a ser usado manda"). Lógica pura, sem nós: o autoload
# InputDevice alimenta os note_* e reage ao retorno (true = o dispositivo mudou).

enum Device { KEYBOARD_MOUSE, GAMEPAD }

const AXIS_SWITCH_THRESHOLD := 0.5   # empurrão deliberado; abaixo disso é drift
const STICK_DEADZONE := 0.25         # abaixo disso o analógico não move cursor nem menu
const MOUSE_MIN_MOTION := 0.5        # ignora tremor sub-pixel do mouse

var active: Device = Device.KEYBOARD_MOUSE
var gamepad_id: int = -1
# Último input foi do mouse (e não de tecla/controle). Os anéis de seleção (FocusGlow) só
# aparecem quando é false: com o mouse, o hover/clique já mostra o item.
var pointer_active: bool = false

func note_key() -> bool:
	pointer_active = false
	return _set_active(Device.KEYBOARD_MOUSE)

func note_mouse_motion(relative: Vector2) -> bool:
	if relative.length() < MOUSE_MIN_MOTION:
		return false
	pointer_active = true
	return _set_active(Device.KEYBOARD_MOUSE)

func note_mouse_button() -> bool:
	pointer_active = true
	return _set_active(Device.KEYBOARD_MOUSE)

func note_joy_button(device_id: int) -> bool:
	gamepad_id = device_id
	pointer_active = false
	return _set_active(Device.GAMEPAD)

func note_joy_axis(device_id: int, value: float) -> bool:
	if absf(value) < AXIS_SWITCH_THRESHOLD:
		return false
	gamepad_id = device_id
	pointer_active = false
	return _set_active(Device.GAMEPAD)

# Desconectar o controle em uso devolve o jogo ao teclado/mouse; outro controle que
# ainda esteja ligado vira o ativo no próximo input dele.
func note_joy_disconnected(device_id: int) -> bool:
	if device_id != gamepad_id:
		return false
	gamepad_id = -1
	pointer_active = false
	return _set_active(Device.KEYBOARD_MOUSE)

func _set_active(device: Device) -> bool:
	if active == device:
		return false
	active = device
	return true

# Zona morta radial: devolve um vetor reescalado para 0..1 (zero dentro da zona morta).
static func apply_deadzone(v: Vector2, deadzone: float = STICK_DEADZONE) -> Vector2:
	var len := v.length()
	if len < deadzone:
		return Vector2.ZERO
	return v.normalized() * minf(1.0, (len - deadzone) / (1.0 - deadzone))

# Direção em 4 vias pelo eixo dominante (Vector2i.ZERO abaixo do limiar). Evita
# disparar duas setas numa diagonal.
static func stick_dir4(v: Vector2, threshold: float = AXIS_SWITCH_THRESHOLD) -> Vector2i:
	if v.length() < threshold:
		return Vector2i.ZERO
	if absf(v.x) >= absf(v.y):
		return Vector2i(1 if v.x > 0.0 else -1, 0)
	return Vector2i(0, 1 if v.y > 0.0 else -1)
