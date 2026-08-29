class_name PartySelect
extends Control

# ======================================================
# 🎨 ASSETS
# ======================================================
const BG_TEXTURE   := preload("res://assets/ui/backgrounds/menu_bg.png")
const LOGO_TEXTURE := preload("res://assets/ui/logo/party_select_logo.png")

const BTN_NORMAL  := preload("res://assets/ui/buttons/btn_normal.png")
const BTN_HOVER   := preload("res://assets/ui/buttons/btn_hover.png")
const BTN_PRESSED := preload("res://assets/ui/buttons/btn_pressed.png")

const CARD_NORMAL   := preload("res://assets/ui/cards/card_normal.png")
const CARD_SELECTED := preload("res://assets/ui/cards/card_selected.png")

const SCROLL_BG_TEXTURE   := preload("res://assets/ui/scrollbar/scroll_bg.png")
const SCROLL_FILL_TEXTURE := preload("res://assets/ui/scrollbar/scroll_fill.png")

# Ícones individuais por herói — chave deve bater com BattleState.ALL_HERO_DATA.keys()
const HERO_ICONS: Dictionary = {
	"Guerreiro": preload("res://assets/ui/icons/party_select/icon_guerreiro.png"),
	"Mago":      preload("res://assets/ui/icons/party_select/icon_mago.png"),
	"Arqueiro":  preload("res://assets/ui/icons/party_select/icon_arqueiro.png"),
	"Clérigo":   preload("res://assets/ui/icons/party_select/icon_clerigo.png"),
	"Ladrao":    preload("res://assets/ui/icons/party_select/icon_ladrao.png"),
	"Bárbaro":   preload("res://assets/ui/icons/party_select/icon_barbaro.png"),
	"Monge":     preload("res://assets/ui/icons/party_select/icon_monge.png"),
	"Paladino":  preload("res://assets/ui/icons/party_select/icon_paladino.png"),
}

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE DE TAMANHOS
# ──────────────────────────────────────────────────────
const CARD_WIDTH        := 200   # largura — aumentar aqui não afeta o texto
const CARD_HEIGHT       := 280   # altura do card
const CARD_PATCH        := 24    # nine-patch margin
const CARD_MARGIN_H     := 35    # margem horizontal interna do card
const CARD_MARGIN_V     := 0     # margem vertical interna
const CARD_SEPARATION  := 5     # separação entre elementos
const ICON_SIZE        := 35    # tamanho do ícone (largura e altura)
const ICON_TOP_MARGIN  := 35    # margem do ícone em relação ao topo do card
const ICON_AREA_HEIGHT := 60    # altura reservada para o ícone no topo
const FONT_NAME        := 13
const FONT_CLASS       := 10
const FONT_STAT        := 10
const CARD_ZOOM_SEL    := 1.02  # escala do card selecionado

# 🔽 AJUSTES DE ANIMAÇÃO COM SELEÇÃO
const ICON_SELECTED_OFFSET       := 8.0   # Quantos pixels o ícone vai DESCER ao selecionar
const TEXT_TOP_UNSELECTED_OFFSET := 15.0   # Folga que some ao deselecionar (fazendo o texto SUBIR)
# ──────────────────────────────────────────────────────
const STATS_TOP_MARGIN := 25.0  # <- Aumente este valor se quiser empurrar os stats ainda mais para baixo

# ======================================================
# VARS
# ======================================================
var _selected: Dictionary = {}
var _cards:    Dictionary = {}   # hname -> NinePatchRect
var _icons:    Dictionary = {}   # hname -> TextureRect
var _text_spacers: Dictionary = {} # hname -> Control (espaçador do topo do texto)
var _start_btn: TextureButton
var _counter_lbl: Label
var _scroll: ScrollContainer
var _scroll_fill: NinePatchRect  # fill da barra customizada
var _scroll_track: Control       # track clicável

var _hero_names: Array[String] = []
var _cursor: int = 0
var _area: int = 0       # 0 = cards, 1 = botões
var _btn_cursor: int = 0 # 0 = Voltar, 1 = Iniciar
var _back_btn: TextureButton

# ======================================================
# READY
# ======================================================
func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	_build_background()
	_build_layout()

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
	var center := VBoxContainer.new()
	center.anchor_left   = 0.5
	center.anchor_right  = 0.5
	center.anchor_top    = 0.5
	center.anchor_bottom = 0.5
	center.offset_left   = -500
	center.offset_right  =  500
	center.offset_top    = -300
	center.offset_bottom =  300
	center.add_theme_constant_override("separation", 14)
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(center)

	_build_logo(center)
	_build_header_labels(center)
	_build_cards_section(center)
	_build_custom_scrollbar(center)
	_build_buttons_row(center)

	_update_counter()
	_update_start_btn()

	center.modulate.a = 0.0
	create_tween().tween_property(center, "modulate:a", 1.0, 0.4)

