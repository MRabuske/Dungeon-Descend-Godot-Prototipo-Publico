class_name BattleState
extends RefCounted

enum State { PLAYER_TURN, ENEMY_TURN, MOVE_MODE, ATTACK_MODE }

enum Tab { ACTION, HABILIDADES, ITEMS }

var grid_cols: int = 12
var grid_rows: int = 7
var tile_data_map: Array = []
var context_message: String = ""
var enemy_hp: Dictionary = {}
var hero_spawns: Array[Vector2i] = []
var enemy_spawns: Array[Vector2i] = []

static var ALL_HERO_DATA: Dictionary = {
	"Guerreiro": GuerreiroData.new(),
	"Mago":      MagoData.new(),
	"Arqueiro":  ArqueiroData.new(),
	"Clérigo":   ClérigoData.new(),
	"Ladrao":    LadraoData.new(),
	"Bárbaro":   BarbaroData.new(),
	"Paladino":  PaladinoData.new(),
	"Monge":     MongeData.new(),
}

static var ALL_ENEMIES: Dictionary = {
	"Goblin":          GoblinScoutData.new(),
	"Orc":             OrcWarriorData.new(),
	"Mage":            DarkMageData.new(),
	"Undead":          SkeletonArcherData.new(),
	"EliteWarrior":    EliteWarriorData.new(),
	"EliteMage":       EliteMageData.new(),
	"DungeonGuardian": DungeonGuardianData.new(),
}

static var TURN_QUEUE: Array = [
	{"name": "Guerreiro",        "is_player": true},
	{"name": "Goblin Scout",     "is_player": false, "type": "Goblin",  "ac": 13},
	{"name": "Mago",             "is_player": true},
	{"name": "Arqueiro",         "is_player": true},
	{"name": "Orc Warrior",      "is_player": false, "type": "Orc",     "ac": 15},
	{"name": "Clérigo",          "is_player": true},
	{"name": "Dark Mage",        "is_player": false, "type": "Mage",    "ac": 11},
	{"name": "Skeleton Archer",  "is_player": false, "type": "Undead",  "ac": 12},
	{"name": "Ladrao",           "is_player": true},
	{"name": "Bárbaro",          "is_player": true},
	{"name": "Paladino",         "is_player": true},
	{"name": "Monge",            "is_player": true},
]

# Slots calculados para nível 4: Full caster=[4,3,...], Half caster=[3,0,...],
# non-caster=[0,...]. Monge é non-caster mas tem 4 Ki (level 4 × ki_per_level 1).
static var PLAYERS: Array = [
	{"name": "Guerreiro", "hp": 80,  "max_hp": 100, "spell_slots": [0,0,0,0,0,0], "spell_slots_max": [0,0,0,0,0,0], "ki": 0, "ki_max": 0,
	 "class": "Fighter", "level": 4, "ac": 16, "initiative": 8,  "speed": 7, "proficiency": 3},
	{"name": "Mago",      "hp": 60,  "max_hp": 100, "spell_slots": [4,3,0,0,0,0], "spell_slots_max": [4,3,0,0,0,0], "ki": 0, "ki_max": 0,
	 "class": "Wizard",  "level": 4, "ac": 12, "initiative": 5,  "speed": 6, "proficiency": 3},
	{"name": "Arqueiro",  "hp": 70,  "max_hp": 100, "spell_slots": [3,0,0,0,0,0], "spell_slots_max": [3,0,0,0,0,0], "ki": 0, "ki_max": 0,
	 "class": "Ranger",  "level": 4, "ac": 14, "initiative": 10, "speed": 8, "proficiency": 3},
	{"name": "Clérigo",   "hp": 75,  "max_hp": 100, "spell_slots": [4,3,0,0,0,0], "spell_slots_max": [4,3,0,0,0,0], "ki": 0, "ki_max": 0,
	 "class": "Cleric",  "level": 4, "ac": 15, "initiative": 6,  "speed": 7, "proficiency": 3},
	{"name": "Ladrao",    "hp": 55,  "max_hp": 100, "spell_slots": [0,0,0,0,0,0], "spell_slots_max": [0,0,0,0,0,0], "ki": 0, "ki_max": 0,
	 "class": "Rogue",   "level": 4, "ac": 13, "initiative": 9,  "speed": 9, "proficiency": 3},
	{"name": "Bárbaro",  "hp": 95,  "max_hp": 120, "spell_slots": [0,0,0,0,0,0], "spell_slots_max": [0,0,0,0,0,0], "ki": 0, "ki_max": 0,
	 "class": "Barbarian", "level": 4, "ac": 12, "initiative": 7, "speed": 6, "proficiency": 3},
	{"name": "Paladino",  "hp": 80,  "max_hp": 110, "spell_slots": [3,0,0,0,0,0], "spell_slots_max": [3,0,0,0,0,0], "ki": 0, "ki_max": 0,
	 "class": "Paladin", "level": 4, "ac": 16, "initiative": 6,  "speed": 6, "proficiency": 3},
	{"name": "Monge",     "hp": 65,  "max_hp": 90,  "spell_slots": [0,0,0,0,0,0], "spell_slots_max": [0,0,0,0,0,0], "ki": 4, "ki_max": 4,
	 "class": "Monk",    "level": 4, "ac": 14, "initiative": 11, "speed": 10, "proficiency": 3},
]

static func setup_party(hero_names: Array) -> void:
	PLAYERS = []
	TURN_QUEUE = []
	for hname in hero_names:
		var hero: HeroData = ALL_HERO_DATA.get(hname)
		if hero != null:
			PLAYERS.append(hero.to_combat_dict())
			TURN_QUEUE.append({"name": hname, "is_player": true})
	for edata: EnemyData in ALL_ENEMIES.values():
		TURN_QUEUE.append({
			"name": edata.enemy_name,
			"is_player": false,
			"type": edata.enemy_type,
			"ac": edata.ac,
		})
	for p in PLAYERS:
		p["bonus_atk"] = 0
		p["bonus_def"] = 0
		# Recursos genéricos (tipos no motor; atribuição é build).
		p["pools"] = p.get("pools", {})                          # { key: {current, max} }
		p["extra_action_max"] = p.get("extra_action_max", 0)
		p["extra_action_charges"] = p.get("extra_action_max", 0)

static func reset_players() -> void:
	for p in PLAYERS:
		var hero: HeroData = ALL_HERO_DATA.get(p["name"])
		if hero != null:
			p["hp"] = hero.base_hp
			p["spell_slots"] = hero.get_spell_slots_max()
			p["ki"] = hero.ki_max()
		# Recarrega recursos genéricos (encontro/descanso — cruza com 3.5).
		for pk in p.get("pools", {}).keys():
			p["pools"][pk]["current"] = p["pools"][pk].get("max", 0)
		p["extra_action_charges"] = p.get("extra_action_max", 0)

static func setup_enemies_for_room(room_type: int) -> void:
	TURN_QUEUE = TURN_QUEUE.filter(func(e: Dictionary) -> bool:
		return e.get("is_player", false))

	var enemy_keys: Array
	match room_type:
		DungeonState.RoomType.ELITE:
			enemy_keys = ["EliteWarrior", "EliteMage"]
		DungeonState.RoomType.BOSS:
			enemy_keys = ["DungeonGuardian"]
		_:
			enemy_keys = ["Goblin", "Orc", "Mage", "Undead"]

	for key in enemy_keys:
		var edata: EnemyData = ALL_ENEMIES.get(key, null)
		if edata != null:
			TURN_QUEUE.append({
				"name":      edata.enemy_name,
				"is_player": false,
				"type":      edata.enemy_type,
				"ac":        edata.ac,
			})

var tab_action:      Array[ActionData] = []
var tab_habilidades: Array[ActionData] = []

static var TAB_ITEMS: Array = [
	{"label": "Poção", "shape": 2, "color_idx": 5, "count": 3, "is_item": true, "heal": 30},
	{"label": "Éter",  "shape": 2, "color_idx": 5, "count": 1, "is_item": true, "spell_slot_restore": 1},
]

static var TAB_END_TURN: Array[ActionData] = [
	AcaoEsperar.new(),
	AcaoFugir.new(),
]

const TAB_LABELS := ["ACTION", "HABILIDADES", "ITEMS"]
const MAX_SLOTS  := 6
# Condições que a ação Ajudar/Help remove do alvo (BG3). Manter genérico:
# acrescentar novas chaves aqui conforme forem criadas (ensnared, sleeping…).
const HELP_CLEARS := ["prone", "restrained", "burning"]

var current_state:        State     = State.PLAYER_TURN
var active_index:         int       = 0
var active_tab:           int       = 0
var cursor_position:      int       = 0
var enemy_action_text:         String    = ""
var active_enemy_action_idx:   int       = 0
var move_points_remaining:     int       = 0
var _last_move_cost:           int       = 0
var has_attacked:         bool      = false
var has_used_bonus_action: bool     = false
var fury_extra_attack:    bool      = false
var _sneak_attack_used_this_turn: bool = false
var move_cursor:          Vector2i  = Vector2i(2, 3)
var attack_target_indices: Array[int] = []
var attack_cursor_idx:    int       = 0
var current_attack_range: int       = 0
var current_attack_color: Color     = Color.WHITE
var current_aoe_radius:   int       = 0
# Mira de AoE em PONTO do chao (BG3): quando ativo, o cursor de ataque e um TILE
# livre dentro do alcance (nao precisa de criatura no centro). Ligado em
# enter_attack_mode quando aoe_radius > 0.
var attack_tile_mode:     bool      = false
var attack_tile_cursor:   Vector2i  = Vector2i.ZERO
var _attack_targets_allies: bool    = false
var _attack_self_target: bool       = false
var _current_attack_is_bonus: bool  = false
var _current_action: ActionData     = null
var battle_stats: Dictionary = {}
var _undo_move_pos:       Vector2i  = Vector2i.ZERO
var _undo_attack_info:    Dictionary = {}
var combatant_positions: Array[Vector2i] = []

func _init() -> void:
	tile_data_map.clear()
	for col in range(grid_cols):
		var column: Array[TerrainTile] = []
		for row in range(grid_rows):
			var tile := TerrainTile.new()
			tile.ground = TerrainTile.GroundType.NORMAL
			column.append(tile)
		tile_data_map.append(column)
	enemy_hp.clear()
	for entry in TURN_QUEUE:
		if not entry["is_player"]:
			var edata := ALL_ENEMIES.get(entry.get("type", ""), null) as EnemyData
			var max_hp: int = edata.max_hp if edata != null else 30
			enemy_hp[entry["name"]] = max_hp
	combatant_positions.clear()
	for _i in range(TURN_QUEUE.size()):
		combatant_positions.append(Vector2i.ZERO)
	combatant_statuses.clear()
	for _i in range(TURN_QUEUE.size()):
		combatant_statuses.append({})
	tile_surfaces.clear()
	_acted_this_round.clear()
	if TURN_QUEUE.size() > 0 and TURN_QUEUE[0].get("is_player", false):
		_load_hero_actions(TURN_QUEUE[0]["name"])
	_refill_move_points()

func setup(map_data) -> void:
	grid_cols = map_data.grid_cols
	grid_rows = map_data.grid_rows
	tile_data_map = map_data.tile_data_map
	hero_spawns = map_data.hero_spawns
	enemy_spawns = map_data.enemy_spawns
	TAB_ITEMS = [
		{"label": "Poção", "shape": 2, "color_idx": 5, "count": 3, "is_item": true, "heal": 30},
		{"label": "Éter",  "shape": 2, "color_idx": 5, "count": 1, "is_item": true, "spell_slot_restore": 1},
	]
	dead_indices.clear()
	battle_result = ""
	combatant_statuses.clear()
	for _i in range(TURN_QUEUE.size()):
		combatant_statuses.append({})
	tile_surfaces.clear()
	_acted_this_round.clear()
	last_attack_info.clear()
	combat_log.clear()
	pending_deaths.clear()
	battle_stats = {
		"turns": 0,
		"player_damage_dealt": 0,
		"enemy_damage_dealt": 0,
		"crits": 0,
		"enemy_deaths": 0,
		"player_deaths": 0,
	}
	var hero_idx := 0
	var enemy_idx := 0
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"]:
			if hero_idx < map_data.hero_spawns.size():
				combatant_positions[i] = map_data.hero_spawns[hero_idx]
			hero_idx += 1
		else:
			if enemy_idx < map_data.enemy_spawns.size():
				combatant_positions[i] = map_data.enemy_spawns[enemy_idx]
			enemy_idx += 1
	if DungeonState.current_run != null and \
			not DungeonState.current_run.pending_buffs.is_empty():
		for buff in DungeonState.current_run.pending_buffs:
			var btype: String = buff.get("type", "")
			var bval: int     = buff.get("value", 0)
			for p in PLAYERS:
				match btype:
					"ATK_UP": p["bonus_atk"] = p.get("bonus_atk", 0) + bval
					"DEF_UP": p["bonus_def"] = p.get("bonus_def", 0) + bval
		DungeonState.current_run.pending_buffs.clear()
		DungeonState.current_run.save()

func _tile_cost(pos: Vector2i) -> int:
	var tile: TerrainTile = tile_data_map[pos.x][pos.y]
	if tile.ground == TerrainTile.GroundType.MUD:
		return 2
	if tile_surfaces.get(pos, {}).get("type", SurfaceType.Type.NONE) == SurfaceType.Type.ICE:
		return 2
	return 1

func _tile_at(idx: int) -> int:
	var pos: Vector2i = combatant_positions[idx]
	var tile: TerrainTile = tile_data_map[pos.x][pos.y]
	match tile.ground:
		TerrainTile.GroundType.NORMAL:
			return MapGenerator.TileType.NORMAL
		TerrainTile.GroundType.MUD:
			return MapGenerator.TileType.MUD
		_:
			return MapGenerator.TileType.NORMAL

func _is_elevated(idx: int) -> bool:
	var pos: Vector2i = combatant_positions[idx]
	var tile: TerrainTile = tile_data_map[pos.x][pos.y]
	return tile.ground == TerrainTile.GroundType.ELEVATED

# ── SUPERFÍCIES ──────────────────────────────────────────────────────────────
# Camadas elementais persistentes sobre tiles. Criadas por spells/armadilhas,
# aplicam efeitos ao entrar no tile ou no início do turno. Ver battle/surface_type.gd.

# Distância em TILES (Chebyshev / king-move): inclui diagonais. Métrica única de
# alcance de ataque/spell e de raio de AoE (D&D/BG3). NÃO usar para movimento/AI.
static func king_dist(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))

func _get_tiles_in_radius(center: Vector2i, radius: int) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if maxi(absi(dx), absi(dy)) <= radius:
				var p := center + Vector2i(dx, dy)
				if p.x >= 0 and p.x < grid_cols and p.y >= 0 and p.y < grid_rows:
					if not tile_data_map[p.x][p.y].is_void():
						tiles.append(p)
	return tiles

# Resultado quando duas superfícies se encontram no mesmo tile.
# 'incoming' é a superfície nova sendo depositada.
func _resolve_surface_interaction(existing: int, incoming: int) -> int:
	var pair := [existing, incoming]
	# Fogo + Água → Vapor (temporário)
	if SurfaceType.Type.FIRE in pair and SurfaceType.Type.WATER in pair:
		return SurfaceType.Type.STEAM
	# Fogo + Gelo → Água (gelo derrete)
	if SurfaceType.Type.FIRE in pair and SurfaceType.Type.ICE in pair:
		return SurfaceType.Type.WATER
	# Água + Frio → Gelo
	if existing == SurfaceType.Type.WATER and incoming == SurfaceType.Type.ICE:
		return SurfaceType.Type.ICE
	# Água + Trovão (marcador ELECTRIFIED_WATER) → Água Eletrificada
	if existing == SurfaceType.Type.WATER and incoming == SurfaceType.Type.ELECTRIFIED_WATER:
		return SurfaceType.Type.ELECTRIFIED_WATER
	# Padrão: a nova substitui a existente
	return incoming

func _add_surface(pos: Vector2i, type: int) -> void:
	if type == SurfaceType.Type.NONE:
		tile_surfaces.erase(pos)
		return
	var existing_type: int = tile_surfaces.get(pos, {}).get("type", SurfaceType.Type.NONE)
	var result_type: int = type if existing_type == SurfaceType.Type.NONE \
		else _resolve_surface_interaction(existing_type, type)
	if result_type == SurfaceType.Type.NONE:
		tile_surfaces.erase(pos)
	else:
		tile_surfaces[pos] = {"type": result_type, "turns": SurfaceType.DURATION[result_type]}

# Pinta superfície no tile do alvo + tiles de AoE após um ataque bem-sucedido.
# Para Trovão (marcador ELECTRIFIED_WATER): só converte tiles que já têm Água.
func _deposit_surface_after_attack(target_pos: Vector2i, action: ActionData) -> void:
	if action == null or action.creates_surface == SurfaceType.Type.NONE:
		return
	var radius: int = action.aoe_radius if action.aoe_radius > 0 else 0
	var tiles: Array[Vector2i] = _get_tiles_in_radius(target_pos, radius)
	for t in tiles:
		if action.creates_surface == SurfaceType.Type.ELECTRIFIED_WATER:
			if tile_surfaces.get(t, {}).get("type", SurfaceType.Type.NONE) == SurfaceType.Type.WATER:
				_add_surface(t, SurfaceType.Type.ELECTRIFIED_WATER)
		else:
			_add_surface(t, action.creates_surface)
	# Fogo criado EMBAIXO de um combatente parado tambem o deixa "Em Chamas"
	# (BG3), nao so quando ele anda para dentro. Checa o tipo RESULTANTE de cada
	# tile (respeita interacoes Fogo+Agua->Vapor / Fogo+Gelo->Agua). Sem dano
	# imediato: a spell ja aplicou o dano e o tick de burning cuida do resto.
	for t in tiles:
		if tile_surfaces.get(t, {}).get("type", SurfaceType.Type.NONE) != SurfaceType.Type.FIRE:
			continue
		for ci in range(TURN_QUEUE.size()):
			if dead_indices.has(ci):
				continue
			if combatant_positions[ci] == t:
				_ignite(ci)

# Aplica/renova a condicao "Em Chamas" (Burning): 1d4 de Fogo/turno por 2 turnos.
# Regra unica de ignicao reutilizada por: andar para dentro do fogo
# (apply_surface_on_enter), fogo criado embaixo (_deposit_surface_after_attack)
# e permanecer sobre o fogo no inicio do turno (_apply_surface_tick).
func _ignite(idx: int) -> void:
	apply_condition(idx, "burning", 2)

# Aplica dano a um combatente (jogador ou inimigo), tratando morte.
# Centraliza a ramificação player/enemy usada por superfícies.
func _deal_damage_to_combatant(combatant_idx: int, dmg: int) -> void:
	var entry: Dictionary = TURN_QUEUE[combatant_idx]
	if entry["is_player"]:
		var pidx: int = _player_index_by_name(entry["name"])
		if pidx >= 0:
			PLAYERS[pidx]["hp"] = maxi(0, PLAYERS[pidx]["hp"] - dmg)
			_check_concentration_after_damage(combatant_idx, dmg)
			if PLAYERS[pidx]["hp"] <= 0:
				_on_death(combatant_idx)
	else:
		var new_hp: int = maxi(0, enemy_hp.get(entry["name"], 0) - dmg)
		enemy_hp[entry["name"]] = new_hp
		if new_hp <= 0:
			_on_death(combatant_idx)

# Registra um indicador VISUAL de dano no canal pending_surface_hits (lido por
# BattleScene._flush_surface_floaters: floater + hit-flash + barra de HP).
# PURAMENTE VISUAL — não altera HP/morte/concentração. `color` = cor do tipo de
# dano (ver ActionData.damage_type_color); `label` opcional (ex.: "Veneno").
func _register_damage_floater(target_idx: int, damage: int, color: Color, label: String = "") -> void:
	if damage <= 0:
		return
	pending_surface_hits.append({"target_idx": target_idx, "damage": damage, "label": label, "color": color})

# ── Mitigação por tipo de dano (Resistência/Vulnerabilidade/Imunidade) ───────
# Convenção: strings das listas = nomes do enum DamageType (ex.: "FIRE"),
# comparadas case-insensitive. HEALING nunca é mitigado.
func _damage_type_name(damage_type: int) -> String:
	return ActionData.DamageType.keys()[damage_type]

func _type_in_list(list, type_name: String) -> bool:
	for s in list:
		if String(s).to_upper() == type_name.to_upper():
			return true
	return false

