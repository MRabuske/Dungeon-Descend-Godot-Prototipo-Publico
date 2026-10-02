class_name ActionPanel
extends Control

# Grid de acoes estilo BG3. Substitui o antigo sistema de abas
# ACTION/HABILIDADES/ITEMS. As acoes do heroi ativo sao divididas em dois
# lados (esquerda = acoes normais/mover/dash; direita = habilidades/magias),
# separados por uma divisoria. Indicadores de Action/Bonus Action ficam acima
# do grid; o botao Fim de Turno fica na lateral direita.
#
# Contrato com BattleScene:
#   grid_action_clicked(action)  — uma acao foi clicada (ActionData)
#   grid_action_hovered(action)  — hover numa acao (ActionData) ou null ao sair
#   end_turn_pressed             — botao Fim de Turno
#   cancel_action / confirm_action — overlay de confirmacao (itens / fim de turno)
signal grid_action_clicked(action)
signal grid_action_hovered(action)
signal end_turn_pressed
signal cancel_action
signal confirm_action
# Altura desejada da HUD muda quando o nº de linhas do grid muda (cresce p/ cima).
signal content_height_changed(h: int)

# ======================================================
# ASSETS
# ======================================================
const PANEL_TEXTURE   := preload("res://assets/ui/panels/panel_actions.png")
const SLOT_NORMAL_TEX := preload("res://assets/ui/buttons/slot_normal.png")
const SLOT_ACTIVE_TEX := preload("res://assets/ui/buttons/slot_active.png")
const BTN_NORMAL      := preload("res://assets/ui/buttons/btn_normal.png")
const BTN_HOVER       := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_PRESSED     := preload("res://assets/ui/buttons/btn_pressed.png")
const ITEM_ICON_POCAO := preload("res://assets/ui/icons/itens/poção.png")
const ITEM_ICON_ETER  := preload("res://assets/ui/icons/itens/éter.png")

# ──────────────────────────────────────────────────────
# TAMANHOS
# ──────────────────────────────────────────────────────
const PANEL_PATCH := 16
const GRID_COLS   := 14
const SLOT_MIN_W  := 30
const SLOT_H      := 50
const HUD_CHROME  := 100  # barras de recurso/itens + margens (rows=2 => 100 + 2*50 = 200)
const ICON_SIZE   := 28
const FONT_SLOTNUM := 7
const FONT_MSG    := 10
const FONT_SLOT   := 8
const DIVIDER_COLOR := Color(0.80, 0.20, 0.20)
# ──────────────────────────────────────────────────────

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

	var _normal_tex: Texture2D
	var _active_tex: Texture2D

	func setup_textures(normal: Texture2D, active: Texture2D) -> void:
		_normal_tex = normal
		_active_tex = active

	func _draw() -> void:
		var tex := _active_tex if is_active else _normal_tex
		if tex:
			draw_texture_rect(tex, Rect2(Vector2.ZERO, size), false)

		var c := size / 2.0
		if icon_texture != null:
			var s := minf(ICON_SIZE, minf(size.x, size.y) - 6.0)
			draw_texture_rect(icon_texture, Rect2(c.x - s * 0.5, c.y - s * 0.5, s, s), false, Color.WHITE)
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
# INNER — RESOURCE ICON (Action dot / Bonus arrow)
# ======================================================
class ResourceIcon extends Control:
	enum Kind { DOT, ARROW }
	var kind: int  = Kind.DOT
	var used: bool = false

	const GREEN  := Color(0.30, 0.80, 0.35)
	const ORANGE := Color(0.95, 0.55, 0.15)
	const USED   := Color(0.22, 0.22, 0.25)

	func _draw() -> void:
		var c := size / 2.0
		var col := USED if used else (GREEN if kind == Kind.DOT else ORANGE)
		if kind == Kind.DOT:
			draw_circle(c, minf(size.x, size.y) * 0.32, col)
		else:
			var r := minf(size.x, size.y) * 0.42
			draw_polygon(PackedVector2Array([
				c + Vector2(0, -r), c + Vector2(r, r * 0.7), c + Vector2(-r, r * 0.7),
			]), PackedColorArray([col]))

