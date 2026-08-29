class_name DungeonMapScreenBkp
extends Control

# ======================================================
# 🎨 ASSETS
# ======================================================
const BG_TEXTURE   := preload("res://assets/ui/backgrounds/menu_bg.png")
const LOGO_TEXTURE := preload("res://assets/ui/logo/dungeon_map_logo.png")

const PANEL_TEXTURE := preload("res://assets/ui/panels/panel_large.png")

const BTN_NORMAL  := preload("res://assets/ui/buttons/btn_normal.png")
const BTN_HOVER   := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_PRESSED := preload("res://assets/ui/buttons/btn_pressed.png")

const BTN_RED_NORMAL  := preload("res://assets/ui/buttons/btn_pressed.png")
const BTN_RED_HOVER   := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_RED_PRESSED := preload("res://assets/ui/buttons/btn_pressed.png")

# Círculos dos nós — por raridade, 3 estados cada
const NODE_TEXTURES := {
	"battle":  [
		preload("res://assets/ui/map/nodes/node_battle_normal.png"),
		preload("res://assets/ui/map/nodes/node_battle_hover.png"),
		preload("res://assets/ui/map/nodes/node_battle_selected.png"),
	],
	"elite": [
		preload("res://assets/ui/map/nodes/node_elite_normal.png"),
		preload("res://assets/ui/map/nodes/node_elite_hover.png"),
		preload("res://assets/ui/map/nodes/node_elite_selected.png"),
	],
	"boss": [
		preload("res://assets/ui/map/nodes/node_boss_normal.png"),
		preload("res://assets/ui/map/nodes/node_boss_hover.png"),
		preload("res://assets/ui/map/nodes/node_boss_selected.png"),
	],
	"event": [
		preload("res://assets/ui/map/nodes/node_event_normal.png"),
		preload("res://assets/ui/map/nodes/node_event_hover.png"),
		preload("res://assets/ui/map/nodes/node_event_selected.png"),
	],
	"mystery": [
		preload("res://assets/ui/map/nodes/node_mystery_normal.png"),
		preload("res://assets/ui/map/nodes/node_mystery_hover.png"),
		preload("res://assets/ui/map/nodes/node_mystery_selected.png"),
	],
}

# Ícones sobre os nós (boss não tem ícone — já está embutido no NODE_TEXTURES)
const NODE_ICONS := {
	DungeonState.RoomType.BATTLE:  preload("res://assets/ui/map/icons/icon_battle.png"),
	DungeonState.RoomType.ELITE:   preload("res://assets/ui/map/icons/icon_elite.png"),
	DungeonState.RoomType.EVENT:   preload("res://assets/ui/map/icons/icon_event.png"),
	DungeonState.RoomType.MYSTERY: preload("res://assets/ui/map/icons/icon_mystery.png"),
}

# Nó do boss usa uma textura especial maior (já com ícone embutido)
const BOSS_NODE_TEXTURES := [
	preload("res://assets/ui/map/nodes/node_boss_special_normal.png"),
	preload("res://assets/ui/map/nodes/node_boss_special_hover.png"),
	preload("res://assets/ui/map/nodes/node_boss_special_selected.png"),
]

# 6 variações estéticas de corrente — sorteadas por conexão
const CHAIN_TEXTURES := [
	preload("res://assets/ui/map/chains/chain_1.png"),
	preload("res://assets/ui/map/chains/chain_2.png"),
	preload("res://assets/ui/map/chains/chain_3.png"),
	preload("res://assets/ui/map/chains/chain_4.png"),
	preload("res://assets/ui/map/chains/chain_5.png"),
	preload("res://assets/ui/map/chains/chain_6.png"),
]