# Núcleo PURO: aplica imunidade/resistência/vulnerabilidade + Wet a um valor.
# Imunidade → 0; resist+vuln do mesmo tipo → normal (cancelam);
# resistência → metade (divisão inteira, pode chegar a 0); vulnerabilidade → dobro.
func _mitigate(amount: int, damage_type: int, res, vuln, imm, wet: bool) -> int:
	if damage_type == ActionData.DamageType.HEALING:
		return amount
	var tname: String = _damage_type_name(damage_type)
	if _type_in_list(imm, tname):
		return 0
	var resistant: bool = _type_in_list(res, tname)
	var vulnerable: bool = _type_in_list(vuln, tname)
	# Wet (BG3): vulnerabilidade dinâmica a COLD e THUNDER.
	if wet and (damage_type == ActionData.DamageType.COLD or damage_type == ActionData.DamageType.THUNDER):
		vulnerable = true
	if resistant and vulnerable:
		return amount          # cancelam → dano normal
	if resistant:
		return amount / 2      # divisão inteira arredonda p/ baixo
	if vulnerable:
		return amount * 2
	return amount

# Engrenagem ÚNICA usada por todos os pontos de dano. Busca as listas do alvo
# (HeroData/EnemyData) e o status Wet, e devolve o dano mitigado.
func _apply_damage_type_mods(target_idx: int, damage_type: int, amount: int) -> int:
	var entry: Dictionary = TURN_QUEUE[target_idx]
	var res: Array = []
	var vuln: Array = []
	var imm: Array = []
	if entry["is_player"]:
		var hd: HeroData = ALL_HERO_DATA.get(entry["name"], null)
		if hd != null:
			res = hd.resistances
			vuln = hd.vulnerabilities
			imm = hd.immunities
	else:
		var ed: EnemyData = ALL_ENEMIES.get(entry.get("type", ""), null)
		if ed != null:
			res = ed.resistances
			vuln = ed.vulnerabilities
			imm = ed.immunities
	var wet: bool = combatant_statuses[target_idx].get("wet", 0) > 0
	return _mitigate(amount, damage_type, res, vuln, imm, wet)

# Decrementa a duração de todas as superfícies; remove as que expiraram.
# Chamado uma vez por advance_turn (1 tick por turno de combatente).
func _tick_all_surfaces() -> void:
	var expired: Array[Vector2i] = []
	for pos in tile_surfaces:
		tile_surfaces[pos]["turns"] -= 1
		if tile_surfaces[pos]["turns"] <= 0:
			expired.append(pos)
	for pos in expired:
		tile_surfaces.erase(pos)

# Dano de superfície no início do turno do combatente que está sobre ela.
func _apply_surface_tick(combatant_idx: int) -> void:
	var pos: Vector2i = combatant_positions[combatant_idx]
	var s_type: int = tile_surfaces.get(pos, {}).get("type", SurfaceType.Type.NONE)
	if s_type == SurfaceType.Type.FIRE:
		# Fonte unica: permanecer sobre o fogo (re)aplica "Em Chamas". O dano vem
		# do tick de burning em advance_turn — nao ha dano direto de superficie.
		_ignite(combatant_idx)
		return
	if not SurfaceType.TICK_DAMAGE.has(s_type):
		return
	var td: Dictionary = SurfaceType.TICK_DAMAGE[s_type]
	var dmg: int = DiceRoller.roll(td["count"], td["sides"])
	var type_name: String
	match s_type:
		SurfaceType.Type.CLOUD_OF_DAGGERS: type_name = "nuvem de adagas"
		_:                                 type_name = "raio"
	_register_damage_floater(combatant_idx, dmg, ActionData.damage_type_color(ActionData.DamageType.PHYSICAL), "Cortante")
	_deal_damage_to_combatant(combatant_idx, dmg)
	_log("%s sofreu %d de dano de %s (superfície)" % [TURN_QUEUE[combatant_idx]["name"], dmg, type_name], "dmg")

# Sneak Attack (BG3/D&D): só dispara se o Ladrão tiver Vantagem líquida na
# rolagem OU houver um aliado a ≤1 tile do alvo, e no máximo uma vez por turno.
func _can_sneak_attack(attacker_idx: int, target_idx: int) -> bool:
	if _sneak_attack_used_this_turn:
		return false
	var entry: Dictionary = TURN_QUEUE[attacker_idx]
	if not entry.get("is_player", false):
		return false
	var hdata := ALL_HERO_DATA.get(entry["name"], null) as HeroData
	if hdata == null or hdata.hero_class != "Rogue":
		return false
	# Condição 1: vantagem líquida nesta rolagem de ataque.
	var mods: Dictionary = _get_attack_roll_mods(attacker_idx, target_idx, current_attack_range)
	if mods["adv"] > 0 and mods["dis"] == 0:
		return true
	# Condição 2: um aliado do Ladrão adjacente ao alvo (Manhattan ≤ 1).
	var target_pos: Vector2i = combatant_positions[target_idx]
	for i in range(TURN_QUEUE.size()):
		if i == attacker_idx or dead_indices.has(i):
			continue
		if TURN_QUEUE[i].get("is_player", false):
			var ally_pos: Vector2i = combatant_positions[i]
			if absi(ally_pos.x - target_pos.x) + absi(ally_pos.y - target_pos.y) <= 1:
				return true
	return false

func get_active_combatant() -> Dictionary:
	return TURN_QUEUE[active_index % TURN_QUEUE.size()]

func is_player_turn() -> bool:
	return get_active_combatant()["is_player"]

func get_active_player_index() -> int:
	if not is_player_turn():
		return -1
	var active_name: String = get_active_combatant()["name"]
	for i in range(PLAYERS.size()):
		if PLAYERS[i]["name"] == active_name:
			return i
	return -1

## The action currently selected for an attack/skill/spell (set by enter_attack_mode flow).
func get_current_action() -> ActionData:
	return _current_action

## Estimated probability [0.05, 0.95] that the active player hits target_idx with the
## current action. Mirrors the bonus math in _apply_attack() but rolls no dice.
## Auto-hit actions (AOE, or non-weapon spells that consume a spell slot) return 1.0.
func calc_hit_chance(target_idx: int) -> float:
	var action := _current_action
	if action != null and (action.aoe_radius > 0 or (not action.is_weapon_attack and action.spell_slot_level > 0)):
		return 1.0
	var pidx := get_active_player_index()
	if pidx < 0 or target_idx < 0 or target_idx >= TURN_QUEUE.size():
		return 0.5
	var target_ac: int = TURN_QUEUE[target_idx].get("ac", 10)
	var prof: int = PLAYERS[pidx].get("proficiency", 2)
	var weapon: WeaponData = PLAYERS[pidx].get("weapon", null)
	var weapon_attack_bonus: int = 0
	var attr: ActionData.DamageAttribute = ActionData.DamageAttribute.STR
	if action != null and action.is_weapon_attack and weapon != null:
		attr = weapon.damage_attribute
		weapon_attack_bonus = weapon.attack_bonus
		if weapon.is_finesse:
			var p: Dictionary = PLAYERS[pidx]
			var str_mod := _raw_mod(p.get("strength",  10))
			var dex_mod := _raw_mod(p.get("dexterity", 10))
			attr = ActionData.DamageAttribute.DEX if dex_mod >= str_mod else ActionData.DamageAttribute.STR
	elif action != null:
		attr = action.damage_attribute
	var attr_mod: int = _get_attr_modifier(attr)
	var bonus: int = prof + attr_mod + weapon_attack_bonus
	return clampf((21.0 - target_ac + bonus) / 20.0, 0.05, 0.95)

func _load_hero_actions(player_name: String) -> void:
	var hdata: HeroData = ALL_HERO_DATA.get(player_name, null)
	if hdata == null:
		return
	tab_action = []
	for a in hdata.actions:
		tab_action.append(a.duplicate())
	# Dash disponivel para todos os herois — inserido antes do Mover (sempre o
	# ultimo) para ficar junto das acoes de movimento.
	var dash := DashAction.new()
	if not tab_action.is_empty() and tab_action[tab_action.size() - 1] is AcaoMover:
		tab_action.insert(tab_action.size() - 1, dash)
	else:
		tab_action.append(dash)
	# Desengajar disponível para todos — gasta a ação principal e impede OA.
	var diseng := AcaoDesengajar.new()
	if not tab_action.is_empty() and tab_action[tab_action.size() - 1] is AcaoMover:
		tab_action.insert(tab_action.size() - 1, diseng)
	else:
		tab_action.append(diseng)
	tab_habilidades = []
	for s in hdata.skills:
		tab_habilidades.append(s.duplicate())
	# Ações táticas BG3 universais (3.3): qualquer combatente as usa.
	tab_habilidades.append(AcaoEmpurrar.new())
	tab_habilidades.append(AcaoEsconder.new())
	tab_habilidades.append(AcaoDip.new())
	tab_habilidades.append(AcaoPular.new())
	tab_habilidades.append(AcaoArremessar.new())

func is_item_available(item) -> bool:
	if item is ActionData:
		var action := item as ActionData
		if action.action_type == ActionData.Type.ATTACK:
			if action.bonus_action:
				if has_used_bonus_action:
					return false
			elif has_attacked:
				return fury_extra_attack
		if action.action_type == ActionData.Type.MOVE and move_points_remaining <= 0:
			return false
		# Dash gasta a Action principal — indisponivel se ela ja foi usada.
		if action.action_type == ActionData.Type.DASH and has_attacked:
			return false
		# Desengajar tambem gasta a Action principal.
		if action is AcaoDesengajar and has_attacked:
			return false
		# Esconder gasta a Action principal.
		if action is AcaoEsconder and has_attacked:
			return false
		# Mergulhar gasta a Ação Bônus.
		if action is AcaoDip and has_used_bonus_action:
			return false
		# Pular exige deslocamento disponível.
		if action is AcaoPular and move_points_remaining < JUMP_MOVE_COST:
			return false
		if action.spell_slot_level > 0:
			var pidx := get_active_player_index()
			if pidx >= 0:
				var slots: Array = PLAYERS[pidx].get("spell_slots", [0, 0, 0, 0, 0, 0])
				var has_slot := false
				for i in range(action.spell_slot_level - 1, slots.size()):
					if slots[i] > 0:
						has_slot = true
						break
				if not has_slot:
					return false
		if action.ki_cost > 0:
			var pidx_ki := get_active_player_index()
			if pidx_ki >= 0 and PLAYERS[pidx_ki].get("ki", 0) < action.ki_cost:
				return false
		if action.max_pp > 0 and action.pp <= 0:
			return false
		# Recurso genérico "pool" (ex.: Imposição de Mãos).
		if action.pool_key != "":
			var pidx_pool := get_active_player_index()
			if pidx_pool >= 0:
				var pool: Dictionary = PLAYERS[pidx_pool].get("pools", {}).get(action.pool_key, {})
				if pool.get("current", 0) < action.pool_cost:
					return false
		# Recurso genérico "ação extra" (ex.: Surto de Ação).
		if action.grants_extra_action:
			var pidx_ex := get_active_player_index()
			if pidx_ex >= 0 and PLAYERS[pidx_ex].get("extra_action_charges", 0) <= 0:
				return false
		return true
	if item is Dictionary:
		return item.get("count", 0) > 0
	return false

# Gasta `amount` de um pool nomeado do jogador. Retorna false se insuficiente.
func _spend_pool(pidx: int, key: String, amount: int) -> bool:
	if pidx < 0 or pidx >= PLAYERS.size():
		return false
	var pools: Dictionary = PLAYERS[pidx].get("pools", {})
	var pool: Dictionary = pools.get(key, {})
	if pool.get("current", 0) < amount:
		return false
	pool["current"] -= amount
	return true

# Devolve a Ação principal (Surto de Ação) gastando uma carga. Retorna false sem cargas.
func grant_extra_action(pidx: int) -> bool:
	if pidx < 0 or pidx >= PLAYERS.size():
		return false
	if PLAYERS[pidx].get("extra_action_charges", 0) <= 0:
		return false
	PLAYERS[pidx]["extra_action_charges"] -= 1
	has_attacked = false
	fury_extra_attack = false
	return true

## Consome 1 spell slot do nível pedido, ou do primeiro nível superior disponível
## (upcast). Não faz nada se spell_level <= 0 ou se não há slots.
func consume_spell_slot(spell_level: int) -> void:
	var pidx := get_active_player_index()
	if pidx < 0 or spell_level <= 0:
		return
	var slots: Array = PLAYERS[pidx].get("spell_slots", [0, 0, 0, 0, 0, 0])
	for i in range(spell_level - 1, slots.size()):
		if slots[i] > 0:
			slots[i] -= 1
			_log("Slot de %dº nível consumido." % (i + 1), "system")
			return

func get_active_tab_items() -> Array:
	var result: Array = []
	match active_tab:
		0:
			for a in tab_action:
				result.append(a)
			while result.size() < MAX_SLOTS - 1:
				result.append(null)
			result.append(TAB_END_TURN[0])
		1:
			for a in tab_habilidades:
				result.append(a)
			while result.size() < MAX_SLOTS:
				result.append(null)
		2:
			for item in TAB_ITEMS:
				result.append(item)
			while result.size() < MAX_SLOTS:
				result.append(null)
	return result

func move_tab(delta: int) -> void:
	active_tab = (active_tab + delta + 3) % 3
	cursor_position = 0

func move_cursor_tab(delta: int) -> void:
	var items := get_active_tab_items()
	var new_pos := cursor_position + delta

	# pula slots nulos na direção do movimento
	while new_pos >= 0 and new_pos < items.size() and items[new_pos] == null:
		new_pos += delta

	if new_pos < 0:
		active_tab = (active_tab - 1 + 3) % 3
		var new_items := get_active_tab_items()
		cursor_position = new_items.size() - 1
		while cursor_position > 0 and new_items[cursor_position] == null:
			cursor_position -= 1
	elif new_pos >= items.size():
		active_tab = (active_tab + 1) % 3
		cursor_position = 0
		var new_items := get_active_tab_items()
		while cursor_position < new_items.size() - 1 and new_items[cursor_position] == null:
			cursor_position += 1
	else:
		cursor_position = new_pos

func advance_turn() -> void:
	battle_stats["turns"] = battle_stats.get("turns", 0) + 1
	var next: int = (active_index + 1) % TURN_QUEUE.size()
	var guard: int = 0
	while dead_indices.has(next) and guard < TURN_QUEUE.size():
		next = (next + 1) % TURN_QUEUE.size()
		guard += 1
	var stun_guard: int = 0
	while stun_guard < TURN_QUEUE.size():
		var status: Dictionary = combatant_statuses[next]
		if status.get("poison", 0) > 0:
			status["poison"] -= 1
			var poison_dmg: int = DiceRoller.roll(1, 4)
			if TURN_QUEUE[next]["is_player"]:
				var pidx: int = _player_index_by_name(TURN_QUEUE[next]["name"])
				if pidx >= 0:
					PLAYERS[pidx]["hp"] = maxi(0, PLAYERS[pidx]["hp"] - poison_dmg)
					if PLAYERS[pidx]["hp"] <= 0:
						_on_death(next)
			else:
				var cname: String = TURN_QUEUE[next]["name"]
				enemy_hp[cname] = maxi(0, enemy_hp.get(cname, 0) - poison_dmg)
				if enemy_hp[cname] <= 0:
					_on_death(next)
			context_message = "%s took %d poison damage!" % [TURN_QUEUE[next]["name"], poison_dmg]
			_log("%s recebeu %d de dano de veneno" % [TURN_QUEUE[next]["name"], poison_dmg], "status")
			_register_damage_floater(next, poison_dmg, Color(0.55, 0.75, 0.20), "Veneno")
		# Burning: 1d4 de Fogo no início do turno; usa o mesmo canal de floater
		# (pending_surface_hits) que o dano de superfície.
		if status.get("burning", 0) > 0:
			status["burning"] -= 1
			var burn_dmg: int = DiceRoller.roll(1, 4)
			_register_damage_floater(next, burn_dmg, ActionData.damage_type_color(ActionData.DamageType.FIRE), "Fogo")
			_deal_damage_to_combatant(next, burn_dmg)
			context_message = "%s está em chamas! -%d HP" % [TURN_QUEUE[next]["name"], burn_dmg]
			_log("%s sofreu %d de dano de Fogo (Em Chamas)" % [TURN_QUEUE[next]["name"], burn_dmg], "dmg")
		if dead_indices.has(next):
			var skip: int = 0
			next = (next + 1) % TURN_QUEUE.size()
			while dead_indices.has(next) and skip < TURN_QUEUE.size():
				next = (next + 1) % TURN_QUEUE.size()
				skip += 1
			stun_guard += 1
			continue
		if status.get("stun", 0) > 0:
			status["stun"] -= 1
			context_message = TURN_QUEUE[next]["name"] + " is stunned and loses their turn!"
			_log("%s perdeu o turno (atordoado)" % TURN_QUEUE[next]["name"], "status")
			var skip: int = 0
			next = (next + 1) % TURN_QUEUE.size()
			while dead_indices.has(next) and skip < TURN_QUEUE.size():
				next = (next + 1) % TURN_QUEUE.size()
				skip += 1
			stun_guard += 1
			continue
		# Paralyzed: perde o turno por completo (mesmo padrão do Atordoado).
		if status.get("paralyzed", 0) > 0:
			status["paralyzed"] -= 1
			context_message = TURN_QUEUE[next]["name"] + " está paralisado e perde o turno!"
			_log("%s perdeu o turno (paralisado)" % TURN_QUEUE[next]["name"], "status")
			var skip_p: int = 0
			next = (next + 1) % TURN_QUEUE.size()
			while dead_indices.has(next) and skip_p < TURN_QUEUE.size():
				next = (next + 1) % TURN_QUEUE.size()
				skip_p += 1
			stun_guard += 1
			continue
		# Downed: rola 1 Death Save e passa o turno (não age).
		if status.get("downed", false):
			_process_death_save(next)
			context_message = TURN_QUEUE[next]["name"] + " está caído — Death Save rolado."
			var skip: int = 0
			next = (next + 1) % TURN_QUEUE.size()
			while dead_indices.has(next) and skip < TURN_QUEUE.size():
				next = (next + 1) % TURN_QUEUE.size()
				skip += 1
			stun_guard += 1
			continue
		break
	# Superfícies: dano no INÍCIO DO TURNO do combatente (1x por turno, correto),
	# mas o DECAIMENTO de duração ocorre 1x por ROUND. Quando voltamos a um
	# combatente que já agiu, um novo round começou → decai todas as superfícies.
	if _acted_this_round.has(next):
		_acted_this_round.clear()
		_tick_all_surfaces()
	_acted_this_round[next] = true
	_apply_surface_tick(next)
	# Decrementar buffs que duram N turnos do próprio combatente
	var next_status: Dictionary = combatant_statuses[next]
	if next_status.get("raging", 0) > 0:
		next_status["raging"] -= 1
	if next_status.get("acid", 0) > 0:
		next_status["acid"] -= 1
	if next_status.get("wet", 0) > 0:
		next_status["wet"] -= 1
	if next_status.get("poisoned", 0) > 0:
		next_status["poisoned"] -= 1
	# Decaimento das novas condições com duração em turnos do próprio combatente.
	# (burning decai no seu próprio tick; paralyzed no bloco de skip acima.)
	for _cond in ["blinded", "frightened", "restrained", "invisible", "grappled", "bonus_d4"]:
		if next_status.get(_cond, 0) > 0:
			next_status[_cond] -= 1
	if next_status.get("charmed", 0) > 0:
		next_status["charmed"] -= 1
		if next_status["charmed"] <= 0:
			next_status.erase("charmed_by")
	if next_status.get("marked", 0) > 0:
		next_status["marked"] -= 1
		if next_status["marked"] <= 0:
			next_status.erase("marked_by")
			next_status.erase("marked_n")
			next_status.erase("marked_d")
	# Oculto quebra se algum inimigo passou a ter linha de visão no início do turno.
	_break_hidden_if_seen(next)
	# Prone: levantar no início do turno custa metade do deslocamento máximo.
	_prone_stand_cost = 0
	if next_status.get("prone", 0) > 0:
		next_status.erase("prone")
		var p_idx: int = _player_index_by_name(TURN_QUEUE[next]["name"]) if TURN_QUEUE[next]["is_player"] else -1
		var max_spd: int = PLAYERS[p_idx].get("speed", 6) if p_idx >= 0 else 4
		_prone_stand_cost = max_spd / 2
		_log("%s se levantou (custo de metade do movimento)" % TURN_QUEUE[next]["name"], "system")
	active_index = next
	# Reação reseta no INÍCIO do próprio turno (regra D&D 5e). Disengage também.
	combatant_statuses[next]["reaction_used"] = false
	combatant_statuses[next]["disengage"] = false
	combatant_statuses[next]["disengage_exempt"] = []
	active_tab = 0
	cursor_position = 0
	_refill_move_points()
	if _prone_stand_cost > 0:
		move_points_remaining = maxi(0, move_points_remaining - _prone_stand_cost)
	has_attacked = false
	has_used_bonus_action = false
	fury_extra_attack = false
	_sneak_attack_used_this_turn = false
	_undo_attack_info.clear()
	move_cursor = combatant_positions[active_index]
	if is_player_turn():
		current_state = State.PLAYER_TURN
		enemy_action_text = ""
		_load_hero_actions(TURN_QUEUE[active_index]["name"])
	else:
		current_state = State.ENEMY_TURN
		_roll_enemy_action()

