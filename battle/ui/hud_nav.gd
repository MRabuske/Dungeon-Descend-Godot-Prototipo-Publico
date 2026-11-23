class_name HudNav
extends RefCounted

# Navegação do cursor da HUD de ações sobre as posições VISÍVEIS do grid (puro, sem nós).
# Cada entrada é {"id": String, "row": int, "col": int}; col é a coluna visual combinada
# (lado esquerdo + lado direito) e a barra de itens é a última linha. Esquerda/direita
# percorrem a ordem de leitura (linha, coluna) com volta; cima/baixo vão à linha vizinha,
# na coluna mais próxima, e não dão a volta.

static func reading_order(entries: Array) -> Array:
	var sorted: Array = entries.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["row"] < b["row"] or (a["row"] == b["row"] and a["col"] < b["col"]))
	return sorted

# Próximo id a partir de current_id na direção dir. current_id fora da lista (ou vazio)
# cai na primeira entrada; lista vazia devolve "".
static func step(entries: Array, current_id: String, dir: Vector2i) -> String:
	var ordered: Array = reading_order(entries)
	if ordered.is_empty():
		return ""
	var pos := -1
	for i in range(ordered.size()):
		if ordered[i]["id"] == current_id:
			pos = i
			break
	if pos < 0:
		return ordered[0]["id"]
	if dir.x != 0:
		return ordered[posmod(pos + dir.x, ordered.size())]["id"]
	if dir.y == 0:
		return current_id
	var cur: Dictionary = ordered[pos]
	var rows: Array = []
	for e in ordered:
		if not rows.has(e["row"]):
			rows.append(e["row"])
	var ri: int = rows.find(cur["row"]) + dir.y
	if ri < 0 or ri >= rows.size():
		return current_id
	var best: Dictionary = {}
	for e in ordered:
		if e["row"] != rows[ri]:
			continue
		if best.is_empty() or absi(e["col"] - cur["col"]) < absi(best["col"] - cur["col"]):
			best = e
	return best["id"]
