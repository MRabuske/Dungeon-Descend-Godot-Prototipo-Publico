class_name AcaoArremessarPocao
extends ActionData

# Arremessar Poção (BG3, bg3.wiki/wiki/Potion_of_Healing): Ação, alcance 18 m = 12 casas. A nuvem
# cura quem estiver nela, aliado ou inimigo; é assim que se cura um aliado com a Poção (não há
# ação de "dar" a poção). Área: esfera de 5 ft (a nuvem do BG3 tem raio de 1 m; aceito como 1 casa).
func _init() -> void:
	label            = "Arremessar Poção"
	action_type      = Type.ATTACK
	shape            = SHAPE_CIRCLE
	color_idx        = COLOR_ITEM
	attack_range     = 12
	area_kind        = AreaShape.Kind.SPHERE
	area_size_ft     = 5
	damage_attribute = DamageAttribute.NONE
	damage_type      = DamageType.HEALING
	damage_dice_count = BattleState.POTION_DICE
	damage_dice_sides = BattleState.POTION_SIDES