func enter_move_mode() -> void:
	if current_state != State.PLAYER_TURN or move_points_remaining <= 0:
		return
	move_cursor = combatant_positions[active_index]
	current_state = State.MOVE_MODE

# Reabastece os pontos de movimento do combatente ativo. Para herois usa o
# campo speed (em tiles, padrao DnD: 30 pes = 6 tiles); inimigos nao usam este
# rastreamento (movem via get_enemy_move_path), entao ficam em 0.
func _refill_move_points() -> void:
	var pidx := get_active_player_index()
	move_points_remaining = PLAYERS[pidx]["speed"] if pidx >= 0 else 0
	_last_move_cost = 0

# Reabastece o movimento no meio do turno (ex.: habilidade Passo do Vento).
func refill_move_points() -> void:
	_refill_move_points()

# Ha um movimento confirmado neste turno que ainda pode ser desfeito?
func can_undo_move() -> bool:
	return _last_move_cost > 0

# Dash: gasta a Action principal e soma a velocidade base aos pontos de
# movimento restantes (dobra o movimento do turno). Nao entra em modo de alvo.
func apply_dash() -> void:
	var pidx := get_active_player_index()
	if pidx < 0 or has_attacked:
		return
	move_points_remaining += int(PLAYERS[pidx]["speed"])
	has_attacked = true
	_log("%s usa Dash! Movimento dobrado." % PLAYERS[pidx]["name"], "status")

func move_cursor_grid(delta: Vector2i) -> void:
	var new_pos := move_cursor + delta
	new_pos.x = clampi(new_pos.x, 0, grid_cols - 1)
	new_pos.y = clampi(new_pos.y, 0, grid_rows - 1)
	if not get_reachable_tiles().has(new_pos):
		return
	move_cursor = new_pos

func confirm_move() -> void:
	_undo_move_pos = combatant_positions[active_index]
	# Custo exato ate o destino, vindo do mapa de alcance (consistente com a
	# checagem de tiles alcancaveis, inclusive custo de lama). Guardado em
	# _last_move_cost para permitir desfazer (cancel_confirmed_move).
	_last_move_cost = int(get_reachable_tiles().get(move_cursor, 0))
	combatant_positions[active_index] = move_cursor
	move_points_remaining = maxi(0, move_points_remaining - _last_move_cost)
	current_state = State.PLAYER_TURN

func activate_trap_after_move(combatant_idx: int, pos: Vector2i) -> void:
	_check_trap(combatant_idx, pos)

# Aplica o efeito de entrada da superfície ao combatente que pisa no tile.
# Chamado pela BattleScene após o movimento (junto de activate_trap_after_move).
func apply_surface_on_enter(combatant_idx: int, pos: Vector2i) -> void:
	if pos.x < 0 or pos.x >= grid_cols or pos.y < 0 or pos.y >= grid_rows:
		return
	var s_type: int = tile_surfaces.get(pos, {}).get("type", SurfaceType.Type.NONE)
	var cname: String = TURN_QUEUE[combatant_idx]["name"]
	match s_type:
		SurfaceType.Type.FIRE:
			var fdmg: int = DiceRoller.roll(1, 4)
			_register_damage_floater(combatant_idx, fdmg, ActionData.damage_type_color(ActionData.DamageType.FIRE), "Fogo")
			_deal_damage_to_combatant(combatant_idx, fdmg)
			_ignite(combatant_idx)  # Em Chamas: 1d4/turno por 2 turnos
			_log("%s entrou no fogo! -%d HP (Em Chamas)" % [cname, fdmg], "dmg")
		SurfaceType.Type.ICE:
			_apply_ice_prone_save(combatant_idx)
		SurfaceType.Type.WATER:
			combatant_statuses[combatant_idx]["wet"] = 3
			# Água apaga o fogo (BG3): cancela Em Chamas.
			if combatant_statuses[combatant_idx].get("burning", 0) > 0:
				combatant_statuses[combatant_idx].erase("burning")
				_log("%s foi apagado pela água (não está mais Em Chamas)" % cname, "status")
			_log("%s ficou molhado (vulnerável a Raio e Frio)" % cname, "status")
		SurfaceType.Type.ELECTRIFIED_WATER:
			var edmg: int = DiceRoller.roll(1, 4)
			_register_damage_floater(combatant_idx, edmg, ActionData.damage_type_color(ActionData.DamageType.THUNDER), "Raio")
			_deal_damage_to_combatant(combatant_idx, edmg)
			_log("%s foi eletrocutado! -%d HP" % [cname, edmg], "dmg")
		SurfaceType.Type.ACID:
			combatant_statuses[combatant_idx]["acid"] = 2
			_log("%s foi banhado em ácido! -2 CA por 2 turnos" % cname, "status")
		SurfaceType.Type.POISON:
			combatant_statuses[combatant_idx]["poisoned"] = 3
			_log("%s foi envenenado (desvantagem em ataques)" % cname, "status")
		SurfaceType.Type.CLOUD_OF_DAGGERS:
			var cdmg: int = DiceRoller.roll(4, 4)
			_register_damage_floater(combatant_idx, cdmg, ActionData.damage_type_color(ActionData.DamageType.PHYSICAL), "Cortante")
			_deal_damage_to_combatant(combatant_idx, cdmg)
			_log("%s entrou na Nuvem de Adagas! -%d HP (Slashing)" % [cname, cdmg], "dmg")

func cancel_confirmed_move() -> bool:
	if _last_move_cost <= 0:
		return false
	combatant_positions[active_index] = _undo_move_pos
	move_points_remaining += _last_move_cost
	_last_move_cost = 0
	context_message = "Movimento cancelado."
	return true

func cancel_move() -> void:
	current_state = State.PLAYER_TURN

func _check_trap(combatant_idx: int, pos: Vector2i) -> void:
	if pos.x < 0 or pos.x >= grid_cols or pos.y < 0 or pos.y >= grid_rows:
		return
	var tile: TerrainTile = tile_data_map[pos.x][pos.y]
	if tile.effect == TerrainTile.EffectType.TRAP_INACTIVE:
		tile.effect = TerrainTile.EffectType.TRAP_ACTIVE
		var cname: String = TURN_QUEUE[combatant_idx]["name"]
		var trap_dmg: int = DiceRoller.roll(2, 4)
		if TURN_QUEUE[combatant_idx]["is_player"]:
			var pidx := get_active_player_index()
			if pidx >= 0:
				PLAYERS[pidx]["hp"] = maxi(0, PLAYERS[pidx]["hp"] - trap_dmg)
				if PLAYERS[pidx]["hp"] <= 0:
					_on_death(combatant_idx)
		else:
			var new_hp: int = maxi(0, enemy_hp.get(cname, 30) - trap_dmg)
			enemy_hp[cname] = new_hp
			if new_hp <= 0:
				_on_death(combatant_idx)
		context_message = "%s triggered a trap! -%d HP" % [cname, trap_dmg]
		_log("%s ativou uma armadilha! -%d HP e envenenado" % [cname, trap_dmg], "status")
		_register_damage_floater(combatant_idx, trap_dmg, ActionData.damage_type_color(ActionData.DamageType.PHYSICAL), "Armadilha")
		combatant_statuses[combatant_idx]["poison"] = 3
		# A armadilha deixa uma nuvem de Veneno persistente no tile.
		_add_surface(pos, SurfaceType.Type.POISON)

# Saving throw de DEX (DC 12) ao entrar em superfície de Gelo. Falha → Prone.
func _apply_ice_prone_save(combatant_idx: int) -> void:
	var dc := 12
	var dex_save_action := ActionData.new()
	dex_save_action.save_attribute = ActionData.DamageAttribute.DEX
	var save_result: Dictionary = _resolve_saving_throw(combatant_idx, dc, dex_save_action)
	if not save_result["saved"]:
		combatant_statuses[combatant_idx]["prone"] = 1
		_break_concentration(combatant_idx)  # Prone quebra concentração (BG3)
		var cname: String = TURN_QUEUE[combatant_idx]["name"]
		_log("%s escorregou no gelo e caiu (Prone)!" % cname, "status")

func get_path_to(destination: Vector2i) -> Array[Vector2i]:
	var origin: Vector2i = combatant_positions[active_index]
	if origin == destination:
		return []
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var came_from: Dictionary = {}
	came_from[origin] = origin
	var frontier: Array[Vector2i] = [origin]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if cur == destination:
			break
		for d in dirs:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.x >= grid_cols or nxt.y < 0 or nxt.y >= grid_rows:
				continue
			if came_from.has(nxt):
				continue
			var t: TerrainTile = tile_data_map[nxt.x][nxt.y]
			if t.is_void():
				continue
			if t.object == TerrainTile.ObjectType.OBSTACLE:
				continue
			var has_combatant := false
			for i in range(combatant_positions.size()):
				if i == active_index:
					continue
				if combatant_positions[i] == nxt:
					has_combatant = true
					break
			if has_combatant:
				continue
			came_from[nxt] = cur
			frontier.append(nxt)
	if not came_from.has(destination):
		return [destination]
	var path: Array[Vector2i] = []
	var step: Vector2i = destination
	while step != origin:
		path.push_front(step)
		step = came_from[step]
	return path

func get_reachable_tiles() -> Dictionary:
	var origin: Vector2i = combatant_positions[active_index]
	# Condições que impedem totalmente o movimento (BG3/D&D).
	var ms: Dictionary = combatant_statuses[active_index]
	if ms.get("paralyzed", 0) > 0 or ms.get("restrained", 0) > 0 \
			or ms.get("grappled", 0) > 0:
		return {}
	# Limite = pontos de movimento RESTANTES no turno (movimento dividido).
	var spd: int = move_points_remaining
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var cost_map: Dictionary = {}
	cost_map[origin] = 0
	var frontier: Array[Vector2i] = [origin]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		var cur_cost: int = cost_map[cur]
		for d in dirs:
			var nxt: Vector2i = cur + d
			if nxt.x < 0 or nxt.x >= grid_cols or nxt.y < 0 or nxt.y >= grid_rows:
				continue
			var tile: TerrainTile = tile_data_map[nxt.x][nxt.y]
			if tile.is_void():
				continue
			if tile.object == TerrainTile.ObjectType.OBSTACLE:
				continue
			var has_combatant := false
			for i in range(combatant_positions.size()):
				if i == active_index:  
					continue
				if dead_indices.has(i):
					continue
				if combatant_positions[i] == nxt:
					has_combatant = true
					break
			if has_combatant:
				continue  
			var new_cost: int = cur_cost + _tile_cost(nxt)
			if new_cost > spd:
				continue
			if cost_map.has(nxt) and cost_map[nxt] <= new_cost:
				continue
			cost_map[nxt] = new_cost
			frontier.append(nxt)
	var result: Dictionary = {}
	for pos in cost_map.keys():
		var blocked := false
		for i in range(combatant_positions.size()):
			if i == active_index or dead_indices.has(i):
				continue
			if combatant_positions[i] == pos:
				blocked = true
				break
		if not blocked:
			# Valor = custo acumulado ate a tile (usado por confirm_move para
			# deduzir o exato dos pontos restantes). Callers que so testam
			# alcance usam .has()/.keys(), entao o valor nao os afeta.
			result[pos] = cost_map[pos]
	# Amedrontado (BG3/D&D): pode mover, mas não para tiles que o aproximem da
	# fonte do medo. Sem fonte registrada, apenas não bloqueia.
	if ms.get("frightened", 0) > 0:
		var src_idx: int = ms.get("frightened_by", -1)
		if src_idx >= 0 and src_idx < combatant_positions.size() and not dead_indices.has(src_idx):
			var src: Vector2i = combatant_positions[src_idx]
			var origin_dist: int = abs(origin.x - src.x) + abs(origin.y - src.y)
			var filtered: Dictionary = {}
			for pos in result.keys():
				var pos_dist: int = abs(pos.x - src.x) + abs(pos.y - src.y)
				if pos_dist >= origin_dist:
					filtered[pos] = result[pos]
			result = filtered
	return result


var dead_indices: Dictionary = {}
var battle_result: String = ""
var last_attack_info: Dictionary = {}
var combatant_statuses: Array = []
var tile_surfaces: Dictionary = {}   # Vector2i -> {type: int, turns: int}
var concentration_by_caster: Dictionary = {}  # queue_idx (int) -> { "label": String, "action": ActionData }
var pending_surface_hits: Array = []  # {target_idx, damage, label} — read by BattleScene for floaters
var _acted_this_round: Dictionary = {}  # queue_idx -> true; detecta limite de round p/ decair superfícies 1x/round
var _prone_stand_cost: int = 0
var combat_log: Array = []
var pending_deaths: Array[int] = []

func _get_active_behavior() -> Dictionary:
	var enemy := get_active_combatant()
	var enemy_type: String = enemy.get("type", "Goblin")
	var edata := ALL_ENEMIES.get(enemy_type, null) as EnemyData
	if edata == null or active_enemy_action_idx >= edata.action_behaviors.size():
		return {"range": 1, "damage_mult": 1.0, "aoe_radius": 0,
				"is_self_buff": false, "is_flee": false,
				"applies_status": "", "status_chance": 0.0,
				"buff_type": "", "buff_value": 0, "buff_turns": 0}
	return edata.action_behaviors[active_enemy_action_idx]

func _enemy_action_range() -> int:
	return _get_active_behavior().get("range", 1)

func _enemy_action_is_self() -> bool:
	var b := _get_active_behavior()
	return b.get("is_self_buff", false)

func get_enemy_move_path() -> Array[Vector2i]:
	var enemy := get_active_combatant()
	assert(not enemy.get("is_player", false), "get_enemy_move_path called on a player combatant")
	var enemy_type: String = enemy.get("type", "")
	var _edata := ALL_ENEMIES.get(enemy_type, null) as EnemyData
	var spd: int = _edata.speed if _edata != null else 5
	var origin: Vector2i = combatant_positions[active_index]

	# Condições que impedem o movimento da IA (Paralyzed já pula o turno inteiro).
	var es: Dictionary = combatant_statuses[active_index]
	if es.get("restrained", 0) > 0 or es.get("grappled", 0) > 0 or es.get("frightened", 0) > 0:
		return []

	if _enemy_action_is_self():
		return []

	var target := origin
	var best_dist := 99999
	var es_charm: Dictionary = combatant_statuses[active_index]
	var charmer: int = es_charm.get("charmed_by", -1) if es_charm.get("charmed", 0) > 0 else -1
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"] and not dead_indices.has(i):
			if i == charmer:
				continue  # Charmed: não persegue quem o encantou
			var d := absi(combatant_positions[i].x - origin.x) + absi(combatant_positions[i].y - origin.y)
			if d < best_dist:
				best_dist = d
				target = combatant_positions[i]

	if best_dist == 99999:
		return []

	if "Fleeing" in enemy_action_text:
		return _trim_path_end(_enemy_path_flee(origin, target, spd))

	var attack_range := _enemy_action_range()

	if best_dist <= attack_range:
		if randf() < 0.65:
			return []
		return _trim_path_end(_enemy_path_reposition(origin, target, attack_range, spd))

	return _trim_path_end(_enemy_path_approach(origin, target, attack_range, spd))

func _trim_path_end(path: Array[Vector2i]) -> Array[Vector2i]:
	while not path.is_empty():
		var last: Vector2i = path[-1]
		var blocked := false
		for i in range(combatant_positions.size()):
			if i != active_index and combatant_positions[i] == last:
				blocked = true
				break
		if blocked:
			path.pop_back()
		else:
			break
	return path

