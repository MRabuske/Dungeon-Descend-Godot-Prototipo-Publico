class_name TurnOrderBar
extends Control

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
	_margin_container.add_child(_hbox)

# ======================================================
# PUBLIC API
# ======================================================
func refresh(queue: Array, active_index: int) -> void:
	for child in _hbox.get_children():
		_hbox.remove_child(child)
		child.queue_free()

	for i in queue.size():
		_hbox.add_child(_build_slot(queue[i], i == active_index, i))

	var n: int = queue.size()
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

	var portrait_tex := _get_combatant_portrait(combatant)
	if portrait_tex:
		var portrait_rect := TextureRect.new()
		portrait_rect.texture      = portrait_tex
		portrait_rect.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		portrait_rect.stretch_mode = TextureRect.STRETCH_SCALE
		portrait_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		portrait_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_margin.add_child(portrait_rect)
	else:
		var main_lbl := Label.new()
		main_lbl.text                 = combatant["name"].substr(0, 2).to_upper()
		main_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		main_lbl.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		main_lbl.add_theme_font_size_override("font_size", 12)
		main_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		main_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot_margin.add_child(main_lbl)

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

	return root
	
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
