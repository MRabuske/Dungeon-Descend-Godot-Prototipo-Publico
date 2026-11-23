class_name AreaShape
extends RefCounted

# Formas de área do D&D 2024 (SRD 5.2, Rules Glossary "Area of Effect"; DMG 2024 "Areas of Effect"
# em grid) traduzidas para casas. Lógica pura: sem nós, sem estado — o BattleState chama, a prévia
# e o resultado usam a MESMA função (pré-visualização = efeito aplicado).
#
# Regras do DMG 2024 que o motor reproduz:
#  - a área é posta no grid escolhendo um CRUZAMENTO de casas como ponto de origem;
#  - uma casa é afetada se a área cobrir PELO MENOS METADE dela ("at least half a square").
#
# Coordenadas: a casa (c, r) ocupa [c, c+1] × [r, r+1]; o canto (intersecção) (x, y) é o ponto
# inteiro. 1 casa = 5 pés. Os tamanhos entram em pés, como nos livros.

enum Kind { NONE = -1, SPHERE, CUBE, CONE, LINE, CYLINDER, EMANATION }

const FT_PER_SQUARE := 5.0
const EPS := 1e-6              # tolerância para "exatamente metade" ser afetada
const CURVE_SLICES := 128      # fatias na integração do círculo
const RIM_SAMPLES := 32        # amostras por lado na emanação (borda arredondada)

# ── Formas ───────────────────────────────────────────────────────────────────

## Esfera: círculo de raio `radius_ft` com centro no ponto de origem (um cruzamento).
static func sphere(center: Vector2, radius_ft: int) -> Array[Vector2i]:
	var r: float = radius_ft / FT_PER_SQUARE
	var bounds := Rect2(center - Vector2(r, r), Vector2(2.0 * r, 2.0 * r))
	return _collect(bounds, func(sq: Vector2i) -> float: return _circle_coverage(center, r, sq))

## Cilindro: visto de cima (o jogo não tem altura) é o mesmo círculo da esfera.
static func cylinder(center: Vector2, radius_ft: int) -> Array[Vector2i]:
	return sphere(center, radius_ft)

## Emanação: parte do espaço de uma criatura (uma casa) em todas as direções e a acompanha. O
## contorno é o quadrado da criatura expandido por um disco (cantos arredondados). A casa de origem
## fica de fora, salvo `include_origin` (a habilidade diz que também afeta a própria criatura).
static func emanation(origin_square: Vector2i, radius_ft: int, include_origin: bool = false) -> Array[Vector2i]:
	var r: float = radius_ft / FT_PER_SQUARE
	var rect := Rect2(Vector2(origin_square), Vector2.ONE)
	var bounds := rect.grow(r)
	var tiles := _collect(bounds, func(sq: Vector2i) -> float: return _emanation_coverage(rect, r, sq))
	if not include_origin:
		tiles.erase(origin_square)
	return tiles

## Cubo alinhado ao grid: bloco de lado `side_ft` (em casas) com a casa `tile` no centro. Para o
## cubo de 5 pés é exatamente a casa mirada.
static func cube_square(tile: Vector2i, side_ft: int) -> Array[Vector2i]:
	var n: int = maxi(1, roundi(side_ft / FT_PER_SQUARE))
	var start: Vector2i = tile - Vector2i((n - 1) / 2, (n - 1) / 2)
	var tiles: Array[Vector2i] = []
	for dx in range(n):
		for dy in range(n):
			tiles.append(start + Vector2i(dx, dy))
	return tiles

## Cubo em direção livre (origem no centro de uma face, estendendo-se para `aim`).
static func cube(origin: Vector2, aim: Vector2, side_ft: int) -> Array[Vector2i]:
	var s: float = side_ft / FT_PER_SQUARE
	var d: Vector2 = _dir(origin, aim)
	var p: Vector2 = Vector2(-d.y, d.x) * (s * 0.5)
	return _polygon_squares(PackedVector2Array([origin + p, origin + p + d * s, origin - p + d * s, origin - p]))

## Cone: a largura em cada ponto do comprimento é igual à distância da origem (D&D 2024).
static func cone(origin: Vector2, aim: Vector2, length_ft: int) -> Array[Vector2i]:
	var l: float = length_ft / FT_PER_SQUARE
	var d: Vector2 = _dir(origin, aim)
	var p: Vector2 = Vector2(-d.y, d.x) * (l * 0.5)
	return _polygon_squares(PackedVector2Array([origin, origin + d * l + p, origin + d * l - p]))

## Linha: retângulo de `length_ft` por `width_ft`, com o eixo partindo da origem rumo a `aim`.
static func line(origin: Vector2, aim: Vector2, length_ft: int, width_ft: int = 5) -> Array[Vector2i]:
	var l: float = length_ft / FT_PER_SQUARE
	var w: float = width_ft / FT_PER_SQUARE
	var d: Vector2 = _dir(origin, aim)
	var p: Vector2 = Vector2(-d.y, d.x) * (w * 0.5)
	return _polygon_squares(PackedVector2Array([origin + p, origin + p + d * l, origin - p + d * l, origin - p]))