# ======================================================
# INNER — SLOT INDICATOR (nivel de spell slot / Ki, clicavel p/ filtrar)
# ======================================================
class SlotIndicator extends Control:
	var level: int     = 1      # 1-6 (spell slot) ou -1 (Ki)
	var available: int = 0      # slots disponiveis no nivel
	var max_slots: int = 0      # slots maximos no nivel
	var active: bool   = false  # filtro ativo neste indicador?

	const SLOT_COLOR    := Color(0.20, 0.55, 0.95)
	const SLOT_SPENT    := Color(0.22, 0.22, 0.28)
	const ACTIVE_BORDER := Color(0.90, 0.80, 0.20)
	const KI_COLOR      := Color(0.95, 0.80, 0.30)

	static func _roman(n: int) -> String:
		var numerals := ["I", "II", "III", "IV", "V", "VI"]
		return numerals[n - 1] if n >= 1 and n <= numerals.size() else str(n)

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var base_col := KI_COLOR if level == -1 else SLOT_COLOR
		var col := base_col if available > 0 else SLOT_SPENT

		if active:
			draw_rect(Rect2(Vector2.ZERO, size), Color(col.r, col.g, col.b, 0.15))
			draw_rect(Rect2(Vector2.ZERO, size), ACTIVE_BORDER, false, 1.5)

		var label := "Ki" if level == -1 else _roman(level)
		draw_string(ThemeDB.fallback_font, Vector2(0, h * 0.45), label,
				HORIZONTAL_ALIGNMENT_CENTER, w, 11, col)

		var dot_r   := 2.5
		var n_dots  := mini(max_slots, 8)
		var spacing := (w - 4.0) / maxf(n_dots, 1)
		for i in range(n_dots):
			var cx := 2.0 + spacing * i + spacing * 0.5
			draw_circle(Vector2(cx, h * 0.78), dot_r, col if i < available else SLOT_SPENT)

# ======================================================
# INNER — GRID CELL (suporta clique, hover e drag-reorder)
# ======================================================
class GridCell extends Control:
	var panel: ActionPanel
	var side: String        = "left"
	var slot_index: int     = 0
	var drawer: SlotDrawer
	var num_lbl: Label
	var action: ActionData  = null

	func _gui_input(event: InputEvent) -> void:
		# Dispara no release: assim, ao iniciar um arraste (botao pressionado +
		# mover), o clique nao executa a acao — o release vai para o destino do
		# drop, nao para esta celula.
		var mb := event as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and action != null:
			# Se esta celula foi a origem de um drag, o release nao deve executar a
			# acao (o usuario estava arrastando, nao clicando).
			if panel._drag_source != self:
				panel._on_cell_clicked(action)
			panel._drag_source = null

	func _get_drag_data(_at: Vector2) -> Variant:
		# So permite arrastar quando o grid esta desbloqueado, sem filtro ativo
		# e ha uma acao na celula.
		if panel._grid_locked or panel._filter_mode != 0 or panel._slot_filter_level != 0 or action == null:
			return null
		var preview := SlotDrawer.new()
		preview.setup_textures(ActionPanel.SLOT_NORMAL_TEX, ActionPanel.SLOT_ACTIVE_TEX)
		preview.icon_texture = drawer.icon_texture
		preview.shape        = drawer.shape
		preview.icon_color   = drawer.icon_color
		preview.custom_minimum_size = Vector2(ActionPanel.SLOT_H, ActionPanel.SLOT_H)
		preview.size = Vector2(ActionPanel.SLOT_H, ActionPanel.SLOT_H)
		set_drag_preview(preview)
		panel._drag_source = self
		return {"side": side, "from": slot_index, "label": action.label}

	func _can_drop_data(_at: Vector2, data: Variant) -> bool:
		# Aceita drop de qualquer lado (drag livre entre esquerda e direita).
		return data is Dictionary and data.has("from") and data.has("side") and data.has("label")

	func _drop_data(_at: Vector2, data: Variant) -> void:
		panel._place_action(String(data["label"]), String(data["side"]), int(data["from"]), side, slot_index)

# ======================================================
# VARS
# ======================================================
var _state: BattleState
var _panel_bg: NinePatchRect

var _resource_bar: HBoxContainer
var _action_dot: ResourceIcon
var _bonus_arrow: ResourceIcon

var _grid_body: HBoxContainer
var _left_grid: GridContainer
var _right_grid: GridContainer
var _divider_handle: ColorRect
var _dragging_divider: bool = false
var _left_cells: Array  = []
var _right_cells: Array = []

var _side_controls: VBoxContainer
var _lock_btn: Button
var _drag_source = null   # GridCell de origem do drag em curso (evita clique pós-drag)

