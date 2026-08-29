class_name GameSettings

const PATH := "user://settings.cfg"

static func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return {"fullscreen": false, "vsync": true, "resolution": "1280x720"}
	return {
		"fullscreen": cfg.get_value("display", "fullscreen", false),
		"vsync":      cfg.get_value("display", "vsync", true),
		"resolution": cfg.get_value("display", "resolution", "1280x720"),
	}

static func save_settings(settings: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", settings.get("fullscreen", false))
	cfg.set_value("display", "vsync",      settings.get("vsync", true))
	cfg.set_value("display", "resolution", settings.get("resolution", "1280x720"))
	cfg.save(PATH)

static func apply_settings(settings: Dictionary) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if settings.get("fullscreen", false)
		else DisplayServer.WINDOW_MODE_WINDOWED
	)
	DisplayServer.window_set_vsync_mode(
		DisplayServer.VSYNC_ENABLED if settings.get("vsync", true)
		else DisplayServer.VSYNC_DISABLED
	)
	if not settings.get("fullscreen", false):
		var res_str: String = settings.get("resolution", "1280x720")
		var parts := res_str.split("x")
		if parts.size() == 2:
			var w := int(parts[0])
			var h := int(parts[1])
			if w > 0 and h > 0:
				DisplayServer.window_set_size(Vector2i(w, h))
