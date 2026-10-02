class_name BattleScene
extends Control

# ======================================================
# 🎨 ASSETS
# ======================================================
const BG_TEXTURE := preload("res://assets/ui/backgrounds/battle_bg.png")

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE DE TAMANHOS
# ──────────────────────────────────────────────────────
const HUD_HEIGHT       := 200   # altura default da HUD (rows=2); vira dinâmica via _hud_h
const STATUS_WIDTH     := 280
var _hud_h: int = HUD_HEIGHT     # altura viva da HUD (acompanha as linhas da ActionPanel)
# ──────────────────────────────────────────────────────

# ======================================================
# VARS
# ======================================================
var _state: BattleState
var _turn_bar: TurnOrderBar
var _battle_area: BattleArea
var _status_panel: StatusPanel
var _action_panel: ActionPanel
var _log_panel: CombatLogPanel
var _log_toggle_btn: Button
var _end_turn_btn: Button
var _result_screen: BattleResultScreen
var _pause_menu: PauseMenu
var _turn_transition: TurnTransitionLayer
var _examine_panel: ExaminePanel
var _context_menu:  ContextMenu
var _action_tooltip: ActionTooltipPanel
var _enemy_info_panel: EnemyInfoPanel
var _animating: bool = false
var _camera_shake: CameraShake
var _screen_flash: ScreenFlash
var _pending_end_turn_action: ActionData = null
var _pending_item: Dictionary = {}
var _pending_attack_slot_level: int = 0
var _pending_attack_ki_cost: int = 0
var _pending_attack_action: ActionData = null
# Reactions (BG3): fila de reações pendentes + flag de pausa para o popup "Ask".
var _reaction_popup: ReactionPopup = null
var _reaction_pending: bool = false
var _pending_reaction_queue: Array[Dictionary] = []

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0

	BattleState.setup_enemies_for_room(_get_current_room_type())
	_state = BattleState.new()

	_build_background()
	_build_layout()
	_build_overlays()
	_connect_signals()
	_initialize_state()
	_refresh_ui()
	
	# Força o background para o índice 0
	var bg = get_child(0)
	if bg is TextureRect and bg.texture == BG_TEXTURE:
		move_child(bg, 0)

	_camera_shake = CameraShake.new()
	_camera_shake.battle_area = _battle_area   # ← _battle_area já existe aqui
	add_child(_camera_shake)
	
	_screen_flash = ScreenFlash.new()
	add_child(_screen_flash)
	_screen_flash.setup()

	_battle_area.inject_vfx_references(_camera_shake, _screen_flash)

	# Com a iniciativa rolada, o primeiro combatente pode ser um inimigo.
	# Nesse caso dispara o turno dele (senão o jogo ficaria parado esperando
	# input em um turno inimigo). Feito ao final do _ready para garantir que
	# camera shake / screen flash já estão prontos para a animação de ataque.
	if _state.current_state == BattleState.State.ENEMY_TURN:
		_after_advance()

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
# BUILD — LAYOUT (turn bar + battle area + hud)
# ======================================================
func _build_layout() -> void:
	var root_vbox := VBoxContainer.new()
	root_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root_vbox)

	_turn_bar = TurnOrderBar.new()
	root_vbox.add_child(_turn_bar)

	_battle_area = BattleArea.new()
	_battle_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_battle_area.clip_contents       = true
	root_vbox.add_child(_battle_area)

	_build_hud(root_vbox)

# ======================================================
# BUILD — HUD (status + action + context + log)
# ======================================================
func _build_hud(parent: Control) -> void:
	# HUD sem altura fixa: dimensiona pela ActionPanel (cresce para CIMA, pois a
	# BattleArea acima cede espaço). custom_minimum_size.y NÃO é setado aqui.
	var hud := HBoxContainer.new()
	parent.add_child(hud)

	_status_panel = StatusPanel.new()
	_status_panel.custom_minimum_size.x = STATUS_WIDTH
	_status_panel.concentration_cancel_requested.connect(_on_concentration_cancel)
	hud.add_child(_status_panel)

	_action_panel = ActionPanel.new()
	_action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_panel.custom_minimum_size.y = _action_panel.content_height()
	_action_panel.content_height_changed.connect(_on_hud_height_changed)
	hud.add_child(_action_panel)

	# ── End Turn: botão circular verde, isolado à direita do painel de ações ──
	_end_turn_btn = Button.new()
	_end_turn_btn.custom_minimum_size = Vector2(80, 80)
	_end_turn_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_end_turn_btn.text = "⏳\nFIM"
	_end_turn_btn.add_theme_font_size_override("font_size", 9)
	var sb_n := StyleBoxFlat.new()
	sb_n.bg_color = Color(0.15, 0.50, 0.20)
	sb_n.corner_radius_top_left     = 40
	sb_n.corner_radius_top_right    = 40
	sb_n.corner_radius_bottom_left  = 40
	sb_n.corner_radius_bottom_right = 40
	_end_turn_btn.add_theme_stylebox_override("normal", sb_n)
	var sb_h: StyleBoxFlat = sb_n.duplicate()
	sb_h.bg_color = Color(0.20, 0.65, 0.25)
	_end_turn_btn.add_theme_stylebox_override("hover", sb_h)
	var sb_p: StyleBoxFlat = sb_n.duplicate()
	sb_p.bg_color = Color(0.10, 0.35, 0.14)
	_end_turn_btn.add_theme_stylebox_override("pressed", sb_p)
	_end_turn_btn.pressed.connect(_on_end_turn_pressed)
	hud.add_child(_end_turn_btn)

	# ── Combat log: painel flutuante colapsável (não ocupa espaço no HUD) ──
	_log_panel = CombatLogPanel.new()
	_log_panel.set_anchor_and_offset(SIDE_RIGHT,  1.0, -10)
	_log_panel.set_anchor_and_offset(SIDE_LEFT,   1.0, -220)
	_log_panel.hide()
	add_child(_log_panel)

	# Botão de toggle "💬" fixado no canto inferior direito, acima do HUD
	_log_toggle_btn = Button.new()
	_log_toggle_btn.text = "💬"
	_log_toggle_btn.custom_minimum_size = Vector2(32, 32)
	var sb_log := StyleBoxFlat.new()
	sb_log.corner_radius_top_left     = 16
	sb_log.corner_radius_top_right    = 16
	sb_log.corner_radius_bottom_left  = 16
	sb_log.corner_radius_bottom_right = 16
	sb_log.bg_color = Color(0.12, 0.12, 0.18, 0.90)
	_log_toggle_btn.add_theme_stylebox_override("normal", sb_log)
	_log_toggle_btn.add_theme_font_size_override("font_size", 14)
	_log_toggle_btn.set_anchor_and_offset(SIDE_RIGHT,  1.0, -12)
	_log_toggle_btn.set_anchor_and_offset(SIDE_LEFT,   1.0, -46)
	_log_toggle_btn.pressed.connect(func() -> void:
		if _log_panel.visible:
			_log_panel.hide()
		else:
			_log_panel.show()
			_log_panel.refresh()
	)
	add_child(_log_toggle_btn)
	_position_hud_overlays()

# Reposiciona os overlays do log (painel + toggle) logo acima da HUD, acompanhando
# a altura dinâmica `_hud_h` (a HUD cresce para cima ao adicionar linhas de grid).
func _position_hud_overlays() -> void:
	if _log_panel == null or _log_toggle_btn == null:
		return
	_log_panel.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -_hud_h - 10)
	_log_panel.set_anchor_and_offset(SIDE_TOP,    1.0, -_hud_h - 300)
	_log_toggle_btn.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -_hud_h - 12)
	_log_toggle_btn.set_anchor_and_offset(SIDE_TOP,    1.0, -_hud_h - 46)

func _on_hud_height_changed(h: int) -> void:
	_hud_h = h
	_position_hud_overlays()

# ======================================================
# BUILD — OVERLAYS (result screen + pause menu)
# ======================================================
func _build_overlays() -> void:
	_result_screen = BattleResultScreen.new()
	add_child(_result_screen)

	_pause_menu = PauseMenu.new()
	add_child(_pause_menu)

	_turn_transition = TurnTransitionLayer.new()
	add_child(_turn_transition)
	_examine_panel = ExaminePanel.new()
	add_child(_examine_panel)

	_action_tooltip = ActionTooltipPanel.new()
	add_child(_action_tooltip)

	_enemy_info_panel = EnemyInfoPanel.new()
	add_child(_enemy_info_panel)

	_reaction_popup = ReactionPopup.new()
	add_child(_reaction_popup)

