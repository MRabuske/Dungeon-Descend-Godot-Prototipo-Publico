class_name StatusPanel
extends Control

# ======================================================
# 🎨 ASSETS
# ======================================================
const PANEL_TEXTURE := preload("res://assets/ui/panels/panel_small.png")
const HP_BAR_BG     := preload("res://assets/ui/bars/bar_bg.png")
const HP_BAR_FILL   := preload("res://assets/ui/bars/hp_fill.png")
const MP_BAR_BG     := preload("res://assets/ui/bars/bar_bg.png")
const MP_BAR_FILL   := preload("res://assets/ui/bars/mp_fill.png")

# ──────────────────────────────────────────────────────
# 🔧 CONSTANTES DE AJUSTE FINO
# ──────────────────────────────────────────────────────
const MARGIN_PANEL_LEFT   := 22
const MARGIN_PANEL_RIGHT  := 20
const MARGIN_PANEL_TOP    := 20
const MARGIN_PANEL_BOTTOM := 16
const CONTENT_SEPARATION  := 6
# ──────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE DE TAMANHOS
# ──────────────────────────────────────────────────────
const PANEL_PATCH    := 16
const PORTRAIT_SIZE  := 68
const ICON_SIZE      := 12
const BAR_HEIGHT     := 12
const FONT_NAME      := 12
const FONT_CLASS     := 10
const FONT_STAT      := 8
const FONT_STATUS    := 8
const CLASS_BADGE_SIZE := 20
# ──────────────────────────────────────────────────────

# Nome do heroi (em PLAYERS) → sufixo do arquivo de icone em
# assets/ui/icons/party_select/icon_<sufixo>.png
const CLASS_ICON_NAMES := {
	"Guerreiro": "guerreiro", "Mago": "mago", "Arqueiro": "arqueiro",
	"Clérigo": "clerigo", "Ladrao": "ladrao", "Bárbaro": "barbaro",
	"Monge": "monge", "Paladino": "paladino",
}

const HP_COLOR    := Color(0.80, 0.15, 0.18)
const HP_CRITICAL := Color(0.90, 0.20, 0.20)
const MP_COLOR    := Color(0.20, 0.40, 0.88)

const PLAYER_COLORS := [
	Color(0.30, 0.55, 1.00),
	Color(0.30, 0.85, 0.50),
	Color(0.95, 0.75, 0.20),
	Color(0.85, 0.40, 0.90),
]

# ======================================================
# INNER CLASSES
# ======================================================
class Portrait extends Control:
	var player_color: Color         = Color.WHITE
	var is_enemy: bool              = false
	var portrait_texture: Texture2D = null

	const BORDER_COLOR := Color(1.0, 0.85, 0.0)
	const ENEMY_BG     := Color(0.22, 0.05, 0.05)
	const ENEMY_MARK   := Color(0.80, 0.20, 0.20)

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		if portrait_texture:
			draw_texture_rect(portrait_texture, Rect2(Vector2(2, 2), size - Vector2(4, 4)), false, Color.WHITE)
		else:
			draw_rect(r, ENEMY_BG if is_enemy else player_color)
		#draw_rect(r, BORDER_COLOR, false, 2.0)
		if is_enemy and not portrait_texture:
			_draw_skull()

	func _draw_skull() -> void:
		var c    := size / 2.0
		var sk_r := minf(size.x, size.y) * 0.30
		draw_arc(c + Vector2(0.0, -sk_r * 0.15), sk_r, 0.0, TAU, 48, ENEMY_MARK, 2.0)
		var eye_r := sk_r * 0.22
		draw_circle(c + Vector2(-sk_r * 0.35, -sk_r * 0.10), eye_r, ENEMY_BG)
		draw_circle(c + Vector2( sk_r * 0.35, -sk_r * 0.10), eye_r, ENEMY_BG)
		var jaw_y := c.y + sk_r * 0.20
		for t in range(3):
			draw_rect(Rect2(c.x - sk_r * 0.28 + t * sk_r * 0.28, jaw_y, sk_r * 0.16, sk_r * 0.28), ENEMY_MARK)

	func set_portrait(texture: Texture2D) -> void:
		portrait_texture = texture
		queue_redraw()

