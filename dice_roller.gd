class_name DiceRoller
extends Node

static func roll_d(sides: int) -> int:
	return randi_range(1, sides)

static func roll(count: int, sides: int) -> int:
	var total := 0
	for i in count:
		total += randi_range(1, sides)
	return total

# Rola d20 com Vantagem (maior de 2), Desvantagem (menor de 2), ou Normal.
# adv e dis podem ser > 1 (múltiplas fontes) — qualquer par cancela → normal.
# Retorna: { result: int, other: int, mode: String ("advantage"|"disadvantage"|"normal") }
static func roll_d20_adv_dis(adv: int, dis: int) -> Dictionary:
	var r1 := randi_range(1, 20)
	var r2 := randi_range(1, 20)
	if adv > 0 and dis == 0:
		return {"result": maxi(r1, r2), "other": mini(r1, r2), "mode": "advantage"}
	elif dis > 0 and adv == 0:
		return {"result": mini(r1, r2), "other": maxi(r1, r2), "mode": "disadvantage"}
	return {"result": r1, "other": r2, "mode": "normal"}