var _grid_locked: bool   = true
var _filter_mode: int    = 0    # 0 = nenhum; 1 = Action (bonus=false); 2 = Bonus (bonus=true)
var _slot_filter_level: int = 0 # 0 = sem filtro de slot; 1-6 = nivel; -1 = Ki
var _slot_indicators: Array = []  # referencias aos SlotIndicator (niveis 1-6 + Ki)
# Posicao fixa de cada acao no grid (esparso): label -> {"side": "left"/"right", "slot": int}.
# Persiste pelos refreshes; permite slots vazios fora de ordem (drag livre, estilo BG3).
var _slot_assign: Dictionary = {}

# Overlay de confirmacao / mensagens de modo (mover/atacar/inimigo)
var _action_bar: Control
var _enemy_lbl: Label
var _action_desc_lbl: Label
var _back_btn: TextureButton
var _confirm_btn: TextureButton
var _needs_confirm: bool     = false
var _action_bar_active: bool = false

var _divider: int = 7  # coluna onde fica a divisoria (esquerda 0.._divider-1)
var _rows: int    = 2  # linhas do grid (1..4); cada linha tem 14 slots

# Barra de itens (separada do grid)
var _items_bar: HBoxContainer
var _item_cells: Array = []

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	_build_panel()

# ======================================================
# BUILD — PANEL
# ======================================================
func _build_panel() -> void:
	_panel_bg = NinePatchRect.new()
	_panel_bg.texture             = PANEL_TEXTURE
	_panel_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_panel_bg.patch_margin_left   = PANEL_PATCH
	_panel_bg.patch_margin_right  = PANEL_PATCH
	_panel_bg.patch_margin_top    = PANEL_PATCH
	_panel_bg.patch_margin_bottom = PANEL_PATCH
	_panel_bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	add_child(_panel_bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   14)
	margin.add_theme_constant_override("margin_right",  14)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	var root_vbox := VBoxContainer.new()
	root_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(root_vbox)

	_build_resource_bar(root_vbox)

	_grid_body = HBoxContainer.new()
	_grid_body.add_theme_constant_override("separation", 6)
	_grid_body.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	_grid_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	root_vbox.add_child(_grid_body)

	_build_grid(_grid_body)
	_build_side_controls(_grid_body)

	_build_items_bar(root_vbox)
	_build_action_bar()

	_emit_content_height()

# ======================================================
# BUILD — RESOURCE BAR (Action / Bonus indicators)
# ======================================================
func _build_resource_bar(parent: Control) -> void:
	_resource_bar = HBoxContainer.new()
	_resource_bar.add_theme_constant_override("separation", 8)
	_resource_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(_resource_bar)

	_action_dot = ResourceIcon.new()
	_action_dot.kind = ResourceIcon.Kind.DOT
	_action_dot.custom_minimum_size = Vector2(16, 16)
	_action_dot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_action_dot.gui_input.connect(func(ev: InputEvent) -> void: _on_resource_clicked(ev, 1))
	_resource_bar.add_child(_action_dot)

	_bonus_arrow = ResourceIcon.new()
	_bonus_arrow.kind = ResourceIcon.Kind.ARROW
	_bonus_arrow.custom_minimum_size = Vector2(16, 16)
	_bonus_arrow.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_bonus_arrow.gui_input.connect(func(ev: InputEvent) -> void: _on_resource_clicked(ev, 2))
	_resource_bar.add_child(_bonus_arrow)

	# Indicadores de spell slot (niveis I-VI) + Ki, clicaveis p/ filtrar o grid.
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(6, 0)
	sep.add_theme_color_override("separator_color", Color(1, 1, 1, 0.15))
	_resource_bar.add_child(sep)

	_slot_indicators.clear()
	for i in range(7):  # 0-5 = niveis 1-6; 6 = Ki
		var ind := SlotIndicator.new()
		ind.level = (i + 1) if i < 6 else -1
		ind.custom_minimum_size = Vector2(36, 42)
		ind.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		ind.visible = false
		var lvl := ind.level
		ind.gui_input.connect(func(ev: InputEvent) -> void: _on_slot_indicator_clicked(ev, lvl))
		_resource_bar.add_child(ind)
		_slot_indicators.append(ind)

# Clicar num indicador alterna o filtro do grid (so um filtro por vez).
func _on_resource_clicked(event: InputEvent, mode: int) -> void:
	var mb := event as InputEventMouseButton
	if not (mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed):
		return
	_slot_filter_level = 0  # filtros Action/Bonus e de slot sao mutuamente exclusivos
	_filter_mode = 0 if _filter_mode == mode else mode
	_update_grid()

