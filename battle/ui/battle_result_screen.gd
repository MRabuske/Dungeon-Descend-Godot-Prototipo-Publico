class_name BattleResultScreen
extends Control

signal continue_requested
signal restart_requested

# ======================================================
# 🎨 ASSETS
# ======================================================
const FRAME_VICTORY := preload("res://assets/ui/result/victory_frame.png")
const FRAME_DEFEAT  := preload("res://assets/ui/result/defeat_frame.png")

const TITLE_VICTORY := preload("res://assets/ui/result/victory_title.png")
const TITLE_DEFEAT  := preload("res://assets/ui/result/defeat_title.png")

const DIVIDER_VICTORY := preload("res://assets/ui/result/victory_divider.png")
const DIVIDER_DEFEAT  := preload("res://assets/ui/result/defeat_divider.png")

const ICON_TURNS   := preload("res://assets/ui/result/icons/icon_turns.png")
const ICON_DMG_OUT := preload("res://assets/ui/result/icons/icon_dmg_out.png")
const ICON_DMG_IN  := preload("res://assets/ui/result/icons/icon_dmg_in.png")
const ICON_CRITS   := preload("res://assets/ui/result/icons/icon_crits.png")
const ICON_KILLS   := preload("res://assets/ui/result/icons/icon_kills.png")
const ICON_DEATHS  := preload("res://assets/ui/result/icons/icon_deaths.png")

const STAT_ROW_BG := preload("res://assets/ui/result/stat_row_bg.png")

const HERO_HP_BG        := preload("res://assets/ui/result/hero_hp_bar_bg.png")
const HERO_HP_FILL_LIVE := preload("res://assets/ui/result/hero_hp_bar_fill.png")
const HERO_HP_FILL_DEAD := preload("res://assets/ui/result/hero_hp_bar_fill.png")
const HERO_ICON_ALIVE   := preload("res://assets/ui/result/icon_status_alive.png")
const HERO_ICON_DEAD    := preload("res://assets/ui/result/icon_status_dead.png")

const BTN_WIN_NORMAL  := preload("res://assets/ui/result/btn_victory_normal.png")
const BTN_WIN_HOVER   := preload("res://assets/ui/result/btn_victory_hover.png")
const BTN_WIN_PRESSED := preload("res://assets/ui/result/btn_victory_pressed.png")

const BTN_LOSE_NORMAL  := preload("res://assets/ui/result/btn_defeat_normal.png")
const BTN_LOSE_HOVER   := preload("res://assets/ui/result/btn_defeat_hover.png")
const BTN_LOSE_PRESSED := preload("res://assets/ui/result/btn_defeat_pressed.png")

# ──────────────────────────────────────────────────────
# 🔧 CONFIGURAÇÃO DE TAMANHOS E CONSTANTES (Ajuste Fácil)
# ──────────────────────────────────────────────────────
const FRAME_PATCH      := 80    

# [AJUSTE AQUI] Customização da largura do painel e das linhas divisórias
const FRAME_ANCHOR_H   := 0.28   # Aumente para estreitar o frame (Ex: 0.25), diminua para alargar (Ex: 0.18)
const DIVIDER_WIDTH_PCT:= 0.80  # Define a largura horizontal dos dividers (80% da área disponível)
const DIVIDER_MARGIN_TOP    := 4
const DIVIDER_MARGIN_BOTTOM := 4

const FRAME_ANCHOR_V   := 0.02  

const MARGIN_LEFT      := 55    
const MARGIN_RIGHT     := 55    
const MARGIN_TOP       := 70    
const MARGIN_BOTTOM    := 35    # Reduzido ligeiramente para acomodar o botão fixo embaixo

const TITLE_HEIGHT     := 48    
const DIVIDER_HEIGHT   := 16    

const STAT_ROW_HEIGHT  := 26    
const STAT_ROW_PATCH   := 6     
const STAT_ICON_SIZE   := 18    
const FONT_STAT_KEY    := 8    
const FONT_STAT_VAL    := 10    

