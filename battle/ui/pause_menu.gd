class_name PauseMenu
extends Control

signal resume_requested
signal menu_requested

# ======================================================
# 🎨 ASSETS
# ======================================================
const PANEL_TEXTURE := preload("res://assets/ui/panels/panel_small.png")

const BTN_NORMAL  := preload("res://assets/ui/buttons/btn_normal.png")
const BTN_HOVER   := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_PRESSED := preload("res://assets/ui/buttons/btn_pressed.png")

const BTN_RED_NORMAL  := preload("res://assets/ui/buttons/btn_pressed.png")
const BTN_RED_HOVER   := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_RED_PRESSED := preload("res://assets/ui/buttons/btn_pressed.png")

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE DE TAMANHOS
# ──────────────────────────────────────────────────────
const PANEL_PATCH := 32
const PANEL_W     := 380
const PANEL_H     := 380
const TITLE_SIZE  := 28
# ──────────────────────────────────────────────────────

const TITLE_COLOR := Color(0.90, 0.78, 0.20)

# ======================================================
# VARS
# ======================================================
var _options: OptionsPanel
var _panel: NinePatchRect

var _btns: Array[TextureButton]  = []
var _btn_normals: Array[Texture2D] = []
var _callbacks: Array[Callable]  = []
var _focused: int = 0

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	mouse_filter  = Control.MOUSE_FILTER_STOP
	modulate.a    = 0.0
	visible       = false

	z_index = 1000

	_build_overlay()
	_build_panel()
	_build_options()

# ======================================================
# BUILD — OVERLAY
# ======================================================
func _build_overlay() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.68)
	add_child(overlay)

# ======================================================
# BUILD — PANEL
# ======================================================
func _build_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = NinePatchRect.new()
	_panel.texture             = PANEL_TEXTURE
	_panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	_panel.patch_margin_left   = PANEL_PATCH
	_panel.patch_margin_right  = PANEL_PATCH
	_panel.patch_margin_top    = PANEL_PATCH
	_panel.patch_margin_bottom = PANEL_PATCH
	center.add_child(_panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    28)
	margin.add_theme_constant_override("margin_bottom", 28)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(vbox)

	_build_title(vbox)
	_add_separator(vbox)
	_build_buttons(vbox)

	var hint := Label.new()
	hint.text = "↑ ↓ Navegar   ·   ENTER Selecionar   ·   ESC Retomar"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.62))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.anchor_left   = 0.0
	hint.anchor_right  = 1.0
	hint.anchor_top    = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_top    = -32.0
	hint.offset_bottom = -8.0
	hint.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	add_child(hint)

# ======================================================
# BUILD — TITLE
# ======================================================
func _build_title(parent: Control) -> void:
	var title := Label.new()
	title.text = "PAUSADO"
	title.add_theme_font_size_override("font_size", TITLE_SIZE)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(title)

# ======================================================
# BUILD — BUTTONS
# ======================================================
func _build_buttons(parent: Control) -> void:
	_add_texture_button(parent, "Continuar", BTN_NORMAL, BTN_HOVER, BTN_PRESSED,
		func() -> void: resume_requested.emit())
	_add_texture_button(parent, "Opcoes", BTN_NORMAL, BTN_HOVER, BTN_PRESSED,
		func() -> void: _options.show_panel())
	_add_texture_button(parent, "Menu Principal",
		BTN_RED_NORMAL, BTN_RED_HOVER, BTN_RED_PRESSED,
		func() -> void: menu_requested.emit())

# ======================================================
# BUILD — OPTIONS
# ======================================================
func _build_options() -> void:
	_options = OptionsPanel.new()
	add_child(_options)

# ======================================================
# SHOW / HIDE
# ======================================================
func show_menu() -> void:
	modulate.a   = 0.0
	visible      = true
	_panel.scale = Vector2(0.92, 0.92)
	_set_focus(_focused)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self,   "modulate:a", 1.0,        0.18)
	tw.tween_property(_panel, "scale",      Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_menu() -> void:
	if _options != null and _options.visible:
		_options.hide_panel()

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self,   "modulate:a", 0.0,                 0.14)
	tw.tween_property(_panel, "scale",      Vector2(0.92, 0.92), 0.14)
	tw.chain().tween_callback(func(): visible = false)

# ======================================================
# HELPER — TEXTURE BUTTON
# ======================================================
func _add_texture_button(parent: Control, text: String,
		tex_n: Texture2D, tex_h: Texture2D, tex_p: Texture2D,
		cb: Callable) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal        = tex_n
	btn.texture_hover         = tex_h
	btn.texture_pressed       = tex_p
	btn.custom_minimum_size   = Vector2(260, 52)
	btn.ignore_texture_size   = true
	btn.stretch_mode          = TextureButton.STRETCH_SCALE
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(btn)
	_btns.append(btn)
	_btn_normals.append(tex_n)
	_callbacks.append(cb)

	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.add_theme_color_override("font_color",        Color(0.90, 0.85, 0.75))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	btn.add_child(lbl)

	btn.pressed.connect(cb)
	btn.mouse_entered.connect(func(): _set_focus(_btns.find(btn)))
	return btn

# ======================================================
# KEYBOARD INPUT
# ======================================================
func _unhandled_input(event: InputEvent) -> void:
	if not visible or _options.visible:
		return
	if not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	var handled := true
	match (event as InputEventKey).keycode:
		KEY_UP, KEY_W:
			_move_focus(-1)
		KEY_DOWN, KEY_S:
			_move_focus(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _focused < _callbacks.size():
				_callbacks[_focused].call()
		KEY_ESCAPE, KEY_P:
			resume_requested.emit()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _move_focus(delta: int) -> void:
	_set_focus((_focused + delta + _btns.size()) % _btns.size())

func _set_focus(idx: int) -> void:
	if not _btns.is_empty() and _focused < _btns.size():
		_btns[_focused].texture_normal = _btn_normals[_focused]
	_focused = idx
	if _focused < _btns.size():
		_btns[_focused].texture_normal = BTN_HOVER

func _add_separator(parent: Control) -> void:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.22, 0.22, 0.28))
	parent.add_child(sep)
