class_name ExaminePanel
extends Control

# ======================================================
# 🎨 ASSETS
# ======================================================
const PANEL_TEXTURE       := preload("res://assets/ui/panels/panel_examine.png")
const PANEL_SMALL_TEXTURE := preload("res://assets/ui/panels/panel_examine_text.png")
const BTN_NORMAL          := preload("res://assets/ui/buttons/btn_normal.png")
const BTN_HOVER           := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_PRESSED         := preload("res://assets/ui/buttons/btn_pressed.png")

const ARROW_LEFT  := preload("res://assets/ui/buttons/arrow_left.png")
const ARROW_RIGHT := preload("res://assets/ui/buttons/arrow_right.png")

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE DE TAMANHOS
# ──────────────────────────────────────────────────────
const PANEL_PATCH        := 32
const PANEL_SMALL_PATCH  := 16
const PANEL_W            := 700
const PANEL_H            := 460
const LEFT_W             := 240
const PADDING            := 22
const FONT_TITLE         := 20
const FONT_SUBTITLE      := 12
const FONT_SECTION       := 12
const FONT_TEXT          := 10
const FONT_STAT          := 10
const ARROW_SIZE         := 24
const SPRITE_SCALE       := 2.5
# ──────────────────────────────────────────────────────

const OVERLAY_COLOR     := Color(0.0,    0.0,  0.0,  0.72)
const TITLE_COLOR       := Color("#ab9051")  # #F4CE74
const TEXT_COLOR        := Color(0.85,   0.82,  0.75)
const TEXT_STAT_COLOR   := Color("#ab9051")
const SECTION_HDR_COLOR := Color(0.55,   0.55,  0.62)
const PLACEHOLDER_COLOR := Color(0.30,   0.30,  0.33)

var _sprite_rect:      TextureRect
var _anim_sprite:      AnimatedSprite2D
var _sprite_frames:    SpriteFrames
var _current_dir_idx:  int = 0
var _directions:       Array[String] = ["down_right", "down_left", "up_right", "up_left"]
var _name_label:       Label
var _subtitle_label:   Label
var _combat_stats_box: VBoxContainer
var _attr_grid:        GridContainer
var _conditions_box:   VBoxContainer
var _resistances_box:  VBoxContainer
var _vulnerabilities_box: VBoxContainer
var _immunities_box:   VBoxContainer
var _features_box:     VBoxContainer

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	z_index       = 950
	_build()
	modulate.a   = 0.0
	visible      = false
	mouse_filter = Control.MOUSE_FILTER_STOP

# ── BUILD ──────────────────────────────────────────────────────────────────

func _build() -> void:
	var overlay := ColorRect.new()
	overlay.color = OVERLAY_COLOR
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Control.new()
	panel.custom_minimum_size = Vector2(PANEL_W, PANEL_H)
	center.add_child(panel)

	var panel_bg := NinePatchRect.new()
	panel_bg.texture = PANEL_TEXTURE
	panel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_bg.patch_margin_left   = PANEL_PATCH
	panel_bg.patch_margin_right  = PANEL_PATCH
	panel_bg.patch_margin_top    = PANEL_PATCH
	panel_bg.patch_margin_bottom = PANEL_PATCH
	panel_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(panel_bg)

	_build_close_button(panel)
	_build_left_column(panel)
	_build_right_column(panel)

func _build_close_button(parent: Control) -> void:
	var btn := TextureButton.new()
	btn.texture_normal  = BTN_PRESSED
	btn.texture_hover   = BTN_HOVER
	btn.custom_minimum_size = Vector2(28, 28)
	btn.ignore_texture_size = true
	btn.stretch_mode    = TextureButton.STRETCH_SCALE
	btn.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	btn.offset_left   = -38.0
	btn.offset_top    =   8.0
	btn.offset_right  =  -8.0
	btn.offset_bottom =  36.0
	parent.add_child(btn)

	var x_lbl := Label.new()
	x_lbl.text = "X"
	x_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	x_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	x_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	x_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	x_lbl.add_theme_font_size_override("font_size", 8)
	x_lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.75))
	btn.add_child(x_lbl)

	btn.pressed.connect(hide_panel)