# Mapeamento RoomType → chave de NODE_TEXTURES
const NODE_TYPE_KEY := {
	DungeonState.RoomType.BATTLE:  "battle",
	DungeonState.RoomType.ELITE:   "elite",
	DungeonState.RoomType.BOSS:    "boss",
	DungeonState.RoomType.EVENT:   "event",
	DungeonState.RoomType.MYSTERY: "mystery",
}

const NODE_NAMES := {
	DungeonState.RoomType.BATTLE:  "Batalha",
	DungeonState.RoomType.ELITE:   "Batalha Elite",
	DungeonState.RoomType.BOSS:    "BOSS",
	DungeonState.RoomType.EVENT:   "Evento",
	DungeonState.RoomType.MYSTERY: "Mistério",
}

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE DE TAMANHOS
# ──────────────────────────────────────────────────────
const NODE_SIZE         := 64.0    # diâmetro do nó em pixels
const NODE_SIZE_BOSS    := 88.0    # boss é maior — textura já com ícone embutido
const NODE_ICON_SIZE    := 30.0    # tamanho do ícone sobre o nó (não boss)
const CHAIN_THICKNESS   := 12.0    # espessura visual da corrente (altura do tile)
const PANEL_PATCH       := 32      # nine-patch margin do painel lateral
const PANEL_TITLE_SIZE  := 16
const PANEL_FLOOR_SIZE  := 12
# ──────────────────────────────────────────────────────

# ======================================================
# VARS
# ======================================================
var _state: DungeonState
var _selected_node_id: int  = -1
var _hovered_node_id: int   = -1
var _available_ids: Array   = []
var _past_locked_ids: Array = []   # não completados, não disponíveis, andar já passado
var _chain_map: Dictionary  = {}   # "from_id:to_id" -> int (índice da textura)

var _canvas: Control
var _info_name: Label
var _info_floor: Label
var _enter_btn: TextureButton

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	_state = DungeonState.current_run
	if _state == null:
		SceneTransition.fade_to("res://ui/main_menu.tscn")
		return

	_assign_chain_textures()

	_build_background()
	_build_layout()
	_refresh_available()
	_auto_select_first()

# ======================================================
# CHAIN MAP — monta sequência de texturas por conexão
#
# Regras:
#   ponta inicial/final → sorteia entre chain_1, chain_2, chain_5  (índices 0,1,4)
#   segmentos do meio   → 70% chain_4 (índice 3), 30% sorteia entre chain_3, chain_6 (índices 2,5)
#
# _chain_map guarda Array[int] com os índices de cada segmento da corrente.
# ======================================================
const _CHAIN_ENDS   := [0, 1, 4]   # chain_1, chain_2, chain_5
const _CHAIN_MIDDLE := [2, 5]      # chain_3, chain_6 (minoria do meio)
const _CHAIN_MAIN   := 3           # chain_4 (70% do meio)
const _CHAIN_SEGS   := 8           # segmentos por conexão — ajuste visual

func _assign_chain_textures() -> void:
	var rng := RandomNumberGenerator.new()
	for node: DungeonState.RoomNode in _state.nodes:
		for conn_id: int in node.connections:
			var key := "%d:%d" % [mini(node.id, conn_id), maxi(node.id, conn_id)]
			if _chain_map.has(key):
				continue

			rng.seed = node.id * 7919 + conn_id * 6271

			var segs: Array[int] = []
			for s in _CHAIN_SEGS:
				if s == 0 or s == _CHAIN_SEGS - 1:
					segs.append(_CHAIN_ENDS[rng.randi() % _CHAIN_ENDS.size()])
				else:
					if rng.randf() < 0.70:
						segs.append(_CHAIN_MAIN)
					else:
						segs.append(_CHAIN_MIDDLE[rng.randi() % _CHAIN_MIDDLE.size()])
			_chain_map[key] = segs

# ======================================================
# BUILD — BACKGROUND
# ======================================================
func _build_background() -> void:
	var bg := TextureRect.new()
	bg.texture      = BG_TEXTURE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