class BarIcon extends Control:
	var is_heart: bool = true
	const HEART_COLOR   := Color(0.90, 0.20, 0.25)
	const DIAMOND_COLOR := Color(0.25, 0.50, 0.95)

	func _draw() -> void:
		var c := size / 2.0
		if is_heart:
			var r := size.x * 0.22
			draw_circle(c + Vector2(-r, -r * 0.4), r, HEART_COLOR)
			draw_circle(c + Vector2( r, -r * 0.4), r, HEART_COLOR)
			draw_polygon(PackedVector2Array([
				c + Vector2(-size.x * 0.44, -size.y * 0.05),
				c + Vector2( size.x * 0.44, -size.y * 0.05),
				c + Vector2(0.0,             size.y * 0.44),
			]), PackedColorArray([HEART_COLOR]))
		else:
			draw_polygon(PackedVector2Array([
				c + Vector2(0.0,           -size.y * 0.46),
				c + Vector2( size.x * 0.46, 0.0),
				c + Vector2(0.0,            size.y * 0.46),
				c + Vector2(-size.x * 0.46, 0.0),
			]), PackedColorArray([DIAMOND_COLOR]))

class StatusEffectIcon extends Control:
	enum EffectType { POISON, STUN, BURN, FREEZE, BLESS }
	var effect_type: int = EffectType.POISON
	var custom_texture: Texture2D = null
	var duration: int = 0

	const POISON_COLOR := Color(0.30, 0.85, 0.35)
	const STUN_COLOR   := Color(0.95, 0.80, 0.15)
	const BURN_COLOR   := Color(0.95, 0.40, 0.15)
	const FREEZE_COLOR := Color(0.30, 0.70, 0.95)
	const BLESS_COLOR  := Color(0.85, 0.90, 0.40)

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.35
		if custom_texture:
			draw_texture_rect(custom_texture, Rect2(Vector2(2,2), size-Vector2(4,4)), false, Color.WHITE)
			return
		match effect_type:
			EffectType.POISON:
				draw_circle(c, r, POISON_COLOR)
				draw_circle(c, r * 0.5, Color(0.1, 0.1, 0.1, 0.8))
			EffectType.STUN:
				for i in range(5):
					var angle := i * PI * 2.0 / 5.0 - PI / 2.0
					var p1 := c + Vector2(cos(angle), sin(angle)) * r
					var p2 := c + Vector2(cos(angle+0.4), sin(angle+0.4)) * r * 0.4
					var p3 := c + Vector2(cos(angle+0.8), sin(angle+0.8)) * r
					draw_polygon(PackedVector2Array([p1,p2,p3]), PackedColorArray([STUN_COLOR]))
			EffectType.BURN:
				draw_polygon(PackedVector2Array([
					c+Vector2(0,-r), c+Vector2(r*0.5,r*0.3), c+Vector2(r*0.2,r*0.1),
					c+Vector2(0,r*0.6), c+Vector2(-r*0.2,r*0.1), c+Vector2(-r*0.5,r*0.3),
				]), PackedColorArray([BURN_COLOR]))
			EffectType.FREEZE:
				draw_polygon(PackedVector2Array([
					c+Vector2(0,-r), c+Vector2(r*0.5,-r*0.3), c+Vector2(r*0.2,0),
					c+Vector2(r,r*0.5), c+Vector2(0,r*0.3), c+Vector2(-r,r*0.5),
					c+Vector2(-r*0.2,0), c+Vector2(-r*0.5,-r*0.3),
				]), PackedColorArray([FREEZE_COLOR]))
			EffectType.BLESS:
				var cs := r * 0.6
				draw_rect(Rect2(c.x-cs*0.2, c.y-cs, cs*0.4, cs*2), BLESS_COLOR)
				draw_rect(Rect2(c.x-cs, c.y-cs*0.2, cs*2, cs*0.4), BLESS_COLOR)

	func set_effect(effect: int, dur: int = 0) -> void:
		effect_type = effect
		duration    = dur
		queue_redraw()

	func set_texture(texture: Texture2D) -> void:
		custom_texture = texture
		queue_redraw()

# ======================================================
# SIGNALS
# ======================================================
signal concentration_cancel_requested(queue_idx: int)

# ======================================================
# VARS
# ======================================================
var _state: BattleState
var _portrait: Portrait
var _name_lbl: Label
var _class_lbl: Label
var _hp_row: HBoxContainer
var _hp_bar: TextureProgressBar
var _hp_val_lbl: Label
var _slot_container: VBoxContainer
var _action_lbl: Label
var _status_icons_container: HBoxContainer
var _status_icons: Array = []
var _status_row: HBoxContainer
var _class_badge: TextureRect
var _class_badge_bg: Panel

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

	var outer_vbox := VBoxContainer.new()
	outer_vbox.add_theme_constant_override("separation", CONTENT_SEPARATION)
	margin.add_child(outer_vbox)

	_build_top_row(outer_vbox)
	_build_status_row(outer_vbox)

