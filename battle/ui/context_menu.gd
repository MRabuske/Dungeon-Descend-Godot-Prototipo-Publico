class_name ContextMenu
extends Control

signal examine_requested(slot_index: int)

const BTN_NORMAL  := preload("res://assets/ui/buttons/btn_normal.png")
const BTN_HOVER   := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_PRESSED := preload("res://assets/ui/buttons/btn_pressed.png")

const MENU_W  := 148
const MENU_H  := 44
const PADDING := 6

var _slot_index: int = -1

func _ready() -> void:
	z_index      = 900
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(MENU_W, MENU_H)
	size = Vector2(MENU_W, MENU_H)
	_build()

func _build() -> void:
	# Placeholder background — artist replaces with popup_menu.png NinePatch
	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.08, 0.13, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   PADDING)
	margin.add_theme_constant_override("margin_right",  PADDING)
	margin.add_theme_constant_override("margin_top",    PADDING)
	margin.add_theme_constant_override("margin_bottom", PADDING)
	add_child(margin)

	var btn := TextureButton.new()
	btn.texture_normal      = BTN_NORMAL
	btn.texture_hover       = BTN_HOVER
	btn.texture_pressed     = BTN_PRESSED
	btn.custom_minimum_size = Vector2(MENU_W - PADDING * 2, MENU_H - PADDING * 2)
	btn.ignore_texture_size = true
	btn.stretch_mode        = TextureButton.STRETCH_SCALE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(btn)

	var lbl := Label.new()
	lbl.text = "Examinar"
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.75))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	btn.add_child(lbl)

	btn.pressed.connect(func() -> void:
		examine_requested.emit(_slot_index)
		queue_free()
	)

func show_at(pos: Vector2, slot_index: int) -> void:
	_slot_index = slot_index
	var vp := get_viewport_rect().size
	position = Vector2(
		clampf(pos.x, 0.0, vp.x - MENU_W),
		clampf(pos.y, 0.0, vp.y - MENU_H)
	)
	visible = true

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			queue_free()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if not Rect2(global_position, size).has_point(mb.global_position):
				queue_free()
				get_viewport().set_input_as_handled()
