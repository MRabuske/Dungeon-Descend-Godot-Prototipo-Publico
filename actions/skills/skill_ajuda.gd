class_name SkillAjuda
extends ActionData

# Ação Ajudar (Help Action, BG3): ergue um aliado Downed (1 HP) e remove
# condições (Prone, Contido, Em Chamas…) do alvo. Tratada como Ação (não
# Bônus), alinhando ao BG3. Sem custo de slot.
func _init() -> void:
	label             = "Ajuda"
	action_type       = Type.ATTACK
	shape             = SHAPE_CIRCLE
	color_idx         = COLOR_ITEM
	attack_range      = 2
	targets_allies    = true
	bonus_action      = false
	revives_downed    = true
	clears_conditions = ["prone", "restrained", "burning"]
	damage_dice_count = 0
	damage_dice_sides = 4
	damage_attribute  = DamageAttribute.NONE
