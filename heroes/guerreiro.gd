class_name GuerreiroData
extends HeroData

func _init() -> void:
	hero_name    = "Guerreiro"
	hero_class   = "Fighter"
	sprite       = preload("res://assets/sprites/hero/guerreiro/guerreiro.png")
	portrait     = preload("res://assets/ui/portraits/hero/guerreiro/guerreiro.png")
	level        = 4
	base_hp      = 80
	max_hp       = 100
	base_mp      = 40
	max_mp       = 80
	ac           = 16
	initiative   = 8
	speed        = 7
	proficiency  = 3
	strength     = 16
	dexterity    = 12
	intelligence = 8
	wisdom       = 10
	constitution = 15
	actions = [AtqNormal.new(), AtqPesado.new(), AcaoMover.new()]
	skills  = [SkillSegundoVento.new()]
