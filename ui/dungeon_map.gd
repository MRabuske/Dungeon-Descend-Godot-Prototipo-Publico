class_name DungeonMapScreen
extends Control

# ======================================================
# 🎨 ASSETS
# ======================================================
const BG_TEXTURE   := preload("res://assets/ui/backgrounds/menu_bg.png")
const LOGO_TEXTURE := preload("res://assets/ui/logo/dungeon_map_logo.png")

const PANEL_TEXTURE := preload("res://assets/ui/panels/panel_large.png")

const BTN_NORMAL   := preload("res://assets/ui/buttons/btn_normal.png")
const BTN_HOVER    := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_PRESSED  := preload("res://assets/ui/buttons/btn_pressed.png")
const BTN_DISABLED := preload("res://assets/ui/buttons/btn_disabled.png")
const BTN_COMPLETED := preload("res://assets/ui/buttons/btn_disabled.png")

const BTN_RED_NORMAL  := preload("res://assets/ui/buttons/btn_pressed.png")
const BTN_RED_HOVER   := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_RED_PRESSED := preload("res://assets/ui/buttons/btn_pressed.png")

const CHAIN_GLOW_TEXTURE := preload("res://assets/ui/map/chains/glow_particle.png")

# Círculos dos nós — por raridade, 3 estados cada (0=normal, 1=hover, 2=selected/pressed)
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

# Ícones sobre os nós (boss não tem ícone)
const NODE_ICONS := {
	DungeonState.RoomType.BATTLE:  preload("res://assets/ui/map/icons/icon_battle.png"),
	DungeonState.RoomType.ELITE:   preload("res://assets/ui/map/icons/icon_elite.png"),
	DungeonState.RoomType.EVENT:   preload("res://assets/ui/map/icons/icon_event.png"),
	DungeonState.RoomType.MYSTERY: preload("res://assets/ui/map/icons/icon_mystery.png"),
}

# Nó do boss usa uma textura especial maior
const BOSS_NODE_TEXTURES := [
	preload("res://assets/ui/map/nodes/node_boss_special_normal.png"),
	preload("res://assets/ui/map/nodes/node_boss_special_hover.png"),
	preload("res://assets/ui/map/nodes/node_boss_special_selected.png"),
]

# 6 variações estéticas de corrente
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

const NODE_DESCRIPTIONS := {
	DungeonState.RoomType.BATTLE:  "Combate tático por turnos contra inimigos comuns.",
	DungeonState.RoomType.ELITE:   "Inimigo poderoso com habilidades especiais. Maior risco, maior recompensa.",
	DungeonState.RoomType.BOSS:    "O guardião do dungeon. Derrote-o para completar a run.",
	DungeonState.RoomType.EVENT:   "Uma situação inesperada. Suas escolhas têm consequências.",
	DungeonState.RoomType.MYSTERY: "Destino incerto. Pode ser uma bênção ou uma armadilha.",
}

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE DE TAMANHOS
# ──────────────────────────────────────────────────────
const NODE_SIZE        := 64.0    # diâmetro do nó em pixels
const NODE_SIZE_BOSS    := 88.0    # boss é maior
const NODE_ICON_SIZE    := 30.0    # tamanho do ícone sobre o nó
const CHAIN_THICKNESS   := 12.0    # espessura visual da corrente
const PANEL_PATCH       := 32     # nine-patch margin do painel lateral
const PANEL_TITLE_SIZE  := 16
const PANEL_FLOOR_SIZE  := 12
# ──────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE Do GLOW
# ──────────────────────────────────────────────────────
const CHAIN_GLOW_COLOR := Color(0.55, 0.08, 0.08, 0.9)
const CHAIN_GLOW_INTENSITY := 1
const CHAIN_GLOW_PULSE_SPEED := 2.5
const CHAIN_GLOW_PARTICLE_SIZE := 10
const CHAIN_GLOW_PARTICLE_SPACING := 10.0
# ──────────────────────────────────────────────────────

