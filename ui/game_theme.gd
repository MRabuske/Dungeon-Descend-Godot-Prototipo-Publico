extends Node

const FONT_PATH    := "res://assets/fonts/PressStart2P-Regular.ttf"
const DEFAULT_SIZE := 12

# ── Visual tweaks ─────────────────────────────────────
const OUTLINE_SIZE  := 2
const OUTLINE_COLOR := Color(0.05, 0.04, 0.10, 0.92)   # preto levemente roxo
const SHADOW_COLOR  := Color(0.00, 0.00, 0.00, 0.50)
const SHADOW_X      := 2
const SHADOW_Y      := 2
# ──────────────────────────────────────────────────────

# Tipos de controle que exibem texto e se beneficiam do outline/shadow
const TEXT_TYPES := [
	"Label", "Button", "RichTextLabel",
	"LineEdit", "OptionButton", "CheckBox",
]

func _ready() -> void:
	if not ResourceLoader.exists(FONT_PATH):
		push_warning("GameTheme: fonte não encontrada em " + FONT_PATH)
		return

	var font := load(FONT_PATH) as FontFile
	if font == null:
		push_warning("GameTheme: falha ao carregar fonte")
		return

	# Renderização pixel-perfect — sem antialiasing nem subpixel blur
	font.antialiasing         = TextServer.FONT_ANTIALIASING_NONE
	font.hinting              = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED

	var theme := Theme.new()
	theme.default_font      = font
	theme.default_font_size = DEFAULT_SIZE

	for t in TEXT_TYPES:
		theme.set_constant("outline_size",    t, OUTLINE_SIZE)
		theme.set_color("font_outline_color", t, OUTLINE_COLOR)
		theme.set_constant("shadow_offset_x", t, SHADOW_X)
		theme.set_constant("shadow_offset_y", t, SHADOW_Y)
		theme.set_color("font_shadow_color",  t, SHADOW_COLOR)

	get_tree().get_root().theme = theme