func _build_left_column(panel: Control) -> void:
	var left := Control.new()
	left.anchor_left   = 0.0
	left.anchor_right  = 0.0
	left.anchor_top    = 0.0
	left.anchor_bottom = 1.0
	left.offset_left   = PADDING
	left.offset_right  = LEFT_W
	left.offset_top    = PADDING
	left.offset_bottom = -PADDING
	panel.add_child(left)

	_sprite_rect = TextureRect.new()
	_sprite_rect.expand_mode    = TextureRect.EXPAND_IGNORE_SIZE
	_sprite_rect.stretch_mode   = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_sprite_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_sprite_rect.visible = false
	left.add_child(_sprite_rect)

	_anim_sprite = AnimatedSprite2D.new()
	_anim_sprite.centered = true
	_anim_sprite.visible = false
	left.add_child(_anim_sprite)

	var arrow_y := (PANEL_H - PADDING * 2) * 0.5 - ARROW_SIZE * 0.5

	var btn_left := TextureButton.new()
	btn_left.texture_normal  = ARROW_LEFT
	btn_left.texture_hover   = ARROW_LEFT
	btn_left.ignore_texture_size = true
	btn_left.stretch_mode    = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_left.size            = Vector2(ARROW_SIZE, ARROW_SIZE)
	btn_left.position        = Vector2(4, arrow_y)
	btn_left.pressed.connect(func(): _rotate_sprite(-1))
	left.add_child(btn_left)

	var btn_right := TextureButton.new()
	btn_right.texture_normal  = ARROW_RIGHT
	btn_right.texture_hover   = ARROW_RIGHT
	btn_right.ignore_texture_size = true
	btn_right.stretch_mode    = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn_right.size            = Vector2(ARROW_SIZE, ARROW_SIZE)
	btn_right.position        = Vector2(LEFT_W - PADDING - ARROW_SIZE - 4, arrow_y)
	btn_right.pressed.connect(func(): _rotate_sprite(1))
	left.add_child(btn_right)

func _build_right_column(panel: Control) -> void:
	var right := Control.new()
	right.anchor_left   = 0.0
	right.anchor_right  = 1.0
	right.anchor_top    = 0.0
	right.anchor_bottom = 1.0
	right.offset_left   = LEFT_W + PADDING * 2
	right.offset_right  = -PADDING
	right.offset_top    = PADDING + 10
	right.offset_bottom = -PADDING
	panel.add_child(right)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.clip_contents = false
	right.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(vbox)

	_name_label = Label.new()
	_name_label.add_theme_font_size_override("font_size", FONT_TITLE)
	_name_label.add_theme_color_override("font_color", TITLE_COLOR)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	vbox.add_child(_name_label)

	_subtitle_label = Label.new()
	_subtitle_label.add_theme_font_size_override("font_size", FONT_SUBTITLE)
	_subtitle_label.add_theme_color_override("font_color", SECTION_HDR_COLOR)
	vbox.add_child(_subtitle_label)

	vbox.add_child(_make_separator())

	_combat_stats_box = VBoxContainer.new()
	_combat_stats_box.add_theme_constant_override("separation", 3)
	vbox.add_child(_combat_stats_box)

	vbox.add_child(_make_separator())

	_attr_grid = GridContainer.new()
	_attr_grid.columns = 3
	_attr_grid.add_theme_constant_override("h_separation", 10)
	_attr_grid.add_theme_constant_override("v_separation", 3)
	vbox.add_child(_attr_grid)

	vbox.add_child(_make_separator())

	_conditions_box = VBoxContainer.new()
	_conditions_box.add_theme_constant_override("separation", 3)
	_build_section_with_header(vbox, "Condições", _conditions_box)

	vbox.add_child(_make_separator())

	_resistances_box = VBoxContainer.new()
	_resistances_box.add_theme_constant_override("separation", 3)
	_build_section_with_header(vbox, "Resistências", _resistances_box)

	vbox.add_child(_make_separator())

	_vulnerabilities_box = VBoxContainer.new()
	_vulnerabilities_box.add_theme_constant_override("separation", 3)
	_build_section_with_header(vbox, "Vulnerabilidades", _vulnerabilities_box)

	vbox.add_child(_make_separator())

	_immunities_box = VBoxContainer.new()
	_immunities_box.add_theme_constant_override("separation", 3)
	_build_section_with_header(vbox, "Imunidades", _immunities_box)

	vbox.add_child(_make_separator())

	_features_box = VBoxContainer.new()
	_features_box.add_theme_constant_override("separation", 3)
	_build_section_with_header(vbox, "Habilidades Notáveis", _features_box)

# ── SPRITE ─────────────────────────────────────────────────────────────────

