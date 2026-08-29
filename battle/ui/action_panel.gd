class_name ActionPanel
extends Control

signal tab_clicked(index: int)
signal slot_clicked(index: int)
signal slot_hovered(index: int)
signal cancel_action
signal confirm_action

# ======================================================
# ASSETS
# ======================================================
const PANEL_TEXTURE      := preload("res://assets/ui/panels/panel_actions.png")
const TAB_NORMAL_TEXTURE := preload("res://assets/ui/buttons/tab_normal.png")
const TAB_ACTIVE_TEXTURE := preload("res://assets/ui/buttons/tab_active.png")
const SLOT_NORMAL_TEX    := preload("res://assets/ui/buttons/slot_normal.png")
const SLOT_ACTIVE_TEX    := preload("res://assets/ui/buttons/slot_active.png")
const BTN_NORMAL         := preload("res://assets/ui/buttons/btn_normal.png")
const BTN_HOVER          := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_PRESSED        := preload("res://assets/ui/buttons/btn_pressed.png")
const ITEM_ICON_POCAO    := preload("res://assets/ui/icons/itens/poção.png")
const ITEM_ICON_ETER     := preload("res://assets/ui/icons/itens/éter.png")

# ──────────────────────────────────────────────────────
# TAMANHOS
# ──────────────────────────────────────────────────────
const PANEL_PATCH := 16
const TAB_HEIGHT  := 26
const SLOT_HEIGHT := 64
const ICON_SIZE   := 32
const FONT_TAB    := 8
const FONT_SLOT   := 8
const FONT_SUB    := 6
const FONT_MSG    := 10
# ──────────────────────────────────────────────────────

const TAB_LABELS := ["ACTION", "SPELLS", "ITEMS"]

const ACTION_ICON_COLORS := [
	Color(0.85, 0.35, 0.25),
	Color(0.30, 0.55, 0.90),
	Color(0.60, 0.60, 0.60),
	Color(0.85, 0.75, 0.20),
	Color(0.40, 0.30, 0.90),
	Color(0.25, 0.75, 0.35),
	Color(0.20, 0.55, 0.90),
]

# ======================================================
# INNER — SLOT DRAWER
# ======================================================
class SlotDrawer extends Control:
	var icon_texture: Texture2D = null
	var shape: int              = -1
	var icon_color: Color       = Color.WHITE
	var is_active: bool         = false
	var has_bonus_badge: bool   = false

	var _normal_tex: Texture2D
	var _active_tex: Texture2D

	const SLOT_BG := Color(0.06, 0.07, 0.11)

	func setup_textures(normal: Texture2D, active: Texture2D) -> void:
		_normal_tex = normal
		_active_tex = active

	func _draw() -> void:
		var tex := _active_tex if is_active else _normal_tex
		if tex:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)

		if has_bonus_badge:
			draw_circle(Vector2(size.x - 7.0, 7.0), 5.5, Color(0, 0, 0, 0.70))
			draw_circle(Vector2(size.x - 7.0, 7.0), 4.0, Color(0.95, 0.80, 0.15))

		var c := size / 2.0

		if icon_texture != null:
			var icon_rect := Rect2(c.x - ICON_SIZE * 0.5, c.y - ICON_SIZE * 0.5, ICON_SIZE, ICON_SIZE)
			draw_texture_rect(icon_texture, icon_rect, false, Color.WHITE)
			return

		if shape < 0:
			var d := minf(size.x, size.y) * 0.12
			draw_line(c - Vector2(d, 0), c + Vector2(d, 0), Color(0.3, 0.3, 0.35, 0.5), 1.0)
			draw_line(c - Vector2(0, d), c + Vector2(0, d), Color(0.3, 0.3, 0.35, 0.5), 1.0)
			return

		var ir := minf(size.x, size.y) * 0.28
		match shape:
			0: draw_rect(Rect2(c.x - ir, c.y - ir, ir * 2, ir * 2), icon_color)
			1:
				var pts := PackedVector2Array()
				for k in range(6):
					var angle := k * PI / 3.0 - PI / 6.0
					pts.append(c + Vector2(cos(angle), sin(angle)) * ir)
				draw_polygon(pts, PackedColorArray([icon_color]))
			2: draw_circle(c, ir, icon_color)
			3:
				draw_polygon(PackedVector2Array([
					c + Vector2(0, -ir), c + Vector2(ir * 0.87, ir * 0.5), c + Vector2(-ir * 0.87, ir * 0.5),
				]), PackedColorArray([icon_color]))
			4:
				draw_line(c + Vector2(0, -ir), c + Vector2(-ir * 0.55, -ir * 0.1), icon_color, 2.0)
				draw_line(c + Vector2(0, -ir), c + Vector2( ir * 0.55, -ir * 0.1), icon_color, 2.0)
				draw_line(c + Vector2(0, -ir), c + Vector2(0,  ir * 0.6),          icon_color, 2.0)

