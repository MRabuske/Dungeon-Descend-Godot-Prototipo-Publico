class_name EventScene
extends Control

# ======================================================
# 🎨 ASSETS
# ======================================================
const BG_TEXTURE   := preload("res://assets/ui/backgrounds/mystery_bg.png")
const PANEL_TEXTURE_MAIN := preload("res://assets/ui/panels/panel_mystery.png")
const PANEL_TEXTURE_DESC := preload("res://assets/ui/panels/panel_mystery_desc.png")

const BTN_NORMAL  := preload("res://assets/ui/buttons/btn_normal.png")
const BTN_HOVER   := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_PRESSED := preload("res://assets/ui/buttons/btn_pressed.png")

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE DE TAMANHOS
# ──────────────────────────────────────────────────────
const PANEL_PATCH      := 32
const PANEL_WIDTH      := 520
const PANEL_HEIGHT     := 420
const TITLE_MARGIN_TOP := 58
const FONT_TITLE       := 12
const FONT_DESC        := 9
const FONT_CHOICE      := 9
const FONT_RESULT      := 9
const FONT_CONTINUE    := 9
# ──────────────────────────────────────────────────────

const TITLE_COLOR := Color(0.55, 0.08, 0.08)

# ======================================================
# VARS
# ======================================================d
var _event: EventData
var _choice_buttons: Array = []
var _result_lbl: Label
var _continue_btn: TextureButton
var _go_to_battle: bool = false

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	var node_id: int = -1
	if DungeonState.current_run != null:
		node_id = DungeonState.current_run.current_node_id

	var node: DungeonState.RoomNode = null
	if DungeonState.current_run != null:
		node = DungeonState.current_run.get_node_by_id(node_id)

	if node != null and node.type == DungeonState.RoomType.MYSTERY:
		_event = MysteryRegistry.resolve(node_id)
	else:
		_event = EventData.get_for_node(node_id)

	if _event == null:
		_finish()
		return

	_build_background()
	_build_ui()

# ======================================================
# BUILD — BACKGROUND
# ======================================================
func _build_background() -> void:
	var bg := TextureRect.new()
	bg.texture      = BG_TEXTURE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var dark := ColorRect.new()
	dark.color = Color(0, 0, 0, 0.65)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dark)

# ======================================================
# BUILD — UI
# ======================================================
func _build_ui() -> void:
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var panel := Control.new()
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, PANEL_HEIGHT)
	center.add_child(panel)

	var panel_bg := NinePatchRect.new()
	panel_bg.texture = PANEL_TEXTURE_MAIN
	panel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_bg.patch_margin_left   = PANEL_PATCH
	panel_bg.patch_margin_right  = PANEL_PATCH
	panel_bg.patch_margin_top    = PANEL_PATCH
	panel_bg.patch_margin_bottom = PANEL_PATCH
	panel.add_child(panel_bg)

	# Container principal com 3 seções
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	main_vbox.add_theme_constant_override("separation", 0)
	panel.add_child(main_vbox)

	# 1. Container do Título (topo)
	var title_container := MarginContainer.new()
	title_container.add_theme_constant_override("margin_left",   60)
	title_container.add_theme_constant_override("margin_right",  60)
	title_container.add_theme_constant_override("margin_top",    TITLE_MARGIN_TOP)
	title_container.add_theme_constant_override("margin_bottom", 4)
	main_vbox.add_child(title_container)

	var title := Label.new()
	title.text = _event.title
	title.add_theme_font_size_override("font_size", FONT_TITLE)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title_container.add_child(title)

	# 2. Container da Descrição (tamanho conforme conteúdo)
	var desc_container := MarginContainer.new()
	desc_container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	desc_container.add_theme_constant_override("margin_left",   60)
	desc_container.add_theme_constant_override("margin_right",  60)
	desc_container.add_theme_constant_override("margin_top",    60)
	desc_container.add_theme_constant_override("margin_bottom", 12)
	main_vbox.add_child(desc_container)

	var desc_inner_margin := MarginContainer.new()
	desc_inner_margin.add_theme_constant_override("margin_left",   12)
	desc_inner_margin.add_theme_constant_override("margin_right",  12)
	desc_inner_margin.add_theme_constant_override("margin_top",    12)
	desc_inner_margin.add_theme_constant_override("margin_bottom", 12)
	desc_inner_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desc_container.add_child(desc_inner_margin)

	var desc_bg := NinePatchRect.new()
	desc_bg.texture = PANEL_TEXTURE_DESC
	desc_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	desc_bg.patch_margin_left   = PANEL_PATCH - 12
	desc_bg.patch_margin_right  = PANEL_PATCH - 12
	desc_bg.patch_margin_top    = PANEL_PATCH - 12 
	desc_bg.patch_margin_bottom = PANEL_PATCH - 12
	desc_bg.custom_minimum_size = Vector2(60, 60)
	desc_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	desc_inner_margin.add_child(desc_bg)

	var desc_vbox := VBoxContainer.new()
	desc_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	desc_inner_margin.add_child(desc_vbox)
	
	var desc_text_margin := MarginContainer.new()
	desc_text_margin.add_theme_constant_override("margin_left",   30)
	desc_text_margin.add_theme_constant_override("margin_right",  30)
	desc_text_margin.add_theme_constant_override("margin_top",    30)
	desc_text_margin.add_theme_constant_override("margin_bottom", 30)
	desc_vbox.add_child(desc_text_margin)

	var desc := Label.new()
	desc.text = _event.description
	desc.add_theme_font_size_override("font_size", FONT_DESC)
	desc.add_theme_color_override("font_color", Color(0.78, 0.78, 0.88))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_text_margin.add_child(desc)

	# 3. Container dos Botões (embaixo)
	var buttons_container := MarginContainer.new()
	buttons_container.add_theme_constant_override("margin_left",   60)
	buttons_container.add_theme_constant_override("margin_right",  60)
	buttons_container.add_theme_constant_override("margin_top",    8)
	buttons_container.add_theme_constant_override("margin_bottom", 30)
	main_vbox.add_child(buttons_container)

	var buttons_vbox := VBoxContainer.new()
	buttons_vbox.add_theme_constant_override("separation", 8)
	buttons_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons_container.add_child(buttons_vbox)

	for choice: EventData.EventChoice in _event.choices:
		var btn := _make_button(choice.label)
		var c := choice
		btn.pressed.connect(func() -> void: _on_choice(c))
		_choice_buttons.append(btn)
		buttons_vbox.add_child(btn)

	_result_lbl = Label.new()
	_result_lbl.add_theme_font_size_override("font_size", FONT_RESULT)
	_result_lbl.add_theme_color_override("font_color", Color(0.70, 0.92, 0.70))
	_result_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_result_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result_lbl.visible = false
	buttons_vbox.add_child(_result_lbl)

	_continue_btn = _make_button("Continuar")
	_continue_btn.visible = false
	_continue_btn.pressed.connect(_finish)
	buttons_vbox.add_child(_continue_btn)

	# Animação de entrada
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.3)
	