# ======================================================
# BUILD — LOGO
# ======================================================
func _build_logo(parent: Control) -> void:
	var logo := TextureRect.new()
	logo.texture               = LOGO_TEXTURE
	logo.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size   = Vector2(0, 90)
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(logo)

# ======================================================
# BUILD — LABELS DO HEADER
# ======================================================
func _build_header_labels(parent: Control) -> void:
	var sub := Label.new()
	sub.text = "Escolha até 4 heróis (mínimo 1)"
	sub.add_theme_font_size_override("font_size", 13)
	sub.add_theme_color_override("font_color", Color(0.52, 0.52, 0.60))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(sub)

	_counter_lbl = Label.new()
	_counter_lbl.add_theme_font_size_override("font_size", 14)
	_counter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(_counter_lbl)

# ======================================================
# BUILD — SCROLL CONTAINER DOS CARDS
# ======================================================
func _build_cards_section(parent: Control) -> void:
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.custom_minimum_size    = Vector2(0, CARD_HEIGHT + 20)  # espaço extra total
	_scroll.size_flags_horizontal  = Control.SIZE_EXPAND_FILL

	_scroll.get_h_scroll_bar().modulate.a = 0.0
	_scroll.add_theme_stylebox_override("scroll", StyleBoxEmpty.new())

	parent.add_child(_scroll)

	# Cria um Control vazio que servirá como "padding top"
	var top_padding := Control.new()
	top_padding.custom_minimum_size = Vector2(0, 40)  # metade do espaço extra
	_scroll.add_child(top_padding)

	# O row (HBoxContainer) continua igual, mas agora é filho do top_padding? Não.
	# Precisamos de um container vertical simples que empilhe o padding e o row.
	# O problema anterior era que o VBoxContainer não tinha altura definida.
	# Vamos usar um VBoxContainer com altura explícita e um row com altura fixa.
	
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Define a altura total do VBox igual à altura do Scroll (CARD_HEIGHT + 80)
	vbox.custom_minimum_size = Vector2(0, CARD_HEIGHT + 40)
	_scroll.add_child(vbox)
	
	# Espaçador superior flexível (vai ocupar todo espaço disponível acima do row)
	var spacer_top := Control.new()
	spacer_top.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_top)
	
	# Row dos cards
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Importante: row não deve expandir verticalmente, pois tem altura fixa (CARD_HEIGHT)
	row.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vbox.add_child(row)
	
	# Espaçador inferior flexível (mesmo tamanho do top, para centralizar)
	var spacer_bottom := Control.new()
	spacer_bottom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(spacer_bottom)

	for hname: String in BattleState.ALL_HERO_DATA.keys():
		_hero_names.append(hname)
		_selected[hname] = false
		var card := _build_card(hname)
		_cards[hname] = card
		row.add_child(card)
		_update_card_visual(hname, false)

	_set_cursor(0, false)

	_scroll.get_h_scroll_bar().changed.connect(_update_scroll_fill)
	_scroll.get_h_scroll_bar().value_changed.connect(func(_v: float): _update_scroll_fill())
# ======================================================
# BUILD — BARRA DE SCROLL CUSTOMIZADA
# ======================================================
func _build_custom_scrollbar(parent: Control) -> void:
	var wrapper := Control.new()
	wrapper.custom_minimum_size   = Vector2(0, 35)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(wrapper)

	_scroll_track = Control.new()
	_scroll_track.anchor_left   = 0.10
	_scroll_track.anchor_right  = 0.90
	_scroll_track.anchor_top    = 0.0
	_scroll_track.anchor_bottom = 1.0
	_scroll_track.mouse_filter  = Control.MOUSE_FILTER_STOP
	wrapper.add_child(_scroll_track)

	var track_bg := NinePatchRect.new()
	track_bg.texture              = SCROLL_BG_TEXTURE
	track_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	track_bg.patch_margin_left   = 8
	track_bg.patch_margin_right  = 8
	track_bg.patch_margin_top    = 4
	track_bg.patch_margin_bottom = 4
	track_bg.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	_scroll_track.add_child(track_bg)

	_scroll_fill = NinePatchRect.new()
	_scroll_fill.texture              = SCROLL_FILL_TEXTURE
	_scroll_fill.patch_margin_left    = 2
	_scroll_fill.patch_margin_right   = 2
	_scroll_fill.patch_margin_top     = 4
	_scroll_fill.patch_margin_bottom  = 4
	_scroll_fill.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	_scroll_track.add_child(_scroll_fill)

	_scroll_track.gui_input.connect(_on_scrolltrack_input)

