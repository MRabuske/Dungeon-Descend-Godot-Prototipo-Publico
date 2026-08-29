class_name OptionsPanel
extends Control

# ======================================================
# 🎨 ASSETS
# ======================================================
const PANEL_TEXTURE := preload("res://assets/ui/panels/options_panel.png")

const BTN_NORMAL  := preload("res://assets/ui/buttons/btn_normal.png")
const BTN_HOVER   := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_PRESSED := preload("res://assets/ui/buttons/btn_pressed.png")

const TOGGLE_ON  := preload("res://assets/ui/buttons/toggle_on.png")
const TOGGLE_OFF := preload("res://assets/ui/buttons/toggle_off.png")

const DD_HEADER_CLOSED       := preload("res://assets/ui/dropdown/dropdown_header.png")
const DD_HEADER_OPEN         := preload("res://assets/ui/dropdown/dropdown_header_pressed.png")
const DD_HEADER_PRESSED_HOVER := preload("res://assets/ui/dropdown/dropdown_header_pressed_hover.png")
const DD_HEADER_CLOSED_HOVER := preload("res://assets/ui/dropdown/dropdown_header_hover.png")

const DD_LIST_BG       := preload("res://assets/ui/dropdown/dropdown_bg.png")
const DD_ITEM_NORMAL   := preload("res://assets/ui/dropdown/dropdown_item_normal.png")
const DD_ITEM_HOVER    := preload("res://assets/ui/dropdown/dropdown_item_hover.png")
const DD_ITEM_SELECTED := preload("res://assets/ui/dropdown/dropdown_item_selected.png")

const RESOLUTIONS       := ["1280x720", "1600x900", "1920x1080"]
const RESOLUTION_LABELS := ["1280 x 720", "1600 x 900", "1920 x 1080"]

# ======================================================
# VARS
# ======================================================
var _fullscreen_btn: TextureButton
var _vsync_btn: TextureButton
var _overlay: ColorRect
var _panel: Control
var _res_dropdown_btn: TextureButton
var _res_header_label: Label
var _res_popup: PanelContainer
var _res_list: VBoxContainer
var _dropdown_open := false

var _option_items: Array[Control] = []
var _focused_opt: int = 0
var _res_idx: int = 0

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	mouse_filter  = Control.MOUSE_FILTER_STOP
	modulate.a    = 0.0
	visible       = false

	_build_overlay()
	_build_panel()
	_build_res_popup()

# ======================================================
# BUILD — OVERLAY
# ======================================================
func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0, 0, 0, 0.72)
	add_child(_overlay)

# ======================================================
# BUILD — PANEL
# ======================================================
func _build_panel() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_panel = Control.new()
	_panel.custom_minimum_size = Vector2(520, 360)
	center.add_child(_panel)

	# Background NinePatch
	var panel_bg := NinePatchRect.new()
	panel_bg.texture = PANEL_TEXTURE
	panel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_bg.patch_margin_left   = 45
	panel_bg.patch_margin_top    = 75
	panel_bg.patch_margin_right  = 45
	panel_bg.patch_margin_bottom = 15
	_panel.add_child(panel_bg)

	# Margin
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    45)
	margin.add_theme_constant_override("margin_bottom", 28)
	_panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	margin.add_child(vbox)

	_build_title(vbox)
	_add_separator(vbox)
	_build_toggles(vbox)
	_add_separator(vbox)
	_build_resolution_row(vbox)
	_add_separator(vbox)
	_build_close_button(vbox)

# ======================================================
# BUILD — TITLE
# ======================================================
func _build_title(parent: Control) -> void:
	var title := Label.new()
	title.text = "OPCOES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	parent.add_child(title)

# ======================================================
# BUILD — TOGGLES
# ======================================================
func _build_toggles(parent: Control) -> void:
	var settings := GameSettings.load_settings()
	_fullscreen_btn = _add_toggle(parent, "Tela Cheia", settings.get("fullscreen", false), func(on: bool):
		_save_and_apply("fullscreen", on)
	)
	_vsync_btn = _add_toggle(parent, "Vsync", settings.get("vsync", true), func(on: bool):
		_save_and_apply("vsync", on)
	)
	# Store the two rows (last two children added to parent)
	var children := parent.get_children()
	_option_items.append(children[children.size() - 2])
	_option_items.append(children[children.size() - 1])

