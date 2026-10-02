class_name TurnOrderBar
extends Control

signal slot_right_clicked(slot_index: int, global_mouse_pos: Vector2)

# ======================================================
# 🎨 ASSETS
# ======================================================
const PANEL_TEXTURE        := preload("res://assets/ui/panels/panel_turn_order_bar.png")
const SLOT_PLAYER_TEXTURE  := preload("res://assets/ui/turn_order/slot_player.png")
const SLOT_ENEMY_TEXTURE   := preload("res://assets/ui/turn_order/slot_enemy.png")
const SLOT_ACTIVE_TEXTURE  := preload("res://assets/ui/turn_order/slot_active.png")

# ──────────────────────────────────────────────────────
# 🔧 CONSTANTES DE AJUSTE FINO (MODIFIQUE AQUI!)
# ──────────────────────────────────────────────────────
# Margens internas da barra maior
const MARGIN_BAR_LEFT     := 30
const MARGIN_BAR_RIGHT    := 30
const MARGIN_BAR_TOP      := 15
const MARGIN_BAR_BOTTOM   := 8

# Margem de 4 pixels em cada lado para o retrato ficar recuado sob a moldura
const MARGIN_SLOT_LEFT    := 2
const MARGIN_SLOT_RIGHT   := 2
const MARGIN_SLOT_TOP     := 2
const MARGIN_SLOT_BOTTOM  := 2
# ──────────────────────────────────────────────────────

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE DE TAMANHOS
# ──────────────────────────────────────────────────────
const PANEL_PATCH    := 20
const SLOT_SIZE      := 52
const SLOT_GAP       := 30
const FONT_INITNUM   := 10
const INACTIVE_ALPHA := 0.55
# ──────────────────────────────────────────────────────

# ======================================================
# VARS
# ======================================================
var _hbox: HBoxContainer
var _panel_bg: NinePatchRect
var _margin_container: MarginContainer

# Set during refresh() so _build_slot() can read live enemy HP from the active battle.
var _state_ref: BattleState = null

const HP_BAR_HEIGHT := 6.0
const HP_NUM_FONT_SIZE := 9

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size.y = SLOT_SIZE + MARGIN_BAR_TOP + MARGIN_BAR_BOTTOM
	_build_panel()

# ======================================================
# BUILD — PANEL BG + HBOX
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

	_margin_container = MarginContainer.new()
	_margin_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_margin_container.add_theme_constant_override("margin_left",   MARGIN_BAR_LEFT)
	_margin_container.add_theme_constant_override("margin_right",  MARGIN_BAR_RIGHT)
	_margin_container.add_theme_constant_override("margin_top",    MARGIN_BAR_TOP)
	_margin_container.add_theme_constant_override("margin_bottom", MARGIN_BAR_BOTTOM)
	add_child(_margin_container)

	_hbox = HBoxContainer.new()
	_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	_hbox.add_theme_constant_override("separation", SLOT_GAP)
	_hbox.mouse_filter = Control.MOUSE_FILTER_STOP
	_hbox.gui_input.connect(_on_hbox_gui_input)
	_margin_container.add_child(_hbox)

# ======================================================
# PUBLIC API
# ======================================================
func refresh(queue: Array, active_index: int, state: BattleState = null) -> void:
	_state_ref = state
	for child in _hbox.get_children():
		_hbox.remove_child(child)
		child.queue_free()

	# Skip dead combatants so they drop out of the turn order. slot_index stays the
	# original queue index (used for HP lookup); is_active still matches the active
	# combatant since active_index is also a queue index.
	var n: int = 0
	for i in queue.size():
		if state != null and state.dead_indices.has(i):
			continue
		_hbox.add_child(_build_slot(queue[i], i == active_index, i))
		n += 1

	var final_width: int = n * SLOT_SIZE + max(0, n - 1) * SLOT_GAP + MARGIN_BAR_LEFT + MARGIN_BAR_RIGHT
	custom_minimum_size.x = final_width
	size.x = final_width

