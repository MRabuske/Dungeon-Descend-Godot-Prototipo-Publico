extends CanvasLayer

var _overlay: ColorRect

func _ready() -> void:
	layer = 128
	_overlay = ColorRect.new()
	_overlay.color = Color.BLACK
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.modulate.a = 0.0
	add_child(_overlay)

func fade_to(scene_path: String) -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_overlay, "modulate:a", 1.0, 0.35)
	tw.tween_callback(func() -> void:
		get_tree().change_scene_to_file(scene_path)
	)
	tw.tween_interval(0.1)
	tw.tween_property(_overlay, "modulate:a", 0.0, 0.35)
	tw.tween_callback(func() -> void:
		_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	)
