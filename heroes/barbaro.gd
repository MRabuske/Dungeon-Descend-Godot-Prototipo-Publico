class_name BarbaroData
extends HeroData

func _init() -> void:
	hero_name        = "Bárbaro"
	hero_class       = "Barbarian"
	sprite           = preload("res://assets/sprites/hero/barbaro/barbaro.png")
	portrait         = preload("res://assets/ui/portraits/hero/barbaro/barbaro.png")
	sprite_frames = preload("res://assets/sprites/hero/barbaro/barbaro_animation.tres")
	level            = 4
	base_hp          = 95
	max_hp           = 120
	ac               = 12
	initiative       = 7
	speed            = 6
	proficiency      = 3
	strength         = 20
	dexterity        = 8
	intelligence     = 6
	wisdom           = 8
	constitution     = 18
	charisma         = 8
	save_proficiencies = ["STR", "CON"]
	damage_reduction = 1

	weapon = HeroData.make_weapon("Greataxe", 1, 12, ActionData.DamageAttribute.STR)
	actions = [AtqNormal.new(), AtqPesado.new(), AcaoMover.new()]
	skills  = []