# Clicar num indicador de slot filtra o grid para as magias daquele nivel (ou Ki).
func _on_slot_indicator_clicked(event: InputEvent, level: int) -> void:
	var mb := event as InputEventMouseButton
	if not (mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed):
		return
	_filter_mode = 0  # mutuamente exclusivo com Action/Bonus
	_slot_filter_level = 0 if _slot_filter_level == level else level
	_update_grid()
	_update_resource_bar()

# ======================================================
# BUILD — GRID (left + divider + right)
# ======================================================
func _build_grid(parent: Control) -> void:
	_left_grid = _make_side_grid(_divider)
	parent.add_child(_left_grid)

	# Divisoria vermelha arrastavel: segurar e arrastar redistribui as colunas
	# entre os lados (minimo 1 coluna por lado).
	_divider_handle = ColorRect.new()
	_divider_handle.color = DIVIDER_COLOR
	_divider_handle.custom_minimum_size = Vector2(6, 0)
	_divider_handle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_divider_handle.mouse_filter = Control.MOUSE_FILTER_STOP
	_divider_handle.mouse_default_cursor_shape = Control.CURSOR_HSIZE
	_divider_handle.gui_input.connect(_on_divider_input)
	parent.add_child(_divider_handle)

	_right_grid = _make_side_grid(GRID_COLS - _divider)
	parent.add_child(_right_grid)

	_rebuild_cells()

# ======================================================
# DIVIDER DRAG
# ======================================================
func _on_divider_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging_divider = mb.pressed
	elif event is InputEventMouseMotion and _dragging_divider:
		# Fracao da posicao do mouse ao longo da regiao das 14 colunas.
		var region_left  := _left_grid.global_position.x
		var region_right := _right_grid.global_position.x + _right_grid.size.x
		var region_w     := region_right - region_left
		if region_w <= 0.0:
			return
		var frac := clampf((get_global_mouse_position().x - region_left) / region_w, 0.0, 1.0)
		var new_div := clampi(int(round(frac * GRID_COLS)), 1, GRID_COLS - 1)
		if new_div != _divider:
			_set_divider(new_div)

func _set_divider(n: int) -> void:
	_divider = clampi(n, 1, GRID_COLS - 1)
	_left_grid.columns  = _divider
	_right_grid.columns = GRID_COLS - _divider
	_rebuild_cells()
	if _state != null:
		_update_grid()

func _make_side_grid(cols: int) -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = maxi(1, cols)
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.size_flags_vertical   = Control.SIZE_EXPAND_FILL
	return grid

# Recria as celulas dos dois lados conforme _divider e o numero de linhas (2).
func _rebuild_cells() -> void:
	for c in _left_grid.get_children():
		c.queue_free()
	for c in _right_grid.get_children():
		c.queue_free()
	_left_cells.clear()
	_right_cells.clear()

	var rows := _rows
	var left_cols  := _divider
	var right_cols := GRID_COLS - _divider
	_left_grid.columns  = maxi(1, left_cols)
	_right_grid.columns = maxi(1, right_cols)

	var num := 1
	for i in range(rows * left_cols):
		_left_cells.append(_make_cell(_left_grid, "left", i, num))
		num += 1
	for i in range(rows * right_cols):
		_right_cells.append(_make_cell(_right_grid, "right", i, num))
		num += 1

func _make_cell(grid: GridContainer, side: String, slot_index: int, number: int) -> GridCell:
	var cell := GridCell.new()
	cell.panel      = self
	cell.side       = side
	cell.slot_index = slot_index
	cell.custom_minimum_size   = Vector2(SLOT_MIN_W, SLOT_H)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cell.mouse_filter          = Control.MOUSE_FILTER_STOP
	grid.add_child(cell)

	var drawer := SlotDrawer.new()
	drawer.setup_textures(SLOT_NORMAL_TEX, SLOT_ACTIVE_TEX)
	drawer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(drawer)
	cell.drawer = drawer

	var num_lbl := Label.new()
	num_lbl.text = str(number)
	num_lbl.add_theme_font_size_override("font_size", FONT_SLOTNUM)
	num_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	num_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	num_lbl.position = Vector2(2, -12)
	num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(num_lbl)
	cell.num_lbl = num_lbl

	cell.mouse_entered.connect(func() -> void: grid_action_hovered.emit(cell.action))
	cell.mouse_exited.connect(func() -> void:  grid_action_hovered.emit(null))
	return cell

# Chamado pela GridCell ao receber um clique simples sobre uma acao.
func _on_cell_clicked(action) -> void:
	grid_action_clicked.emit(action)

