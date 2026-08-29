class_name BattleScene
extends Control

# ======================================================
# 🎨 ASSETS
# ======================================================
const BG_TEXTURE := preload("res://assets/ui/backgrounds/battle_bg.png")

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE DE TAMANHOS
# ──────────────────────────────────────────────────────
const HUD_HEIGHT       := 200
const STATUS_WIDTH     := 280
const CONTEXT_WIDTH    := 170
const LOG_WIDTH        := 200
# ──────────────────────────────────────────────────────

# ======================================================
# VARS
# ======================================================
var _state: BattleState
var _turn_bar: TurnOrderBar
var _battle_area: BattleArea
var _status_panel: StatusPanel
var _action_panel: ActionPanel
var _context_panel: ContextPanel
var _log_panel: CombatLogPanel
var _result_screen: BattleResultScreen
var _pause_menu: PauseMenu
var _turn_transition: TurnTransitionLayer
var _animating: bool = false
var _camera_shake: CameraShake
var _screen_flash: ScreenFlash
var _pending_end_turn_action: ActionData = null
var _pending_item: Dictionary = {}
var _pending_attack_mp_cost: int = 0

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
	var hud := HBoxContainer.new()
	hud.custom_minimum_size.y = HUD_HEIGHT
	parent.add_child(hud)

	_status_panel = StatusPanel.new()
	_status_panel.custom_minimum_size.x = STATUS_WIDTH
	hud.add_child(_status_panel)

	_action_panel = ActionPanel.new()
	_action_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hud.add_child(_action_panel)

	_context_panel = ContextPanel.new()
	_context_panel.custom_minimum_size.x = CONTEXT_WIDTH
	hud.add_child(_context_panel)

	_log_panel = CombatLogPanel.new()
	_log_panel.custom_minimum_size.x = LOG_WIDTH
	hud.add_child(_log_panel)

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

