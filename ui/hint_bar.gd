class_name HintBar
extends HBoxContainer

# Faixa de dicas de botões ("Ⓐ Confirmar  Ⓑ Voltar"). Os glifos são placeholders
# desenhados em código (estilo Xbox: A/B/X/Y coloridos, demais em "keycap"); a arte final
# substitui só Glyph. As dicas trocam sozinhas entre controle e teclado: a barra compara
# InputDevice.active_device a cada frame (polling, sem sinais) e se refaz quando muda.
# Entrada cuja ação não tem equivalente no dispositivo ativo (InputGlyphs.label == "")
# some.

const FONT_SIZE := 10
const A_COLOR := Color(0.30, 0.72, 0.35)
const B_COLOR := Color(0.85, 0.30, 0.28)
const X_COLOR := Color(0.28, 0.50, 0.90)
const Y_COLOR := Color(0.92, 0.78, 0.25)
const KEYCAP_COLOR := Color(0.20, 0.21, 0.28)

var _hints: Array = []   # [[StringName acao, String rotulo], ...]
var _drawn_device: int = -1

# Cria uma barra centralizada no rodapé de uma tela de tela cheia.
static func attach_bottom(parent: Control, hints: Array) -> HintBar:
	var bar := HintBar.new()
	bar.anchor_left = 0.0
	bar.anchor_right = 1.0
	bar.anchor_top = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top = -34.0
	bar.offset_bottom = -8.0
	parent.add_child(bar)
	bar.set_hints(hints)
	return bar

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 18)

# Dispositivo ativo lido do autoload por caminho: sem o identificador estático, a barra
# compila mesmo onde os autoloads ainda não existem (testes) e cai em teclado/mouse.
static func _active_device() -> int:
	var loop := Engine.get_main_loop()
	var autoload: Node = (loop as SceneTree).root.get_node_or_null("InputDevice") if loop is SceneTree else null
	return autoload.active_device if autoload != null else InputDeviceTracker.Device.KEYBOARD_MOUSE

func set_hints(hints: Array) -> void:
	if hints == _hints and _drawn_device == _active_device():
		return
	_hints = hints
	_rebuild()

func _process(_dt: float) -> void:
	if _active_device() != _drawn_device:
		_rebuild()

func _rebuild() -> void:
	_drawn_device = _active_device()
	for c in get_children():
		remove_child(c)
		c.queue_free()
	for h in _hints:
		var text: String = InputGlyphs.label(h[0], _drawn_device)
		if text == "":
			continue
		add_child(_make_entry(text, String(h[1]), _drawn_device == InputDeviceTracker.Device.GAMEPAD))

func _make_entry(glyph_text: String, label_text: String, gamepad: bool) -> Control:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	var glyph := Glyph.new()
	glyph.setup(glyph_text, gamepad)
	row.add_child(glyph)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.84))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 3)
	row.add_child(lbl)
	return row

# Glifo placeholder: círculo colorido para A/B/X/Y do controle, "keycap" para o resto.
class Glyph extends Control:
	var _text: String = ""
	var _round_color: Color = Color.TRANSPARENT

	func setup(text: String, gamepad: bool) -> void:
		_text = text
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		if gamepad:
			match text:
				"A": _round_color = HintBar.A_COLOR
				"B": _round_color = HintBar.B_COLOR
				"X": _round_color = HintBar.X_COLOR
				"Y": _round_color = HintBar.Y_COLOR
		custom_minimum_size = Vector2(22.0, 22.0)

	# A fonte do tema (pixel font) só é conhecida dentro da árvore.
	func _ready() -> void:
		if _round_color.a > 0.0:
			return
		var w: float = get_theme_default_font().get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, HintBar.FONT_SIZE).x
		custom_minimum_size = Vector2(maxf(22.0, w + 12.0), 22.0)

	func _draw() -> void:
		var font := get_theme_default_font()
		var text_size: Vector2 = font.get_string_size(_text, HORIZONTAL_ALIGNMENT_LEFT, -1, HintBar.FONT_SIZE)
		if _round_color.a > 0.0:
			draw_circle(size * 0.5, 11.0, _round_color)
		else:
			var box := StyleBoxFlat.new()
			box.bg_color = HintBar.KEYCAP_COLOR
			box.set_corner_radius_all(5)
			box.set_border_width_all(1)
			box.border_color = Color(0.55, 0.55, 0.65)
			draw_style_box(box, Rect2(Vector2.ZERO, size))
		var pos := Vector2((size.x - text_size.x) * 0.5, (size.y + text_size.y) * 0.5 - 3.0)
		draw_string(font, pos, _text, HORIZONTAL_ALIGNMENT_LEFT, -1, HintBar.FONT_SIZE, Color.WHITE)
