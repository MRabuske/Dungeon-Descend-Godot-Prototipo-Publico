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
var _hint_bar: HintBar
var _end_turn_btn: Button
var _result_screen: BattleResultScreen
var _pause_menu: PauseMenu
var _turn_transition: TurnTransitionLayer
var _examine_panel: ExaminePanel
var _context_menu:  ContextMenu
var _action_tooltip: ActionTooltipPanel
var _enemy_info_panel: EnemyInfoPanel
var _animating: bool = false
# Painel de detalhes aberto pela navegação por teclado/controle (não pelo hover do mouse).
var _nav_tip_active: bool = false
var _hud_tip_allowed_prev: bool = false
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
# Exame de combatentes pela barra de turnos (Y/Tab): barra -> menu "Examinar" -> painel.
enum ExamineFocus { NONE, BAR, MENU, PANEL }
var _examine_focus: ExamineFocus = ExamineFocus.NONE
var _examine_idx: int = -1            # índice de TURN_QUEUE em exame
var _examine_via_bar: bool = false    # false = aberto pelo clique direito do mouse

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
	_end_turn_btn.focus_mode = Control.FOCUS_NONE   # só mouse: com foco, Enter/A o acionaria
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
	_log_toggle_btn.focus_mode = Control.FOCUS_NONE
	_log_toggle_btn.pressed.connect(_toggle_log)
	add_child(_log_toggle_btn)

	# Dicas de botões: canto inferior esquerdo da área de combate, acima da HUD.
	_hint_bar = HintBar.new()
	_hint_bar.z_index = 150   # acima dos sprites do grid
	_hint_bar.alignment = BoxContainer.ALIGNMENT_BEGIN
	_hint_bar.set_anchor_and_offset(SIDE_LEFT,  0.0, 12)
	_hint_bar.set_anchor_and_offset(SIDE_RIGHT, 0.75, 0)
	add_child(_hint_bar)
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
	if _hint_bar != null:
		_hint_bar.set_anchor_and_offset(SIDE_BOTTOM, 1.0, -_hud_h - 8)
		_hint_bar.set_anchor_and_offset(SIDE_TOP,    1.0, -_hud_h - 34)

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
	_action_panel.grid_nav_selected.connect(_on_nav_selected)

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
	_turn_bar.slot_clicked.connect(_switch_hero_to)

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

	# Heróis que acabaram de ficar Downed (qualquer origem de dano) → vibração.
	for _downed_idx: int in _state.pending_downed:
		InputDevice.rumble(InputRumble.DOWNED)
	_state.pending_downed.clear()

	# Herói ativo ficou incapaz no meio do bloco (Downed, Atordoado, Paralisado): o controle passa sozinho
	# ao próximo disponível; se não há mais ninguém, a vez passa (bloco terminado).
	if not _animating and not _reaction_pending and _state.battle_result.is_empty() \
			and _state.current_state == BattleState.State.PLAYER_TURN:
		match _state.pass_control_if_incapable():
			1:
				_clear_pending_actions()
			2:
				_state.advance_turn()
				_after_advance()
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
	# O mesmo botão encerra o turno do herói ativo e, num herói que já encerrou, cancela o fim de turno.
	_end_turn_btn.text = "↩\nVOLTAR" if _state.active_ended() else "⏳\nFIM"
	_status_panel.refresh(_state.active_index)  # 👈 ISSO que atualiza os portraits!
	_log_panel.refresh()
	_update_attack_outlines()
	_update_hints()

# Dicas de botões conforme o contexto do combate (os popups têm as suas próprias).
func _update_hints() -> void:
	if _hint_bar == null or _state == null:
		return
	var hints: Array = []
	if _reaction_pending or _pause_menu.visible or not _state.battle_result.is_empty():
		hints = []
	elif _examine_focus != ExamineFocus.NONE:
		hints = [[&"navigate", "Combatente"], [&"confirm", "Examinar"], [&"back", "Voltar"]]
	elif _action_panel._action_bar_active:
		hints = [[&"confirm", "Confirmar"], [&"back", "Cancelar"]]
	elif _state.current_state == BattleState.State.MOVE_MODE or _state.current_state == BattleState.State.ATTACK_MODE:
		hints = [[&"cursor", "Cursor"], [&"navigate", "Quadrado"], [&"confirm", "Confirmar"],
			[&"back", "Cancelar"], [&"camera", "Câmera"], [&"zoom", "Zoom"]]
	elif _state.current_state == BattleState.State.PLAYER_TURN:
		hints = [[&"navigate", "Ação"], [&"confirm", "Usar"], [&"tabs", "Filtro"],
			[&"end_turn", "Cancelar fim de turno" if _state.active_ended() else "Fim de turno"],
			[&"examine", "Examinar"], [&"los", "Visão inimiga"], [&"log", "Log"], [&"pause", "Pausa"]]
		if _state.switchable_members().size() > 1:
			hints.insert(1, [&"switch_hero", "Trocar herói"])
	_hint_bar.set_hints(hints)