# ======================================================
# VARS
# ======================================================
var _state: DungeonState
var _selected_node_id: int  = -1
var _hovered_node_id: int   = -1
var _available_ids: Array   = []   # Lista de salas ativas na rodada atual
var _chain_map: Dictionary  = {}   # "from_id:to_id" -> int (índice da textura)
var _glow_time: float = 0.0

var _canvas: Control
var _info_name: Label
var _info_floor: Label
var _enter_btn: TextureButton
var _enter_btn_label: Label     # ◄ GUARDAMOS A REFERÊNCIA DO TEXTO INTERNO DO BOTÃO
var _info_icon: TextureRect
var _info_desc: Label

var _party_list_container: VBoxContainer
var _kb_cursor: int = 0

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	print("=== DungeonMapScreen _ready ===")
	print("BattleState.PLAYERS size: ", BattleState.PLAYERS.size())
	for p in BattleState.PLAYERS:
		print("Player: ", p.get("name", "?"), " - HP: ", p.get("hp", 0))
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

func _process(delta: float) -> void:
	if _state == null:
		return
	
	_glow_time += delta
	
	if not _available_ids.is_empty():
		_canvas.queue_redraw()

# ======================================================
# CHAIN MAP — monta sequência de texturas por conexão
# ======================================================
const _CHAIN_ENDS   := [0, 1, 4]   
const _CHAIN_MIDDLE := [2, 5]      
const _CHAIN_MAIN   := 3           
const _CHAIN_SEGS   := 8           

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
	var panel := NinePatchRect.new()
	panel.texture             = PANEL_TEXTURE
	panel.anchor_left         = 0.70
	panel.anchor_right        = 1.0
	panel.anchor_top          = 0.0
	panel.anchor_bottom       = 1.0
	panel.offset_top          = 68
	panel.offset_bottom       = -56
	panel.patch_margin_left   = PANEL_PATCH
	panel.patch_margin_right  = PANEL_PATCH
	panel.patch_margin_top    = PANEL_PATCH
	panel.patch_margin_bottom = PANEL_PATCH
	add_child(panel)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   25)
	margin.add_theme_constant_override("margin_right",  20)
	margin.add_theme_constant_override("margin_top",    24)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	vbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	margin.add_child(vbox)

	_info_icon = TextureRect.new()
	_info_icon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_info_icon.custom_minimum_size = Vector2(0, 40)
	_info_icon.visible             = false
	vbox.add_child(_info_icon)

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

	_info_desc = Label.new()
	_info_desc.add_theme_font_size_override("font_size", 11)
	_info_desc.add_theme_color_override("font_color", Color(0.65, 0.68, 0.78))
	_info_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info_desc.visible = false
	vbox.add_child(_info_desc)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.22, 0.22, 0.30))
	sep.custom_minimum_size.y = 6
	vbox.add_child(sep)

	var party_title := Label.new()
	party_title.text = "PARTY"
	party_title.add_theme_font_size_override("font_size", 10)
	party_title.add_theme_color_override("font_color", Color(0.50, 0.58, 0.78))
	vbox.add_child(party_title)

	_party_list_container = VBoxContainer.new()
	_party_list_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_party_list_container)

	# ← REMOVIDO o loop duplicado que estava aqui
	# Agora apenas chamamos _refresh_party_list(), que já faz tudo
	_refresh_party_list()

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer)

	_enter_btn = _add_texture_button(vbox, "Entrar", BTN_NORMAL, BTN_HOVER, BTN_PRESSED, _on_enter_room)
	_enter_btn.texture_disabled = BTN_DISABLED
	_enter_btn.visible = false

	if _enter_btn.get_child_count() > 0:
		_enter_btn_label = _enter_btn.get_child(0) as Label
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

	var hint := Label.new()
	hint.text = "← → Selecionar sala   ·   ENTER Entrar   ·   ESC Deselecionar"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(hint)

