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
const STAT_ICON_SIZE := 16
# ──────────────────────────────────────────────────────

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

class StatIcon extends Control:
	enum Kind { AC, INITIATIVE, SPEED, PROFICIENCY, STRENGTH, DEXTERITY, INTELLIGENCE, WISDOM, CONSTITUTION }
	var kind: int = Kind.AC
	var custom_texture: Texture2D = null
	static var icon_cache: Dictionary = {}

	static func get_icon_texture(icon_name: String) -> Texture2D:
		if icon_cache.has(icon_name):
			return icon_cache[icon_name]
		var path := "res://assets/ui/icons/stats/%s.png" % icon_name
		if ResourceLoader.exists(path):
			var tex := load(path)
			icon_cache[icon_name] = tex
			return tex
		return null

	const ICON_COLOR := Color(0.75, 0.70, 0.55)

	func _draw() -> void:
		var c := size / 2.0
		var h := size.y * 0.46
		var w := size.x * 0.46
		if custom_texture:
			draw_texture_rect(custom_texture, Rect2(Vector2(2, 2), size - Vector2(4, 4)), false, Color.WHITE)
			return
		match kind:
			Kind.AC:
				var pts := PackedVector2Array([
					c+Vector2(0,-h), c+Vector2(w,-h*0.3), c+Vector2(w*0.6,h),
					c+Vector2(-w*0.6,h), c+Vector2(-w,-h*0.3),
				])
				draw_polyline(PackedVector2Array([pts[0],pts[1],pts[2],pts[3],pts[4],pts[0]]), ICON_COLOR, 1.5)
			Kind.INITIATIVE:
				draw_polyline(PackedVector2Array([
					c+Vector2(w*0.3,-h), c+Vector2(-w*0.1,0),
					c+Vector2(w*0.3,0),  c+Vector2(-w*0.3,h),
				]), ICON_COLOR, 1.5)
			Kind.SPEED:
				draw_polyline(PackedVector2Array([c+Vector2(-w,0), c+Vector2(w*0.5,0)]), ICON_COLOR, 1.5)
				draw_polygon(PackedVector2Array([
					c+Vector2(w,0), c+Vector2(w*0.45,-h*0.55), c+Vector2(w*0.45,h*0.55),
				]), PackedColorArray([ICON_COLOR]))
			Kind.PROFICIENCY:
				for i in range(4):
					var angle := i * PI / 2.0 - PI / 4.0
					draw_line(c, c + Vector2(cos(angle), sin(angle)) * h, ICON_COLOR, 1.5)

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
# VARS
# ======================================================
var _state: BattleState
var _portrait: Portrait
var _name_lbl: Label
var _class_lbl: Label
var _hp_row: HBoxContainer
var _mp_row: HBoxContainer
var _hp_bar: TextureProgressBar
var _mp_bar: TextureProgressBar
var _hp_val_lbl: Label
var _mp_val_lbl: Label
var _stat_lbls: Array  = []
var _stat_icons: Array = []
var _action_lbl: Label
var _status_icons_container: HBoxContainer
var _status_icons: Array = []
var _status_row: HBoxContainer
var _stat_name_lbls: Array = []

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
	_build_stats_grid(outer_vbox)
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
	_mp_row = _build_bar_row(false, info_vbox)

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
	print("bar size =", bar.size)
	print("bar min =", bar.get_minimum_size())
	print("bar combined =", bar.get_combined_minimum_size())
	print("texture width =", HP_BAR_BG.get_width())
	hbox.add_child(bar)

	if is_hp: _hp_bar = bar
	else:     _mp_bar = bar

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
	else:     _mp_val_lbl = val_lbl

	return hbox