# ======================================================
# ACTIONS
# ======================================================
func _on_choice(choice: EventData.EventChoice) -> void:
	var result: String
	if choice.is_random:
		if randi() % 2 == 0:
			var extra := _apply_one(choice.consequence_type, choice.value, choice.target)
			result = choice.result_text + (" " + extra if extra != "" else "")
		else:
			var extra := _apply_one(choice.secondary_type, choice.secondary_value, choice.secondary_target)
			result = choice.secondary_text + (" " + extra if extra != "" else "")
	else:
		_apply_one(choice.consequence_type, choice.value, choice.target)
		if choice.secondary_type != EventData.ConsequenceType.NOTHING:
			var extra := _apply_one(choice.secondary_type, choice.secondary_value, choice.secondary_target)
			result = choice.result_text + (" " + extra if extra != "" else "")
		else:
			result = choice.result_text

	if _go_to_battle:
		SceneTransition.fade_to("res://battle/battle_scene.tscn")
		return

	for btn in _choice_buttons:
		btn.visible = false
	_result_lbl.text = result
	_result_lbl.visible = true
	_continue_btn.visible = true

func _apply_one(ctype: int, value: int, target: String) -> String:
	var C := EventData.ConsequenceType
	match ctype:
		C.HEAL_PARTY:
			for p in BattleState.PLAYERS:
				p["hp"] = mini(p["max_hp"], p["hp"] + value)
		C.DAMAGE_PARTY:
			for p in BattleState.PLAYERS:
				p["hp"] = maxi(1, p["hp"] - value)
		C.HEAL_TARGET:
			var pidx := _resolve_target(target)
			if pidx >= 0:
				var p: Dictionary = BattleState.PLAYERS[pidx]
				p["hp"] = mini(p["max_hp"], p["hp"] + value)
				return "(%s +%dHP)" % [p["name"], value]
		C.DAMAGE_TARGET:
			var pidx := _resolve_target(target)
			if pidx >= 0:
				var p: Dictionary = BattleState.PLAYERS[pidx]
				p["hp"] = maxi(1, p["hp"] - value)
				return "(%s -%dHP)" % [p["name"], value]
		C.MP_RESTORE_PARTY:
			for p in BattleState.PLAYERS:
				p["mp"] = mini(p["max_mp"], p["mp"] + value)
		C.BUFF_NEXT_BATTLE:
			if DungeonState.current_run != null:
				DungeonState.current_run.pending_buffs.append({"type": target, "value": value})
		C.REVEAL_CONNECTIONS:
			if DungeonState.current_run != null:
				DungeonState.current_run.reveal_extra_connections(
					DungeonState.current_run.current_node_id)
		C.GO_TO_BATTLE:
			_go_to_battle = true
	return ""

func _resolve_target(target: String) -> int:
	if BattleState.PLAYERS.is_empty():
		return -1
	if target == "random_hero":
		return randi() % BattleState.PLAYERS.size()
	if target == "weakest_hero":
		var min_hp := 999999
		var idx    := 0
		for i in range(BattleState.PLAYERS.size()):
			if BattleState.PLAYERS[i]["hp"] < min_hp:
				min_hp = BattleState.PLAYERS[i]["hp"]
				idx = i
		return idx
	return -1

func _finish() -> void:
	if DungeonState.current_run != null:
		DungeonState.current_run.complete_current_room()
	SceneTransition.fade_to("res://ui/dungeon_map.tscn")

# ======================================================
# HELPERS
# ======================================================
func _make_button(text: String) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal  = BTN_NORMAL
	btn.texture_hover   = BTN_HOVER
	btn.texture_pressed = BTN_PRESSED
	btn.ignore_texture_size = true
	btn.stretch_mode    = TextureButton.STRETCH_SCALE
	btn.custom_minimum_size = Vector2(300, 42)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	btn.size_flags_vertical   = Control.SIZE_SHRINK_CENTER

	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", FONT_CHOICE)
	lbl.add_theme_color_override("font_color", Color(0.90, 0.85, 0.75))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	btn.add_child(lbl)

	return btn