# ======================================================
# CONNECT SIGNALS
# ======================================================
func _connect_signals() -> void:
	_result_screen.continue_requested.connect(_on_continue_requested)
	_result_screen.restart_requested.connect(_on_restart_requested)

	_pause_menu.resume_requested.connect(func() -> void: _pause_menu.hide_menu())
	_pause_menu.menu_requested.connect(_on_pause_to_menu)

	_action_panel.tab_clicked.connect(_on_tab_clicked)
	_action_panel.slot_clicked.connect(_on_slot_clicked)
	_action_panel.slot_hovered.connect(_on_slot_hovered)

	_battle_area.tile_clicked.connect(_on_tile_clicked)
	_battle_area.tile_hovered.connect(_on_tile_hovered)

	_action_panel.cancel_action.connect(func():
		_pending_attack_mp_cost = 0  # Devolve o MP que não foi gasto
		_pending_end_turn_action = null
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
	_state.setup(map_data)

	_battle_area.setup(_state)
	_battle_area.set_void_theme(VoidTheme.ThemeType.ABYSS)

	_action_panel.setup(_state)
	_status_panel.setup(_state)
	_log_panel.setup(_state)
	const ROOM_TITLES: Dictionary = {
		DungeonState.RoomType.BATTLE: "Batalha",
		DungeonState.RoomType.ELITE:  "Batalha Elite",
		DungeonState.RoomType.BOSS:   "CHEFE DO DUNGEON",
	}
	var rtype := _get_current_room_type()
	var floor_lbl := "Dungeon"
	if DungeonState.current_run != null:
		var _node := DungeonState.current_run.get_node_by_id(
			DungeonState.current_run.current_node_id)
		if _node != null:
			floor_lbl = "Boss" if _node.floor_idx == DungeonState.FLOOR_COUNT - 1 \
				else "Andar %d" % (_node.floor_idx + 1)
	_context_panel.setup(
		ROOM_TITLES.get(rtype, "Batalha"),
		floor_lbl,
		"Prepare-se para o combate.")

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

	_turn_bar.refresh(BattleState.TURN_QUEUE, _state.active_index)
	_battle_area.refresh(_state.active_index)
	_action_panel.refresh()
	_status_panel.refresh(_state.active_index)  # 👈 ISSO que atualiza os portraits!
	_log_panel.refresh()
	_refresh_context()
	_update_attack_outlines()

func _refresh_context() -> void:
	if _state.current_state == BattleState.State.ATTACK_MODE:
		if _state.attack_target_indices.is_empty():
			_context_panel.show_message("Nenhum alvo no alcance da habilidade")
		else:
			var preview: Dictionary = _state.get_attack_target_preview()
			if preview.is_empty() or preview.get("is_self", false):
				_context_panel.show_message("Escolhendo alvo...")
			else:
				_context_panel.setup(
					preview["name"],
					preview["subtitle"],
					preview["desc"],
					"← → trocar alvo   •   ESC cancelar"
				)
	elif _state.context_message != "":
		_context_panel.show_message(_state.context_message)
		_state.context_message = ""

# ======================================================
# INPUT
# ======================================================
func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	var key := (event as InputEventKey).keycode

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
			elif _state.has_moved:
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
	match event.keycode:
		KEY_LEFT, KEY_UP, KEY_A, KEY_W:    _state.cycle_attack_target(-1)
		KEY_RIGHT, KEY_DOWN, KEY_D, KEY_S: _state.cycle_attack_target(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_execute_confirm_attack()
			return
		KEY_ESCAPE: _state.cancel_attack()
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

	if item is ActionData:
		var action := item as ActionData
		match action.action_type:
			ActionData.Type.MOVE:
				_execute_action(action)
			ActionData.Type.ATTACK:
				_execute_action(action)
			ActionData.Type.END_TURN:
				var desc := ""
				if item is AcaoDefender:
					desc = "+2 AC até o próximo turno"
				elif item is AcaoEsperar:
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
		elif item.has("mp"):
			desc = "Restaura %d MP" % item["mp"]
		_action_panel.show_action_bar(item.get("label", "Item"), desc, true)
		_pending_item = item

func _execute_action(action: ActionData) -> void:
	match action.action_type:
		ActionData.Type.MOVE:
			_state.enter_move_mode()
			_refresh_ui()

		ActionData.Type.ATTACK:
			_pending_attack_mp_cost = action.mp_cost
			_state.current_damage_attribute = action.damage_attribute
			_state.current_base_dmg_min     = action.base_damage_min
			_state.current_base_dmg_max     = action.base_damage_max
			_state.enter_attack_mode(
				action.attack_range, action.targets_allies,
				action.proj_color, action.self_target,
				action.aoe_radius, action.bonus_action)
			_refresh_ui()

		ActionData.Type.END_TURN:
			_execute_end_turn_action(action)

func _execute_end_turn_action(item: ActionData) -> void:
	var pidx: int = _state.get_active_player_index()

	if item is SkillFlurry:
		if pidx >= 0:
			var p: Dictionary = BattleState.PLAYERS[pidx]
			if p["mp"] >= item.mp_cost:
				p["mp"] -= item.mp_cost
				_state.fury_extra_attack = true
				_state._log("Monge usa Flurry of Blows!", "status")
			else:
				_state._log("Ki insuficiente!", "status")
		_refresh_ui()
		return

	if item is SkillPassoVento:
		if pidx >= 0:
			var p: Dictionary = BattleState.PLAYERS[pidx]
			if p["mp"] >= item.mp_cost:
				p["mp"] -= item.mp_cost
				_state.has_moved = false
				_state._log("Monge usa Passo do Vento!", "status")
			else:
				_state._log("Ki insuficiente!", "status")
		_refresh_ui()
		return

	if item is AcaoDefender:
		_state.apply_defender_action(pidx)
	elif item is AcaoEsperar:
		if pidx >= 0 and BattleState.PLAYERS[pidx]["class"] == "Rogue":
			_state.apply_furtivo_status(pidx)
	elif item is SkillSegundoVento:
		if pidx >= 0 and item.pp > 0:
			item.pp -= 1
			var p: Dictionary = BattleState.PLAYERS[pidx]
			p["hp"] = mini(p["hp"] + 15, p["max_hp"])
			_state._log("%s usa Segundo Vento! +15 HP" % BattleState.PLAYERS[pidx]["name"], "status")
	elif item is SkillSmite:
		if pidx >= 0:
			var p: Dictionary = BattleState.PLAYERS[pidx]
			if p["mp"] >= item.mp_cost:
				p["mp"] -= item.mp_cost
				_state.apply_smite_status(pidx)
			else:
				_state._log("MP insuficiente para Smite!", "status")

	_state.advance_turn()
	_after_advance()

# ======================================================
# EXECUTE — CONFIRM MOVE
# ======================================================
func _execute_confirm_move() -> void:
	var move_path: Array[Vector2i] = _state.get_path_to(_state.move_cursor)
	_state.confirm_move()
	var both_done: bool = _state.has_moved and _state.has_attacked

	if move_path.is_empty():
		if both_done:
			_state.advance_turn()
			_after_advance()
		else:
			_refresh_ui()
		return

	_animating = true
	_battle_area.animate_move(_state.active_index, move_path, func() -> void:
		_animating = false
		var final_pos: Vector2i = _state.combatant_positions[_state.active_index]
		_state.activate_trap_after_move(_state.active_index, final_pos)
		if both_done:
			_state.advance_turn()
			_after_advance()
		else:
			_refresh_ui()
	)

# ======================================================
# EXECUTE — CONFIRM ATTACK
# ======================================================
func _execute_confirm_attack() -> void:
	var attacker_idx: int   = _state.active_index
	var target_pos: Vector2i = _state.get_attack_cursor_pos()
	var has_target: bool    = not _state.attack_target_indices.is_empty()
	var is_self: bool       = has_target and target_pos == _state.combatant_positions[attacker_idx]
	var is_ranged: bool     = _state.current_attack_range > 1 and not is_self
	var proj_color: Color   = _state.current_attack_color
	var aoe_radius: int     = _state.current_aoe_radius
	
	_state.confirm_attack()
	var both_done: bool = _state.has_moved and _state.has_attacked

	if _pending_attack_mp_cost > 0:
		_state.consume_spell_mp(_pending_attack_mp_cost)
		_pending_attack_mp_cost = 0

	if not has_target:
		if both_done:
			_state.advance_turn()
			_after_advance()
		else:
			_refresh_ui()
		return

	_animating = true
	var callback := func() -> void:
		_animating = false
		_show_floater_if_needed()
		_process_pending_deaths()
		if _check_battle_end():
			return
		if both_done:
			_state.advance_turn()
			_after_advance()
		else:
			_refresh_ui()

	if aoe_radius > 0:
		_battle_area.animate_aoe_attack(attacker_idx, target_pos, aoe_radius, proj_color, is_ranged, callback)
	elif is_ranged:
		var is_crit: bool = _state.last_attack_info.get("is_crit", false)
		_battle_area.animate_ranged_attack(attacker_idx, target_pos, proj_color, callback, is_crit)
	else:
		var is_crit: bool = _state.last_attack_info.get("is_crit", false)
		_battle_area.animate_attack(attacker_idx, target_pos, callback, is_crit)

# ======================================================
# AFTER ADVANCE
# ======================================================

func _after_advance() -> void:
	if _check_battle_end():
		return

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
				_do_enemy_turn()
			)
		else:
			_animating = false
			_refresh_ui()
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
			)
		else:
			_animating = false
			_refresh_ui()