# ======================================================
# BUILD — TOP ROW
# ======================================================
func _build_top_row(parent: Control) -> void:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 5)
	parent.add_child(hbox)

	_portrait = Portrait.new()
	_portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(_portrait)
	_build_class_badge()

	var info_vbox := VBoxContainer.new()
	info_vbox.add_theme_constant_override("separation", 3)
	info_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(info_vbox)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", FONT_NAME)
	info_vbox.add_child(_name_lbl)

	_class_lbl = Label.new()
	_class_lbl.add_theme_font_size_override("font_size", FONT_CLASS)
	_class_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	info_vbox.add_child(_class_lbl)

	_hp_row = _build_bar_row(true,  info_vbox)

	# Display de spell slots / Ki (substitui a antiga barra de MP)
	_slot_container = VBoxContainer.new()
	_slot_container.add_theme_constant_override("separation", 1)
	info_vbox.add_child(_slot_container)

	_action_lbl = Label.new()
	_action_lbl.add_theme_font_size_override("font_size", FONT_STAT)
	_action_lbl.add_theme_color_override("font_color", Color(0.80, 0.70, 0.50))
	_action_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_action_lbl.visible       = false
	info_vbox.add_child(_action_lbl)

	var status_header := HBoxContainer.new()
	status_header.add_theme_constant_override("separation", 8)
	info_vbox.add_child(status_header)

	var status_label := Label.new()
	status_label.text = "Efeitos:"
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	status_header.add_child(status_label)

	_status_icons_container = HBoxContainer.new()
	_status_icons_container.add_theme_constant_override("separation", 4)
	status_header.add_child(_status_icons_container)

# ======================================================
# BUILD — BAR ROW
# FIX: custom_minimum_size explícito no BarIcon para evitar colapso
# ======================================================
func _build_bar_row(is_hp: bool, parent: Control) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)
	parent.add_child(hbox)

	var icon := BarIcon.new()
	icon.is_heart            = is_hp
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(icon)

	var bar := TextureProgressBar.new()
	bar.nine_patch_stretch = true
	bar.texture_under         = HP_BAR_BG   if is_hp else MP_BAR_BG
	bar.texture_progress      = HP_BAR_FILL if is_hp else MP_BAR_FILL
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical   = Control.SIZE_SHRINK_CENTER
	bar.custom_minimum_size.y = BAR_HEIGHT
	bar.min_value             = 0.0
	bar.max_value             = 1.0
	bar.value                 = 1.0
	bar.step                  = 0.001
	hbox.add_child(bar)

	if is_hp: _hp_bar = bar

	var val_lbl := Label.new()
	val_lbl.add_theme_font_size_override("font_size", 7)
	val_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	val_lbl.grow_horizontal       = Control.GROW_DIRECTION_BOTH
	val_lbl.grow_vertical         = Control.GROW_DIRECTION_BOTH
	val_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_CENTER
	val_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	val_lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	val_lbl.add_theme_constant_override("shadow_offset_x", 1)
	val_lbl.add_theme_constant_override("shadow_offset_y", 1)
	bar.add_child(val_lbl)

	if is_hp: _hp_val_lbl = val_lbl

	return hbox

# ======================================================
# BUILD — SPELL SLOTS / KI DISPLAY
# Mostra uma linha por nível de slot que o herói possui (●=disponível, ○=gasto)
# mais uma linha de Ki para o Monge. Non-casters sem Ki não exibem nada.
# ======================================================
func _refresh_slot_display(player: Dictionary) -> void:
	for child in _slot_container.get_children():
		child.queue_free()
	var slots: Array     = player.get("spell_slots", [])
	var slots_max: Array = player.get("spell_slots_max", [])
	var ki: int     = player.get("ki", 0)
	var ki_max: int = player.get("ki_max", 0)
	var has_any := false
	for i in range(slots_max.size()):
		if i >= slots.size() or slots_max[i] <= 0:
			continue
		has_any = true
		var lbl := Label.new()
		lbl.text = "Nv.%d  %s%s" % [
			i + 1,
			"●".repeat(slots[i]),
			"○".repeat(slots_max[i] - slots[i]),
		]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", MP_COLOR)
		_slot_container.add_child(lbl)
	if ki_max > 0:
		has_any = true
		var ki_lbl := Label.new()
		ki_lbl.text = "Ki  %s%s" % ["●".repeat(ki), "○".repeat(ki_max - ki)]
		ki_lbl.add_theme_font_size_override("font_size", 11)
		ki_lbl.add_theme_color_override("font_color", Color(0.95, 0.80, 0.30))
		_slot_container.add_child(ki_lbl)
	_slot_container.visible = has_any

