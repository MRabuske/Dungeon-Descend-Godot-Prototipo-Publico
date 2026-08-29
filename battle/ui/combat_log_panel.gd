class_name CombatLogPanel
extends Control

# ======================================================
# 🎨 ASSETS
# ======================================================
const PANEL_TEXTURE := preload("res://assets/ui/panels/panel_log.png")

# ──────────────────────────────────────────────────────
# 🔧 CONSTANTES DE AJUSTE FINO (MODIFIQUE AQUI!)
# ──────────────────────────────────────────────────────
const MARGIN_PANEL_LEFT   := 22
const MARGIN_PANEL_RIGHT  := 14
const MARGIN_PANEL_TOP    := 45
const MARGIN_PANEL_BOTTOM := 20

# Separação vertical geral entre os blocos (Título -> Linha Sepradora -> Caixa de Logs)
const CONTENT_SEPARATION  := 4

# Separação vertical interna entre cada linha de texto do log de combate
const LOG_LINE_SEPARATION := 2
# ──────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE DE TAMANHOS
# ──────────────────────────────────────────────────────
const PANEL_PATCH   := 16
const FONT_TITLE    := 9
const FONT_ENTRY    := 9
const MAX_VISIBLE   := 25 # 👈 Pode aumentar esse número agora que temos scroll!
# ──────────────────────────────────────────────────────

const TYPE_COLORS := {
	"dmg":    Color(0.95, 0.42, 0.32),
	"heal":   Color(0.30, 0.88, 0.50),
	"miss":   Color(0.72, 0.72, 0.55),
	"status": Color(0.75, 0.52, 0.95),
	"system": Color(0.58, 0.60, 0.65),
	"crit":   Color(1.00, 0.85, 0.10),
}

# ======================================================
# VARS
# ======================================================
var _state: BattleState
var _entry_lbls: Array = []
var _scroll_container: ScrollContainer # 👈 Referência para controlar a rolagem programaticamente

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	_build_panel()

# ======================================================
# BUILD — PANEL
# ======================================================
func _build_panel() -> void:
	var panel_bg := NinePatchRect.new()
	panel_bg.texture             = PANEL_TEXTURE
	panel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_bg.patch_margin_left   = PANEL_PATCH
	panel_bg.patch_margin_right  = PANEL_PATCH
	panel_bg.patch_margin_top    = PANEL_PATCH
	panel_bg.patch_margin_bottom = PANEL_PATCH
	panel_bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	add_child(panel_bg)

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

	#var title := Label.new()
	#title.text = "COMBAT LOG"
	#title.add_theme_font_size_override("font_size", FONT_TITLE)
	#title.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))
	#vbox.add_child(title)
#
	#var sep := HSeparator.new()
	#sep.add_theme_color_override("color", Color(0.18, 0.18, 0.22))
	#vbox.add_child(sep)

	# 1. Criamos o ScrollContainer e dizemos para ele se esticar no espaço vertical restante
	_scroll_container = ScrollContainer.new()
	_scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED # Desativa barra horizontal perigosa
	_scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO       # Mostra barra vertical só se necessário
	vbox.add_child(_scroll_container)

	# 2. O VBox das linhas agora vira FILHO do ScrollContainer
	var log_lines_vbox := VBoxContainer.new()
	log_lines_vbox.add_theme_constant_override("separation", LOG_LINE_SEPARATION)
	log_lines_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL # Faz as linhas ocuparem a largura total interna
	_scroll_container.add_child(log_lines_vbox)

	for _i in MAX_VISIBLE:
		var lbl := Label.new()
		lbl.add_theme_font_size_override("font_size", FONT_ENTRY)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.visible       = false
		log_lines_vbox.add_child(lbl)
		_entry_lbls.append(lbl)

# ======================================================
# PUBLIC API
# ======================================================
func setup(state: BattleState) -> void:
	_state = state

func refresh() -> void:
	if _state == null:
		return
	var entries: Array = _state.combat_log
	for i in _entry_lbls.size():
		var lbl: Label = _entry_lbls[i]
		if i < entries.size():
			var entry: Dictionary = entries[i]
			lbl.text = entry.get("text", "")
			lbl.add_theme_color_override("font_color",
				TYPE_COLORS.get(entry.get("type", "system"), TYPE_COLORS["system"]))
			lbl.visible = true
		else:
			lbl.visible = false
	