# ======================================================
# INPUT
# ======================================================
func _input(event: InputEvent) -> void:
	if _handle_action_event(event):
		return
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

	_sync_examine_state()
	if _examine_focus != ExamineFocus.NONE:
		_handle_examine_key(event as InputEventKey)
		return

	if _action_panel._action_bar_active:
		_handle_action_bar(event as InputEventKey)
		return

	match _state.current_state:
		BattleState.State.PLAYER_TURN:  _handle_player_turn(event as InputEventKey)
		BattleState.State.MOVE_MODE:    _handle_move_mode(event as InputEventKey)
		BattleState.State.ATTACK_MODE:  _handle_attack_mode(event as InputEventKey)

# ======================================================
# INPUT — COMANDOS DO COMBATE (actions: X, Y/Tab, View, R3)
# ======================================================
# Eventos de joypad só valem com o controle já ativo: o botão que o "acorda" apenas
# troca o dispositivo (a cena roda antes do autoload InputDevice).
func _handle_action_event(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and not InputDevice.is_gamepad():
		return false
	var act: StringName = &""
	for a: StringName in [InputBindings.END_TURN, InputBindings.EXAMINE, InputBindings.LOG, InputBindings.ZOOM_CYCLE, InputBindings.SWITCH_HERO]:
		if event.is_action_pressed(a, false):
			act = a
			break
	if act == &"":
		return false
	get_viewport().set_input_as_handled()
	if _pause_menu.visible:
		return true
	match act:
		InputBindings.LOG:
			_toggle_log()
		InputBindings.ZOOM_CYCLE:
			_battle_area.cycle_zoom()
		InputBindings.SWITCH_HERO:
			_switch_hero_to_next()
		InputBindings.END_TURN:
			# Mesmos bloqueios do botão FIM: nada durante animação, reação ou exame.
			if not _reaction_pending and _examine_focus == ExamineFocus.NONE \
					and not _action_panel._action_bar_active \
					and _state.battle_result.is_empty():
				_on_end_turn_pressed()
		InputBindings.EXAMINE:
			if not _reaction_pending and not _animating and _examine_focus == ExamineFocus.NONE \
					and not _action_panel._action_bar_active \
					and _state.current_state == BattleState.State.PLAYER_TURN \
					and _state.battle_result.is_empty():
				_enter_examine()
	return true

func _toggle_log() -> void:
	if _log_panel.visible:
		_log_panel.hide()
	else:
		_log_panel.show()
		_log_panel.refresh()

# ======================================================
# EXAME DE COMBATENTES (barra de turnos)
# ======================================================
func _enter_examine() -> void:
	var idx: int = _state.examine_step(_state.active_index, 0)
	if idx < 0:
		return
	_examine_idx = idx
	_examine_via_bar = true
	_examine_focus = ExamineFocus.BAR
	_apply_examine_highlight()

func _exit_examine() -> void:
	_examine_focus = ExamineFocus.NONE
	_examine_idx = -1
	_apply_examine_highlight()
	if _examine_panel.visible:
		_examine_panel.hide_panel()
	if _context_menu != null and is_instance_valid(_context_menu):
		_context_menu.queue_free()
		_context_menu = null

func _apply_examine_highlight() -> void:
	_turn_bar.set_examine_highlight(_examine_idx)
	_battle_area.set_examine_highlight(_examine_idx)
	_update_hints()

# O painel/menu também fecham por conta própria (botão X, clique fora); realinha o
# estado com o que está de fato na tela.
func _sync_examine_state() -> void:
	if _examine_focus == ExamineFocus.PANEL and not _examine_panel.visible:
		_examine_focus = ExamineFocus.BAR if _examine_via_bar else ExamineFocus.NONE
	elif _examine_focus == ExamineFocus.MENU and (_context_menu == null or not is_instance_valid(_context_menu)):
		_examine_focus = ExamineFocus.BAR
	if _examine_focus == ExamineFocus.NONE and _examine_idx != -1:
		_examine_idx = -1
		_apply_examine_highlight()

# Anda na ordem de turnos; combatentes mortos não são selecionáveis e a ordem pode mudar
# entre um passo e outro, então a seleção é sempre saneada pelo estado.
func _examine_move(delta: int) -> void:
	var idx: int = _state.examine_step(_examine_idx, delta)
	if idx < 0:
		_exit_examine()
		return
	_examine_idx = idx
	_apply_examine_highlight()
	if _examine_focus == ExamineFocus.PANEL:
		_examine_panel.show_for(_state, _examine_idx)

func _handle_examine_key(event: InputEventKey) -> void:
	get_viewport().set_input_as_handled()
	if _state.examine_step(_examine_idx, 0) < 0:
		_exit_examine()
		return
	_examine_idx = _state.examine_step(_examine_idx, 0)
	match _examine_focus:
		ExamineFocus.BAR:
			match event.keycode:
				KEY_LEFT, KEY_A:
					_examine_move(-1)
				KEY_RIGHT, KEY_D:
					_examine_move(1)
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_open_examine_menu()
				KEY_ESCAPE:
					_exit_examine()
		ExamineFocus.MENU:
			match event.keycode:
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					_context_menu.confirm()
				KEY_ESCAPE:
					_context_menu.queue_free()
					_context_menu = null
					_examine_focus = ExamineFocus.BAR
		ExamineFocus.PANEL:
			match event.keycode:
				KEY_LEFT, KEY_A:
					_examine_move(-1)
				KEY_RIGHT, KEY_D:
					_examine_move(1)
				KEY_ESCAPE:
					_examine_panel.hide_panel()
					_examine_focus = ExamineFocus.BAR if _examine_via_bar else ExamineFocus.NONE
					if _examine_focus == ExamineFocus.NONE:
						_exit_examine()

func _open_examine_menu() -> void:
	var r: Rect2 = _turn_bar.get_slot_global_rect(_examine_idx)
	_open_context_menu(Vector2(r.position.x, r.end.y + 4.0), _examine_idx)
	_examine_focus = ExamineFocus.MENU

# ======================================================
# INPUT — PLAYER TURN
# ======================================================
func _handle_player_turn(event: InputEventKey) -> void:
	# O cursor da HUD percorre as células VISÍVEIS do grid (ActionPanel); Q/E (LB/RB)
	# trocam o filtro do grid, que é a "aba" da HUD atual.
	match event.keycode:
		KEY_UP, KEY_W:       _action_panel.nav_move(Vector2i(0, -1))
		KEY_DOWN, KEY_S:     _action_panel.nav_move(Vector2i(0, 1))
		KEY_LEFT, KEY_A:     _action_panel.nav_move(Vector2i(-1, 0))
		KEY_RIGHT, KEY_D:    _action_panel.nav_move(Vector2i(1, 0))
		KEY_Q:               _action_panel.cycle_filter(-1)
		KEY_E:               _action_panel.cycle_filter(1)
		KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6:
			# O número é o do canto da célula, o mesmo que o jogador vê no grid.
			if _action_panel.nav_select_by_number(event.keycode - KEY_1 + 1):
				_execute_current_item()
			get_viewport().set_input_as_handled()
			return
		KEY_ENTER, KEY_KP_ENTER:
			_execute_current_item()
			get_viewport().set_input_as_handled()
			return
		KEY_SPACE:
			# BG3: Space encerra o turno do herói ativo e, num herói que já encerrou, cancela o fim de turno.
			_end_or_cancel_turn()
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
		KEY_UP, KEY_W:    _step_cursor(Vector2i( 0, -1)); return
		KEY_DOWN, KEY_S:  _step_cursor(Vector2i( 0,  1)); return
		KEY_LEFT, KEY_A:  _step_cursor(Vector2i(-1,  0)); return
		KEY_RIGHT, KEY_D: _step_cursor(Vector2i( 1,  0)); return
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_confirm_cursor()
			return
		KEY_ESCAPE: _state.cancel_move()
	_refresh_ui()

# ======================================================
# INPUT — ATTACK MODE
# ======================================================
# Em TODOS os modos de mira (área, alvo único, aliado, si mesmo, Pulo) as setas/D-pad
# andam de quadrado em quadrado; a validade só é cobrada ao confirmar.
func _handle_attack_mode(event: InputEventKey) -> void:
	match event.keycode:
		KEY_UP, KEY_W:    _step_cursor(Vector2i( 0, -1)); return
		KEY_DOWN, KEY_S:  _step_cursor(Vector2i( 0,  1)); return
		KEY_LEFT, KEY_A:  _step_cursor(Vector2i(-1,  0)); return
		KEY_RIGHT, KEY_D: _step_cursor(Vector2i( 1,  0)); return
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			_confirm_cursor()
			return
		KEY_ESCAPE:
			_state.cancel_attack()
			_pending_attack_action = null
	_refresh_ui()

# ======================================================
# CURSOR DE QUADRADO (mouse, analógico, D-pad e setas dividem o mesmo cursor)
# ======================================================
func _step_cursor(delta: Vector2i) -> void:
	_state.step_cursor(delta)
	_battle_area.snap_pointer_to_tile(_state.cursor_tile)
	_refresh_ui()

# Ao entrar em MOVE/ATTACK o ponteiro vai para o cursor inicial do estado.
func _sync_cursor_on_enter() -> void:
	if _state.current_state == BattleState.State.MOVE_MODE \
			or _state.current_state == BattleState.State.ATTACK_MODE:
		_battle_area.snap_pointer_to_tile(_state.cursor_tile)

# Confirmar no cursor (Enter/A ou clique): só executa em quadrado válido. Inválido:
# mostra o motivo no quadrado, não executa nada e não consome recurso.
func _confirm_cursor() -> void:
	if not _state.apply_cursor_selection():
		var fb: Dictionary = _state.get_cursor_feedback()
		if fb["reason"] != "":
			_battle_area.show_text_floater(_state.cursor_tile, fb["reason"], FloaterManager.COLOR_MISS, 16, false)
		_refresh_ui()
		return
	if _state.current_state == BattleState.State.MOVE_MODE:
		_execute_confirm_move()
	else:
		_execute_confirm_attack()

# Barra Confirmar/Voltar: ←/→ movem o foco (o anel branco mostra qual), Enter/A aciona
# exatamente o botão focado e Esc/B volta.
func _handle_action_bar(event: InputEventKey) -> void:
	match event.keycode:
		KEY_ESCAPE:
			_action_panel._on_cancel_action()
		KEY_LEFT, KEY_A:
			if _action_panel._confirm_btn.visible:
				_action_panel._confirm_btn.grab_focus()
		KEY_RIGHT, KEY_D:
			_action_panel._back_btn.grab_focus()
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _action_panel._back_btn.has_focus() or not _action_panel._confirm_btn.visible:
				_action_panel._on_cancel_action()
			else:
				_action_panel._on_confirm_action()
		_:
			return
	get_viewport().set_input_as_handled()   # a GUI não pode acionar o botão em dobro

# ======================================================
# EXECUTE — CURRENT ITEM
# ======================================================
func _execute_current_item() -> void:
	_nav_tip_active = false
	_action_tooltip.hide_tooltip()
	var item = _action_panel.nav_selected()
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
				_update_hints()
				_pending_end_turn_action = action
	elif item is Dictionary:
		var desc := ActionTooltipPanel.item_description(item)
		_action_panel.show_action_bar(item.get("label", "Item"), desc, true)
		_update_hints()
		_pending_item = item

func _execute_action(action: ActionData) -> void:
	match action.action_type:
		ActionData.Type.MOVE:
			_state.enter_move_mode()
			_sync_cursor_on_enter()
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
				action.bonus_action)
			# Ranged sem linha de visão até nenhum alvo: avisa e volta ao neutro.
			if action.attack_range > 1 and _state.current_state == BattleState.State.ATTACK_MODE \
					and not _state.attack_tile_mode and not action.self_target \
					and not action.targets_allies and _state.attack_target_indices.is_empty():
				_state.cancel_attack()
				_pending_attack_action = null
				_state._log("Sem linha de visão até um alvo — reposicione para abrir o ângulo.", "miss")
			_sync_cursor_on_enter()
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
		_state.spend_action_cost(item)
		_refresh_ui()
		return

	# Mergulhar (Dip): gasta a Ação Bônus, reveste a arma, NÃO encerra o turno.
	if item is AcaoDip:
		_state.resolve_dip(_state.active_index)
		_state.spend_action_cost(item)
		_refresh_ui()
		return

	# Passo do Vento e Segundo Vento (BG3): Ação Bônus, NÃO encerram o turno.
	if item is SkillPassoVento:
		_state.use_step_of_the_wind(item)
		_refresh_ui()
		return
	if item is SkillSegundoVento:
		_state.use_second_wind(item)
		_refresh_ui()
		return

	if item is AcaoEsperar:
		if pidx >= 0 and BattleState.PLAYERS[pidx]["class"] == "Rogue":
			_state.apply_furtivo_status(pidx)
	_end_active_turn()

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
			if tgt >= 0 and not _state.dead_indices.has(tgt) and _state.spend_ki(monk_idx, 1):
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
		_enqueue_opportunity_attacks(mover_idx, old_pos, final_pos, move_path)
		_process_next_reaction(func() -> void:
			if _check_battle_end():
				return
			if _end_turn_if_forced():
				return
			_refresh_ui()
		)
	)

