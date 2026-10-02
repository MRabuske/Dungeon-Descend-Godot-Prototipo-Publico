class_name ActionTooltipPanel
extends PanelContainer

# Floating tooltip shown when hovering an action/skill icon in the ActionPanel.
# Appears after a short delay (HOVER_DELAY) to avoid flicker; hidden on mouse-out
# or click. Content: name, effect description, damage, range and cost.

const HOVER_DELAY := 0.3

var _name_lbl:   Label
var _desc_lbl:   Label
var _damage_lbl: RichTextLabel
var _range_lbl:  Label
var _cost_lbl:   Label

var _pending_action: ActionData = null
var _timer_active: bool = false

func _ready() -> void:
	visible = false
	mouse_filter = MOUSE_FILTER_IGNORE
	z_index = 200

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.04, 0.14, 0.94)
	style.set_corner_radius_all(7)
	style.set_border_width_all(1)
	style.border_color = Color(0.5, 0.45, 0.25, 0.85)
	style.content_margin_left   = 10.0
	style.content_margin_right  = 10.0
	style.content_margin_top    = 8.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	add_child(vbox)

	_name_lbl   = _make_lbl(14, Color.WHITE)
	_desc_lbl   = _make_lbl(11, Color(0.75, 0.75, 0.75))
	_damage_lbl = _make_rich_lbl(12, Color(0.95, 0.7, 0.3))
	_range_lbl  = _make_lbl(11, Color(0.65, 0.85, 0.95))
	_cost_lbl   = _make_lbl(11, Color(0.78, 0.58, 0.95))

	vbox.add_child(_name_lbl)
	vbox.add_child(_desc_lbl)
	vbox.add_child(_damage_lbl)
	vbox.add_child(_range_lbl)
	vbox.add_child(_cost_lbl)

func _make_lbl(font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 190.0
	return l

func _make_rich_lbl(font_size: int, color: Color) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.add_theme_font_size_override("normal_font_size", font_size)
	l.add_theme_color_override("default_color", color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 190.0
	return l

# Schedules the tooltip to appear for `action` after HOVER_DELAY. Calling again
# with a new action before the delay elapses just swaps the pending action.
func show_for(action: ActionData) -> void:
	if action == null:
		hide_tooltip()
		return
	_pending_action = action
	if _timer_active:
		return
	_timer_active = true
	var t := get_tree().create_timer(HOVER_DELAY)
	t.timeout.connect(func() -> void:
		_timer_active = false
		if _pending_action == null:
			return
		_populate(_pending_action)
		visible = true
		_reposition()
	)

func hide_tooltip() -> void:
	_pending_action = null
	visible = false

func _reposition() -> void:
	reset_size()
	var mouse := get_global_mouse_position()
	var pos := mouse - Vector2(size.x * 0.5, size.y + 14.0)
	var vp := get_viewport_rect().size
	pos.x = clampf(pos.x, 4.0, vp.x - size.x - 4.0)
	pos.y = clampf(pos.y, 4.0, vp.y - size.y - 4.0)
	position = pos

func _populate(action: ActionData) -> void:
	_name_lbl.text = action.label

	var desc := _desc_text(action)
	_desc_lbl.text = desc
	_desc_lbl.visible = desc != ""

	var dmg := _damage_text(action)
	_damage_lbl.text = dmg
	_damage_lbl.visible = dmg != ""

	var rng := _range_text(action)
	_range_lbl.text = rng
	_range_lbl.visible = rng != ""

	var cost := _cost_text(action)
	_cost_lbl.text = cost
	_cost_lbl.visible = cost != ""

# ── Pure text builders (unit-tested) ───────────────────────────────────────────
func _damage_text(action: ActionData) -> String:
	# Mostra a linha de dano sempre que a ação for um ATAQUE com dados de dano —
	# não depende de ter modificador de atributo (ex.: Nuvem de Adagas = 4d4 fixo,
	# sem atributo). Ações de MOVE/END_TURN ficam de fora mesmo com dados residuais.
	if action == null or action.action_type != ActionData.Type.ATTACK:
		return ""
	if action.damage_dice_count <= 0 or action.damage_dice_sides <= 0:
		return ""
	var verb := "Cura" if action.targets_allies else "Dano"
	var c := ActionData.damage_type_color(action.damage_type)
	var hex := "#%02x%02x%02x" % [int(c.r * 255), int(c.g * 255), int(c.b * 255)]
	# Ataques multi-hit (ex.: Flurry of Blows) prefixam o nº de golpes: "2× 1d6 + DES".
	var hits_prefix := "%d× " % action.hit_count if action.hit_count > 1 else ""
	# Só adiciona "+ ATRIBUTO" quando há um atributo de dano (NONE = dano fixo).
	var attr_suffix := " + %s" % _attr_name(action.damage_attribute) \
		if action.damage_attribute != ActionData.DamageAttribute.NONE else ""
	var base := "%s: [color=%s]%s%dd%d%s[/color]" % [verb, hex, hits_prefix, action.damage_dice_count, action.damage_dice_sides, attr_suffix]
	if action.smite_dice_count > 0:
		var rc := ActionData.damage_type_color(ActionData.DamageType.RADIANT)
		var rhex := "#%02x%02x%02x" % [int(rc.r * 255), int(rc.g * 255), int(rc.b * 255)]
		base += " + [color=%s]%dd%d Radiante[/color]" % [rhex, action.smite_dice_count, action.smite_dice_sides]
	return base

func _range_text(action: ActionData) -> String:
	if action == null or action.action_type != ActionData.Type.ATTACK or action.attack_range <= 0:
		return ""
	var unit := "tile" if action.attack_range == 1 else "tiles"
	return "Alcance: %d %s" % [action.attack_range, unit]

func _cost_text(action: ActionData) -> String:
	if action == null:
		return ""
	var parts: Array[String] = []
	if action.spell_slot_level > 0:
		parts.append("Slot %dº nível" % action.spell_slot_level)
	if action.ki_cost > 0:
		parts.append("%d Ki" % action.ki_cost)
	if parts.is_empty():
		return ""
	return "Custo: " + ", ".join(parts)

func _desc_text(action: ActionData) -> String:
	if action == null:
		return ""
	var parts: Array[String] = []
	if action.aoe_radius > 0:
		parts.append("Área de efeito: raio %d" % action.aoe_radius)
	if action.applies_condition != "":
		parts.append("Aplica: %s" % StatusDefinitions.name_of(action.applies_condition))
	if action.bonus_action:
		parts.append("Ação bônus")
	return "\n".join(parts)

func _attr_name(attr: ActionData.DamageAttribute) -> String:
	match attr:
		ActionData.DamageAttribute.STR: return "FOR"
		ActionData.DamageAttribute.DEX: return "DES"
		ActionData.DamageAttribute.INT: return "INT"
		ActionData.DamageAttribute.WIS: return "SAB"
		_: return "—"
