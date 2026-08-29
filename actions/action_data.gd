class_name ActionData
extends Resource

enum Type { ATTACK, MOVE, END_TURN }

enum DamageAttribute { NONE, STR, DEX, INT, WIS }

# Índices de shape para o SlotDrawer
const SHAPE_SQUARE   := 0  # ataque básico
const SHAPE_HEXAGON  := 1  # magia / habilidade
const SHAPE_CIRCLE   := 2  # item
const SHAPE_TRIANGLE := 3  # ação de turno
const SHAPE_ARROW    := 4  # movimento

# Índices de cor (ActionPanel.ACTION_ICON_COLORS)
const COLOR_ATTACK := 0
const COLOR_DEFEND := 1
const COLOR_WAIT   := 2
const COLOR_FLEE   := 3
const COLOR_SPELL  := 4
const COLOR_ITEM   := 5
const COLOR_MOVE   := 6

@export var label:       String = ""
@export var action_type: Type   = Type.ATTACK
@export var shape:       int    = SHAPE_SQUARE
@export var color_idx:   int    = COLOR_ATTACK

@export_group("Ícone Personalizado")
@export var icon: Texture2D

@export_group("Ataque")
@export var attack_range:   int   = 1
@export var proj_color:     Color = Color.WHITE
@export var aoe_radius:     int   = 0
@export var targets_allies: bool  = false
@export var self_target:    bool  = false
@export var bonus_action:   bool  = false

@export_group("Power Points")
@export var pp:     int = 0
@export var max_pp: int = 0

@export_group("Dano")
@export var damage_attribute: DamageAttribute = DamageAttribute.NONE
@export var base_damage_min:  int = 4
@export var base_damage_max:  int = 8

@export_group("Magia")
@export var mp_cost: int = 0


func has_icon() -> bool:
	return icon != null