# ======================================================
# BUILD — ITEMS BAR (separada do grid)
# ======================================================
func _build_items_bar(parent: Control) -> void:
	_items_bar = HBoxContainer.new()
	_items_bar.add_theme_constant_override("separation", 6)
	_items_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	parent.add_child(_items_bar)

	var lbl := Label.new()
	lbl.text = "Itens:"
	lbl.add_theme_font_size_override("font_size", FONT_SLOT)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_items_bar.add_child(lbl)

func _update_items_bar() -> void:
	if _items_bar == null:
		return
	if _item_cells.is_empty():
		for item in BattleState.TAB_ITEMS:
			_add_item_cell(item)
	for entry: Dictionary in _item_cells:
		var item: Dictionary = entry["item"]
		var avail := _state.is_item_available(item)
		var drawer: SlotDrawer = entry["drawer"]
		drawer.icon_color = Color(0.3, 0.3, 0.35) if not avail else ACTION_ICON_COLORS[item.get("color_idx", 5)]
		drawer.queue_redraw()
		entry["count_lbl"].text = "x%d" % item.get("count", 0)

func _add_item_cell(item: Dictionary) -> void:
	var cell := HBoxContainer.new()
	cell.add_theme_constant_override("separation", 2)
	cell.mouse_filter = Control.MOUSE_FILTER_STOP
	_items_bar.add_child(cell)

	var drawer := SlotDrawer.new()
	drawer.setup_textures(SLOT_NORMAL_TEX, SLOT_ACTIVE_TEX)
	drawer.custom_minimum_size = Vector2(34, 34)
	drawer.icon_texture = _get_item_icon(item.get("label", ""))
	drawer.shape        = item.get("shape", 2)
	drawer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(drawer)

	var count_lbl := Label.new()
	count_lbl.add_theme_font_size_override("font_size", FONT_SLOT)
	count_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cell.add_child(count_lbl)

	var item_ref := item
	cell.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			grid_action_clicked.emit(item_ref)
	)
	cell.mouse_entered.connect(func() -> void: grid_action_hovered.emit(item_ref))
	cell.mouse_exited.connect(func() -> void:  grid_action_hovered.emit(null))

	_item_cells.append({"item": item, "drawer": drawer, "count_lbl": count_lbl})

func _get_item_icon(label: String) -> Texture2D:
	match label:
		"Poção": return ITEM_ICON_POCAO
		"Éter":  return ITEM_ICON_ETER
		_:       return null

# ======================================================
# BUILD — SIDE CONTROLS (Fim de Turno + cadeado + linhas)
# ======================================================
func _build_side_controls(parent: Control) -> void:
	# VBox de controles na borda DIREITA EXTERNA do grid: cadeado + linhas (+/−).
	# (End Turn saiu daqui — agora é um botão circular no HUD, em battle_scene.gd)
	_side_controls = VBoxContainer.new()
	_side_controls.add_theme_constant_override("separation", 4)
	_side_controls.alignment = BoxContainer.ALIGNMENT_CENTER
	_side_controls.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(_side_controls)

	# Cadeado: alterna travar/destravar o drag-reorder dos slots.
	_lock_btn = Button.new()
	_lock_btn.custom_minimum_size = Vector2(26, 26)
	var sb_lock := StyleBoxFlat.new()
	sb_lock.bg_color = Color(0.18, 0.18, 0.22)
	sb_lock.corner_radius_top_left     = 4
	sb_lock.corner_radius_top_right    = 4
	sb_lock.corner_radius_bottom_left  = 4
	sb_lock.corner_radius_bottom_right = 4
	_lock_btn.add_theme_stylebox_override("normal", sb_lock)
	_lock_btn.add_theme_font_size_override("font_size", 10)
	_lock_btn.pressed.connect(_on_lock_toggled)
	_side_controls.add_child(_lock_btn)
	_update_lock_label()

	# Botoes + / - para adicionar/remover linhas do grid (1..4).
	var plus_btn := Button.new()
	plus_btn.text = "+"
	plus_btn.custom_minimum_size = Vector2(26, 22)
	plus_btn.add_theme_font_size_override("font_size", 12)
	plus_btn.pressed.connect(func() -> void: _set_rows(_rows + 1))
	_side_controls.add_child(plus_btn)

	var minus_btn := Button.new()
	minus_btn.text = "−"
	minus_btn.custom_minimum_size = Vector2(26, 22)
	minus_btn.add_theme_font_size_override("font_size", 12)
	minus_btn.pressed.connect(func() -> void: _set_rows(_rows - 1))
	_side_controls.add_child(minus_btn)