# ======================================================
# BUILD — LAYOUT PRINCIPAL
# ======================================================
func _build_layout() -> void:
	# Logo no topo centralizado
	var logo := TextureRect.new()
	logo.texture             = LOGO_TEXTURE
	logo.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	logo.custom_minimum_size = Vector2(0, 64)
	logo.offset_bottom       = 64
	add_child(logo)

	_build_canvas()
	_build_info_panel()
	_build_bottom_bar()

# ======================================================
# BUILD — CANVAS DO MAPA
# ======================================================
func _build_canvas() -> void:
	_canvas = Control.new()
	_canvas.anchor_left   = 0.0
	_canvas.anchor_right  = 0.70
	_canvas.anchor_top    = 0.0
	_canvas.anchor_bottom = 1.0
	_canvas.offset_top    = 68
	_canvas.offset_bottom = -56
	_canvas.mouse_filter  = Control.MOUSE_FILTER_STOP
	_canvas.draw.connect(_on_canvas_draw)
	_canvas.gui_input.connect(_on_canvas_input)
	_canvas.mouse_exited.connect(func():
		if _hovered_node_id != -1:
			_hovered_node_id = -1
			_canvas.queue_redraw()
	)
	add_child(_canvas)

# ======================================================
# BUILD — PAINEL LATERAL
# ======================================================
func _build_info_panel() -> void:
	# NinePatch com textura de pedra
	var panel := NinePatchRect.new()
	panel.texture             = PANEL_TEXTURE
	panel.anchor_left         = 0.70
	panel.anchor_right        = 1.0
	panel.anchor_top          = 0.0
	panel.anchor_bottom       = 0.50
	panel.offset_top          = 68
	panel.offset_bottom       = -56
	panel.patch_margin_left   = PANEL_PATCH
	panel.patch_margin_right  = PANEL_PATCH
	panel.patch_margin_top    = PANEL_PATCH
	panel.patch_margin_bottom = PANEL_PATCH
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   20)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(vbox)

	_info_name = Label.new()
	_info_name.text = "Selecione uma sala"
	_info_name.add_theme_font_size_override("font_size", PANEL_TITLE_SIZE)
	_info_name.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	_info_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_info_name)

	_info_floor = Label.new()
	_info_floor.add_theme_font_size_override("font_size", PANEL_FLOOR_SIZE)
	_info_floor.add_theme_color_override("font_color", Color(0.55, 0.62, 0.80))
	vbox.add_child(_info_floor)

	# Spacer empurra o botão para baixo
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_enter_btn = _add_texture_button(vbox, "Entrar", BTN_NORMAL, BTN_HOVER, BTN_PRESSED, _on_enter_room)
	_enter_btn.visible = false

# ======================================================
# BUILD — BARRA INFERIOR
# ======================================================
func _build_bottom_bar() -> void:
	var bar := HBoxContainer.new()
	bar.anchor_left   = 0.0
	bar.anchor_right  = 1.0
	bar.anchor_top    = 1.0
	bar.anchor_bottom = 1.0
	bar.offset_top    = -52
	bar.offset_bottom = -4
	bar.alignment     = BoxContainer.ALIGNMENT_CENTER
	add_child(bar)

	_add_texture_button(bar, "Voltar ao Menu",
		BTN_RED_NORMAL, BTN_RED_HOVER, BTN_RED_PRESSED, _on_back_to_menu)

# ======================================================
# CANVAS — DRAW
# ======================================================
func _on_canvas_draw() -> void:
	if _state == null:
		return

	_draw_connections()
	_draw_nodes()

func _draw_connections() -> void:
	for node: DungeonState.RoomNode in _state.nodes:
		# Nó origem invisível → nenhuma corrente sai dele
		if not _is_node_visible(node):
			continue
		var from_pos := _node_center(node)
		for conn_id: int in node.connections:
			var target: DungeonState.RoomNode = _state.get_node_by_id(conn_id)
			if target == null or not _is_node_visible(target):
				continue
			var to_pos := _node_center(target)
			var key    := "%d:%d" % [mini(node.id, conn_id), maxi(node.id, conn_id)]
			var segs: Array = _chain_map.get(key, [_CHAIN_MAIN])
			_draw_chain(from_pos, to_pos, segs)

