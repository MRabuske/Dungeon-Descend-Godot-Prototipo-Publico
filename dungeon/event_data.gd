class_name EventData
extends Resource

enum ConsequenceType {
	NOTHING            = 0,
	HEAL_PARTY         = 1,
	DAMAGE_PARTY       = 2,
	HEAL_TARGET        = 3,
	DAMAGE_TARGET      = 4,
	MP_RESTORE_PARTY   = 5,
	BUFF_NEXT_BATTLE   = 6,
	REVEAL_CONNECTIONS = 7,
	GO_TO_BATTLE       = 8,
}

# target semantics per consequence_type:
#   HEAL/DAMAGE_TARGET  → "random_hero" | "weakest_hero"
#   BUFF_NEXT_BATTLE    → "ATK_UP" | "DEF_UP"  (negative value = debuff)
#   GO_TO_BATTLE        → "none"  (routes to battle scene, skips complete_current_room)
#   everything else     → "party" | "none"
#
# is_random = true  → 50/50 between primary and secondary (mutually exclusive)
# is_random = false → primary always; secondary also applied if secondary_type != NOTHING
class EventChoice:
	var label: String
	var consequence_type: int
	var value: int
	var target: String
	var result_text: String
	var secondary_type: int    = ConsequenceType.NOTHING
	var secondary_value: int   = 0
	var secondary_target: String = "none"
	var secondary_text: String = ""
	var is_random: bool        = false

	func _init(
			l: String, ct: int, v: int, tgt: String, rt: String,
			sec_t: int = 0, sec_v: int = 0, sec_tgt: String = "none",
			sec_rt: String = "", rand: bool = false) -> void:
		label = l
		consequence_type = ct
		value = v
		target = tgt
		result_text = rt
		secondary_type = sec_t
		secondary_value = sec_v
		secondary_target = sec_tgt
		secondary_text = sec_rt
		is_random = rand
		assert(consequence_type in ConsequenceType.values(), "Invalid consequence_type: %d" % consequence_type)
		assert(secondary_type in ConsequenceType.values(), "Invalid secondary_type: %d" % secondary_type)

var id: String          = ""
var title: String       = ""
var description: String = ""
var choices: Array      = []   # Array[EventChoice] — typed annotation unsupported for inner classes

func _init(p_id: String, p_title: String, p_desc: String, p_choices: Array) -> void:
	id = p_id
	title = p_title
	description = p_desc
	choices = p_choices

static var REGISTRY: Dictionary = {}

static func _static_init() -> void:
	_build_registry()

static func get_for_node(node_id: int) -> EventData:
	var keys: Array = REGISTRY.keys()
	return REGISTRY[keys[abs(node_id) % keys.size()]]

static func _build_registry() -> void:
	var C := ConsequenceType
	var events: Array = [
		EventData.new("arcane_fountain", "Fonte Arcana",
			"Água cristalina e brilhante pulsa numa fonte no corredor.",
			[
				EventChoice.new("Beber",
					C.MP_RESTORE_PARTY, 25, "party",
					"A party absorve a energia. Todos recuperam 25 MP."),
				EventChoice.new("Examinar",
					C.NOTHING, 0, "none",
					"A fonte parece inofensiva. A party segue em frente."),
			]),
		EventData.new("cursed_altar", "Altar Maldito",
			"Runas sombrias pulsam num altar antigo. A energia é palpável.",
			[
				EventChoice.new("Ativar o Altar",
					C.BUFF_NEXT_BATTLE, 10, "ATK_UP",
					"O altar concede poder! ATK +10 na próxima batalha.",
					C.DAMAGE_TARGET, 25, "random_hero",
					"O altar reage violentamente, ferindo um herói!", true),
				EventChoice.new("Destruir",
					C.DAMAGE_PARTY, 10, "party",
					"O altar explode. A party sofre 10 de dano mas ganha DEF +8.",
					C.BUFF_NEXT_BATTLE, 8, "DEF_UP"),
				EventChoice.new("Ignorar",
					C.NOTHING, 0, "none",
					"A party segue em frente, prudentemente."),
			]),
		EventData.new("prisoner", "Prisioneiro",
			"Um aventureiro agoniza preso numa gaiola enferrujada.",
			[
				EventChoice.new("Libertar",
					C.REVEAL_CONNECTIONS, 0, "none",
					"Grato, o aventureiro revela rotas secretas no próximo andar."),
				EventChoice.new("Ignorar",
					C.NOTHING, 0, "none",
					"A party deixa o prisioneiro para trás."),
			]),
		EventData.new("trapped_chest", "Baú Armadilhado",
			"Um baú reluzente no centro da sala. Claramente armadilhado.",
			[
				EventChoice.new("Abrir com Cuidado",
					C.HEAL_PARTY, 20, "party",
					"A party encontra poções. Todos curam 20 HP."),
				EventChoice.new("Arrombar",
					C.HEAL_PARTY, 35, "party",
					"A armadilha dispara! A party cura 35 HP.",
					C.DAMAGE_TARGET, 30, "random_hero",
					"Um herói leva 30 de dano."),
			]),
		EventData.new("ritual", "Ritual Interrompido",
			"Energia residual de um ritual recente flutua no ar.",
			[
				EventChoice.new("Absorver a Energia",
					C.MP_RESTORE_PARTY, 40, "party",
					"A energia restaura o fôlego arcano. Todos recuperam 40 MP.",
					C.DAMAGE_PARTY, 15, "party",
					"A energia instável corrói a party. Todos perdem 15 HP.", true),
				EventChoice.new("Purificar",
					C.NOTHING, 0, "none",
					"A energia é dissipada com segurança. Sem efeitos."),
			]),
		EventData.new("campfire", "Fogueira",
			"Uma fogueira crepita num recanto protegido. Um raro momento de descanso.",
			[
				EventChoice.new("Descansar",
					C.HEAL_PARTY, 30, "party",
					"A party descansa junto à fogueira. Todos curam 30 HP.",
					C.MP_RESTORE_PARTY, 25, "party",
					"Todos recuperam 25 MP."),
				EventChoice.new("Manter Guarda",
					C.HEAL_TARGET, 60, "weakest_hero",
					"O herói mais fraco descansa enquanto os outros vigiam. Recupera 60 HP."),
			]),
	]
	for e: EventData in events:
		REGISTRY[e.id] = e