## Origem de uma área "Self" (cone, linha) que parte do conjurador: o canto da casa dele mais
## próximo da direção mirada (decisão de projeto; o livro só diz "um cruzamento"). Em eixo exato
## (dx ou dy = 0) o empate vai para o canto de cima/esquerda.
static func self_origin(caster_square: Vector2i, aim_square: Vector2i) -> Vector2:
	var d: Vector2i = aim_square - caster_square
	return Vector2(caster_square.x + (1 if d.x > 0 else 0), caster_square.y + (1 if d.y > 0 else 0))

# ── Coleta de casas ──────────────────────────────────────────────────────────

# Casas dentro de `bounds` cuja cobertura (0..1) chega a metade. Ordem estável (coluna, linha).
static func _collect(bounds: Rect2, coverage: Callable) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var x0: int = floori(bounds.position.x)
	var y0: int = floori(bounds.position.y)
	var x1: int = ceili(bounds.end.x)
	var y1: int = ceili(bounds.end.y)
	for x in range(x0, x1):
		for y in range(y0, y1):
			var sq := Vector2i(x, y)
			if float(coverage.call(sq)) >= 0.5 - EPS:
				result.append(sq)
	return result

static func _polygon_squares(poly: PackedVector2Array) -> Array[Vector2i]:
	var min_p: Vector2 = poly[0]
	var max_p: Vector2 = poly[0]
	for pt in poly:
		min_p = Vector2(minf(min_p.x, pt.x), minf(min_p.y, pt.y))
		max_p = Vector2(maxf(max_p.x, pt.x), maxf(max_p.y, pt.y))
	return _collect(Rect2(min_p, max_p - min_p), func(sq: Vector2i) -> float: return _polygon_coverage(poly, sq))

static func _dir(origin: Vector2, aim: Vector2) -> Vector2:
	var d: Vector2 = aim - origin
	return Vector2.RIGHT if d.length() < 0.0001 else d.normalized()

# ── Cobertura de uma casa (fração 0..1 da casa coberta pela forma) ──────────────

# Área do círculo ∩ casa, por integração em fatias verticais (ponto médio).
static func _circle_coverage(center: Vector2, r: float, sq: Vector2i) -> float:
	var area := 0.0
	for i in range(CURVE_SLICES):
		var x: float = sq.x + (i + 0.5) / CURVE_SLICES
		var dy2: float = r * r - (x - center.x) * (x - center.x)
		if dy2 <= 0.0:
			continue
		var h: float = sqrt(dy2)
		var lo: float = maxf(center.y - h, float(sq.y))
		var hi: float = minf(center.y + h, float(sq.y + 1))
		if hi > lo:
			area += (hi - lo) / CURVE_SLICES
	return area

# Fração da casa a distância <= r do retângulo da criatura (amostras em grade uniforme).
static func _emanation_coverage(rect: Rect2, r: float, sq: Vector2i) -> float:
	var inside := 0
	for i in range(RIM_SAMPLES):
		for j in range(RIM_SAMPLES):
			var p := Vector2(sq.x + (i + 0.5) / RIM_SAMPLES, sq.y + (j + 0.5) / RIM_SAMPLES)
			var dx: float = maxf(maxf(rect.position.x - p.x, 0.0), p.x - rect.end.x)
			var dy: float = maxf(maxf(rect.position.y - p.y, 0.0), p.y - rect.end.y)
			if dx * dx + dy * dy <= r * r:
				inside += 1
	return float(inside) / float(RIM_SAMPLES * RIM_SAMPLES)

# Área do polígono CONVEXO ∩ casa (Sutherland–Hodgman contra os 4 lados da casa; exata).
static func _polygon_coverage(poly: PackedVector2Array, sq: Vector2i) -> float:
	var pts: PackedVector2Array = poly
	var x0 := float(sq.x)
	var y0 := float(sq.y)
	var edges: Array = [
		[Vector2(1, 0), x0],         # x >= x0
		[Vector2(-1, 0), -(x0 + 1)], # x <= x0 + 1
		[Vector2(0, 1), y0],         # y >= y0
		[Vector2(0, -1), -(y0 + 1)], # y <= y0 + 1
	]
	for e in edges:
		pts = _clip(pts, e[0], float(e[1]))
		if pts.size() < 3:
			return 0.0
	var area := 0.0
	for i in range(pts.size()):
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[(i + 1) % pts.size()]
		area += a.x * b.y - b.x * a.y
	return absf(area) * 0.5

# Mantém a parte do polígono com normal·p >= offset.
static func _clip(pts: PackedVector2Array, normal: Vector2, offset: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(pts.size()):
		var cur: Vector2 = pts[i]
		var nxt: Vector2 = pts[(i + 1) % pts.size()]
		var dc: float = normal.dot(cur) - offset
		var dn: float = normal.dot(nxt) - offset
		if dc >= 0.0:
			out.append(cur)
		if (dc >= 0.0) != (dn >= 0.0):
			var t: float = dc / (dc - dn)
			out.append(cur + (nxt - cur) * t)
	return out
