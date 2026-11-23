class_name DiceRoller
extends Node

# Fila de resultados forçados (testes): cada dado rolado consome o próximo valor,
# limitado às faces do dado; vazia = RNG global. Evita depender da ORDEM das
# rolagens (seed) quando um teste precisa fixar um dado que não é o primeiro.
static var _forced: Array = []

static func force_next(values: Array) -> void:
	_forced.append_array(values)

static func clear_forced() -> void:
	_forced.clear()

static func _die(sides: int) -> int:
	if _forced.is_empty():
		return randi_range(1, sides)
	return clampi(int(_forced.pop_front()), 1, sides)

static func roll_d(sides: int) -> int:
	return _die(sides)

static func roll(count: int, sides: int) -> int:
	var total := 0
	for i in count:
		total += _die(sides)
	return total

# Rola d20 com Vantagem (maior de 2), Desvantagem (menor de 2), ou Normal.
# adv e dis podem ser > 1 (múltiplas fontes) — qualquer par cancela → normal.
# Retorna: { result: int, other: int, mode: String ("advantage"|"disadvantage"|"normal") }
static func roll_d20_adv_dis(adv: int, dis: int) -> Dictionary:
	var r1 := _die(20)
	var r2 := _die(20)
	if adv > 0 and dis == 0:
		return {"result": maxi(r1, r2), "other": mini(r1, r2), "mode": "advantage"}
	elif dis > 0 and adv == 0:
		return {"result": mini(r1, r2), "other": maxi(r1, r2), "mode": "disadvantage"}
	return {"result": r1, "other": r2, "mode": "normal"}