func _set_rows(n: int) -> void:
	var clamped := clampi(n, 1, 4)
	if clamped == _rows:
		return
	_rows = clamped
	_rebuild_cells()
	if _state != null:
		_update_grid()
	_emit_content_height()

# Altura desejada da HUD = chrome (barras de recurso/itens + margens) + linhas do grid.
# A HUD cresce para CIMA porque a BattleArea (acima, EXPAND_FILL) cede o espaço.
func content_height() -> int:
	return HUD_CHROME + _rows * SLOT_H

func _emit_content_height() -> void:
	custom_minimum_size.y = content_height()
	content_height_changed.emit(content_height())

func _on_lock_toggled() -> void:
	_grid_locked = not _grid_locked
	_update_lock_label()

func _update_lock_label() -> void:
	if _lock_btn != null:
		_lock_btn.text = "🔒" if _grid_locked else "🔓"

# ======================================================
# BUILD — ACTION BAR (overlay de confirmacao / mensagens)
# ======================================================
func _build_action_bar() -> void:
	_action_bar = Control.new()
	_action_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_action_bar.visible = false
	add_child(_action_bar)

	var bg := NinePatchRect.new()
	bg.texture             = PANEL_TEXTURE
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

	_back_btn = _make_text_button("Voltar")
	buttons_hbox.add_child(_back_btn)
	_back_btn.pressed.connect(_on_cancel_action)

	_confirm_btn = _make_text_button("Confirmar")
	buttons_hbox.add_child(_confirm_btn)
	_confirm_btn.pressed.connect(_on_confirm_action)

	var bottom_spacer := Control.new()
	bottom_spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	action_vbox.add_child(bottom_spacer)

func _make_text_button(text: String) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal        = BTN_NORMAL
	btn.texture_hover         = BTN_HOVER
	btn.texture_pressed       = BTN_PRESSED
	btn.ignore_texture_size   = true
	btn.stretch_mode          = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	btn.custom_minimum_size   = Vector2(160, 36)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var lbl := Label.new()
	lbl.text = text
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", FONT_SLOT)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(lbl)
	return btn

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
	_update_resource_bar()
	_update_grid()
	_update_items_bar()

# ======================================================
# UPDATE — VISIBILITY
# ======================================================
func _update_visibility() -> void:
	if _action_bar_active:
		return
	var show_grid  := false
	var show_panel := false
	var msg        := ""

	match _state.current_state:
		BattleState.State.PLAYER_TURN:
			show_grid = true
		BattleState.State.MOVE_MODE:
			msg        = "Movendo — escolha o destino"
			show_panel = true
		BattleState.State.ATTACK_MODE:
			var lbl   := "Ataque"
			var allies := false
			if _pending_label != "":
				lbl = _pending_label
			allies = _pending_targets_allies
			msg        = "%s — escolha o %s" % [lbl, "aliado" if allies else "alvo"]
			show_panel = true
		BattleState.State.ENEMY_TURN:
			msg        = _state.enemy_action_text if _state.enemy_action_text != "" else "Inimigo está agindo..."
			show_panel = true

	# Filtro nao persiste fora do turno do jogador.
	if not show_grid:
		_filter_mode = 0
		_slot_filter_level = 0

	_resource_bar.visible  = show_grid
	_grid_body.visible     = show_grid
	if _items_bar != null:
		_items_bar.visible = show_grid
	_action_bar.visible    = show_panel
	_back_btn.visible      = show_panel and _state.current_state != BattleState.State.ENEMY_TURN
	_confirm_btn.visible   = show_panel and _needs_confirm
	_enemy_lbl.text        = msg
	_enemy_lbl.visible     = not msg.is_empty()

# ======================================================
# UPDATE — RESOURCE BAR
# ======================================================
func _update_resource_bar() -> void:
	# Bolinha verde = Action principal; seta laranja = Bonus Action.
	# Apagam (cinza) quando o recurso ja foi consumido no turno.
	_action_dot.used  = _state.has_attacked
	_bonus_arrow.used = _state.has_used_bonus_action
	_action_dot.queue_redraw()
	_bonus_arrow.queue_redraw()

	# Indicadores de spell slot / Ki refletem o herói ativo.
	var pidx := _state.get_active_player_index()
	var slots: Array     = []
	var slots_max: Array = []
	var ki: int     = 0
	var ki_max: int = 0
	if pidx >= 0:
		var p: Dictionary = BattleState.PLAYERS[pidx]
		slots     = p.get("spell_slots",     [0, 0, 0, 0, 0, 0])
		slots_max = p.get("spell_slots_max", [0, 0, 0, 0, 0, 0])
		ki        = p.get("ki",     0)
		ki_max    = p.get("ki_max", 0)

	for i in range(_slot_indicators.size()):
		var ind: SlotIndicator = _slot_indicators[i]
		if i < 6:
			var s_max: int = slots_max[i] if i < slots_max.size() else 0
			ind.visible   = s_max > 0
			ind.available = slots[i] if i < slots.size() else 0
			ind.max_slots = s_max
			ind.active    = _slot_filter_level == (i + 1)
		else:
			ind.visible   = ki_max > 0
			ind.available = ki
			ind.max_slots = ki_max
			ind.active    = _slot_filter_level == -1
		ind.queue_redraw()