# ======================================================
# VARS
# ======================================================
var _state: BattleState
var _panel_bg: NinePatchRect
var _tab_btns: Array[TextureButton]  = []
var _slot_drawers: Array[SlotDrawer] = []
var _slot_name_lbls: Array[Label]    = []
var _slot_sub_lbls: Array[Label]     = []
var _enemy_lbl: Label
var _action_desc_lbl: Label
var _action_bar: Control
var _back_btn: TextureButton
var _confirm_btn: TextureButton
var _slots_container: MarginContainer
var _needs_confirm: bool    = false
var _action_bar_active: bool = false

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	_build_panel()

# ======================================================
# BUILD — PANEL
# ======================================================
func _build_panel() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   0)
	margin.add_theme_constant_override("margin_right",  0)
	margin.add_theme_constant_override("margin_top",    0)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", -6)
	root_vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(root_vbox)

	_build_tab_bar(root_vbox)

	var content_area := MarginContainer.new()
	content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_theme_constant_override("margin_left",  16)
	content_area.add_theme_constant_override("margin_right", 16)
	root_vbox.add_child(content_area)

	_slots_container = MarginContainer.new()
	_slots_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_slots_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content_area.add_child(_slots_container)

	_panel_bg = NinePatchRect.new()
	_panel_bg.texture             = PANEL_TEXTURE
	_panel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_bg.patch_margin_left   = PANEL_PATCH
	_panel_bg.patch_margin_right  = PANEL_PATCH
	_panel_bg.patch_margin_top    = PANEL_PATCH
	_panel_bg.patch_margin_bottom = PANEL_PATCH
	_panel_bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_slots_container.add_child(_panel_bg)

	var slots_margin := MarginContainer.new()
	slots_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slots_margin.add_theme_constant_override("margin_left",   16)
	slots_margin.add_theme_constant_override("margin_right",  16)
	slots_margin.add_theme_constant_override("margin_top",    14)
	slots_margin.add_theme_constant_override("margin_bottom", 14)
	_slots_container.add_child(slots_margin)

	_build_slots(slots_margin)
	_build_action_bar(content_area)

# ======================================================
# BUILD — TAB BAR
# ======================================================
func _build_tab_bar(parent: Control) -> void:
	var outer := HBoxContainer.new()
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(outer)

	outer.add_child(_build_tab_hint("Q"))

	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", -3)
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(tab_bar)

	outer.add_child(_build_tab_hint("E"))

	for i in TAB_LABELS.size():
		var wrapper := Control.new()
		wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		wrapper.custom_minimum_size.y = TAB_HEIGHT + 7  # reserva espaço fixo para o shift ativo
		tab_bar.add_child(wrapper)

		var btn := TextureButton.new()
		btn.texture_normal      = TAB_NORMAL_TEXTURE
		btn.texture_pressed     = TAB_ACTIVE_TEXTURE
		btn.texture_hover       = TAB_ACTIVE_TEXTURE
		btn.ignore_texture_size = true
		btn.stretch_mode        = TextureButton.STRETCH_SCALE
		btn.anchor_left   = 0.0
		btn.anchor_right  = 1.0
		btn.anchor_top    = 0.0
		btn.anchor_bottom = 1.0
		# estado inicial = inativo; offset_bottom sempre 0
		wrapper.add_child(btn)
		_tab_btns.append(btn)

		var lbl := Label.new()
		lbl.text = TAB_LABELS[i]
		lbl.add_theme_font_size_override("font_size", FONT_TAB)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		lbl.anchor_left   = 0.0
		lbl.anchor_right  = 1.0
		lbl.anchor_top    = 0.0
		lbl.anchor_bottom = 1.0
		lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
		btn.add_child(lbl)

		var tab_i := i
		btn.pressed.connect(func(): tab_clicked.emit(tab_i))