# ======================================================
# BUILD — CLASS BADGE
# Icone de classe sobreposto no canto inferior direito do retrato.
# ======================================================
func _build_class_badge() -> void:
	_class_badge_bg = Panel.new()
	_class_badge_bg.custom_minimum_size = Vector2(CLASS_BADGE_SIZE, CLASS_BADGE_SIZE)
	_class_badge_bg.size = Vector2(CLASS_BADGE_SIZE, CLASS_BADGE_SIZE)
	# Ancora no canto inferior direito do retrato.
	_class_badge_bg.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_class_badge_bg.position = Vector2(PORTRAIT_SIZE - CLASS_BADGE_SIZE, PORTRAIT_SIZE - CLASS_BADGE_SIZE)
	_class_badge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.6)
	sb.set_corner_radius_all(CLASS_BADGE_SIZE / 2)
	_class_badge_bg.add_theme_stylebox_override("panel", sb)
	_portrait.add_child(_class_badge_bg)

	_class_badge = TextureRect.new()
	_class_badge.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_class_badge.expand_mode      = TextureRect.EXPAND_IGNORE_SIZE
	_class_badge.stretch_mode     = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_class_badge.mouse_filter     = Control.MOUSE_FILTER_IGNORE
	_class_badge_bg.add_child(_class_badge)

func _get_class_icon(player_name: String) -> Texture2D:
	var suffix: String = CLASS_ICON_NAMES.get(player_name, player_name.to_lower())
	var path := "res://assets/ui/icons/party_select/icon_%s.png" % suffix
	return load(path) if ResourceLoader.exists(path) else null

# ======================================================
# BUILD — STATUS ROW
# ======================================================
func _build_status_row(parent: Control) -> void:
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 6)
	parent.add_child(_status_row)

# ======================================================
# PUBLIC API
# ======================================================
func setup(state: BattleState) -> void:
	_state = state

func refresh(active_index: int) -> void:
	var queue_idx: int        = active_index % BattleState.TURN_QUEUE.size()
	var combatant: Dictionary = BattleState.TURN_QUEUE[queue_idx]
	if combatant["is_player"]:
		_show_player(_find_player_index(combatant["name"]))
	else:
		_show_enemy(combatant, active_index)
	_refresh_status_badges(queue_idx)

	# Retrato escurece quando o herói está Downed (estilo BG3).
	if _state != null and _state.is_downed(queue_idx):
		_portrait.modulate = Color(0.4, 0.4, 0.4, 1.0)
	else:
		_portrait.modulate = Color.WHITE

# ======================================================
# SHOW PLAYER / ENEMY
# ======================================================
func _show_player(idx: int) -> void:
	var player: Dictionary = BattleState.PLAYERS[idx]
	_portrait.set_portrait(_get_portrait_from_player(player))
	_portrait.player_color = PLAYER_COLORS[idx]
	_portrait.is_enemy     = false

	_name_lbl.text  = player["name"]
	_class_lbl.text = "Lv. %d · %s" % [player["level"], player["class"]]

	var hp_ratio := float(player["hp"]) / float(player["max_hp"]) if player["max_hp"] > 0 else 0.0
	_hp_bar.value    = hp_ratio
	_hp_bar.modulate = HP_CRITICAL if hp_ratio < 0.25 else Color.WHITE
	_hp_val_lbl.text = "%d / %d" % [player["hp"], player["max_hp"]]

	_refresh_slot_display(player)

	_hp_row.visible     = true
	_action_lbl.visible = false

	# Badge de classe no retrato
	var class_icon := _get_class_icon(player["name"])
	_class_badge.texture     = class_icon
	_class_badge_bg.visible  = class_icon != null

	var combatant_idx := _find_combatant_index_by_name(player["name"])
	if combatant_idx >= 0:
		_update_status_icons(combatant_idx)
	else:
		_status_icons_container.visible = false

