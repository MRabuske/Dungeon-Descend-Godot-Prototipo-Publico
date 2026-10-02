class_name ReactionPopup
extends Control

# Popup de decisão de reação no estilo BG3: painel médio ACIMA da HUD, com linha
# de contexto, lista de caixas selecionáveis (portrait + nome + custo) e botão
# "Não Reagir". 1 opção → clicar usa na hora; 2+ → selecionar + Confirmar.
#
# O jogo já pausa enquanto o popup está aberto (BattleScene._reaction_pending
# bloqueia o input e o sequenciador segura as animações). O root NÃO trava o
# mouse fora do painel (mouse_filter = IGNORE); só o painel captura o mouse.

signal reaction_decided(chosen: Array)

const PANEL_WIDTH := 560.0

var _on_done: Callable = Callable()
var _context_label: Label
var _instruction_label: Label
var _options_container: VBoxContainer
var _confirm_btn: Button
var _panel: PanelContainer

# Opções da rodada atual e seleção (trigger_types selecionados).
var _options: Array = []
var _selected: Array = []
var _option_boxes: Array = []  # Buttons, paralelo a _options

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 100
	_build_ui()
	visible = false

func _make_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.10, 0.97)
	style.set_corner_radius_all(10)
	style.set_border_width_all(2)
	style.border_color = Color(0.62, 0.52, 0.28, 0.95)  # dourado/marrom medieval
	style.set_content_margin_all(16)
	style.shadow_color = Color(0, 0, 0, 0.55)
	style.shadow_size = 8
	return style

func _build_ui() -> void:
	# Painel ancorado à base, acima da HUD, centralizado, largura fixa, cresce p/ cima.
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.add_theme_stylebox_override("panel", _make_panel_style())
	_panel.anchor_left = 0.5
	_panel.anchor_right = 0.5
	_panel.anchor_top = 1.0
	_panel.anchor_bottom = 1.0
	_panel.offset_left = -PANEL_WIDTH * 0.5
	_panel.offset_right = PANEL_WIDTH * 0.5
	_panel.offset_bottom = -(float(BattleScene.HUD_HEIGHT) + 12.0)
	_panel.offset_top = _panel.offset_bottom
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(_panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	_panel.add_child(vbox)

	_context_label = Label.new()
	_context_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_context_label.add_theme_font_size_override("font_size", 16)
	_context_label.add_theme_color_override("font_color", Color(0.65, 0.95, 0.65))
	_context_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_context_label)

	_instruction_label = Label.new()
	_instruction_label.text = "Escolha como reagir"
	_instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_instruction_label.add_theme_color_override("font_color", Color(0.80, 0.78, 0.65))
	vbox.add_child(_instruction_label)

	_options_container = VBoxContainer.new()
	_options_container.add_theme_constant_override("separation", 6)
	vbox.add_child(_options_container)

	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 14)
	vbox.add_child(btn_row)

	_confirm_btn = Button.new()
	_confirm_btn.text = "Confirmar"
	_confirm_btn.custom_minimum_size = Vector2(170, 40)
	_confirm_btn.pressed.connect(_on_confirm)
	btn_row.add_child(_confirm_btn)

	var decline_btn := Button.new()
	decline_btn.text = "Não Reagir"
	decline_btn.custom_minimum_size = Vector2(170, 40)
	decline_btn.pressed.connect(func() -> void: _resolve([]))
	btn_row.add_child(decline_btn)

# options: Array[Dictionary] — cada uma { trigger_type, label, cost_text, portrait }.
# on_done(chosen: Array) recebe a lista de trigger_types escolhidos (vazia = recusou).
func show_for(context_text: String, options: Array, on_done: Callable) -> void:
	_on_done = on_done
	_options = options
	_selected = []
	_context_label.text = context_text
	_rebuild_options()
	# Com 1 opção não há etapa de confirmação — clicar na caixa usa direto.
	_confirm_btn.visible = options.size() >= 2
	visible = true

func _rebuild_options() -> void:
	for c in _options_container.get_children():
		c.queue_free()
	_option_boxes = []
	var multi: bool = _options.size() >= 2
	for idx in range(_options.size()):
		var opt: Dictionary = _options[idx]
		var box := Button.new()
		box.toggle_mode = multi
		box.custom_minimum_size = Vector2(0, 52)
		box.focus_mode = Control.FOCUS_NONE
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		box.add_child(row)

		var portrait = opt.get("portrait", null)
		if portrait != null:
			var tex := TextureRect.new()
			tex.texture = portrait
			tex.custom_minimum_size = Vector2(40, 40)
			tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(tex)

		var name_lbl := Label.new()
		name_lbl.text = str(opt.get("label", "Reação"))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(name_lbl)

		var cost_text: String = str(opt.get("cost_text", ""))
		if cost_text != "":
			var cost_lbl := Label.new()
			cost_lbl.text = cost_text
			cost_lbl.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
			cost_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			cost_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			row.add_child(cost_lbl)

		var trigger: String = str(opt.get("trigger_type", ""))
		if multi:
			box.toggled.connect(_on_option_toggled.bind(trigger))
		else:
			box.pressed.connect(func() -> void: _resolve([trigger]))
		_options_container.add_child(box)
		_option_boxes.append(box)

func _on_option_toggled(pressed: bool, trigger: String) -> void:
	if pressed:
		if not _selected.has(trigger):
			_selected.append(trigger)
	else:
		_selected.erase(trigger)

func _on_confirm() -> void:
	# Sem nada selecionado, Confirmar equivale a não reagir.
	_resolve(_selected.duplicate())

func hide_popup() -> void:
	visible = false

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and (event as InputEventKey).pressed:
		var key := (event as InputEventKey).keycode
		match key:
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_resolve([])
			KEY_ENTER, KEY_KP_ENTER:
				get_viewport().set_input_as_handled()
				if _options.size() == 1:
					_resolve([str(_options[0].get("trigger_type", ""))])
				else:
					_resolve(_selected.duplicate())

func _resolve(chosen: Array) -> void:
	visible = false
	reaction_decided.emit(chosen)
	var cb := _on_done
	_on_done = Callable()
	if cb.is_valid():
		cb.call(chosen)
