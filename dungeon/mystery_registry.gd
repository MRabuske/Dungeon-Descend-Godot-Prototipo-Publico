class_name MysteryRegistry
extends RefCounted

# Outcome weights (out of 100):
#   0–39  → random event from EventData.REGISTRY  (40%)
#   40–69 → treasure (heal + MP restore)           (30%)
#   70–89 → battle surprise                        (20%)
#   90–99 → curse (damage + ATK debuff)            (10%)

static func resolve(node_id: int) -> EventData:
	var rng := RandomNumberGenerator.new()
	rng.seed = abs(node_id) * 31337 + 42
	var roll: int = rng.randi() % 100
	if roll < 40:
		return _random_event(rng)
	elif roll < 70:
		return _treasure_event()
	elif roll < 90:
		return _battle_event()
	else:
		return _curse_event()

static func _random_event(rng: RandomNumberGenerator) -> EventData:
	var keys: Array = EventData.REGISTRY.keys()
	var key: String = keys[rng.randi() % keys.size()]
	return EventData.REGISTRY[key]

static func _treasure_event() -> EventData:
	var C := EventData.ConsequenceType
	return EventData.new("mystery_treasure", "Tesouro Escondido",
		"Atrás de uma parede falsa, vocês encontram provisões escondidas.",
		[
			EventData.EventChoice.new("Pegar",
				C.HEAL_PARTY, 40, "party",
				"A party recolhe as provisões. Todos curam 40 HP.",
				C.MP_RESTORE_PARTY, 30, "party",
				"Todos recuperam 30 MP."),
		])

static func _battle_event() -> EventData:
	var C := EventData.ConsequenceType
	return EventData.new("mystery_battle", "Encontro Inesperado!",
		"Uma criatura surge das sombras. Não há tempo para negociar.",
		[
			EventData.EventChoice.new("Entrar em Combate",
				C.GO_TO_BATTLE, 0, "none",
				""),
		])

static func _curse_event() -> EventData:
	var C := EventData.ConsequenceType
	return EventData.new("mystery_curse", "Armadilha Arcana",
		"Uma armadilha mágica dispara ao pisarem na sala. Energia negativa envolve a party.",
		[
			EventData.EventChoice.new("Aceitar o destino",
				C.DAMAGE_PARTY, 20, "party",
				"A armadilha debilita a party. Todos perdem 20 HP.",
				C.BUFF_NEXT_BATTLE, -5, "ATK_UP",
				"ATK -5 na próxima batalha."),
		])