# Cair Prone no próprio turno (superfície de Gelo) encerra o turno na hora (bg3.wiki/wiki/Prone).
func _end_turn_if_forced() -> bool:
	if not _state.turn_forced_end:
		return false
	_state.turn_forced_end = false
	_end_active_turn()   # herói: só o turno DELE acaba; inimigo: avança
	return true

# Monta entradas de OA na fila para todos os reatores válidos contra mover_idx. Com `path`
# (movimento a pé) a checagem é PASSO A PASSO; sem ele (Pulo), é um salto de old_pos a new_pos.
func _enqueue_opportunity_attacks(mover_idx: int, old_pos: Vector2i, new_pos: Vector2i, path: Array[Vector2i] = []) -> void:
	# UMA regra para prévia e execução: BattleState.check_opportunity_attacks_along. O Pulo é um passo
	# único até `new_pos`; a prévia (BattleArea) faz exatamente a mesma chamada.
	var steps: Array[Vector2i] = path if not path.is_empty() else ([new_pos] as Array[Vector2i])
	var reactors: Array[int] = _state.check_opportunity_attacks_along(mover_idx, old_pos, steps)
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
	var pidx: int = _state.player_index_of(combatant_idx)
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
	var has_area: bool      = _state.current_has_area()
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

	# Arremessar Poção: a nuvem cura quem estiver na área — não passa pelo _apply_attack.
	if action is AcaoArremessarPocao:
		_state.resolve_potion_throw(target_pos)
		_state.finalize_attack()
		_pending_attack_action = null
		_flush_surface_floaters()
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
		# Janela de reação: o golpe fica pendente até a fila de reações (Smite
		# entra como componente do mesmo golpe) e só então é aplicado.
		_state.hold_hits_for_reactions = true
		_state.confirm_attack()
		_state.hold_hits_for_reactions = false
		var callback := func() -> void:
			_animating = false
			_pending_attack_action = null
			# Reações ofensivas (Smite Divino / Golpe Atordoante) precisam de um
			# alvo único — não se aplicam à detonação em ponto do chão.
			if target_idx >= 0:
				_enqueue_offensive_reactions(attacker_idx, is_ranged)
			_process_next_reaction(func() -> void:
				_state.commit_pending_hit()
				_show_floater_if_needed()
				_flush_surface_floaters()  # floaters por alvo na detonação em tile
				_process_pending_deaths()
				if _check_battle_end():
					return
				_refresh_ui()
			)
		_play_attack_animation(attacker_idx, target_pos, action, has_area, is_ranged, is_self, callback)
	else:
		_execute_multi_hit(attacker_idx, target_pos, target_idx, action, has_area, is_ranged, is_self, hit_count)