# ======================================================
# BUILD — SLOT
# ======================================================
func _build_slot(combatant: Dictionary, is_active: bool, slot_index: int) -> Control:
	var root := Control.new()
	# 🛑 O SLOT SÓ OCUPA O TAMANHO REAL DA ÁREA ÚTIL (Ex: 52x52)
	# O painel de fundo vai ler este tamanho exato, eliminando a "gordura" vertical!
	root.custom_minimum_size = Vector2(SLOT_SIZE, SLOT_SIZE)
	root.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	if not is_active:
		root.modulate.a = INACTIVE_ALPHA

	# 1. CAMADA DE TRÁS: MarginContainer para o Retrato (Aplica as margens internas na área útil)
	var slot_margin := MarginContainer.new()
	slot_margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot_margin.add_theme_constant_override("margin_left",   MARGIN_SLOT_LEFT)
	slot_margin.add_theme_constant_override("margin_right",  MARGIN_SLOT_RIGHT)
	slot_margin.add_theme_constant_override("margin_top",    MARGIN_SLOT_TOP)
	slot_margin.add_theme_constant_override("margin_bottom", MARGIN_SLOT_BOTTOM)
	slot_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(slot_margin)

	var portrait_node: Control = null
	var portrait_tex := _get_combatant_portrait(combatant)
	if portrait_tex:
		var portrait_rect := TextureRect.new()
		portrait_rect.texture      = portrait_tex
		portrait_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_SCALE
		portrait_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_margin.add_child(portrait_rect)
		portrait_node = portrait_rect
	else:
		var main_lbl := Label.new()
		main_lbl.text                 = combatant["name"].substr(0, 2).to_upper()
		main_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		main_lbl.add_theme_font_size_override("font_size", 12)
		main_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		main_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_margin.add_child(main_lbl)
		portrait_node = main_lbl

	# 2. CAMADA DA FRENTE: Moldura Gráfica Extensível (Ignora o limite do pai)
	var slot_tex_rect := TextureRect.new()
	slot_tex_rect.texture      = SLOT_ACTIVE_TEXTURE if is_active \
		else (SLOT_PLAYER_TEXTURE if combatant["is_player"] else SLOT_ENEMY_TEXTURE)
	slot_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	
	# 🛠️ A MÁGICA ACONTECE AQUI:
	# Primeiro ancoramos o rect para ocupar todo o espaço do pai (0,0 até 52,52)
	slot_tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	
	# Agora aplicamos offsets para empurrar as bordas visuais para fora do nó pai de 52x52.
	# Exemplo: Se os adornos do topo e de baixo ocupam 6px extras cada, colocamos -6 no topo e 6 embaixo.
	# Modifique estes 4 valores abaixo até a moldura abraçar os adornos perfeitamente!
	slot_tex_rect.offset_left   = -8   # Se tiver adornos nas laterais, use valores negativos (ex: -4)
	slot_tex_rect.offset_right  = 8   # Se tiver adornos nas laterais, use valores positivos (ex: 4)
	slot_tex_rect.offset_top    = -14  # 👈 Estica para cima (Sobe além do limite do slot)
	slot_tex_rect.offset_bottom = 12   # 👈 Estica para baixo (Desce além do limite do slot)
	
	slot_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(slot_tex_rect)

	# 3. OVERLAY ABSOLUTO: Número de iniciativa
	var num_lbl := Label.new()
	num_lbl.text    = str(slot_index + 1)
	num_lbl.add_theme_font_size_override("font_size", FONT_INITNUM)
	num_lbl.modulate      = Color(1, 1, 1, 0.7)
	num_lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	num_lbl.offset_left   = -16.0
	num_lbl.offset_top    = -14.0
	num_lbl.offset_right  = -2.0
	num_lbl.offset_bottom = -2.0
	num_lbl.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	root.add_child(num_lbl)

	# 4. HP BAR — colored bar pinned to the bottom of the slot, over the frame.
	var hp_vals := _hp_values(combatant, slot_index)
	var ratio := clampf(float(hp_vals.x) / maxf(float(hp_vals.y), 1.0), 0.0, 1.0)

	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.4)
	hp_bg.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hp_bg.offset_top = -HP_BAR_HEIGHT
	hp_bg.offset_bottom = 0.0
	hp_bg.offset_left = 0.0
	hp_bg.offset_right = 0.0
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_bg)

	var hp_fill := ColorRect.new()
	hp_fill.color = _hp_color(ratio)
	hp_fill.anchor_left = 0.0
	hp_fill.anchor_right = ratio
	hp_fill.anchor_top = 1.0
	hp_fill.anchor_bottom = 1.0
	hp_fill.offset_left = 0.0
	hp_fill.offset_right = 0.0
	hp_fill.offset_top = -HP_BAR_HEIGHT
	hp_fill.offset_bottom = 0.0
	hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_fill)

	# 5. HP NUMBER — "current/max" centered just below the HP bar.
	var hp_num := Label.new()
	hp_num.text = "%d/%d" % [hp_vals.x, hp_vals.y]
	hp_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_num.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	hp_num.add_theme_font_size_override("font_size", HP_NUM_FONT_SIZE)
	hp_num.add_theme_color_override("font_color", Color.WHITE)
	hp_num.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	hp_num.add_theme_constant_override("outline_size", 3)
	hp_num.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	hp_num.offset_top    = 0.0                       # starts at the slot's bottom edge (below the bar)
	hp_num.offset_bottom = HP_NUM_FONT_SIZE + 4.0    # extends into the frame's lower adornment
	hp_num.offset_left   = -4.0
	hp_num.offset_right  = 4.0
	hp_num.mouse_filter  = Control.MOUSE_FILTER_IGNORE
	root.add_child(hp_num)

	# 6. DOWNED — retrato escurecido + 3 círculos de sucesso / 3 de falha (estilo BG3).
	if _state_ref != null and _state_ref.is_downed(slot_index):
		if portrait_node != null:
			portrait_node.modulate = Color(0.4, 0.4, 0.4)

		var status: Dictionary = {}
		if slot_index < _state_ref.combatant_statuses.size():
			status = _state_ref.combatant_statuses[slot_index]
		var s_cnt: int = status.get("death_saves_success", 0)
		var f_cnt: int = status.get("death_saves_failure", 0)

		var ds_row := HBoxContainer.new()
		ds_row.add_theme_constant_override("separation", 1)
		ds_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
		ds_row.offset_top = 2.0
		ds_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		for j in 3:
			var dot := Label.new()
			dot.text = "●" if j < s_cnt else "○"
			dot.add_theme_font_size_override("font_size", 8)
			dot.add_theme_color_override("font_color",
				Color(0.2, 0.9, 0.2) if j < s_cnt else Color(0.4, 0.4, 0.4))
			dot.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			dot.add_theme_constant_override("outline_size", 2)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ds_row.add_child(dot)
		for j in 3:
			var dot := Label.new()
			dot.text = "●" if j < f_cnt else "○"
			dot.add_theme_font_size_override("font_size", 8)
			dot.add_theme_color_override("font_color",
				Color(0.9, 0.15, 0.15) if j < f_cnt else Color(0.4, 0.4, 0.4))
			dot.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			dot.add_theme_constant_override("outline_size", 2)
			dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ds_row.add_child(dot)
		root.add_child(ds_row)

	root.mouse_filter = Control.MOUSE_FILTER_PASS

	# Store the real TURN_QUEUE index so right-click examine resolves the correct
	# combatant even after deaths remove slots and visual order diverges from queue order.
	root.set_meta("queue_index", slot_index)

	return root