const PORTRAIT_SIZE    := 36    
const HERO_BAR_WIDTH   := 140   
const HERO_BAR_HEIGHT  := 26
const HERO_STATUS_SIZE := 32    
const FONT_HERO        := 10    

const CONTENT_SEP      := 6     
# ──────────────────────────────────────────────────────

const STAT_ROWS := [
	["Turnos jogados",      ICON_TURNS,   "turns"],
	["Dano infligido",      ICON_DMG_OUT, "player_damage_dealt"],
	["Dano recebido",       ICON_DMG_IN,  "enemy_damage_dealt"],
	["Críticos",            ICON_CRITS,   "crits"],
	["Inimigos derrotados", ICON_KILLS,   "enemy_deaths"],
	["Heróis perdidos",     ICON_DEATHS,  "player_deaths"],
]

var _frame_rect: NinePatchRect
var _title_rect: TextureRect
var _stat_val_lbls: Array  = []
var _dividers: Array       = []  
var _dynamic_vbox: VBoxContainer  

var _stats_container: VBoxContainer
var _divider_mid_1: Control
var _divider_mid_2: Control
var _divider_bottom: Control
var _action_btn: TextureButton

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	mouse_filter  = Control.MOUSE_FILTER_STOP
	modulate.a    = 0.0
	visible       = false

	z_index = 1000

	_build_overlay()
	_build_frame()

func _build_overlay() -> void:
	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.82)
	add_child(overlay)

func _build_frame() -> void:
	_frame_rect = NinePatchRect.new()
	_frame_rect.anchor_left   = FRAME_ANCHOR_H
	_frame_rect.anchor_right  = 1.0 - FRAME_ANCHOR_H
	_frame_rect.anchor_top    = FRAME_ANCHOR_V
	_frame_rect.anchor_bottom = 1.0 - FRAME_ANCHOR_V
	_frame_rect.patch_margin_left   = FRAME_PATCH
	_frame_rect.patch_margin_right  = FRAME_PATCH
	_frame_rect.patch_margin_top    = FRAME_PATCH
	_frame_rect.patch_margin_bottom = FRAME_PATCH
	add_child(_frame_rect)

	var absolute_vbox := VBoxContainer.new()
	absolute_vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	absolute_vbox.add_theme_constant_override("separation", 0)
	_frame_rect.add_child(absolute_vbox)

	var top_spacer := Control.new()
	top_spacer.custom_minimum_size.y = MARGIN_TOP
	absolute_vbox.add_child(top_spacer)

	var title_margin := MarginContainer.new()
	title_margin.add_theme_constant_override("margin_left", MARGIN_LEFT)
	title_margin.add_theme_constant_override("margin_right", MARGIN_RIGHT)
	absolute_vbox.add_child(title_margin)

	_title_rect = TextureRect.new()
	_title_rect.stretch_mode          = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_title_rect.expand_mode           = TextureRect.EXPAND_IGNORE_SIZE
	_title_rect.custom_minimum_size   = Vector2(0, TITLE_HEIGHT)
	_title_rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_rect.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	title_margin.add_child(_title_rect)

	_divider_mid_1 = _create_absolute_divider()
	absolute_vbox.add_child(_divider_mid_1)

	var stats_margin := MarginContainer.new()
	stats_margin.add_theme_constant_override("margin_left", MARGIN_LEFT)
	stats_margin.add_theme_constant_override("margin_right", MARGIN_RIGHT)
	absolute_vbox.add_child(stats_margin)

	_stats_container = VBoxContainer.new()
	_stats_container.add_theme_constant_override("separation", CONTENT_SEP)
	stats_margin.add_child(_stats_container)
	_build_stat_rows(_stats_container)

	_divider_mid_2 = _create_absolute_divider()
	absolute_vbox.add_child(_divider_mid_2)

	var dynamic_margin := MarginContainer.new()
	dynamic_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dynamic_margin.add_theme_constant_override("margin_left", MARGIN_LEFT)
	dynamic_margin.add_theme_constant_override("margin_right", MARGIN_RIGHT)
	absolute_vbox.add_child(dynamic_margin)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.get_v_scroll_bar().modulate.a = 0.0 
	dynamic_margin.add_child(scroll)

	_dynamic_vbox = VBoxContainer.new()
	_dynamic_vbox.add_theme_constant_override("separation", CONTENT_SEP)
	_dynamic_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_dynamic_vbox)

	# Seção Fixa Inferior (Botão e Divisor saem do Scroll e ficam travados no fundo)
	_divider_bottom = _create_absolute_divider()
	absolute_vbox.add_child(_divider_bottom)

	var btn_margin := MarginContainer.new()
	btn_margin.add_theme_constant_override("margin_bottom", MARGIN_BOTTOM)
	absolute_vbox.add_child(btn_margin)

	# Instanciação inicial do botão para controle de fluxo
	_action_btn = TextureButton.new()
	btn_margin.add_child(_action_btn)