# ======================================================
# CANVAS — DRAW
# ======================================================
func _on_canvas_draw() -> void:
	if _state == null:
		return

	_draw_floor_labels()
	_draw_connections()
	_draw_nodes()

func _draw_floor_labels() -> void:
	var sz      := _canvas.size
	var margin  := NODE_SIZE * 0.5 + 8.0
	var avail_h := sz.y - margin * 2.0
	var font    := ThemeDB.fallback_font
	var lbl_col  := Color(0.55, 0.62, 0.80, 0.45)
	var line_col := Color(0.25, 0.28, 0.40, 0.18)

	for f in range(DungeonState.FLOOR_COUNT):
		var t := float(f) / float(DungeonState.FLOOR_COUNT - 1)
		var y := margin + t * avail_h

		if f > 0:
			var prev_t := float(f - 1) / float(DungeonState.FLOOR_COUNT - 1)
			var sep_y  := margin + (prev_t + t) * 0.5 * avail_h
			_canvas.draw_line(Vector2(0, sep_y), Vector2(sz.x, sep_y), line_col, 1.0)

		var lbl := "Boss" if f == DungeonState.FLOOR_COUNT - 1 else "Andar %d" % (f + 1)
		_canvas.draw_string(font, Vector2(8.0, y + 5.0), lbl,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 10, lbl_col)

func _draw_connections() -> void:
	for node: DungeonState.RoomNode in _state.nodes:
		var from_pos := _node_center(node)
		for conn_id: int in node.connections:
			var target: DungeonState.RoomNode = _state.get_node_by_id(conn_id)
			if target == null:
				continue
			var to_pos := _node_center(target)
			var key    := "%d:%d" % [mini(node.id, conn_id), maxi(node.id, conn_id)]
			var segs: Array = _chain_map.get(key, [_CHAIN_MAIN])
			
			var should_glow := node.completed and _available_ids.has(target.id)
			if not should_glow:
				should_glow = target.completed and _available_ids.has(node.id)
			
			_draw_chain(from_pos, to_pos, segs, should_glow)

func _draw_chain(from: Vector2, to: Vector2, seg_indices: Array, apply_glow: bool = false) -> void:
	var diff   := to - from
	var length := diff.length()
	var angle  := diff.angle()
	if length < 1.0 or seg_indices.is_empty():
		return

	var seg_len := length / seg_indices.size()

	if apply_glow:
		var pulse := sin(_glow_time * CHAIN_GLOW_PULSE_SPEED) * 0.5 + 0.5
		var particle_alpha := CHAIN_GLOW_INTENSITY * (0.4 + pulse * 0.6)
		var particle_color := Color(
			CHAIN_GLOW_COLOR.r,
			CHAIN_GLOW_COLOR.g,
			CHAIN_GLOW_COLOR.b,
			particle_alpha
		)
		
		var half_particle := CHAIN_GLOW_PARTICLE_SIZE * 0.5
		var total_length := seg_len * seg_indices.size()
		var num_particles := maxi(1, int(total_length / CHAIN_GLOW_PARTICLE_SPACING))
		var particle_spacing := total_length / num_particles
		
		for p_idx in num_particles:
			var dist := particle_spacing * p_idx
			var particle_pos := from + diff.normalized() * dist
			
			var xform := Transform2D(0.0, particle_pos)
			_canvas.draw_set_transform_matrix(xform)
			
			_canvas.draw_texture_rect(
				CHAIN_GLOW_TEXTURE,
				Rect2(-half_particle, -half_particle, CHAIN_GLOW_PARTICLE_SIZE, CHAIN_GLOW_PARTICLE_SIZE),
				false,
				particle_color
			)

	for i in seg_indices.size():
		var tex: Texture2D = CHAIN_TEXTURES[seg_indices[i]]
		var origin := from + diff.normalized() * (seg_len * i)
		var xform  := Transform2D(angle, origin)
		var rect   := Rect2(0.0, -CHAIN_THICKNESS * 0.5, seg_len, CHAIN_THICKNESS)

		_canvas.draw_set_transform_matrix(xform)
		_canvas.draw_texture_rect(tex, rect, false)

	_canvas.draw_set_transform_matrix(Transform2D.IDENTITY)