# ======================================================
# INPUT — TRACK DO SCROLL
# ======================================================
func _on_scrolltrack_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	var mm := ev as InputEventMouseMotion

	if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		_seek_scroll_to_mouse(mb.position.x)

	if mm and (mm.button_mask & MOUSE_BUTTON_MASK_LEFT):
		_seek_scroll_to_mouse(mm.position.x)

func _seek_scroll_to_mouse(local_x: float) -> void:
	var hbar := _scroll.get_h_scroll_bar()
	var ratio := clampf(local_x / _scroll_track.size.x, 0.0, 1.0)
	hbar.value = ratio * (hbar.max_value - hbar.page)

# ======================================================
# UPDATE — POSIÇÃO DO FILL DO SCROLL
# ======================================================
func _update_scroll_fill() -> void:
	var hbar := _scroll.get_h_scroll_bar()
	var scrollable := hbar.max_value - hbar.page
	if scrollable <= 0.0:
		_scroll_fill.visible = false
		return

	_scroll_fill.visible = true
	var track_w  := _scroll_track.size.x
	var ratio    := hbar.page / hbar.max_value
	var fill_w   := maxf(track_w * ratio, 24.0)
	var fill_x   := (hbar.value / scrollable) * (track_w - fill_w)

	_scroll_fill.position = Vector2(fill_x, 0.0)
	_scroll_fill.size     = Vector2(fill_w, _scroll_track.size.y)

# ======================================================
# BUILD — CARD INDIVIDUAL
# ======================================================
func _build_card(hname: String) -> NinePatchRect:
	var data: HeroData = BattleState.ALL_HERO_DATA[hname]

	var card := NinePatchRect.new()
	card.texture              = CARD_NORMAL
	card.custom_minimum_size  = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.patch_margin_left    = CARD_PATCH
	card.patch_margin_right   = CARD_PATCH
	card.patch_margin_top     = CARD_PATCH
	card.patch_margin_bottom  = CARD_PATCH
	card.mouse_filter         = Control.MOUSE_FILTER_STOP
	card.pivot_offset         = Vector2(CARD_WIDTH * 0.5, CARD_HEIGHT * 0.5)

	# ── ÍCONE ──
	if HERO_ICONS.has(hname):
		var icon := TextureRect.new()
		icon.texture             = HERO_ICONS[hname]
		icon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		icon.position = Vector2((CARD_WIDTH - ICON_SIZE) * 0.5, ICON_TOP_MARGIN)
		icon.size = Vector2(ICON_SIZE, ICON_SIZE)
		icon.pivot_offset = Vector2(ICON_SIZE * 0.5, ICON_SIZE * 0.5)
		card.add_child(icon)
		_icons[hname] = icon

	# ── CONTEÚDO ──
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",   CARD_MARGIN_H)
	margin.add_theme_constant_override("margin_right",  CARD_MARGIN_H)
	margin.add_theme_constant_override("margin_top",    ICON_TOP_MARGIN + ICON_AREA_HEIGHT -20)
	margin.add_theme_constant_override("margin_bottom", CARD_MARGIN_V)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", CARD_SEPARATION)
	vbox.alignment    = BoxContainer.ALIGNMENT_BEGIN
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(vbox)

	# 🆕 Espaçador dinâmico do topo (ele vai mudar de tamanho para empurrar o texto)
	var text_top_spacer := Control.new()
	text_top_spacer.custom_minimum_size = Vector2(0, 0)
	vbox.add_child(text_top_spacer)
	_text_spacers[hname] = text_top_spacer

	# Nome
	var name_lbl := Label.new()
	name_lbl.text = hname
	name_lbl.add_theme_font_size_override("font_size", FONT_NAME)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.90, 0.82))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode        = TextServer.AUTOWRAP_OFF
	name_lbl.clip_contents        = true
	name_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# Classe
	var class_lbl := Label.new()
	class_lbl.text = data.hero_class
	class_lbl.add_theme_font_size_override("font_size", FONT_CLASS)
	class_lbl.add_theme_color_override("font_color", Color(0.55, 0.62, 0.80))
	class_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	class_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(class_lbl)

	# Espaçador do meio
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, STATS_TOP_MARGIN)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(spacer)

	for pair: Array in [
		["HP",  "%d / %d" % [data.base_hp, data.max_hp]],
		["MP",  "%d / %d" % [data.base_mp, data.max_mp]],
		["AC",  str(data.ac)],
		["SPD", str(data.speed)],
	]:
		vbox.add_child(_build_stat_row(pair[0], pair[1]))

	card.gui_input.connect(func(ev: InputEvent) -> void:
		var mb := ev as InputEventMouseButton
		if mb and mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_toggle_hero(hname)
	)

	return card