func _show_enemy(enemy: Dictionary, idx: int) -> void:
	_portrait.set_portrait(_get_portrait_from_enemy(enemy))
	_portrait.is_enemy = true

	_name_lbl.text  = enemy["name"]
	_class_lbl.text = "Enemy · %s" % enemy["type"]

	var hp: int     = _state.enemy_hp.get(enemy["name"], 0)
	var max_hp: int = _state.get_enemy_max_hp(idx)
	var hp_ratio    := float(hp) / float(max_hp) if max_hp > 0 else 0.0
	_hp_bar.value    = hp_ratio
	_hp_val_lbl.text = "%d / %d" % [hp, max_hp]
	_hp_row.visible  = true
	if _slot_container != null:
		_slot_container.visible = false

	_action_lbl.text    = ""
	_action_lbl.visible = false

	# Inimigos nao tem badge de classe.
	_class_badge_bg.visible = false

	_update_status_icons(idx)

# ======================================================
# STATUS BADGES
# ======================================================
func _refresh_status_badges(queue_idx: int) -> void:
	for child in _status_row.get_children():
		child.queue_free()
	if _state == null or queue_idx < 0 or queue_idx >= _state.combatant_statuses.size():
		return

	var status: Dictionary = _state.combatant_statuses[queue_idx]
	# Badges montados a partir da fonte única StatusDefinitions (sem mapa duplicado).
	for key: String in StatusDefinitions.ORDER:
		if status.get(key, 0) > 0:
			var text: String = StatusDefinitions.name_of(key)
			if StatusDefinitions.shows_duration(key):
				text += " (%d)" % int(status[key])
			var lbl := Label.new()
			lbl.text = text
			lbl.add_theme_font_size_override("font_size", FONT_STATUS)
			lbl.add_theme_color_override("font_color", StatusDefinitions.color_of(key))
			_status_row.add_child(lbl)

	# Indicador de Concentração estilo BG3: nome do spell + botão × para cancelar.
	if _state.is_concentrating(queue_idx):
		var action: ActionData = _state.get_concentration_action(queue_idx)
		var spell_full: String = action.label if action else "Concentrando"
		var spell_short: String = spell_full.left(6)

		var conc_panel := PanelContainer.new()
		var conc_style := StyleBoxFlat.new()
		conc_style.bg_color = Color(0.05, 0.05, 0.15, 0.85)
		conc_style.border_color = Color(0.3, 0.7, 1.0)
		conc_style.set_border_width_all(2)
		conc_style.set_corner_radius_all(6)
		conc_style.content_margin_left = 5
		conc_style.content_margin_right = 3
		conc_style.content_margin_top = 1
		conc_style.content_margin_bottom = 1
		conc_panel.add_theme_stylebox_override("panel", conc_style)
		conc_panel.tooltip_text = "%s\nClique em × para cancelar concentração" % spell_full

		var conc_hbox := HBoxContainer.new()
		conc_hbox.add_theme_constant_override("separation", 3)
		conc_panel.add_child(conc_hbox)

		var conc_name := Label.new()
		conc_name.text = "◆ " + spell_short
		conc_name.add_theme_font_size_override("font_size", FONT_STATUS)
		conc_name.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		conc_hbox.add_child(conc_name)

		var conc_cancel := Button.new()
		conc_cancel.text = "×"
		conc_cancel.flat = true
		conc_cancel.focus_mode = Control.FOCUS_NONE
		conc_cancel.add_theme_font_size_override("font_size", FONT_STATUS)
		conc_cancel.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
		conc_cancel.add_theme_color_override("font_hover_color", Color(1.0, 0.7, 0.7))
		conc_cancel.custom_minimum_size = Vector2(16, 16)
		conc_cancel.tooltip_text = "Cancelar concentração"
		conc_cancel.pressed.connect(func() -> void: concentration_cancel_requested.emit(queue_idx))
		conc_hbox.add_child(conc_cancel)

		_status_row.add_child(conc_panel)

	# Indicador de Downed estilo BG3: rótulo CAÍDO + 3 círculos de sucesso / 3 de falha.
	if _state.is_downed(queue_idx):
		var s_cnt: int = status.get("death_saves_success", 0)
		var f_cnt: int = status.get("death_saves_failure", 0)

		var down_vbox := VBoxContainer.new()
		down_vbox.add_theme_constant_override("separation", 1)

		var down_lbl := Label.new()
		down_lbl.text = "CAÍDO"
		down_lbl.add_theme_font_size_override("font_size", FONT_STATUS)
		down_lbl.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0))
		down_vbox.add_child(down_lbl)

		var succ_row := HBoxContainer.new()
		succ_row.add_theme_constant_override("separation", 3)
		for j in 3:
			var dot := Label.new()
			dot.text = "●" if j < s_cnt else "○"
			dot.add_theme_font_size_override("font_size", FONT_STATUS + 2)
			dot.add_theme_color_override("font_color",
				Color(0.2, 0.9, 0.2) if j < s_cnt else Color(0.35, 0.35, 0.35))
			succ_row.add_child(dot)
		down_vbox.add_child(succ_row)

		var fail_row := HBoxContainer.new()
		fail_row.add_theme_constant_override("separation", 3)
		for j in 3:
			var dot := Label.new()
			dot.text = "●" if j < f_cnt else "○"
			dot.add_theme_font_size_override("font_size", FONT_STATUS + 2)
			dot.add_theme_color_override("font_color",
				Color(0.9, 0.15, 0.15) if j < f_cnt else Color(0.35, 0.35, 0.35))
			fail_row.add_child(dot)
		down_vbox.add_child(fail_row)

		_status_row.add_child(down_vbox)