func _is_node_visible(node: DungeonState.RoomNode) -> bool:
	return node.completed \
		or _available_ids.has(node.id) \
		or _past_locked_ids.has(node.id)

func _draw_chain(from: Vector2, to: Vector2, seg_indices: Array) -> void:
	var diff   := to - from
	var length := diff.length()
	var angle  := diff.angle()
	if length < 1.0 or seg_indices.is_empty():
		return

	var seg_len := length / seg_indices.size()

	for i in seg_indices.size():
		var tex: Texture2D = CHAIN_TEXTURES[seg_indices[i]]
		var origin := from + diff.normalized() * (seg_len * i)
		var xform  := Transform2D(angle, origin)

		_canvas.draw_set_transform_matrix(xform)
		_canvas.draw_texture_rect(tex,
			Rect2(0.0, -CHAIN_THICKNESS * 0.5, seg_len, CHAIN_THICKNESS),
			false)

	_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_nodes() -> void:
	for node: DungeonState.RoomNode in _state.nodes:
		var pos     := _node_center(node)
		var is_boss := node.type == DungeonState.RoomType.BOSS
		var textures: Array = BOSS_NODE_TEXTURES if is_boss \
			else NODE_TEXTURES.get(NODE_TYPE_KEY.get(node.type, "battle"), NODE_TEXTURES["battle"])
		var nsize := NODE_SIZE_BOSS if is_boss else NODE_SIZE
		var half  := nsize * 0.5

		var tex_idx  := 0         # 0=normal  1=hover  2=pressed/selected
		var alpha    := 1.0
		var show_icon := true

		if node.completed:
			# ── Completado: aspecto pressed + ícone + opacidade reduzida ──
			tex_idx   = 2
			alpha     = 0.45
			show_icon = true
		elif _past_locked_ids.has(node.id):
			# ── Linha passada, não feito: aspecto normal + ícone + opacidade reduzida ──
			tex_idx   = 0
			alpha     = 0.40
			show_icon = true
		elif _available_ids.has(node.id):
			# ── Disponível: estado interativo normal/hover/selected ──
			if node.id == _selected_node_id:
				tex_idx = 2
			elif node.id == _hovered_node_id:
				tex_idx = 1
		else:
			# ── Futuro bloqueado: completamente invisível / não desenhado ──
			continue

		var color := Color(1, 1, 1, alpha)

		_canvas.draw_texture_rect(textures[tex_idx],
			Rect2(pos - Vector2.ONE * half, Vector2.ONE * nsize),
			false, color)

		# Ícone por cima (boss já tem embutido)
		if show_icon and not is_boss and NODE_ICONS.has(node.type):
			var icon: Texture2D = NODE_ICONS[node.type]
			var icon_half := NODE_ICON_SIZE * 0.5
			_canvas.draw_texture_rect(icon,
				Rect2(pos - Vector2.ONE * icon_half, Vector2.ONE * NODE_ICON_SIZE),
				false, color)

		# Anel dourado apenas no selecionado disponível
		if node.id == _selected_node_id and _available_ids.has(node.id):
			_canvas.draw_arc(pos, half + 3.0, 0.0, TAU, 48,
				Color(0.90, 0.78, 0.20), 3.0)

# ======================================================
# CANVAS — INPUT
# ======================================================
func _on_canvas_input(event: InputEvent) -> void:
	if _state == null:
		return

	var mm := event as InputEventMouseMotion
	if mm != null:
		var new_hover := _node_id_at(mm.position, true)
		if new_hover != _hovered_node_id:
			_hovered_node_id = new_hover
			_canvas.queue_redraw()
		return

	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var hit_id := _node_id_at(mb.position, true)
	if hit_id >= 0:
		_select_node(hit_id)
	else:
		_deselect_node()