func _rotate_sprite(delta: int) -> void:
	_current_dir_idx = (_current_dir_idx + delta + _directions.size()) % _directions.size()
	_update_sprite_direction()

func _update_sprite_direction() -> void:
	var dir_name := _directions[_current_dir_idx]
	var center := Vector2((LEFT_W - PADDING) * 0.5, (PANEL_H - PADDING * 2) * 0.45)
	
	if _sprite_frames and _sprite_frames.has_animation("idle_" + dir_name):
		_sprite_rect.visible = false
		_anim_sprite.visible = true
		_anim_sprite.sprite_frames = _sprite_frames
		_anim_sprite.scale = Vector2(SPRITE_SCALE, SPRITE_SCALE)
		_anim_sprite.position = center
		_anim_sprite.play("idle_" + dir_name)
	else:
		_anim_sprite.visible = false
		_sprite_rect.visible = true

# ── PUBLIC API ─────────────────────────────────────────────────────────────

func show_for(state: BattleState, idx: int) -> void:
	if idx < 0 or idx >= BattleState.TURN_QUEUE.size():
		return

	var combatant: Dictionary = BattleState.TURN_QUEUE[idx]
	var is_player: bool = combatant.get("is_player", false)

	var name_str:       String
	var type_str:       String
	var level_val:      int
	var current_hp:     int
	var max_hp_val:     int
	var ac_val:         int
	var str_v:          int
	var dex_v:          int
	var con_v:          int
	var int_v:          int
	var wis_v:          int
	var cha_v:          int
	var resistances:    Array
	var vulnerabilities: Array
	var immunities:     Array
	var features:       Array
	var sprite_texture: Texture2D

	if is_player:
		var hero_name: String = combatant.get("name", "")
		var hd: HeroData = BattleState.ALL_HERO_DATA.get(hero_name, null)
		var pd: Dictionary = {}
		for p: Dictionary in BattleState.PLAYERS:
			if p.get("name", "") == hero_name:
				pd = p
				break
		name_str       = hd.hero_name    if hd else hero_name
		type_str       = hd.hero_class   if hd else ""
		level_val      = hd.level        if hd else 0
		max_hp_val     = hd.max_hp       if hd else 0
		current_hp     = pd.get("hp", max_hp_val)
		ac_val         = hd.ac           if hd else 0
		str_v          = hd.strength     if hd else 0
		dex_v          = hd.dexterity    if hd else 0
		con_v          = hd.constitution if hd else 0
		int_v          = hd.intelligence if hd else 0
		wis_v          = hd.wisdom       if hd else 0
		cha_v          = hd.charisma     if hd else 0
		resistances    = hd.resistances      if hd else []
		vulnerabilities = hd.vulnerabilities if hd else []
		immunities     = hd.immunities       if hd else []
		features       = hd.passive_features if hd else []
		sprite_texture = hd.sprite       if hd else null
		_sprite_frames = hd.sprite_frames if hd else null
	else:
		var enemy_type: String = combatant.get("type", "")
		var ename: String      = combatant.get("name", "")
		var ed: EnemyData      = BattleState.ALL_ENEMIES.get(enemy_type, null)
		name_str       = ed.enemy_name    if ed else ename
		type_str       = ed.enemy_type    if ed else ""
		level_val      = ed.level         if ed else 0
		max_hp_val     = ed.max_hp        if ed else 0
		current_hp     = state.enemy_hp.get(ename, max_hp_val)
		ac_val         = ed.ac            if ed else 0
		str_v          = ed.strength      if ed else 0
		dex_v          = ed.dexterity     if ed else 0
		con_v          = ed.constitution  if ed else 0
		int_v          = ed.intelligence  if ed else 0
		wis_v          = ed.wisdom        if ed else 0
		cha_v          = ed.charisma      if ed else 0
		resistances    = ed.resistances      if ed else []
		vulnerabilities = ed.vulnerabilities if ed else []
		immunities     = ed.immunities       if ed else []
		features       = ed.passive_features if ed else []
		sprite_texture = ed.sprite        if ed else null
		_sprite_frames = ed.sprite_frames if ed else null

	_sprite_rect.texture = sprite_texture
	_current_dir_idx = 0
	_update_sprite_direction()

	_name_label.text     = name_str
	_subtitle_label.text = type_str + " — Level " + str(level_val)

	_populate_combat_stats(current_hp, max_hp_val, ac_val)
	_populate_attributes(str_v, dex_v, con_v, int_v, wis_v, cha_v)
	_populate_conditions(state, idx)
	_populate_resistance_section(resistances)
	_populate_text_section(_vulnerabilities_box, vulnerabilities)
	_populate_text_section(_immunities_box, immunities)
	_populate_text_section(_features_box, features)

	visible    = true
	modulate.a = 0.0
	create_tween().tween_property(self, "modulate:a", 1.0, 0.18)