# ======================================================
# ENEMY TURN
# ======================================================
func _do_enemy_turn() -> void:
	var path: Array[Vector2i] = _state.get_enemy_move_path()
	_state.apply_enemy_move(path)
	
	if path.is_empty():
		_enemy_do_attack()
		return

	_animating = true
	_battle_area.animate_move(_state.active_index, path, func() -> void:
		_animating = false
		var final_pos: Vector2i = _state.combatant_positions[_state.active_index]
		_state.activate_trap_after_move(_state.active_index, final_pos)
		_enemy_do_attack()
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

	_animating = true
	var is_crit: bool = _state.last_attack_info.get("is_crit", false)
	var callback := func() -> void:
		_animating = false
		_show_floater_if_needed()
		_process_pending_deaths()
		if _check_battle_end():
			return
		_state.advance_turn()
		_after_advance()

	if info.get("is_ranged", false):
		_battle_area.animate_ranged_attack(attacker_idx, target_pos, info.get("color", Color.WHITE), callback, is_crit)
	else:
		_battle_area.animate_attack(attacker_idx, target_pos, callback, is_crit)

# ======================================================
# TILE EVENTS
# ======================================================
func _on_tile_clicked(grid_pos: Vector2i) -> void:
	if _animating:
		return
	match _state.current_state:
		BattleState.State.MOVE_MODE:
			if _state.get_reachable_tiles().has(grid_pos):
				_state.move_cursor = grid_pos
				_execute_confirm_move()
		BattleState.State.ATTACK_MODE:
			for i in range(_state.attack_target_indices.size()):
				if _state.combatant_positions[_state.attack_target_indices[i]] == grid_pos:
					_state.attack_cursor_idx = i
					_execute_confirm_attack()
					return

func _on_tile_hovered(grid_pos: Vector2i) -> void:
	if _animating or _state.current_state == BattleState.State.ATTACK_MODE:
		return
	if grid_pos.x < 0 or grid_pos.x >= _state.grid_cols \
	or grid_pos.y < 0 or grid_pos.y >= _state.grid_rows:
		return

	# Verifica se há combatente na tile
	for i in range(_state.combatant_positions.size()):
		if _state.dead_indices.has(i) or _state.combatant_positions[i] != grid_pos:
			continue
		var c: Dictionary = BattleState.TURN_QUEUE[i]
		if c["is_player"]:
			var pidx := _find_player_idx(c["name"])
			if pidx >= 0:
				var p: Dictionary  = BattleState.PLAYERS[pidx]
				var st: String     = _state.get_active_status_text(i)
				_context_panel.setup(p["name"],
					"%s Nv.%d" % [p["class"], p["level"]],
					"HP %d/%d   AC %d   SPD %d%s" % [
						p["hp"], p["max_hp"], p["ac"], p["speed"],
						("  [" + st + "]") if st != "" else ""], "")
		else:
			var hp: int     = _state.enemy_hp.get(c["name"], 0)
			var max_hp: int = _state.get_enemy_max_hp(i)
			var st: String  = _state.get_active_status_text(i)
			_context_panel.setup(c["name"], c.get("type", "Inimigo"),
				"HP %d/%d   AC %d%s" % [
					hp, max_hp, c.get("ac", 10),
					("  [" + st + "]") if st != "" else ""], "")
		return

	# Nenhum combatente — mostra info do terreno
	var tile: TerrainTile = _state.tile_data_map[grid_pos.x][grid_pos.y]
	var info: Array       = _terrain_info(tile)
	if info[0] != "":
		_context_panel.setup(info[0], "Terreno", info[1], "")

# ======================================================
# SLOT EVENTS
# ======================================================
func _on_tab_clicked(idx: int) -> void:
	if _animating or _state.current_state != BattleState.State.PLAYER_TURN:
		return
	_state.active_tab      = idx
	_state.cursor_position = 0
	_refresh_ui()

func _on_slot_clicked(idx: int) -> void:
	if _animating or _state.current_state != BattleState.State.PLAYER_TURN:
		return
	var items: Array = _state.get_active_tab_items()
	if idx >= items.size():
		return
	_state.cursor_position = idx
	_execute_current_item()

func _on_slot_hovered(idx: int) -> void:
	if _state.current_state != BattleState.State.PLAYER_TURN:
		return
	if idx < 0:
		_context_panel.setup("Battle Arena", "Procedural Map", "Explore the terrain.")
		return

	var items: Array = _state.get_active_tab_items()
	if idx >= items.size():
		return

	var item      = items[idx]
	var title_str := ""
	var subtitle  := ""
	var desc      := ""
	var hint      := ""

	if item is ActionData:
		var action := item as ActionData
		title_str = action.label
		match action.action_type:
			ActionData.Type.MOVE:
				var pidx := _state.get_active_player_index()
				var spd: int = BattleState.PLAYERS[pidx]["speed"] if pidx >= 0 else 0
				subtitle = "Movimento"
				desc     = "Velocidade: %d tiles" % spd
			ActionData.Type.ATTACK:
				var dmg_range := _state.get_damage_range(action)
				if action.targets_allies:
					subtitle = "Cura  •  Alcance %d" % action.attack_range
					desc     = "Restaura %d-%d HP" % [dmg_range.x, dmg_range.y]
				else:
					subtitle = "Ataque  •  Alcance %d" % action.attack_range
					desc     = "Dano: %d-%d" % [dmg_range.x, dmg_range.y]
					if action.attack_range == 1:
						desc += "  •  20% atordoar"
					if action.aoe_radius > 0:
						desc += "  •  AoE raio %d" % action.aoe_radius
				if action.max_pp > 0:
					desc += "  •  PP %d/%d" % [action.pp, action.max_pp]
				if action.mp_cost > 0:
					desc += "  [MP: %d]" % action.mp_cost
				if action.bonus_action:
					hint = "Ação bónus — usável após atacar"
			ActionData.Type.END_TURN:
				subtitle = "Ação de turno"
	elif item is Dictionary:
		title_str = item.get("label", "")
		subtitle  = "Item  •  x%d restante(s)" % item.get("count", 0)
		if item.has("heal"):
			desc = "Restaura %d HP" % item["heal"]
		elif item.has("mp"):
			desc = "Restaura %d MP" % item["mp"]

	_context_panel.setup(title_str, subtitle, desc, hint)

# ======================================================
# BATTLE END
# ======================================================
func _check_battle_end() -> bool:
	if _state.battle_result.is_empty():
		return false

	var msg: String = "Vitória! Todos os inimigos foram derrotados!" \
		if _state.battle_result == "win" \
		else "Derrota... Todos os heróis foram eliminados."
	_context_panel.show_message(msg)

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
	
	_battle_area.show_floater(
		_state.combatant_positions[target_idx], 
		amount, 
		is_heal, 
		_state.last_attack_info.get("is_crit", false)
	)	

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
		if action.mp_cost > 0:
			desc += "  •  Custo: %d MP" % action.mp_cost
	elif action.action_type == ActionData.Type.END_TURN:
		desc = action.label
	return desc