# ======================================================
# NODE — HELPERS
# ======================================================
func _node_center(node: DungeonState.RoomNode) -> Vector2:
	var sz     := _canvas.size
	var margin := NODE_SIZE * 0.5 + 8.0
	return Vector2(
		margin + node.position.x * (sz.x - margin * 2.0),
		margin + node.position.y * (sz.y - margin * 2.0)
	)

func _node_id_at(pos: Vector2, available_only: bool) -> int:
	for node: DungeonState.RoomNode in _state.nodes:
		if node.completed:
			continue
		if available_only and not _available_ids.has(node.id):
			continue
		var nsize := NODE_SIZE_BOSS if node.type == DungeonState.RoomType.BOSS else NODE_SIZE
		if pos.distance_to(_node_center(node)) <= nsize * 0.5:
			return node.id
	return -1

func _select_node(id: int) -> void:
	_selected_node_id = id
	var node: DungeonState.RoomNode = _state.get_node_by_id(id)
	if node == null:
		return
	_info_name.text  = NODE_NAMES.get(node.type, "Sala")
	_info_floor.text = "Boss" if node.floor == DungeonState.FLOOR_COUNT - 1 \
		else "Andar %d" % node.floor
	_enter_btn.visible = true
	_canvas.queue_redraw()

func _deselect_node() -> void:
	_selected_node_id  = -1
	_info_name.text    = "Selecione uma sala"
	_info_floor.text   = ""
	_enter_btn.visible = false
	_canvas.queue_redraw()

func _refresh_available() -> void:
	_available_ids.clear()
	_past_locked_ids.clear()

	for n: DungeonState.RoomNode in _state.get_available_rooms():
		_available_ids.append(n.id)

	# Andar atual = menor andar entre os disponíveis (ou 0 se nenhum)
	var current_floor := 0
	if not _available_ids.is_empty():
		var first: DungeonState.RoomNode = _state.get_node_by_id(_available_ids[0])
		if first != null:
			current_floor = first.floor

	# Nós não completados e não disponíveis em andares anteriores ao atual
	for n: DungeonState.RoomNode in _state.nodes:
		if n.completed:
			continue
		if _available_ids.has(n.id):
			continue
		if n.floor < current_floor:
			_past_locked_ids.append(n.id)

func _auto_select_first() -> void:
	if _available_ids.is_empty():
		return
	_select_node(_available_ids[0])

# ======================================================
# ACTIONS
# ======================================================
func _on_enter_room() -> void:
	if _selected_node_id < 0 or _state == null:
		return
	_state.enter_room(_selected_node_id)
	SceneTransition.fade_to("res://battle/battle_scene.tscn")

func _on_back_to_menu() -> void:
	DungeonState.current_run = null
	BattleState.reset_players()
	SceneTransition.fade_to("res://ui/main_menu.tscn")

# ======================================================
# HELPER — TEXTURE BUTTON
# ======================================================
func _add_texture_button(
		parent: Control,
		text: String,
		tex_n: Texture2D,
		tex_h: Texture2D,
		tex_p: Texture2D,
		cb: Callable) -> TextureButton:

	var btn := TextureButton.new()
	btn.texture_normal        = tex_n
	btn.texture_hover         = tex_h
	btn.texture_pressed       = tex_p
	btn.custom_minimum_size   = Vector2(220, 52)
	btn.ignore_texture_size   = true
	btn.stretch_mode          = TextureButton.STRETCH_SCALE
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(btn)

	var lbl := Label.new()
	lbl.text = text
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color",        Color(0.90, 0.85, 0.75))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	btn.add_child(lbl)

	btn.pressed.connect(cb)
	return btn
