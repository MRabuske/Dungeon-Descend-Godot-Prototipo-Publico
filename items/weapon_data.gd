class_name WeaponData
extends Resource

@export var weapon_name: String = ""
@export var damage_dice_count: int = 1
@export var damage_dice_sides: int = 6
@export var damage_attribute: ActionData.DamageAttribute = ActionData.DamageAttribute.STR
@export var is_finesse: bool = false
@export var versatile_dice_sides: int = 0
@export var attack_bonus: int = 0
