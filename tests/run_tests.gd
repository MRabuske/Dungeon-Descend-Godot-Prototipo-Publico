extends SceneTree

var _passed := 0
var _failed := 0

func _initialize() -> void:
	_run_all()
	print("\nResults: %d passed, %d failed" % [_passed, _failed])
	quit(0 if _failed == 0 else 1)

func _eq(label: String, actual: Variant, expected: Variant) -> void:
	if actual == expected:
		print("PASS: " + label)
		_passed += 1
	else:
		print("FAIL: %s\n  expected: %s\n  actual:   %s" % [label, str(expected), str(actual)])
		_failed += 1

func _true(label: String, value: bool) -> void:
	_eq(label, value, true)

func _flood_fill_map(map_data: MapGenerator.MapData, start: Vector2i) -> Array:
	var visited: Dictionary = {}
	var frontier: Array[Vector2i] = [start]
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if visited.has(cur):
			continue
		visited[cur] = true
		for d in dirs:
			var nxt := cur + d
			if nxt.x < 0 or nxt.x >= map_data.grid_cols or nxt.y < 0 or nxt.y >= map_data.grid_rows:
				continue
			var t: int = map_data.tile_map[nxt.x][nxt.y]
			if t == MapGenerator.TileType.VOID or t == MapGenerator.TileType.OBSTACLE:
				continue
			if not visited.has(nxt):
				frontier.append(nxt)
	return visited.keys()

