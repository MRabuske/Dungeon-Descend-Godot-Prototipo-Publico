class_name EnemyInfoPanel
extends PanelContainer

# Fixed BG3-style info shown near the top of the screen (just below the
# TurnOrderBar) while in ATTACK_MODE: portrait + name + a graphical HP bar with
# "current / max" overlaid. Driven by BattleScene from
# BattleArea.attack_hover_changed.

const PORTRAIT_SIZE := 32.0
# Sits below the TurnOrderBar (~75px tall) with a comfortable gap, BG3-style.
const TOP_MARGIN    := 120.0
# Graphical HP bar — intermediate size (smaller than the original 200x14).
const HP_BAR_WIDTH  := 160.0
const HP_BAR_HEIGHT := 11.0

var _portrait_rect: TextureRect
var _portrait_fallback: Label
var _name_lbl: Label
var _hp_fill: ColorRect
var _hp_text: Label

func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 150
	# Slightly opaque (semi-transparent) dark background.
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.10, 0.55)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.0, 0.0, 0.0, 0.35)
	style.content_margin_left   = 8.0
	style.content_margin_right  = 8.0
	style.content_margin_top    = 6.0
	style.content_margin_bottom = 6.0
	add_theme_stylebox_override("panel", style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	add_child(row)

	# Portrait (with a 2-letter fallback when no texture is available).
	var portrait_holder := Control.new()
	portrait_holder.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait_holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(portrait_holder)

	_portrait_rect = TextureRect.new()
	_portrait_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	_portrait_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait_holder.add_child(_portrait_rect)

	_portrait_fallback = Label.new()
	_portrait_fallback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_fallback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_portrait_fallback.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_portrait_fallback.add_theme_font_size_override("font_size", 13)
	_portrait_fallback.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_portrait_fallback.add_theme_constant_override("outline_size", 3)
	_portrait_fallback.visible = false
	portrait_holder.add_child(_portrait_fallback)

	# Right column: name + graphical HP bar with the "cur / max" text overlaid.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 15)
	_name_lbl.add_theme_color_override("font_color", Color.WHITE)
	_name_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_name_lbl.add_theme_constant_override("outline_size", 3)
	col.add_child(_name_lbl)

	# HP bar — background + fill + centered text overlay.
	var bar_holder := Control.new()
	bar_holder.custom_minimum_size = Vector2(HP_BAR_WIDTH, HP_BAR_HEIGHT)
	col.add_child(bar_holder)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.5)
	hp_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar_holder.add_child(hp_bg)

	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.3, 0.95, 0.3)
	_hp_fill.anchor_left = 0.0
	_hp_fill.anchor_top = 0.0
	_hp_fill.anchor_right = 1.0
	_hp_fill.anchor_bottom = 1.0
	bar_holder.add_child(_hp_fill)

	_hp_text = Label.new()
	_hp_text.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hp_text.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	_hp_text.add_theme_font_size_override("font_size", 10)
	_hp_text.add_theme_color_override("font_color", Color.WHITE)
	_hp_text.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hp_text.add_theme_constant_override("outline_size", 3)
	bar_holder.add_child(_hp_text)

# Shows the panel for a combatant (TURN_QUEUE dict) with the given live HP.
func show_for(combatant: Dictionary, hp_cur: int, hp_max: int) -> void:
	_name_lbl.text = str(combatant.get("name", "?"))

	var portrait := _get_portrait(combatant)
	if portrait != null:
		_portrait_rect.texture = portrait
		_portrait_rect.visible = true
		_portrait_fallback.visible = false
	else:
		_portrait_rect.visible = false
		_portrait_fallback.text = str(combatant.get("name", "??")).substr(0, 2).to_upper()
		_portrait_fallback.visible = true

	var ratio := clampf(float(hp_cur) / maxf(float(hp_max), 1.0), 0.0, 1.0)
	_hp_fill.anchor_right = ratio
	_hp_fill.color = _hp_color(ratio)
	_hp_text.text = "%d / %d" % [hp_cur, hp_max]

	visible = true
	_reposition()

func hide_panel() -> void:
	visible = false

func _reposition() -> void:
	reset_size()
	var vp := get_viewport_rect().size
	position = Vector2((vp.x - size.x) * 0.5, TOP_MARGIN)

func _hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.3, 0.95, 0.3)
	elif ratio >= 0.2:
		return Color(0.95, 0.7, 0.2)
	return Color(0.95, 0.35, 0.35)

# Same portrait resolution used by TurnOrderBar._get_combatant_portrait().
func _get_portrait(combatant: Dictionary) -> Texture2D:
	if combatant.get("is_player", false):
		for player: Dictionary in BattleState.PLAYERS:
			if player.get("name") == combatant.get("name", ""):
				var portrait = player.get("portrait")
				if portrait and portrait is Texture2D:
					return portrait
	else:
		var enemy_type: String = combatant.get("type", "")
		if BattleState.ALL_ENEMIES.has(enemy_type):
			var enemy_data = BattleState.ALL_ENEMIES[enemy_type]
			if enemy_data.has_method("to_combat_dict"):
				var portrait = enemy_data.to_combat_dict().get("portrait")
				if portrait and portrait is Texture2D:
					return portrait
			elif enemy_data.has("portrait"):
				return enemy_data.portrait
	return null
