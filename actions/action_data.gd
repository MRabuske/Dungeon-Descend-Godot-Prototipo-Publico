class_name ActionData
extends Resource

enum Type { ATTACK, MOVE, END_TURN, DASH }

enum DamageAttribute { NONE, STR, DEX, INT, WIS, CON }

# Tipos de dano da BG3 (13) + HEALING (cura, nunca mitigada).
enum DamageType { SLASHING, PIERCING, BLUDGEONING, ACID, COLD, FIRE, FORCE, LIGHTNING, NECROTIC, POISON, PSYCHIC, RADIANT, THUNDER, HEALING }

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
@export var targets_allies: bool  = false
@export var self_target:    bool  = false
@export var bonus_action:   bool  = false

@export_group("Área (D&D 2024)")
## Forma da área (AreaShape.Kind). NONE = a ação não tem área. Esfera/cilindro: mira num CRUZAMENTO;
## cubo: mira numa casa; emanação: parte da casa da criatura de origem (o alvo, ou o próprio conjurador).
@export var area_kind: int = AreaShape.Kind.NONE
## Raio (esfera, cilindro, emanação), lado (cubo) ou comprimento (cone, linha), em PÉS (5 ft = 1 casa).
@export var area_size_ft: int = 0
## Largura da linha, em pés.
@export var area_width_ft: int = 5
## Emanação que também afeta a criatura de origem (a habilidade diz que sim).
@export var area_includes_origin: bool = false

@export_group("Power Points")
@export var pp:     int = 0
@export var max_pp: int = 0

@export_group("Dano")
@export var damage_attribute: DamageAttribute = DamageAttribute.NONE
@export var damage_type: DamageType = DamageType.BLUDGEONING
@export var damage_dice_count: int = 1
@export var damage_dice_sides: int = 6
@export var smite_dice_count: int = 0
@export var smite_dice_sides: int = 0
@export var is_weapon_attack:  bool = false
@export var use_versatile_grip: bool = false
@export var requires_saving_throw: bool = false
@export var hit_count: int = 1                  # número de hits por ação (Flurry = 2)

@export_group("Magia")
@export var spell_slot_level: int = 0  # 0 = cantrip/sem custo; 1-6 = nível do slot consumido
@export var ki_cost: int = 0           # Custo em Ki (apenas habilidades do Monge)
@export var requires_concentration: bool = false  # Spell exige concentração (um por vez)
## Magia (truque ou com slot): o dano NÃO soma o modificador de atributo (BG3). Ataque com arma soma.
@export var is_spell: bool = false

@export_group("Recursos genéricos")
## Gasta de um pool nomeado do jogador (ex.: "lay_on_hands"). "" = não usa pool.
@export var pool_key: String = ""
@export var pool_cost: int = 0
## Devolve a Ação principal uma vez (ex.: Surto de Ação), gastando uma carga.
@export var grants_extra_action: bool = false

@export_group("Reação")
@export var is_reaction: bool = false
# Gatilho que dispara a reação. Valores: "on_melee_hit_self" (este combatente acerta
# um ataque corpo-a-corpo), "on_attacked_ranged" (atingido por ataque à distância),
# "on_attacked_visible" (atacado por inimigo visível), "on_enemy_leave_melee" (OA).
@export var reaction_trigger: String = ""

@export_group("Visual do Projétil")
@export var projectile_texture: Texture2D
@export var projectile_frames: SpriteFrames
@export var projectile_scale:   Vector2 = Vector2(1.0, 1.0)
@export var projectile_speed:   float   = 1.0

@export_group("Visual do Impacto")
@export var impact_type:        int    = -1

@export_group("Áudio")
@export var sfx_cast:    String = ""
@export var sfx_impact:  String = ""