# ======================================================
# BUILD — LINHA DE STAT
# ======================================================
func _build_stat_row(key: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var key_lbl := Label.new()
	key_lbl.text = key
	key_lbl.add_theme_font_size_override("font_size", FONT_STAT)
	key_lbl.add_theme_color_override("font_color", Color(0.55, 0.62, 0.80))
	key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(key_lbl)

	var val_lbl := Label.new()
	val_lbl.text = value
	val_lbl.add_theme_font_size_override("font_size", FONT_STAT)
	val_lbl.add_theme_color_override("font_color", Color(0.82, 0.84, 0.90))
	val_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(val_lbl)

	return row

# ======================================================
# BUILD — BOTÕES
# ======================================================
func _build_buttons_row(parent: Control) -> void:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	parent.add_child(row)

	_back_btn = _add_texture_button(row, "Voltar", func() -> void:
		SceneTransition.fade_to("res://ui/main_menu.tscn")
	)
	_back_btn.modulate = Color(1.0, 0.5, 0.5)

	_start_btn = _add_texture_button(row, "Iniciar Batalha", _on_start)

	var hint := Label.new()
	hint.text = "← → Navegar   ·   ENTER Selecionar   ·   ↑ ↓ Mudar área   ·   F Confirmar   ·   ESC Voltar"
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.45, 0.45, 0.50))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(hint)

# ======================================================
# INPUT
# ======================================================
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not (event as InputEventKey).pressed:
		return
	match (event as InputEventKey).keycode:
		KEY_LEFT, KEY_A:
			if _area == 0:
				_move_cursor(-1)
			else:
				_move_btn_cursor(-1)
		KEY_RIGHT, KEY_D:
			if _area == 0:
				_move_cursor(1)
			else:
				_move_btn_cursor(1)
		KEY_UP, KEY_W:
			if _area == 1:
				_set_area(0)
		KEY_DOWN, KEY_S:
			if _area == 0:
				_set_area(1)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			if _area == 0:
				if not _hero_names.is_empty():
					_toggle_hero(_hero_names[_cursor])
			else:
				_press_focused_btn()
		KEY_F:
			if not _start_btn.disabled:
				_on_start()
		KEY_ESCAPE:
			SceneTransition.fade_to("res://ui/main_menu.tscn")

# ── cards ──────────────────────────────────────────────
func _move_cursor(delta: int) -> void:
	_set_cursor((_cursor + delta + _hero_names.size()) % _hero_names.size(), true)

func _set_cursor(idx: int, scroll: bool) -> void:
	if not _hero_names.is_empty():
		_cards[_hero_names[_cursor]].modulate = Color.WHITE
	_cursor = idx
	if _area == 0:
		_cards[_hero_names[_cursor]].modulate = Color(1.18, 1.12, 0.88)
	if scroll:
		_scroll_to_cursor()

func _scroll_to_cursor() -> void:
	if _hero_names.is_empty():
		return
	var card_step := float(CARD_WIDTH + 16)
	var target := _cursor * card_step - (_scroll.size.x - CARD_WIDTH) * 0.5
	create_tween().tween_property(_scroll, "scroll_horizontal", int(maxf(0.0, target)), 0.15)

# ── área / botões ──────────────────────────────────────
func _set_area(area: int) -> void:
	_area = area
	if area == 0:
		_set_btn_visual(_btn_cursor, false)
		_cards[_hero_names[_cursor]].modulate = Color(1.18, 1.12, 0.88)
	else:
		_cards[_hero_names[_cursor]].modulate = Color.WHITE
		if _btn_cursor == 1 and _start_btn.disabled:
			_btn_cursor = 0
		_set_btn_visual(_btn_cursor, true)

func _move_btn_cursor(delta: int) -> void:
	_set_btn_visual(_btn_cursor, false)
	var next := (_btn_cursor + delta + 2) % 2
	if next == 1 and _start_btn.disabled:
		next = 0
	_btn_cursor = next
	_set_btn_visual(_btn_cursor, true)

