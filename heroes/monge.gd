class_name MongeData
extends HeroData

func _init() -> void:
	hero_name    = "Monge"
	hero_class   = "Monk"
	sprite       = preload("res://assets/sprites/hero/monge/monge.png")
	portrait     = preload("res://assets/ui/portraits/hero/monge/monge.png")
	level        = 4
	base_hp      = 65
	max_hp       = 90
	base_mp      = 5
	max_mp       = 5
	ac           = 14
	initiative   = 11
	speed        = 10
	proficiency  = 3
	strength     = 12
	dexterity    = 18
	intelligence = 10
	wisdom       = 14
	constitution = 13
	damage_reduction = 0
	actions = [AtqSoco.new(), AtqRapido.new(), AcaoMover.new()]
	skills  = [SkillFlurry.new(), SkillPassoVento.new()]