func _draw_nodes() -> void:
	for node: DungeonState.RoomNode in _state.nodes:
		var pos     := _node_center(node)
		var is_boss := node.type == DungeonState.RoomType.BOSS
		var textures: Array = BOSS_NODE_TEXTURES if is_boss \
			else NODE_TEXTURES.get(NODE_TYPE_KEY.get(node.type, "battle"), NODE_TEXTURES["battle"])
		var nsize := NODE_SIZE_BOSS if is_boss else NODE_SIZE
		var half  := nsize * 0.5

		var tex_idx  := 0  
		var alpha    := 1.0

		if node.completed:
			tex_idx = 2    # Força estado permanente de "Pressed" nos já completados
		elif node.id == _selected_node_id:
			tex_idx = 2    
		elif node.id == _hovered_node_id:
			tex_idx = 1    

		var color := Color(1, 1, 1, alpha)

		_canvas.draw_texture_rect(textures[tex_idx],
			Rect2(pos - Vector2.ONE * half, Vector2.ONE * nsize),
			false, color)

		if not is_boss and NODE_ICONS.has(node.type):
			var icon: Texture2D = NODE_ICONS[node.type]
			var icon_half := NODE_ICON_SIZE * 0.5
			_canvas.draw_texture_rect(icon,
				Rect2(pos - Vector2.ONE * icon_half, Vector2.ONE * NODE_ICON_SIZE),
				false, color)

		if node.id == _selected_node_id and _available_ids.has(node.id) and not node.completed:
			_canvas.draw_arc(pos, half + 3.0, 0.0, TAU, 48,
				Color(0.90, 0.78, 0.20), 3.0)