# ======================================================
# BUILD — RESOLUTION ROW
# ======================================================
# ======================================================
# BUILD — RESOLUTION ROW (VERSÃO CORRIGIDA - FUNCIONA!)
# ======================================================
func _build_resolution_row(parent: Control) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	_option_items.append(row)

	var lbl := Label.new()
	lbl.text = "Resolucao"
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	# Container para o botão dropdown
	var btn_container := Control.new()
	btn_container.custom_minimum_size = Vector2(200, 48)
	btn_container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	row.add_child(btn_container)

	_res_dropdown_btn = TextureButton.new()
	_res_dropdown_btn.ignore_texture_size   = true
	_res_dropdown_btn.stretch_mode          = TextureButton.STRETCH_SCALE
	_res_dropdown_btn.custom_minimum_size   = Vector2(200, 48)
	_res_dropdown_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_res_dropdown_btn.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_res_dropdown_btn.texture_normal  = DD_HEADER_CLOSED
	_res_dropdown_btn.texture_hover   = DD_HEADER_CLOSED_HOVER
	_res_dropdown_btn.texture_pressed = DD_HEADER_OPEN
	btn_container.add_child(_res_dropdown_btn)

	# Criar um MarginContainer para o label (funciona!)
	var margin_container := MarginContainer.new()
	margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_container.add_theme_constant_override("margin_left", 12)
	margin_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res_dropdown_btn.add_child(margin_container)
	
	# Label do header
	_res_header_label = Label.new()
	_res_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_res_header_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_res_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_res_header_label.add_theme_color_override("font_color", Color.WHITE)
	_res_header_label.add_theme_font_size_override("font_size", 14)
	_res_header_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin_container.add_child(_res_header_label)

	# Inicializa com o valor salvo nas settings
	var saved := GameSettings.load_settings().get("resolution", RESOLUTIONS[0]) as String
	var idx   := RESOLUTIONS.find(saved)
	_res_header_label.text = RESOLUTION_LABELS[idx if idx >= 0 else 0]

	_res_dropdown_btn.pressed.connect(func():
		if _dropdown_open: _close_dropdown()
		else: _open_dropdown()
	)

# ======================================================
# BUILD — RES POPUP
# ======================================================
func _build_res_popup() -> void:
	_res_popup = PanelContainer.new()
	_res_popup.visible = false
	_res_popup.custom_minimum_size = Vector2(160, 100)
	add_child(_res_popup)

	# Remove estilo padrão do PanelContainer
	_res_popup.add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	# Textura de fundo via NinePatch
	var popup_bg := NinePatchRect.new()
	popup_bg.texture = DD_LIST_BG
	popup_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_bg.patch_margin_left   = 10
	popup_bg.patch_margin_top    = 10
	popup_bg.patch_margin_right  = 10
	popup_bg.patch_margin_bottom = 10
	_res_popup.add_child(popup_bg)

	# Margem interna
	var popup_margin := MarginContainer.new()
	popup_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup_margin.add_theme_constant_override("margin_left",   4)
	popup_margin.add_theme_constant_override("margin_right",  4)
	popup_margin.add_theme_constant_override("margin_top",    4)
	popup_margin.add_theme_constant_override("margin_bottom", 4)
	_res_popup.add_child(popup_margin)

	_res_list = VBoxContainer.new()
	_res_list.add_theme_constant_override("separation", 2)
	popup_margin.add_child(_res_list)

	for i in RESOLUTION_LABELS.size():
		_res_list.add_child(_build_res_item(i))

# ======================================================
# BUILD — RES ITEM
#
# FIX: O Label agora é irmão do TextureButton dentro de um
# Control pai com tamanho definido. Assim o PRESET_FULL_RECT
# tem referência de tamanho e o texto aparece corretamente.
# ======================================================
func _build_res_item(i: int) -> Control:
	var item := TextureButton.new()
	item.ignore_texture_size    = true
	item.stretch_mode           = TextureButton.STRETCH_SCALE
	item.custom_minimum_size    = Vector2(152, 32)
	item.size_flags_horizontal  = Control.SIZE_EXPAND_FILL
	item.texture_normal  = DD_ITEM_NORMAL
	item.texture_hover   = DD_ITEM_HOVER
	item.texture_pressed = DD_ITEM_SELECTED

	# Label filho do TextureButton: herda o tamanho dele e renderiza por cima
	# da textura. MOUSE_FILTER_IGNORE garante que o clique chega ao botão pai.
	var lbl := Label.new()
	lbl.text = RESOLUTION_LABELS[i]
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.add_theme_font_size_override("font_size", 14)
	item.add_child(lbl)

	item.pressed.connect(func():
		_res_header_label.text = RESOLUTION_LABELS[i]
		_save_and_apply("resolution", RESOLUTIONS[i])
		_close_dropdown()
	)

	return item

# ======================================================
# BUILD — CLOSE BUTTON
# ======================================================
func _build_close_button(parent: Control) -> void:
	var btn := _add_texture_button(parent, "Fechar", hide_panel)
	btn.custom_minimum_size = Vector2(200, 52)
	_option_items.append(btn)

# ======================================================
# DROPDOWN
# ======================================================
func _open_dropdown() -> void:
	_dropdown_open = true
	_res_dropdown_btn.texture_normal = DD_HEADER_OPEN
	_res_dropdown_btn.texture_hover  = DD_HEADER_PRESSED_HOVER
	_res_popup.global_position = _res_dropdown_btn.global_position + Vector2(0, 42)
	_res_popup.visible = true