# Enfileira reações ofensivas do atacante após acertar um ataque corpo-a-corpo.
func _enqueue_offensive_reactions(attacker_idx: int, is_ranged: bool) -> void:
	if is_ranged:
		return
	if not _state.last_attack_info.get("hit", false):
		return
	if not BattleState.TURN_QUEUE[attacker_idx]["is_player"]:
		return
	var pidx: int = _state.player_index_of(attacker_idx)
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
		if _state.has_slot_at_or_above(pidx, 1):
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
	if _pending_attack_action != null and (_pending_attack_slot_level > 0 or _pending_attack_ki_cost > 0):
		_state.spend_action_cost(_pending_attack_action)
	_pending_attack_slot_level = 0
	_pending_attack_ki_cost = 0

## Despacha a animação de ataque correta (AoE / projétil / corpo-a-corpo) e
## dispara `cb` ao final.
func _play_attack_animation(attacker_idx: int, target_pos: Vector2i, action: ActionData, has_area: bool, is_ranged: bool, is_self: bool, cb: Callable) -> void:
	if has_area:
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
func _execute_multi_hit(attacker_idx: int, target_pos: Vector2i, target_idx: int, action: ActionData, has_area: bool, is_ranged: bool, is_self: bool, hit_count: int) -> void:
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
		_play_attack_animation(attacker_idx, target_pos, action, has_area, is_ranged, is_self, cb)
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
	_clear_pending_actions()

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
			# Turno compartilhado: o subtítulo lista o grupo (a Fúria do Bárbaro agora entra no início
			# do turno de cada membro, em BattleState._begin_member).
			_turn_transition.show_turn("Turno Herói", _turn_title(combatant_name), func() -> void:
				_animating = false
				if not is_inside_tree():
					return
				_refresh_ui()
				# Floaters de dano de superfície de início de turno (ex.: Mago na nuvem).
				_flush_surface_floaters()
			)
		else:
			_animating = false
			_refresh_ui()
			_flush_surface_floaters()