# ======================================================
# KEYBOARD INPUT
# ======================================================
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	match (event as InputEventKey).keycode:
		KEY_LEFT, KEY_A:
			_move_kb_cursor(-1)
		KEY_RIGHT, KEY_D:
			_move_kb_cursor(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_on_enter_room()
		KEY_ESCAPE:
			_deselect_node()

func _move_kb_cursor(delta: int) -> void:
	if _available_ids.is_empty():
		return
	_kb_cursor = (_kb_cursor + delta + _available_ids.size()) % _available_ids.size()
	_select_node(_available_ids[_kb_cursor])

# ======================================================
# CANVAS — INPUT
# ======================================================
func _on_canvas_input(event: InputEvent) -> void:
	if _state == null:
		return

	var mm := event as InputEventMouseMotion
	if mm != null:
		var new_hover := _node_id_at(mm.position)
		if new_hover != _hovered_node_id:
			_hovered_node_id = new_hover
			_canvas.queue_redraw()
		return

	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return

	var hit_id := _node_id_at(mb.position)
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

func _node_id_at(pos: Vector2) -> int:
	for node: DungeonState.RoomNode in _state.nodes:
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
	_info_floor.text = "Boss" if node.floor_idx == DungeonState.FLOOR_COUNT - 1 \
		else "Andar %d" % (node.floor_idx + 1)
	if NODE_ICONS.has(node.type):
		_info_icon.texture = NODE_ICONS[node.type]
		_info_icon.visible = true
	else:
		_info_icon.visible = false
	_info_desc.text    = NODE_DESCRIPTIONS.get(node.type, "")
	_info_desc.visible = _info_desc.text != ""

	_enter_btn.visible = true
	
	# ── MODIFICAÇÃO DINÂMICA DO TEXTO E TEXTURA DO BOTÃO LATERAL ──
	if node.completed:
		if _enter_btn_label:
			_enter_btn_label.text = "Concluído" # ◄ Altera texto interno
		_enter_btn.disabled = true              # ◄ Ativa textura BTN_DISABLED automaticamente
	elif _available_ids.has(id):
		if _enter_btn_label:
			_enter_btn_label.text = "Entrar"    # Retorna para o padrão
		_enter_btn.disabled = false             # Ativa texturas normais de clique
	else:
		if _enter_btn_label:
			_enter_btn_label.text = "Entrar"    # Mantém texto, mas bloqueia
		_enter_btn.disabled = true              # Ativa textura BTN_DISABLED (inativo)
		
	_canvas.queue_redraw()

func _deselect_node() -> void:
	_selected_node_id  = -1
	_info_name.text    = "Selecione uma sala"
	_info_floor.text   = ""
	_info_icon.visible = false
	_info_desc.visible = false
	_info_desc.text    = ""
	_enter_btn.visible = false
	_canvas.queue_redraw()

func _refresh_available() -> void:
	_available_ids.clear()
	for n: DungeonState.RoomNode in _state.get_available_rooms():
		_available_ids.append(n.id)
	_available_ids.sort_custom(func(a: int, b: int) -> bool:
		var na := _state.get_node_by_id(a)
		var nb := _state.get_node_by_id(b)
		return na.position.x < nb.position.x
	)
	_kb_cursor = 0

func _auto_select_first() -> void:
	if not _available_ids.is_empty():
		_kb_cursor = 0
		_select_node(_available_ids[0])
	elif not _state.nodes.is_empty():
		_select_node(_state.nodes[0].id)

# ======================================================
# ACTIONS
# ======================================================
func _on_enter_room() -> void:
	if _selected_node_id < 0 or _state == null or not _available_ids.has(_selected_node_id):
		return
	
	var node: DungeonState.RoomNode = _state.get_node_by_id(_selected_node_id)
	if node == null or node.completed:
		return
		
	_state.enter_room(_selected_node_id)
	match node.type:
		DungeonState.RoomType.EVENT, DungeonState.RoomType.MYSTERY:
			SceneTransition.fade_to("res://ui/event_scene.tscn")
		_:
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
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color",        Color(0.90, 0.85, 0.75))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 2)
	lbl.add_theme_constant_override("shadow_offset_y", 2)
	btn.add_child(lbl)

	btn.pressed.connect(cb)
	return btn

func _refresh_party_list() -> void:
	if _party_list_container == null:
		return
		
	# Limpa a lista atual
	for child in _party_list_container.get_children():
		child.queue_free()
	
	# Verifica se há dados
	if BattleState.PLAYERS.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "Nenhum herói selecionado"
		empty_lbl.add_theme_font_size_override("font_size", 10)
		empty_lbl.add_theme_color_override("font_color", Color(0.65, 0.40, 0.40))
		_party_list_container.add_child(empty_lbl)
		return
	
	# Recria a lista com os dados atuais
	for p in BattleState.PLAYERS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		_party_list_container.add_child(row)

		var name_lbl := Label.new()
		name_lbl.text = p.get("name", "?")
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.88, 0.86, 0.78))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_lbl)

		var hp_val: int  = p.get("hp", 0)
		var hp_max: int  = p.get("max_hp", 1)
		var ratio: float = float(hp_val) / float(hp_max)
		var hp_color := Color(0.25, 0.80, 0.40)
		if ratio < 0.5:
			hp_color = Color(0.90, 0.65, 0.15)
		if ratio < 0.25:
			hp_color = Color(0.85, 0.25, 0.20)

		var hp_lbl := Label.new()
		hp_lbl.text = "%d / %d" % [hp_val, hp_max]
		hp_lbl.add_theme_font_size_override("font_size", 11)
		hp_lbl.add_theme_color_override("font_color", hp_color)
		row.add_child(hp_lbl)
