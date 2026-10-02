class_name GuerreiroData
extends HeroData

func _init() -> void:
	hero_name    = "Guerreiro"
	hero_class   = "Fighter"
	sprite       = preload("res://assets/sprites/hero/guerreiro/guerreiro.png")
	portrait     = preload("res://assets/ui/portraits/hero/guerreiro/guerreiro.png")
	sprite_frames = preload("res://assets/sprites/hero/guerreiro/guerreiro_animation.tres")
	level        = 4
	base_hp      = 80
	max_hp       = 100
	ac           = 16
	initiative   = 8
	speed        = 7
	proficiency  = 3
	strength     = 16
	dexterity    = 12
	intelligence = 8
	wisdom       = 10
	constitution = 15
	charisma     = 10
	save_proficiencies = ["STR", "CON"]
	weapon = HeroData.make_weapon("Longsword", 1, 8, ActionData.DamageAttribute.STR, false, 10)
	actions = [AtqNormal.new(), AtqPesado.new(), AcaoMover.new()]
	skills  = [SkillSegundoVento.new(), SkillAjuda.new()]