func _build_tab_hint(key: String) -> Label:
	var hint := Label.new()
	hint.text = key
	hint.custom_minimum_size  = Vector2(60, 0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment   = VERTICAL_ALIGNMENT_BOTTOM
	hint.add_theme_font_size_override("font_size", FONT_TAB)
	hint.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return hint

# ======================================================
# BUILD — SLOTS
# ======================================================
func _build_slots(parent: Control) -> void:
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 6)
	parent.add_child(grid)

	for i in BattleState.MAX_SLOTS:
		var slot_vbox := VBoxContainer.new()
		slot_vbox.add_theme_constant_override("separation", 3)
		slot_vbox.alignment             = BoxContainer.ALIGNMENT_CENTER
		slot_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slot_vbox.mouse_filter          = Control.MOUSE_FILTER_STOP
		grid.add_child(slot_vbox)

		var drawer := SlotDrawer.new()
		drawer.setup_textures(SLOT_NORMAL_TEX, SLOT_ACTIVE_TEX)
		drawer.custom_minimum_size   = Vector2(0, SLOT_HEIGHT)
		drawer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		drawer.mouse_filter          = Control.MOUSE_FILTER_IGNORE
		slot_vbox.add_child(drawer)
		_slot_drawers.append(drawer)

		var name_lbl := Label.new()
		name_lbl.add_theme_font_size_override("font_size", FONT_SLOT)
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.autowrap_mode        = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.max_lines_visible    = 2
		name_lbl.clip_contents        = true
		name_lbl.custom_minimum_size  = Vector2(0, 30)
		name_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		slot_vbox.add_child(name_lbl)
		_slot_name_lbls.append(name_lbl)

		var sub_lbl := Label.new()
		sub_lbl.add_theme_font_size_override("font_size", FONT_SUB)
		sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub_lbl.custom_minimum_size  = Vector2(0, 14)
		sub_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
		slot_vbox.add_child(sub_lbl)
		_slot_sub_lbls.append(sub_lbl)

		var slot_i := i
		slot_vbox.gui_input.connect(func(ev: InputEvent) -> void:
			var mb := ev as InputEventMouseButton
			if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
				slot_clicked.emit(slot_i)
		)
		slot_vbox.mouse_entered.connect(func(): slot_hovered.emit(slot_i))
		slot_vbox.mouse_exited.connect(func():  slot_hovered.emit(-1))