# Turno compartilhado (BG3): troca livre entre os heróis do bloco, só com o estado "neutro"
# (nenhuma ação, mira ou confirmação pendente) e fora de animação, reação, pausa e exame.
func _can_switch_hero() -> bool:
	return not _animating and not _reaction_pending and not _pause_menu.visible \
		and _examine_focus == ExamineFocus.NONE and _state.battle_result.is_empty() \
		and _is_neutral_player_state() and _state.switchable_members().size() > 1

func _switch_hero_to_next() -> void:
	if _can_switch_hero() and _state.cycle_active_member(1):
		_refresh_ui()

func _switch_hero_to(queue_idx: int) -> void:
	if _can_switch_hero() and _state.switch_active_member(queue_idx):
		_refresh_ui()

# Subtítulo do turno dos heróis: o nome do ativo, ou o grupo quando o turno é compartilhado.
func _turn_title(active_name: String) -> String:
	var block: Array[int] = _state.get_turn_block()
	if block.size() < 2:
		return active_name
	var names: Array[String] = []
	for m in block:
		names.append(str(BattleState.TURN_QUEUE[m]["name"]))
	return ", ".join(names) if block.size() <= 3 else "%s e mais %d" % [active_name, block.size() - 1]

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
		_enqueue_opportunity_attacks(enemy_idx, enemy_old_pos, final_pos, path)
		_process_next_reaction(func() -> void:
			if _check_battle_end():
				return
			# Se o inimigo morreu por um OA, encerra o turno dele.
			if _state.dead_indices.has(enemy_idx):
				_state.advance_turn()
				_after_advance()
				return
			# Caiu Prone no próprio turno (Gelo): o turno acaba sem atacar (BG3).
			if _end_turn_if_forced():
				return
			_enemy_do_attack()
		)
	)

