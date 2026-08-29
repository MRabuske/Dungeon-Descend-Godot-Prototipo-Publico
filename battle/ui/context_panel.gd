class_name ContextPanel
extends Control

# ======================================================
# 🎨 ASSETS
# ======================================================
const PANEL_TEXTURE := preload("res://assets/ui/panels/panel_context.png")

# ──────────────────────────────────────────────────────
# 🔧 CONSTANTES DE AJUSTE FINO (MODIFIQUE AQUI!)
# ──────────────────────────────────────────────────────
# Margens para afastar os textos dos ornamentos e bordas da arte do painel
const MARGIN_PANEL_LEFT   := 20
const MARGIN_PANEL_RIGHT  := 15
const MARGIN_PANEL_TOP    := 50
const MARGIN_PANEL_BOTTOM := 14

# Distância vertical entre o título, subtítulo, descrição e dica
const CONTENT_SEPARATION  := 10
# ──────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE DE TAMANHOS
# ──────────────────────────────────────────────────────
const PANEL_PATCH    := 16
const FONT_TITLE     := 10
const FONT_SUBTITLE  := 8
const FONT_DESC      := 8
const FONT_HINT      := 7
# ──────────────────────────────────────────────────────

# ======================================================
# VARS
# ======================================================
var _title_lbl:    Label
var _subtitle_lbl: Label
var _desc_lbl:     Label
var _alt_lbl:      Label

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	_build_panel()

# ======================================================
# BUILD — PANEL
# ======================================================
func _build_panel() -> void:
	# Renderiza a moldura de fundo de forma independente
	var panel_bg := NinePatchRect.new()
	panel_bg.texture             = PANEL_TEXTURE
	panel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_bg.patch_margin_left   = PANEL_PATCH
	panel_bg.patch_margin_right  = PANEL_PATCH
	panel_bg.patch_margin_top    = PANEL_PATCH
	panel_bg.patch_margin_bottom = PANEL_PATCH
	panel_bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	add_child(panel_bg)

	# Container que gerencia as áreas seguras para escrita
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   MARGIN_PANEL_LEFT)
	margin.add_theme_constant_override("margin_right",  MARGIN_PANEL_RIGHT)
	margin.add_theme_constant_override("margin_top",    MARGIN_PANEL_TOP)
	margin.add_theme_constant_override("margin_bottom", MARGIN_PANEL_BOTTOM)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", CONTENT_SEPARATION)
	margin.add_child(vbox)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", FONT_TITLE)
	_title_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_title_lbl)

	_subtitle_lbl = Label.new()
	_subtitle_lbl.add_theme_font_size_override("font_size", FONT_SUBTITLE)
	_subtitle_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	_subtitle_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_subtitle_lbl)

	_desc_lbl = Label.new()
	_desc_lbl.add_theme_font_size_override("font_size", FONT_DESC)
	_desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_desc_lbl)

	_alt_lbl = Label.new()
	_alt_lbl.add_theme_font_size_override("font_size", FONT_HINT)
	_alt_lbl.add_theme_color_override("font_color", Color(0.50, 0.50, 0.50))
	_alt_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_alt_lbl)

# ======================================================
# PUBLIC API
# ======================================================
func setup(title: String, subtitle: String, desc: String, hint: String = "Hold ALT for details") -> void:
	_title_lbl.text    = title
	_subtitle_lbl.text = subtitle
	_desc_lbl.text     = desc
	_alt_lbl.text      = hint

func show_message(msg: String) -> void:
	_desc_lbl.text = msg