# ======================================================
# UPDATE — GRID
# ======================================================
func _update_grid() -> void:
	if _slot_filter_level != 0:
		_update_grid_slot_filtered()
		return
	if _filter_mode != 0:
		_update_grid_filtered()
		return

	_divider_handle.visible = true

	var actions: Array = []
	for a in _state.tab_action:
		if a != null:
			actions.append(a)
	for a in _state.tab_habilidades:
		if a != null:
			actions.append(a)

	var left_cap := _rows * _divider
	var right_cap := _rows * (GRID_COLS - _divider)
	var left_map: Dictionary = {}   # slot -> action
	var right_map: Dictionary = {}
	var unplaced: Array = []

	# 1) Posicoes fixas (drag do usuario) que ainda cabem.
	for a in actions:
		var asg = _slot_assign.get(a.label, null)
		if asg == null:
			unplaced.append(a)
			continue
		var amap: Dictionary = left_map if asg["side"] == "left" else right_map
		var cap: int = left_cap if asg["side"] == "left" else right_cap
		var slot: int = int(asg["slot"])
		if slot >= 0 and slot < cap and not amap.has(slot):
			amap[slot] = a
		else:
			unplaced.append(a)

	# 2) Auto-coloca o resto no 1o slot livre do lado padrao (_classify).
	for a in unplaced:
		var l: Array = []
		var r: Array = []
		_classify(a, l, r)
		var side := "left" if not l.is_empty() else "right"
		var amap2: Dictionary = left_map if side == "left" else right_map
		var cap2: int = left_cap if side == "left" else right_cap
		var free := _first_free_slot(amap2, cap2)
		if free >= 0:
			amap2[free] = a
			_slot_assign[a.label] = {"side": side, "slot": free}

	_fill_side_sparse(_left_cells, left_map)
	_fill_side_sparse(_right_cells, right_map)

# Menor indice de slot livre em [0, cap), ou -1 se cheio.
func _first_free_slot(amap: Dictionary, cap: int) -> int:
	for i in range(cap):
		if not amap.has(i):
			return i
	return -1

# Modo filtro: mostra TODAS as acoes do bonus_action escolhido, mescladas
# (esquerda + direita como um grid continuo, sem divisoria).
func _update_grid_filtered() -> void:
	_divider_handle.visible = false
	var want_bonus := _filter_mode == 2
	var filtered: Array = []
	for a in _state.tab_action:
		if a.bonus_action == want_bonus:
			filtered.append(a)
	for a in _state.tab_habilidades:
		if a.bonus_action == want_bonus:
			filtered.append(a)
	_fill_side(_left_cells + _right_cells, filtered)

# Modo filtro por nivel de slot: mostra as magias que consomem o nivel escolhido
# (ou as habilidades de Ki quando _slot_filter_level == -1), grid continuo.
func _update_grid_slot_filtered() -> void:
	_divider_handle.visible = false
	var filtered: Array = []
	for a in _state.tab_action + _state.tab_habilidades:
		if _slot_filter_level == -1:
			if a.ki_cost > 0:
				filtered.append(a)
		elif a.spell_slot_level == _slot_filter_level:
			filtered.append(a)
	_fill_side(_left_cells + _right_cells, filtered)

# Renderiza um lado por SLOT (esparso): slot_map[i] = ActionData (ausente = vazio).
func _fill_side_sparse(cells: Array, slot_map: Dictionary) -> void:
	for i in range(cells.size()):
		var cell: GridCell = cells[i]
		var drawer: SlotDrawer = cell.drawer
		if slot_map.has(i):
			var action: ActionData = slot_map[i]
			cell.action = action
			cell.tooltip_text = action.label
			var unavailable := not _state.is_item_available(action)
			drawer.shape        = action.shape
			drawer.icon_color   = Color(0.3, 0.3, 0.35) if unavailable else ACTION_ICON_COLORS[action.color_idx]
			drawer.icon_texture = action.icon if action.has_icon() else null
			drawer.is_active    = false
			cell.num_lbl.visible = true
			cell.modulate = Color(1, 1, 1, 0.45) if unavailable else Color.WHITE
		else:
			cell.modulate = Color.WHITE
			cell.action = null
			cell.tooltip_text = ""
			drawer.shape = -1
			drawer.icon_texture = null
			drawer.is_active = false
			cell.num_lbl.visible = false
		drawer.queue_redraw()