func _enemy_do_attack() -> void:
	var attacker_idx: int    = _state.active_index
	# Janela de reação: o golpe fica pendente até Esquiva/Defletir decidirem.
	_state.hold_hits_for_reactions = true
	var info: Dictionary     = _state.apply_enemy_attack()
	_state.hold_hits_for_reactions = false
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
		_state.commit_pending_hit()   # dano aplicado uma vez, já reduzido pelas reações
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
	var pidx: int = _state.player_index_of(target_idx)
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
	_sync_examine_state()
	_update_nav_tooltip()
	_hint_bar.visible = not _pause_menu.visible and not _reaction_pending and _state.battle_result.is_empty()
	_action_panel.nav_enabled = not _pause_menu.visible and not _reaction_pending and _examine_focus == ExamineFocus.NONE
	InputDevice.stick_drives_cursor = _stick_drives_cursor()
	var want: bool = InputDevice.is_los_held() and _is_neutral_player_state() and not _animating
	if want != _los_overlay_on:
		_los_overlay_on = want
		_battle_area.set_los_overlay(want, _state.get_enemy_vision_tiles() if want else {})

func _exit_tree() -> void:
	InputDevice.stick_drives_cursor = false

# O analógico esquerdo move o cursor livre do grid só enquanto há um modo de grid ativo
# e nada mais (animação, reação, pausa, exame, barra de confirmação) está no controle.
func _stick_drives_cursor() -> bool:
	return (_state.current_state == BattleState.State.MOVE_MODE \
			or _state.current_state == BattleState.State.ATTACK_MODE) \
		and not _animating and not _reaction_pending and not _pause_menu.visible \
		and not _action_panel._action_bar_active and _examine_focus == ExamineFocus.NONE \
		and _state.battle_result.is_empty()

