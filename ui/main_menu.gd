class_name MainMenu
extends Control

# ======================================================
# ASSETS
# ======================================================
const BG_TEXTURE   := preload("res://assets/ui/backgrounds/menu_bg.png")
const LOGO_TEXTURE := preload("res://assets/ui/logo/logo.png")

const BTN_NORMAL  := preload("res://assets/ui/buttons/btn_normal.png")
const BTN_HOVER   := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_PRESSED := preload("res://assets/ui/buttons/btn_pressed.png")

# ======================================================
# VARS
# ======================================================
var _options: OptionsPanel

var _btns: Array[TextureButton] = []
var _lbl_containers: Array[Control] = []
var _callbacks: Array[Callable] = []
var _focused: int = 0

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	GameSettings.apply_settings(GameSettings.load_settings())

	_build_background()
	_build_ui()
	_build_version_label()
	_build_options_panel()

# ======================================================
# INPUT
# ======================================================
func _unhandled_input(event: InputEvent) -> void:
	if _options.visible:
		return
	if not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	match (event as InputEventKey).keycode:
		KEY_UP:
			_move_focus(-1)
		KEY_DOWN:
			_move_focus(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _focused < _callbacks.size():
				_callbacks[_focused].call()

func _move_focus(delta: int) -> void:
	var next := _focused
	for _i in _btns.size():
		next = (next + delta + _btns.size()) % _btns.size()
		if _btns[next].visible:
			break
	if next != _focused:
		_set_focus(next)

func _set_focus(idx: int) -> void:
	_unfocus_btn(_focused)
	_focused = idx
	_focus_btn(_focused)

func _focus_btn(idx: int) -> void:
	_btns[idx].texture_normal = BTN_HOVER
	_lbl_containers[idx].create_tween().tween_property(_lbl_containers[idx], "position:x", 6.0, 0.08)

func _unfocus_btn(idx: int) -> void:
	_btns[idx].texture_normal = BTN_NORMAL
	_lbl_containers[idx].create_tween().tween_property(_lbl_containers[idx], "position:x", 0.0, 0.08)

# ======================================================
# BUILD — BACKGROUND
# ======================================================
func _build_background() -> void:
	var bg := TextureRect.new()
	bg.texture      = BG_TEXTURE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0, 0.55)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dark)

# ======================================================
# BUILD — UI (logo + botões)
# ======================================================
func _build_ui() -> void:
	var ui := Control.new()
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ui)

	var panel := VBoxContainer.new()
	panel.anchor_left   = 0.08
	panel.anchor_right  = 0.45
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_constant_override("separation", 14)
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	ui.add_child(panel)

	var logo := TextureRect.new()
	logo.texture              = LOGO_TEXTURE
	logo.stretch_mode         = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size  = Vector2(520, 240)
	panel.add_child(logo)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	panel.add_child(spacer)

	_add_button(panel, "Nova Run",  _on_nova_run)

	var continuar := _add_button(panel, "Continuar", _on_continuar)
	continuar.visible = FileAccess.file_exists(DungeonState.SAVE_PATH)

	_add_button(panel, "Opcoes",  _on_opcoes)
	_add_button(panel, "Credits", _on_credits)
	_add_button(panel, "Sair",    _on_sair)

	_focus_btn(0)

	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.5)

# ======================================================
# BUILD — VERSION LABEL
# ======================================================
func _build_version_label() -> void:
	var version := Label.new()
	version.text = "v0.1.0-dev"
	version.add_theme_font_size_override("font_size", 12)
	version.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	version.position = Vector2(16, get_viewport_rect().size.y - 32)
	add_child(version)

# ======================================================
# BUILD — OPTIONS PANEL
# ======================================================
func _build_options_panel() -> void:
	_options = OptionsPanel.new()
	add_child(_options)

# ======================================================
# BUTTON
# ======================================================
func _add_button(parent: Control, text: String, cb: Callable) -> TextureButton:
	var idx := _btns.size()

	var btn := TextureButton.new()
	btn.texture_normal        = BTN_NORMAL
	btn.texture_hover         = BTN_HOVER
	btn.texture_pressed       = BTN_PRESSED
	btn.custom_minimum_size   = Vector2(300, 50)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.ignore_texture_size   = true
	btn.stretch_mode          = TextureButton.STRETCH_SCALE
	parent.add_child(btn)
	_btns.append(btn)
	_callbacks.append(cb)

	var lbl_container := Control.new()
	lbl_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl_container)
	_lbl_containers.append(lbl_container)

	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color",        Color(0.90, 0.85, 0.75))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl_container.add_child(lbl)

	btn.mouse_entered.connect(func():
		_set_focus(idx)
	)
	btn.mouse_exited.connect(func():
		if _focused != idx:
			_unfocus_btn(idx)
	)

	btn.pressed.connect(cb)
	return btn

# ======================================================
# ACTIONS
# ======================================================
func _on_nova_run() -> void:
	DungeonState.current_run = DungeonState.new()
	DungeonState.current_run.generate()
	SceneTransition.fade_to("res://ui/party_select.tscn")

func _on_continuar() -> void:
	DungeonState.current_run = DungeonState.load_save()
	if DungeonState.current_run == null:
		return
	if DungeonState.current_run.party_names.is_empty():
		DungeonState.delete_save()
		DungeonState.current_run = null
		return
	if DungeonState.current_run.pending_room:
		BattleState.setup_party(DungeonState.current_run.party_names)
		SceneTransition.fade_to("res://battle/battle_scene.tscn")
	else:
		BattleState.setup_party(DungeonState.current_run.party_names)
		SceneTransition.fade_to("res://ui/dungeon_map.tscn")

func _on_opcoes() -> void:
	_options.show_panel()

func _on_credits() -> void:
	pass

func _on_sair() -> void:
	get_tree().quit()