func _set_btn_visual(idx: int, focused: bool) -> void:
	var btn := _back_btn if idx == 0 else _start_btn
	btn.texture_normal = BTN_HOVER if focused else BTN_NORMAL

func _press_focused_btn() -> void:
	if _btn_cursor == 0:
		SceneTransition.fade_to("res://ui/main_menu.tscn")
	elif not _start_btn.disabled:
		_on_start()

# ======================================================
# TOGGLE HERO
# ======================================================
func _toggle_hero(hname: String) -> void:
	if _selected.get(hname, false):
		_selected[hname] = false
	else:
		if _count_selected() >= 4:
			return
		_selected[hname] = true

	_update_card_visual(hname, true)
	_update_counter()
	_update_start_btn()

# ======================================================
# UPDATE — VISUAL DO CARD
# ======================================================
func _update_card_visual(hname: String, animate: bool) -> void:
	var card := _cards.get(hname) as NinePatchRect
	if card == null:
		return

	var is_sel: bool = _selected.get(hname, false)
	card.texture = CARD_SELECTED if is_sel else CARD_NORMAL

	var target_scale := Vector2.ONE * CARD_ZOOM_SEL if is_sel else Vector2.ONE

	# 1. Posição Y do Ícone (Desce se selecionado)
	var base_icon_x := (CARD_WIDTH - ICON_SIZE) * 0.5
	var target_icon_y := ICON_TOP_MARGIN + (ICON_SELECTED_OFFSET if is_sel else 0.0)
	var target_icon_pos := Vector2(base_icon_x, target_icon_y)

	# 2. Altura do espaçador do texto (Fica maior quando selecionado, fazendo o texto descer)
	var target_spacer_h := TEXT_TOP_UNSELECTED_OFFSET if is_sel else 0.0
	var target_spacer_size := Vector2(0, target_spacer_h)

	var icon := _icons.get(hname) as TextureRect
	var text_spacer := _text_spacers.get(hname) as Control

	if animate:
		var tween := card.create_tween().set_parallel(true)
		
		# Animação de escala do card
		tween.tween_property(card, "scale", target_scale, 0.12) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			
		# Animação do ícone descendo
		if icon:
			tween.tween_property(icon, "position", target_icon_pos, 0.12) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
				
		# 🆕 Animação do espaçador (Muda o tamanho dinamicamente movendo o texto sem quebrar o VBox)
		if text_spacer:
			tween.tween_property(text_spacer, "custom_minimum_size", target_spacer_size, 0.12) \
				.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	else:
		card.scale = target_scale
		if icon:
			icon.position = target_icon_pos
		if text_spacer:
			text_spacer.custom_minimum_size = target_spacer_size

# ======================================================
# UPDATE — CONTADOR
# ======================================================
func _update_counter() -> void:
	var count := _count_selected()
	_counter_lbl.text = "%d / 4 selecionados" % count
	_counter_lbl.add_theme_color_override(
		"font_color",
		Color(0.4, 1.0, 0.5) if count >= 1 else Color(0.8, 0.4, 0.4)
	)

# ======================================================
# UPDATE — BOTÃO INICIAR
# ======================================================
func _update_start_btn() -> void:
	var enabled := _count_selected() > 0
	_start_btn.disabled = not enabled
	_start_btn.modulate  = Color.WHITE if enabled else Color(0.45, 0.45, 0.50, 0.60)

# ======================================================
# HELPERS
# ======================================================
func _count_selected() -> int:
	var c := 0
	for v: bool in _selected.values():
		if v: c += 1
	return c

func _add_texture_button(parent: Control, text: String, cb: Callable) -> TextureButton:
	var btn := TextureButton.new()
	btn.texture_normal        = BTN_NORMAL
	btn.texture_hover         = BTN_HOVER
	btn.texture_pressed       = BTN_PRESSED
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

# ======================================================
# ON START
# ======================================================
func _on_start() -> void:
	var selected_names: Array[String] = []
	for hname: String in BattleState.ALL_HERO_DATA.keys():
		if _selected.get(hname, false):
			selected_names.append(hname)
	if selected_names.is_empty():
		return

	BattleState.setup_party(selected_names)

	if DungeonState.current_run != null:
		DungeonState.current_run.party_names = selected_names.duplicate()
		DungeonState.current_run.save()
		SceneTransition.fade_to("res://ui/dungeon_map.tscn")
	else:
		SceneTransition.fade_to("res://battle/battle_scene.tscn")
