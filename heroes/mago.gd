class_name MagoData
extends HeroData

func _init() -> void:
	hero_name    = "Mago"
	hero_class   = "Wizard"
	sprite       = preload("res://assets/sprites/hero/mago/mago.png")
	portrait     = preload("res://assets/ui/portraits/hero/mago/mago.png")
	level        = 4
	base_hp      = 60
	max_hp       = 100
	base_mp      = 100
	max_mp       = 100
	ac           = 12
	initiative   = 5
	speed        = 6
	proficiency  = 3
	strength     = 8
	dexterity    = 14
	intelligence = 18
	wisdom       = 12
	constitution = 10
	actions = [AtqArcano.new(), AcaoMover.new()]
	skills  = [SpellFogo.new(), SpellGelo.new(), SpellTrovao.new(), SpellCura.new()]