# ======================================================
# STATUS EFFECT ICONS
# ======================================================
func _update_status_icons(combatant_idx: int) -> void:
	for child in _status_icons_container.get_children():
		child.queue_free()
	_status_icons.clear()

	if _state == null or combatant_idx < 0 or combatant_idx >= _state.combatant_statuses.size():
		return

	var statuses: Dictionary = _state.combatant_statuses[combatant_idx]
	var effects: Array = []
	if statuses.get("poison", 0) > 0:
		effects.append({"type": StatusEffectIcon.EffectType.POISON, "duration": statuses["poison"]})
	if statuses.get("stun", 0) > 0:
		effects.append({"type": StatusEffectIcon.EffectType.STUN, "duration": statuses["stun"]})

	for effect: Dictionary in effects:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 2)

		var icon := StatusEffectIcon.new()
		icon.custom_minimum_size = Vector2(20, 20)
		icon.set_effect(effect["type"], effect["duration"])
		var tex := _get_status_icon_texture(effect["type"])
		if tex: icon.set_texture(tex)
		row.add_child(icon)

		var dur_lbl := Label.new()
		dur_lbl.text = str(effect["duration"])
		dur_lbl.add_theme_font_size_override("font_size", 9)
		dur_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.70))
		dur_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(dur_lbl)

		_status_icons_container.add_child(row)
		_status_icons.append(icon)

	_status_icons_container.visible = not effects.is_empty()

# ======================================================
# HELPERS
# ======================================================
func _find_player_index(player_name: String) -> int:
	for i in range(BattleState.PLAYERS.size()):
		if BattleState.PLAYERS[i]["name"] == player_name:
			return i
	return 0

func _find_combatant_index_by_name(character_name: String) -> int:
	for i in range(BattleState.TURN_QUEUE.size()):
		if BattleState.TURN_QUEUE[i].get("name") == character_name:
			return i
	return -1

func _get_portrait_from_player(player: Dictionary) -> Texture2D:
	var portrait = player.get("portrait")
	if portrait and portrait is Texture2D:
		return portrait
	var hero_data = BattleState.ALL_HERO_DATA.get(player["name"])
	if hero_data and hero_data.has("portrait"):
		return hero_data.portrait
	return null

func _get_portrait_from_enemy(enemy: Dictionary) -> Texture2D:
	var enemy_type: String = enemy.get("type", "")
	if BattleState.ALL_ENEMIES.has(enemy_type):
		var enemy_data = BattleState.ALL_ENEMIES[enemy_type]
		if enemy_data.has_method("to_combat_dict"):
			var portrait = enemy_data.to_combat_dict().get("portrait")
			if portrait and portrait is Texture2D:
				return portrait
		if enemy_data.has("portrait"):
			return enemy_data.portrait
	return null

func _get_status_icon_texture(effect_type: int) -> Texture2D:
	var names := {
		StatusEffectIcon.EffectType.POISON: "poison",
		StatusEffectIcon.EffectType.STUN:   "stun",
		StatusEffectIcon.EffectType.BURN:   "burn",
		StatusEffectIcon.EffectType.FREEZE: "freeze",
		StatusEffectIcon.EffectType.BLESS:  "bless",
	}
	var icon_name: String = names.get(effect_type, "")
	if icon_name.is_empty():
		return null
	var path := "res://assets/ui/icons/status/%s.png" % icon_name
	return load(path) if ResourceLoader.exists(path) else null