# O hover (mouse ou analógico) move o cursor de quadrado de MOVE/ATTACK: o quadrado sob
# o ponteiro é o selecionado, qualquer um, alcançável ou não.
func _on_tile_hovered(grid_pos: Vector2i) -> void:
	if _state == null:
		return
	if _state.current_state != BattleState.State.MOVE_MODE \
			and _state.current_state != BattleState.State.ATTACK_MODE:
		return
	_state.set_cursor_tile(grid_pos)
	_update_attack_outlines()
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
			# Turno compartilhado: clicar em OUTRO herói do bloco passa o controle para ele.
			for member in _state.switchable_members():
				if member != _state.active_index and _state.combatant_positions[member] == grid_pos:
					_switch_hero_to(member)
					return
			if _is_neutral_player_state() and _state.move_points_remaining > 0:
				var self_pos: Vector2i = _state.combatant_positions[_state.active_index]
				if absi(grid_pos.x - self_pos.x) <= 1 and absi(grid_pos.y - self_pos.y) <= 1:
					_state.enter_move_mode()
					_sync_cursor_on_enter()
					_refresh_ui()
		BattleState.State.MOVE_MODE, BattleState.State.ATTACK_MODE:
			# Clicar = selecionar o quadrado e confirmar: a mesma regra do Enter/A.
			_state.set_cursor_tile(grid_pos)
			_confirm_cursor()

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
# `action` é ActionData (células) ou Dictionary (itens), por isso sem tipo.
func _on_action_hovered(action) -> void:
	if _action_tooltip == null:
		return
	_nav_tip_active = false   # o mouse assumiu o painel
	if action == null or _state == null or _state.current_state != BattleState.State.PLAYER_TURN:
		_action_tooltip.hide_tooltip()
		return
	_action_tooltip.show_for(action)

# Seleção por teclado/controle: o mesmo painel do hover, junto ao item sob o anel.
func _on_nav_selected(subject, anchor: Rect2) -> void:
	if _action_tooltip == null:
		return
	if subject == null or not _hud_tooltip_allowed():
		_nav_tip_active = false
		_action_tooltip.hide_tooltip()
		return
	_nav_tip_active = true
	_action_tooltip.show_for(subject, anchor)

# A HUD só mostra detalhes quando é ela quem recebe os comandos.
func _hud_tooltip_allowed() -> bool:
	return _state != null and _state.current_state == BattleState.State.PLAYER_TURN and not _animating and not _reaction_pending and not _pause_menu.visible and _examine_focus == ExamineFocus.NONE and not _action_panel._action_bar_active and _state.battle_result.is_empty()

# Esconde o painel da navegação quando a HUD deixa de receber os comandos (mover, mirar,
# exame, pausa, reação, fim de turno). No controle, ao voltar à HUD o painel reaparece.
func _update_nav_tooltip() -> void:
	var allowed := _hud_tooltip_allowed()
	if _nav_tip_active and not allowed:
		_nav_tip_active = false
		_action_tooltip.hide_tooltip()
	if allowed and not _hud_tip_allowed_prev and InputDevice.is_gamepad():
		_action_panel.announce_selection()
	_hud_tip_allowed_prev = allowed

# Element B: shows/hides the fixed top-of-screen enemy info panel as the hovered
# attack target changes (cidx is a TURN_QUEUE index, or -1 for none).
func _on_attack_hover_changed(cidx: int) -> void:
	if _enemy_info_panel == null:
		return
	if cidx < 0 or _state == null or cidx >= BattleState.TURN_QUEUE.size():
		_enemy_info_panel.hide_panel()
		return
	var combatant: Dictionary = BattleState.TURN_QUEUE[cidx]
	_enemy_info_panel.show_for(combatant, _state.get_hp(cidx), maxi(1, _state.get_max_hp(cidx)))

func _on_end_turn_pressed() -> void:
	if _animating or _state.current_state != BattleState.State.PLAYER_TURN:
		return
	_end_or_cancel_turn()

# Ação ou seleção pendente some quando o controle muda de herói ou de turno.
func _clear_pending_actions() -> void:
	_pending_attack_action = null
	_pending_end_turn_action = null
	_pending_item = {}
	_pending_attack_slot_level = 0
	_pending_attack_ki_cost = 0

# Fim de turno e "cancelar fim de turno" usam o MESMO comando (BG3, bg3.wiki "Controls": Space; no
# controle é o botão X do jogo, porque o Y daqui é Examinar): no herói que ainda age, encerra o turno
# DELE; num herói que já encerrou (selecionado pelo retrato), cancela e ele volta a agir.
func _end_or_cancel_turn() -> void:
	if _state.active_ended():
		if _state.cancel_member_end(_state.active_index):
			_clear_pending_actions()
			_refresh_ui()
		return
	_end_active_turn()

