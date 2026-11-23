class_name BattleCamera
extends RefCounted

# Matemática da câmera do combate (pan/zoom) separada do BattleArea para ser testável.
# "Pan" aqui é o deslocamento do mundo na tela (BattleArea._pan_offset): empurrar o
# cursor para a direita REVELA mapa à direita, então o pan DIMINUI.

const ZOOM_LEVELS: Array[float] = [0.75, 1.0, 1.5, 2.0]
const EDGE_MARGIN := 56.0        # faixa junto à borda da tela que rola a câmera
const EDGE_PAN_SPEED := 420.0    # px/s com o analógico a fundo
const STICK_PAN_SPEED := 360.0   # px/s do analógico direito
const POINTER_SPEED := 700.0     # px/s do cursor livre com o analógico a fundo

# Próximo nível de zoom (R3). Acima do último, volta ao menor.
static func next_zoom(current: float) -> float:
	for z in ZOOM_LEVELS:
		if z > current + 0.001:
			return z
	return ZOOM_LEVELS[0]

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