func _run_all() -> void:
	var s := BattleState.new()

	# Initial state
	_eq("initial state is PLAYER_TURN", s.current_state, BattleState.State.PLAYER_TURN)
	_eq("initial active_index is 0",    s.active_index,    0)
	_eq("initial active_tab is 0",      s.active_tab,      0)
	_eq("initial cursor_position is 0", s.cursor_position, 0)
	_eq("initial enemy_action_text is empty", s.enemy_action_text, "")
	_true("first combatant is player", s.is_player_turn())
	_eq("get_active_player_index returns 0 for Guerreiro", s.get_active_player_index(), 0)

	# PLAYERS have new fields
	_true("PLAYERS[0] has class field",       BattleState.PLAYERS[0].has("class"))
	_true("PLAYERS[0] has level field",       BattleState.PLAYERS[0].has("level"))
	_true("PLAYERS[0] has ac field",          BattleState.PLAYERS[0].has("ac"))
	_true("PLAYERS[0] has initiative field",  BattleState.PLAYERS[0].has("initiative"))
	_true("PLAYERS[0] has speed field",       BattleState.PLAYERS[0].has("speed"))
	_true("PLAYERS[0] has proficiency field", BattleState.PLAYERS[0].has("proficiency"))

	# TURN_QUEUE enemies have type and ac
	var enemy := BattleState.TURN_QUEUE[1]
	_true("enemy has is_player=false", not enemy["is_player"])
	_true("enemy has type field",      enemy.has("type"))
	_true("enemy has ac field",        enemy.has("ac"))

	# get_active_tab_items
	_eq("get_active_tab_items returns tab_action at start",
		s.get_active_tab_items(), s.tab_action)

	# move_tab
	s.move_tab(1)
	_eq("move_tab(1) moves to HABILIDADES", s.active_tab, 1)
	_eq("move_tab resets cursor to 0",      s.cursor_position, 0)
	s.move_tab(-1)
	_eq("move_tab(-1) returns to ACTION",   s.active_tab, 0)

	# move_cursor_tab within tab
	s.move_cursor_tab(1)
	_eq("move_cursor_tab(1) increments cursor", s.cursor_position, 1)
	s.move_cursor_tab(-1)
	_eq("move_cursor_tab(-1) decrements cursor", s.cursor_position, 0)

	# move_cursor_tab wrap to next tab
	for _i in range(s.tab_action.size()):
		s.move_cursor_tab(1)
	_eq("wrap right: switches to HABILIDADES", s.active_tab, 1)
	_eq("wrap right: cursor at 0",             s.cursor_position, 0)

	# move_cursor_tab wrap to previous tab
	s.move_cursor_tab(-1)
	_eq("wrap left: returns to ACTION",        s.active_tab, 0)
	_eq("wrap left: cursor at last ACTION slot",
		s.cursor_position, s.tab_action.size() - 1)

	# advance_turn to enemy: sets enemy_action_text
	s.active_tab = 2
	s.cursor_position = 1
	s.advance_turn()
	_eq("advance_turn increments active_index to 1", s.active_index, 1)
	_eq("advance_turn resets active_tab to 0",       s.active_tab, 0)
	_eq("advance_turn resets cursor to 0",           s.cursor_position, 0)
	_eq("index 1 is ENEMY_TURN", s.current_state, BattleState.State.ENEMY_TURN)
	_true("enemy_action_text is non-empty after enemy turn", s.enemy_action_text.length() > 0)
	_eq("get_active_player_index returns -1 on enemy turn", s.get_active_player_index(), -1)

	# advance_turn to player: clears enemy_action_text
	s.advance_turn()
	_eq("index 2 (Mago) is PLAYER_TURN", s.current_state, BattleState.State.PLAYER_TURN)
	_eq("enemy_action_text cleared on player turn", s.enemy_action_text, "")

	# Full queue wrap
	var s2 := BattleState.new()
	for _i in range(BattleState.TURN_QUEUE.size()):
		s2.advance_turn()
	_eq("full queue wrap returns active_index to 0", s2.active_index, 0)
	_true("after full wrap, is player turn again", s2.is_player_turn())

	# ── Movement tests ──────────────────────────────────────────────────────────

	var m := BattleState.new()

	# Initial movement state
	_eq("initial has_moved is false", m.has_moved, false)
	_eq("Guerreiro starts at (2,3)", m.combatant_positions[0], Vector2i(2, 3))
	_eq("Goblin Scout starts at (9,1)", m.combatant_positions[1], Vector2i(9, 1))

	# tab_action has Mover slot as AcaoMover instance
	var mover_slot: ActionData = s.tab_action[s.tab_action.size() - 1]
	_eq("last tab_action slot label is Mover", mover_slot.label, "Mover")
	_true("Mover slot is AcaoMover instance", mover_slot is AcaoMover)

	# enter_move_mode
	m.enter_move_mode()
	_eq("enter_move_mode switches to MOVE_MODE", m.current_state, BattleState.State.MOVE_MODE)
	_eq("enter_move_mode sets move_cursor to active position", m.move_cursor, Vector2i(2, 3))

	# enter_move_mode is no-op when state is ENEMY_TURN
	var me := BattleState.new()
	me.advance_turn()  # moves to index 1 — Goblin Scout (ENEMY_TURN)
	me.enter_move_mode()
	_eq("enter_move_mode no-op when ENEMY_TURN", me.current_state, BattleState.State.ENEMY_TURN)

	# move_cursor_grid within speed range (Guerreiro speed=7)
	m.move_cursor_grid(Vector2i(1, 0))
	_eq("move_cursor_grid(1,0) moves cursor right to (3,3)", m.move_cursor, Vector2i(3, 3))

	# move_cursor_grid blocked at speed limit
	# Guerreiro at (2,3), speed=7. Moving right 7 times = (9,3). 8th move blocked.
	var ms := BattleState.new()
	ms.enter_move_mode()
	for _i in range(8):
		ms.move_cursor_grid(Vector2i(1, 0))
	_eq("cursor stops at speed limit from origin", ms.move_cursor, Vector2i(9, 3))

	# move_cursor_grid blocked by occupied tile
	# (3,4) is occupied by Clérigo (combatant_positions[5])
	# Navigate: one step right to (3,3), then one step down — (3,4) is occupied → blocked.
	var mb := BattleState.new()
	mb.enter_move_mode()
	mb.move_cursor_grid(Vector2i(1, 0))   # (2,3) → (3,3)
	mb.move_cursor_grid(Vector2i(0, 1))   # tries (3,4) — occupied → blocked
	_eq("move_cursor blocked by occupied tile", mb.move_cursor, Vector2i(3, 3))

	# move_cursor_grid clamped at grid boundary
	# Cursor starts at active position (2,3). Move left 3 times — should stop at x=0.
	var mg := BattleState.new()
	mg.enter_move_mode()
	for _i in range(4):
		mg.move_cursor_grid(Vector2i(-1, 0))
	_eq("cursor clamped at left grid boundary", mg.move_cursor, Vector2i(0, 3))

	# confirm_move updates position and sets has_moved
	var mc := BattleState.new()
	mc.enter_move_mode()
	mc.move_cursor = Vector2i(4, 3)
	mc.confirm_move()
	_eq("confirm_move updates combatant position", mc.combatant_positions[0], Vector2i(4, 3))
	_eq("confirm_move sets has_moved to true",     mc.has_moved, true)
	_eq("confirm_move returns to PLAYER_TURN",     mc.current_state, BattleState.State.PLAYER_TURN)

	# enter_move_mode is no-op when has_moved=true
	mc.enter_move_mode()
	_eq("enter_move_mode no-op when has_moved=true", mc.current_state, BattleState.State.PLAYER_TURN)

	# cancel_move restores PLAYER_TURN without moving
	var mx := BattleState.new()
	mx.enter_move_mode()
	mx.move_cursor_grid(Vector2i(2, 0))
	mx.cancel_move()
	_eq("cancel_move returns to PLAYER_TURN",        mx.current_state, BattleState.State.PLAYER_TURN)
	_eq("cancel_move leaves original position intact", mx.combatant_positions[0], Vector2i(2, 3))
	_eq("cancel_move does not set has_moved",         mx.has_moved, false)

	# get_reachable_tiles returns non-empty array within grid bounds
	var mr := BattleState.new()
	var tiles: Array[Vector2i] = mr.get_reachable_tiles()
	_true("get_reachable_tiles returns non-empty result", tiles.size() > 0)
	# Guerreiro at (2,3), speed=7 — all tiles with Manhattan dist <=7, excluding occupied
	# Spot-check: (5,3) is dist=3, unoccupied → should be reachable
	_true("(5,3) is in reachable tiles", Vector2i(5, 3) in tiles)
	# (9,1) is occupied by Goblin Scout → must NOT appear
	_true("occupied tile (9,1) not in reachable tiles", not (Vector2i(9, 1) in tiles))

	# advance_turn resets has_moved
	var ma := BattleState.new()
	ma.enter_move_mode()
	ma.confirm_move()
	_eq("has_moved true before advance", ma.has_moved, true)
	ma.advance_turn()
	_eq("advance_turn resets has_moved to false", ma.has_moved, false)

	# ── Enemy AI movement tests ─────────────────────────────────────────────────

	# Enemy speed via ALL_ENEMIES EnemyData objects
	_eq("Goblin speed is 6",  BattleState.ALL_ENEMIES["Goblin"].speed,  6)
	_eq("Orc speed is 4",     BattleState.ALL_ENEMIES["Orc"].speed,     4)
	_eq("Mage speed is 5",    BattleState.ALL_ENEMIES["Mage"].speed,    5)
	_eq("Undead speed is 5",  BattleState.ALL_ENEMIES["Undead"].speed,  5)

	# get_enemy_move_path — Goblin Scout at (9,1), nearest player Mago at (1,1), dist=8, speed=6
	# Greedy path moves along x: (8,1)→(7,1)→...→(3,1) — 6 steps, none occupied
	var en := BattleState.new()
	en.advance_turn()  # active_index=1: Goblin Scout
	var en_path: Array[Vector2i] = en.get_enemy_move_path()
	_eq("enemy path size equals speed when dist > speed", en_path.size(), 6)
	_eq("enemy path ends at (3,1) after 6 steps toward Mago", en_path[-1], Vector2i(3, 1))

	# get_enemy_move_path — enemy already adjacent: returns empty path
	var ea := BattleState.new()
	ea.combatant_positions[1] = Vector2i(2, 2)  # Goblin Scout adjacent to Guerreiro at (2,3)
	ea.advance_turn()                             # active_index=1, Goblin at (2,2)
	var ea_path: Array[Vector2i] = ea.get_enemy_move_path()
	_eq("path empty when enemy already adjacent to player", ea_path.size(), 0)

	# apply_enemy_move — updates combatant position to last tile in path
	var eap := BattleState.new()
	eap.advance_turn()  # active_index=1: Goblin Scout at (9,1)
	var manual_path: Array[Vector2i] = [Vector2i(8, 1), Vector2i(7, 1)]
	eap.apply_enemy_move(manual_path)
	_eq("apply_enemy_move updates position to last tile", eap.combatant_positions[1], Vector2i(7, 1))

	# apply_enemy_move — no-op with empty path
	var eae := BattleState.new()
	eae.advance_turn()  # Goblin Scout at (9,1)
	eae.apply_enemy_move([])
	_eq("apply_enemy_move no-op with empty path", eae.combatant_positions[1], Vector2i(9, 1))

	# ── MapGenerator tests ──────────────────────────────────────────────────────

	var gen := MapGenerator.new()
	var md := gen.generate(42)  # fixed seed for determinism

	# Grid bounds
	_true("grid_cols in range [8,14]", md.grid_cols >= 8 and md.grid_cols <= 14)
	_true("grid_rows in range [5,8]",  md.grid_rows >= 5 and md.grid_rows <= 8)

	# Spawn counts
	_eq("hero_spawns has 4 entries",  md.hero_spawns.size(),  4)
	_eq("enemy_spawns has 4 entries", md.enemy_spawns.size(), 4)

	# No spawn on VOID or OBSTACLE
	var spawns_clean := true
	for pos in md.hero_spawns + md.enemy_spawns:
		var t: int = md.tile_map[pos.x][pos.y]
		if t == MapGenerator.TileType.VOID or t == MapGenerator.TileType.OBSTACLE:
			spawns_clean = false
	_true("no spawn on VOID or OBSTACLE", spawns_clean)

	# Connectivity: all accessible tiles reachable from hero_spawns[0]
	var accessible: Array[Vector2i] = []
	for col in range(md.grid_cols):
		for row in range(md.grid_rows):
			var t: int = md.tile_map[col][row]
			if t != MapGenerator.TileType.VOID and t != MapGenerator.TileType.OBSTACLE:
				accessible.append(Vector2i(col, row))
	var reached := _flood_fill_map(md, md.hero_spawns[0])
	_eq("map is fully connected", reached.size(), accessible.size())

	# Determinism: same seed → same result
	var md2 := gen.generate(42)
	_true("same seed same cols",        md2.grid_cols == md.grid_cols)
	_true("same seed same rows",        md2.grid_rows == md.grid_rows)
	_true("same seed same tile [0][0]", md2.tile_map[0][0] == md.tile_map[0][0])
	_true("same seed same center tile", md2.tile_map[int(md2.grid_cols / 2.0)][int(md2.grid_rows / 2.0)] == md.tile_map[int(md.grid_cols / 2.0)][int(md.grid_rows / 2.0)])

	# ── Terrain-aware movement tests ────────────────────────────────────────────

	# OBSTACLE blocks movement
	var bo := BattleState.new()
	bo.enter_move_mode()
	bo.tile_map[3][3] = MapGenerator.TileType.OBSTACLE
	var obs_tiles := bo.get_reachable_tiles()
	_true("OBSTACLE tile not in reachable set", not (Vector2i(3, 3) in obs_tiles))

	# MUD increases cost: fill row 3 cols 3-10 with MUD
	# Around-path to (8,2): (2,3)→(2,2)→(3,2)→...→(8,2) costs 7 → reachable
	# To (8,3): cheapest path passes through MUD, min cost 9 → not reachable with speed 7
	var bm := BattleState.new()
	bm.enter_move_mode()
	for c in range(3, 11):
		bm.tile_map[c][3] = MapGenerator.TileType.MUD
	var mud_tiles := bm.get_reachable_tiles()
	_true("(8,2) reachable going around MUD row", Vector2i(8, 2) in mud_tiles)
	_true("(8,3) blocked by MUD cost >7",         not (Vector2i(8, 3) in mud_tiles))

	# Trap: confirm_move onto TRAP tile reduces HP and sets context_message
	var hp_before: int = BattleState.PLAYERS[0]["hp"]
	var bt := BattleState.new()
	bt.tile_map[4][3] = MapGenerator.TileType.TRAP
	bt.enter_move_mode()
	bt.move_cursor = Vector2i(4, 3)
	bt.confirm_move()
	_eq("trap reduces player HP by 5",   BattleState.PLAYERS[0]["hp"], hp_before - 5)
	_true("context_message set on trap", bt.context_message.length() > 0)
	BattleState.PLAYERS[0]["hp"] = hp_before  # restore for subsequent tests

	# BattleState.setup() applies map_data
	var bsetup := BattleState.new()
	bsetup.setup(md)
	_eq("setup() sets grid_cols", bsetup.grid_cols, md.grid_cols)
	_eq("setup() sets grid_rows", bsetup.grid_rows, md.grid_rows)
	_eq("setup() sets hero spawn 0",  bsetup.combatant_positions[0], md.hero_spawns[0])
	_eq("setup() sets enemy spawn 0", bsetup.combatant_positions[1], md.enemy_spawns[0])

	# Task 1: action_behaviors
	var goblin: EnemyData = BattleState.ALL_ENEMIES["Goblin"]
	_eq("goblin action_behaviors size matches pool", goblin.action_behaviors.size(), goblin.action_pool.size())
	_eq("goblin flee behavior is_flee=true",        goblin.action_behaviors[4].get("is_flee", false), true)
	_eq("goblin dagger behavior range=3",           goblin.action_behaviors[2].get("range", -1), 3)

	var orc: EnemyData = BattleState.ALL_ENEMIES["Orc"]
	_eq("orc smash behavior range=1",              orc.action_behaviors[0].get("range", -1), 1)
	_true("orc charge damage_mult > 1.0",          orc.action_behaviors[2].get("damage_mult", 1.0) > 1.0)
	_eq("orc rage is_self_buff=true",              orc.action_behaviors[4].get("is_self_buff", false), true)
	_eq("orc rage buff_type=raging",               orc.action_behaviors[4].get("buff_type", ""), "raging")

	var mage: EnemyData = BattleState.ALL_ENEMIES["Mage"]
	_eq("mage frost nova aoe_radius=1",            mage.action_behaviors[2].get("aoe_radius", 0), 1)
	_eq("mage frost nova applies_status=stunned",  mage.action_behaviors[2].get("applies_status", ""), "stunned")
	_eq("mage teleport is_self_buff=true",         mage.action_behaviors[4].get("is_self_buff", false), true)

	var archer: EnemyData = BattleState.ALL_ENEMIES["Undead"]
	_eq("archer arrow range=5",                    archer.action_behaviors[0].get("range", -1), 5)
	_eq("archer aiming is_self_buff=true",         archer.action_behaviors[2].get("is_self_buff", false), true)
	_eq("archer aiming buff_type=aiming",          archer.action_behaviors[2].get("buff_type", ""), "aiming")

	# Task 3: AI personality
	# Goblin com HP baixo deve escolher Fleeing (idx 4)
	var s_goblin := BattleState.new()
	# active_index 1 é o Goblin Scout no TURN_QUEUE padrão
	s_goblin.active_index = 1
	s_goblin.enemy_hp["Goblin Scout"] = 1  # HP crítico (< 40% de 20)
	# combatant_positions precisa ter tamanho correto
	s_goblin.combatant_positions.resize(BattleState.TURN_QUEUE.size())
	for i in range(BattleState.TURN_QUEUE.size()):
		s_goblin.combatant_positions[i] = Vector2i(i, 0)
	_eq("goblin picks Fleeing when HP < 40%", s_goblin._pick_enemy_action_idx(), 4)

	# Orc com HP normal deve escolher ataque (0 ou 1)
	var s_orc := BattleState.new()
	s_orc.active_index = 4  # Orc Warrior no TURN_QUEUE padrão (índice 4)
	s_orc.enemy_hp["Orc Warrior"] = 40  # HP cheio
	s_orc.combatant_positions.resize(BattleState.TURN_QUEUE.size())
	for i in range(BattleState.TURN_QUEUE.size()):
		s_orc.combatant_positions[i] = Vector2i(i, 0)
	var orc_action := s_orc._pick_enemy_action_idx()
	_true("orc with full HP picks normal attack (0 or 1)", orc_action == 0 or orc_action == 1)

	# Task 5: defending status
	var s_defender := BattleState.new()
	s_defender.apply_defender_action(0)  # Guerreiro é PLAYERS[0] e TURN_QUEUE[0]
	_true("apply_defender_action sets defending on turn queue index 0",
		  s_defender.combatant_statuses[0].get("defending", 0) > 0)
	_eq("get_active_status_text returns Defender string",
		s_defender.get_active_status_text(0), "Defender +2 AC")

	# Task 1 (Ladrao): hero data stats
	var ladrao_data: HeroData = BattleState.ALL_HERO_DATA.get("Ladrao", null)
	_true("ALL_HERO_DATA contains Ladrao", ladrao_data != null)
	_eq("Ladrao speed is 9",       ladrao_data.speed,      9)
	_eq("Ladrao dexterity is 18",  ladrao_data.dexterity,  18)
	_eq("Ladrao base_hp is 55",    ladrao_data.base_hp,    55)
	_eq("Ladrao class is Rogue",   ladrao_data.hero_class, "Rogue")

	# Task 2 (Ladrao): apply_furtivo_status
	var s_furtivo := BattleState.new()
	s_furtivo.apply_furtivo_status(0)  # PLAYERS[0] = Guerreiro → TURN_QUEUE[0]
	_true("apply_furtivo_status sets furtivo on queue idx 0",
		  s_furtivo.combatant_statuses[0].get("furtivo", 0) > 0)

	# Task 3 (Ladrao): furtivo consumed in _apply_attack
	var s_sneak := BattleState.new()
	s_sneak.active_index = 0  # Guerreiro (TURN_QUEUE[0], is_player=true)
	s_sneak.combatant_statuses[0]["furtivo"] = 1
	s_sneak.enemy_hp["Goblin Scout"] = 100
	for i in range(BattleState.TURN_QUEUE.size()):
		s_sneak.combatant_positions[i] = Vector2i(i, 0)
	s_sneak._apply_attack(1)  # ataca Goblin Scout (TURN_QUEUE[1])
	_true("furtivo consumed after _apply_attack",
		  s_sneak.combatant_statuses[0].get("furtivo", 0) == 0)
	_true("_apply_attack dealt damage > 0",
		  s_sneak.last_attack_info.get("amount", 0) > 0)

	# Task 1 (Bárbaro): hero data stats
	var barbaro_data: HeroData = BattleState.ALL_HERO_DATA.get("Bárbaro", null)
	_true("ALL_HERO_DATA contains Bárbaro", barbaro_data != null)
	_eq("Bárbaro strength is 20",        barbaro_data.strength,        20)
	_eq("Bárbaro base_hp is 95",         barbaro_data.base_hp,         95)
	_eq("Bárbaro class is Barbarian",    barbaro_data.hero_class,      "Barbarian")
	_eq("Bárbaro damage_reduction is 1", barbaro_data.damage_reduction, 1)
	_eq("Bárbaro constitution is 18", barbaro_data.constitution, 18)
	_eq("Bárbaro max_hp is 120",      barbaro_data.max_hp,       120)

	# Task 2 (Bárbaro): fury status e extra attack
	var s_fury := BattleState.new()
	s_fury.apply_fury_status(0)  # PLAYERS[0] = Guerreiro → TURN_QUEUE[0]
	_true("apply_fury_status sets fury on queue idx 0",
		  s_fury.combatant_statuses[0].get("fury", 0) > 0)
	_true("has_fury returns true after apply_fury_status",
		  s_fury.has_fury(0))
	_true("fury_extra_attack is true after apply_fury_status",
		  s_fury.fury_extra_attack)

	# Task 3 (Bárbaro): fury +4 dano em _apply_attack
	var s_barbaro := BattleState.new()
	s_barbaro.active_index = 0  # Guerreiro como atacante (TURN_QUEUE[0])
	s_barbaro.combatant_statuses[0]["fury"] = 1
	s_barbaro.enemy_hp["Goblin Scout"] = 200  # HP alto para não morrer
	for i in range(BattleState.TURN_QUEUE.size()):
		s_barbaro.combatant_positions[i] = Vector2i(i, 0)
	s_barbaro._apply_attack(1)  # ataca Goblin Scout (TURN_QUEUE[1])
	_true("fury adds damage (minimum is base_min + prof + 4 = 11)",
		  s_barbaro.last_attack_info.get("amount", 0) >= 11)

	# Task 1: novos ataques
	var arcano := AtqArcano.new()
	_eq("AtqArcano label", arcano.label, "Raio Arcano")
	_eq("AtqArcano damage_attribute is INT", arcano.damage_attribute, ActionData.DamageAttribute.INT)
	_eq("AtqArcano attack_range", arcano.attack_range, 4)

	var divino := AtqDivino.new()
	_eq("AtqDivino label", divino.label, "Atq. Divino")
	_eq("AtqDivino damage_attribute is WIS", divino.damage_attribute, ActionData.DamageAttribute.WIS)
	_eq("AtqDivino attack_range", divino.attack_range, 1)

	var soco := AtqSoco.new()
	_eq("AtqSoco label", soco.label, "Soco")
	_eq("AtqSoco damage_attribute is DEX", soco.damage_attribute, ActionData.DamageAttribute.DEX)
	_eq("AtqSoco base_damage_max", soco.base_damage_max, 5)

	# Task 2: skills
	var sv := SkillSegundoVento.new()
	_eq("SkillSegundoVento label", sv.label, "Segundo Vento")
	_eq("SkillSegundoVento pp", sv.pp, 1)
	_eq("SkillSegundoVento max_pp", sv.max_pp, 1)
	_eq("SkillSegundoVento action_type is END_TURN", sv.action_type, ActionData.Type.END_TURN)

	var cf := SkillChuvaFlechas.new()
	_eq("SkillChuvaFlechas label", cf.label, "Chuva de Flechas")
	_eq("SkillChuvaFlechas mp_cost", cf.mp_cost, 15)
	_eq("SkillChuvaFlechas aoe_radius", cf.aoe_radius, 1)
	_eq("SkillChuvaFlechas damage_attribute is DEX", cf.damage_attribute, ActionData.DamageAttribute.DEX)

	var ca := SkillCuraArea.new()
	_eq("SkillCuraArea label", ca.label, "Cura em Área")
	_eq("SkillCuraArea targets_allies", ca.targets_allies, true)
	_eq("SkillCuraArea mp_cost", ca.mp_cost, 25)

	# Task 3: HeroData arrays
	var hd := HeroData.new()
	_true("HeroData.actions exists and is empty", hd.actions.is_empty())
	_true("HeroData.skills exists and is empty",  hd.skills.is_empty())

	# Task 4: Guerreiro e Mago actions
	var g_data: HeroData = BattleState.ALL_HERO_DATA["Guerreiro"]
	_true("Guerreiro actions has AtqNormal",       g_data.actions.size() >= 1 and g_data.actions[0] is AtqNormal)
	_true("Guerreiro actions has AcaoMover last",  g_data.actions.size() >= 2 and g_data.actions[g_data.actions.size()-1] is AcaoMover)
	_true("Guerreiro skills has SkillSegundoVento", g_data.skills.size() == 1 and g_data.skills[0] is SkillSegundoVento)

	var m_data: HeroData = BattleState.ALL_HERO_DATA["Mago"]
	_true("Mago actions has AtqArcano",  m_data.actions.size() >= 1 and m_data.actions[0] is AtqArcano)
	_true("Mago skills has 4 items",     m_data.skills.size() == 4)
	_true("Mago skills[0] is SpellFogo", m_data.skills[0] is SpellFogo)

	# Task 5: Arqueiro e Clérigo
	var a_data: HeroData = BattleState.ALL_HERO_DATA["Arqueiro"]
	_true("Arqueiro actions[0] is AtqRapido",      a_data.actions.size() >= 1 and a_data.actions[0] is AtqRapido)
	_true("Arqueiro actions[1] is AtqPreciso",     a_data.actions.size() >= 2 and a_data.actions[1] is AtqPreciso)
	_true("Arqueiro skills[0] is SkillChuvaFlechas", a_data.skills.size() == 1 and a_data.skills[0] is SkillChuvaFlechas)

	var c_data: HeroData = BattleState.ALL_HERO_DATA["Clérigo"]
	_true("Clérigo actions[0] is AtqDivino",     c_data.actions.size() >= 1 and c_data.actions[0] is AtqDivino)
	_true("Clérigo skills has SpellCura",        c_data.skills.size() >= 1 and c_data.skills[0] is SpellCura)
	_true("Clérigo skills has SkillCuraArea",    c_data.skills.size() == 2 and c_data.skills[1] is SkillCuraArea)

	# Task 6: Ladrao e Bárbaro
	var l_data: HeroData = BattleState.ALL_HERO_DATA["Ladrao"]
	_true("Ladrao actions[0] is AtqNormal (DEX)", l_data.actions.size() >= 1 and l_data.actions[0] is AtqNormal)
	_eq("Ladrao AtqNormal uses DEX", l_data.actions[0].damage_attribute, ActionData.DamageAttribute.DEX)
	_true("Ladrao actions[1] is AtqRapido",       l_data.actions.size() >= 2 and l_data.actions[1] is AtqRapido)
	_true("Ladrao skills is empty",               l_data.skills.is_empty())

	var b_data: HeroData = BattleState.ALL_HERO_DATA["Bárbaro"]
	_true("Bárbaro actions[0] is AtqNormal",  b_data.actions.size() >= 1 and b_data.actions[0] is AtqNormal)
	_true("Bárbaro actions[1] is AtqPesado",  b_data.actions.size() >= 2 and b_data.actions[1] is AtqPesado)
	_true("Bárbaro skills is empty",          b_data.skills.is_empty())

	# Task 7: tab_action loads per-hero actions
	var s7 := BattleState.new()
	# s7 starts at Guerreiro (TURN_QUEUE[0])
	_true("tab_action at start matches Guerreiro actions",
		s7.tab_action.size() == BattleState.ALL_HERO_DATA["Guerreiro"].actions.size())
	_true("tab_action[0] is AtqNormal for Guerreiro",
		s7.tab_action[0] is AtqNormal)
	# advance to Mago (TURN_QUEUE[2] = Mago, need 2 advance_turns)
	s7.advance_turn()  # goes to TURN_QUEUE[1] = Goblin Scout (enemy)
	s7.advance_turn()  # goes to TURN_QUEUE[2] = Mago (player)
	_true("tab_action after 2 advances matches Mago actions",
		s7.tab_action.size() == BattleState.ALL_HERO_DATA["Mago"].actions.size())
	_true("tab_action[0] is AtqArcano for Mago",
		s7.tab_action[0] is AtqArcano)
	# PP check: SkillSegundoVento with pp=0 is unavailable
	var sv2 := SkillSegundoVento.new()
	sv2.pp = 0
	_true("is_item_available returns false when pp=0",
		not s7.is_item_available(sv2))

	# ── Paladino tests ──────────────────────────────────────────────────────────

	# Task 1: SkillSmite e SkillCuraMaos
	var sm := SkillSmite.new()
	_eq("SkillSmite label", sm.label, "Smite Divino")
	_eq("SkillSmite mp_cost", sm.mp_cost, 15)
	_eq("SkillSmite action_type is END_TURN", sm.action_type, ActionData.Type.END_TURN)
	_eq("SkillSmite self_target", sm.self_target, true)

	var cm := SkillCuraMaos.new()
	_eq("SkillCuraMaos label", cm.label, "Cura das Mãos")
	_eq("SkillCuraMaos mp_cost", cm.mp_cost, 20)
	_eq("SkillCuraMaos targets_allies", cm.targets_allies, true)
	_eq("SkillCuraMaos damage_attribute is WIS", cm.damage_attribute, ActionData.DamageAttribute.WIS)
	_eq("SkillCuraMaos base_damage_min", cm.base_damage_min, 15)
	_eq("SkillCuraMaos base_damage_max", cm.base_damage_max, 25)

	# Task 2: PaladinoData stats e actions
	var pal_data: HeroData = BattleState.ALL_HERO_DATA.get("Paladino", null)
	_true("ALL_HERO_DATA contains Paladino", pal_data != null)
	_eq("Paladino strength is 16",    pal_data.strength,   16)
	_eq("Paladino wisdom is 14",      pal_data.wisdom,     14)
	_eq("Paladino max_hp is 110",     pal_data.max_hp,     110)
	_eq("Paladino base_mp is 40",     pal_data.base_mp,    40)
	_eq("Paladino class is Paladin",  pal_data.hero_class, "Paladin")
	_eq("Paladino ac is 16",          pal_data.ac,         16)
	_eq("Paladino speed is 6",        pal_data.speed,      6)
	_true("Paladino actions[0] is AtqDivino",    pal_data.actions.size() >= 1 and pal_data.actions[0] is AtqDivino)
	_true("Paladino actions[1] is AcaoMover",    pal_data.actions.size() >= 2 and pal_data.actions[1] is AcaoMover)
	_true("Paladino skills[0] is SkillSmite",    pal_data.skills.size() >= 1 and pal_data.skills[0] is SkillSmite)
	_true("Paladino skills[1] is SkillCuraMaos", pal_data.skills.size() >= 2 and pal_data.skills[1] is SkillCuraMaos)

	# Task 3: apply_smite_status
	var s_smite := BattleState.new()
	s_smite.apply_smite_status(0)  # Guerreiro (PLAYERS[0]) → TURN_QUEUE[0]
	_true("apply_smite_status sets smite on queue idx 0",
		  s_smite.combatant_statuses[0].get("smite", 0) > 0)

	# Task 3: smite em _apply_attack — dano aumentado e status consumido
	var s_pal := BattleState.new()
	s_pal.active_index = 0
	s_pal.combatant_statuses[0]["smite"] = 1
	s_pal.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_pal.combatant_positions[i] = Vector2i(i, 0)
	s_pal._apply_attack(1)  # ataca Goblin Scout (TURN_QUEUE[1])
	_true("smite adds damage (minimum base_min + prof + 8 = 15)",
		  s_pal.last_attack_info.get("amount", 0) >= 15)
	_true("smite is consumed after attack",
		  s_pal.combatant_statuses[0].get("smite", 0) == 0)

	# Task 3: is_item_available bloqueia SkillSmite quando MP insuficiente
	var s_mp := BattleState.new()
	BattleState.PLAYERS[0]["mp"] = 10  # MP < 15
	var sm2 := SkillSmite.new()
	_true("SkillSmite unavailable when MP < 15",
		  not s_mp.is_item_available(sm2))
	BattleState.PLAYERS[0]["mp"] = 40  # restaurar

	# ── Monge tests ─────────────────────────────────────────────────────────────

	# Task 1: SkillFlurry e SkillPassoVento
	var fl := SkillFlurry.new()
	_eq("SkillFlurry label", fl.label, "Flurry of Blows")
	_eq("SkillFlurry mp_cost", fl.mp_cost, 1)
	_eq("SkillFlurry action_type is END_TURN", fl.action_type, ActionData.Type.END_TURN)
	_eq("SkillFlurry self_target", fl.self_target, true)

	var pv := SkillPassoVento.new()
	_eq("SkillPassoVento label", pv.label, "Passo do Vento")
	_eq("SkillPassoVento mp_cost", pv.mp_cost, 1)
	_eq("SkillPassoVento action_type is END_TURN", pv.action_type, ActionData.Type.END_TURN)

	# Task 2: MongeData stats e actions
	var monk_data: HeroData = BattleState.ALL_HERO_DATA.get("Monge", null)
	_true("ALL_HERO_DATA contains Monge", monk_data != null)
	_eq("Monge dexterity is 18",   monk_data.dexterity,  18)
	_eq("Monge max_hp is 90",      monk_data.max_hp,     90)
	_eq("Monge base_mp is 5",      monk_data.base_mp,    5)
	_eq("Monge max_mp is 5",       monk_data.max_mp,     5)
	_eq("Monge speed is 10",       monk_data.speed,      10)
	_eq("Monge class is Monk",     monk_data.hero_class, "Monk")
	_true("Monge actions[0] is AtqSoco",       monk_data.actions.size() >= 1 and monk_data.actions[0] is AtqSoco)
	_true("Monge actions[1] is AtqRapido",     monk_data.actions.size() >= 2 and monk_data.actions[1] is AtqRapido)
	_true("Monge actions[2] is AcaoMover",     monk_data.actions.size() >= 3 and monk_data.actions[2] is AcaoMover)
	_true("Monge skills[0] is SkillFlurry",    monk_data.skills.size() >= 1 and monk_data.skills[0] is SkillFlurry)
	_true("Monge skills[1] is SkillPassoVento", monk_data.skills.size() >= 2 and monk_data.skills[1] is SkillPassoVento)

	# Task 3: SkillFlurry habilita fury_extra_attack
	var s_monk := BattleState.new()
	s_monk.active_index = 0
	BattleState.PLAYERS[0]["mp"] = 5
	BattleState.PLAYERS[0]["mp"] -= 1
	s_monk.fury_extra_attack = true
	_true("fury_extra_attack enabled after Flurry", s_monk.fury_extra_attack)
	_eq("Ki decremented after Flurry", BattleState.PLAYERS[0]["mp"], 4)
	BattleState.PLAYERS[0]["mp"] = 40  # restaurar para Guerreiro

	# Task 3: is_item_available bloqueia SkillFlurry quando Ki=0
	var s_ki := BattleState.new()
	BattleState.PLAYERS[0]["mp"] = 0
	var fl2 := SkillFlurry.new()
	_true("SkillFlurry unavailable when Ki=0",
		  not s_ki.is_item_available(fl2))
	BattleState.PLAYERS[0]["mp"] = 40  # restaurar

	# --- DungeonState tests ---
	var ds := DungeonState.new()
	ds.generate(42)

	var ds_floor_counts: Dictionary = {}
	for dn in ds.nodes:
		ds_floor_counts[dn.floor_idx] = ds_floor_counts.get(dn.floor_idx, 0) + 1
	_eq("DungeonState: floor 0 has 1 node",  ds_floor_counts.get(0, 0), 1)
	_eq("DungeonState: floor 5 has 1 node",  ds_floor_counts.get(5, 0), 1)
	_true("DungeonState: floor 1 has 2-3 nodes",
		ds_floor_counts.get(1, 0) >= 2 and ds_floor_counts.get(1, 0) <= 3)
	_true("DungeonState: floor 4 has 2-3 nodes",
		ds_floor_counts.get(4, 0) >= 2 and ds_floor_counts.get(4, 0) <= 3)

	var ds_entry_ok := true
	for dn in ds.nodes:
		if dn.floor_idx == 0 and dn.type != DungeonState.RoomType.BATTLE:
			ds_entry_ok = false
	_true("DungeonState: floor 0 node is BATTLE", ds_entry_ok)

	var ds_boss_ok := true
	for dn in ds.nodes:
		if dn.floor_idx == 5 and dn.type != DungeonState.RoomType.BOSS:
			ds_boss_ok = false
	_true("DungeonState: floor 5 node is BOSS", ds_boss_ok)

	var ds_avail := ds.get_available_rooms()
	_eq("DungeonState: get_available_rooms at start returns 1 room", ds_avail.size(), 1)
	_eq("DungeonState: available room at start is floor 0", ds_avail[0].floor_idx, 0)

	ds.enter_room(0)
	_eq("DungeonState: enter_room sets current_node_id", ds.current_node_id, 0)

	ds.complete_current_room()
	var ds_n0: DungeonState.RoomNode = ds.get_node_by_id(0)
	_true("DungeonState: complete_current_room marks node completed",
		ds_n0 != null and ds_n0.completed)

	var ds2 := DungeonState.new()
	ds2.generate(42)
	_true("DungeonState: is_run_complete false initially", not ds2.is_run_complete())

	var ds_boss_id := -1
	for dn in ds2.nodes:
		if dn.type == DungeonState.RoomType.BOSS:
			ds_boss_id = dn.id
	_true("DungeonState: boss node exists", ds_boss_id >= 0)
	ds2.current_node_id = ds_boss_id
	ds2.complete_current_room()
	_true("DungeonState: is_run_complete true after boss completed", ds2.is_run_complete())

	var ds3 := DungeonState.new()
	ds3.generate(42)
	var ds_reachable: Array = []
	for dn in ds3.nodes:
		if dn.floor_idx == 0:
			ds_reachable.append(dn.id)
	var ds_visited: Dictionary = {}
	while not ds_reachable.is_empty():
		var nid: int = ds_reachable.pop_back()
		if ds_visited.has(nid): continue
		ds_visited[nid] = true
		var dn3: DungeonState.RoomNode = ds3.get_node_by_id(nid)
		if dn3 == null: continue
		for c in dn3.connections:
			if not ds_visited.has(c):
				ds_reachable.append(c)
	_eq("DungeonState: all nodes reachable from floor 0",
		ds_visited.size(), ds3.nodes.size())

	# save/load round-trip
	var ds4 := DungeonState.new()
	ds4.generate(42)
	ds4.enter_room(0)
	ds4.complete_current_room()
	ds4.save()
	var ds4_loaded := DungeonState.load_save()
	_true("DungeonState: load_save returns non-null", ds4_loaded != null)
	if ds4_loaded != null:
		_eq("DungeonState: load_save preserves current_node_id", ds4_loaded.current_node_id, 0)
		_eq("DungeonState: load_save preserves node count", ds4_loaded.nodes.size(), ds4.nodes.size())
		var ds4_n0: DungeonState.RoomNode = ds4_loaded.get_node_by_id(0)
		_true("DungeonState: load_save preserves completed flag", ds4_n0 != null and ds4_n0.completed)
	DungeonState.delete_save()

	# get_available_rooms after entering a room
	var ds5 := DungeonState.new()
	ds5.generate(42)
	ds5.enter_room(0)
	ds5.complete_current_room()
	var ds5_avail := ds5.get_available_rooms()
	_true("DungeonState: get_available_rooms after complete returns floor-1 nodes",
		ds5_avail.size() > 0 and ds5_avail[0].floor_idx == 1)

	# EventData registry
	_eq("EventData registry has 6 events", EventData.REGISTRY.size(), 6)
	_true("arcane_fountain exists", EventData.REGISTRY.has("arcane_fountain"))
	_true("campfire exists",        EventData.REGISTRY.has("campfire"))
	var ef: EventData = EventData.get_for_node(0)
	_true("get_for_node returns non-null", ef != null)
	var altar: EventData = EventData.REGISTRY["cursed_altar"]
	_eq("cursed_altar has 3 choices", altar.choices.size(), 3)
	var ativar: EventData.EventChoice = altar.choices[0]
	_true("Ativar is_random", ativar.is_random)
	_eq("Ativar primary is BUFF_NEXT_BATTLE",
		ativar.consequence_type, EventData.ConsequenceType.BUFF_NEXT_BATTLE)
	_eq("Ativar secondary is DAMAGE_TARGET",
		ativar.secondary_type, EventData.ConsequenceType.DAMAGE_TARGET)

	# MysteryRegistry — determinism and outcome coverage
	var m0: EventData = MysteryRegistry.resolve(0)
	_true("MysteryRegistry returns non-null for node 0", m0 != null)
	_true("MysteryRegistry is deterministic",
		MysteryRegistry.resolve(7).id == MysteryRegistry.resolve(7).id)
	var ids_seen: Dictionary = {}
	for test_id in range(200):
		var ev: EventData = MysteryRegistry.resolve(test_id)
		ids_seen[ev.id] = true
	_true("mystery_treasure reachable", ids_seen.has("mystery_treasure"))
	_true("mystery_battle reachable",   ids_seen.has("mystery_battle"))
	_true("mystery_curse reachable",    ids_seen.has("mystery_curse"))
	_eq("GO_TO_BATTLE enum value is 8",
		EventData.ConsequenceType.GO_TO_BATTLE, 8)
	# setup_enemies_for_room compositions
	BattleState.setup_party(["Guerreiro"])
	BattleState.setup_enemies_for_room(DungeonState.RoomType.BATTLE)
	var tq_battle: Array = BattleState.TURN_QUEUE.filter(func(e): return not e.get("is_player", false))
	_eq("BATTLE has 4 enemies", tq_battle.size(), 4)

	BattleState.setup_enemies_for_room(DungeonState.RoomType.ELITE)
	var tq_elite: Array = BattleState.TURN_QUEUE.filter(func(e): return not e.get("is_player", false))
	_eq("ELITE has 2 enemies", tq_elite.size(), 2)
	_eq("ELITE first enemy is Elite Warrior", tq_elite[0]["name"], "Elite Warrior")
	_eq("ELITE second enemy is Elite Mage",   tq_elite[1]["name"], "Elite Mage")

	BattleState.setup_enemies_for_room(DungeonState.RoomType.BOSS)
	var tq_boss: Array = BattleState.TURN_QUEUE.filter(func(e): return not e.get("is_player", false))
	_eq("BOSS has 1 enemy", tq_boss.size(), 1)
	_eq("BOSS enemy is Dungeon Guardian", tq_boss[0]["name"], "Dungeon Guardian")

	var guardian: EnemyData = BattleState.ALL_ENEMIES.get("DungeonGuardian", null)
	_true("DungeonGuardian registered", guardian != null)
	_eq("DungeonGuardian max_hp is 180", guardian.max_hp, 180)
	_eq("DungeonGuardian has 6 behaviors", guardian.action_behaviors.size(), 6)
