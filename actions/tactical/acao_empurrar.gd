class_name AcaoEmpurrar
extends ActionData

# Empurrar (Shove, BG3): Ação Bônus universal. Contest de Atletismo; empurra o
# alvo para longe (pode jogá-lo no void ou numa superfície). NÃO derruba Prone.
# A resolução vive em BattleState.resolve_shove().
func _init() -> void:
	label            = "Empurrar"
	action_type      = Type.ATTACK
	shape            = SHAPE_ARROW
	color_idx        = COLOR_DEFEND
	attack_range     = 1
	bonus_action     = true
	damage_attribute = DamageAttribute.NONE
	damage_dice_count = 0
	damage_dice_sides = 0