# ======================================================
# CONNECT SIGNALS
# ======================================================
func _connect_signals() -> void:
	_result_screen.continue_requested.connect(_on_continue_requested)
	_result_screen.restart_requested.connect(_on_restart_requested)

	_pause_menu.resume_requested.connect(func() -> void: _pause_menu.hide_menu())
	_pause_menu.menu_requested.connect(_on_pause_to_menu)

	_action_panel.grid_action_clicked.connect(_on_grid_action_clicked)
	_action_panel.grid_action_hovered.connect(_on_action_hovered)

	_battle_area.tile_clicked.connect(_on_tile_clicked)
	_battle_area.tile_hovered.connect(_on_tile_hovered)
	_battle_area.attack_hover_changed.connect(_on_attack_hover_changed)

	_action_panel.cancel_action.connect(func():
		_pending_attack_slot_level = 0  # Cancela o slot que não foi gasto
		_pending_attack_ki_cost = 0     # Cancela o Ki que não foi gasto
		_pending_end_turn_action = null
		_pending_attack_action = null
		_pending_item = {}
		if _state.current_state == BattleState.State.MOVE_MODE:
			_state.cancel_move()
		elif _state.current_state == BattleState.State.ATTACK_MODE:
			_state.cancel_attack()
		_action_panel.hide_action_bar()
		_refresh_ui()
	)
	_action_panel.confirm_action.connect(func():
		if _pending_end_turn_action != null:
			_execute_end_turn_action(_pending_end_turn_action)
			_pending_end_turn_action = null
			_action_panel.hide_action_bar()
		elif not _pending_item.is_empty():
			_state.use_item(_pending_item)
			_show_floater_if_needed()
			_pending_item = {}
			_action_panel.hide_action_bar()
		_refresh_ui()
	)
	
	_battle_area.resized.connect(func():
		_refresh_ui()
	)
	_turn_bar.slot_right_clicked.connect(_on_portrait_right_clicked)

# ======================================================
# HELPERS — ROOM TYPE
# ======================================================
func _get_current_room_type() -> int:
	if DungeonState.current_run == null:
		return DungeonState.RoomType.BATTLE
	var node: DungeonState.RoomNode = DungeonState.current_run.get_node_by_id(
		DungeonState.current_run.current_node_id)
	if node == null:
		return DungeonState.RoomType.BATTLE
	return node.type

# ======================================================
# INITIALIZE STATE
# ======================================================
func _initialize_state() -> void:
	var map_gen  := MapGenerator.new()
	var map_data := map_gen.generate()
	_state.roll_initiative()   # ordena TURN_QUEUE antes de setup() posicionar
	_state.setup(map_data)
	_state.begin_turn()        # inicializa o turno do 1º da iniciativa

	_battle_area.setup(_state)
	_battle_area.set_void_theme(VoidTheme.ThemeType.ABYSS)

	_action_panel.setup(_state)
	_status_panel.setup(_state)
	_log_panel.setup(_state)

# ======================================================
# REFRESH UI
# ======================================================
func _refresh_ui() -> void:
	if not is_inside_tree() or _state == null:
		return

	if not _animating:
		_battle_area._combatant_layer.sync_visual_positions(
			_state, 
			_battle_area._visual_positions, 
			_battle_area._get_offset()
		)
		_battle_area._combatant_layer.update_all_combatant_ui(_state)

	_turn_bar.refresh(BattleState.TURN_QUEUE, _state.active_index, _state)
	_battle_area.refresh(_state.active_index)
	_action_panel.refresh()
	_status_panel.refresh(_state.active_index)  # 👈 ISSO que atualiza os portraits!
	_log_panel.refresh()
	_update_attack_outlines()

# ======================================================
# INPUT
# ======================================================
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	var key := (event as InputEventKey).keycode

	# Enquanto um popup de reação aguarda decisão, ele consome o input (tem seu
	# próprio _input). BattleScene não processa nada até a reação ser resolvida.
	if _reaction_pending:
		return

	if _pause_menu.visible:
		if key == KEY_ESCAPE or key == KEY_P:
			_pause_menu.hide_menu()
			get_viewport().set_input_as_handled()
		return

	if key == KEY_P:
		if not _animating and _state.battle_result.is_empty():
			_pause_menu.show_menu()
		get_viewport().set_input_as_handled()
		return

	if _animating:
		return

	if _action_panel._action_bar_active:
		_handle_action_bar(event as InputEventKey)
		return

	match _state.current_state:
		BattleState.State.PLAYER_TURN:  _handle_player_turn(event as InputEventKey)
		BattleState.State.MOVE_MODE:    _handle_move_mode(event as InputEventKey)
		BattleState.State.ATTACK_MODE:  _handle_attack_mode(event as InputEventKey)

# ======================================================
# INPUT — PLAYER TURN
# ======================================================
func _handle_player_turn(event: InputEventKey) -> void:
	match event.keycode:
		KEY_UP, KEY_W, KEY_Q:    _state.move_tab(-1)
		KEY_DOWN, KEY_S, KEY_E:  _state.move_tab(1)
		KEY_LEFT, KEY_A:     _state.move_cursor_tab(-1)
		KEY_RIGHT, KEY_D:    _state.move_cursor_tab(1)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			_state.cursor_position = event.keycode - KEY_1
			_execute_current_item()
			get_viewport().set_input_as_handled()
			return
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_execute_current_item()
			get_viewport().set_input_as_handled()
			return
		KEY_ESCAPE:
			if _state.has_attacked:
				_state.cancel_confirmed_attack()
			elif _state.can_undo_move():
				if _state.cancel_confirmed_move():
					_battle_area._combatant_layer.sync_visual_positions(
						_state, 
						_battle_area._visual_positions, 
						_battle_area._get_offset()
					)
			elif _state.battle_result.is_empty():
				_pause_menu.show_menu()
				get_viewport().set_input_as_handled()
				return
	_refresh_ui()

# ======================================================
# INPUT — MOVE MODE
# ======================================================
func _handle_move_mode(event: InputEventKey) -> void:
	match event.keycode:
		KEY_UP, KEY_W:    _state.move_cursor_grid(Vector2i( 0, -1))
		KEY_DOWN, KEY_S:  _state.move_cursor_grid(Vector2i( 0,  1))
		KEY_LEFT, KEY_A:  _state.move_cursor_grid(Vector2i(-1,  0))
		KEY_RIGHT, KEY_D: _state.move_cursor_grid(Vector2i( 1,  0))
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_execute_confirm_move()
			return
		KEY_ESCAPE: _state.cancel_move()
	_refresh_ui()

