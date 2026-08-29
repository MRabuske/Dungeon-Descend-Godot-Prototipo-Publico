class_name BarbaroData
extends HeroData

func _init() -> void:
	hero_name        = "Bárbaro"
	hero_class       = "Barbarian"
	sprite           = preload("res://assets/sprites/hero/barbaro/barbaro.png")
	portrait         = preload("res://assets/ui/portraits/hero/barbaro/barbaro.png")
	level            = 4
	base_hp          = 95
	max_hp           = 120
	base_mp          = 0
	max_mp           = 0
	ac               = 12
	initiative       = 7
	speed            = 6
	proficiency      = 3
	strength         = 20
	dexterity        = 8
	intelligence     = 6
	wisdom           = 8
	constitution     = 18
	damage_reduction = 1

	actions = [AtqNormal.new(), AtqPesado.new(), AcaoMover.new()]
	skills  = []
