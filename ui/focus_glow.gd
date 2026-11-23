class_name FocusGlow
extends RefCounted

# Indicador único de seleção do jogo: borda branca de 3 px (a mesma do exame na barra de
# turnos). Qualquer tela usa make_ring() para o item selecionado, ou attach() para botões
# que recebem foco do teclado/controle.

const RING_COLOR := Color.WHITE
const RING_WIDTH := 3

# Regra única: os anéis só aparecem com teclado ou controle. Com o mouse (último input)
# ficam ocultos em todas as telas e voltam, no último item selecionado, ao usar tecla/controle.
# Lido do autoload por caminho (como o HintBar): sem ele (parse isolado) o anel aparece.
static func rings_shown() -> bool:
	var loop := Engine.get_main_loop()
	var autoload: Node = (loop as SceneTree).root.get_node_or_null("InputDevice") if loop is SceneTree else null
	return autoload == null or not autoload.tracker.pointer_active

# Anel de seleção: Panel de tela cheia com fundo transparente e borda branca. Não captura
# mouse. Adicione-o como último filho do item para ficar por cima. `follows_device` false
# = marcador que vale também para o mouse (ex.: retrato examinado).
static func make_ring(follows_device: bool = true) -> Panel:
	var ring: Panel = FocusRing.new() if follows_device else Panel.new()
	ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.set_border_width_all(RING_WIDTH)
	style.border_color = RING_COLOR
	ring.add_theme_stylebox_override("panel", style)
	return ring

# Mostra o anel enquanto o controle tem foco (TextureButton não tem estilo de foco).
static func attach(btn: Control) -> void:
	var ring := make_ring()
	ring.visible = btn.has_focus()
	btn.add_child(ring)
	# focus_exited também dispara ao liberar a cena, quando o anel (filho) já foi liberado.
	btn.focus_entered.connect(func() -> void:
		if is_instance_valid(ring):
			ring.visible = true)
	btn.focus_exited.connect(func() -> void:
		if is_instance_valid(ring):
			ring.visible = false)