# ======================================================
# BUILD — STATS GRID
# ======================================================
func _build_stats_grid(parent: Control) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 4)
	parent.add_child(grid)

	for sk: Dictionary in [
		{"icon": "ac",           "label": "AC",   "kind": StatIcon.Kind.AC},
		{"icon": "initiative",   "label": "Init", "kind": StatIcon.Kind.INITIATIVE},
		{"icon": "speed",        "label": "SPD",  "kind": StatIcon.Kind.SPEED},
		{"icon": "proficiency",  "label": "Prof", "kind": StatIcon.Kind.PROFICIENCY},
		{"icon": "strength",     "label": "For",  "kind": StatIcon.Kind.STRENGTH},
		{"icon": "dextery",      "label": "Des",  "kind": StatIcon.Kind.DEXTERITY},
		{"icon": "intelligence", "label": "Int",  "kind": StatIcon.Kind.INTELLIGENCE},
		{"icon": "wisdom",       "label": "Sab",  "kind": StatIcon.Kind.WISDOM},
		{"icon": "constitution", "label": "Con",  "kind": StatIcon.Kind.CONSTITUTION},
	]:
		var item := HBoxContainer.new()
		item.add_theme_constant_override("separation", 3)

		var icon := StatIcon.new()
		icon.kind                = sk["kind"]
		icon.custom_minimum_size = Vector2(STAT_ICON_SIZE, STAT_ICON_SIZE)
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tex := StatIcon.get_icon_texture(sk["icon"])
		if tex: icon.custom_texture = tex
		item.add_child(icon)
		_stat_icons.append(icon)

		var name_lbl := Label.new()
		name_lbl.text = sk["label"] + ":"
		name_lbl.add_theme_font_size_override("font_size", FONT_STAT)
		name_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.65))
		name_lbl.custom_minimum_size.x = 25
		name_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_LEFT
		item.add_child(name_lbl)
		_stat_name_lbls.append(name_lbl)

		var val_lbl := Label.new()
		val_lbl.add_theme_font_size_override("font_size", FONT_STAT)
		val_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.70))
		val_lbl.custom_minimum_size.x = 10
		val_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
		item.add_child(val_lbl)
		_stat_lbls.append(val_lbl)

		grid.add_child(item)

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

	var mp_ratio := float(player["mp"]) / float(player["max_mp"]) if player["max_mp"] > 0 else 0.0
	_mp_bar.value    = mp_ratio
	_mp_val_lbl.text = "%d / %d" % [player["mp"], player["max_mp"]]

	_hp_row.visible     = true
	_mp_row.visible     = true
	_action_lbl.visible = false

	var stat_values := [
		player["ac"], player["initiative"], player["speed"], player["proficiency"],
		player["strength"], player["dexterity"], player["intelligence"],
		player["wisdom"], player["constitution"],
	]
	for i in range(_stat_lbls.size()):
		if i < stat_values.size():
			_stat_name_lbls[i].visible = true
			_stat_lbls[i].text     = str(stat_values[i])
			_stat_lbls[i].visible  = true
			_stat_icons[i].visible = true
		else:
			_stat_lbls[i].text     = ""
			_stat_lbls[i].visible  = false
			_stat_icons[i].visible = false

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
	_mp_row.visible  = false

	_action_lbl.text    = ""
	_action_lbl.visible = false

	# Stats do EnemyData: AC, Speed, Attack Bonus
	# Mapeamento: índice 0=AC, 2=SPD, 3=Prof (usaremos para Attack Bonus)
	var enemy_stats := [
		enemy.get("ac", 10),           # índice 0 - AC
		0,                              # índice 1 - Initiative (não tem)
		enemy.get("speed", 5),         # índice 2 - SPD
		enemy.get("attack_bonus", 2),  # índice 3 - Prof (placeholder para Atk)
	]
	
	for i in range(_stat_lbls.size()):
		if i < enemy_stats.size() and enemy_stats[i] != 0:
			_stat_lbls[i].text     = str(enemy_stats[i])
			_stat_lbls[i].visible  = true
			_stat_icons[i].visible = true
		else:
			_stat_name_lbls[i].visible = false 
			_stat_lbls[i].text     = ""
			_stat_lbls[i].visible  = false
			_stat_icons[i].visible = false

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
	var badge_map := [
		["defending", "Defender +2 AC", Color(0.3, 0.6, 1.0)],
		["stun",      "Atordoado",       Color(1.0, 0.9, 0.2)],
		["stunned",   "Atordoado",       Color(1.0, 0.9, 0.2)],
		["raging",    "Furia +3 dano",   Color(1.0, 0.3, 0.2)],
		["aiming",    "Mirando +2 alc",  Color(0.6, 1.0, 0.6)],
		["furtivo",   "Furtivo",         Color(0.7, 0.4, 1.0)],
		["fury",      "Fúria",           Color(1.0, 0.2, 0.0)],
		["smite",     "Smite",           Color(1.0, 0.9, 0.2)],
	]
	var seen_stun := false
	for entry: Array in badge_map:
		var key: String  = entry[0]
		var text: String = entry[1]
		var color: Color = entry[2]
		if key == "stunned" and seen_stun:
			continue
		if key == "stun" and status.get("stun", 0) > 0:
			seen_stun = true
		if status.get(key, 0) > 0:
			var lbl := Label.new()
			lbl.text = text
			lbl.add_theme_font_size_override("font_size", FONT_STATUS)
			lbl.add_theme_color_override("font_color", color)
			_status_row.add_child(lbl)

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