func _create_absolute_divider() -> Control:
	var outer := MarginContainer.new()
	outer.add_theme_constant_override("margin_top", DIVIDER_MARGIN_TOP)
	outer.add_theme_constant_override("margin_bottom", DIVIDER_MARGIN_BOTTOM)
	outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Mudamos o retorno para Control para permitir que o CenterContainer seja retornado
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	outer.add_child(center)
	
	var div := TextureRect.new()
	div.stretch_mode          = TextureRect.STRETCH_SCALE
	div.expand_mode           = TextureRect.EXPAND_IGNORE_SIZE 
	div.custom_minimum_size   = Vector2(0, DIVIDER_HEIGHT)
	div.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	div.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	
	center.add_child(div)
	_dividers.append(div) # Continuamos guardando o TextureRect na array para o show_result aplicar a textura
	
	# Evento de redimensionamento dinâmico para garantir que o divisor meça exatamente a porcentagem definida
	center.item_rect_changed.connect(func():
		div.custom_minimum_size.x = center.size.x * DIVIDER_WIDTH_PCT
	)
	return outer

func _build_stat_rows(parent: Control) -> void:
	for entry: Array in STAT_ROWS:
		parent.add_child(_build_stat_row(entry[0], entry[1]))

func _build_stat_row(label_text: String, icon_tex: Texture2D) -> Control:
	# O Control principal serve como a âncora e container da linha inteira
	var row_root := Control.new()
	row_root.custom_minimum_size.y = STAT_ROW_HEIGHT
	row_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# 1. CAMADA DA ESQUERDA (Travada exatamente em 50% da largura do frame)
	var left_root := Control.new()
	left_root.anchor_left = 0.0
	left_root.anchor_right = 0.5 # 50% da largura: morre no centro exato
	left_root.anchor_top = 0.0
	left_root.anchor_bottom = 1.0
	left_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_root.add_child(left_root)

	# Margem direita para desgrudar o fundo do ícone (ajuste o -4.0 se quiser mais colado ou afastado)
	var name_bg := NinePatchRect.new()
	name_bg.texture              = STAT_ROW_BG
	name_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	name_bg.offset_right         = -(STAT_ICON_SIZE / 2.0) # Desloca o fim do BG para dar espaço ao ícone
	name_bg.patch_margin_left    = STAT_ROW_PATCH
	name_bg.patch_margin_right   = STAT_ROW_PATCH
	name_bg.patch_margin_top     = STAT_ROW_PATCH
	name_bg.patch_margin_bottom  = STAT_ROW_PATCH
	name_bg.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	left_root.add_child(name_bg)

	var key_lbl := Label.new()
	key_lbl.text = label_text
	key_lbl.add_theme_font_size_override("font_size", FONT_STAT_KEY)
	key_lbl.add_theme_color_override("font_color", Color(0.82, 0.78, 0.62))
	key_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	key_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	key_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	key_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	key_lbl.offset_left          = float(STAT_ROW_PATCH) + 8.0
	key_lbl.offset_right         = -(STAT_ICON_SIZE / 2.0)
	left_root.add_child(key_lbl)

	# 2. CAMADA DO ÍCONE (Centralizado Absoluto no Meio do Frame)
	var center_container := CenterContainer.new()
	center_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_root.add_child(center_container)

	var icon_rect := TextureRect.new()
	icon_rect.texture             = icon_tex
	icon_rect.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	icon_rect.custom_minimum_size = Vector2(STAT_ICON_SIZE, STAT_ICON_SIZE)
	icon_rect.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	center_container.add_child(icon_rect)

	# 3. CAMADA DA DIREITA (O número fixado na ponta direita)
	var right_hbox := HBoxContainer.new()
	right_hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	right_hbox.alignment = HBoxContainer.ALIGNMENT_END
	right_hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_root.add_child(right_hbox)

	var val_lbl := Label.new()
	val_lbl.add_theme_font_size_override("font_size", FONT_STAT_VAL)
	val_lbl.add_theme_color_override("font_color", Color(0.95, 0.90, 0.72))
	val_lbl.custom_minimum_size.x = 40
	val_lbl.horizontal_alignment  = HORIZONTAL_ALIGNMENT_RIGHT
	val_lbl.vertical_alignment    = VERTICAL_ALIGNMENT_CENTER
	val_lbl.mouse_filter          = Control.MOUSE_FILTER_IGNORE
	right_hbox.add_child(val_lbl)
	_stat_val_lbls.append(val_lbl)

	return row_root