# ======================================================
# BUILD — ACTION BAR
# ======================================================
func _build_action_bar(parent: Control) -> void:
	_action_bar = Control.new()
	_action_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_action_bar.visible = false
	parent.add_child(_action_bar)

	var bg := NinePatchRect.new()
	bg.texture            = PANEL_TEXTURE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.patch_margin_left   = PANEL_PATCH
	bg.patch_margin_right  = PANEL_PATCH
	bg.patch_margin_top    = PANEL_PATCH
	bg.patch_margin_bottom = PANEL_PATCH
	bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_action_bar.add_child(bg)

	var action_margin := MarginContainer.new()
	action_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	action_margin.add_theme_constant_override("margin_left",   16)
	action_margin.add_theme_constant_override("margin_right",  16)
	action_margin.add_theme_constant_override("margin_top",    14)
	action_margin.add_theme_constant_override("margin_bottom", 14)
	_action_bar.add_child(action_margin)

	var action_vbox := VBoxContainer.new()
	action_vbox.add_theme_constant_override("separation", 16)
	action_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_margin.add_child(action_vbox)

	var top_spacer := Control.new()
	top_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_vbox.add_child(top_spacer)

	_enemy_lbl = Label.new()
	_enemy_lbl.text = "Inimigo está agindo..."
	_enemy_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_enemy_lbl.autowrap_mode        = TextServer.AUTOWRAP_ARBITRARY
	_enemy_lbl.add_theme_font_size_override("font_size", FONT_MSG)
	action_vbox.add_child(_enemy_lbl)

	_action_desc_lbl = Label.new()
	_action_desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_action_desc_lbl.autowrap_mode        = TextServer.AUTOWRAP_ARBITRARY
	_action_desc_lbl.add_theme_font_size_override("font_size", FONT_SLOT)
	_action_desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	action_vbox.add_child(_action_desc_lbl)

	var buttons_hbox := HBoxContainer.new()
	buttons_hbox.add_theme_constant_override("separation", 16)
	buttons_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	action_vbox.add_child(buttons_hbox)

	_back_btn = TextureButton.new()
	_back_btn.texture_normal       = BTN_NORMAL
	_back_btn.texture_hover        = BTN_HOVER
	_back_btn.texture_pressed      = BTN_PRESSED
	_back_btn.ignore_texture_size  = true
	_back_btn.stretch_mode         = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_back_btn.custom_minimum_size  = Vector2(160, 36)
	_back_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons_hbox.add_child(_back_btn)

	var back_lbl := Label.new()
	back_lbl.text = "Voltar"
	back_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	back_lbl.add_theme_font_size_override("font_size", FONT_SLOT)
	back_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	back_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_back_btn.add_child(back_lbl)
	_back_btn.pressed.connect(_on_cancel_action)

	_confirm_btn = TextureButton.new()
	_confirm_btn.texture_normal       = BTN_NORMAL
	_confirm_btn.texture_hover        = BTN_HOVER
	_confirm_btn.texture_pressed      = BTN_PRESSED
	_confirm_btn.ignore_texture_size  = true
	_confirm_btn.stretch_mode         = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	_confirm_btn.custom_minimum_size  = Vector2(160, 36)
	_confirm_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	buttons_hbox.add_child(_confirm_btn)

	var confirm_lbl := Label.new()
	confirm_lbl.text = "Confirmar"
	confirm_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	confirm_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	confirm_lbl.add_theme_font_size_override("font_size", FONT_SLOT)
	confirm_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	confirm_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_confirm_btn.add_child(confirm_lbl)
	_confirm_btn.pressed.connect(_on_confirm_action)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_vbox.add_child(bottom_spacer)

# ======================================================
# PUBLIC API
# ======================================================
func setup(state: BattleState) -> void:
	_state = state
	refresh()

func refresh() -> void:
	if _state == null:
		return
	_update_visibility()
	_update_tabs()
	_update_slots()

# ======================================================
# UPDATE — VISIBILITY
# ======================================================
func _update_visibility() -> void:
	if _action_bar_active:
		return
	var show_grid  := false
	var show_tabs  := false
	var show_panel := false
	var msg        := ""

	match _state.current_state:
		BattleState.State.PLAYER_TURN:
			show_tabs = true
			show_grid = true
		BattleState.State.MOVE_MODE:
			msg        = "Movendo — escolha o destino"
			show_panel = true
		BattleState.State.ATTACK_MODE:
			var items := _state.get_active_tab_items()
			var item   = items[_state.cursor_position] if _state.cursor_position < items.size() else null
			var lbl   := "Ataque"
			var allies := false
			if item is ActionData:
				lbl    = (item as ActionData).label
				allies = (item as ActionData).targets_allies
			elif item is Dictionary:
				lbl    = item.get("label", "Ataque")
				allies = item.get("targets_allies", false)
			msg        = "%s — escolha o %s" % [lbl, "aliado" if allies else "alvo"]
			show_panel = true
		BattleState.State.ENEMY_TURN:
			msg        = _state.enemy_action_text if _state.enemy_action_text != "" else "Inimigo está agindo..."
			show_panel = true

	for btn: TextureButton in _tab_btns:
		btn.visible = show_tabs

	_action_bar.visible    = show_panel
	_back_btn.visible      = show_panel and _state.current_state != BattleState.State.ENEMY_TURN
	_confirm_btn.visible   = show_panel and _needs_confirm
	_enemy_lbl.text        = msg
	_enemy_lbl.visible     = not msg.is_empty()

	_slots_container.visible = show_grid

