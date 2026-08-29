class_name TurnTransitionLayer
extends CanvasLayer

const OVERLAY_COLOR     := Color(0.05, 0.05, 0.10)
const OVERLAY_MAX_ALPHA := 0.72
const TITLE_COLOR       := Color(1.0, 0.90, 0.70)
const SUBTITLE_COLOR    := Color(0.85, 0.78, 0.60)

var _overlay: ColorRect
var _label_root: VBoxContainer
var _title_label: Label
var _subtitle_label: Label
var _tween: Tween

func _ready() -> void:
	layer = 10

	_overlay = ColorRect.new()
	_overlay.color = OVERLAY_COLOR
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.modulate.a = 0.0
	add_child(_overlay)

	_label_root = VBoxContainer.new()
	_label_root.alignment = BoxContainer.ALIGNMENT_CENTER
	_label_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label_root.modulate.a = 0.0
	_label_root.custom_minimum_size = Vector2(600.0, 0.0)
	_label_root.anchor_left   = 0.5
	_label_root.anchor_top    = 0.5
	_label_root.anchor_right  = 0.5
	_label_root.anchor_bottom = 0.5
	_label_root.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label_root.grow_vertical   = Control.GROW_DIRECTION_BOTH
	add_child(_label_root)

	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.add_theme_font_size_override("font_size", 28)
	_title_label.add_theme_color_override("font_color", TITLE_COLOR)
	_label_root.add_child(_title_label)

	_subtitle_label = Label.new()
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_subtitle_label.add_theme_font_size_override("font_size", 18)
	_subtitle_label.add_theme_color_override("font_color", SUBTITLE_COLOR)
	_label_root.add_child(_subtitle_label)

func show_turn(title: String, subtitle: String, on_done: Callable) -> void:
	if not is_inside_tree():
		on_done.call()
		return

	if _tween:
		_tween.kill()

	_title_label.text = title
	_subtitle_label.text = subtitle

	_tween = create_tween()
	_tween.tween_method(_set_alpha, 0.0, 1.0, 0.3)
	_tween.tween_interval(0.5)
	_tween.tween_method(_set_alpha, 1.0, 0.0, 0.4)
	_tween.tween_callback(on_done)

func _set_alpha(alpha: float) -> void:
	_overlay.modulate.a = alpha * OVERLAY_MAX_ALPHA
	_label_root.modulate.a = alpha
