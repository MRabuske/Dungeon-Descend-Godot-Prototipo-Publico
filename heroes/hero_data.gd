class_name HeroData
extends Resource

@export var hero_name:   String = ""
@export var hero_class:  String = ""
@export var level:       int    = 1

@export_group("Visual")
@export var portrait: Texture2D
@export var sprite: Texture2D
@export var sprite_scale: float = 1.0

@export_group("Vida e Mana")
@export var base_hp:  int = 100
@export var max_hp:   int = 100
@export var base_mp:  int = 0
@export var max_mp:   int = 0

@export_group("Atributos de Combate")
@export var ac:               int = 10
@export var initiative:       int = 5
@export var speed:            int = 5
@export var proficiency:      int = 2
@export var damage_reduction: int = 0

@export_group("Atributos Primarios")
@export var strength:     int = 10
@export var dexterity:    int = 10
@export var intelligence: int = 10
@export var wisdom:       int = 10
@export var constitution: int = 10

func to_combat_dict() -> Dictionary:
	return {
		"name":         hero_name,
		"type":         hero_class,
		"class":        hero_class,
		"level":        level,
		"hp":           base_hp,
		"max_hp":       max_hp,
		"mp":           base_mp,
		"max_mp":       max_mp,
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
		"portrait":     portrait,
		"sprite":       sprite,
		"sprite_scale": sprite_scale,
	}

var actions: Array[ActionData] = []
var skills:  Array[ActionData] = []