func hide_panel() -> void:
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.14)
	tw.tween_callback(func(): visible = false)

# ── POPULATE ───────────────────────────────────────────────────────────────

func _populate_combat_stats(current_hp: int, max_hp: int, ac: int) -> void:
	_clear_children(_combat_stats_box)
	_combat_stats_box.add_child(
		_icon_row_colored("res://assets/ui/icons/stats/hp.png", "hp.png",
			"HP:", " %d / %d" % [current_hp, max_hp]))
	_combat_stats_box.add_child(
		_icon_row_colored("res://assets/ui/icons/stats/ac.png", "ac.png",
			"AC:", " %d" % ac))

func _populate_attributes(str_v: int, dex_v: int, con_v: int,
		int_v: int, wis_v: int, cha_v: int) -> void:
	_clear_children(_attr_grid)
	var attrs: Array = [
		["FOR:", str_v, "strength.png"],
		["DES:", dex_v, "dextery.png"],
		["CON:", con_v, "constitution.png"],
		["INT:", int_v, "intelligence.png"],
		["SAB:", wis_v, "wisdom.png"],
		["CHA:", cha_v, "charisma.png"],
	]
	for a in attrs:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 15)
		var icon := _build_icon("res://assets/ui/icons/stats/" + a[2], a[2])
		icon.custom_minimum_size = Vector2(18, 18)
		cell.add_child(icon)
		
		var lbl := Label.new()
		lbl.text = a[0]
		lbl.add_theme_font_size_override("font_size", FONT_STAT)
		lbl.add_theme_color_override("font_color", TITLE_COLOR)
		cell.add_child(lbl)
		
		var val := Label.new()
		val.text = str(a[1])
		val.add_theme_font_size_override("font_size", FONT_STAT)
		val.add_theme_color_override("font_color", TEXT_COLOR)
		cell.add_child(val)
		
		_attr_grid.add_child(cell)

func _populate_conditions(state: BattleState, combatant_idx: int) -> void:
	_clear_children(_conditions_box)
	if combatant_idx < 0 or combatant_idx >= state.combatant_statuses.size():
		_empty_label(_conditions_box, "Nenhuma")
		return
	var statuses: Dictionary = state.combatant_statuses[combatant_idx]
	var any_active := false
	# Itera o REGISTRY (fonte única) — só exibe chaves de display conhecidas,
	# ignorando estado interno (charmed_by, reaction_used, death_saves_*, etc.).
	for key: String in StatusDefinitions.ORDER:
		var val = statuses.get(key, 0)
		if typeof(val) != TYPE_INT or val <= 0:
			continue
		any_active = true
		var icon_path := "res://assets/ui/icons/condicoes/" + key + ".png"
		var title := StatusDefinitions.name_of(key)
		if StatusDefinitions.shows_duration(key):
			title += " (%d turnos)" % val
		_conditions_box.add_child(_icon_row(icon_path, key + ".png", title))
		var desc := StatusDefinitions.desc_of(key)
		if desc != "":
			var dlbl := Label.new()
			dlbl.text = desc
			dlbl.add_theme_font_size_override("font_size", FONT_TEXT - 2)
			dlbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.72))
			dlbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			_conditions_box.add_child(dlbl)
	if not any_active:
		_empty_label(_conditions_box, "Nenhuma")

func _populate_resistance_section(resistances: Array) -> void:
	_clear_children(_resistances_box)
	if resistances.is_empty():
		_empty_label(_resistances_box, "Nenhuma")
		return
	for r: String in resistances:
		var filename := r.to_lower().replace(" ", "_") + ".png"
		var icon_path := "res://assets/ui/icons/resistencias/" + filename
		_resistances_box.add_child(_icon_row(icon_path, filename, r))

func _populate_text_section(box: VBoxContainer, items: Array) -> void:
	_clear_children(box)
	if items.is_empty():
		_empty_label(box, "Nenhuma")
		return
	for item: String in items:
		var lbl := Label.new()
		lbl.text = "• " + item
		lbl.add_theme_font_size_override("font_size", FONT_TEXT)
		lbl.add_theme_color_override("font_color", TEXT_COLOR)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		box.add_child(lbl)