@export_group("Efeitos no Alvo")
@export var save_attribute: DamageAttribute = DamageAttribute.DEX
# Superfície persistente criada nos tiles atingidos após o ataque (0 = nenhuma)
@export var creates_surface: int = SurfaceType.Type.NONE
# Duração (s) do VFX de impacto persistente no alvo (ex.: chama). Antes: target_effect_dur.
@export var impact_vfx_dur: float = 2.0

@export_group("Condição aplicada")
## Chave de status (StatusDefinitions) aplicada ao alvo ao acertar. "" = nenhuma.
@export var applies_condition: String = ""
## Atributo do save do alvo p/ resistir à condição. NONE = aplica sem save (auto no acerto).
@export var condition_save_attribute: DamageAttribute = DamageAttribute.NONE
## Duração da condição em turnos.
@export var condition_duration: int = 2
## DC fixo do save da condição. 0 = usa 8 + proficiência + mod do atributo de conjuração.
@export var condition_dc: int = 0

@export_group("Efeito de suporte")
## Help/Ajuda: reergue alvo Downed para 1 HP.
@export var revives_downed: bool = false
## Help/Ajuda: condições removidas do alvo (vazio usa BattleState.HELP_CLEARS).
@export var clears_conditions: Array[String] = []

@export_group("Visual do AoE")
@export var aoe_projectile_frames: SpriteFrames
@export var aoe_impact_type: int = -1
@export var aoe_cascade_type: int = -1
@export var aoe_cascade_delay: float = 0.05
@export var aoe_instant: bool = false

func has_icon() -> bool:
	return icon != null

static func damage_type_color(t: DamageType) -> Color:
	match t:
		DamageType.SLASHING, DamageType.PIERCING, DamageType.BLUDGEONING:
			return Color(1.00, 0.95, 0.85)                      # branco quente (físico)
		DamageType.FORCE:     return Color(0.65, 0.40, 1.00)  # roxo
		DamageType.RADIANT:   return Color(1.00, 0.90, 0.30)  # dourado
		DamageType.FIRE:      return Color(1.00, 0.45, 0.10)  # laranja-vermelho
		DamageType.COLD:      return Color(0.40, 0.80, 1.00)  # azul gelo
		DamageType.LIGHTNING: return Color(0.85, 0.85, 0.20)  # amarelo
		DamageType.THUNDER:   return Color(0.60, 0.70, 0.95)  # azul acinzentado
		DamageType.POISON:    return Color(0.55, 0.75, 0.20)  # verde-oliva
		DamageType.ACID:      return Color(0.70, 0.95, 0.20)  # verde-limão
		DamageType.PSYCHIC:   return Color(1.00, 0.45, 0.80)  # rosa
		DamageType.HEALING:   return Color(0.30, 1.00, 0.45)  # verde
		DamageType.NECROTIC:  return Color(0.55, 0.20, 0.75)  # roxo escuro
	return Color.WHITE

func has_area() -> bool:
	return area_kind != AreaShape.Kind.NONE

## Esfera e cilindro se miram num cruzamento de casas (o cursor anda pelos cantos).
func aims_at_corner() -> bool:
	return area_kind == AreaShape.Kind.SPHERE or area_kind == AreaShape.Kind.CYLINDER

## Área mirada num ponto do chão (cruzamento ou casa livre, sem precisar de criatura no centro).
func aims_at_ground() -> bool:
	return aims_at_corner() or area_kind == AreaShape.Kind.CUBE

## Texto curto da forma e do tamanho, para tooltip e logs ("Esfera de 5 ft").
func area_text() -> String:
	var names := {AreaShape.Kind.SPHERE: "Esfera", AreaShape.Kind.CUBE: "Cubo", AreaShape.Kind.CONE: "Cone",
		AreaShape.Kind.LINE: "Linha", AreaShape.Kind.CYLINDER: "Cilindro", AreaShape.Kind.EMANATION: "Emanação"}
	return "%s de %d ft" % [names.get(area_kind, "Área"), area_size_ft] if has_area() else ""
