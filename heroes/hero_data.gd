class_name HeroData
extends Resource

enum CasterType { NONE, HALF, FULL }

# Tabelas de spell slots D&D 5e, níveis 1-12. Índice 0 = nível 1, índice 11 = nível 12.
# Cada entrada é [1º, 2º, 3º, 4º, 5º, 6º] — 6 slots cobrem full caster até o nível 12.
const _FULL_SLOTS: Array = [
	[2, 0, 0, 0, 0, 0],  # nível 1
	[3, 0, 0, 0, 0, 0],  # nível 2
	[4, 2, 0, 0, 0, 0],  # nível 3
	[4, 3, 0, 0, 0, 0],  # nível 4
	[4, 3, 2, 0, 0, 0],  # nível 5
	[4, 3, 3, 0, 0, 0],  # nível 6
	[4, 3, 3, 1, 0, 0],  # nível 7
	[4, 3, 3, 2, 0, 0],  # nível 8
	[4, 3, 3, 3, 1, 0],  # nível 9
	[4, 3, 3, 3, 2, 0],  # nível 10
	[4, 3, 3, 3, 2, 1],  # nível 11
	[4, 3, 3, 3, 2, 1],  # nível 12
]
const _HALF_SLOTS: Array = [
	[0, 0, 0, 0, 0, 0],  # nível 1
	[2, 0, 0, 0, 0, 0],  # nível 2
	[3, 0, 0, 0, 0, 0],  # nível 3
	[3, 0, 0, 0, 0, 0],  # nível 4
	[4, 2, 0, 0, 0, 0],  # nível 5
	[4, 2, 0, 0, 0, 0],  # nível 6
	[4, 3, 0, 0, 0, 0],  # nível 7
	[4, 3, 0, 0, 0, 0],  # nível 8
	[4, 3, 2, 0, 0, 0],  # nível 9
	[4, 3, 2, 0, 0, 0],  # nível 10
	[4, 3, 3, 0, 0, 0],  # nível 11
	[4, 3, 3, 1, 0, 0],  # nível 12
]

@export var hero_name:   String = ""
@export var hero_class:  String = ""
@export var level:       int    = 1

@export_group("Visual")
@export var portrait: Texture2D
@export var sprite: Texture2D
@export var sprite_scale: float = 1.0
@export var sprite_frames: SpriteFrames 

@export_group("Vida")
@export var base_hp:  int = 100
@export var max_hp:   int = 100

@export_group("Progressão (Spell Slots / Ki)")
@export var caster_type:  CasterType = CasterType.NONE
@export var ki_per_level: int = 0  # Monge: 1; todos os outros: 0

@export_group("Atributos de Combate")
@export var ac:               int = 10
@export var initiative:       int = 5
@export var speed:            int = 5
@export var proficiency:      int = 2
@export var damage_reduction: int = 0
@export var crit_threshold:   int = 20
# Saving throws com proficiência por classe (D&D 5e). Chaves: STR/DEX/INT/WIS/CON/CHA.
@export var save_proficiencies: Array[String] = []

@export_group("Equipamento")
@export var weapon: WeaponData = null

@export_group("Atributos Primarios")
@export var strength:     int = 10
@export var dexterity:    int = 10
@export var intelligence: int = 10
@export var wisdom:       int = 10
@export var constitution: int = 10
@export var charisma:          int    = 10

@export_group("Examine Data")
@export var resistances:       Array[String] = []
@export var vulnerabilities:   Array[String] = []
@export var immunities:        Array[String] = []
@export var passive_features:  Array[String] = []

func to_combat_dict() -> Dictionary:
	return {
		"name":         hero_name,
		"type":         hero_class,
		"class":        hero_class,
		"level":        level,
		"hp":           base_hp,
		"max_hp":       max_hp,
		"spell_slots":     get_spell_slots_max(),
		"spell_slots_max": get_spell_slots_max(),
		"ki":              ki_max(),
		"ki_max":          ki_max(),
		"ac":           ac,
		"initiative":   initiative,
		"speed":        speed,
		"proficiency":      proficiency,
		"damage_reduction": damage_reduction,
		"strength":         strength,
		"dexterity":    dexterity,
		"intelligence": intelligence,
		"wisdom":       wisdom,
		"constitution": constitution,
		"charisma":         charisma,
		"resistances":      resistances,
		"vulnerabilities":  vulnerabilities,
		"immunities":       immunities,
		"passive_features": passive_features,
		"crit_threshold":   crit_threshold,
		"weapon":           weapon,
		"portrait":     portrait,
		"sprite":       sprite,
		"sprite_scale": sprite_scale,
		"sprite_frames": sprite_frames,
		"reactions":    reactions,
	}

# Calcula o array de spell slots máximos a partir do caster_type e do level atual.
# Quando o sistema de levels for implementado, basta atualizar `level` — os slots
# se ajustam automaticamente sem tocar nos arquivos de herói.
func get_spell_slots_max() -> Array:
	var idx := clampi(level - 1, 0, 11)
	match caster_type:
		CasterType.FULL: return _FULL_SLOTS[idx].duplicate()
		CasterType.HALF: return _HALF_SLOTS[idx].duplicate()
		_: return [0, 0, 0, 0, 0, 0]

# Ki máximo do Monge = level × ki_per_level. 0 para não-monges.
func ki_max() -> int:
	return level * ki_per_level

var actions: Array[ActionData] = []
var skills:  Array[ActionData] = []
var reactions: Array[ActionData] = []

# Aura passiva (framework genérico): afeta aliados vivos em alcance Chebyshev.
# "" = sem aura. Efeito suportado: "save_bonus". Atribuição é build.
@export var aura_effect: String = ""
@export var aura_radius: int = 0
@export var aura_value:  int = 0

# Factory para criar a arma equipada de cada herói em uma linha.
static func make_weapon(wname: String, dcount: int, dsides: int,
		attr: ActionData.DamageAttribute, finesse: bool = false,
		versatile: int = 0) -> WeaponData:
	var w := WeaponData.new()
	w.weapon_name         = wname
	w.damage_dice_count   = dcount
	w.damage_dice_sides   = dsides
	w.damage_attribute    = attr
	w.is_finesse          = finesse
	w.versatile_dice_sides = versatile
	return w