# ── HELPERS ────────────────────────────────────────────────────────────────

func _build_section_with_header(parent: VBoxContainer, title: String, content_box: VBoxContainer) -> void:
	var section_vbox := VBoxContainer.new()
	section_vbox.add_theme_constant_override("separation", 6)
	parent.add_child(section_vbox)
	
	var outer_margin := MarginContainer.new()
	outer_margin.add_theme_constant_override("margin_left", -20)
	section_vbox.add_child(outer_margin)
	
	var header_wrapper := Control.new()
	header_wrapper.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	header_wrapper.z_index = 10
	header_wrapper.clip_contents = false
	outer_margin.add_child(header_wrapper)
	
	var measure_label := Label.new()
	measure_label.text = title.to_upper()
	measure_label.add_theme_font_size_override("font_size", FONT_SECTION)
	header_wrapper.add_child(measure_label)
	
	await get_tree().process_frame
	var text_size := measure_label.get_minimum_size()
	measure_label.queue_free()
	
	var total_w := text_size.x + PANEL_SMALL_PATCH * 2 + 8
	var total_h := text_size.y + PANEL_SMALL_PATCH * 1 + 2
	header_wrapper.custom_minimum_size = Vector2(total_w, total_h)
	
	var header_bg := NinePatchRect.new()
	header_bg.texture = PANEL_SMALL_TEXTURE
	header_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_bg.patch_margin_left   = PANEL_SMALL_PATCH
	header_bg.patch_margin_right  = PANEL_SMALL_PATCH
	header_bg.patch_margin_top    = PANEL_SMALL_PATCH
	header_bg.patch_margin_bottom = PANEL_SMALL_PATCH
	header_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_wrapper.add_child(header_bg)
	
	var header_label := _section_header(title)
	header_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	header_label.offset_left   = PANEL_SMALL_PATCH
	header_label.offset_right  = -PANEL_SMALL_PATCH
	header_label.offset_top    = PANEL_SMALL_PATCH * 0.6
	header_label.offset_bottom = -2
	header_wrapper.add_child(header_label)
	
	section_vbox.add_child(content_box)

func _icon_row(icon_path: String, placeholder_name: String, label_text: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	var icon := _build_icon(icon_path, placeholder_name)
	icon.custom_minimum_size = Vector2(18, 18)
	hbox.add_child(icon)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", FONT_TEXT)
	lbl.add_theme_color_override("font_color", TEXT_COLOR)
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(lbl)
	return hbox

func _build_icon(icon_path: String, placeholder_name: String) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(18, 18)
	if ResourceLoader.exists(icon_path):
		var tr := TextureRect.new()
		tr.texture      = load(icon_path)
		tr.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(tr)
	else:
		var rect := ColorRect.new()
		rect.color = PLACEHOLDER_COLOR
		rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(rect)
		if placeholder_name != "":
			var lbl := Label.new()
			lbl.text = placeholder_name
			lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
			lbl.add_theme_font_size_override("font_size", 5)
			lbl.clip_text    = true
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			container.add_child(lbl)
	return container

func _section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text.to_upper()
	lbl.add_theme_font_size_override("font_size", FONT_SECTION)
	lbl.add_theme_color_override("font_color", SECTION_HDR_COLOR)
	return lbl

func _empty_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", FONT_TEXT)
	lbl.add_theme_color_override("font_color", SECTION_HDR_COLOR)
	parent.add_child(lbl)

func _make_separator() -> HSeparator:
	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.22, 0.22, 0.28))
	return sep

func _clear_children(node: Control) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey:
		var ke := event as InputEventKey
		if ke.pressed and ke.keycode == KEY_ESCAPE:
			hide_panel()
			get_viewport().set_input_as_handled()

func _icon_row_colored(icon_path: String, placeholder_name: String,
		label_text: String, value_text: String) -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 6)
	var icon := _build_icon(icon_path, placeholder_name)
	icon.custom_minimum_size = Vector2(24, 24)
	hbox.add_child(icon)
	
	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", FONT_TEXT)
	lbl.add_theme_color_override("font_color", TEXT_STAT_COLOR)  # cor dourada
	lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(lbl)
	
	var val := Label.new()
	val.text = value_text
	val.add_theme_font_size_override("font_size", FONT_TEXT)
	val.add_theme_color_override("font_color", TEXT_COLOR)  # cor normal
	val.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(val)
	
	return hbox