# Encerra só o turno do herói ativo; o controle passa ao próximo que ainda age, e a vez só passa
# adiante quando o último herói disponível do bloco encerra. Inimigo: avança direto.
func _end_active_turn() -> void:
	if not BattleState.TURN_QUEUE[_state.active_index]["is_player"]:
		_state.advance_turn()
		_after_advance()
		return
	match _state.end_member_turn():
		BattleState.EndResult.BLOCK_DONE:
			_state.advance_turn()
			_after_advance()
		BattleState.EndResult.SWITCHED:
			_clear_pending_actions()
			_action_panel.hide_action_bar()
			_refresh_ui()

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
	# Vibração: crítico causado/recebido por herói. Marca o golpe para não vibrar duas
	# vezes se este método rodar de novo sobre o mesmo last_attack_info.
	var rumble_kind: StringName = _state.hit_rumble_kind(_state.last_attack_info)
	if rumble_kind != &"" and not _state.last_attack_info.get("rumbled", false):
		_state.last_attack_info["rumbled"] = true
		InputDevice.rumble(rumble_kind)
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
	
	_battle_area._combatant_layer.update_single_combatant_hp(target_idx, _state.get_hp(target_idx), _state.get_max_hp(target_idx))

	# Display estilo BG3: o floater principal mostra só o dano base da arma
	# (dados + atributo); cada componente extra (Furtivo, Smite) aparece como um
	# floater próprio em sequência, nunca somado num único número.
	var smite_amount: int = _state.last_attack_info.get("smite_amount", 0)
	var status_bonus_amount: int = _state.last_attack_info.get("status_bonus_amount", 0)
	var status_bonus_label: String = _state.last_attack_info.get("status_bonus_label", "")
	var base_amount: int = maxi(1, amount - smite_amount - status_bonus_amount)

	var dtype = _state.last_attack_info.get("damage_type", ActionData.DamageType.BLUDGEONING)
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
		var is_heal: bool = hit.get("is_heal", false)
		if not is_heal:
			_battle_area.show_hit_flash(idx)
		# Número de dano em roxo vivo (tema da nuvem) + rótulo do tipo, no mesmo
		# estilo dos floaters de bônus (Furtivo/Smite), para ficar bem visível. A
		# detonação de AoE em tile pode sobrescrever com a cor do tipo de dano.
		var surf_color: Color = hit.get("color", Color(0.78, 0.45, 1.0))
		_battle_area.show_floater(pos, hit.get("damage", 0), is_heal, false, surf_color)
		var hit_label: String = hit.get("label", "")
		if hit_label != "":
			_battle_area.show_text_floater(pos, hit_label, surf_color, 14, false)
		# Atualiza a barra de HP imediatamente para refletir o dano de superfície.
		_battle_area._combatant_layer.update_single_combatant_hp(idx, _state.get_hp(idx), _state.get_max_hp(idx))
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
func _terrain_info(tile: TerrainTile) -> Array:
	if tile.effect == TerrainTile.EffectType.TRAP_ACTIVE:
		return ["Armadilha Ativada", "Dano e veneno ao pisar!"]
	if tile.object != TerrainTile.ObjectType.NONE:
		match tile.object:
			TerrainTile.ObjectType.STATUE:   return ["Estátua",    "Obstáculo decorativo."]
			TerrainTile.ObjectType.OBSTACLE: return ["Obstáculo",  "Bloqueia passagem."]
			TerrainTile.ObjectType.COVER:    return ["Cobertura",  "Bloqueia o movimento e a linha de visão."]
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
	
	# Destacado = o alvo válido sob o cursor (mouse, analógico, D-pad ou setas).
	var selected := -1
	# Em mira de cruzamento o cursor não é uma casa: não destaca criatura nenhuma.
	var under_cursor: int = -1 if _state.attack_corner_mode else _state._combatant_at(_state.cursor_tile)
	if under_cursor >= 0 and _state.attack_target_indices.has(under_cursor):
		selected = under_cursor
	
	_battle_area.update_combatant_outlines(available, selected)

func _get_action_description(action: ActionData) -> String:
	var desc := ""
	if action.action_type == ActionData.Type.ATTACK:
		var dmg_range := _state.get_damage_range(action)
		if action.targets_allies:
			desc = "Cura %d-%d HP  •  Alcance %d" % [dmg_range.x, dmg_range.y, action.attack_range]
		else:
			desc = "Dano: %d-%d  •  Alcance: %d" % [dmg_range.x, dmg_range.y, action.attack_range]
			if action.has_area():
				desc += "  •  " + action.area_text()
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
	_examine_via_bar = false
	_open_context_menu(global_mouse_pos, slot_index)

func _open_context_menu(pos: Vector2, slot_index: int) -> void:
	if _context_menu != null and is_instance_valid(_context_menu):
		_context_menu.queue_free()
	_context_menu = ContextMenu.new()
	add_child(_context_menu)
	_context_menu.examine_requested.connect(_on_examine_requested)
	_context_menu.show_at(pos, slot_index)

func _on_examine_requested(slot_index: int) -> void:
	_context_menu = null
	_examine_idx = slot_index
	_examine_focus = ExamineFocus.PANEL
	_apply_examine_highlight()
	_examine_panel.show_for(_state, slot_index)