func show_result(result: String, stats: Dictionary) -> void:
	if visible:
		return

	var is_win := result == "win"

	_frame_rect.texture = FRAME_VICTORY if is_win else FRAME_DEFEAT
	_title_rect.texture = TITLE_VICTORY if is_win else TITLE_DEFEAT
	var div_tex         := DIVIDER_VICTORY if is_win else DIVIDER_DEFEAT
	
	for div: TextureRect in _dividers:
		div.texture = div_tex

	for i in _stat_val_lbls.size():
		var key: String = STAT_ROWS[i][2]
		(_stat_val_lbls[i] as Label).text = str(stats.get(key, 0))

	for child in _dynamic_vbox.get_children():
		child.queue_free()

	var heroes_lbl := Label.new()
	heroes_lbl.text = "Heróis"
	heroes_lbl.add_theme_font_size_override("font_size", FONT_HERO + 2) 
	heroes_lbl.add_theme_color_override("font_color", Color(0.72, 0.68, 0.52))
	heroes_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_dynamic_vbox.add_child(heroes_lbl)

	for p: Dictionary in BattleState.PLAYERS:
		_dynamic_vbox.add_child(_build_hero_row(p))

	# Atualiza o botão fixado no fundo com a variação correta (Vitória ou Derrota)
	_update_action_button(is_win)

	visible              = true
	modulate.a            = 0.0
	_frame_rect.scale    = Vector2(0.92, 0.92)
	_frame_rect.pivot_offset = _frame_rect.custom_minimum_size * 0.5

	var tw := create_tween().set_parallel(true)
	tw.tween_property(self,        "modulate:a", 1.0,        0.22)
	tw.tween_property(_frame_rect, "scale",      Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _build_hero_row(p: Dictionary) -> HBoxContainer:
	var alive: bool = p["hp"] > 0

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var name_lbl := Label.new()
	name_lbl.text = p["name"]
	name_lbl.add_theme_font_size_override("font_size", FONT_HERO)
	name_lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78) if alive else Color(0.55, 0.52, 0.50))
	name_lbl.custom_minimum_size.x = 80 
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(name_lbl)

	var portrait_tex := _get_portrait(p)
	var portrait := TextureRect.new()
	portrait.texture             = portrait_tex
	portrait.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.expand_mode         = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	portrait.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	if not alive:
		portrait.modulate = Color(0.40, 0.40, 0.40)
	hbox.add_child(portrait)

	var class_lbl := Label.new()
	var hero_class: String = "Herói"
	
	var hero_data = BattleState.ALL_HERO_DATA.get(p["name"])
	if hero_data and hero_data is Resource:
		hero_class = hero_data.hero_class 
		
	class_lbl.text = hero_class
	class_lbl.add_theme_font_size_override("font_size", FONT_HERO - 1)
	class_lbl.add_theme_color_override("font_color", Color(0.65, 0.60, 0.55))
	class_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL 
	class_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(class_lbl)

	var status_icon := TextureRect.new()
	status_icon.texture             = HERO_ICON_ALIVE if alive else HERO_ICON_DEAD
	status_icon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_icon.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
	status_icon.custom_minimum_size = Vector2(HERO_STATUS_SIZE, HERO_STATUS_SIZE)
	status_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_icon.mouse_filter        = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(status_icon)

	var bar_root := Control.new()
	bar_root.custom_minimum_size = Vector2(HERO_BAR_WIDTH, HERO_BAR_HEIGHT)
	bar_root.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hbox.add_child(bar_root)

	var hp_bar := TextureProgressBar.new()
	hp_bar.texture_under    = HERO_HP_BG
	hp_bar.texture_progress = HERO_HP_FILL_LIVE if alive else HERO_HP_FILL_DEAD
	hp_bar.nine_patch_stretch = true
	hp_bar.stretch_margin_left = 4
	hp_bar.stretch_margin_right = 4
	hp_bar.stretch_margin_top = 4
	hp_bar.stretch_margin_bottom = 4
	hp_bar.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_bar.min_value = 0.0
	hp_bar.max_value = float(p["max_hp"]) if p["max_hp"] > 0 else 1.0
	hp_bar.value     = float(p["hp"])
	bar_root.add_child(hp_bar)

	var hp_lbl := Label.new()
	hp_lbl.text = "%d/%d" % [p["hp"], p["max_hp"]]
	hp_lbl.add_theme_font_size_override("font_size", FONT_HERO - 3)
	hp_lbl.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95) if alive else Color(0.82, 0.30, 0.30))
	hp_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	hp_lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	hp_bar.add_child(hp_lbl)

	return hbox