func _close_dropdown() -> void:
	_dropdown_open = false
	_res_dropdown_btn.texture_normal = DD_HEADER_CLOSED
	_res_dropdown_btn.texture_hover  = DD_HEADER_CLOSED_HOVER
	_res_popup.visible = false

# ======================================================
# SHOW / HIDE
# ======================================================
func show_panel() -> void:
	modulate.a  = 0.0
	visible     = true
	_panel.scale = Vector2(0.95, 0.95)

	var saved := GameSettings.load_settings().get("resolution", RESOLUTIONS[0]) as String
	_res_idx = maxi(0, RESOLUTIONS.find(saved))
	_set_opt_focus(0)

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self,   "modulate:a", 1.0,        0.18)
	tw.tween_property(_panel, "scale",      Vector2.ONE, 0.18)

func hide_panel() -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self,   "modulate:a", 0.0,                  0.14)
	tw.tween_property(_panel, "scale",      Vector2(0.95, 0.95),  0.14)
	tw.chain().tween_callback(func(): visible = false)

# ======================================================
# KEYBOARD INPUT
# ======================================================
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	var key := (event as InputEventKey).keycode
	if _dropdown_open:
		if key in [KEY_ESCAPE, KEY_UP, KEY_DOWN, KEY_W, KEY_S]:
			_close_dropdown()
			get_viewport().set_input_as_handled()
		return
	var handled := true
	match key:
		KEY_UP, KEY_W:
			_move_opt_focus(-1)
		KEY_DOWN, KEY_S:
			_move_opt_focus(1)
		KEY_LEFT, KEY_A:
			if _focused_opt == 2:
				_cycle_resolution(-1)
		KEY_RIGHT, KEY_D:
			if _focused_opt == 2:
				_cycle_resolution(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_activate_focused_opt()
		KEY_ESCAPE:
			hide_panel()
		_:
			handled = false
	if handled:
		get_viewport().set_input_as_handled()

func _move_opt_focus(delta: int) -> void:
	_set_opt_focus((_focused_opt + delta + _option_items.size()) % _option_items.size())

func _set_opt_focus(idx: int) -> void:
	if not _option_items.is_empty() and _focused_opt < _option_items.size():
		_option_items[_focused_opt].modulate = Color.WHITE
	_focused_opt = idx
	if _focused_opt < _option_items.size():
		_option_items[_focused_opt].modulate = Color(1.18, 1.12, 0.88)

func _activate_focused_opt() -> void:
	match _focused_opt:
		0: _fullscreen_btn.pressed.emit()
		1: _vsync_btn.pressed.emit()
		2: _cycle_resolution(1)
		3: hide_panel()

func _cycle_resolution(delta: int) -> void:
	_res_idx = (_res_idx + delta + RESOLUTIONS.size()) % RESOLUTIONS.size()
	_res_header_label.text = RESOLUTION_LABELS[_res_idx]
	_save_and_apply("resolution", RESOLUTIONS[_res_idx])

# ======================================================
# HELPERS
# ======================================================
func _save_and_apply(key: String, value: Variant) -> void:
	var s := GameSettings.load_settings()
	s[key] = value
	GameSettings.save_settings(s)
	GameSettings.apply_settings(s)

func _add_texture_button(parent: Control, text: String, cb: Callable) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal  = BTN_NORMAL
	btn.texture_hover   = BTN_HOVER
	btn.texture_pressed = BTN_PRESSED
	btn.custom_minimum_size     = Vector2(220, 52)
	btn.ignore_texture_size     = true
	btn.stretch_mode            = TextureButton.STRETCH_SCALE
	btn.size_flags_horizontal   = Control.SIZE_SHRINK_CENTER
	parent.add_child(btn)

	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	btn.add_child(lbl)

	btn.pressed.connect(cb)
	return btn

func _add_toggle(parent: Control, label_text: String, default_on: bool, cb: Callable) -> TextureButton:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(lbl)

	var toggle := TextureButton.new()
	toggle.custom_minimum_size = Vector2(90, 40)
	toggle.ignore_texture_size = true
	toggle.set_meta("on", default_on)
	
	toggle.texture_normal = TOGGLE_ON if default_on else TOGGLE_OFF
	row.add_child(toggle)

	toggle.pressed.connect(func():
		var on := not toggle.get_meta("on") as bool
		toggle.set_meta("on", on)
		toggle.texture_normal = TOGGLE_ON if on else TOGGLE_OFF
		cb.call(on)
	)

	return toggle

func _add_separator(parent: Control) -> void:
	var sep := ColorRect.new()
	sep.color = Color(1, 1, 1, 0.08)
	sep.custom_minimum_size = Vector2(0, 2)
	parent.add_child(sep)
