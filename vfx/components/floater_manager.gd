class_name FloaterManager
extends Node

# ======================================================
# Gerencia floaters de dano com arco de bezier.
# Adicione como filho do BattleArea ou BattleScene.
# Uso:
#   FloaterManager.spawn(world_pos, 42, false, true)
# ======================================================

# ──────────────────────────────────────────────────────
# 🔧 AJUSTE
# ──────────────────────────────────────────────────────
const FONT_SIZE_NORMAL  := 16
const FONT_SIZE_CRIT    := 22
const ARC_SPREAD        := 22.0    # px — desvio lateral aleatório
const DURATION          := 0.85    # seg do floater completo
const FADE_DELAY        := 0.35    # seg antes de começar o fade

const COLOR_HEAL        := Color(0.30, 1.00, 0.45)
const COLOR_CRIT        := Color(1.00, 0.85, 0.10)
const COLOR_NORMAL      := Color(1.00, 0.30, 0.20)
const COLOR_MISS        := Color(0.70, 0.70, 0.70)
# ──────────────────────────────────────────────────────

var _parent: Control = null   # nó pai para adicionar labels

# ======================================================
# SETUP
# ======================================================
func setup(parent_control: Control) -> void:
	_parent = parent_control

# ======================================================
# PUBLIC
# ======================================================
func spawn(world_pos: Vector2, amount: int,
		is_heal: bool, is_crit: bool = false, is_miss: bool = false) -> void:

	var lbl := Label.new()
	var color: Color
	var text: String

	if is_miss:
		text  = "MISS"
		color = COLOR_MISS
		lbl.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	elif is_heal:
		text  = "+" + str(amount)
		color = COLOR_HEAL
		lbl.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)
	elif is_crit:
		text  = "CRIT! -" + str(amount)
		color = COLOR_CRIT
		lbl.add_theme_font_size_override("font_size", FONT_SIZE_CRIT)
	else:
		text  = "-" + str(amount)
		color = COLOR_NORMAL
		lbl.add_theme_font_size_override("font_size", FONT_SIZE_NORMAL)

	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.7))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.z_index = 100

	var root := _parent if _parent != null else get_tree().current_scene
	root.add_child(lbl)
	lbl.global_position = world_pos - Vector2(0, 20)

	# Escala inicial em crits
	if is_crit:
		lbl.scale = Vector2(1.4, 1.4)

	var tw := create_tween().set_parallel(true)

	# Movimento para cima
	tw.tween_property(lbl, "position:y", lbl.global_position.y - 60.0, DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Desvio lateral aleatório
	tw.tween_property(lbl, "position:x", lbl.global_position.x + randf_range(-ARC_SPREAD, ARC_SPREAD), DURATION) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	# Fade out
	tw.tween_property(lbl, "modulate:a", 0.0, DURATION - FADE_DELAY) \
		.set_delay(FADE_DELAY) \
		.set_trans(Tween.TRANS_SINE)

	# Scale recovery em crits
	if is_crit:
		tw.tween_property(lbl, "scale", Vector2.ONE, 0.15) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	tw.chain().tween_callback(func():
		print("DEBUG: Removendo label")
		lbl.queue_free()
	)