# Label da acao atualmente no slot (side, slot), ou "" se vazio.
func _action_label_at(side: String, slot: int) -> String:
	var cells: Array = _left_cells if side == "left" else _right_cells
	if slot < 0 or slot >= cells.size() or cells[slot].action == null:
		return ""
	return cells[slot].action.label

# Coloca `label` em (to_side, to_slot). Destino ocupado => troca o ocupante para
# o slot de origem. Destino vazio => so move (a acao fica fixa naquele indice).
func _place_action(label: String, from_side: String, from_slot: int, to_side: String, to_slot: int) -> void:
	var occupant := _action_label_at(to_side, to_slot)
	_slot_assign[label] = {"side": to_side, "slot": to_slot}
	if occupant != "" and occupant != label:
		_slot_assign[occupant] = {"side": from_side, "slot": from_slot}
	if _state != null:
		_update_grid()

# Acoes comuns/taticas universais (BG3): ficam a ESQUERDA, mesmo sendo bonus/END_TURN.
func _is_universal_left(a) -> bool:
	return a is AcaoEmpurrar or a is AcaoPular or a is SkillAjuda or a is AcaoArremessar \
		or a is AcaoDip or a is AcaoEsconder or a is AcaoDesengajar or a is AcaoMover or a is DashAction

# Esquerda = acoes comuns/taticas universais + Mover/Dash. Direita = magias e
# habilidades de classe (bonus/slot/ki/END_TURN que NAO sao universais).
func _classify(a, left: Array, right: Array) -> void:
	if a == null:
		return
	if _is_universal_left(a):
		left.append(a)
		return
	if a.bonus_action or a.spell_slot_level > 0 or a.ki_cost > 0 or a.action_type == ActionData.Type.END_TURN:
		right.append(a)
	else:
		left.append(a)

func _fill_side(cells: Array, actions: Array) -> void:
	for i in range(cells.size()):
		var cell: GridCell = cells[i]
		var drawer: SlotDrawer = cell.drawer
		if i < actions.size():
			var action: ActionData = actions[i]
			cell.action = action
			cell.tooltip_text = action.label
			var unavailable := not _state.is_item_available(action)
			drawer.shape        = action.shape
			drawer.icon_color   = Color(0.3, 0.3, 0.35) if unavailable else ACTION_ICON_COLORS[action.color_idx]
			drawer.icon_texture = action.icon if action.has_icon() else null
			drawer.is_active    = false
			cell.num_lbl.visible = true
			cell.modulate = Color(1, 1, 1, 0.45) if unavailable else Color.WHITE
		else:
			cell.modulate = Color.WHITE
			cell.action = null
			cell.tooltip_text = ""
			drawer.shape        = -1
			drawer.icon_texture = null
			drawer.is_active    = false
			cell.num_lbl.visible = false
		drawer.queue_redraw()

# ======================================================
# CALLBACKS / OVERLAY
# ======================================================
func _on_cancel_action() -> void:
	cancel_action.emit()

func _on_confirm_action() -> void:
	confirm_action.emit()

# Rotulo da acao pendente, para a mensagem do modo de ataque.
var _pending_label: String = ""
var _pending_targets_allies: bool = false

func set_pending_attack(label: String, targets_allies: bool) -> void:
	_pending_label = label
	_pending_targets_allies = targets_allies

func show_action_bar(title: String, desc: String = "", needs_confirm: bool = false) -> void:
	_action_bar_active = true
	_needs_confirm     = needs_confirm
	_enemy_lbl.text    = title
	_enemy_lbl.visible = true
	_action_desc_lbl.text    = desc
	_action_desc_lbl.visible = not desc.is_empty()
	_action_bar.visible      = true
	_resource_bar.visible    = false
	_grid_body.visible       = false
	_back_btn.visible    = true
	_confirm_btn.visible = needs_confirm
	if needs_confirm:
		_confirm_btn.grab_focus()
	else:
		_back_btn.grab_focus()

func hide_action_bar() -> void:
	_action_bar_active = false
	_action_bar.visible = false
	_needs_confirm      = false
	refresh()
