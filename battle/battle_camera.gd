class_name BattleCamera
extends RefCounted

# Matemática da câmera do combate (pan/zoom) separada do BattleArea para ser testável.
# "Pan" aqui é o deslocamento do mundo na tela (BattleArea._pan_offset): empurrar o
# cursor para a direita REVELA mapa à direita, então o pan DIMINUI.
# Transformação: tela = mundo * zoom + view/2 * (1 - zoom) + pan (o zoom gira em torno do centro da tela).

const MAX_ZOOM := 2.5
const FIT_PAD := 24.0            # folga em volta do mapa no zoom de visão geral
const PAN_SLACK := 160.0         # quanto de "vazio" além da borda do mapa o pan permite
const ZOOM_RATE := 1.6           # e-folds por segundo com o analógico/tecla a fundo
const EDGE_MARGIN := 56.0        # faixa junto à borda da tela que rola a câmera
const EDGE_PAN_SPEED := 420.0    # px/s com o analógico a fundo
const POINTER_SPEED := 700.0     # px/s do cursor livre com o analógico a fundo
const KEY_PAN_SPEED := 400.0     # px/s do W/A/S/D (parecido com o pan de borda)
const FOLLOW_RATE := 7.0         # suavidade do foco automático (maior = mais rápido)

# Zoom em que o mapa inteiro cabe na tela (com FIT_PAD de folga).
static func fit_zoom(world_size: Vector2, view: Vector2) -> float:
	if world_size.x <= 0.0 or world_size.y <= 0.0:
		return 1.0
	var avail := (view - Vector2.ONE * FIT_PAD * 2.0).max(Vector2.ONE)
	return minf(avail.x / world_size.x, avail.y / world_size.y)

# Zoom mínimo (mais afastado): sempre cabe o mapa inteiro; nunca obriga a aproximar além de 1.0.
static func min_zoom(world_size: Vector2, view: Vector2) -> float:
	return minf(fit_zoom(world_size, view), 1.0)

static func clamp_zoom(zoom: float, world_size: Vector2, view: Vector2) -> float:
	return clampf(zoom, min_zoom(world_size, view), MAX_ZOOM)

# Zoom contínuo: axis > 0 aproxima, < 0 afasta (multiplicativo, então a velocidade percebida é constante).
static func zoom_step(zoom: float, axis: float, dt: float) -> float:
	return zoom * exp(axis * ZOOM_RATE * dt)

# Pan que mantém o ponto do mundo no centro da tela quando o zoom muda.
static func rescale_pan(pan: Vector2, old_zoom: float, new_zoom: float) -> Vector2:
	return pan * (new_zoom / old_zoom)

# Pan que leva um ponto do mundo ao centro da tela.
static func pan_to_center(world_point: Vector2, view: Vector2, zoom: float) -> Vector2:
	return (view * 0.5 - world_point) * zoom

# Intervalo permitido do pan (position = mínimo, end = máximo). `world` é o retângulo do mapa em
# coordenadas de mundo. Mapa maior que a tela: pode rolar até a borda dele ficar `slack` px para dentro.
# Mapa menor que a tela: fica travado no centro.
static func pan_limits(world: Rect2, view: Vector2, zoom: float, slack: float = PAN_SLACK) -> Rect2:
	var lx := _axis_limits(world.position.x, world.size.x, view.x, zoom, slack)
	var ly := _axis_limits(world.position.y, world.size.y, view.y, zoom, slack)
	return Rect2(Vector2(lx.x, ly.x), Vector2(lx.y - lx.x, ly.y - ly.x))

static func _axis_limits(w0: float, wsize: float, view: float, zoom: float, slack: float) -> Vector2:
	var p0: float = w0 * zoom + view * 0.5 * (1.0 - zoom)   # borda do mapa na tela com pan 0
	var lo: float = (view - (p0 + wsize * zoom)) - slack
	var hi: float = -p0 + slack
	if lo > hi:
		var mid: float = (lo + hi) * 0.5
		return Vector2(mid, mid)
	return Vector2(lo, hi)

static func clamp_pan(pan: Vector2, world: Rect2, view: Vector2, zoom: float) -> Vector2:
	var lim := pan_limits(world, view, zoom)
	return pan.clamp(lim.position, lim.end)

# O ponto de tela está dentro da tela, com `margin` de folga?
static func tile_visible(screen_pos: Vector2, view: Vector2, margin: float = EDGE_MARGIN) -> bool:
	var m: float = minf(margin, minf(view.x, view.y) * 0.25)   # tela minúscula: a margem encolhe junto
	return Rect2(Vector2.ZERO, view).grow(-m).has_point(screen_pos)

# Velocidade do pan quando o ponteiro está na faixa de borda E o analógico empurra
# para essa borda. Fora disso, zero.
static func edge_pan_velocity(pointer: Vector2, view: Vector2, margin: float,
		stick: Vector2, speed: float) -> Vector2:
	var v := Vector2.ZERO
	if pointer.x > view.x - margin and stick.x > 0.0:
		v.x = -stick.x * speed
	elif pointer.x < margin and stick.x < 0.0:
		v.x = -stick.x * speed
	if pointer.y > view.y - margin and stick.y > 0.0:
		v.y = -stick.y * speed
	elif pointer.y < margin and stick.y < 0.0:
		v.y = -stick.y * speed
	return v

# Filtra um deslocamento de pan: só deixa rolar numa direção se ainda há mapa além da
# borda da tela naquela direção (map_rect em coordenadas de tela). No limite, para.
static func can_pan(map_rect: Rect2, view: Vector2, delta: Vector2) -> Vector2:
	var out := delta
	if delta.x < 0.0 and map_rect.end.x <= view.x:
		out.x = 0.0
	elif delta.x > 0.0 and map_rect.position.x >= 0.0:
		out.x = 0.0
	if delta.y < 0.0 and map_rect.end.y <= view.y:
		out.y = 0.0
	elif delta.y > 0.0 and map_rect.position.y >= 0.0:
		out.y = 0.0
	return out

# Velocidade do pan do W/A/S/D. `dir` é para onde a VISTA anda (D = (1, 0)); o mundo anda ao contrário,
# então o pan diminui. A diagonal é normalizada (não anda mais rápido que um eixo só).
static func key_pan_velocity(dir: Vector2) -> Vector2:
	if dir == Vector2.ZERO:
		return Vector2.ZERO
	return -dir.normalized() * KEY_PAN_SPEED
