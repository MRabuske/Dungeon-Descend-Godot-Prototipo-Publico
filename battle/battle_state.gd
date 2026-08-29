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

static var PLAYERS: Array = [
	{"name": "Guerreiro", "hp": 80,  "max_hp": 100, "mp": 40,  "max_mp": 80,
	 "class": "Fighter", "level": 4, "ac": 16, "initiative": 8,  "speed": 7, "proficiency": 3},
	{"name": "Mago",      "hp": 60,  "max_hp": 100, "mp": 100, "max_mp": 100,
	 "class": "Wizard",  "level": 4, "ac": 12, "initiative": 5,  "speed": 6, "proficiency": 3},
	{"name": "Arqueiro",  "hp": 70,  "max_hp": 100, "mp": 30,  "max_mp": 60,
	 "class": "Ranger",  "level": 4, "ac": 14, "initiative": 10, "speed": 8, "proficiency": 3},
	{"name": "Clérigo",   "hp": 75,  "max_hp": 100, "mp": 90,  "max_mp": 100,
	 "class": "Cleric",  "level": 4, "ac": 15, "initiative": 6,  "speed": 7, "proficiency": 3},
	{"name": "Ladrao",    "hp": 55,  "max_hp": 100, "mp": 20,  "max_mp": 40,
	 "class": "Rogue",   "level": 4, "ac": 13, "initiative": 9,  "speed": 9, "proficiency": 3},
	{"name": "Bárbaro",  "hp": 95,  "max_hp": 120, "mp": 0,   "max_mp": 0,
	 "class": "Barbarian", "level": 4, "ac": 12, "initiative": 7, "speed": 6, "proficiency": 3},
	{"name": "Paladino",  "hp": 80,  "max_hp": 110, "mp": 40,  "max_mp": 60,
	 "class": "Paladin", "level": 4, "ac": 16, "initiative": 6,  "speed": 6, "proficiency": 3},
	{"name": "Monge",     "hp": 65,  "max_hp": 90,  "mp": 5,   "max_mp": 5,
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

static func reset_players() -> void:
	for p in PLAYERS:
		var hero: HeroData = ALL_HERO_DATA.get(p["name"])
		if hero != null:
			p["hp"] = hero.base_hp
			p["mp"] = hero.base_mp

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

const CRIT_CHANCE := 0.15


var tab_action:      Array[ActionData] = []
var tab_habilidades: Array[ActionData] = []

static var TAB_ITEMS: Array = [
	{"label": "Poção", "shape": 2, "color_idx": 5, "count": 3, "is_item": true, "heal": 30},
	{"label": "Éter",  "shape": 2, "color_idx": 5, "count": 1, "is_item": true, "mp": 40},
]

static var TAB_END_TURN: Array[ActionData] = [
	AcaoEsperar.new(),
	AcaoDefender.new(),
	AcaoFugir.new(),
]

const TAB_LABELS := ["ACTION", "HABILIDADES", "ITEMS"]
const MAX_SLOTS  := 6

var current_state:        State     = State.PLAYER_TURN
var active_index:         int       = 0
var active_tab:           int       = 0
var cursor_position:      int       = 0
var enemy_action_text:         String    = ""
var active_enemy_action_idx:   int       = 0
var has_moved:                 bool      = false
var has_attacked:         bool      = false
var has_used_bonus_action: bool     = false
var fury_extra_attack:    bool      = false
var move_cursor:          Vector2i  = Vector2i(2, 3)
var attack_target_indices: Array[int] = []
var attack_cursor_idx:    int       = 0
var current_attack_range: int       = 0
var current_attack_color: Color     = Color.WHITE
var current_aoe_radius:   int       = 0
var _attack_targets_allies: bool    = false
var _attack_self_target: bool       = false
var _current_attack_is_bonus: bool  = false
var current_damage_attribute: ActionData.DamageAttribute = ActionData.DamageAttribute.NONE
var current_base_dmg_min: int       = 4
var current_base_dmg_max: int       = 8
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
	if TURN_QUEUE.size() > 0 and TURN_QUEUE[0].get("is_player", false):
		_load_hero_actions(TURN_QUEUE[0]["name"])

func setup(map_data) -> void:
	grid_cols = map_data.grid_cols
	grid_rows = map_data.grid_rows
	tile_data_map = map_data.tile_data_map
	hero_spawns = map_data.hero_spawns
	enemy_spawns = map_data.enemy_spawns
	TAB_ITEMS = [
		{"label": "Poção", "shape": 2, "color_idx": 5, "count": 3, "is_item": true, "heal": 30},
		{"label": "Éter",  "shape": 2, "color_idx": 5, "count": 1, "is_item": true, "mp": 40},
	]
	dead_indices.clear()
	battle_result = ""
	combatant_statuses.clear()
	for _i in range(TURN_QUEUE.size()):
		combatant_statuses.append({})
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i].get("is_player", false):
			var pname: String = TURN_QUEUE[i]["name"]
			var hdata := ALL_HERO_DATA.get(pname, null) as HeroData
			if hdata != null and hdata.hero_class == "Rogue":
				combatant_statuses[i]["furtivo"] = 1
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

func _load_hero_actions(player_name: String) -> void:
	var hdata: HeroData = ALL_HERO_DATA.get(player_name, null)
	if hdata == null:
		return
	tab_action = []
	for a in hdata.actions:
		tab_action.append(a.duplicate())
	tab_habilidades = []
	for s in hdata.skills:
		tab_habilidades.append(s.duplicate())

func is_item_available(item) -> bool:
	if item is ActionData:
		var action := item as ActionData
		if action.action_type == ActionData.Type.ATTACK:
			if action.bonus_action:
				if has_used_bonus_action:
					return false
			elif has_attacked:
				return fury_extra_attack
		if action.action_type == ActionData.Type.MOVE and has_moved:
			return false
		if action.mp_cost > 0:
			var pidx := get_active_player_index()
			if pidx >= 0 and PLAYERS[pidx]["mp"] < action.mp_cost:
				return false
		if action.max_pp > 0 and action.pp <= 0:
			return false
		return true
	if item is Dictionary:
		return item.get("count", 0) > 0
	return false

func consume_spell_mp(cost: int) -> void:
	var pidx := get_active_player_index()
	if pidx >= 0 and cost > 0:
		PLAYERS[pidx]["mp"] = maxi(0, PLAYERS[pidx]["mp"] - cost)

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
			var poison_dmg := 5
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
			context_message = TURN_QUEUE[next]["name"] + " took 5 poison damage!"
			_log("%s recebeu 5 de dano de veneno" % TURN_QUEUE[next]["name"], "status")
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
		break
	# Decrementar buffs que duram N turnos do próprio combatente
	var next_status: Dictionary = combatant_statuses[next]
	if next_status.get("defending", 0) > 0:
		next_status["defending"] -= 1
	if next_status.get("raging", 0) > 0:
		next_status["raging"] -= 1
	if next_status.get("aiming", 0) > 0:
		next_status["aiming"] -= 1
	active_index = next
	active_tab = 0
	cursor_position = 0
	has_moved = false
	has_attacked = false
	has_used_bonus_action = false
	fury_extra_attack = false
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
	if current_state != State.PLAYER_TURN or has_moved:
		return
	move_cursor = combatant_positions[active_index]
	current_state = State.MOVE_MODE

func move_cursor_grid(delta: Vector2i) -> void:
	var new_pos := move_cursor + delta
	new_pos.x = clampi(new_pos.x, 0, grid_cols - 1)
	new_pos.y = clampi(new_pos.y, 0, grid_rows - 1)
	if not get_reachable_tiles().has(new_pos):
		return
	move_cursor = new_pos

func confirm_move() -> void:
	_undo_move_pos = combatant_positions[active_index]
	combatant_positions[active_index] = move_cursor
	has_moved = true
	current_state = State.PLAYER_TURN

func activate_trap_after_move(combatant_idx: int, pos: Vector2i) -> void:
	_check_trap(combatant_idx, pos)

func cancel_confirmed_move() -> bool:
	if not has_moved:
		return false
	combatant_positions[active_index] = _undo_move_pos
	has_moved = false
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
		if TURN_QUEUE[combatant_idx]["is_player"]:
			var pidx := get_active_player_index()
			if pidx >= 0:
				PLAYERS[pidx]["hp"] = maxi(0, PLAYERS[pidx]["hp"] - 5)
				if PLAYERS[pidx]["hp"] <= 0:
					_on_death(combatant_idx)
		else:
			var new_hp: int = maxi(0, enemy_hp.get(cname, 30) - 5)
			enemy_hp[cname] = new_hp
			if new_hp <= 0:
				_on_death(combatant_idx)
		context_message = cname + " triggered a trap! -5 HP"
		_log("%s ativou uma armadilha! -5 HP e envenenado" % cname, "status")
		combatant_statuses[combatant_idx]["poison"] = 3

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
	var player_idx := get_active_player_index()
	var spd: int = PLAYERS[player_idx]["speed"] if player_idx >= 0 else 0
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
			result[pos] = true
	return result


var dead_indices: Dictionary = {}
var battle_result: String = ""
var last_attack_info: Dictionary = {}
var combatant_statuses: Array = []
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

	if _enemy_action_is_self():
		return []

	var target := origin
	var best_dist := 99999
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"] and not dead_indices.has(i):
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
	if "arrow" in enemy_action_text or "Aiming" in enemy_action_text:
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
	if my_status.get("aiming", 0) > 0:
		attack_range += 2
	if attack_range > 1 and _tile_at(active_index) == MapGenerator.TileType.ELEVATED:
		attack_range += 1

	var origin: Vector2i = combatant_positions[active_index]
	var target_idx := -1
	var best_hp    := 99999
	var pidx: int
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"] and not dead_indices.has(i):
			var d: int = absi(combatant_positions[i].x - origin.x) + absi(combatant_positions[i].y - origin.y)
			if d <= attack_range:
				if attack_range == 1 or _has_los(origin, combatant_positions[i]):
					pidx = _player_index_by_name(TURN_QUEUE[i]["name"])
					var phpi: int = PLAYERS[pidx]["hp"] if pidx >= 0 else 99999
					if phpi < best_hp:
						best_hp    = phpi
						target_idx = i
	if target_idx == -1:
		return {"target": Vector2i(-1, -1)}
	var target_tile: int = _tile_at(target_idx)
	var is_aiming: bool  = my_status.get("aiming", 0) > 0
	if is_aiming:
		my_status.erase("aiming")

	if target_tile == MapGenerator.TileType.COVER and not is_aiming and randf() < 0.30:
		last_attack_info = {"amount": 0, "is_heal": false, "target_idx": target_idx}
		context_message = "%s attacked %s but missed! (COVER)" % [get_active_combatant()["name"], TURN_QUEUE[target_idx]["name"]]
		_log("%s atacou %s mas errou (Cobertura)" % [get_active_combatant()["name"], TURN_QUEUE[target_idx]["name"]], "miss")
		return {"target": combatant_positions[target_idx], "is_ranged": attack_range > 1, "color": _get_enemy_projectile_color()}

	var target_status: Dictionary = combatant_statuses[target_idx]
	if target_status.get("defending", 0) > 0 and randf() < 0.40:
		last_attack_info = {"amount": 0, "is_heal": false, "target_idx": target_idx}
		context_message = "%s attacked %s but was blocked! (DEFENDING)" % [get_active_combatant()["name"], TURN_QUEUE[target_idx]["name"]]
		_log("%s atacou %s mas foi bloqueado (Defender)" % [get_active_combatant()["name"], TURN_QUEUE[target_idx]["name"]], "miss")
		return {"target": combatant_positions[target_idx], "is_ranged": attack_range > 1, "color": _get_enemy_projectile_color()}

	var enemy_type_atk: String = get_active_combatant().get("type", "")
	var edata_atk := ALL_ENEMIES.get(enemy_type_atk, null) as EnemyData
	var atk_bonus: int     = edata_atk.attack_bonus if edata_atk != null else 2
	var damage_mult: float = b.get("damage_mult", 1.0)
	var raging_bonus: int  = 3 if my_status.get("raging", 0) > 0 else 0
	var damage: int        = maxi(1, int(randi_range(5, 12) * damage_mult) + atk_bonus + raging_bonus)

	var target_name: String = TURN_QUEUE[target_idx]["name"]
	pidx           = _player_index_by_name(target_name)
	if pidx >= 0:
		var tdata := ALL_HERO_DATA.get(target_name, null) as HeroData
		if tdata != null and tdata.damage_reduction > 0:
			var reduction: int = 2 if combatant_statuses[target_idx].get("fury", 0) > 0 else tdata.damage_reduction
			damage = maxi(1, damage - reduction)
		var def_bonus: int = PLAYERS[pidx].get("bonus_def", 0)
		if def_bonus > 0:
			damage = maxi(1, damage - def_bonus)
	battle_stats["enemy_damage_dealt"] = battle_stats.get("enemy_damage_dealt", 0) + damage
	if pidx >= 0:
		PLAYERS[pidx]["hp"] = maxi(0, PLAYERS[pidx]["hp"] - damage)
		if PLAYERS[pidx]["hp"] <= 0:
			_on_death(target_idx)
	last_attack_info = {"amount": damage, "is_heal": false, "target_idx": target_idx, "is_crit": false}
	context_message = "%s hit %s for %d damage!" % [get_active_combatant()["name"], target_name, damage]
	_log("%s acertou %s por %d de dano" % [get_active_combatant()["name"], target_name, damage], "dmg")

	if b.get("applies_status", "") != "" and randf() < b.get("status_chance", 0.0):
		combatant_statuses[target_idx]["stun"] = 1
		context_message += " " + target_name + " is stunned!"
		_log("%s foi atordoado!" % target_name, "status")

	return {
		"target": combatant_positions[target_idx],
		"is_ranged": attack_range > 1,
		"color": _get_enemy_projectile_color(),
	}

func apply_enemy_move(path: Array[Vector2i]) -> void:
	if path.is_empty():
		return
	combatant_positions[active_index] = path[-1]

func apply_defender_action(player_idx: int) -> void:
	if player_idx < 0 or player_idx >= PLAYERS.size():
		return
	var pname: String = PLAYERS[player_idx]["name"]
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"] and TURN_QUEUE[i]["name"] == pname:
			combatant_statuses[i]["defending"] = 1
			break
	_log("%s está se defendendo (+2 AC)" % pname, "status")

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

func apply_smite_status(player_idx: int) -> void:
	if player_idx < 0 or player_idx >= PLAYERS.size():
		return
	var pname: String = PLAYERS[player_idx]["name"]
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"] and TURN_QUEUE[i]["name"] == pname:
			combatant_statuses[i]["smite"] = 1
			_log("Paladino ativa Smite Divino!", "status")
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
				if t.object == TerrainTile.ObjectType.OBSTACLE:
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
	if attack_target_indices.is_empty():
		return Vector2i.ZERO
	return combatant_positions[attack_target_indices[attack_cursor_idx]]

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
			var d: int = absi(col - origin.x) + absi(row - origin.y)
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
		var d: int = absi(combatant_positions[i].x - origin.x) + absi(combatant_positions[i].y - origin.y)
		if d <= effective_range:
			if effective_range == 1 or _has_los(origin, combatant_positions[i]):
				attack_target_indices.append(i)
	attack_cursor_idx = 0
	current_attack_range = effective_range
	current_attack_color = proj_color
	current_state = State.ATTACK_MODE

func cycle_attack_target(delta: int) -> void:
	if attack_target_indices.is_empty():
		return
	attack_cursor_idx = (attack_cursor_idx + delta + attack_target_indices.size()) % attack_target_indices.size()

func confirm_attack() -> void:
	if attack_target_indices.is_empty():
		current_state = State.PLAYER_TURN
		return
	var target_idx: int = attack_target_indices[attack_cursor_idx]
	_apply_attack(target_idx)
	if has_attacked:
		fury_extra_attack = false
	has_attacked = true
	if _current_attack_is_bonus:
		has_used_bonus_action = true
	_current_attack_is_bonus = false
	current_state = State.PLAYER_TURN
	attack_target_indices.clear()
	current_attack_range = 0
	current_aoe_radius = 0

func cancel_attack() -> void:
	current_state = State.PLAYER_TURN
	attack_target_indices.clear()
	current_attack_range = 0
	current_aoe_radius = 0

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
	elif item.has("mp"):
		var before: int = PLAYERS[pidx]["mp"]
		PLAYERS[pidx]["mp"] = mini(PLAYERS[pidx]["max_mp"], before + item["mp"])
		var actual: int = PLAYERS[pidx]["mp"] - before
		last_attack_info = {"amount": actual, "is_heal": true, "target_idx": active_index}
		context_message = "%s usou %s! +%d MP" % [pname, item["label"], actual]
		_log("%s usou %s (+%d MP)" % [pname, item["label"], actual], "heal")

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

func _roll_player_damage() -> int:
	var pidx  := get_active_player_index()
	var prof: int  = PLAYERS[pidx]["proficiency"] if pidx >= 0 else 2
	var bonus: int = PLAYERS[pidx].get("bonus_atk", 0) if pidx >= 0 else 0
	var modifier   := _get_attr_modifier(current_damage_attribute)
	return randi_range(current_base_dmg_min, current_base_dmg_max) + modifier + prof + bonus

func get_damage_range(action: ActionData) -> Vector2i:
	var pidx := get_active_player_index()
	if pidx < 0 or action.base_damage_max == 0:
		return Vector2i(action.base_damage_min, action.base_damage_max)
	var p: Dictionary = PLAYERS[pidx]
	var prof: int = p.get("proficiency", 2)
	var val: int
	match action.damage_attribute:
		ActionData.DamageAttribute.STR: val = p.get("strength",     10)
		ActionData.DamageAttribute.DEX: val = p.get("dexterity",    10)
		ActionData.DamageAttribute.INT: val = p.get("intelligence", 10)
		ActionData.DamageAttribute.WIS: val = p.get("wisdom",       10)
		_: val = 10
	var mod: int = int((val - 10) / 2.0)
	return Vector2i(
		action.base_damage_min + mod + prof,
		action.base_damage_max + mod + prof
	)

func _apply_attack(target_idx: int) -> void:
	var attacker: String = get_active_combatant()["name"]
	var target_name: String = TURN_QUEUE[target_idx]["name"]
	last_attack_info.clear()
	if _attack_targets_allies:
		var pidx: int = _player_index_by_name(target_name)
		var hp_before: int = PLAYERS[pidx]["hp"] if pidx >= 0 else 0
		_undo_attack_info = {"target_idx": target_idx, "hp_before": hp_before}
		var heal: int = _roll_player_damage()
		if pidx >= 0:
			PLAYERS[pidx]["hp"] = mini(PLAYERS[pidx]["max_hp"], PLAYERS[pidx]["hp"] + heal)
		last_attack_info = {"amount": heal, "is_heal": true, "target_idx": target_idx}
		context_message = "%s healed %s for %d HP!" % [attacker, target_name, heal]
		_log("%s curou %s em %d HP" % [attacker, target_name, heal], "heal")
	else:
		if _tile_at(target_idx) == TerrainTile.ObjectType.COVER and randf() < 0.30:
			last_attack_info = {"amount": 0, "is_heal": false, "target_idx": target_idx}
			var hp_before: int
			if TURN_QUEUE[target_idx]["is_player"]:
				var pidx: int = _player_index_by_name(target_name)
				hp_before = PLAYERS[pidx]["hp"] if pidx >= 0 else 0
			else:
				hp_before = enemy_hp.get(target_name, 0)
			_undo_attack_info = {"target_idx": target_idx, "hp_before": hp_before}
			context_message = "%s attacked %s but missed! (COVER)" % [attacker, target_name]
			_log("%s atacou %s mas errou (Cobertura)" % [attacker, target_name], "miss")
			return
		var is_crit: bool = randf() < CRIT_CHANCE
		var damage: int = _roll_player_damage()
		if is_crit:
			damage *= 2
			battle_stats["crits"] = battle_stats.get("crits", 0) + 1
		if combatant_statuses[active_index].get("furtivo", 0) > 0:
			var sneak_bonus: int = randi_range(3, 8)
			combatant_statuses[active_index].erase("furtivo")
			_log("%s usa Ataque Furtivo! +%d dano" % [get_active_combatant()["name"], sneak_bonus], "status")
			damage += sneak_bonus
		if combatant_statuses[active_index].get("fury", 0) > 0:
			damage += 4
		if combatant_statuses[active_index].get("smite", 0) > 0:
			var smite_bonus: int = randi_range(8, 16)
			combatant_statuses[active_index].erase("smite")
			_log("%s aplica Smite Divino! +%d dano" % [get_active_combatant()["name"], smite_bonus], "status")
			damage += smite_bonus
		battle_stats["player_damage_dealt"] = battle_stats.get("player_damage_dealt", 0) + damage
		if TURN_QUEUE[target_idx]["is_player"]:
			var pidx: int = _player_index_by_name(target_name)
			var hp_before: int = PLAYERS[pidx]["hp"] if pidx >= 0 else 0
			_undo_attack_info = {"target_idx": target_idx, "hp_before": hp_before}
			if pidx >= 0:
				PLAYERS[pidx]["hp"] = maxi(0, PLAYERS[pidx]["hp"] - damage)
				if PLAYERS[pidx]["hp"] <= 0:
					_on_death(target_idx)
		else:
			var hp_before: int = enemy_hp.get(target_name, 0)
			_undo_attack_info = {"target_idx": target_idx, "hp_before": hp_before}
			var new_hp: int = maxi(0, hp_before - damage)
			enemy_hp[target_name] = new_hp
			if new_hp <= 0:
				_on_death(target_idx)
		last_attack_info = {"amount": damage, "is_heal": false, "target_idx": target_idx, "is_crit": is_crit}
		if is_crit:
			context_message = "CRITICO! %s acertou %s por %d de dano!" % [attacker, target_name, damage]
			_log("CRITICO! %s acertou %s por %d de dano" % [attacker, target_name, damage], "crit")
		else:
			context_message = "%s hit %s for %d damage!" % [attacker, target_name, damage]
			_log("%s acertou %s por %d de dano" % [attacker, target_name, damage], "dmg")
		if current_attack_range == 1 and not _attack_targets_allies and randf() < 0.20:
			combatant_statuses[target_idx]["stun"] = 1
			context_message += " " + target_name + " is stunned!"
			_log("%s foi atordoado!" % target_name, "status")
		if current_aoe_radius > 0:
			_apply_aoe_splash(target_idx, int(damage / 2.0))

func _apply_aoe_splash(primary_idx: int, splash_damage: int) -> void:
	var primary_pos: Vector2i = combatant_positions[primary_idx]
	var splash_hits: Array[int] = []
	for i in range(TURN_QUEUE.size()):
		if i == active_index or i == primary_idx or dead_indices.has(i):
			continue
		var is_ally: bool = TURN_QUEUE[i]["is_player"]
		if is_ally == _attack_targets_allies:
			continue
		var d: int = absi(combatant_positions[i].x - primary_pos.x) + absi(combatant_positions[i].y - primary_pos.y)
		if d <= current_aoe_radius:
			splash_hits.append(i)
	for i in splash_hits:
		var sname: String = TURN_QUEUE[i]["name"]
		battle_stats["player_damage_dealt"] = battle_stats.get("player_damage_dealt", 0) + splash_damage
		if TURN_QUEUE[i]["is_player"]:
			var pidx: int = _player_index_by_name(sname)
			if pidx >= 0:
				PLAYERS[pidx]["hp"] = maxi(0, PLAYERS[pidx]["hp"] - splash_damage)
				if PLAYERS[pidx]["hp"] <= 0:
					_on_death(i)
		else:
			var new_hp: int = maxi(0, enemy_hp.get(sname, 0) - splash_damage)
			enemy_hp[sname] = new_hp
			if new_hp <= 0:
				_on_death(i)
		_log("AoE acertou %s por %d de dano" % [sname, splash_damage], "dmg")

func get_enemy_max_hp(idx: int) -> int:
	var enemy_type: String = TURN_QUEUE[idx].get("type", "")
	var edata := ALL_ENEMIES.get(enemy_type, null) as EnemyData
	return edata.max_hp if edata != null else 30

func get_active_status_text(idx: int) -> String:
	if idx < 0 or idx >= combatant_statuses.size():
		return ""
	var status: Dictionary = combatant_statuses[idx]
	var parts: Array[String] = []
	if status.get("poison",    0) > 0: parts.append("Veneno(%d)"   % status["poison"])
	if status.get("stun",      0) > 0: parts.append("Atordoado")
	if status.get("defending", 0) > 0: parts.append("Defender +2 AC")
	if status.get("raging",    0) > 0: parts.append("Fúria +3 dano")
	if status.get("aiming",    0) > 0: parts.append("Mirando +2 alc")
	if status.get("fury",      0) > 0: parts.append("Fúria +4 dano")
	if status.get("smite",     0) > 0: parts.append("Smite +8-16 dano")
	return "  ".join(parts)

func _log(text: String, type: String = "system") -> void:
	combat_log.push_front({"text": text, "type": type})
	if combat_log.size() > 60:
		combat_log.resize(60)

func _on_death(idx: int) -> void:
	dead_indices[idx] = true
	pending_deaths.append(idx)
	_log("%s foi derrotado!" % TURN_QUEUE[idx]["name"], "system")
	if TURN_QUEUE[idx]["is_player"]:
		battle_stats["player_deaths"] = battle_stats.get("player_deaths", 0) + 1
	else:
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
		"Undead":
			if closest > 3 and my_status.get("aiming", 0) == 0:
				return randi_range(2, 3)  # Aiming
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
		"aiming":
			combatant_statuses[active_index]["aiming"] = b.get("buff_turns", 1)
			context_message = "%s is Aiming! +%d range next attack" % [cname, b.get("buff_value", 2)]
			_log("%s está mirando! +%d de alcance no próximo ataque" % [cname, b.get("buff_value", 2)], "status")
		"teleporting":
			_teleport_enemy()
			context_message = "%s teleported away!" % cname
			_log("%s teleportou!" % cname, "status")
		"rattling":
			context_message = "%s rattles its bones..." % cname
			_log("%s chacoalha os ossos..." % cname, "status")

func _apply_enemy_aoe_attack(b: Dictionary) -> Dictionary:
	var origin: Vector2i   = combatant_positions[active_index]
	var radius: int        = b.get("aoe_radius", 1)
	var damage_mult: float = b.get("damage_mult", 1.0)
	var enemy_type: String = get_active_combatant().get("type", "")
	var edata_a    := ALL_ENEMIES.get(enemy_type, null) as EnemyData
	var atk_bonus: int     = edata_a.attack_bonus if edata_a != null else 2
	var first_target: Vector2i = Vector2i(-1, -1)
	var total_damage := 0
	for i in range(TURN_QUEUE.size()):
		if not TURN_QUEUE[i]["is_player"] or dead_indices.has(i):
			continue
		var dist := absi(combatant_positions[i].x - origin.x) + absi(combatant_positions[i].y - origin.y)
		if dist > radius:
			continue
		var damage: int   = maxi(1, int(randi_range(5, 12) * damage_mult) + atk_bonus)
		var tname: String = TURN_QUEUE[i]["name"]
		var pidx: int     = _player_index_by_name(tname)
		if pidx >= 0:
			PLAYERS[pidx]["hp"] = maxi(0, PLAYERS[pidx]["hp"] - damage)
			if PLAYERS[pidx]["hp"] <= 0:
				_on_death(i)
		total_damage += damage
		battle_stats["enemy_damage_dealt"] = battle_stats.get("enemy_damage_dealt", 0) + damage
		_log("%s acertou %s por %d (AoE)" % [get_active_combatant()["name"], tname, damage], "dmg")
		if b.get("applies_status", "") != "" and randf() < b.get("status_chance", 0.0):
			combatant_statuses[i]["stun"] = 1
			_log("%s foi atordoado!" % tname, "status")
		if first_target.x < 0:
			first_target = combatant_positions[i]
	context_message = "%s cast Frost Nova!" % get_active_combatant()["name"]
	last_attack_info = {"amount": total_damage, "is_heal": false,
						"target_idx": active_index, "is_crit": false}
	if first_target.x >= 0:
		return {"target": first_target, "is_ranged": false,
				"color": Color(0.40, 0.80, 1.00)}
	return {"target": Vector2i(-1, -1)}

func get_tile(col: int, row: int) -> TerrainTile:
	if col < 0 or col >= grid_cols or row < 0 or row >= grid_rows:
		return null
	return tile_data_map[col][row]