func _enemy_path_approach(origin: Vector2i, target: Vector2i, stop_range: int, spd: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur := origin
	for _s in range(spd):
		var dx := target.x - cur.x
		var dy := target.y - cur.y
		if absi(dx) + absi(dy) <= stop_range:
			break
		var primary := Vector2i(signi(dx), 0) if absi(dx) >= absi(dy) else Vector2i(0, signi(dy))
		var next := Vector2i(
			clampi(cur.x + primary.x, 0, grid_cols - 1),
			clampi(cur.y + primary.y, 0, grid_rows - 1)
		)
		if _is_occupied_by_other(next):
			var secondary := Vector2i(0, signi(dy)) if absi(dx) >= absi(dy) else Vector2i(signi(dx), 0)
			if secondary == Vector2i.ZERO:
				break
			next = Vector2i(
				clampi(cur.x + secondary.x, 0, grid_cols - 1),
				clampi(cur.y + secondary.y, 0, grid_rows - 1)
			)
			if _is_occupied_by_other(next):
				break
		cur = next
		path.append(cur)
	return path

func _enemy_path_flee(origin: Vector2i, target: Vector2i, spd: int) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur := origin
	for _s in range(spd):
		var dx := cur.x - target.x
		var dy := cur.y - target.y
		if dx == 0 and dy == 0:
			break
		var primary := Vector2i(signi(dx), 0) if absi(dx) >= absi(dy) else Vector2i(0, signi(dy))
		var next := Vector2i(
			clampi(cur.x + primary.x, 0, grid_cols - 1),
			clampi(cur.y + primary.y, 0, grid_rows - 1)
		)
		if _is_occupied_by_other(next) or next == cur:
			var secondary := Vector2i(0, signi(dy)) if absi(dx) >= absi(dy) else Vector2i(signi(dx), 0)
			if secondary == Vector2i.ZERO:
				break
			next = Vector2i(
				clampi(cur.x + secondary.x, 0, grid_cols - 1),
				clampi(cur.y + secondary.y, 0, grid_rows - 1)
			)
			if _is_occupied_by_other(next) or next == cur:
				break
		cur = next
		path.append(cur)
	return path

func _enemy_path_reposition(origin: Vector2i, target: Vector2i, attack_range: int, spd: int) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for dx in range(-attack_range, attack_range + 1):
		for dy in range(-attack_range, attack_range + 1):
			if absi(dx) + absi(dy) != attack_range:
				continue
			var pos: Vector2i = target + Vector2i(dx, dy)
			if pos.x < 0 or pos.x >= grid_cols or pos.y < 0 or pos.y >= grid_rows:
				continue
			if pos == origin:
				continue
			var tile: TerrainTile = tile_data_map[pos.x][pos.y]
			if tile.is_void() or tile.object == TerrainTile.ObjectType.OBSTACLE:
				continue
			if _is_occupied_by_other(pos):
				continue
			if absi(pos.x - origin.x) + absi(pos.y - origin.y) <= spd:
				candidates.append(pos)
	if candidates.is_empty():
		return []
	var cover_candidates: Array[Vector2i] = []
	for c in candidates:
		var tile: TerrainTile = tile_data_map[c.x][c.y]
		if tile.object == TerrainTile.ObjectType.COVER:
			cover_candidates.append(c)
	if not cover_candidates.is_empty():
		cover_candidates.shuffle()
		return _enemy_path_approach(origin, cover_candidates[0], 0, spd)
	candidates.shuffle()
	return _enemy_path_approach(origin, candidates[0], 0, spd)

func _get_enemy_projectile_color() -> Color:
	if "Shadow Bolt" in enemy_action_text:
		return Color(0.65, 0.15, 0.95)
	if "Frost Nova" in enemy_action_text:
		return Color(0.40, 0.80, 1.00)
	if "arrow" in enemy_action_text:
		return Color(0.90, 0.85, 0.65)
	if "dagger" in enemy_action_text:
		return Color(0.75, 0.80, 0.85)
	return Color.WHITE

func apply_enemy_attack() -> Dictionary:
	var b := _get_active_behavior()

	if b.get("is_flee", false):
		return {"target": Vector2i(-1, -1)}
	if b.get("is_self_buff", false):
		_apply_enemy_self_buff(b)
		return {"target": Vector2i(-1, -1)}

	if b.get("aoe_radius", 0) > 0:
		return _apply_enemy_aoe_attack(b)

	var attack_range: int = b.get("range", 1)
	var my_status: Dictionary = combatant_statuses[active_index]
	if attack_range > 1 and _tile_at(active_index) == MapGenerator.TileType.ELEVATED:
		attack_range += 1

	var origin: Vector2i = combatant_positions[active_index]
	var target_idx := -1
	var best_hp    := 99999
	var pidx: int
	var atk_charmer: int = my_status.get("charmed_by", -1) if my_status.get("charmed", 0) > 0 else -1
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"] and not dead_indices.has(i):
			if i == atk_charmer:
				continue  # Charmed: não pode atacar quem o encantou
			var d: int = king_dist(combatant_positions[i], origin)
			if d <= attack_range:
				if attack_range == 1 or _has_los(origin, combatant_positions[i]):
					pidx = _player_index_by_name(TURN_QUEUE[i]["name"])
					var phpi: int = PLAYERS[pidx]["hp"] if pidx >= 0 else 99999
					if phpi < best_hp:
						best_hp    = phpi
						target_idx = i
	if target_idx == -1:
		return {"target": Vector2i(-1, -1)}
	# Mods de Vantagem/Desvantagem da rolagem do inimigo.
	var _emods: Dictionary = _get_attack_roll_mods(active_index, target_idx, attack_range)

	# ── Resolve dados de combate do inimigo ──────────────────────────────────
	var enemy_type_atk: String = get_active_combatant().get("type", "")
	var edata_atk := ALL_ENEMIES.get(enemy_type_atk, null) as EnemyData
	var atk_bonus: int      = edata_atk.attack_bonus      if edata_atk != null else 2
	var proficiency: int    = edata_atk.proficiency       if edata_atk != null else 2
	var crit_threshold: int = edata_atk.crit_threshold    if edata_atk != null else 20
	var dice_count: int     = edata_atk.damage_dice_count if edata_atk != null else 1
	var dice_sides: int     = edata_atk.damage_dice_sides if edata_atk != null else 6
	var damage_mult: float  = b.get("damage_mult", 1.0)
	var raging_bonus: int   = 2 if my_status.get("raging", 0) > 0 else 0  # D&D: +2 (era +3)

	var attack_attr := edata_atk.attack_damage_attribute if edata_atk != null else ActionData.DamageAttribute.STR
	var attr_val: int = 10
	match attack_attr:
		ActionData.DamageAttribute.DEX: attr_val = edata_atk.dexterity    if edata_atk != null else 10
		ActionData.DamageAttribute.INT: attr_val = edata_atk.intelligence if edata_atk != null else 10
		ActionData.DamageAttribute.WIS: attr_val = edata_atk.wisdom       if edata_atk != null else 10
		_:                              attr_val = edata_atk.strength      if edata_atk != null else 10
	var attr_mod: int = _raw_mod(attr_val)

	var target_name: String = TURN_QUEUE[target_idx]["name"]
	pidx = _player_index_by_name(target_name)
	var target_ac: int = PLAYERS[pidx].get("ac", 10) if pidx >= 0 else 10
	# Condição Acid (superfície de Ácido): -2 CA.
	if combatant_statuses[target_idx].get("acid", 0) > 0:
		target_ac -= 2
	var attacker_name: String = get_active_combatant()["name"]

	# ── ROLAGEM DE ATAQUE ────────────────────────────────────────────────────
	var _eroll: Dictionary = DiceRoller.roll_d20_adv_dis(_emods["adv"], _emods["dis"])
	var d20: int = _eroll["result"]
	var e_roll_mode: String = _eroll["mode"]
	var e_other_roll: int   = _eroll["other"]
	var is_crit: bool = false
	if d20 == 1:
		last_attack_info = {"amount": 0, "is_heal": false, "target_idx": target_idx,
			"is_crit": false, "hit": false, "attack_roll": d20, "attack_total": d20, "target_ac": target_ac,
			"roll_mode": e_roll_mode, "other_roll": e_other_roll,
			"is_saving_throw": false, "save_dc": 0, "save_roll": 0, "save_total": 0}
		context_message = "Erro Crítico! %s errou feio." % attacker_name
		_log("Erro Crítico! %s errou feio." % attacker_name, "miss")
		return {"target": combatant_positions[target_idx], "is_ranged": attack_range > 1, "color": _get_enemy_projectile_color()}

	var attack_total: int = d20 + proficiency + attr_mod + atk_bonus + _emods.get("flat", 0)
	if d20 >= crit_threshold:
		is_crit = true
	elif attack_total < target_ac:
		last_attack_info = {"amount": 0, "is_heal": false, "target_idx": target_idx,
			"is_crit": false, "hit": false, "attack_roll": d20, "attack_total": attack_total, "target_ac": target_ac,
			"roll_mode": e_roll_mode, "other_roll": e_other_roll,
			"is_saving_throw": false, "save_dc": 0, "save_roll": 0, "save_total": 0}
		context_message = "%s errou! (%d vs AC %d)" % [attacker_name, attack_total, target_ac]
		_log("%s rolou %d+%d+%d=%d vs AC %d — ERROU" % [attacker_name, d20, proficiency, attr_mod, attack_total, target_ac], "miss")
		return {"target": combatant_positions[target_idx], "is_ranged": attack_range > 1, "color": _get_enemy_projectile_color()}

	# Auto-crit (BG3/D&D): ataque melee que acerta um alvo Paralisado é sempre crítico.
	if attack_range <= 1 and combatant_statuses[target_idx].get("paralyzed", 0) > 0:
		is_crit = true

	# ── DANO ─────────────────────────────────────────────────────────────────
	var roll_count: int = dice_count * 2 if is_crit else dice_count
	var damage: int = maxi(1, int(DiceRoller.roll(roll_count, dice_sides) * damage_mult) + attr_mod + atk_bonus + raging_bonus)

	# Redução de dano e bônus de defesa (lógica preservada)
	if pidx >= 0:
		var tdata := ALL_HERO_DATA.get(target_name, null) as HeroData
		if tdata != null and tdata.damage_reduction > 0:
			var reduction: int = 2 if combatant_statuses[target_idx].get("fury", 0) > 0 else tdata.damage_reduction
			damage = maxi(1, damage - reduction)
		var def_bonus: int = PLAYERS[pidx].get("bonus_def", 0)
		if def_bonus > 0:
			damage = maxi(1, damage - def_bonus)
	# Resistência/Vulnerabilidade/Imunidade + Wet do alvo (último passo).
	damage = _apply_damage_type_mods(target_idx, ActionData.DamageType.PHYSICAL, damage)
	battle_stats["enemy_damage_dealt"] = battle_stats.get("enemy_damage_dealt", 0) + damage
	if pidx >= 0:
		PLAYERS[pidx]["hp"] = maxi(0, PLAYERS[pidx]["hp"] - damage)
		_check_concentration_after_damage(target_idx, damage)
		if PLAYERS[pidx]["hp"] <= 0:
			if is_downed(target_idx):
				_add_death_save_failure(target_idx, 2 if is_crit else 1)
			else:
				_on_death(target_idx)
	last_attack_info = {"amount": damage, "is_heal": false, "target_idx": target_idx,
		"is_crit": is_crit, "hit": true, "attack_roll": d20, "attack_total": attack_total, "target_ac": target_ac,
		"roll_mode": e_roll_mode, "other_roll": e_other_roll,
		"is_saving_throw": false, "save_dc": 0, "save_roll": 0, "save_total": 0}
	if is_crit:
		context_message = "CRÍTICO! %s acertou %s por %d de dano!" % [attacker_name, target_name, damage]
		_log("CRÍTICO! %s acertou %s por %d de dano" % [attacker_name, target_name, damage], "crit")
	else:
		context_message = "%s hit %s for %d damage!" % [attacker_name, target_name, damage]
		_log("%s acertou %s por %d de dano" % [attacker_name, target_name, damage], "dmg")

	if b.get("applies_status", "") != "":
		_maybe_apply_stun(target_idx, b.get("status_chance", 0.0), attacker_name)

	return {
		"target": combatant_positions[target_idx],
		"is_ranged": attack_range > 1,
		"color": _get_enemy_projectile_color(),
	}

# Aplica stun probabilístico vindo de ataques de inimigos (carga/investida). É o
# stun GENÉRICO de inimigo — distinto do Golpe Atordoante do Monge (apply_stunning_strike),
# que exige saving throw. Mantido separado para que as duas fontes não se confundam.
func _maybe_apply_stun(target_idx: int, chance: float, source_name: String) -> void:
	if randf() < chance:
		combatant_statuses[target_idx]["stun"] = 1
		var tname: String = TURN_QUEUE[target_idx]["name"]
		context_message += " " + tname + " is stunned!"
		_log("%s foi atordoado por %s!" % [tname, source_name], "status")

func apply_enemy_move(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	combatant_positions[active_index] = path[-1]

# ══════════════════════════════════════════════════════════════════════════════
# REACTIONS (BG3): 1 reação por round por combatente, reseta no início do turno.
# A lógica pura vive aqui; BattleScene faz o sequenciamento/pausa dos popups.
# ══════════════════════════════════════════════════════════════════════════════

func consume_reaction(combatant_idx: int) -> void:
	combatant_statuses[combatant_idx]["reaction_used"] = true
	_log("%s usou sua reação" % TURN_QUEUE[combatant_idx]["name"], "status")

func has_reaction_available(combatant_idx: int) -> bool:
	if dead_indices.has(combatant_idx):
		return false
	return not combatant_statuses[combatant_idx].get("reaction_used", false)

func set_reaction_setting(combatant_idx: int, key: String, value: bool) -> void:
	if not combatant_statuses[combatant_idx].has("reaction_settings"):
		combatant_statuses[combatant_idx]["reaction_settings"] = {}
	combatant_statuses[combatant_idx]["reaction_settings"][key] = value

func get_reaction_setting(combatant_idx: int, key: String, default_val: bool) -> bool:
	return combatant_statuses[combatant_idx].get("reaction_settings", {}).get(key, default_val)

# Desengajar (ação principal): impede OA dos inimigos que JÁ estão adjacentes neste
# momento (regra BG3). Inimigos dos quais o combatente se aproximar DEPOIS ainda
# podem fazer OA. Guarda o snapshot dos adjacentes atuais em disengage_exempt.
func apply_disengage(combatant_idx: int, consume_action: bool = true) -> void:
	combatant_statuses[combatant_idx]["disengage"] = true
	var my_pos: Vector2i = combatant_positions[combatant_idx]
	var mover_is_player: bool = TURN_QUEUE[combatant_idx]["is_player"]
	var exempt: Array[int] = []
	for i in range(TURN_QUEUE.size()):
		if i == combatant_idx or dead_indices.has(i):
			continue
		if TURN_QUEUE[i]["is_player"] == mover_is_player:
			continue
		var d: int = absi(my_pos.x - combatant_positions[i].x) + absi(my_pos.y - combatant_positions[i].y)
		if d <= 1:
			exempt.append(i)
	combatant_statuses[combatant_idx]["disengage_exempt"] = exempt
	# O Pulo reaproveita a evasão de OA SEM gastar a Ação principal (consume_action=false).
	if consume_action:
		has_attacked = true
		_log("%s se desengajou" % TURN_QUEUE[combatant_idx]["name"], "status")

# Retorna índices de combatentes que PODEM fazer OA contra mover_idx ao sair do
# alcance corpo-a-corpo. old_pos/new_pos = posição antes/depois do movimento.
func check_opportunity_attacks(mover_idx: int, old_pos: Vector2i, new_pos: Vector2i) -> Array[int]:
	var result: Array[int] = []
	var exempt: Array = combatant_statuses[mover_idx].get("disengage_exempt", [])
	var mover_is_player: bool = TURN_QUEUE[mover_idx]["is_player"]
	for i in range(TURN_QUEUE.size()):
		if i == mover_idx or dead_indices.has(i):
			continue
		if TURN_QUEUE[i]["is_player"] == mover_is_player:
			continue  # mesmo lado
		if exempt.has(i):
			continue  # já estava adjacente quando o mover usou Disengage
		if not has_reaction_available(i):
			continue
		if not get_reaction_setting(i, "OA_enabled", true):
			continue
		# Condições que impedem fazer Ataque de Oportunidade (BG3/D&D).
		var rst: Dictionary = combatant_statuses[i]
		if rst.get("blinded", 0) > 0 or rst.get("paralyzed", 0) > 0 or rst.get("restrained", 0) > 0:
			continue
		# Charmed não pode reagir contra quem o encantou.
		if rst.get("charmed", 0) > 0 and rst.get("charmed_by", -1) == mover_idx:
			continue
		var rpos: Vector2i = combatant_positions[i]
		var old_dist: int = absi(old_pos.x - rpos.x) + absi(old_pos.y - rpos.y)
		var new_dist: int = absi(new_pos.x - rpos.x) + absi(new_pos.y - rpos.y)
		if old_dist <= 1 and new_dist > 1:
			result.append(i)
	return result

# Executa um ataque corpo-a-corpo GRATUITO de attacker_idx contra target_idx.
# Custa apenas a reação (não a ação principal). Popula last_attack_info.
func apply_opportunity_attack(attacker_idx: int, target_idx: int) -> void:
	var atk_action := ActionData.new()
	atk_action.attack_range = 1
	if TURN_QUEUE[attacker_idx]["is_player"]:
		# Puxa dados/atributo da arma equipada do jogador.
		atk_action.is_weapon_attack = true
	else:
		var etype: String = TURN_QUEUE[attacker_idx].get("type", "")
		var edata := ALL_ENEMIES.get(etype, null) as EnemyData
		atk_action.is_weapon_attack = false
		atk_action.damage_dice_count = edata.damage_dice_count if edata != null else 1
		atk_action.damage_dice_sides = edata.damage_dice_sides if edata != null else 6
		atk_action.damage_attribute = ActionData.DamageAttribute.NONE
	# Salva e troca o contexto de ataque para reaproveitar _apply_attack.
	var prev_action: ActionData = _current_action
	var prev_active: int        = active_index
	var prev_range: int         = current_attack_range
	var prev_aoe: int           = current_aoe_radius
	var prev_allies: bool       = _attack_targets_allies
	active_index = attacker_idx
	_current_action = atk_action
	current_attack_range = 1
	current_aoe_radius = 0
	_attack_targets_allies = false
	_apply_attack(target_idx)
	active_index = prev_active
	_current_action = prev_action
	current_attack_range = prev_range
	current_aoe_radius = prev_aoe
	_attack_targets_allies = prev_allies
	consume_reaction(attacker_idx)
	_log("%s fez Ataque de Oportunidade contra %s!" % [
		TURN_QUEUE[attacker_idx]["name"], TURN_QUEUE[target_idx]["name"]], "dmg")

# Uncanny Dodge (Ladrão): reduz à metade o dano do ataque que acabou de acertar.
# Chamada APÓS _apply_attack/apply_enemy_attack popular last_attack_info.
func apply_uncanny_dodge(rogue_idx: int) -> void:
	if not last_attack_info.get("hit", false):
		return
	if last_attack_info.get("target_idx", -1) != rogue_idx:
		return
	var original: int = last_attack_info.get("amount", 0)
	var reduced: int  = original / 2
	var delta: int    = original - reduced
	last_attack_info["amount"] = reduced
	last_attack_info["uncanny_dodge_applied"] = true
	var pidx: int = _player_index_by_name(TURN_QUEUE[rogue_idx]["name"])
	if pidx >= 0:
		PLAYERS[pidx]["hp"] = mini(PLAYERS[pidx]["max_hp"], PLAYERS[pidx]["hp"] + delta)
	consume_reaction(rogue_idx)
	_log("%s usou Esquiva Sobrenatural! Dano %d → %d" % [
		TURN_QUEUE[rogue_idx]["name"], original, reduced], "status")

# Deflect Missiles (Monge): reduz dano de ataque à distância em 1d10+DEX+nível.
# Retorna o dano final após redução (0 = pode devolver o projétil). -1 se inválido.
func apply_deflect_missiles(monk_idx: int) -> int:
	if not last_attack_info.get("hit", false):
		return -1
	if last_attack_info.get("target_idx", -1) != monk_idx:
		return -1
	var pidx: int = _player_index_by_name(TURN_QUEUE[monk_idx]["name"])
	if pidx < 0:
		return -1
	var dex_mod: int   = _raw_mod(PLAYERS[pidx].get("dexterity", 10))
	var level: int     = PLAYERS[pidx].get("level", 1)
	var reduction: int = DiceRoller.roll(1, 10) + dex_mod + level
	var original: int  = last_attack_info.get("amount", 0)
	var final_dmg: int = maxi(0, original - reduction)
	var delta: int     = original - final_dmg
	last_attack_info["amount"] = final_dmg
	last_attack_info["deflect_applied"] = true
	PLAYERS[pidx]["hp"] = mini(PLAYERS[pidx]["max_hp"], PLAYERS[pidx]["hp"] + delta)
	consume_reaction(monk_idx)
	_log("%s desviou o projétil! -%d (dano final %d)" % [
		TURN_QUEUE[monk_idx]["name"], reduction, final_dmg], "status")
	return final_dmg

# Divine Smite via Reaction (Paladino): consome 1 spell slot, adiciona dano
# radiante ((slot+1)d8, dobrado em crítico) ao acerto que acabou de ocorrer.
func apply_divine_smite_reaction(paladin_idx: int, slot_level: int, is_crit: bool) -> int:
	var pidx: int = _player_index_by_name(TURN_QUEUE[paladin_idx]["name"])
	if pidx < 0:
		return 0
	# Consome um slot do nível pedido (ou upcast para o primeiro disponível acima),
	# direto pelo índice do Paladino — não depende de active_index.
	var slots: Array = PLAYERS[pidx].get("spell_slots", [0, 0, 0, 0, 0, 0])
	for i in range(slot_level - 1, slots.size()):
		if slots[i] > 0:
			slots[i] -= 1
			break
	var dice_count: int = (slot_level + 1) * (2 if is_crit else 1)
	var smite_dmg: int  = DiceRoller.roll(dice_count, 8)
	last_attack_info["amount"] = last_attack_info.get("amount", 0) + smite_dmg
	last_attack_info["smite_amount"] = last_attack_info.get("smite_amount", 0) + smite_dmg
	# Aplica o dano radiante extra ao alvo (last_attack_info já foi consumido p/ HP).
	var target_idx: int = last_attack_info.get("target_idx", -1)
	if target_idx >= 0:
		if TURN_QUEUE[target_idx]["is_player"]:
			var tpidx: int = _player_index_by_name(TURN_QUEUE[target_idx]["name"])
			if tpidx >= 0:
				PLAYERS[tpidx]["hp"] = maxi(0, PLAYERS[tpidx]["hp"] - smite_dmg)
				if PLAYERS[tpidx]["hp"] <= 0:
					_on_death(target_idx)
		else:
			var tname: String = TURN_QUEUE[target_idx]["name"]
			enemy_hp[tname] = maxi(0, enemy_hp.get(tname, 0) - smite_dmg)
			if enemy_hp[tname] <= 0:
				_on_death(target_idx)
	# BG3: Divine Smite via reação NÃO consome o ponto de Reação — só o spell slot.
	# Assim o Paladino pode dar Smite e ainda fazer um OA no mesmo round.
	_log("%s usou Smite Divino via Reação! +%d dano radiante" % [
		TURN_QUEUE[paladin_idx]["name"], smite_dmg], "dmg")
	return smite_dmg

# Stunning Strike (Monge): gasta 1 Ki; alvo faz save de CON (CD 8+prof+WIS mod).
# Falha = atordoado. Retorna true se atordoou.
func apply_stunning_strike(monk_idx: int, target_idx: int) -> bool:
	var pidx: int = _player_index_by_name(TURN_QUEUE[monk_idx]["name"])
	if pidx < 0 or PLAYERS[pidx].get("ki", 0) < 1:
		return false
	PLAYERS[pidx]["ki"] -= 1
	var wis_mod: int = _raw_mod(PLAYERS[pidx].get("wisdom", 10))
	var prof: int    = PLAYERS[pidx].get("proficiency", 2)
	var dc: int      = 8 + prof + wis_mod
	var fake_action := ActionData.new()
	fake_action.save_attribute = ActionData.DamageAttribute.CON
	var save_result: Dictionary = _resolve_saving_throw(target_idx, dc, fake_action)
	var stunned: bool = not save_result["saved"]
	if stunned:
		combatant_statuses[target_idx]["stun"] = 1
		_break_concentration(target_idx)  # Stun (incapacitado) quebra concentração (BG3)
	consume_reaction(monk_idx)
	var mname: String = TURN_QUEUE[monk_idx]["name"]
	var tname: String = TURN_QUEUE[target_idx]["name"]
	if stunned:
		_log("%s atordoou %s com Golpe Atordoante! (CD %d)" % [mname, tname, dc], "status")
	else:
		_log("%s resistiu ao Golpe Atordoante de %s (CD %d)" % [tname, mname, dc], "miss")
	return stunned

func apply_furtivo_status(player_idx: int) -> void:
	if player_idx < 0 or player_idx >= PLAYERS.size():
		return
	var pname: String = PLAYERS[player_idx]["name"]
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"] and TURN_QUEUE[i]["name"] == pname:
			combatant_statuses[i]["furtivo"] = 1
			break
	_log("%s está em posição furtiva" % pname, "status")

func apply_fury_status(player_idx: int) -> void:
	if player_idx < 0 or player_idx >= PLAYERS.size():
		return
	var pname: String = PLAYERS[player_idx]["name"]
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"] and TURN_QUEUE[i]["name"] == pname:
			combatant_statuses[i]["fury"] = 1
			fury_extra_attack = true
			_log("%s entra em Fúria!" % pname, "status")
			break

func has_fury(player_idx: int) -> bool:
	if player_idx < 0 or player_idx >= PLAYERS.size():
		return false
	var pname: String = PLAYERS[player_idx]["name"]
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"] and TURN_QUEUE[i]["name"] == pname:
			return combatant_statuses[i].get("fury", 0) > 0
	return false

func _is_occupied_by_other(pos: Vector2i) -> bool:
	var t: TerrainTile = tile_data_map[pos.x][pos.y]
	if t.is_void():
		return true
	if t.object == TerrainTile.ObjectType.OBSTACLE:
		return true
	var active_is_player: bool = TURN_QUEUE[active_index]["is_player"]
	for i in range(combatant_positions.size()):
		if i != active_index and not dead_indices.has(i) and combatant_positions[i] == pos:
			if TURN_QUEUE[i]["is_player"] != active_is_player:
				return true
	return false

# Estruturas que cortam a linha de visão E o tiro (BG3): barricada, estátua,
# cobertura. CHEST (baú) é baixo e NÃO bloqueia.
func _blocks_los(tile: TerrainTile) -> bool:
	return tile.object == TerrainTile.ObjectType.OBSTACLE \
		or tile.object == TerrainTile.ObjectType.STATUE \
		or tile.object == TerrainTile.ObjectType.COVER

func _has_los(from_pos: Vector2i, to_pos: Vector2i) -> bool:
	if from_pos == to_pos:
		return true
	var x0 := from_pos.x
	var y0 := from_pos.y
	var x1 := to_pos.x
	var y1 := to_pos.y
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while true:
		if not (x0 == from_pos.x and y0 == from_pos.y) and not (x0 == to_pos.x and y0 == to_pos.y):
			if x0 >= 0 and x0 < grid_cols and y0 >= 0 and y0 < grid_rows:
				var t: TerrainTile = tile_data_map[x0][y0]
				if _blocks_los(t):
					return false
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	return true

func get_attack_target_preview() -> Dictionary:
	if attack_target_indices.is_empty():
		return {}
	var target_idx: int = attack_target_indices[attack_cursor_idx]
	if target_idx == active_index:
		return {"is_self": true}
	var combatant: Dictionary = TURN_QUEUE[target_idx]
	if combatant["is_player"]:
		var pidx: int = _player_index_by_name(combatant["name"])
		if pidx < 0:
			return {}
		var p: Dictionary = PLAYERS[pidx]
		return {
			"name": p["name"],
			"subtitle": p["class"] + " Nv." + str(p["level"]),
			"desc": "HP: %d/%d   AC: %d   SPD: %d" % [p["hp"], p["max_hp"], p["ac"], p["speed"]],
		}
	else:
		return {
			"name": combatant["name"],
			"subtitle": combatant.get("type", "Inimigo"),
			"desc": "HP: %d/%d   AC: %d" % [enemy_hp.get(combatant["name"], 0), get_enemy_max_hp(target_idx), combatant.get("ac", 10)],
		}

func get_attack_cursor_pos() -> Vector2i:
	if attack_tile_mode:
		return attack_tile_cursor
	if attack_target_indices.is_empty():
		return Vector2i.ZERO
	return combatant_positions[attack_target_indices[attack_cursor_idx]]

# Índice do combatante VIVO sobre `pos`, ou -1. Usado pela mira de AoE em tile.
func _combatant_at(pos: Vector2i) -> int:
	for i in range(TURN_QUEUE.size()):
		if dead_indices.has(i):
			continue
		if combatant_positions[i] == pos:
			return i
	return -1

# Tile inicial do cursor de AoE: criatura alvo mais próxima no alcance, senão o
# primeiro tile de alcance disponível, senão a posição do conjurador.
func _initial_attack_tile() -> Vector2i:
	if not attack_target_indices.is_empty():
		return combatant_positions[attack_target_indices[0]]
	var area: Array[Vector2i] = get_attack_area_tiles()
	if not area.is_empty():
		return area[0]
	return combatant_positions[active_index]

# Move o cursor de AoE em tile, restrito aos tiles dentro do alcance (mesma
# métrica/LOS de get_attack_area_tiles).
func move_attack_tile_cursor(delta: Vector2i) -> void:
	if not attack_tile_mode:
		return
	var new_pos := attack_tile_cursor + delta
	new_pos.x = clampi(new_pos.x, 0, grid_cols - 1)
	new_pos.y = clampi(new_pos.y, 0, grid_rows - 1)
	if not get_attack_area_tiles().has(new_pos):
		return
	attack_tile_cursor = new_pos

# Move o centro do AoE para o tile sob o mouse, se for um tile de alcance válido
# (get_attack_area_tiles). Mantém o último válido se fora. Retorna true se moveu.
func set_attack_tile_cursor_clamped(grid_pos: Vector2i) -> bool:
	if not attack_tile_mode:
		return false
	if not get_attack_area_tiles().has(grid_pos):
		return false
	attack_tile_cursor = grid_pos
	return true

func get_attack_target_positions() -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for i in attack_target_indices:
		result.append(combatant_positions[i])
	return result

func get_attack_area_tiles() -> Array[Vector2i]:
	var origin: Vector2i = combatant_positions[active_index]
	var result: Array[Vector2i] = []
	for col in range(grid_cols):
		for row in range(grid_rows):
			var t: TerrainTile = tile_data_map[col][row]
			if t.object == TerrainTile.ObjectType.OBSTACLE:
				continue
			var d: int = maxi(absi(col - origin.x), absi(row - origin.y))
			if d > 0 and d <= current_attack_range:
				if current_attack_range == 1 or _has_los(origin, Vector2i(col, row)):
					result.append(Vector2i(col, row))
	return result

func enter_attack_mode(action_range: int, targets_allies: bool = false, proj_color: Color = Color.WHITE, self_target: bool = false, aoe_radius: int = 0, is_bonus: bool = false) -> void:
	if current_state != State.PLAYER_TURN:
		return
	if has_attacked and not is_bonus and not fury_extra_attack:
		return
	if is_bonus and has_used_bonus_action:
		return
	_current_attack_is_bonus = is_bonus
	_attack_targets_allies = targets_allies
	_attack_self_target = self_target
	current_aoe_radius = aoe_radius
	var effective_range: int = action_range
	if action_range > 1 and _is_elevated(active_index):
		effective_range += 1
	var origin: Vector2i = combatant_positions[active_index]
	attack_target_indices.clear()
	if self_target:
		attack_target_indices.append(active_index)
	for i in range(TURN_QUEUE.size()):
		if i == active_index or dead_indices.has(i):
			continue
		var is_ally: bool = TURN_QUEUE[i]["is_player"]
		if is_ally != targets_allies:
			continue
		# Charmed: o atacante ativo não pode mirar quem o encantou.
		var cs: Dictionary = combatant_statuses[active_index]
		if not targets_allies and cs.get("charmed", 0) > 0 and cs.get("charmed_by", -1) == i:
			continue
		var d: int = king_dist(combatant_positions[i], origin)
		if d <= effective_range:
			if effective_range == 1 or _has_los(origin, combatant_positions[i]):
				attack_target_indices.append(i)
	attack_cursor_idx = 0
	current_attack_range = effective_range
	current_attack_color = proj_color
	# Mira de AoE em PONTO do chão (BG3): só para spells de dano em área (não cura
	# em aliados, não self-target). O cursor passa a ser um tile livre no alcance.
	attack_tile_mode = (aoe_radius > 0 or _current_action is AcaoPular) and not self_target and not targets_allies
	if attack_tile_mode:
		attack_tile_cursor = _initial_attack_tile()
	current_state = State.ATTACK_MODE

func cycle_attack_target(delta: int) -> void:
	if attack_target_indices.is_empty():
		return
	attack_cursor_idx = (attack_cursor_idx + delta + attack_target_indices.size()) % attack_target_indices.size()

func confirm_attack() -> void:
	if attack_tile_mode:
		# Se houver criatura viva no tile mirado E ela for um alvo válido, trata-a
		# como centro (fluxo de alvo único, com rolagem normal de save por _apply_attack).
		# Caso contrário (tile vazio ou criatura fora da lista de alvos), detona no ponto.
		var on_tile: int = _combatant_at(attack_tile_cursor)
		var list_idx: int = attack_target_indices.find(on_tile) if on_tile >= 0 else -1
		if list_idx >= 0:
			attack_cursor_idx = list_idx
			apply_attack_at_cursor()
		else:
			apply_aoe_at_tile(attack_tile_cursor)
		finalize_attack()
		return
	if attack_target_indices.is_empty():
		current_state = State.PLAYER_TURN
		return
	apply_attack_at_cursor()
	finalize_attack()

## Aplica UM hit contra o alvo atualmente selecionado sem mexer nas flags de
## turno nem no contexto de ataque (range/aoe). Usado tanto por confirm_attack
## (1 hit) quanto pelo fluxo multi-hit (Flurry). Retorna o índice do alvo, ou -1.
func apply_attack_at_cursor() -> int:
	if attack_target_indices.is_empty():
		return -1
	var target_idx: int = attack_target_indices[attack_cursor_idx]
	_apply_attack(target_idx)
	return target_idx

## Finaliza as flags de turno após todos os hits de uma ação de ataque
## resolverem. Mantém o contexto de ataque vivo até ser chamado, para que
## hits subsequentes (Flurry) ainda enxerguem range/aoe corretos.
func finalize_attack() -> void:
	# Atacar quebra o estado Oculto (BG3).
	combatant_statuses[active_index].erase("hidden")
	if _current_attack_is_bonus:
		# Ação bônus (Flurry, Atq. Rápido) consome SÓ a ação bônus — nunca a
		# ação principal. Manter has_attacked intacto preserva o ataque normal.
		has_used_bonus_action = true
	else:
		# Ação principal (ou ataque extra de fúria, que gasta a própria flag).
		if has_attacked:
			fury_extra_attack = false
		has_attacked = true
	_current_attack_is_bonus = false
	current_state = State.PLAYER_TURN
	attack_target_indices.clear()
	current_attack_range = 0
	current_aoe_radius = 0
	attack_tile_mode = false

func cancel_attack() -> void:
	current_state = State.PLAYER_TURN
	attack_target_indices.clear()
	current_attack_range = 0
	current_aoe_radius = 0
	attack_tile_mode = false

func _player_index_by_name(pname: String) -> int:
	for i in range(PLAYERS.size()):
		if PLAYERS[i]["name"] == pname:
			return i
	return -1

func cancel_confirmed_attack() -> bool:
	if not has_attacked or _undo_attack_info.is_empty():
		return false
	var target_idx: int = _undo_attack_info["target_idx"]
	var hp_before: int  = _undo_attack_info["hp_before"]
	var target_name: String = TURN_QUEUE[target_idx]["name"]
	if TURN_QUEUE[target_idx]["is_player"]:
		var pidx: int = _player_index_by_name(target_name)
		if pidx >= 0:
			PLAYERS[pidx]["hp"] = hp_before
	else:
		enemy_hp[target_name] = hp_before
	if hp_before > 0 and dead_indices.has(target_idx):
		dead_indices.erase(target_idx)
		battle_result = ""
	has_attacked = false
	_undo_attack_info.clear()
	context_message = "Ataque cancelado."
	return true

func use_item(item: Dictionary) -> void:
	if item.get("count", 0) <= 0:
		return
	item["count"] -= 1
	var pidx: int = get_active_player_index()
	if pidx < 0:
		return
	var pname: String = PLAYERS[pidx]["name"]
	last_attack_info.clear()
	if item.has("heal"):
		var before: int = PLAYERS[pidx]["hp"]
		PLAYERS[pidx]["hp"] = mini(PLAYERS[pidx]["max_hp"], before + item["heal"])
		var actual: int = PLAYERS[pidx]["hp"] - before
		last_attack_info = {"amount": actual, "is_heal": true, "target_idx": active_index}
		context_message = "%s usou %s! +%d HP" % [pname, item["label"], actual]
		_log("%s usou %s (+%d HP)" % [pname, item["label"], actual], "heal")
	elif item.has("spell_slot_restore"):
		var lvl: int = item["spell_slot_restore"] - 1  # índice 0-based
		var slots: Array = PLAYERS[pidx].get("spell_slots", [0, 0, 0, 0, 0, 0])
		var slots_max: Array = PLAYERS[pidx].get("spell_slots_max", [0, 0, 0, 0, 0, 0])
		if lvl >= 0 and lvl < slots.size() and slots[lvl] < slots_max[lvl]:
			slots[lvl] += 1
			last_attack_info = {"amount": 1, "is_heal": true, "target_idx": active_index}
			context_message = "%s usou %s! +1 slot de %dº nível" % [pname, item["label"], lvl + 1]
			_log("%s usou %s (+1 slot nv.%d)" % [pname, item["label"], lvl + 1], "heal")
		else:
			context_message = "%s usou %s! (slots já cheios)" % [pname, item["label"]]
			_log("%s usou %s (sem efeito)" % [pname, item["label"]], "system")

func _get_attr_modifier(attr: ActionData.DamageAttribute) -> int:
	var pidx := get_active_player_index()
	if pidx < 0:
		return 0
	var p: Dictionary = PLAYERS[pidx]
	var val: int
	match attr:
		ActionData.DamageAttribute.STR: val = p.get("strength",     10)
		ActionData.DamageAttribute.DEX: val = p.get("dexterity",    10)
		ActionData.DamageAttribute.INT: val = p.get("intelligence", 10)
		ActionData.DamageAttribute.WIS: val = p.get("wisdom",       10)
		_: return 0
	return int((val - 10) / 2.0)

# Modificador D&D bruto a partir de um valor de atributo (val - 10) / 2.
func _raw_mod(val: int) -> int:
	return int((val - 10) / 2.0)

# Converte um DamageAttribute em chave de save proficiency ("STR"/"DEX"/...).
# CON/CHA não existem como DamageAttribute, então saves só são rolados contra
# STR/DEX/INT/WIS — as outras proficiências ficam armazenadas mas não consultadas.
func _save_attr_to_key(attr: ActionData.DamageAttribute) -> String:
	match attr:
		ActionData.DamageAttribute.STR: return "STR"
		ActionData.DamageAttribute.DEX: return "DEX"
		ActionData.DamageAttribute.INT: return "INT"
		ActionData.DamageAttribute.WIS: return "WIS"
		ActionData.DamageAttribute.CON: return "CON"
		_: return ""

# Modificador de saving throw para qualquer combatente (player ou inimigo).
func _get_save_mod(combatant_idx: int, attr: ActionData.DamageAttribute) -> int:
	if attr == ActionData.DamageAttribute.NONE:
		return 0
	var entry: Dictionary = TURN_QUEUE[combatant_idx]
	var val: int = 10
	if entry["is_player"]:
		var pidx: int = _player_index_by_name(entry["name"])
		if pidx < 0:
			return 0
		var p: Dictionary = PLAYERS[pidx]
		match attr:
			ActionData.DamageAttribute.STR: val = p.get("strength",     10)
			ActionData.DamageAttribute.DEX: val = p.get("dexterity",    10)
			ActionData.DamageAttribute.INT: val = p.get("intelligence", 10)
			ActionData.DamageAttribute.WIS: val = p.get("wisdom",       10)
			ActionData.DamageAttribute.CON: val = p.get("constitution", 10)
			_: return 0
		# Bônus de proficiência se a classe é proficiente nesse save (D&D 5e).
		var base_mod: int = _raw_mod(val)
		var hdata_sv := ALL_HERO_DATA.get(entry["name"], null) as HeroData
		if hdata_sv != null:
			var attr_key: String = _save_attr_to_key(attr)
			if attr_key != "" and hdata_sv.save_proficiencies.has(attr_key):
				return base_mod + p.get("proficiency", 0)
		return base_mod
	else:
		var etype: String = entry.get("type", "")
		var edata := ALL_ENEMIES.get(etype, null) as EnemyData
		if edata == null:
			return 0
		match attr:
			ActionData.DamageAttribute.STR: val = edata.strength
			ActionData.DamageAttribute.DEX: val = edata.dexterity
			ActionData.DamageAttribute.INT: val = edata.intelligence
			ActionData.DamageAttribute.WIS: val = edata.wisdom
			ActionData.DamageAttribute.CON: val = edata.constitution
			_: return 0
	return _raw_mod(val)

# Modificador bruto de atributo (sem proficiência de save) para qualquer
# combatante. Base para testes de perícia genéricos (Atletismo/Acrobacia/etc.).
func _ability_mod(idx: int, attr: ActionData.DamageAttribute) -> int:
	if idx < 0 or idx >= TURN_QUEUE.size():
		return 0
	var entry: Dictionary = TURN_QUEUE[idx]
	var val: int = 10
	if entry["is_player"]:
		var pidx: int = _player_index_by_name(entry["name"])
		if pidx < 0:
			return 0
		var p: Dictionary = PLAYERS[pidx]
		match attr:
			ActionData.DamageAttribute.STR: val = p.get("strength",     10)
			ActionData.DamageAttribute.DEX: val = p.get("dexterity",    10)
			ActionData.DamageAttribute.INT: val = p.get("intelligence", 10)
			ActionData.DamageAttribute.WIS: val = p.get("wisdom",       10)
			ActionData.DamageAttribute.CON: val = p.get("constitution", 10)
			_: return 0
	else:
		var edata := ALL_ENEMIES.get(entry.get("type", ""), null) as EnemyData
		if edata == null:
			return 0
		match attr:
			ActionData.DamageAttribute.STR: val = edata.strength
			ActionData.DamageAttribute.DEX: val = edata.dexterity
			ActionData.DamageAttribute.INT: val = edata.intelligence
			ActionData.DamageAttribute.WIS: val = edata.wisdom
			ActionData.DamageAttribute.CON: val = edata.constitution
			_: return 0
	return _raw_mod(val)

func _athletics_mod(idx: int) -> int:
	return _ability_mod(idx, ActionData.DamageAttribute.STR)

func _acrobatics_mod(idx: int) -> int:
	return _ability_mod(idx, ActionData.DamageAttribute.DEX)

# Percepção passiva (DC base do Hide) = mod de WIS (o "10 +" entra em resolve_hide).
func _perception_passive(idx: int) -> int:
	return _ability_mod(idx, ActionData.DamageAttribute.WIS)

# True se algum combatante VIVO ocupa `pos` (exceto `ignore_idx`).
func _tile_occupied_by_other(pos: Vector2i, ignore_idx: int) -> bool:
	for i in range(TURN_QUEUE.size()):
		if i == ignore_idx or dead_indices.has(i):
			continue
		if combatant_positions[i] == pos:
			return true
	return false

# Wrapper público sobre _get_attack_roll_mods — usado pela UI (hit preview)
# para colorir/rotular Vantagem/Desvantagem. Assinatura interna inalterada.
func get_attack_roll_mods(attacker_idx: int, target_idx: int, attack_range: int) -> Dictionary:
	return _get_attack_roll_mods(attacker_idx, target_idx, attack_range)

# Conta fontes de vantagem/desvantagem para um roll de ataque.
# attack_range: range efetivo do ataque (>1 = ranged).
# Retorna { adv: int, dis: int } — múltiplas fontes se acumulam; cancelo fica com DiceRoller.
func _get_attack_roll_mods(attacker_idx: int, target_idx: int, attack_range: int) -> Dictionary:
	var adv := 0
	var dis := 0
	var atk_status: Dictionary = combatant_statuses[attacker_idx]
	var tgt_status: Dictionary = combatant_statuses[target_idx]

	if atk_status.get("furtivo", 0) > 0:
		adv += 1
	# Atacante Oculto (Hide/BG3): Vantagem nos próprios ataques (habilita Furtivo).
	if atk_status.get("hidden", 0) > 0:
		adv += 1
	# Atacante Invisível: Vantagem nos próprios ataques.
	if atk_status.get("invisible", 0) > 0:
		adv += 1
	# Atacante com condição que atrapalha: Desvantagem nos próprios ataques.
	if atk_status.get("blinded", 0) > 0:
		dis += 1
	if atk_status.get("frightened", 0) > 0:
		dis += 1
	if atk_status.get("restrained", 0) > 0:
		dis += 1
	if tgt_status.get("stun", 0) > 0:
		adv += 1
	# Ataques CONTRA alvos incapacitados/expostos têm Vantagem.
	if tgt_status.get("paralyzed", 0) > 0:
		adv += 1
	if tgt_status.get("restrained", 0) > 0:
		adv += 1
	if tgt_status.get("blinded", 0) > 0:
		adv += 1
	# Ataques CONTRA alvo Invisível têm Desvantagem.
	if tgt_status.get("invisible", 0) > 0:
		dis += 1
	# Prone (BG3/D&D): alvo caído → ataque melee tem Vantagem, ranged tem Desvantagem.
	if tgt_status.get("prone", 0) > 0:
		if attack_range <= 1:
			adv += 1
		else:
			dis += 1

	# Alto terreno (BG3): bônus/penalidade FLAT na rolagem, não advantage.
	# Atacante mais alto que o alvo: +2; atacando de baixo: -2; mesma altura: 0.
	var flat := 0
	if attack_range > 1:
		var atk_high: bool = _is_elevated(attacker_idx)
		var tgt_high: bool = _is_elevated(target_idx)
		if atk_high and not tgt_high:
			flat += 2
		elif tgt_high and not atk_high:
			flat -= 2

	var tgt_pos: Vector2i = combatant_positions[target_idx]
	var tgt_tile: TerrainTile = tile_data_map[tgt_pos.x][tgt_pos.y]
	if tgt_tile.object == TerrainTile.ObjectType.COVER:
		dis += 1
	# Condição Envenenado (superfície de Veneno): desvantagem em ataques.
	# O DoT puro (chave `poison`) NÃO concede Desvantagem — só dano por turno.
	if atk_status.get("poisoned", 0) > 0:
		dis += 1

	# Buff genérico "+1d4 no próximo teste" (base de Bênção): soma dados extras.
	var bonus_dice := 0
	if atk_status.get("bonus_d4", 0) > 0:
		bonus_dice += 1

	return {"adv": adv, "dis": dis, "flat": flat, "bonus_dice": bonus_dice}

# Fontes de vantagem/desvantagem para saving throws do combatente saver_idx.
func _get_save_roll_mods(saver_idx: int) -> Dictionary:
	var adv := 0
	var dis := 0
	var st: Dictionary = combatant_statuses[saver_idx]
	if st.get("stun", 0) > 0:
		dis += 1
	# Condição Envenenado: desvantagem em saving throws / ability checks.
	if st.get("poisoned", 0) > 0:
		dis += 1
	return {"adv": adv, "dis": dis}

# Resolve um saving throw. Rola d20 com mods do alvo e compara com dc.
# Retorna { saved: bool, roll: int, total: int, mode: String, dc: int }.
func _resolve_saving_throw(target_idx: int, dc: int, action: ActionData, save_attr_override: int = -999) -> Dictionary:
	var st: Dictionary = combatant_statuses[target_idx]
	var save_attr = action.save_attribute if save_attr_override == -999 else save_attr_override
	var is_str_dex := save_attr == ActionData.DamageAttribute.STR or save_attr == ActionData.DamageAttribute.DEX
	# Paralyzed (BG3/D&D): falha automática em saves de FOR e DES.
	if st.get("paralyzed", 0) > 0 and is_str_dex:
		_log("%s está paralisado — falha automática no save." % TURN_QUEUE[target_idx]["name"], "status")
		return {"saved": false, "roll": 0, "total": 0, "mode": "auto-fail", "dc": dc}
	var mods: Dictionary = _get_save_roll_mods(target_idx)
	# Restrained: Desvantagem em saves de DES. Prone: Desvantagem em saves de FOR e DES.
	if st.get("restrained", 0) > 0 and save_attr == ActionData.DamageAttribute.DEX:
		mods["dis"] += 1
	if st.get("prone", 0) > 0 and is_str_dex:
		mods["dis"] += 1
	var roll_result: Dictionary = DiceRoller.roll_d20_adv_dis(mods["adv"], mods["dis"])
	var save_roll: int  = roll_result["result"]
	var save_mod: int   = _get_save_mod(target_idx, save_attr)
	var total: int      = save_roll + save_mod
	# Buff genérico "+1d4 no próximo teste" (Bênção) também soma nos saves.
	if st.get("bonus_d4", 0) > 0:
		total += DiceRoller.roll(1, 4)
	# Aura genérica (ex.: Aura de Proteção do Paladino): +bônus de save de aliado em alcance.
	total += _collect_aura_bonus(target_idx, "save_bonus")
	return {
		"saved": total >= dc,
		"roll":  save_roll,
		"total": total,
		"mode":  roll_result["mode"],
		"dc":    dc,
	}

# DC padrão de save de conjuração (D&D 5e): 8 + proficiência + mod do atributo.
func _spell_save_dc(attacker_idx: int, attr: ActionData.DamageAttribute) -> int:
	var pidx: int = get_active_player_index()
	var prof: int = PLAYERS[pidx].get("proficiency", 2) if pidx >= 0 else 2
	return 8 + prof + _get_attr_modifier(attr)

# Hook genérico: aplica `action.applies_condition` ao alvo. Se a ação define um
# atributo de save de condição, o alvo rola um save próprio (DC = condition_dc ou
# o DC de conjuração padrão); falha = recebe a condição. Sem save = aplica no acerto.
func _apply_action_condition(target_idx: int, action: ActionData, attacker_idx: int) -> void:
	if action == null or action.applies_condition == "":
		return
	if dead_indices.has(target_idx):
		return
	var key: String = action.applies_condition
	var applied := true
	if action.condition_save_attribute != ActionData.DamageAttribute.NONE:
		var dc: int = action.condition_dc if action.condition_dc > 0 else _spell_save_dc(attacker_idx, action.damage_attribute)
		var sv: Dictionary = _resolve_saving_throw(target_idx, dc, action, action.condition_save_attribute)
		applied = not sv["saved"]
		_log("%s vs %s — save %s contra %s" % [TURN_QUEUE[attacker_idx]["name"],
			TURN_QUEUE[target_idx]["name"], "resistiu" if sv["saved"] else "falhou",
			StatusDefinitions.name_of(key)], "status")
	if applied:
		apply_condition(target_idx, key, action.condition_duration, attacker_idx)
		_log("%s recebeu %s (%d turnos)" % [TURN_QUEUE[target_idx]["name"],
			StatusDefinitions.name_of(key), action.condition_duration], "status")

# Salva o HP atual do alvo para permitir desfazer o ataque (_undo_attack_info).
func _save_undo_hp(target_idx: int, target_name: String) -> void:
	var hp_before: int
	if TURN_QUEUE[target_idx]["is_player"]:
		var pidx: int = _player_index_by_name(target_name)
		hp_before = PLAYERS[pidx]["hp"] if pidx >= 0 else 0
	else:
		hp_before = enemy_hp.get(target_name, 0)
	_undo_attack_info = {"target_idx": target_idx, "hp_before": hp_before}

# Retorna o valor de DEX de um combatente do TURN_QUEUE (player ou inimigo).
func _combatant_dex(entry: Dictionary) -> int:
	if entry["is_player"]:
		var pidx: int = _player_index_by_name(entry["name"])
		return PLAYERS[pidx].get("dexterity", 10) if pidx >= 0 else 10
	var edata := ALL_ENEMIES.get(entry.get("type", ""), null) as EnemyData
	return edata.dexterity if edata != null else 10

# Rola iniciativa (d20 + mod DEX) para cada combatente e ordena o TURN_QUEUE
# em ordem decrescente. Empate: maior DEX primeiro. Reseta active_index = 0.
# NÃO acessa combatant_positions — deve ser chamada ANTES de setup() atribuir
# posições, para que estas sejam atribuídas já na ordem ordenada.
func roll_initiative() -> void:
	for entry in TURN_QUEUE:
		entry["initiative_roll"] = DiceRoller.roll_d(20) + _raw_mod(_combatant_dex(entry))
	TURN_QUEUE.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["initiative_roll"] != b["initiative_roll"]:
			return a["initiative_roll"] > b["initiative_roll"]
		return _combatant_dex(a) > _combatant_dex(b))
	active_index = 0

# Inicializa o turno do combatente ativo (TURN_QUEUE[active_index]). Deve ser
# chamada DEPOIS de setup() porque depende de combatant_positions.
func begin_turn() -> void:
	# O 1º combatente já está agindo sem passar por advance_turn — marca-o como
	# tendo agido neste round para que o decaimento de superfícies (1x/round)
	# dispare corretamente quando o turno voltar a ele.
	_acted_this_round[active_index] = true
	move_cursor = combatant_positions[active_index]
	has_attacked = false
	has_used_bonus_action = false
	fury_extra_attack = false
	_sneak_attack_used_this_turn = false
	if is_player_turn():
		current_state = State.PLAYER_TURN
		enemy_action_text = ""
		_load_hero_actions(TURN_QUEUE[active_index]["name"])
	else:
		current_state = State.ENEMY_TURN
		_roll_enemy_action()

func get_damage_range(action: ActionData) -> Vector2i:
	var pidx := get_active_player_index()
	if pidx < 0 or action == null:
		return Vector2i(0, 0)
	var p: Dictionary = PLAYERS[pidx]
	var dice_count: int = action.damage_dice_count
	var dice_sides: int = action.damage_dice_sides
	# For weapon attacks, resolve dice from equipped weapon
	if action.is_weapon_attack:
		var weapon: WeaponData = p.get("weapon", null)
		if weapon != null:
			dice_count = weapon.damage_dice_count
			dice_sides = weapon.versatile_dice_sides if (action.use_versatile_grip and weapon.versatile_dice_sides > 0) else weapon.damage_dice_sides
			if weapon.is_finesse:
				var str_mod := int((p.get("strength",  10) - 10) / 2.0)
				var dex_mod := int((p.get("dexterity", 10) - 10) / 2.0)
				var fmod := maxi(str_mod, dex_mod)
				return Vector2i(dice_count + fmod, dice_count * dice_sides + fmod)
			var wmod := int((p.get("strength", 10) - 10) / 2.0)
			return Vector2i(dice_count + wmod, dice_count * dice_sides + wmod)
	var attr_val: int
	match action.damage_attribute:
		ActionData.DamageAttribute.STR: attr_val = p.get("strength",     10)
		ActionData.DamageAttribute.DEX: attr_val = p.get("dexterity",    10)
		ActionData.DamageAttribute.INT: attr_val = p.get("intelligence", 10)
		ActionData.DamageAttribute.WIS: attr_val = p.get("wisdom",       10)
		_: attr_val = 10
	var mod: int = int((attr_val - 10) / 2.0)
	return Vector2i(dice_count + mod, dice_count * dice_sides + mod)

func _apply_attack(target_idx: int) -> void:
	var attacker: String = get_active_combatant()["name"]
	var target_name: String = TURN_QUEUE[target_idx]["name"]
	var action := _current_action
	last_attack_info.clear()

	# Inicia concentração imediatamente ao lançar (cancela a anterior, se houver).
	if action != null and action.requires_concentration:
		_start_concentration(active_index, action)

	# ── CURA — sem rolagem de ataque ─────────────────────────────────────────
	if _attack_targets_allies:
		var pidx: int = _player_index_by_name(target_name)

		# Ação Ajudar (Help, BG3): ergue aliado Downed a 1 HP e remove condições.
		if action != null and (action.revives_downed or not action.clears_conditions.is_empty()):
			var clears: Array = action.clears_conditions if not action.clears_conditions.is_empty() else HELP_CLEARS
			var cleared := false
			for _k in clears:
				if combatant_statuses[target_idx].get(_k, 0) > 0:
					combatant_statuses[target_idx].erase(_k)
					cleared = true
			if is_downed(target_idx):
				_remove_downed(target_idx)
				if pidx >= 0:
					PLAYERS[pidx]["hp"] = maxi(1, PLAYERS[pidx]["hp"])
				last_attack_info = {"amount": 1, "is_heal": true, "target_idx": target_idx,
					"is_crit": false, "hit": true, "attack_roll": 0, "attack_total": 0, "target_ac": 0}
				context_message = "%s ajudou %s! Em pé com 1 HP!" % [attacker, target_name]
				_log("%s ajudou %s! Em pé com 1 HP!" % [attacker, target_name], "heal")
			elif cleared:
				last_attack_info = {"amount": 0, "is_heal": false, "target_idx": target_idx,
					"is_crit": false, "hit": true, "attack_roll": 0, "attack_total": 0, "target_ac": 0}
				context_message = "%s ajudou %s! Condições removidas." % [attacker, target_name]
				_log("%s ajudou %s! Condições removidas." % [attacker, target_name], "heal")
			else:
				last_attack_info = {"amount": 0, "is_heal": false, "target_idx": target_idx,
					"is_crit": false, "hit": false, "attack_roll": 0, "attack_total": 0, "target_ac": 0}
				_log("%s não precisa de ajuda." % target_name, "miss")
			return

		var hp_before: int = PLAYERS[pidx]["hp"] if pidx >= 0 else 0
		_undo_attack_info = {"target_idx": target_idx, "hp_before": hp_before}
		var heal_attr: ActionData.DamageAttribute = action.damage_attribute if action else ActionData.DamageAttribute.WIS
		var heal: int = DiceRoller.roll(
			action.damage_dice_count if action else 2,
			action.damage_dice_sides if action else 4
		) + _get_attr_modifier(heal_attr)
		if pidx >= 0:
			PLAYERS[pidx]["hp"] = mini(PLAYERS[pidx]["max_hp"], PLAYERS[pidx]["hp"] + heal)
			if PLAYERS[pidx]["hp"] > 0 and is_downed(target_idx):
				_remove_downed(target_idx)  # qualquer cura remove o estado Downed
		last_attack_info = {"amount": heal, "is_heal": true, "target_idx": target_idx,
			"is_crit": false, "hit": true, "attack_roll": 0, "attack_total": 0, "target_ac": 0}
		context_message = "%s healed %s for %d HP!" % [attacker, target_name, heal]
		_log("%s curou %s em %d HP" % [attacker, target_name, heal], "heal")
		if current_aoe_radius > 0:
			_apply_aoe_heal_splash(target_idx, heal)
		return

	var target_ac: int = TURN_QUEUE[target_idx].get("ac", 10)
	# Condição Acid (superfície de Ácido): -2 CA.
	if combatant_statuses[target_idx].get("acid", 0) > 0:
		target_ac -= 2

	# Cobertura agora vira Desvantagem na rolagem (ver _get_attack_roll_mods),
	# não mais um flat miss pré-rolagem.

	# ── Resolve dados do atacante ────────────────────────────────────────────
	var pidx_atk: int       = get_active_player_index()
	var prof: int           = PLAYERS[pidx_atk].get("proficiency", 2) if pidx_atk >= 0 else 2
	var crit_threshold: int = PLAYERS[pidx_atk].get("crit_threshold", 20) if pidx_atk >= 0 else 20
	var bonus_atk: int      = PLAYERS[pidx_atk].get("bonus_atk", 0) if pidx_atk >= 0 else 0
	var weapon: WeaponData  = PLAYERS[pidx_atk].get("weapon", null) if pidx_atk >= 0 else null

	# Resolve atributo e dados de dano (arma vs ação)
	var is_weapon_atk: bool = action != null and action.is_weapon_attack
	var attr: ActionData.DamageAttribute = ActionData.DamageAttribute.STR
	var dice_count: int = 1
	var dice_sides: int = 6
	var weapon_attack_bonus: int = 0
	if is_weapon_atk and weapon != null:
		attr                = weapon.damage_attribute
		dice_count          = weapon.damage_dice_count
		dice_sides          = weapon.damage_dice_sides
		weapon_attack_bonus = weapon.attack_bonus
		if action.use_versatile_grip and weapon.versatile_dice_sides > 0:
			dice_sides = weapon.versatile_dice_sides
		if weapon.is_finesse and pidx_atk >= 0:
			var p: Dictionary = PLAYERS[pidx_atk]
			var str_mod := _raw_mod(p.get("strength",  10))
			var dex_mod := _raw_mod(p.get("dexterity", 10))
			attr = ActionData.DamageAttribute.DEX if dex_mod >= str_mod else ActionData.DamageAttribute.STR
	elif action != null:
		attr       = action.damage_attribute
		dice_count = action.damage_dice_count
		dice_sides = action.damage_dice_sides

	var attr_mod: int = _get_attr_modifier(attr)

	var is_saving_throw: bool = action != null and action.requires_saving_throw
	# Auto-hit: spells de área ou slot sem saving throw (cantrips de área, etc.)
	var is_auto_hit: bool = not is_saving_throw and action != null and (
		action.aoe_radius > 0 or
		(not action.is_weapon_attack and action.spell_slot_level > 0)
	)

	# ── SAVING THROW — spells que permitem resistência ───────────────────────
	if is_saving_throw:
		_save_undo_hp(target_idx, target_name)
		var dc: int = _spell_save_dc(active_index, attr)
		var save_result: Dictionary = _resolve_saving_throw(target_idx, dc, action)
		var base_dmg: int = DiceRoller.roll(dice_count, dice_sides) + attr_mod + bonus_atk
		var st_damage: int = maxi(1, base_dmg / 2 if save_result["saved"] else base_dmg)
		st_damage = _apply_damage_type_mods(target_idx, action.damage_type if action != null else ActionData.DamageType.PHYSICAL, st_damage)
		battle_stats["player_damage_dealt"] = battle_stats.get("player_damage_dealt", 0) + st_damage
		if TURN_QUEUE[target_idx]["is_player"]:
			var pidx_st: int = _player_index_by_name(target_name)
			if pidx_st >= 0:
				PLAYERS[pidx_st]["hp"] = maxi(0, PLAYERS[pidx_st]["hp"] - st_damage)
				_check_concentration_after_damage(target_idx, st_damage)
				if PLAYERS[pidx_st]["hp"] <= 0:
					if is_downed(target_idx):
						_add_death_save_failure(target_idx, 1)
					else:
						_on_death(target_idx)
		else:
			var new_hp_st: int = maxi(0, enemy_hp.get(target_name, 0) - st_damage)
			enemy_hp[target_name] = new_hp_st
			if new_hp_st <= 0:
				_on_death(target_idx)
		last_attack_info = {
			"amount": st_damage, "is_heal": false, "target_idx": target_idx,
			"is_crit": false, "hit": true,
			"attack_roll": save_result["roll"], "attack_total": save_result["total"],
			"target_ac": target_ac, "smite_amount": 0,
			"damage_type": action.damage_type if action != null else ActionData.DamageType.PHYSICAL,
			"roll_mode": save_result["mode"], "other_roll": 0,
			"is_saving_throw": true, "save_dc": dc,
			"save_roll": save_result["roll"], "save_total": save_result["total"],
		}
		var result_txt: String = "resistiu" if save_result["saved"] else "falhou"
		var sv_mod: int = _get_save_mod(target_idx, action.save_attribute)
		context_message = "%s vs %s — Saving Throw DC %d: %s (%d dano)" % [
			attacker, target_name, dc, result_txt, st_damage]
		_log("%s Saving Throw DC %d: %s rola %d+%d=%d — %s (%d dano)" % [
			attacker, dc, target_name, save_result["roll"], sv_mod,
			save_result["total"], result_txt, st_damage], "status" if save_result["saved"] else "dmg")
		if current_aoe_radius > 0:
			# Cada alvo secundário faz seu próprio save: falha = dano cheio,
			# passa = metade (mesma DC do alvo principal).
			_apply_aoe_splash(target_idx, base_dmg, dc, action)
		_deposit_surface_after_attack(combatant_positions[target_idx], action)
		_apply_action_condition(target_idx, action, active_index)
		return

	# ── ROLAGEM DE ATAQUE ────────────────────────────────────────────────────
	var d20: int = 0
	var attack_total: int = 999
	var is_crit: bool = false
	var roll_mode: String = "normal"
	var other_roll: int = 0
	if not is_auto_hit:
		var _mods: Dictionary = _get_attack_roll_mods(active_index, target_idx, current_attack_range)
		var _roll_result: Dictionary = DiceRoller.roll_d20_adv_dis(_mods["adv"], _mods["dis"])
		d20        = _roll_result["result"]
		roll_mode  = _roll_result["mode"]
		other_roll = _roll_result["other"]
		if d20 == 1:
			_save_undo_hp(target_idx, target_name)
			last_attack_info = {"amount": 0, "is_heal": false, "target_idx": target_idx,
				"is_crit": false, "hit": false, "attack_roll": d20, "attack_total": d20, "target_ac": target_ac,
				"roll_mode": roll_mode, "other_roll": other_roll,
				"is_saving_throw": false, "save_dc": 0, "save_roll": 0, "save_total": 0}
			context_message = "Erro Crítico! %s errou feio." % attacker
			_log("Erro Crítico! %s errou feio." % attacker, "miss")
			return
		attack_total = d20 + prof + attr_mod + weapon_attack_bonus + _mods.get("flat", 0)
		if _mods.get("bonus_dice", 0) > 0:
			attack_total += DiceRoller.roll(_mods["bonus_dice"], 4)
		if d20 >= crit_threshold:
			is_crit = true
		elif attack_total < target_ac:
			_save_undo_hp(target_idx, target_name)
			last_attack_info = {"amount": 0, "is_heal": false, "target_idx": target_idx,
				"is_crit": false, "hit": false, "attack_roll": d20, "attack_total": attack_total, "target_ac": target_ac,
				"roll_mode": roll_mode, "other_roll": other_roll,
				"is_saving_throw": false, "save_dc": 0, "save_roll": 0, "save_total": 0}
			context_message = "%s rolou %d+%d+%d=%d vs AC %d — ERROU!" % [attacker, d20, prof, attr_mod, attack_total, target_ac]
			_log("%s rolou %d+%d+%d=%d vs AC %d — ERROU" % [attacker, d20, prof, attr_mod, attack_total, target_ac], "miss")
			return

	# Auto-crit (BG3/D&D): ataque melee que acerta um alvo Paralisado é sempre crítico.
	if current_attack_range <= 1 and combatant_statuses[target_idx].get("paralyzed", 0) > 0:
		is_crit = true

	# ── DANO — proficiência NUNCA entra no dano ──────────────────────────────
	var roll_count: int = dice_count * 2 if is_crit else dice_count
	var damage: int = DiceRoller.roll(roll_count, dice_sides) + attr_mod + bonus_atk

	# Bônus de status aplicados APÓS o dano base. Rastreados em separado para
	# que o display estilo BG3 mostre cada componente como um floater próprio.
	var status_bonus: int = 0
	var status_bonus_label: String = ""
	var statuses: Dictionary = combatant_statuses[active_index]
	if statuses.get("raging", 0) > 0 and current_attack_range <= 1 and attr == ActionData.DamageAttribute.STR:
		damage += 2
	if _can_sneak_attack(active_index, target_idx):
		var sneak: int = DiceRoller.roll(2, 6)
		if statuses.get("furtivo", 0) > 0:
			statuses.erase("furtivo")
		_sneak_attack_used_this_turn = true
		_log("%s usa Ataque Furtivo! +2d6=%d" % [attacker, sneak], "status")
		damage += sneak
		status_bonus += sneak
		status_bonus_label = "Furtivo"
	if statuses.get("fury", 0) > 0:
		damage += 4
		status_bonus += 4
		status_bonus_label = "Fúria" if status_bonus_label == "" else status_bonus_label + "+Fúria"
	# Alvo Marcado: o autor da marca causa dano extra ao acertá-lo (Marca do Caçador).
	var tstat: Dictionary = combatant_statuses[target_idx]
	if tstat.get("marked", 0) > 0 and tstat.get("marked_by", -1) == active_index:
		var mk: int = DiceRoller.roll(tstat.get("marked_n", 1), tstat.get("marked_d", 6))
		damage += mk
		status_bonus += mk
		status_bonus_label = "Marca" if status_bonus_label == "" else status_bonus_label + "+Marca"
		_log("%s atinge alvo Marcado! +%dd%d=%d" % [attacker, tstat.get("marked_n", 1), tstat.get("marked_d", 6), mk], "status")
	var smite_amount: int = 0
	if action != null and action.smite_dice_count > 0:
		var smite_rolls: int = action.smite_dice_count * 2 if is_crit else action.smite_dice_count
		smite_amount = DiceRoller.roll(smite_rolls, action.smite_dice_sides)
		_log("%s Smite Divino! +%dd%d=%d radiante" % [attacker, action.smite_dice_count, action.smite_dice_sides, smite_amount], "crit")
		damage += smite_amount
	# Arma mergulhada (Dip): +1d4 de Fogo por alguns ataques com arma; gasta carga.
	if is_weapon_atk and statuses.get("coated_fire", 0) > 0:
		var coat: int = DiceRoller.roll(1, 4)
		damage += coat
		status_bonus += coat
		status_bonus_label = "Fogo" if status_bonus_label == "" else status_bonus_label + "+Fogo"
		statuses["coated_fire"] -= 1
		_log("%s arma em chamas! +1d4=%d de Fogo" % [attacker, coat], "status")
	damage = maxi(1, damage)
	# Resistência/Vulnerabilidade/Imunidade + Wet do alvo (último passo).
	damage = _apply_damage_type_mods(target_idx, action.damage_type if action != null else ActionData.DamageType.PHYSICAL, damage)

	# ── APLICA O DANO ────────────────────────────────────────────────────────
	_save_undo_hp(target_idx, target_name)
	battle_stats["player_damage_dealt"] = battle_stats.get("player_damage_dealt", 0) + damage
	if TURN_QUEUE[target_idx]["is_player"]:
		var pidx: int = _player_index_by_name(target_name)
		if pidx >= 0:
			PLAYERS[pidx]["hp"] = maxi(0, PLAYERS[pidx]["hp"] - damage)
			_check_concentration_after_damage(target_idx, damage)
			if PLAYERS[pidx]["hp"] <= 0:
				if is_downed(target_idx):
					_add_death_save_failure(target_idx, 2 if is_crit else 1)
				else:
					_on_death(target_idx)
	else:
		var new_hp: int = maxi(0, enemy_hp.get(target_name, 0) - damage)
		enemy_hp[target_name] = new_hp
		if new_hp <= 0:
			_on_death(target_idx)

	last_attack_info = {"amount": damage, "is_heal": false, "target_idx": target_idx,
		"is_crit": is_crit, "hit": true, "attack_roll": d20, "attack_total": attack_total,
		"target_ac": target_ac, "smite_amount": smite_amount,
		"status_bonus_amount": status_bonus, "status_bonus_label": status_bonus_label,
		"damage_type": action.damage_type if action != null else ActionData.DamageType.PHYSICAL,
		"roll_mode": roll_mode, "other_roll": other_roll,
		"is_saving_throw": false, "save_dc": 0, "save_roll": 0, "save_total": 0}
	if is_crit:
		battle_stats["crits"] = battle_stats.get("crits", 0) + 1
		context_message = "CRÍTICO! %s acertou %s por %d de dano!" % [attacker, target_name, damage]
		_log("CRÍTICO! %s acertou %s por %d de dano" % [attacker, target_name, damage], "crit")
	else:
		context_message = "%s hit %s for %d damage!" % [attacker, target_name, damage]
		_log("%s acertou %s por %d de dano" % [attacker, target_name, damage], "dmg")

	# Respingo de AoE
	if current_aoe_radius > 0:
		_apply_aoe_splash(target_idx, int(damage / 2.0), 0, action)

	_deposit_surface_after_attack(combatant_positions[target_idx], action)
	_apply_action_condition(target_idx, action, active_index)

# Aplica o respingo de AoE aos alvos secundários no raio, centrado no alvo
# primário (conjurador + primário excluídos). Wrapper fino sobre _aoe_damage_at
# para preservar a assinatura usada pelos dois ramos de _apply_attack.
func _apply_aoe_splash(primary_idx: int, splash_damage: int, dc: int = 0, action: ActionData = null) -> void:
	_aoe_damage_at(combatant_positions[primary_idx], current_aoe_radius, splash_damage, dc,
		action, [active_index, primary_idx], true)

# Núcleo de dano em ÁREA: atinge todos os combatentes vivos a ≤ radius (Manhattan)
# de `center`, exceto os índices em `exclude`. Friendly fire (BG3): inimigos E
# aliados. Quando dc > 0 e action != null, cada alvo faz seu PRÓPRIO saving throw
# (falha = full_dmg cheio, passa = metade); sem dc, aplica full_dmg flat (legado).
# Se enqueue_floaters, enfileira cada acerto em pending_surface_hits (usado pela
# detonação em tile vazio, que não tem alvo primário em last_attack_info).
func _aoe_damage_at(center: Vector2i, radius: int, full_dmg: int, dc: int, action: ActionData, exclude: Array, enqueue_floaters: bool = false) -> void:
	var hits: Array[int] = []
	for i in range(TURN_QUEUE.size()):
		if exclude.has(i) or dead_indices.has(i):
			continue
		var d: int = king_dist(combatant_positions[i], center)
		if d <= radius:
			hits.append(i)
	for i in hits:
		var sname: String = TURN_QUEUE[i]["name"]
		var final_dmg: int = full_dmg
		var save_txt: String = ""
		if dc > 0 and action != null:
			_save_undo_hp(i, sname)
			var save_result: Dictionary = _resolve_saving_throw(i, dc, action)
			final_dmg = maxi(1, full_dmg / 2) if save_result["saved"] else full_dmg
			save_txt = " (resistiu, metade)" if save_result["saved"] else " (falhou)"
		# Resistência/Vulnerabilidade/Imunidade + Wet do alvo (último passo).
		final_dmg = _apply_damage_type_mods(i, action.damage_type if action != null else ActionData.DamageType.PHYSICAL, final_dmg)
		battle_stats["player_damage_dealt"] = battle_stats.get("player_damage_dealt", 0) + final_dmg
		if enqueue_floaters:
			var fl_color: Color = ActionData.damage_type_color(action.damage_type) if action != null else Color(0.78, 0.45, 1.0)
			_register_damage_floater(i, final_dmg, fl_color, "")
		if TURN_QUEUE[i]["is_player"]:
			var pidx: int = _player_index_by_name(sname)
			if pidx >= 0:
				PLAYERS[pidx]["hp"] = maxi(0, PLAYERS[pidx]["hp"] - final_dmg)
				_check_concentration_after_damage(i, final_dmg)
				if PLAYERS[pidx]["hp"] <= 0:
					_on_death(i)
		else:
			var new_hp: int = maxi(0, enemy_hp.get(sname, 0) - final_dmg)
			enemy_hp[sname] = new_hp
			if new_hp <= 0:
				_on_death(i)
		_log("AoE acertou %s por %d de dano%s" % [sname, final_dmg, save_txt], "dmg")
		# Hook genérico de condição também atinge alvos secundários no raio.
		_apply_action_condition(i, action, active_index)

## Detona uma spell de AoE num PONTO do chão (sem criatura no centro). Calcula DC
## e dano-base como o ramo de saving throw de _apply_attack; todos no raio fazem o
## próprio save. Deposita a superfície (que já faz o _ignite) e enfileira floaters.
func apply_aoe_at_tile(center: Vector2i) -> void:
	var action: ActionData = _current_action
	if action == null:
		return
	var pidx_atk: int  = get_active_player_index()
	var prof: int      = PLAYERS[pidx_atk].get("proficiency", 2) if pidx_atk >= 0 else 2
	var bonus_atk: int = PLAYERS[pidx_atk].get("bonus_atk", 0) if pidx_atk >= 0 else 0
	var attr: ActionData.DamageAttribute = action.damage_attribute
	var attr_mod: int  = _get_attr_modifier(attr)
	var base_dmg: int  = DiceRoller.roll(action.damage_dice_count, action.damage_dice_sides) + attr_mod + bonus_atk
	var dc: int        = 8 + prof + attr_mod
	var attacker: String = TURN_QUEUE[active_index]["name"]
	# Sem alvo primário: o floater vem de pending_surface_hits, não de last_attack_info.
	last_attack_info = {}
	context_message = "%s conjura %s no chão (DC %d)" % [attacker, action.label, dc]
	_log("%s conjura %s no chão (DC %d)" % [attacker, action.label, dc], "status")
	_aoe_damage_at(center, current_aoe_radius, base_dmg, dc, action, [active_index], true)
	_deposit_surface_after_attack(center, action)

# Splash de cura: cura os aliados (jogadores) no raio, além do alvo primário.
# Reusa o mesmo valor de cura rolado para o primário (BG3: rola uma vez).
func _apply_aoe_heal_splash(primary_idx: int, heal_amount: int) -> void:
	var primary_pos: Vector2i = combatant_positions[primary_idx]
	for i in range(TURN_QUEUE.size()):
		if i == primary_idx or dead_indices.has(i):
			continue
		if not TURN_QUEUE[i]["is_player"]:
			continue  # cura só aliados (jogadores)
		var d: int = king_dist(combatant_positions[i], primary_pos)
		if d > current_aoe_radius:
			continue
		var pidx: int = _player_index_by_name(TURN_QUEUE[i]["name"])
		if pidx >= 0:
			PLAYERS[pidx]["hp"] = mini(PLAYERS[pidx]["max_hp"], PLAYERS[pidx]["hp"] + heal_amount)
			if PLAYERS[pidx]["hp"] > 0 and is_downed(i):
				_remove_downed(i)
			_log("Cura em área curou %s em %d HP" % [TURN_QUEUE[i]["name"], heal_amount], "heal")

func get_enemy_max_hp(idx: int) -> int:
	var enemy_type: String = TURN_QUEUE[idx].get("type", "")
	var edata := ALL_ENEMIES.get(enemy_type, null) as EnemyData
	return edata.max_hp if edata != null else 30

func get_active_status_text(idx: int) -> String:
	if idx < 0 or idx >= combatant_statuses.size():
		return ""
	var status: Dictionary = combatant_statuses[idx]
	var parts: Array[String] = []
	# Texto montado a partir da fonte única StatusDefinitions (mesma usada na HUD).
	for key: String in StatusDefinitions.ORDER:
		if status.get(key, 0) > 0:
			if StatusDefinitions.shows_duration(key):
				parts.append("%s(%d)" % [StatusDefinitions.name_of(key), int(status[key])])
			else:
				parts.append(StatusDefinitions.name_of(key))
	return "  ".join(parts)

# Ponto ÚNICO para aplicar uma condição. Centraliza efeitos colaterais:
# Paralyzed e Prone quebram concentração (BG3/D&D). source_idx é usado por
# Charmed para registrar quem encantou (não pode atacar essa origem).
func apply_condition(idx: int, key: String, duration: int, source_idx: int = -1) -> void:
	if idx < 0 or idx >= combatant_statuses.size():
		return
	combatant_statuses[idx][key] = duration
	if key == "charmed" and source_idx >= 0:
		combatant_statuses[idx]["charmed_by"] = source_idx
	if key == "frightened" and source_idx >= 0:
		combatant_statuses[idx]["frightened_by"] = source_idx
	if key == "paralyzed" or key == "prone":
		_break_concentration(idx)

# Marca um alvo (base de Marca do Caçador): só o autor (source_idx) causa o dano
# extra ao acertá-lo. Armazena fonte e dados do bônus no próprio status.
func apply_mark(target_idx: int, source_idx: int, dice_count: int, dice_sides: int, duration: int) -> void:
	if target_idx < 0 or target_idx >= combatant_statuses.size():
		return
	var st: Dictionary = combatant_statuses[target_idx]
	st["marked"] = duration
	st["marked_by"] = source_idx
	st["marked_n"] = dice_count
	st["marked_d"] = dice_sides

# Framework de aura: coleta o maior bônus `effect` emitido por aliados vivos
# (inclui o próprio) dentro do raio da aura (distância Chebyshev). Atribuição da
# aura a cada herói é build (HeroData.aura_*). Efeito suportado: "save_bonus".
func _collect_aura_bonus(target_idx: int, effect: String) -> int:
	var best := 0
	var t_player: bool = TURN_QUEUE[target_idx]["is_player"]
	var t_pos: Vector2i = combatant_positions[target_idx]
	for i in range(TURN_QUEUE.size()):
		if dead_indices.has(i):
			continue
		if TURN_QUEUE[i]["is_player"] != t_player:
			continue
		var hdata := ALL_HERO_DATA.get(TURN_QUEUE[i]["name"], null) as HeroData
		if hdata == null or hdata.aura_effect != effect or hdata.aura_radius <= 0:
			continue
		var d: int = maxi(absi(combatant_positions[i].x - t_pos.x), absi(combatant_positions[i].y - t_pos.y))
		if d <= hdata.aura_radius:
			best = maxi(best, hdata.aura_value)
	return best

# ══════════════════════════════════════════════════════════════════════════
# 3.3 — Ações táticas BG3 (universais; qualquer combatente usa)
# ══════════════════════════════════════════════════════════════════════════

# Empurrar (Shove, BG3): Ação Bônus. Contest Atletismo do empurrador vs passiva
# (10 + maior de Atletismo/Acrobacia) do alvo. Sucesso empurra `dist` tiles na
# direção oposta, parando em obstáculo/ocupado. Cair no void mata. NÃO derruba
# Prone (BG3). Dispara entrada na superfície do tile final.
func resolve_shove(attacker_idx: int, target_idx: int, dist: int = 2) -> Dictionary:
	last_attack_info.clear()
	var atk_roll: int = DiceRoller.roll_d(20) + _athletics_mod(attacker_idx)
	var def_passive: int = 10 + maxi(_athletics_mod(target_idx), _acrobatics_mod(target_idx))
	if atk_roll < def_passive:
		_log("%s tentou empurrar %s e falhou (%d vs %d)" % [TURN_QUEUE[attacker_idx]["name"],
			TURN_QUEUE[target_idx]["name"], atk_roll, def_passive], "miss")
		return {"success": false}
	var a: Vector2i = combatant_positions[attacker_idx]
	var t: Vector2i = combatant_positions[target_idx]
	var dir := Vector2i(signi(t.x - a.x), signi(t.y - a.y))
	if dir == Vector2i.ZERO:
		dir = Vector2i(1, 0)
	var pos := t
	for _i in range(dist):
		var nxt: Vector2i = pos + dir
		if nxt.x < 0 or nxt.x >= grid_cols or nxt.y < 0 or nxt.y >= grid_rows:
			break
		var tile: TerrainTile = tile_data_map[nxt.x][nxt.y]
		if tile.object == TerrainTile.ObjectType.OBSTACLE:
			break
		if _tile_occupied_by_other(nxt, target_idx):
			break
		pos = nxt
		if tile.is_void():
			combatant_positions[target_idx] = pos
			_fall_into_void(target_idx)
			return {"success": true, "void": true, "new_pos": pos}
	combatant_positions[target_idx] = pos
	_apply_surface_tick(target_idx)  # entra na superfície do tile final
	_log("%s empurrou %s para %s" % [TURN_QUEUE[attacker_idx]["name"],
		TURN_QUEUE[target_idx]["name"], str(pos)], "system")
	return {"success": true, "void": false, "new_pos": pos}

# Queda no void (chasm): morte imediata (BG3 — queda em abismo).
func _fall_into_void(idx: int) -> void:
	_log("%s caiu no vazio!" % TURN_QUEUE[idx]["name"], "dmg")
	_on_death(idx)

# Esconder (Hide, BG3): Ação. À vista de um inimigo (LoS direta) e SEM cobertura,
# esconder-se é negado. Fora de vista ou em cobertura, rola Furtividade (d20 +
# DES) vs maior Percepção passiva (10 + WIS) dos inimigos que veem. Sucesso =>
# Oculto (Vantagem + habilita Furtivo).
func resolve_hide(idx: int) -> bool:
	var me: Vector2i = combatant_positions[idx]
	var seers: Array[int] = []
	for i in range(TURN_QUEUE.size()):
		if dead_indices.has(i) or TURN_QUEUE[i]["is_player"] == TURN_QUEUE[idx]["is_player"]:
			continue
		if _has_los(combatant_positions[i], me):
			seers.append(i)
	# À vista e sem cobertura: não dá para se esconder (BG3).
	if not seers.is_empty() and not _is_in_cover(me):
		_log("%s está à vista de %d inimigo(s) — precisa de cobertura para se esconder." % [TURN_QUEUE[idx]["name"], seers.size()], "miss")
		return false
	var dc := 10
	for s in seers:
		dc = maxi(dc, 10 + _perception_passive(s))
	var stealth: int = DiceRoller.roll_d(20) + _acrobatics_mod(idx)
	if stealth >= dc:
		combatant_statuses[idx]["hidden"] = 1
		_log("%s se escondeu (Oculto) — Furtividade %d vs DC %d" % [TURN_QUEUE[idx]["name"], stealth, dc], "status")
		return true
	_log("%s falhou em se esconder (%d vs DC %d)" % [TURN_QUEUE[idx]["name"], stealth, dc], "miss")
	return false

# Cobertura: tile COVER no próprio tile ou adjacente (Chebyshev ≤ 1).
func _is_in_cover(pos: Vector2i) -> bool:
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var p := pos + Vector2i(dx, dy)
			if p.x < 0 or p.x >= grid_cols or p.y < 0 or p.y >= grid_rows:
				continue
			if tile_data_map[p.x][p.y].object == TerrainTile.ObjectType.COVER:
				return true
	return false

# Quebra Oculto se algum inimigo vivo tem linha de visão até `idx` (avistado).
func _break_hidden_if_seen(idx: int) -> void:
	if combatant_statuses[idx].get("hidden", 0) <= 0:
		return
	var me: Vector2i = combatant_positions[idx]
	for i in range(TURN_QUEUE.size()):
		if dead_indices.has(i) or TURN_QUEUE[i]["is_player"] == TURN_QUEUE[idx]["is_player"]:
			continue
		if _has_los(combatant_positions[i], me):
			combatant_statuses[idx].erase("hidden")
			_log("%s foi avistado — não está mais Oculto" % TURN_QUEUE[idx]["name"], "status")
			return

# Tiles vistos por QUALQUER inimigo vivo (sombra cortada por obstáculos via
# _has_los). Base do overlay de LOS (Left Shift) e da coerência do Esconder.
# Visão limitada só por LoS (grade pequena); ENEMY_SIGHT_RANGE permite tuning.
const FEET_PER_TILE := 5
const ENEMY_SIGHT_FEET := 40
const ENEMY_SIGHT_RANGE := ENEMY_SIGHT_FEET / FEET_PER_TILE  # 8 tiles (Chebyshev) = 40 pés
func get_enemy_vision_tiles() -> Dictionary:
	var seen: Dictionary = {}
	for e in range(TURN_QUEUE.size()):
		if dead_indices.has(e) or TURN_QUEUE[e]["is_player"]:
			continue
		var ep: Vector2i = combatant_positions[e]
		for col in range(grid_cols):
			for row in range(grid_rows):
				var p := Vector2i(col, row)
				if tile_data_map[col][row].is_void():
					continue
				if king_dist(ep, p) > ENEMY_SIGHT_RANGE:
					continue
				if _has_los(ep, p):
					seen[p] = true
	return seen

# Mergulhar arma (Dip, BG3): Ação Bônus. Sobre uma superfície de Fogo, reveste a
# arma — os próximos ataques com arma ganham +1d4 de Fogo (cargas em coated_fire).
func resolve_dip(idx: int) -> bool:
	var pos: Vector2i = combatant_positions[idx]
	var surf: int = tile_surfaces.get(pos, {}).get("type", SurfaceType.Type.NONE)
	if surf != SurfaceType.Type.FIRE:
		_log("%s não tem superfície de Fogo para mergulhar a arma." % TURN_QUEUE[idx]["name"], "miss")
		return false
	combatant_statuses[idx]["coated_fire"] = 3
	_log("%s mergulhou a arma nas chamas! (+1d4 Fogo)" % TURN_QUEUE[idx]["name"], "status")
	return true

# Pular (Jump, BG3): Ação Bônus. Custo de movimento FIXO (10 pés = 2 tiles),
# independente da distância. Alcance máximo escala com FOR (jump_reach). Atravessa
# void/superfícies (ignora intermediários), mas o tile de POUSO deve ser válido
# (não-void, sem obstáculo, desocupado). Evita Ataque de Oportunidade.
const JUMP_MOVE_COST := 2  # 10 pés (BG3): custo de movimento FIXO por pulo

# Alcance máximo do pulo (Chebyshev), BG3: mín. 3 tiles (15 pés); 6 tiles (30 pés) em FOR 20.
func jump_reach(idx: int) -> int:
	return clampi(3 + _ability_mod(idx, ActionData.DamageAttribute.STR) * 3 / 5, 3, 6)

# Pouso de pulo válido: Chebyshev ≤ jump_reach, tile não-void, sem obstáculo,
# desocupado. Fonte única usada por resolve_jump, pela prévia do arco e pelo clique.
func is_valid_jump_landing(idx: int, dest: Vector2i) -> bool:
	if dest.x < 0 or dest.x >= grid_cols or dest.y < 0 or dest.y >= grid_rows:
		return false
	var here: Vector2i = combatant_positions[idx]
	var reach: int = jump_reach(idx)
	var d: int = maxi(absi(dest.x - here.x), absi(dest.y - here.y))
	if d <= 0 or d > reach:
		return false
	var tile: TerrainTile = tile_data_map[dest.x][dest.y]
	if tile.is_void() or tile.object == TerrainTile.ObjectType.OBSTACLE:
		return false
	if _tile_occupied_by_other(dest, idx):
		return false
	return true

# Conjunto de tiles de pouso válidos (para testes / consultas).
func get_jump_landing_tiles(idx: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for col in range(grid_cols):
		for row in range(grid_rows):
			var p := Vector2i(col, row)
			if is_valid_jump_landing(idx, p):
				out.append(p)
	return out

func resolve_jump(idx: int, dest: Vector2i) -> bool:
	if not is_valid_jump_landing(idx, dest):
		return false
	if move_points_remaining < JUMP_MOVE_COST:
		return false
	# Pular PROVOCA Ataque de Oportunidade (BG3 atual): a OA é checada no
	# deslocamento pela BattleScene, igual ao movimento normal. (Sem disengage.)
	combatant_positions[idx] = dest
	move_points_remaining = maxi(0, move_points_remaining - JUMP_MOVE_COST)
	_apply_surface_tick(idx)
	_log("%s pulou para %s" % [TURN_QUEUE[idx]["name"], str(dest)], "system")
	return true

# Arremessar (Throw, BG3): Ação. Joga um item/poção num tile — o efeito do item
# é aplicado via os hooks existentes: superfície (creates_surface), dano AoE e
# condição (applies_condition). `action` descreve o item arremessado.
func resolve_throw(center: Vector2i, action: ActionData) -> void:
	if action == null:
		return
	last_attack_info.clear()
	var radius: int = maxi(0, action.aoe_radius)
	if action.damage_dice_count > 0:
		# Com dano: _aoe_damage_at já aplica dano + condição (via _apply_action_condition).
		var base: int = DiceRoller.roll(action.damage_dice_count, action.damage_dice_sides)
		_aoe_damage_at(center, radius, base, 0, action, [], true)
	else:
		# Sem dano: ainda aplica a condição a quem está no raio.
		for i in range(TURN_QUEUE.size()):
			if dead_indices.has(i):
				continue
			if king_dist(combatant_positions[i], center) <= radius:
				_apply_action_condition(i, action, active_index)
	# Superfície depositada por último (Fogo já ateia quem está em cima).
	_deposit_surface_after_attack(center, action)
	_log("%s arremessou %s em %s" % [TURN_QUEUE[active_index]["name"], action.label, str(center)], "status")

func _log(text: String, type: String = "system") -> void:
	combat_log.push_front({"text": text, "type": type})
	if combat_log.size() > 60:
		combat_log.resize(60)

# ── Concentração de spells (BG3) ─────────────────────────────────────────────
# Um caster só concentra em um spell por vez. Lançar outro spell de concentração
# cancela o anterior; tomar dano exige CON save; Prone/Stun/Downed quebram auto.
func is_concentrating(idx: int) -> bool:
	return concentration_by_caster.has(idx)

func get_concentration_action(idx: int) -> ActionData:
	return concentration_by_caster.get(idx, {}).get("action", null)

func _start_concentration(caster_idx: int, action: ActionData) -> void:
	if concentration_by_caster.has(caster_idx):
		_break_concentration(caster_idx)
	concentration_by_caster[caster_idx] = {"label": action.label, "action": action}
	_log("%s começa a concentrar em %s." % [TURN_QUEUE[caster_idx]["name"], action.label], "status")

func _break_concentration(idx: int) -> void:
	if not concentration_by_caster.has(idx):
		return
	var data: Dictionary = concentration_by_caster[idx]
	concentration_by_caster.erase(idx)
	if data.get("label", "") == "Nuvem de Adagas":
		var to_remove: Array[Vector2i] = []
		for pos in tile_surfaces:
			if tile_surfaces[pos].get("type", SurfaceType.Type.NONE) == SurfaceType.Type.CLOUD_OF_DAGGERS:
				to_remove.append(pos)
		for pos in to_remove:
			tile_surfaces.erase(pos)
	_log("Concentração de %s foi interrompida!" % TURN_QUEUE[idx]["name"], "status")

# CON save ao tomar dano: CD = max(10, dano/2). Falha quebra a concentração.
func _check_concentration_after_damage(combatant_idx: int, damage: int) -> void:
	if damage <= 0 or not concentration_by_caster.has(combatant_idx):
		return
	var dc: int = maxi(10, damage / 2)
	var fake_action := ActionData.new()
	fake_action.save_attribute = ActionData.DamageAttribute.CON
	var save_result: Dictionary = _resolve_saving_throw(combatant_idx, dc, fake_action)
	if not save_result["saved"]:
		_break_concentration(combatant_idx)
		_log("%s falhou no Save de Concentração (CD %d)!" % [TURN_QUEUE[combatant_idx]["name"], dc], "status")
	else:
		_log("%s manteve a Concentração. (CD %d)" % [TURN_QUEUE[combatant_idx]["name"], dc], "status")

# ── Death Saves / Downed (BG3) ───────────────────────────────────────────────
# Heróis a 0 HP entram em Downed (caído) e rolam 1 Death Save por turno.
# 3 sucessos = estabilizado; 3 falhas = morte. Inimigos morrem na hora.
func is_downed(idx: int) -> bool:
	if idx < 0 or idx >= combatant_statuses.size():
		return false
	return combatant_statuses[idx].get("downed", false)

func _enter_downed(idx: int) -> void:
	combatant_statuses[idx]["downed"] = true
	combatant_statuses[idx]["death_saves_success"] = 0
	combatant_statuses[idx]["death_saves_failure"] = 0
	_break_concentration(idx)
	_log("%s caiu! (Downed)" % TURN_QUEUE[idx]["name"], "status")
	var pos: int = attack_target_indices.find(idx)
	if pos >= 0:
		attack_target_indices.remove_at(pos)
		if attack_cursor_idx >= attack_target_indices.size():
			attack_cursor_idx = maxi(0, attack_target_indices.size() - 1)
	_check_battle_end()

func _remove_downed(idx: int) -> void:
	combatant_statuses[idx].erase("downed")
	combatant_statuses[idx].erase("death_saves_success")
	combatant_statuses[idx].erase("death_saves_failure")
	combatant_statuses[idx].erase("stable")

# Rola 1 Death Save (d20 puro). >=10 sucesso, <=9 falha. Sem nat-20 cura (BG3).
func _process_death_save(idx: int) -> void:
	if combatant_statuses[idx].get("stable", false):
		return
	var roll: int = DiceRoller.roll(1, 20)
	var cname: String = TURN_QUEUE[idx]["name"]
	if roll >= 10:
		combatant_statuses[idx]["death_saves_success"] = \
			combatant_statuses[idx].get("death_saves_success", 0) + 1
		_log("%s Death Save: %d — Sucesso! (%d/3)" % \
			[cname, roll, combatant_statuses[idx]["death_saves_success"]], "system")
	else:
		combatant_statuses[idx]["death_saves_failure"] = \
			combatant_statuses[idx].get("death_saves_failure", 0) + 1
		_log("%s Death Save: %d — Falha! (%d/3)" % \
			[cname, roll, combatant_statuses[idx]["death_saves_failure"]], "status")
	_check_death_saves(idx)

func _check_death_saves(idx: int) -> void:
	var successes: int = combatant_statuses[idx].get("death_saves_success", 0)
	var failures: int  = combatant_statuses[idx].get("death_saves_failure", 0)
	if successes >= 3:
		combatant_statuses[idx]["stable"] = true
		_log("%s se estabilizou!" % TURN_QUEUE[idx]["name"], "system")
	elif failures >= 3:
		_remove_downed(idx)
		dead_indices[idx] = true
		pending_deaths.append(idx)
		battle_stats["player_deaths"] = battle_stats.get("player_deaths", 0) + 1
		_log("%s morreu." % TURN_QUEUE[idx]["name"], "system")
		var pos: int = attack_target_indices.find(idx)
		if pos >= 0:
			attack_target_indices.remove_at(pos)
			if attack_cursor_idx >= attack_target_indices.size():
				attack_cursor_idx = maxi(0, attack_target_indices.size() - 1)
		_check_battle_end()

# Falha automática de Death Save (dano enquanto Downed; crítico = 2 falhas).
func _add_death_save_failure(idx: int, count: int = 1) -> void:
	combatant_statuses[idx]["death_saves_failure"] = \
		combatant_statuses[idx].get("death_saves_failure", 0) + count
	_log("%s sofreu %d falha(s) automática(s) de Death Save!" % \
		[TURN_QUEUE[idx]["name"], count], "status")
	_check_death_saves(idx)

func _on_death(idx: int) -> void:
	# Heróis entram em Downed; inimigos morrem na hora (regra do projeto).
	if TURN_QUEUE[idx].get("is_player", false):
		if is_downed(idx):
			_add_death_save_failure(idx, 1)  # dano extra enquanto já caído
		else:
			_enter_downed(idx)
		return
	# Morte instantânea de inimigo (comportamento original).
	dead_indices[idx] = true
	pending_deaths.append(idx)
	_log("%s foi derrotado!" % TURN_QUEUE[idx]["name"], "system")
	battle_stats["enemy_deaths"] = battle_stats.get("enemy_deaths", 0) + 1
	var pos: int = attack_target_indices.find(idx)
	if pos >= 0:
		attack_target_indices.remove_at(pos)
		if attack_cursor_idx >= attack_target_indices.size():
			attack_cursor_idx = maxi(0, attack_target_indices.size() - 1)
	_check_battle_end()

func _check_battle_end() -> void:
	var living_players := 0
	var living_enemies := 0
	for i in range(TURN_QUEUE.size()):
		if dead_indices.has(i):
			continue
		if TURN_QUEUE[i]["is_player"]:
			# Heróis Downed não contam como vivos para o fim de combate.
			if not is_downed(i):
				living_players += 1
		else:
			living_enemies += 1
	if living_enemies == 0:
		battle_result = "win"
	elif living_players == 0:
		battle_result = "lose"

func _roll_enemy_action() -> void:
	var enemy := get_active_combatant()
	var enemy_type: String = enemy.get("type", "Goblin")
	var edata := ALL_ENEMIES.get(enemy_type, null) as EnemyData
	active_enemy_action_idx = _pick_enemy_action_idx()
	var pool: Array = edata.action_pool if edata != null else ["Attacking %s..."]
	var idx: int = mini(active_enemy_action_idx, pool.size() - 1)
	var action: String = pool[idx]
	if "%s" in action:
		var living: Array = []
		for p in PLAYERS:
			if p["hp"] > 0:
				living.append(p)
		var target: Dictionary = living[randi() % living.size()] if not living.is_empty() else PLAYERS[0]
		action = action % target["name"]
	enemy_action_text = action

func _closest_hero_distance() -> int:
	var origin: Vector2i = combatant_positions[active_index]
	var best := 99999
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"] and not dead_indices.has(i):
			var d := absi(combatant_positions[i].x - origin.x) + absi(combatant_positions[i].y - origin.y)
			if d < best:
				best = d
	return best

func _pick_enemy_action_idx() -> int:
	var enemy := get_active_combatant()
	var enemy_type: String = enemy.get("type", "Goblin")
	var edata := ALL_ENEMIES.get(enemy_type, null) as EnemyData
	if edata == null or edata.action_behaviors.is_empty():
		return 0
	var cur_hp: int  = enemy_hp.get(enemy.get("name", ""), edata.max_hp)
	var hp_ratio: float = float(cur_hp) / float(edata.max_hp)
	var closest: int = _closest_hero_distance()
	var my_status: Dictionary = combatant_statuses[active_index]

	match enemy_type:
		"Goblin":
			if hp_ratio < 0.40:
				return 4  # Fleeing!
		"Orc":
			if hp_ratio < 0.50 and my_status.get("raging", 0) == 0:
				return 4  # Raging!
		"Mage":
			if closest <= 1:
				return randi_range(2, 3)  # Frost Nova
			if hp_ratio < 0.30:
				return 4  # Teleporting
		"EliteWarrior":
			if hp_ratio < 0.50 and my_status.get("raging", 0) == 0:
				return 4  # Enraging!
			if closest <= 1:
				return 2  # Sweeping Strike (AOE)
			if closest == 2:
				return 3  # Charging (stun)
		"EliteMage":
			if closest <= 2:
				return randi_range(2, 3)  # Ice Storm (AOE)
			if hp_ratio < 0.40 and my_status.get("raging", 0) == 0:
				return 4  # Channeling (self-buff)
		"DungeonGuardian":
			if hp_ratio < 0.50 and my_status.get("raging", 0) == 0:
				return 4  # Enraging!
			if closest <= 1:
				return randi_range(2, 3)  # Shockwave (AOE)
			if closest == 2:
				return 5  # Ground Slam (stun)

	return randi() % 2  # fallback: ataque normal (índices 0 ou 1)

func _teleport_enemy() -> void:
	var best_pos  := combatant_positions[active_index]
	var best_dist := 0
	for x in range(grid_cols):
		for y in range(grid_rows):
			var pos := Vector2i(x, y)
			var t: TerrainTile = tile_data_map[x][y]
			if t.is_void() or t.object == TerrainTile.ObjectType.OBSTACLE:
				continue
			if _is_occupied_by_other(pos):
				continue
			var min_hero_dist := 99999
			for i in range(TURN_QUEUE.size()):
				if TURN_QUEUE[i]["is_player"] and not dead_indices.has(i):
					var d := absi(combatant_positions[i].x - pos.x) + absi(combatant_positions[i].y - pos.y)
					if d < min_hero_dist:
						min_hero_dist = d
			if min_hero_dist > best_dist:
				best_dist = min_hero_dist
				best_pos  = pos
	combatant_positions[active_index] = best_pos

func _apply_enemy_self_buff(b: Dictionary) -> void:
	var buff_type: String = b.get("buff_type", "")
	var cname: String     = get_active_combatant().get("name", "?")
	match buff_type:
		"raging":
			combatant_statuses[active_index]["raging"] = b.get("buff_turns", 2)
			context_message = "%s entered a RAGE! +%d damage for %d turns" % [cname, b.get("buff_value", 3), b.get("buff_turns", 2)]
			_log("%s entrou em Fúria! +%d de dano por %d turnos" % [cname, b.get("buff_value", 3), b.get("buff_turns", 2)], "status")
		"teleporting":
			_teleport_enemy()
			context_message = "%s teleported away!" % cname
			_log("%s teleportou!" % cname, "status")

func _apply_enemy_aoe_attack(b: Dictionary) -> Dictionary:
	var origin: Vector2i   = combatant_positions[active_index]
	var radius: int        = b.get("aoe_radius", 1)
	var damage_mult: float = b.get("damage_mult", 1.0)
	var enemy_type: String = get_active_combatant().get("type", "")
	var edata_a    := ALL_ENEMIES.get(enemy_type, null) as EnemyData
	var atk_bonus: int     = edata_a.attack_bonus if edata_a != null else 2
	# AoE auto-acerta (sem rolagem de ataque); usa os dados de dano do inimigo.
	var attack_attr_aoe := edata_a.attack_damage_attribute if edata_a != null else ActionData.DamageAttribute.STR
	var attr_val_aoe: int = 10
	match attack_attr_aoe:
		ActionData.DamageAttribute.DEX: attr_val_aoe = edata_a.dexterity    if edata_a != null else 10
		ActionData.DamageAttribute.INT: attr_val_aoe = edata_a.intelligence if edata_a != null else 10
		ActionData.DamageAttribute.WIS: attr_val_aoe = edata_a.wisdom       if edata_a != null else 10
		_:                              attr_val_aoe = edata_a.strength      if edata_a != null else 10
	var aoe_attr_mod: int = _raw_mod(attr_val_aoe)
	var dice_cnt: int = edata_a.damage_dice_count if edata_a != null else 1
	var dice_s: int   = edata_a.damage_dice_sides if edata_a != null else 6
	var first_target: Vector2i = Vector2i(-1, -1)
	var total_damage := 0
	for i in range(TURN_QUEUE.size()):
		if not TURN_QUEUE[i]["is_player"] or dead_indices.has(i):
			continue
		var dist := king_dist(combatant_positions[i], origin)
		if dist > radius:
			continue
		var damage: int   = maxi(1, int(DiceRoller.roll(dice_cnt, dice_s) * damage_mult) + aoe_attr_mod + atk_bonus)
		var tname: String = TURN_QUEUE[i]["name"]
		var pidx: int     = _player_index_by_name(tname)
		if pidx >= 0:
			PLAYERS[pidx]["hp"] = maxi(0, PLAYERS[pidx]["hp"] - damage)
			_check_concentration_after_damage(i, damage)
			if PLAYERS[pidx]["hp"] <= 0:
				_on_death(i)
		total_damage += damage
		battle_stats["enemy_damage_dealt"] = battle_stats.get("enemy_damage_dealt", 0) + damage
		_register_damage_floater(i, damage, ActionData.damage_type_color(ActionData.DamageType.COLD), "")
		_log("%s acertou %s por %d (AoE)" % [get_active_combatant()["name"], tname, damage], "dmg")
		if b.get("applies_status", "") != "":
			_maybe_apply_stun(i, b.get("status_chance", 0.0), get_active_combatant()["name"])
		if first_target.x < 0:
			first_target = combatant_positions[i]
	context_message = "%s cast Frost Nova!" % get_active_combatant()["name"]
	# Floaters vêm por alvo de pending_surface_hits; sem agregado em last_attack_info
	# (evita desenhar um número errado sobre o próprio inimigo).
	last_attack_info = {}
	if first_target.x >= 0:
		return {"target": first_target, "is_ranged": false,
				"color": Color(0.40, 0.80, 1.00)}
	return {"target": Vector2i(-1, -1)}

func get_tile(col: int, row: int) -> TerrainTile:
	if col < 0 or col >= grid_cols or row < 0 or row >= grid_rows:
		return null
	return tile_data_map[col][row]