# ======================================================
# INPUT — ATTACK MODE
# ======================================================
func _handle_attack_mode(event: InputEventKey) -> void:
	if _state.attack_tile_mode:
		# Mira de AoE em ponto: setas movem o cursor de tile livre no alcance.
		match event.keycode:
			KEY_UP, KEY_W:    _state.move_attack_tile_cursor(Vector2i( 0, -1))
			KEY_DOWN, KEY_S:  _state.move_attack_tile_cursor(Vector2i( 0,  1))
			KEY_LEFT, KEY_A:  _state.move_attack_tile_cursor(Vector2i(-1,  0))
			KEY_RIGHT, KEY_D: _state.move_attack_tile_cursor(Vector2i( 1,  0))
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				_execute_confirm_attack()
				return
			KEY_ESCAPE:
				_state.cancel_attack()
				_pending_attack_action = null
		_refresh_ui()
		_update_attack_outlines()
		return
	match event.keycode:
		KEY_LEFT, KEY_UP, KEY_A, KEY_W:    _state.cycle_attack_target(-1)
		KEY_RIGHT, KEY_DOWN, KEY_D, KEY_S: _state.cycle_attack_target(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_execute_confirm_attack()
			return
		KEY_ESCAPE:
			_state.cancel_attack()
			_pending_attack_action = null
	_refresh_ui()
	_update_attack_outlines()

func _handle_action_bar(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ESCAPE:
			_action_panel._on_cancel_action()
		KEY_LEFT, KEY_A:
			if _action_panel._confirm_btn.visible:
				_action_panel._confirm_btn.grab_focus()
			_action_panel._update_button_focus()
		KEY_RIGHT, KEY_D:
			_action_panel._back_btn.grab_focus()
			_action_panel._update_button_focus()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _action_panel._confirm_btn.has_focus():
				_action_panel._on_confirm_action()
			else:
				if _action_panel._confirm_btn.visible:
					_action_panel._on_confirm_action()
				else:
					_action_panel._on_cancel_action()

# ======================================================
# EXECUTE — CURRENT ITEM
# ======================================================
func _execute_current_item() -> void:
	var items: Array = _state.get_active_tab_items()
	var item = items[_state.cursor_position] if _state.cursor_position < items.size() else null
	if item == null or not _state.is_item_available(item):
		_refresh_ui()
		return
	_begin_item(item)

# Inicia uma acao/item ja resolvido (vindo do grid ou do teclado).
func _begin_item(item) -> void:
	if item is ActionData:
		var action := item as ActionData
		match action.action_type:
			ActionData.Type.MOVE:
				_execute_action(action)
			ActionData.Type.ATTACK:
				_execute_action(action)
			ActionData.Type.DASH:
				# Dash aplica na hora: dobra o movimento e gasta a Action,
				# sem entrar em modo de selecao de alvo.
				_state.apply_dash()
				_refresh_ui()
			ActionData.Type.END_TURN:
				var desc := ""
				if item is AcaoEsperar:
					desc = "Passa o turno"
				elif item is AcaoFugir:
					desc = "Tenta fugir da batalha"
				else:
					desc = action.label
				_action_panel.show_action_bar(action.label, desc, true)
				_pending_end_turn_action = action
	elif item is Dictionary:
		var desc := ""
		if item.has("heal"):
			desc = "Restaura %d HP" % item["heal"]
		elif item.has("spell_slot_restore"):
			desc = "Restaura 1 slot de %dº nível" % item["spell_slot_restore"]
		_action_panel.show_action_bar(item.get("label", "Item"), desc, true)
		_pending_item = item

func _execute_action(action: ActionData) -> void:
	match action.action_type:
		ActionData.Type.MOVE:
			_state.enter_move_mode()
			_refresh_ui()

		ActionData.Type.ATTACK:
			_pending_attack_slot_level = action.spell_slot_level
			_pending_attack_ki_cost = action.ki_cost
			_action_panel.set_pending_attack(action.label, action.targets_allies)
			_pending_attack_action = action
			_state._current_action = action
			_state.enter_attack_mode(
				action.attack_range, action.targets_allies,
				action.proj_color, action.self_target,
				action.aoe_radius, action.bonus_action)
			# Ranged sem linha de visão até nenhum alvo: avisa e volta ao neutro.
			if action.attack_range > 1 and _state.current_state == BattleState.State.ATTACK_MODE \
					and not _state.attack_tile_mode and not action.self_target \
					and not action.targets_allies and _state.attack_target_indices.is_empty():
				_state.cancel_attack()
				_pending_attack_action = null
				_state._log("Sem linha de visão até um alvo — reposicione para abrir o ângulo.", "miss")
			_refresh_ui()

		ActionData.Type.END_TURN:
			_execute_end_turn_action(action)

func _execute_end_turn_action(item: ActionData) -> void:
	var pidx: int = _state.get_active_player_index()

	# Desengajar NÃO encerra o turno — apenas marca o flag e gasta a ação principal,
	# permitindo que o jogador se mova em seguida sem sofrer Ataque de Oportunidade.
	if item is AcaoDesengajar:
		_state.apply_disengage(_state.active_index)
		_refresh_ui()
		return

	# Esconder (Hide): gasta a Ação principal, aplica Oculto, NÃO encerra o turno.
	if item is AcaoEsconder:
		_state.resolve_hide(_state.active_index)
		_state.has_attacked = true
		_refresh_ui()
		return

	# Mergulhar (Dip): gasta a Ação Bônus, reveste a arma, NÃO encerra o turno.
	if item is AcaoDip:
		_state.resolve_dip(_state.active_index)
		_state.has_used_bonus_action = true
		_refresh_ui()
		return

	if item is SkillPassoVento:
		if pidx >= 0:
			var p: Dictionary = BattleState.PLAYERS[pidx]
			if p.get("ki", 0) >= item.ki_cost:
				p["ki"] -= item.ki_cost
				_state.refill_move_points()
				_state._log("Monge usa Passo do Vento!", "status")
			else:
				_state._log("Ki insuficiente!", "status")
		_refresh_ui()
		return

	if item is AcaoEsperar:
		if pidx >= 0 and BattleState.PLAYERS[pidx]["class"] == "Rogue":
			_state.apply_furtivo_status(pidx)
	elif item is SkillSegundoVento:
		if pidx >= 0 and item.pp > 0:
			item.pp -= 1
			var p: Dictionary = BattleState.PLAYERS[pidx]
			p["hp"] = mini(p["hp"] + 15, p["max_hp"])
			_state._log("%s usa Segundo Vento! +15 HP" % BattleState.PLAYERS[pidx]["name"], "status")
	_state.advance_turn()
	_after_advance()

# ======================================================
# REACTIONS — sequenciador de popups (estilo BG3)
# ======================================================

# Processa a fila de reações pendentes uma por vez. Reações de inimigos ou com
# Ask=off disparam automaticamente; as demais mostram o popup e aguardam decisão.
# Quando a fila esvazia, chama `done`.
func _process_next_reaction(done: Callable) -> void:
	if _pending_reaction_queue.is_empty():
		done.call()
		return
	# Agrupa todas as entradas do MESMO reator (mesmo momento de gatilho) num único
	# popup, no estilo BG3. A fila é drenada por evento, então todas pertencem ao
	# mesmo gatilho.
	var reactor_idx: int = _pending_reaction_queue[0]["reactor_idx"]
	var group: Array[Dictionary] = []
	var rest: Array[Dictionary] = []
	for e in _pending_reaction_queue:
		if e["reactor_idx"] == reactor_idx:
			group.append(e)
		else:
			rest.append(e)
	_pending_reaction_queue = rest

	# Filtra entradas inválidas: as que consomem reação precisam dela disponível.
	# As "livres" (Divine Smite) permanecem mesmo sem reação.
	var valid: Array = []
	for e in group:
		var needs_reaction: bool = e.get("consumes_reaction", true)
		if needs_reaction and not _state.has_reaction_available(reactor_idx):
			continue
		valid.append(e)
	if valid.is_empty():
		_process_next_reaction(done)
		return

	var is_enemy: bool = not BattleState.TURN_QUEUE[reactor_idx]["is_player"]
	if is_enemy:
		# Inimigo reage automaticamente (sem popup) — executa todas em sequência.
		_execute_reaction_group(valid, func() -> void: _process_next_reaction(done))
		return

	# Jogador: monta as opções e mostra o popup BG3.
	var options: Array = []
	for e in valid:
		options.append({
			"trigger_type": e.get("trigger_type", ""),
			"label": e.get("reaction_label", "Reação"),
			"cost_text": e.get("cost_text", ""),
			"portrait": e.get("portrait", null),
		})
	var context_text: String = str(valid[0].get("context_text", valid[0].get("reaction_desc", "")))
	_reaction_pending = true
	_reaction_popup.show_for(context_text, options, func(chosen: Array) -> void:
		_reaction_pending = false
		# Mantém as entradas escolhidas, na ordem do grupo.
		var picked: Array = []
		for e in valid:
			if chosen.has(e.get("trigger_type", "")):
				picked.append(e)
		_execute_reaction_group(picked, func() -> void: _process_next_reaction(done))
	)

# Executa uma lista de reações em sequência (encadeando os callbacks) e chama done.
func _execute_reaction_group(entries: Array, done: Callable) -> void:
	if entries.is_empty():
		done.call()
		return
	var entry: Dictionary = entries[0]
	var tail: Array = entries.slice(1)
	_execute_reaction_entry(entry, func() -> void: _execute_reaction_group(tail, done))

# Executa o efeito de UMA reação e chama `done` ao terminar (após animação).
func _execute_reaction_entry(entry: Dictionary, done: Callable) -> void:
	var trigger: String = str(entry.get("trigger_type", ""))
	match trigger:
		"OA":
			var reactor: int = entry["reactor_idx"]
			var target: int  = entry["target_idx"]
			_state.apply_opportunity_attack(reactor, target)
			_animating = true
			var tpos: Vector2i = _state.combatant_positions[target]
			_play_attack_animation(reactor, tpos, ActionData.new(), 0, false, false,
				func() -> void:
					_animating = false
					_show_floater_if_needed()
					_process_pending_deaths()
					done.call()
			)
		"uncanny_dodge":
			_state.apply_uncanny_dodge(entry["reactor_idx"])
			_show_floater_if_needed()
			done.call()
		"deflect_missiles":
			var final_dmg: int = _state.apply_deflect_missiles(entry["reactor_idx"])
			_show_floater_if_needed()
			if final_dmg == 0:
				# Dano zerado: oferece devolver o projétil (1 Ki) num segundo popup.
				var monk_i: int = entry["reactor_idx"]
				var atk_i: int = entry.get("attacker_idx", -1)
				_pending_reaction_queue.push_front({
					"trigger_type": "deflect_return_fire",
					"reactor_idx": monk_i,
					"target_idx":  atk_i,
					"reaction_label": "Devolver Projétil",
					"reaction_desc": "Gastar 1 Ki para devolver o projétil ao atacante?",
					"context_text": "%s zerou o projétil de %s" % [
						BattleState.TURN_QUEUE[monk_i]["name"],
						BattleState.TURN_QUEUE[atk_i]["name"] if atk_i >= 0 else "?"],
					"cost_text": "1 Ki",
					"consumes_reaction": false,
					"portrait": _portrait_of(monk_i),
				})
			done.call()
		"deflect_return_fire":
			var monk_idx: int = entry["reactor_idx"]
			var tgt: int      = entry.get("target_idx", -1)
			var mpidx: int    = _state._player_index_by_name(BattleState.TURN_QUEUE[monk_idx]["name"])
			if tgt >= 0 and mpidx >= 0 and BattleState.PLAYERS[mpidx].get("ki", 0) >= 1 \
					and not _state.dead_indices.has(tgt):
				BattleState.PLAYERS[mpidx]["ki"] -= 1
				_state.apply_opportunity_attack(monk_idx, tgt)
				_animating = true
				var rpos: Vector2i = _state.combatant_positions[tgt]
				_play_attack_animation(monk_idx, rpos, ActionData.new(), 0, false, false,
					func() -> void:
						_animating = false
						_show_floater_if_needed()
						_process_pending_deaths()
						done.call()
				)
			else:
				done.call()
		"divine_smite":
			var is_crit: bool = _state.last_attack_info.get("is_crit", false)
			_state.apply_divine_smite_reaction(entry["reactor_idx"], 1, is_crit)
			_show_floater_if_needed()
			_process_pending_deaths()
			done.call()
		"stunning_strike":
			var t_idx: int = entry["target_idx"]
			var stunned: bool = _state.apply_stunning_strike(entry["reactor_idx"], t_idx)
			var msg: String = "Atordoado!" if stunned else "Resistiu!"
			_battle_area.show_text_floater(
				_state.combatant_positions[t_idx], msg, Color(0.7, 0.4, 0.9))
			done.call()
		_:
			done.call()

# ======================================================
# EXECUTE — CONFIRM MOVE
# ======================================================
func _execute_confirm_move() -> void:
	var move_path: Array[Vector2i] = _state.get_path_to(_state.move_cursor)
	_state.confirm_move()

	# O turno NUNCA encerra automaticamente apos um movimento — o jogador decide
	# quando terminar (botao Fim de Turno / acoes de fim de turno).
	if move_path.is_empty():
		_refresh_ui()
		return

	_animating = true
	var mover_idx: int = _state.active_index
	var old_pos: Vector2i = _state._undo_move_pos
	_battle_area.animate_move(mover_idx, move_path, func() -> void:
		_animating = false
		var final_pos: Vector2i = _state.combatant_positions[mover_idx]
		_state.activate_trap_after_move(mover_idx, final_pos)
		# On-enter aplica-se a CADA tile do caminho percorrido (BG3), não só ao final.
		for step_pos in move_path:
			_state.apply_surface_on_enter(mover_idx, step_pos)
		_flush_surface_floaters()
		# Ataque de Oportunidade: inimigos adjacentes reagem ao jogador que saiu.
		_enqueue_opportunity_attacks(mover_idx, old_pos, final_pos)
		_process_next_reaction(func() -> void:
			if _check_battle_end():
				return
			_refresh_ui()
		)
	)

# Monta entradas de OA na fila para todos os reatores válidos contra mover_idx.
func _enqueue_opportunity_attacks(mover_idx: int, old_pos: Vector2i, new_pos: Vector2i) -> void:
	var reactors: Array[int] = _state.check_opportunity_attacks(mover_idx, old_pos, new_pos)
	for r in reactors:
		_pending_reaction_queue.append({
			"trigger_type": "OA",
			"reactor_idx": r,
			"target_idx": mover_idx,
			"reaction_label": "Ataque de Oportunidade",
			"reaction_desc": "%s pode atacar %s ao sair do alcance!" % [
				BattleState.TURN_QUEUE[r]["name"],
				BattleState.TURN_QUEUE[mover_idx]["name"]],
			"context_text": "%s saiu do alcance de %s" % [
				BattleState.TURN_QUEUE[mover_idx]["name"],
				BattleState.TURN_QUEUE[r]["name"]],
			"cost_text": "",
			"consumes_reaction": true,
			"portrait": _portrait_of(r),
		})

# Retorna o portrait do combatente (player) ou null (inimigo) para o popup.
func _portrait_of(combatant_idx: int) -> Texture2D:
	if not BattleState.TURN_QUEUE[combatant_idx]["is_player"]:
		return null
	var pidx: int = _state._player_index_by_name(BattleState.TURN_QUEUE[combatant_idx]["name"])
	if pidx < 0:
		return null
	return BattleState.PLAYERS[pidx].get("portrait", null)

# ======================================================
# EXECUTE — CONFIRM ATTACK
# ======================================================
func _execute_confirm_attack() -> void:
	var attacker_idx: int   = _state.active_index
	var target_pos: Vector2i = _state.get_attack_cursor_pos()
	# Mira de AoE em ponto: o cursor de tile é sempre um alvo válido (clampado ao
	# alcance), mesmo sem criatura no centro.
	var tile_mode: bool     = _state.attack_tile_mode
	var has_target: bool    = tile_mode or not _state.attack_target_indices.is_empty()
	var is_self: bool       = (not tile_mode) and has_target and target_pos == _state.combatant_positions[attacker_idx]
	var is_ranged: bool     = _state.current_attack_range > 1 and not is_self
	var aoe_radius: int     = _state.current_aoe_radius
	var hit_count: int      = _pending_attack_action.hit_count if _pending_attack_action != null else 1
	var action: ActionData  = _pending_attack_action

	# Sem alvo válido — limpa o estado pendente; nenhum recurso é gasto.
	if not has_target:
		_state.confirm_attack()
		_pending_attack_slot_level = 0
		_pending_attack_ki_cost = 0
		_pending_attack_action = null
		_refresh_ui()
		return

	# Captura o alvo travado ANTES de qualquer mutação que limpe a seleção. Em mira
	# de tile vazio não há alvo único (target_idx = -1); o estado resolve internamente.
	var target_idx: int = -1
	if not tile_mode:
		target_idx = _state.attack_target_indices[_state.attack_cursor_idx]

	# Empurrar (Shove): resolução tática própria — não passa pelo _apply_attack.
	if action is AcaoEmpurrar and target_idx >= 0:
		_state.resolve_shove(attacker_idx, target_idx)
		_state.finalize_attack()
		_pending_attack_action = null
		_process_pending_deaths()
		if _check_battle_end():
			return
		_refresh_ui()
		return

	# Pular (Jump): mira um tile de pouso — não passa pelo _apply_attack. Só
	# finaliza (gasta a ação) se o pouso for válido; inválido só avisa. Pular
	# PROVOCA Ataque de Oportunidade no deslocamento (BG3), como o movimento normal.
	if action is AcaoPular:
		var jump_from: Vector2i = _state.combatant_positions[attacker_idx]
		if _state.resolve_jump(attacker_idx, target_pos):
			_state.finalize_attack()
			var jump_to: Vector2i = _state.combatant_positions[attacker_idx]
			_pending_attack_action = null
			_animating = true
			_enqueue_opportunity_attacks(attacker_idx, jump_from, jump_to)
			_process_next_reaction(func() -> void:
				_animating = false
				_process_pending_deaths()
				if _check_battle_end():
					return
				_refresh_ui())
		else:
			_battle_area.show_text_floater(target_pos, "Sem pouso", FloaterManager.COLOR_MISS, 16, false)
			_pending_attack_action = null
			_refresh_ui()
		return

	# Arremessar (Throw): efeito de item em área no tile — não passa pelo _apply_attack.
	if action is AcaoArremessar:
		_state.resolve_throw(target_pos, action)
		_state.finalize_attack()
		_pending_attack_action = null
		_process_pending_deaths()
		if _check_battle_end():
			return
		_refresh_ui()
		return

	# Recursos (slot de magia / Ki) são gastos só ao confirmar, nunca ao cancelar.
	_consume_attack_resources()

	# O turno NUNCA encerra automaticamente apos uma acao — o jogador decide
	# quando terminar (botao Fim de Turno / acoes de fim de turno).
	_animating = true

	if tile_mode or hit_count <= 1:
		_state.confirm_attack()
		var callback := func() -> void:
			_animating = false
			_pending_attack_action = null
			# Reações ofensivas (Smite Divino / Golpe Atordoante) precisam de um
			# alvo único — não se aplicam à detonação em ponto do chão.
			if target_idx >= 0:
				_enqueue_offensive_reactions(attacker_idx, is_ranged)
			_process_next_reaction(func() -> void:
				_show_floater_if_needed()
				_flush_surface_floaters()  # floaters por alvo na detonação em tile
				_process_pending_deaths()
				if _check_battle_end():
					return
				_refresh_ui()
			)
		_play_attack_animation(attacker_idx, target_pos, action, aoe_radius, is_ranged, is_self, callback)
	else:
		_execute_multi_hit(attacker_idx, target_pos, target_idx, action, aoe_radius, is_ranged, is_self, hit_count)

# Enfileira reações ofensivas do atacante após acertar um ataque corpo-a-corpo.
func _enqueue_offensive_reactions(attacker_idx: int, is_ranged: bool) -> void:
	if is_ranged:
		return
	if not _state.last_attack_info.get("hit", false):
		return
	if not BattleState.TURN_QUEUE[attacker_idx]["is_player"]:
		return
	var pidx: int = _state._player_index_by_name(BattleState.TURN_QUEUE[attacker_idx]["name"])
	if pidx < 0:
		return
	var t_idx: int = _state.last_attack_info.get("target_idx", -1)
	if t_idx < 0:
		return
	var pclass: String = BattleState.PLAYERS[pidx].get("class", "")
	var is_crit: bool = _state.last_attack_info.get("is_crit", false)
	var ctx: String = "%s acertou %s%s" % [
		BattleState.TURN_QUEUE[attacker_idx]["name"],
		BattleState.TURN_QUEUE[t_idx]["name"],
		"  (CRÍTICO!)" if is_crit else ""]
	var portrait = BattleState.PLAYERS[pidx].get("portrait", null)
	if pclass == "Paladin":
		# Divine Smite NÃO consome a reação (BG3) — só precisa de um spell slot.
		var slots: Array = BattleState.PLAYERS[pidx].get("spell_slots", [])
		var has_slot := false
		for s in slots:
			if s > 0:
				has_slot = true
				break
		if has_slot:
			_pending_reaction_queue.append({
				"trigger_type": "divine_smite",
				"reactor_idx": attacker_idx,
				"target_idx": t_idx,
				"reaction_label": "Smite Divino",
				"reaction_desc": "Gastar 1 slot de magia para adicionar dano radiante?",
				"context_text": ctx,
				"cost_text": "Slot Nv.1",
				"consumes_reaction": false,
				"portrait": portrait,
			})
	elif pclass == "Monk":
		# Golpe Atordoante consome a reação E 1 Ki.
		if _state.has_reaction_available(attacker_idx) and BattleState.PLAYERS[pidx].get("ki", 0) >= 1:
			_pending_reaction_queue.append({
				"trigger_type": "stunning_strike",
				"reactor_idx": attacker_idx,
				"target_idx": t_idx,
				"reaction_label": "Golpe Atordoante",
				"reaction_desc": "Gastar 1 Ki para tentar atordoar o alvo (save de CON)?",
				"context_text": ctx,
				"cost_text": "1 Ki",
				"consumes_reaction": true,
				"portrait": portrait,
			})

## Gasta os recursos pendentes do ataque (slot de magia e/ou Ki). Chamado apenas
## ao confirmar — cancelar a seleção de alvo zera os pendentes sem gastar.
func _consume_attack_resources() -> void:
	if _pending_attack_slot_level > 0:
		_state.consume_spell_slot(_pending_attack_slot_level)
		_pending_attack_slot_level = 0
	if _pending_attack_ki_cost > 0:
		var pidx := _state.get_active_player_index()
		if pidx >= 0:
			BattleState.PLAYERS[pidx]["ki"] = maxi(0, int(BattleState.PLAYERS[pidx].get("ki", 0)) - _pending_attack_ki_cost)
		_pending_attack_ki_cost = 0

## Despacha a animação de ataque correta (AoE / projétil / corpo-a-corpo) e
## dispara `cb` ao final.
func _play_attack_animation(attacker_idx: int, target_pos: Vector2i, action: ActionData, aoe_radius: int, is_ranged: bool, is_self: bool, cb: Callable) -> void:
	if aoe_radius > 0:
		_battle_area.animate_aoe_attack(attacker_idx, target_pos, action, cb)
	elif is_ranged or is_self:
		var is_crit: bool = _state.last_attack_info.get("is_crit", false)
		_battle_area.animate_ranged_attack(attacker_idx, target_pos, action, cb, is_crit)
	else:
		var is_crit: bool = _state.last_attack_info.get("is_crit", false)
		_battle_area.animate_attack(attacker_idx, target_pos, cb, is_crit)

## Flurry of Blows e afins: aplica e anima `hit_count` golpes contra o mesmo
## alvo em sequência (estilo BG3), cada um com seu próprio roll de ataque, dano
## e floater. As flags de turno só são finalizadas após o último golpe.
func _execute_multi_hit(attacker_idx: int, target_pos: Vector2i, target_idx: int, action: ActionData, aoe_radius: int, is_ranged: bool, is_self: bool, hit_count: int) -> void:
	for i in range(hit_count):
		# Interrompe se o alvo morreu num golpe anterior.
		if _state.dead_indices.has(target_idx):
			break
		# Aplica UM golpe (rola ataque + dano, seta last_attack_info) sem
		# finalizar o turno — o contexto de ataque (range/aoe) é preservado.
		_state.apply_attack_at_cursor()
		var done := [false]
		var cb := func() -> void:
			_show_floater_if_needed()
			_process_pending_deaths()
			done[0] = true
		_play_attack_animation(attacker_idx, target_pos, action, aoe_radius, is_ranged, is_self, cb)
		while not done[0]:
			await get_tree().process_frame
		if i < hit_count - 1:
			await get_tree().create_timer(0.25).timeout

	_animating = false
	_pending_attack_action = null
	# Reações ofensivas após a sequência de golpes (avalia o último golpe aplicado).
	_enqueue_offensive_reactions(attacker_idx, is_ranged)
	_process_next_reaction(func() -> void:
		_state.finalize_attack()
		if _check_battle_end():
			return
		_refresh_ui()
	)

# ======================================================
# AFTER ADVANCE
# ======================================================

func _after_advance() -> void:
	if _check_battle_end():
		return

	# Rede de seguranca: a troca de turno limpa qualquer acao pendente, para
	# que o novo turno comece num estado neutro (clicar no personagem volta a
	# entrar no modo de movimento).
	_pending_attack_action = null
	_pending_end_turn_action = null
	_pending_item = {}
	_pending_attack_slot_level = 0
	_pending_attack_ki_cost = 0

	# Verificação de segurança para o índice
	if _state.active_index < 0 or _state.active_index >= BattleState.TURN_QUEUE.size():
		print("ERRO: active_index inválido na transição: ", _state.active_index)
		# Tenta encontrar o próximo índice válido
		var found_valid := false
		for i in range(BattleState.TURN_QUEUE.size()):
			if not _state.dead_indices.has(i):
				_state.active_index = i
				found_valid = true
				break
		if not found_valid:
			# Todos estão mortos - força verificação de fim de batalha
			_state._check_battle_end()
			_check_battle_end()
			return
	
	# Verifica se o combatente atual está morto
	if _state.dead_indices.has(_state.active_index):
		# Avança para o próximo combatente vivo
		var guard := 0
		while _state.dead_indices.has(_state.active_index) and guard < BattleState.TURN_QUEUE.size():
			_state.active_index = (_state.active_index + 1) % BattleState.TURN_QUEUE.size()
			guard += 1
		
		if guard >= BattleState.TURN_QUEUE.size():
			_check_battle_end()
			return
	
	# Verificação final de segurança
	if _state.active_index < 0 or _state.active_index >= BattleState.TURN_QUEUE.size():
		print("ERRO CRÍTICO: Não foi possível encontrar combatente válido")
		return
	
	var combatant_name: String = BattleState.TURN_QUEUE[_state.active_index]["name"]

	# SUBSTITUIR POR ISTO (correção com refresh no lugar certo):
	if _state.current_state == BattleState.State.ENEMY_TURN:
		_animating = true
		if _turn_transition and is_inside_tree():
			_turn_transition.show_turn("Turno Inimigo", combatant_name, func() -> void:
				_animating = false
				if not is_inside_tree():
					return
				_refresh_ui()
				# Floaters de dano de superfície de início de turno só agora que o
				# tabuleiro está visível (a transição cobria a tela antes).
				_flush_surface_floaters()
				_do_enemy_turn()
			)
		else:
			_animating = false
			_refresh_ui()
			_flush_surface_floaters()
			_do_enemy_turn()
	else:
		_animating = true
		if _turn_transition and is_inside_tree():
			_turn_transition.show_turn("Turno Herói", combatant_name, func() -> void:
				_animating = false
				if not is_inside_tree():
					return
				var pidx: int = _state.get_active_player_index()
				if pidx >= 0 and pidx < BattleState.PLAYERS.size():
					if BattleState.PLAYERS[pidx]["class"] == "Barbarian":
						if not _state.has_fury(pidx):
							var p: Dictionary = BattleState.PLAYERS[pidx]
							if float(p["hp"]) / float(p["max_hp"]) < 0.5:
								_state.apply_fury_status(pidx)
						else:
							_state.fury_extra_attack = true
				_refresh_ui()
				# Floaters de dano de superfície de início de turno (ex.: Mago na nuvem).
				_flush_surface_floaters()
			)
		else:
			_animating = false
			_refresh_ui()
			_flush_surface_floaters()

# ======================================================
# ENEMY TURN
# ======================================================
func _do_enemy_turn() -> void:
	var enemy_idx: int = _state.active_index
	var enemy_old_pos: Vector2i = _state.combatant_positions[enemy_idx]
	var path: Array[Vector2i] = _state.get_enemy_move_path()
	_state.apply_enemy_move(path)

	if path.is_empty():
		_enemy_do_attack()
		return

	_animating = true
	_battle_area.animate_move(enemy_idx, path, func() -> void:
		_animating = false
		var final_pos: Vector2i = _state.combatant_positions[enemy_idx]
		_state.activate_trap_after_move(enemy_idx, final_pos)
		# On-enter aplica-se a CADA tile do caminho percorrido (BG3), não só ao final.
		for step_pos in path:
			_state.apply_surface_on_enter(enemy_idx, step_pos)
		_flush_surface_floaters()
		# Ataque de Oportunidade: jogadores adjacentes reagem ao inimigo que saiu.
		_enqueue_opportunity_attacks(enemy_idx, enemy_old_pos, final_pos)
		_process_next_reaction(func() -> void:
			if _check_battle_end():
				return
			# Se o inimigo morreu por um OA, encerra o turno dele.
			if _state.dead_indices.has(enemy_idx):
				_state.advance_turn()
				_after_advance()
				return
			_enemy_do_attack()
		)
	)

func _enemy_do_attack() -> void:
	var attacker_idx: int    = _state.active_index
	var info: Dictionary     = _state.apply_enemy_attack()
	var target_pos: Vector2i = info.get("target", Vector2i(-1, -1))

	if target_pos.x < 0:
		if not _check_battle_end():
			_state.advance_turn()
			_after_advance()
		return

	# Reações defensivas do alvo (Esquiva Sobrenatural / Defletir Projéteis) são
	# resolvidas ANTES da animação, para que o floater mostre o dano já reduzido.
	_enqueue_defensive_reactions(attacker_idx, info)
	_process_next_reaction(func() -> void:
		_animating = true
		var is_crit: bool = _state.last_attack_info.get("is_crit", false)
		var callback := func() -> void:
			_animating = false
			_show_floater_if_needed()
			_flush_surface_floaters()  # AoE inimigo: floater por alvo
			_process_pending_deaths()
			if _check_battle_end():
				return
			_state.advance_turn()
			_after_advance()

		if info.get("is_ranged", false):
			var enemy_action := ActionData.new()
			enemy_action.proj_color = info.get("color", Color.WHITE)

			var enemy_type: String = BattleState.TURN_QUEUE[attacker_idx].get("type", "")
			match enemy_type:
				"Undead":
					enemy_action.sfx_cast = "whoosh_bow"
					enemy_action.sfx_impact = "impact_arrow"
				"Mage":
					enemy_action.sfx_cast = "whoosh_magic"
					enemy_action.sfx_impact = "silent"
				"EliteMage":
					enemy_action.sfx_cast = "whoosh_magic"
					enemy_action.sfx_impact = "silent"

			_battle_area.animate_ranged_attack(attacker_idx, target_pos, enemy_action, callback, is_crit)
		else:
			_battle_area.animate_attack(attacker_idx, target_pos, callback, is_crit)
	)

# Enfileira reações defensivas do alvo atingido por um ataque inimigo.
func _enqueue_defensive_reactions(attacker_idx: int, info: Dictionary) -> void:
	if not _state.last_attack_info.get("hit", false):
		return
	var target_idx: int = _state.last_attack_info.get("target_idx", -1)
	if target_idx < 0 or not BattleState.TURN_QUEUE[target_idx]["is_player"]:
		return
	if not _state.has_reaction_available(target_idx):
		return
	var pidx: int = _state._player_index_by_name(BattleState.TURN_QUEUE[target_idx]["name"])
	if pidx < 0:
		return
	var pclass: String = BattleState.PLAYERS[pidx].get("class", "")
	var is_ranged_atk: bool = info.get("is_ranged", false)
	var ctx: String = "%s atingiu %s" % [
		BattleState.TURN_QUEUE[attacker_idx]["name"],
		BattleState.TURN_QUEUE[target_idx]["name"]]
	var portrait := _portrait_of(target_idx)
	if pclass == "Rogue":
		_pending_reaction_queue.append({
			"trigger_type": "uncanny_dodge",
			"reactor_idx": target_idx,
			"target_idx": target_idx,
			"attacker_idx": attacker_idx,
			"reaction_label": "Esquiva Sobrenatural",
			"reaction_desc": "Reduzir o dano recebido à metade?",
			"context_text": ctx,
			"cost_text": "",
			"consumes_reaction": true,
			"portrait": portrait,
		})
	elif pclass == "Monk" and is_ranged_atk:
		_pending_reaction_queue.append({
			"trigger_type": "deflect_missiles",
			"reactor_idx": target_idx,
			"target_idx": target_idx,
			"attacker_idx": attacker_idx,
			"reaction_label": "Defletir Projéteis",
			"reaction_desc": "Reduzir o dano do projétil (1d10+DEX+nível)?",
			"context_text": ctx,
			"cost_text": "",
			"consumes_reaction": true,
			"portrait": portrait,
		})

# ======================================================
# TILE EVENTS
# ======================================================

# Estado "completamente neutro": e o turno do jogador, nenhuma acao/confirmacao
# esta pendente e nenhum modo (mover/atacar) esta ativo. Usado para permitir o
# clique no proprio personagem entrar direto no modo de movimento.
func _is_neutral_player_state() -> bool:
	return _state.current_state == BattleState.State.PLAYER_TURN \
		and _pending_end_turn_action == null \
		and _pending_item.is_empty() \
		and _pending_attack_action == null

# Overlay de LOS dos inimigos: aparece só no estado neutro enquanto Left Shift
# está pressionado. Poll por frame evita tecla "presa" ao alternar janela/estado.
var _los_overlay_on: bool = false

func _process(_dt: float) -> void:
	if _state == null:
		return
	var want: bool = Input.is_key_pressed(KEY_SHIFT) and _is_neutral_player_state() and not _animating
	if want != _los_overlay_on:
		_los_overlay_on = want
		_battle_area.set_los_overlay(want, _state.get_enemy_vision_tiles() if want else {})

# Em ATTACK_MODE com mira de AoE em tile, o movimento do mouse arrasta o centro
# do AoE (clampado ao alcance). Setas e clique continuam funcionando.
func _on_tile_hovered(grid_pos: Vector2i) -> void:
	if _state == null or _state.current_state != BattleState.State.ATTACK_MODE:
		return
	# Pular: o arco segue o mouse livremente (sem clamp ao alcance de mira).
	if _state._current_action is AcaoPular:
		_battle_area.queue_redraw()
		return
	if not _state.attack_tile_mode:
		return
	if _state.set_attack_tile_cursor_clamped(grid_pos):
		_battle_area.queue_redraw()

func _on_tile_clicked(grid_pos: Vector2i) -> void:
	if _animating:
		return
	match _state.current_state:
		BattleState.State.PLAYER_TURN:
			# Clicar no proprio personagem ativo (ou bem perto dele), com o
			# estado completamente neutro (nenhuma acao selecionada ou
			# confirmacao pendente), entra direto no modo de movimento — sem
			# passar pelo menu. Como o sprite isometrico se desenha acima do
			# tile, o clique costuma cair num tile vizinho; por isso aceitamos
			# a vizinhanca imediata (Chebyshev <= 1) do tile do personagem.
			if _is_neutral_player_state() and _state.move_points_remaining > 0:
				var self_pos: Vector2i = _state.combatant_positions[_state.active_index]
				if absi(grid_pos.x - self_pos.x) <= 1 and absi(grid_pos.y - self_pos.y) <= 1:
					_state.enter_move_mode()
					_refresh_ui()
		BattleState.State.MOVE_MODE:
			if _state.get_reachable_tiles().has(grid_pos):
				_state.move_cursor = grid_pos
				_execute_confirm_move()
		BattleState.State.ATTACK_MODE:
			# Pular: clique num pouso válido executa; inválido só avisa, sem gastar ação.
			if _state._current_action is AcaoPular:
				if _state.is_valid_jump_landing(_state.active_index, grid_pos):
					_state.attack_tile_cursor = grid_pos
					_execute_confirm_attack()
				else:
					_battle_area.show_text_floater(grid_pos, "Sem pouso", FloaterManager.COLOR_MISS, 16, false)
				return
			# Mira de AoE em ponto: clicar em qualquer tile válido no alcance posiciona
			# o cursor de tile e detona ali (com ou sem criatura no centro).
			if _state.attack_tile_mode:
				if _state.get_attack_area_tiles().has(grid_pos):
					_state.attack_tile_cursor = grid_pos
					_execute_confirm_attack()
				return
			for i in range(_state.attack_target_indices.size()):
				if _state.combatant_positions[_state.attack_target_indices[i]] == grid_pos:
					_state.attack_cursor_idx = i
					_execute_confirm_attack()
					return

# ======================================================
# GRID EVENTS
# ======================================================
func _on_grid_action_clicked(action) -> void:
	if _action_tooltip != null:
		_action_tooltip.hide_tooltip()
	if _animating or _state.current_state != BattleState.State.PLAYER_TURN:
		return
	if action == null or not _state.is_item_available(action):
		_refresh_ui()
		return
	_begin_item(action)

# Shows the action tooltip on hover (after a short delay); hides it on mouse-out
# (action == null) or when not the player's turn.
func _on_action_hovered(action: ActionData) -> void:
	if _action_tooltip == null:
		return
	if action == null or _state == null or _state.current_state != BattleState.State.PLAYER_TURN:
		_action_tooltip.hide_tooltip()
		return
	_action_tooltip.show_for(action)

# Element B: shows/hides the fixed top-of-screen enemy info panel as the hovered
# attack target changes (cidx is a TURN_QUEUE index, or -1 for none).
func _on_attack_hover_changed(cidx: int) -> void:
	if _enemy_info_panel == null:
		return
	if cidx < 0 or _state == null or cidx >= BattleState.TURN_QUEUE.size():
		_enemy_info_panel.hide_panel()
		return
	var combatant: Dictionary = BattleState.TURN_QUEUE[cidx]
	var hp_cur: int
	var hp_max: int
	if combatant.get("is_player", false):
		var pidx := _state._player_index_by_name(combatant["name"])
		hp_cur = BattleState.PLAYERS[pidx].get("hp", 0) if pidx >= 0 else 0
		hp_max = BattleState.PLAYERS[pidx].get("max_hp", 1) if pidx >= 0 else 1
	else:
		hp_cur = int(_state.enemy_hp.get(combatant.get("name", ""), 0))
		hp_max = _state.get_enemy_max_hp(cidx)
	_enemy_info_panel.show_for(combatant, hp_cur, hp_max)

func _on_end_turn_pressed() -> void:
	if _animating or _state.current_state != BattleState.State.PLAYER_TURN:
		return
	_state.advance_turn()
	_after_advance()

# ======================================================
# BATTLE END
# ======================================================
func _check_battle_end() -> bool:
	if _state.battle_result.is_empty():
		return false

	_animating = true
	var result: String      = _state.battle_result
	var stats: Dictionary   = _state.battle_stats.duplicate()
	var tween               := create_tween()
	tween.tween_interval(1.5)
	tween.tween_callback(func() -> void: _result_screen.show_result(result, stats))
	return true

# ======================================================
# PENDING DEATHS / FLOATER
# ======================================================
func _process_pending_deaths() -> void:
	for idx: int in _state.pending_deaths:
		_battle_area.start_death_animation(idx)
	_state.pending_deaths.clear()

func _show_floater_if_needed() -> void:
	if _state.last_attack_info.is_empty():
		return
	var target_idx: int = _state.last_attack_info.get("target_idx", -1)
	var amount: int     = _state.last_attack_info.get("amount", 0)
	if target_idx < 0 or target_idx >= _state.combatant_positions.size():
		return
	var is_heal: bool = _state.last_attack_info.get("is_heal", false)
	if not is_heal and amount > 0:
		_battle_area.show_hit_flash(target_idx)
	if amount == 0:
		# An attack that dealt no damage and wasn't a heal is a miss — float an indicator.
		if not is_heal and not _state.last_attack_info.get("hit", false):
			var grid_pos: Vector2i = _state.combatant_positions[target_idx]
			if int(_state.last_attack_info.get("attack_roll", -1)) == 1:
				_battle_area.show_text_floater(grid_pos, "Critical Miss!", FloaterManager.COLOR_CRIT_MISS, 18, true)
			else:
				_battle_area.show_text_floater(grid_pos, "Miss!", FloaterManager.COLOR_MISS, 16, false)
		return
	
	var combatant: Dictionary = BattleState.TURN_QUEUE[target_idx]
	if combatant["is_player"]:
		var player_idx := _find_player_idx(combatant["name"])
		if player_idx >= 0:
			var player: Dictionary = BattleState.PLAYERS[player_idx]
			_battle_area._combatant_layer.update_single_combatant_hp(target_idx, player["hp"], player["max_hp"])
	else:
		var cname: String = combatant["name"]
		var hp: int = _state.enemy_hp.get(cname, 0)
		var max_hp: int = _state.get_enemy_max_hp(target_idx)
		_battle_area._combatant_layer.update_single_combatant_hp(target_idx, hp, max_hp)
	
	# Display estilo BG3: o floater principal mostra só o dano base da arma
	# (dados + atributo); cada componente extra (Furtivo, Smite) aparece como um
	# floater próprio em sequência, nunca somado num único número.
	var smite_amount: int = _state.last_attack_info.get("smite_amount", 0)
	var status_bonus_amount: int = _state.last_attack_info.get("status_bonus_amount", 0)
	var status_bonus_label: String = _state.last_attack_info.get("status_bonus_label", "")
	var base_amount: int = maxi(1, amount - smite_amount - status_bonus_amount)

	var dtype = _state.last_attack_info.get("damage_type", ActionData.DamageType.PHYSICAL)
	var dtype_color := ActionData.damage_type_color(dtype) if not is_heal else Color(-1, -1, -1)
	_battle_area.show_floater(
		_state.combatant_positions[target_idx],
		base_amount,
		is_heal,
		_state.last_attack_info.get("is_crit", false),
		dtype_color
	)

	var fpos: Vector2i = _state.combatant_positions[target_idx]
	if status_bonus_amount > 0 and status_bonus_label != "":
		await get_tree().create_timer(0.18).timeout
		_battle_area.show_text_floater(fpos, "+%d %s" % [status_bonus_amount, status_bonus_label],
			Color(0.7, 0.3, 1.0), 16, false)  # roxo p/ bônus de status (Furtivo/Fúria)
	if smite_amount > 0:
		await get_tree().create_timer(0.18).timeout
		_battle_area.show_text_floater(fpos, "+%d Radiante" % smite_amount,
			Color(1.0, 0.85, 0.1), 16, false)

# Mostra floaters (e atualiza barra de HP) para dano de superfície acumulado em
# pending_surface_hits — preenchido por _apply_surface_tick / apply_surface_on_enter.
# Slashing/Cortante usa cor branco-azulada para distinguir do dano de arma.
func _flush_surface_floaters() -> void:
	if _state.pending_surface_hits.is_empty():
		return
	for hit in _state.pending_surface_hits:
		var idx: int = hit.get("target_idx", -1)
		if idx < 0 or idx >= _state.combatant_positions.size():
			continue
		var pos: Vector2i = _state.combatant_positions[idx]
		_battle_area.show_hit_flash(idx)
		# Número de dano em roxo vivo (tema da nuvem) + rótulo do tipo, no mesmo
		# estilo dos floaters de bônus (Furtivo/Smite), para ficar bem visível. A
		# detonação de AoE em tile pode sobrescrever com a cor do tipo de dano.
		var surf_color: Color = hit.get("color", Color(0.78, 0.45, 1.0))
		_battle_area.show_floater(pos, hit.get("damage", 0), false, false, surf_color)
		var hit_label: String = hit.get("label", "")
		if hit_label != "":
			_battle_area.show_text_floater(pos, hit_label, surf_color, 14, false)
		# Atualiza a barra de HP imediatamente para refletir o dano de superfície.
		var combatant: Dictionary = BattleState.TURN_QUEUE[idx]
		if combatant["is_player"]:
			var pidx := _find_player_idx(combatant["name"])
			if pidx >= 0:
				var player: Dictionary = BattleState.PLAYERS[pidx]
				_battle_area._combatant_layer.update_single_combatant_hp(idx, player["hp"], player["max_hp"])
		else:
			var hp: int = _state.enemy_hp.get(combatant["name"], 0)
			_battle_area._combatant_layer.update_single_combatant_hp(idx, hp, _state.get_enemy_max_hp(idx))
	_state.pending_surface_hits.clear()

# Cancelamento manual de concentração via botão × no StatusPanel.
# queue_idx é o índice em TURN_QUEUE que o StatusPanel está renderizando — usá-lo
# diretamente evita o descasamento com PLAYERS[] de get_active_player_index().
func _on_concentration_cancel(queue_idx: int) -> void:
	if _state.is_concentrating(queue_idx):
		_state._break_concentration(queue_idx)
		_refresh_ui()

# ======================================================
# ACTIONS — SCENE TRANSITIONS
# ======================================================
func _on_continue_requested() -> void:
	if DungeonState.current_run == null:
		push_error("_on_continue_requested: no active dungeon run")
		SceneTransition.fade_to("res://ui/main_menu.tscn")
		return
	DungeonState.current_run.complete_current_room()
	if DungeonState.current_run.is_run_complete():
		DungeonState.delete_save()
		DungeonState.current_run = null
		BattleState.reset_players()
		SceneTransition.fade_to("res://ui/main_menu.tscn")
	else:
		SceneTransition.fade_to("res://ui/dungeon_map.tscn")

func _on_pause_to_menu() -> void:
	DungeonState.current_run = null
	BattleState.reset_players()
	SceneTransition.fade_to("res://ui/main_menu.tscn")

func _on_restart_requested() -> void:
	if DungeonState.current_run != null:
		DungeonState.delete_save()
		DungeonState.current_run = null
	BattleState.reset_players()
	SceneTransition.fade_to("res://ui/main_menu.tscn")

# ======================================================
# HELPERS
# ======================================================
func _find_player_idx(pname: String) -> int:
	for i in range(BattleState.PLAYERS.size()):
		if BattleState.PLAYERS[i]["name"] == pname:
			return i
	return -1

func _terrain_info(tile: TerrainTile) -> Array:
	if tile.effect == TerrainTile.EffectType.TRAP_ACTIVE:
		return ["Armadilha Ativada", "Dano e veneno ao pisar!"]
	if tile.object != TerrainTile.ObjectType.NONE:
		match tile.object:
			TerrainTile.ObjectType.STATUE:   return ["Estátua",    "Obstáculo decorativo."]
			TerrainTile.ObjectType.OBSTACLE: return ["Obstáculo",  "Bloqueia passagem."]
			TerrainTile.ObjectType.COVER:    return ["Cobertura",  "Fornece cobertura contra ataques."]
	if tile.ground == TerrainTile.GroundType.ELEVATED:
		return ["Elevado", "Terreno elevado. +1 alcance para ataques à distância."]
	match tile.ground:
		TerrainTile.GroundType.NORMAL: return ["Normal", "Terreno comum. Sem bônus."]
		TerrainTile.GroundType.MUD:    return ["Lama",   "Custo de movimento: 2."]
		TerrainTile.GroundType.STONE:  return ["Pedra",  "Terreno rochoso."]
		TerrainTile.GroundType.GRASS:  return ["Grama",  "Terreno coberto de vegetação."]
		_:                             return ["", ""]

func _update_attack_outlines() -> void:
	if _state.current_state != BattleState.State.ATTACK_MODE:
		_battle_area.update_combatant_outlines([], -1)
		return
	
	var available: Array = []
	for i in _state.attack_target_indices:
		available.append(i)
	
	var selected := -1
	if not _state.attack_target_indices.is_empty():
		var cursor_idx: int = _state.attack_cursor_idx
		if cursor_idx >= 0 and cursor_idx < _state.attack_target_indices.size():
			selected = _state.attack_target_indices[cursor_idx]
	
	_battle_area.update_combatant_outlines(available, selected)

func _get_action_description(action: ActionData) -> String:
	var desc := ""
	if action.action_type == ActionData.Type.ATTACK:
		var dmg_range := _state.get_damage_range(action)
		if action.targets_allies:
			desc = "Cura %d-%d HP  •  Alcance %d" % [dmg_range.x, dmg_range.y, action.attack_range]
		else:
			desc = "Dano: %d-%d  •  Alcance: %d" % [dmg_range.x, dmg_range.y, action.attack_range]
			if action.aoe_radius > 0:
				desc += "  •  AoE raio %d" % action.aoe_radius
		if action.spell_slot_level > 0:
			desc += "  •  Slot: %dº nível" % action.spell_slot_level
		elif action.ki_cost > 0:
			desc += "  •  Custo: %d Ki" % action.ki_cost
	elif action.action_type == ActionData.Type.END_TURN:
		desc = action.label
	return desc

# ======================================================
# EXAMINE / CONTEXT MENU
# ======================================================
func _on_portrait_right_clicked(slot_index: int, global_mouse_pos: Vector2) -> void:
	if _animating:
		return
	if _context_menu != null and is_instance_valid(_context_menu):
		_context_menu.queue_free()
	_context_menu = ContextMenu.new()
	add_child(_context_menu)
	_context_menu.examine_requested.connect(_on_examine_requested)
	_context_menu.show_at(global_mouse_pos, slot_index)

func _on_examine_requested(slot_index: int) -> void:
	_context_menu = null
	_examine_panel.show_for(_state, slot_index)