# ======================================================
# BUILD — BOTÃO DE AÇÃO FIXADO (ATUALIZAÇÃO DINÂMICA)
# ======================================================
func _update_action_button(is_win: bool) -> void:
	var tex_n  := BTN_WIN_NORMAL  if is_win else BTN_LOSE_NORMAL
	var tex_h  := BTN_WIN_HOVER   if is_win else BTN_LOSE_HOVER
	var tex_p  := BTN_WIN_PRESSED if is_win else BTN_LOSE_PRESSED
	var label  := "Continuar" if is_win else "Menu Principal"

	_action_btn.texture_normal        = tex_n
	_action_btn.texture_hover         = tex_h
	_action_btn.texture_pressed       = tex_p
	_action_btn.custom_minimum_size   = Vector2(260, 52) 
	_action_btn.ignore_texture_size   = true
	_action_btn.stretch_mode          = TextureButton.STRETCH_SCALE
	_action_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	# Limpa labels antigos para evitar duplicação em reuso da tela
	for child in _action_btn.get_children():
		child.queue_free()

	var lbl := Label.new()
	lbl.text = label
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
	lbl.mouse_filter         = Control.MOUSE_FILTER_IGNORE
	lbl.add_theme_font_size_override("font_size", 14) 
	lbl.add_theme_color_override("font_color",        Color(0.92, 0.86, 0.72))
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	_action_btn.add_child(lbl)

	# Desconecta conexões antigas com segurança antes de vincular os novos lambdas
	if _action_btn.pressed.is_connected(continue_requested.emit):
		_action_btn.pressed.disconnect(continue_requested.emit)
	if _action_btn.pressed.is_connected(restart_requested.emit):
		_action_btn.pressed.disconnect(restart_requested.emit)

	if is_win:
		_action_btn.pressed.connect(func() -> void: continue_requested.emit())
	else:
		_action_btn.pressed.connect(func() -> void: restart_requested.emit())

# ======================================================
# HELPERS
# ======================================================
func _get_portrait(p: Dictionary) -> Texture2D:
	var portrait = p.get("portrait")
	if portrait and portrait is Texture2D:
		return portrait
		
	var hero_data = BattleState.ALL_HERO_DATA.get(p["name"])
	if hero_data and hero_data is Resource:
		return hero_data.portrait
		
	return null
