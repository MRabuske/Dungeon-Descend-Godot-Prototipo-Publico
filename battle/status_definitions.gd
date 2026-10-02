class_name StatusDefinitions

# ======================================================
# Fonte ÚNICA de verdade para exibição de condições/status.
# StatusPanel e ExaminePanel consomem este registro — não duplicar
# nomes/cores/descrições em nenhum painel.
#
# A lógica de QUAL status está ativo vem sempre de
# BattleState.combatant_statuses[idx]; aqui só vivem os metadados de display.
#
# Chaves internas que NÃO devem aparecer na HUD (charmed_by, frightened_by,
# reaction_used, disengage, disengage_exempt, reaction_settings, death_saves_*,
# stable) simplesmente não estão no REGISTRY — os painéis iteram ORDER.
# ======================================================

# key -> { name: String (PT), desc: String, color: Color, duration: bool }
const REGISTRY: Dictionary = {
	# ── Condições D&D/BG3 ────────────────────────────────────────────────
	"burning":    {"name": "Em Chamas",   "desc": "Recebe 1d4 de Fogo no início do turno. Cancelado ao entrar na Água.", "color": Color(1.0, 0.45, 0.1),  "duration": true},
	"blinded":    {"name": "Cego",        "desc": "Desvantagem nos ataques. Ataques contra: Vantagem. Não faz Ataque de Oportunidade.", "color": Color(0.55, 0.55, 0.6), "duration": true},
	"frightened": {"name": "Amedrontado", "desc": "Não pode se aproximar da fonte do medo. Desvantagem em ataques.", "color": Color(0.8, 0.6, 0.2),   "duration": true},
	"paralyzed":  {"name": "Paralisado",  "desc": "Não pode mover nem agir. Ataques contra: Vantagem (crítico se melee). Falha automática em saves de FOR e DES.", "color": Color(0.9, 0.85, 0.3),  "duration": true},
	"restrained": {"name": "Contido",     "desc": "Não pode se mover. Ataques contra: Vantagem. Próprios ataques e saves de DES: Desvantagem.", "color": Color(0.6, 0.4, 0.25),  "duration": true},
	"invisible":  {"name": "Invisível",   "desc": "Próprios ataques: Vantagem. Ataques contra: Desvantagem.", "color": Color(0.6, 0.8, 1.0),   "duration": true},
	"charmed":    {"name": "Encantado",   "desc": "Não pode atacar quem o encantou.", "color": Color(1.0, 0.5, 0.85),  "duration": true},
	"grappled":   {"name": "Agarrado",    "desc": "Não pode se mover. Pode atacar normalmente.", "color": Color(0.7, 0.5, 0.35),  "duration": true},
	"prone":      {"name": "Prostrado",   "desc": "Caído. Ataques melee contra: Vantagem; ranged: Desvantagem. Levantar custa metade do movimento.", "color": Color(0.7, 0.7, 0.8),   "duration": false},

	# ── Status já existentes (unificados aqui para display coerente) ──────
	"stun":       {"name": "Atordoado",      "desc": "Perde o turno completamente.", "color": Color(1.0, 0.9, 0.2),  "duration": false},
	"poison":     {"name": "Veneno",         "desc": "Recebe dano no início do turno.", "color": Color(0.4, 0.9, 0.3),  "duration": true},
	"poisoned":   {"name": "Envenenado",     "desc": "Desvantagem em ataques e saves.", "color": Color(0.5, 0.8, 0.2),  "duration": true},
	"wet":        {"name": "Molhado",        "desc": "Vulnerável a Raio e Frio.", "color": Color(0.4, 0.7, 1.0),  "duration": true},
	"acid":       {"name": "Ácido",          "desc": "-2 de CA.", "color": Color(0.5, 0.9, 0.1),  "duration": true},
	"raging":     {"name": "Enfurecido",     "desc": "+2 de dano em ataques corpo a corpo.", "color": Color(1.0, 0.3, 0.2),  "duration": false},
	"fury":       {"name": "Fúria +4 dano",  "desc": "+4 de dano (Bárbaro).", "color": Color(1.0, 0.2, 0.0),  "duration": false},
	"furtivo":    {"name": "Furtivo",        "desc": "Vantagem na próxima rolagem de ataque.", "color": Color(0.7, 0.4, 1.0),  "duration": false},
	"bonus_d4":   {"name": "Abençoado",      "desc": "+1d4 nas rolagens de ataque e saves.", "color": Color(1.0, 0.9, 0.5),  "duration": true},
	"marked":     {"name": "Marcado",        "desc": "Quem o marcou causa dano extra ao acertá-lo.", "color": Color(0.9, 0.4, 0.4),  "duration": true},
	"hidden":     {"name": "Oculto",         "desc": "Vantagem nos ataques e habilita Furtivo. Quebra ao atacar ou ao ser avistado.", "color": Color(0.5, 0.5, 0.7),  "duration": false},
	"coated_fire":{"name": "Arma em Chamas", "desc": "+1d4 de Fogo nos próximos ataques com arma.", "color": Color(1.0, 0.5, 0.2),  "duration": true},
}

# Ordem de exibição nos painéis (condições negativas primeiro, buffs depois).
const ORDER: Array = [
	"burning", "blinded", "frightened", "paralyzed", "restrained",
	"charmed", "grappled", "prone", "stun", "poison", "poisoned",
	"wet", "acid", "invisible", "raging", "fury", "furtivo", "bonus_d4", "marked", "hidden", "coated_fire",
]

static func has(key: String) -> bool:
	return REGISTRY.has(key)

static func name_of(key: String) -> String:
	return REGISTRY.get(key, {}).get("name", key.capitalize())

static func desc_of(key: String) -> String:
	return REGISTRY.get(key, {}).get("desc", "")

static func color_of(key: String) -> Color:
	return REGISTRY.get(key, {}).get("color", Color.WHITE)

static func shows_duration(key: String) -> bool:
	return REGISTRY.get(key, {}).get("duration", false)
