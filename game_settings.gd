class_name GameSettings

# Variável (não const) para os testes redirecionarem para a pasta própria deles.
static var PATH := "user://settings.cfg"

# Espelho em memória da opção de vibração, atualizado por apply_settings; é o que o
# InputDevice consulta a cada vibração (evita reabrir o arquivo no meio do combate).
static var vibration_enabled: bool = true

static func load_settings() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return {"fullscreen": false, "vsync": true, "resolution": "1280x720", "vibration": true}
	return {
		"fullscreen": cfg.get_value("display", "fullscreen", false),
		"vsync":      cfg.get_value("display", "vsync", true),
		"resolution": cfg.get_value("display", "resolution", "1280x720"),
		"vibration":  cfg.get_value("input", "vibration", true),
	}

static func save_settings(settings: Dictionary) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "fullscreen", settings.get("fullscreen", false))
	cfg.set_value("display", "vsync",      settings.get("vsync", true))
	cfg.set_value("display", "resolution", settings.get("resolution", "1280x720"))
	cfg.set_value("input",   "vibration",  settings.get("vibration", true))
	cfg.save(PATH)

static func apply_settings(settings: Dictionary) -> void:
	vibration_enabled = settings.get("vibration", true)
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