# ======================================================
# HELPER — HP BAR
# ======================================================
# Returns the combatant's (current_hp, max_hp).
# Players read static BattleState.PLAYERS; enemies read live HP from the active
# BattleState (_state_ref) and max HP from EnemyData. Falls back to a full bar
# when no state is available (e.g. UI smoke tests).
func _hp_values(combatant: Dictionary, slot_index: int) -> Vector2i:
	var cur := 0
	var mx := 1
	if combatant.get("is_player", false):
		for player: Dictionary in BattleState.PLAYERS:
			if player.get("name") == combatant.get("name", ""):
				cur = int(player.get("hp", 0))
				mx  = int(player.get("max_hp", 1))
				break
	else:
		var nm: String = combatant.get("name", "")
		if _state_ref != null:
			cur = int(_state_ref.enemy_hp.get(nm, 0))
			mx  = maxi(1, _state_ref.get_enemy_max_hp(slot_index))
		else:
			var etype: String = combatant.get("type", "")
			if BattleState.ALL_ENEMIES.has(etype):
				mx  = int(BattleState.ALL_ENEMIES[etype].max_hp)
				cur = mx
	return Vector2i(cur, maxi(mx, 1))

# Returns the combatant's current HP as a fraction [0,1].
func _hp_ratio(combatant: Dictionary, slot_index: int) -> float:
	var v := _hp_values(combatant, slot_index)
	return clampf(float(v.x) / maxf(float(v.y), 1.0), 0.0, 1.0)

func _hp_color(ratio: float) -> Color:
	if ratio > 0.5:
		return Color(0.2, 0.85, 0.2)   # green
	elif ratio >= 0.2:
		return Color(0.95, 0.6, 0.1)   # orange
	return Color(0.9, 0.15, 0.15)      # red

# ======================================================
# INPUT — RIGHT-CLICK ON SLOT
# ======================================================
func _on_hbox_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if mb.button_index != MOUSE_BUTTON_RIGHT or not mb.pressed:
		return
	for i in _hbox.get_child_count():
		var child := _hbox.get_child(i) as Control
		if child == null:
			continue
		if child.get_global_rect().has_point(mb.global_position):
			var queue_idx: int = child.get_meta("queue_index", i)
			slot_right_clicked.emit(queue_idx, mb.global_position)
			get_viewport().set_input_as_handled()
			return

# ======================================================
# HELPER — PORTRAIT
# ======================================================
func _get_combatant_portrait(combatant: Dictionary) -> Texture2D:
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