# ======================================================
# UPDATE — TABS
# ======================================================
func _update_tabs() -> void:
	if _state.current_state != BattleState.State.PLAYER_TURN:
		return
	for i in _tab_btns.size():
		var btn := _tab_btns[i]
		var is_active := i == _state.active_tab
		btn.texture_normal = TAB_ACTIVE_TEXTURE if is_active else TAB_NORMAL_TEXTURE
		btn.offset_top    = 7.0 if is_active else 0.0
		btn.offset_bottom = 0.0

# ======================================================
# UPDATE — SLOTS
# ======================================================
func _update_slots() -> void:
	var items := _state.get_active_tab_items()
	for i in BattleState.MAX_SLOTS:
		var drawer   := _slot_drawers[i]
		var name_lbl := _slot_name_lbls[i]
		var sub_lbl  := _slot_sub_lbls[i]

		if i >= items.size() or items[i] == null:
			_clear_slot(drawer, name_lbl, sub_lbl)
			continue

		var item        = items[i]
		var unavailable := not _state.is_item_available(item)

		if item is ActionData:
			var action := item as ActionData
			drawer.shape           = action.shape
			drawer.icon_color      = Color(0.3, 0.3, 0.35) if unavailable else ACTION_ICON_COLORS[action.color_idx]
			drawer.icon_texture    = action.icon if action.has_icon() else null
			drawer.is_active       = (i == _state.cursor_position)
			drawer.has_bonus_badge = action.bonus_action and not _state.has_used_bonus_action
			drawer.queue_redraw()
			name_lbl.text = "%d. %s" % [i + 1, action.label]
			sub_lbl.text  = "PP %d/%d" % [action.pp, action.max_pp] if action.max_pp > 0 else ""
		else:
			var d := item as Dictionary
			drawer.shape           = d.get("shape", 2)
			drawer.icon_color      = Color(0.3, 0.3, 0.35) if unavailable else ACTION_ICON_COLORS[d.get("color_idx", 5)]
			drawer.icon_texture    = _get_item_icon(d.get("label", ""))
			drawer.is_active       = (i == _state.cursor_position)
			drawer.has_bonus_badge = false
			drawer.queue_redraw()
			name_lbl.text = "%d. %s" % [i + 1, d.get("label", "")]
			sub_lbl.text  = "x%d" % d["count"] if d.has("count") else ""

func _clear_slot(drawer: SlotDrawer, name_lbl: Label, sub_lbl: Label) -> void:
	drawer.shape           = -1
	drawer.icon_texture    = null
	drawer.icon_color      = Color.WHITE
	drawer.is_active       = false
	drawer.has_bonus_badge = false
	drawer.queue_redraw()
	name_lbl.text = ""
	sub_lbl.text  = ""

func _get_item_icon(item_label: String) -> Texture2D:
	match item_label:
		"Poção": return ITEM_ICON_POCAO
		"Éter":  return ITEM_ICON_ETER
		_:       return null

# ======================================================
# CALLBACKS
# ======================================================
func _on_cancel_action() -> void:
	cancel_action.emit()

func _on_confirm_action() -> void:
	confirm_action.emit()

func show_action_bar(title: String, desc: String = "", needs_confirm: bool = false) -> void:
	_action_bar_active = true
	_needs_confirm     = needs_confirm
	_enemy_lbl.text    = title
	_enemy_lbl.visible = true
	_action_desc_lbl.text    = desc
	_action_desc_lbl.visible = not desc.is_empty()
	_action_bar.visible      = true
	_slots_container.visible = false
	for btn: TextureButton in _tab_btns:
		btn.visible = false
	_back_btn.visible    = true
	_confirm_btn.visible = needs_confirm
	if needs_confirm:
		_confirm_btn.grab_focus()
	else:
		_back_btn.grab_focus()
	_update_button_focus()

func hide_action_bar() -> void:
	_action_bar_active       = false
	_action_bar.visible      = false
	_slots_container.visible = true
	_needs_confirm           = false
	refresh()

func _update_button_focus() -> void:
	_back_btn.texture_normal = BTN_HOVER if _back_btn.has_focus() else BTN_NORMAL
	if _confirm_btn.visible:
		_confirm_btn.texture_normal = BTN_HOVER if _confirm_btn.has_focus() else BTN_NORMAL
