class_name ScreenFlash
extends ColorRect

# ======================================================
# Flash de tela no impacto.
# Adicione como filho do BattleScene, acima de tudo.
# Configuração no _ready do BattleScene:
#
#   var flash := ScreenFlash.new()
#   add_child(flash)
#   flash.setup()
# ======================================================

func setup() -> void:
	# Ocupa a tela toda, sem bloquear input
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	modulate.a   = 0.0
	z_index      = 100

# ======================================================
# PUBLIC
# ======================================================
func flash_white(duration := 0.06) -> void:
	flash(Color.WHITE, duration)

func flash_red(duration := 0.10) -> void:
	flash(Color(1.0, 0.15, 0.15), duration)

func flash(flash_color: Color, duration := 0.07) -> void:
	self.color   = Color(flash_color.r, flash_color.g, flash_color.b, 0.85)
	modulate     = Color.WHITE                               
	var tw := create_tween()
	tw.tween_property(self, "color:a", 0.0, duration) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
