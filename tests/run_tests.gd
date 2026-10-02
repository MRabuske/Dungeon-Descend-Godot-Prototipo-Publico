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

# Encontra uma seed tal que o PRIMEIRO DiceRoller.roll_d(20) após seed() seja
# igual a `target`. Usado para forçar nat 1 / nat 20 deterministicamente.
func _find_seed_for_d20(target: int) -> int:
	for s in range(200000):
		seed(s)
		if DiceRoller.roll_d(20) == target:
			return s
	return 0

# Canonical fixed battlefield used by the movement / enemy-AI tests.
# These positions were the hardcoded default in BattleState until commit 1e880ff
# moved combatant placement into setup(map_data). The logic tests still depend on
# this exact layout (grid is 12x7 by default, which covers it).
func _battlefield() -> BattleState:
	var bs := BattleState.new()
	var pos := [
		Vector2i(2, 3),   # [0] Guerreiro
		Vector2i(9, 1),   # [1] Goblin Scout
		Vector2i(1, 1),   # [2] Mago
		Vector2i(1, 5),   # [3] Arqueiro
		Vector2i(10, 3),  # [4] Orc Warrior
		Vector2i(3, 4),   # [5] Clérigo
		Vector2i(9, 5),   # [6] Dark Mage
		Vector2i(11, 3),  # [7] Skeleton Archer
	]
	for i in range(mini(pos.size(), bs.combatant_positions.size())):
		bs.combatant_positions[i] = pos[i]
	return bs

# Verifica que nenhuma aresta entre andares adjacentes cruza outra.
# Duas arestas (a->b) e (c->d) cruzam se a.x < c.x e b.x > d.x (ou simétrico).
func _no_crossings(ds: DungeonState) -> bool:
	for f in range(ds.floor_count - 1):
		var edges: Array = []
		for n: DungeonState.RoomNode in ds.nodes:
			if n.floor_idx != f:
				continue
			for cid in n.connections:
				var t: DungeonState.RoomNode = ds.get_node_by_id(cid)
				if t != null:
					edges.append([n.position.x, t.position.x])
		for i in range(edges.size()):
			for j in range(i + 1, edges.size()):
				var ax: float = edges[i][0]; var bx: float = edges[i][1]
				var cx: float = edges[j][0]; var dx: float = edges[j][1]
				if (ax < cx and bx > dx) or (ax > cx and bx < dx):
					return false
	return true

func _flood_fill_map(map_data: MapGenerator.MapData, start: Vector2i) -> Array:
	var visited: Dictionary = {}
	var frontier: Array[Vector2i] = [start]
	var dirs := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if visited.has(cur):
			continue
		visited[cur] = true
		for d: Vector2i in dirs:
			var nxt := cur + d
			if nxt.x < 0 or nxt.x >= map_data.grid_cols or nxt.y < 0 or nxt.y >= map_data.grid_rows:
				continue
			var tile: TerrainTile = map_data.tile_data_map[nxt.x][nxt.y]
			if tile.is_void() or tile.object == TerrainTile.ObjectType.OBSTACLE:
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
	var enemy: Dictionary = BattleState.TURN_QUEUE[1]
	_true("enemy has is_player=false", not enemy["is_player"])
	_true("enemy has type field",      enemy.has("type"))
	_true("enemy has ac field",        enemy.has("ac"))

	# get_active_tab_items: fixed-size slot grid (MAX_SLOTS) — actions first,
	# end-turn in the last slot, remaining slots padded with null.
	var tab0 := s.get_active_tab_items()
	_eq("tab 0 has MAX_SLOTS slots", tab0.size(), BattleState.MAX_SLOTS)
	_eq("tab 0 starts with tab_action", tab0.slice(0, s.tab_action.size()), s.tab_action)
	_eq("tab 0 last slot is end-turn", tab0[BattleState.MAX_SLOTS - 1], BattleState.TAB_END_TURN[0])

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

	# wrap right: moving right past the last selectable ACTION slot wraps to HABILIDADES
	s.active_tab = 0
	s.cursor_position = 0
	for _i in range(BattleState.MAX_SLOTS):
		s.move_cursor_tab(1)
		if s.active_tab != 0:
			break
	_eq("wrap right: switches to HABILIDADES", s.active_tab, 1)
	_true("wrap right: cursor on a selectable slot",
		s.get_active_tab_items()[s.cursor_position] != null)

	# wrap left: moving left past the first slot returns to ACTION
	s.active_tab = 1
	s.cursor_position = 0
	s.move_cursor_tab(-1)
	_eq("wrap left: returns to ACTION", s.active_tab, 0)
	_true("wrap left: cursor on a selectable slot",
		s.get_active_tab_items()[s.cursor_position] != null)

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

	var m := _battlefield()

	# Initial movement state
	_eq("initial move points = Guerreiro speed (7)", m.move_points_remaining, 7)
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
	var me := _battlefield()
	me.advance_turn()  # moves to index 1 — Goblin Scout (ENEMY_TURN)
	me.enter_move_mode()
	_eq("enter_move_mode no-op when ENEMY_TURN", me.current_state, BattleState.State.ENEMY_TURN)

	# move_cursor_grid within speed range (Guerreiro speed=7)
	m.move_cursor_grid(Vector2i(1, 0))
	_eq("move_cursor_grid(1,0) moves cursor right to (3,3)", m.move_cursor, Vector2i(3, 3))

	# move_cursor_grid blocked at speed limit
	# Guerreiro at (2,3), speed=7. Moving right 7 times = (9,3). 8th move blocked.
	var ms := _battlefield()
	ms.enter_move_mode()
	for _i in range(8):
		ms.move_cursor_grid(Vector2i(1, 0))
	_eq("cursor stops at speed limit from origin", ms.move_cursor, Vector2i(9, 3))

	# move_cursor_grid blocked by occupied tile
	# (3,4) is occupied by Clérigo (combatant_positions[5])
	# Navigate: one step right to (3,3), then one step down — (3,4) is occupied → blocked.
	var mb := _battlefield()
	mb.enter_move_mode()
	mb.move_cursor_grid(Vector2i(1, 0))   # (2,3) → (3,3)
	mb.move_cursor_grid(Vector2i(0, 1))   # tries (3,4) — occupied → blocked
	_eq("move_cursor blocked by occupied tile", mb.move_cursor, Vector2i(3, 3))

	# move_cursor_grid clamped at grid boundary
	# Cursor starts at active position (2,3). Move left 3 times — should stop at x=0.
	var mg := _battlefield()
	mg.enter_move_mode()
	for _i in range(4):
		mg.move_cursor_grid(Vector2i(-1, 0))
	_eq("cursor clamped at left grid boundary", mg.move_cursor, Vector2i(0, 3))

	# confirm_move updates position and deducts movement cost
	var mc := _battlefield()
	mc.enter_move_mode()
	mc.move_cursor = Vector2i(4, 3)
	mc.confirm_move()
	_eq("confirm_move updates combatant position", mc.combatant_positions[0], Vector2i(4, 3))
	# Guerreiro (2,3) → (4,3): 2 tiles em terreno normal = custo 2. speed 7 → 5 restantes
	_eq("confirm_move deducts movement cost", mc.move_points_remaining, 5)
	_eq("confirm_move returns to PLAYER_TURN",     mc.current_state, BattleState.State.PLAYER_TURN)

	# movimento dividido: ainda da pra reentrar no modo de movimento com pontos sobrando
	mc.enter_move_mode()
	_eq("enter_move_mode works again with points remaining", mc.current_state, BattleState.State.MOVE_MODE)

	# cancel_move restores PLAYER_TURN without moving
	var mx := _battlefield()
	mx.enter_move_mode()
	mx.move_cursor_grid(Vector2i(2, 0))
	mx.cancel_move()
	_eq("cancel_move returns to PLAYER_TURN",        mx.current_state, BattleState.State.PLAYER_TURN)
	_eq("cancel_move leaves original position intact", mx.combatant_positions[0], Vector2i(2, 3))
	_eq("cancel_move leaves move points intact",      mx.move_points_remaining, 7)

	# get_reachable_tiles returns non-empty array within grid bounds
	var mr := _battlefield()
	var tiles: Dictionary = mr.get_reachable_tiles()
	_true("get_reachable_tiles returns non-empty result", tiles.size() > 0)
	# Guerreiro at (2,3), speed=7 — all tiles with Manhattan dist <=7, excluding occupied
	# Spot-check: (5,3) is dist=3, unoccupied → should be reachable
	_true("(5,3) is in reachable tiles", Vector2i(5, 3) in tiles)
	# (9,1) is occupied by Goblin Scout → must NOT appear
	_true("occupied tile (9,1) not in reachable tiles", not (Vector2i(9, 1) in tiles))

	# advance_turn (volta completa da fila) reabastece os pontos de movimento
	var ma := _battlefield()
	ma.enter_move_mode()
	ma.move_cursor = Vector2i(5, 3)   # 3 tiles em terreno normal = custo 3
	ma.confirm_move()
	_eq("move points deducted after move", ma.move_points_remaining, 4)
	for _i in range(BattleState.TURN_QUEUE.size()):
		ma.advance_turn()
	_eq("advance_turn refills move points to full speed", ma.move_points_remaining, 7)

	# ── Dash tests ───────────────────────────────────────────────────────────────

	# Dash presente no grid de acoes (todos os herois), antes do Mover
	var has_dash := false
	for a in m.tab_action:
		if a is DashAction:
			has_dash = true
	_true("Dash present in tab_action", has_dash)
	_true("Mover still last in tab_action", m.tab_action[m.tab_action.size() - 1] is AcaoMover)

	# Dash dobra o movimento (soma a velocidade base) e gasta a Action
	var mdash := _battlefield()
	_eq("Dash before: full move points", mdash.move_points_remaining, 7)
	mdash.apply_dash()
	_eq("Dash adds base speed to move points", mdash.move_points_remaining, 14)
	_eq("Dash consumes the main action", mdash.has_attacked, true)
	_eq("Dash unavailable after action used", mdash.is_item_available(DashAction.new()), false)

	# ── Enemy AI movement tests ─────────────────────────────────────────────────

	# Enemy speed via ALL_ENEMIES EnemyData objects
	_eq("Goblin speed is 6",  BattleState.ALL_ENEMIES["Goblin"].speed,  6)
	_eq("Orc speed is 4",     BattleState.ALL_ENEMIES["Orc"].speed,     4)
	_eq("Mage speed is 5",    BattleState.ALL_ENEMIES["Mage"].speed,    5)
	_eq("Undead speed is 5",  BattleState.ALL_ENEMIES["Undead"].speed,  5)

	# get_enemy_move_path — Goblin Scout at (9,1), nearest player Mago at (1,1), dist=8, speed=6
	# Greedy path moves along x: (8,1)→(7,1)→...→(3,1) — 6 steps, none occupied
	var en := _battlefield()
	en.advance_turn()  # active_index=1: Goblin Scout
	var en_path: Array[Vector2i] = en.get_enemy_move_path()
	_eq("enemy path size equals speed when dist > speed", en_path.size(), 6)
	_eq("enemy path ends at (3,1) after 6 steps toward Mago", en_path[-1], Vector2i(3, 1))

	# get_enemy_move_path — enemy already adjacent: returns empty path
	var ea := _battlefield()
	ea.combatant_positions[1] = Vector2i(2, 2)  # Goblin Scout adjacent to Guerreiro at (2,3)
	ea.advance_turn()                             # active_index=1, Goblin at (2,2)
	# get_enemy_move_path tem 65% de chance de retornar [] quando já adjacente
	# (randf() < 0.65) e 35% de reposicionar — seed fixo torna o teste determinístico.
	seed(1)
	var ea_path: Array[Vector2i] = ea.get_enemy_move_path()
	_eq("path empty when enemy already adjacent to player", ea_path.size(), 0)

	# apply_enemy_move — updates combatant position to last tile in path
	var eap := _battlefield()
	eap.advance_turn()  # active_index=1: Goblin Scout at (9,1)
	var manual_path: Array[Vector2i] = [Vector2i(8, 1), Vector2i(7, 1)]
	eap.apply_enemy_move(manual_path)
	_eq("apply_enemy_move updates position to last tile", eap.combatant_positions[1], Vector2i(7, 1))

	# apply_enemy_move — no-op with empty path
	var eae := _battlefield()
	eae.advance_turn()  # Goblin Scout at (9,1)
	eae.apply_enemy_move([])
	_eq("apply_enemy_move no-op with empty path", eae.combatant_positions[1], Vector2i(9, 1))

	# ── MapGenerator tests ──────────────────────────────────────────────────────

	var gen := MapGenerator.new()
	var md := gen.generate(42)  # fixed seed for determinism

	# Grid bounds
	_true("grid_cols in range [22,36]", md.grid_cols >= 22 and md.grid_cols <= 36)
	_true("grid_rows in range [18,28]", md.grid_rows >= 18 and md.grid_rows <= 28)

	# Spawn counts
	_eq("hero_spawns has 4 entries",  md.hero_spawns.size(),  4)
	_eq("enemy_spawns has 4 entries", md.enemy_spawns.size(), 4)

	# No spawn on VOID or OBSTACLE
	var spawns_clean := true
	for pos in md.hero_spawns + md.enemy_spawns:
		var tile: TerrainTile = md.tile_data_map[pos.x][pos.y]
		if tile.is_void() or tile.object == TerrainTile.ObjectType.OBSTACLE:
			spawns_clean = false
	_true("no spawn on VOID or OBSTACLE", spawns_clean)

	# Connectivity: all accessible tiles reachable from hero_spawns[0]
	var accessible: Array[Vector2i] = []
	for col in range(md.grid_cols):
		for row in range(md.grid_rows):
			var tile: TerrainTile = md.tile_data_map[col][row]
			if not tile.is_void() and tile.object != TerrainTile.ObjectType.OBSTACLE:
				accessible.append(Vector2i(col, row))
	var reached := _flood_fill_map(md, md.hero_spawns[0])
	_eq("map is fully connected", reached.size(), accessible.size())

	# Determinism: same seed → same result
	var md2 := gen.generate(42)
	_true("same seed same cols",        md2.grid_cols == md.grid_cols)
	_true("same seed same rows",        md2.grid_rows == md.grid_rows)
	_true("same seed same tile [0][0]",
		md2.tile_data_map[0][0].ground == md.tile_data_map[0][0].ground \
		and md2.tile_data_map[0][0].object == md.tile_data_map[0][0].object)
	var det_cx := int(md.grid_cols / 2.0)
	var det_cy := int(md.grid_rows / 2.0)
	_true("same seed same center tile",
		md2.tile_data_map[det_cx][det_cy].ground == md.tile_data_map[det_cx][det_cy].ground \
		and md2.tile_data_map[det_cx][det_cy].object == md.tile_data_map[det_cx][det_cy].object)

	# ── Terrain-aware movement tests ────────────────────────────────────────────

	# OBSTACLE blocks movement
	var bo := _battlefield()
	bo.enter_move_mode()
	bo.tile_data_map[3][3].object = TerrainTile.ObjectType.OBSTACLE
	var obs_tiles := bo.get_reachable_tiles()
	_true("OBSTACLE tile not in reachable set", not (Vector2i(3, 3) in obs_tiles))

	# MUD increases cost: fill row 3 cols 3-10 with MUD
	# Around-path to (8,2): (2,3)→(2,2)→(3,2)→...→(8,2) costs 7 → reachable
	# To (8,3): cheapest path passes through MUD, min cost 9 → not reachable with speed 7
	var bm := _battlefield()
	bm.enter_move_mode()
	for c in range(3, 11):
		bm.tile_data_map[c][3].ground = TerrainTile.GroundType.MUD
	var mud_tiles := bm.get_reachable_tiles()
	_true("(8,2) reachable going around MUD row", Vector2i(8, 2) in mud_tiles)
	_true("(8,3) blocked by MUD cost >7",         not (Vector2i(8, 3) in mud_tiles))

	# Trap: confirm_move onto TRAP tile reduces HP and sets context_message
	var hp_before: int = BattleState.PLAYERS[0]["hp"]
	var bt := _battlefield()
	bt.tile_data_map[4][3].effect = TerrainTile.EffectType.TRAP_INACTIVE
	bt.enter_move_mode()
	bt.move_cursor = Vector2i(4, 3)
	bt.confirm_move()
	bt.activate_trap_after_move(bt.active_index, bt.combatant_positions[bt.active_index])
	var bt_loss: int = hp_before - BattleState.PLAYERS[0]["hp"]
	_true("trap reduces player HP by 2d4 (2..8)", bt_loss >= 2 and bt_loss <= 8)
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
	_eq("archer 2o slot tambem e tiro (range=5)",  archer.action_behaviors[1].get("range", -1), 5)
	_eq("archer nao tem self-buff",                archer.action_behaviors[0].get("is_self_buff", false), false)
	_eq("archer pool reduzido a 2 ataques",        archer.action_behaviors.size(), 2)
	_true("aiming removido do REGISTRY",           not StatusDefinitions.has("aiming"))
	_true("aiming removido do ORDER",              not ("aiming" in StatusDefinitions.ORDER))

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

	# Task 3 (Ladrao): Sneak Attack dispara com furtivo (= advantage) e é
	# consumido. Só o Rogue (TURN_QUEUE[8] = Ladrao) pode usá-lo.
	var s_sneak := BattleState.new()
	s_sneak.active_index = 8  # Ladrao (Rogue)
	s_sneak.current_attack_range = 1
	s_sneak._current_action = AtqNormal.new()
	s_sneak.combatant_statuses[8]["furtivo"] = 1
	s_sneak.enemy_hp["Goblin Scout"] = 100
	for i in range(BattleState.TURN_QUEUE.size()):
		s_sneak.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(15))  # garante acerto (15+prof >= AC do Goblin)
	s_sneak._apply_attack(1)  # ataca Goblin Scout (TURN_QUEUE[1])
	_true("furtivo consumed after sneak attack",
		  s_sneak.combatant_statuses[8].get("furtivo", 0) == 0)
	_true("sneak attack flagged used this turn",
		  s_sneak._sneak_attack_used_this_turn)
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
	# Dano agora usa dados; isolamos o bônus de fury comparando dois ataques
	# com a MESMA seed (um sem fury, um com fury). O delta deve ser exatamente +4.
	var s_fury_off := BattleState.new()
	s_fury_off.active_index = 0
	s_fury_off._current_action = AtqNormal.new()
	s_fury_off.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_fury_off.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(15))
	s_fury_off._apply_attack(1)
	var dmg_no_fury: int = s_fury_off.last_attack_info.get("amount", 0)

	var s_barbaro := BattleState.new()
	s_barbaro.active_index = 0  # Guerreiro como atacante (TURN_QUEUE[0])
	s_barbaro._current_action = AtqNormal.new()
	s_barbaro.combatant_statuses[0]["fury"] = 1
	s_barbaro.enemy_hp["Goblin Scout"] = 200  # HP alto para não morrer
	for i in range(BattleState.TURN_QUEUE.size()):
		s_barbaro.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(15))
	s_barbaro._apply_attack(1)  # ataca Goblin Scout (TURN_QUEUE[1])
	var dmg_fury: int = s_barbaro.last_attack_info.get("amount", 0)
	_true("fury adds +4 damage vs same-seed baseline", dmg_fury - dmg_no_fury == 4)

	# ── 3.9 A1: hook genérico applies_condition ──────────────────────────────
	# Sem save: a condição é aplicada ao acertar.
	var s_cond := BattleState.new()
	s_cond.active_index = 0
	var act_cond := ActionData.new()
	act_cond.action_type = ActionData.Type.ATTACK
	act_cond.damage_attribute = ActionData.DamageAttribute.STR
	act_cond.applies_condition = "restrained"
	act_cond.condition_duration = 3
	s_cond._current_action = act_cond
	s_cond.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_cond.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(18))
	s_cond._apply_attack(1)
	_eq("applies_condition sem save aplica no acerto", s_cond.combatant_statuses[1].get("restrained", 0), 3)

	# Com save de DC impossível (999): falha => aplica.
	var s_cond_fail := BattleState.new()
	s_cond_fail.active_index = 0
	var act_cf := ActionData.new()
	act_cf.action_type = ActionData.Type.ATTACK
	act_cf.damage_attribute = ActionData.DamageAttribute.STR
	act_cf.applies_condition = "blinded"
	act_cf.condition_save_attribute = ActionData.DamageAttribute.DEX
	act_cf.condition_dc = 999
	s_cond_fail._current_action = act_cf
	s_cond_fail.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_cond_fail.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(18))
	s_cond_fail._apply_attack(1)
	_true("applies_condition com save: falha aplica", s_cond_fail.combatant_statuses[1].get("blinded", 0) > 0)

	# Com save de DC trivial (1): passa => NÃO aplica.
	var s_cond_pass := BattleState.new()
	s_cond_pass.active_index = 0
	var act_cp := ActionData.new()
	act_cp.action_type = ActionData.Type.ATTACK
	act_cp.damage_attribute = ActionData.DamageAttribute.STR
	act_cp.applies_condition = "blinded"
	act_cp.condition_save_attribute = ActionData.DamageAttribute.DEX
	act_cp.condition_dc = 1
	s_cond_pass._current_action = act_cp
	s_cond_pass.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_cond_pass.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(18))
	s_cond_pass._apply_attack(1)
	_eq("applies_condition com save: passa não aplica", s_cond_pass.combatant_statuses[1].get("blinded", 0), 0)

	# Migração: spell_fogo perdeu target_effect (burning vem da superfície FIRE).
	var sf_mig := SpellFogo.new()
	_eq("spell_fogo applies_condition vazio", sf_mig.applies_condition, "")
	_eq("spell_fogo ainda cria superfície FIRE", sf_mig.creates_surface, SurfaceType.Type.FIRE)

	# ── 3.9 A2: buff genérico bonus_d4 (+1d4 no ataque/save) ─────────────────
	var s_b4_off := BattleState.new()
	s_b4_off.active_index = 0
	s_b4_off._current_action = AtqNormal.new()
	s_b4_off.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_b4_off.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(15))
	s_b4_off._apply_attack(1)
	var at_off: int = s_b4_off.last_attack_info.get("attack_total", 0)

	var s_b4_on := BattleState.new()
	s_b4_on.active_index = 0
	s_b4_on._current_action = AtqNormal.new()
	s_b4_on.combatant_statuses[0]["bonus_d4"] = 5
	s_b4_on.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_b4_on.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(15))
	s_b4_on._apply_attack(1)
	var b4_delta: int = s_b4_on.last_attack_info.get("attack_total", 0) - at_off
	_true("bonus_d4 soma +1..4 no attack_total", b4_delta >= 1 and b4_delta <= 4)

	# Decaimento: -1 por round do próprio combatente.
	var s_b4_decay := _battlefield()
	s_b4_decay.combatant_statuses[1]["bonus_d4"] = 3
	s_b4_decay.advance_turn()  # próximo a agir = Goblin Scout (idx 1)
	_eq("bonus_d4 decai 1 por round", s_b4_decay.combatant_statuses[1].get("bonus_d4", 0), 2)

	# ── 3.9 A3: alvo marcado (+dano por acerto, só do autor) ─────────────────
	var s_mk_off := BattleState.new()
	s_mk_off.active_index = 0
	s_mk_off._current_action = AtqNormal.new()
	s_mk_off.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_mk_off.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(15))
	s_mk_off._apply_attack(1)
	var dmg_mk_off: int = s_mk_off.last_attack_info.get("amount", 0)

	var s_mk_on := BattleState.new()
	s_mk_on.active_index = 0
	s_mk_on._current_action = AtqNormal.new()
	s_mk_on.apply_mark(1, 0, 1, 6, 5)   # marcado pelo atacante ativo (idx 0)
	s_mk_on.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_mk_on.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(15))
	s_mk_on._apply_attack(1)
	var mk_delta: int = s_mk_on.last_attack_info.get("amount", 0) - dmg_mk_off
	_true("marcado pelo atacante ativo soma +1d6", mk_delta >= 1 and mk_delta <= 6)

	# Marcado por OUTRO combatente (não o atacante) NÃO soma dano.
	var s_mk_other := BattleState.new()
	s_mk_other.active_index = 0
	s_mk_other._current_action = AtqNormal.new()
	s_mk_other.apply_mark(1, 3, 1, 6, 5)   # marcado por idx 3, não pelo atacante
	s_mk_other.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_mk_other.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(15))
	s_mk_other._apply_attack(1)
	_eq("marcado por outro não soma dano", s_mk_other.last_attack_info.get("amount", 0), dmg_mk_off)

	# Decaimento limpa marked_by quando expira.
	var s_mk_decay := _battlefield()
	s_mk_decay.apply_mark(1, 0, 1, 6, 1)
	s_mk_decay.advance_turn()  # idx 1 age; marked 1 -> 0, limpa
	_true("marked expira e limpa marked_by", not s_mk_decay.combatant_statuses[1].has("marked_by"))

	# ── 3.3 B1: Empurrar (Shove) ─────────────────────────────────────────────
	_true("Empurrar é ação bônus", AcaoEmpurrar.new().bonus_action)

	# Sucesso empurra na direção correta (alvo à direita -> +x), sem Prone.
	var s_shove := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		s_shove.combatant_positions[i] = Vector2i(i, 6)
	s_shove.combatant_positions[0] = Vector2i(2, 0)
	s_shove.combatant_positions[1] = Vector2i(3, 0)
	seed(_find_seed_for_d20(20))
	var sh_res := s_shove.resolve_shove(0, 1)
	_true("shove bem-sucedido", sh_res.get("success", false))
	_eq("shove empurra +x 2 tiles", s_shove.combatant_positions[1], Vector2i(5, 0))
	_eq("shove NÃO aplica prone (BG3)", s_shove.combatant_statuses[1].get("prone", 0), 0)

	# Empurrar para o void mata o alvo.
	var s_void := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		s_void.combatant_positions[i] = Vector2i(i, 6)
	s_void.combatant_positions[0] = Vector2i(2, 0)
	s_void.combatant_positions[1] = Vector2i(3, 0)
	s_void.tile_data_map[4][0].ground = TerrainTile.GroundType.VOID
	seed(_find_seed_for_d20(20))
	var vr := s_void.resolve_shove(0, 1)
	_true("shove no void é marcado como void", vr.get("void", false))
	_true("shove no void mata o alvo", s_void.dead_indices.has(1))

	# Contest falho não move o alvo.
	var s_sh_fail := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		s_sh_fail.combatant_positions[i] = Vector2i(i, 6)
	s_sh_fail.combatant_positions[0] = Vector2i(2, 0)
	s_sh_fail.combatant_positions[1] = Vector2i(3, 0)
	seed(_find_seed_for_d20(1))
	var fr := s_sh_fail.resolve_shove(0, 1)
	_true("shove falho não tem sucesso", not fr.get("success", true))
	_eq("shove falho não move", s_sh_fail.combatant_positions[1], Vector2i(3, 0))

	# ── 3.3 B2: Esconder (Hide) + status hidden ──────────────────────────────
	_eq("Esconder é END_TURN (gasta Ação)", AcaoEsconder.new().action_type, ActionData.Type.END_TURN)

	# Hidden concede Vantagem nos ataques do oculto.
	var s_hide_adv := BattleState.new()
	s_hide_adv.combatant_statuses[0]["hidden"] = 1
	var hmods := s_hide_adv.get_attack_roll_mods(0, 1, 1)
	_true("Oculto concede Vantagem", hmods.get("adv", 0) >= 1)

	# Atacar quebra Oculto.
	var s_hide_atk := BattleState.new()
	s_hide_atk.active_index = 0
	s_hide_atk.combatant_statuses[0]["hidden"] = 1
	s_hide_atk.finalize_attack()
	_eq("atacar quebra Oculto", s_hide_atk.combatant_statuses[0].get("hidden", 0), 0)

	# Hide falha sob LoS inimigo (DC = Percepção do observador).
	var s_hide_seen := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		if i != 0 and i != 1:
			s_hide_seen.dead_indices[i] = true
	s_hide_seen.combatant_positions[0] = Vector2i(1, 1)
	s_hide_seen.combatant_positions[1] = Vector2i(5, 1)
	seed(_find_seed_for_d20(1))
	_true("hide negado à vista sem cobertura", not s_hide_seen.resolve_hide(0))
	_eq("hide negado não concede Oculto", s_hide_seen.combatant_statuses[0].get("hidden", 0), 0)

	# À vista, mas EM COBERTURA: não é negado — rola e pode ter sucesso.
	var s_hide_cover := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		if i != 0 and i != 1:
			s_hide_cover.dead_indices[i] = true
	s_hide_cover.combatant_positions[0] = Vector2i(1, 1)
	s_hide_cover.combatant_positions[1] = Vector2i(5, 1)              # vê (1,1)
	s_hide_cover.tile_data_map[1][1].object = TerrainTile.ObjectType.COVER
	seed(_find_seed_for_d20(20))
	_true("hide em cobertura, mesmo visto, pode ter sucesso", s_hide_cover.resolve_hide(0))

	# Hide tem sucesso quando a LoS está bloqueada por obstáculo (DC base 10).
	var s_hide_block := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		if i != 0 and i != 1:
			s_hide_block.dead_indices[i] = true
	s_hide_block.combatant_positions[0] = Vector2i(1, 1)
	s_hide_block.combatant_positions[1] = Vector2i(5, 1)
	s_hide_block.tile_data_map[3][1].object = TerrainTile.ObjectType.OBSTACLE
	seed(_find_seed_for_d20(20))
	_true("hide sucesso com LoS bloqueada", s_hide_block.resolve_hide(0))
	_true("hide concede Oculto", s_hide_block.combatant_statuses[0].get("hidden", 0) > 0)

	# Ser avistado no início do turno quebra Oculto.
	var s_hide_turn := _battlefield()
	s_hide_turn.combatant_statuses[1]["hidden"] = 1
	s_hide_turn.advance_turn()  # próximo = idx 1 (Goblin), Guerreiro tem LoS
	_eq("avistado no início do turno quebra Oculto", s_hide_turn.combatant_statuses[1].get("hidden", 0), 0)

	# ── LOS: visão dos inimigos com sombra de obstáculo ──────────────────────
	var s_vis := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		if i != 1:
			s_vis.dead_indices[i] = true   # único inimigo vivo = idx 1
	s_vis.combatant_positions[1] = Vector2i(2, 3)
	s_vis.tile_data_map[4][3].object = TerrainTile.ObjectType.OBSTACLE
	var vis := s_vis.get_enemy_vision_tiles()
	_true("inimigo vê (3,3) à sua frente", vis.has(Vector2i(3, 3)))
	_true("sombra de obstáculo: (6,3) não é visto", not vis.has(Vector2i(6, 3)))

	# Alcance finito de visão (Chebyshev <= 8): linha limpa, sem bloqueador.
	var s_range := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		if i != 1:
			s_range.dead_indices[i] = true
	s_range.combatant_positions[1] = Vector2i(2, 3)
	var rng := s_range.get_enemy_vision_tiles()
	_true("inimigo vê tile a Chebyshev 8 (10,3)", rng.has(Vector2i(10, 3)))
	_true("inimigo NÃO vê tile a Chebyshev 9 (11,3)", not rng.has(Vector2i(11, 3)))

	# STATUE e COVER cortam a linha de visão (não só OBSTACLE).
	var s_stat := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		if i != 1:
			s_stat.dead_indices[i] = true
	s_stat.combatant_positions[1] = Vector2i(2, 3)
	s_stat.tile_data_map[4][3].object = TerrainTile.ObjectType.STATUE
	_true("STATUE bloqueia visão: (6,3) não é visto", not s_stat.get_enemy_vision_tiles().has(Vector2i(6, 3)))
	_true("_has_los barra através de STATUE", not s_stat._has_los(Vector2i(2, 3), Vector2i(6, 3)))
	s_stat.tile_data_map[4][3].object = TerrainTile.ObjectType.COVER
	_true("_has_los barra através de COVER", not s_stat._has_los(Vector2i(2, 3), Vector2i(6, 3)))

	# Coerência: cercado de estruturas → vê só uma fração da grade, não tudo.
	var s_box := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		if i != 1:
			s_box.dead_indices[i] = true
	s_box.combatant_positions[1] = Vector2i(5, 3)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var b: Vector2i = Vector2i(5, 3) + Vector2i(dx, dy)
			s_box.tile_data_map[b.x][b.y].object = TerrainTile.ObjectType.OBSTACLE
	var box_seen := s_box.get_enemy_vision_tiles().size()
	_true("inimigo cercado vê fração do mapa (não a grade toda)", box_seen < s_box.grid_cols * s_box.grid_rows / 2)

	# Tiro bloqueado por estrutura na linha: alvo não é mirável; remover abre o ângulo.
	var s_block := _battlefield()
	s_block.active_index = 0
	s_block._current_action = AtqNormal.new()
	s_block.combatant_positions[0] = Vector2i(2, 3)
	s_block.combatant_positions[1] = Vector2i(9, 3)
	s_block.tile_data_map[5][3].object = TerrainTile.ObjectType.COVER  # na linha (2,3)->(9,3)
	s_block.enter_attack_mode(10, false)
	_true("alvo atrás de estrutura não é mirável", not (1 in s_block.attack_target_indices))
	s_block.cancel_attack()
	s_block.tile_data_map[5][3].object = TerrainTile.ObjectType.NONE
	s_block.enter_attack_mode(10, false)
	_true("removida a estrutura, alvo volta a ser mirável", 1 in s_block.attack_target_indices)

	# Sem regressão: alvo SOBRE cobertura (endpoint) continua mirável, com Desvantagem.
	var s_oncov := _battlefield()
	s_oncov.active_index = 0
	s_oncov._current_action = AtqNormal.new()
	s_oncov.combatant_positions[0] = Vector2i(2, 3)
	s_oncov.combatant_positions[1] = Vector2i(6, 3)
	s_oncov.tile_data_map[6][3].object = TerrainTile.ObjectType.COVER  # tile do ALVO
	s_oncov.enter_attack_mode(10, false)
	_true("alvo sobre cobertura (linha limpa) é mirável", 1 in s_oncov.attack_target_indices)
	_eq("alvo sobre cobertura rola com Desvantagem", s_oncov._get_attack_roll_mods(0, 1, 10)["dis"], 1)

	# ── 3.3 B4: Mergulhar arma (Dip) + coated_fire ───────────────────────────
	_true("Mergulhar é ação bônus", AcaoDip.new().bonus_action)
	var s_dip := BattleState.new()
	s_dip.combatant_positions[0] = Vector2i(2, 2)
	_true("dip sem superfície falha", not s_dip.resolve_dip(0))
	_eq("dip falho não reveste", s_dip.combatant_statuses[0].get("coated_fire", 0), 0)
	s_dip.tile_surfaces[Vector2i(2, 2)] = {"type": SurfaceType.Type.FIRE, "turns": 5}
	_true("dip sobre Fogo reveste a arma", s_dip.resolve_dip(0))
	_eq("dip concede 3 cargas", s_dip.combatant_statuses[0].get("coated_fire", 0), 3)

	# Ataque com arma sob coated_fire soma +1d4 e gasta uma carga.
	var s_coat_off := BattleState.new()
	s_coat_off.active_index = 0
	s_coat_off._current_action = AtqNormal.new()
	s_coat_off.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_coat_off.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(15))
	s_coat_off._apply_attack(1)
	var dmg_coat_off: int = s_coat_off.last_attack_info.get("amount", 0)

	var s_coat_on := BattleState.new()
	s_coat_on.active_index = 0
	s_coat_on._current_action = AtqNormal.new()
	s_coat_on.combatant_statuses[0]["coated_fire"] = 2
	s_coat_on.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_coat_on.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(15))
	s_coat_on._apply_attack(1)
	var coat_delta: int = s_coat_on.last_attack_info.get("amount", 0) - dmg_coat_off
	_true("coated_fire soma +1..4 no ataque com arma", coat_delta >= 1 and coat_delta <= 4)
	_eq("coated_fire decrementa carga (2->1)", s_coat_on.combatant_statuses[0].get("coated_fire", 0), 1)

	# ── 3.3 B3: Pular (Jump) ─────────────────────────────────────────────────
	_true("Pular é ação bônus", AcaoPular.new().bonus_action)
	var s_jump := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		s_jump.combatant_positions[i] = Vector2i(i, 6)
	s_jump.combatant_positions[0] = Vector2i(1, 1)
	s_jump.tile_data_map[2][1].ground = TerrainTile.GroundType.VOID  # atravessa
	var mp_before: int = s_jump.move_points_remaining
	_true("jump atravessa void e pousa em tile válido", s_jump.resolve_jump(0, Vector2i(3, 1)))
	_eq("jump moveu para o tile de pouso", s_jump.combatant_positions[0], Vector2i(3, 1))
	_true("jump NAO seta disengage (provoca OA agora)", not s_jump.combatant_statuses[0].get("disengage", false))
	_true("jump consome deslocamento", s_jump.move_points_remaining < mp_before)

	# Pouso inválido (void/obstáculo) é rejeitado.
	var s_jump_bad := BattleState.new()
	s_jump_bad.combatant_positions[0] = Vector2i(1, 1)
	s_jump_bad.tile_data_map[2][1].ground = TerrainTile.GroundType.VOID
	_true("jump rejeita pouso em void", not s_jump_bad.resolve_jump(0, Vector2i(2, 1)))
	s_jump_bad.tile_data_map[2][2].object = TerrainTile.ObjectType.OBSTACLE
	_true("jump rejeita pouso em obstáculo", not s_jump_bad.resolve_jump(0, Vector2i(2, 2)))

	# Prévia do Pulo: get_jump_landing_tiles / is_valid_jump_landing.
	var s_land := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		s_land.combatant_positions[i] = Vector2i(20, 20)
	s_land.combatant_positions[0] = Vector2i(5, 3)
	s_land.tile_data_map[6][3].object = TerrainTile.ObjectType.OBSTACLE  # inválido
	s_land.tile_data_map[5][4].ground = TerrainTile.GroundType.VOID       # inválido
	s_land.combatant_positions[1] = Vector2i(4, 3)                        # ocupado
	var land_tiles := s_land.get_jump_landing_tiles(0)
	_true("landing inclui (7,3) válido", Vector2i(7, 3) in land_tiles)
	_true("landing exclui obstáculo (6,3)", not (Vector2i(6, 3) in land_tiles))
	_true("landing exclui void (5,4)", not (Vector2i(5, 4) in land_tiles))
	_true("landing exclui tile ocupado (4,3)", not (Vector2i(4, 3) in land_tiles))
	_true("is_valid_jump_landing concorda com o conjunto (6,3)",
		s_land.is_valid_jump_landing(0, Vector2i(6, 3)) == (Vector2i(6, 3) in land_tiles))
	var land_reach := s_land.jump_reach(0)
	_true("landing exclui fora de alcance", not s_land.is_valid_jump_landing(0, Vector2i(5 + land_reach + 1, 3)))

	# Fix 1: Pulo (ação bônus) gasta SÓ a bônus, nunca a principal.
	var s_eco := _battlefield()
	s_eco.active_index = 0
	s_eco._current_attack_is_bonus = true          # como enter_attack_mode(is_bonus=true)
	s_eco.move_points_remaining = 6
	var dest_eco := s_eco.combatant_positions[0] + Vector2i(2, 0)
	_true("setup: pouso válido", s_eco.is_valid_jump_landing(0, dest_eco))
	_true("resolve_jump teve sucesso", s_eco.resolve_jump(0, dest_eco))
	s_eco.finalize_attack()
	_true("Pulo NÃO gasta a Ação principal", not s_eco.has_attacked)
	_true("Pulo gasta a Ação Bônus", s_eco.has_used_bonus_action)

	# Fix 2: custo de movimento FIXO (2), independente da distância.
	var s_cost := _battlefield()
	s_cost.active_index = 0
	s_cost.move_points_remaining = 5
	var dest_cost := s_cost.combatant_positions[0] + Vector2i(3, 0)   # d=3
	_true("pouso d=3 válido", s_cost.is_valid_jump_landing(0, dest_cost))
	_true("resolve_jump ok", s_cost.resolve_jump(0, dest_cost))
	_eq("Pulo custa 2 de movimento (fixo)", s_cost.move_points_remaining, 3)

	# Fix 2: sem movimento suficiente (<2) o Pulo é bloqueado.
	var s_nomove := _battlefield()
	s_nomove.active_index = 0
	s_nomove.move_points_remaining = 1
	_true("Pulo bloqueado com <2 de movimento",
		not s_nomove.resolve_jump(0, s_nomove.combatant_positions[0] + Vector2i(2, 0)))

	# Fix 2: alcance ancorado no BG3 (FOR 10 -> 3 tiles; FOR 20 -> 6 tiles).
	# Estado estático isolado (save/restore) para não vazar para outros testes.
	var saved_players := BattleState.PLAYERS
	var saved_queue := BattleState.TURN_QUEUE
	BattleState.setup_party(["Guerreiro"])
	var s_reach := BattleState.new()
	BattleState.PLAYERS[0]["strength"] = 10
	_eq("FOR 10 -> alcance 3 tiles", s_reach.jump_reach(0), 3)
	BattleState.PLAYERS[0]["strength"] = 20
	_eq("FOR 20 -> alcance 6 tiles", s_reach.jump_reach(0), 6)
	BattleState.PLAYERS = saved_players
	BattleState.TURN_QUEUE = saved_queue

	# Item 1: Pular para fora do alcance de um inimigo adjacente PROVOCA OA.
	var s_jump_oa := _battlefield()
	s_jump_oa.active_index = 0
	s_jump_oa.combatant_positions[0] = Vector2i(5, 3)
	s_jump_oa.combatant_positions[1] = Vector2i(6, 3)            # inimigo adjacente
	s_jump_oa.move_points_remaining = 6
	var jump_oa_from := s_jump_oa.combatant_positions[0]
	_true("jump válido", s_jump_oa.resolve_jump(0, Vector2i(8, 3)))   # sai do alcance
	var jump_oa_list := s_jump_oa.check_opportunity_attacks(0, jump_oa_from, s_jump_oa.combatant_positions[0])
	_true("Pulo dispara OA do inimigo adjacente", 1 in jump_oa_list)

	# Desengajar continua evitando OA no mesmo deslocamento.
	var s_jump_diseng := _battlefield()
	s_jump_diseng.active_index = 0
	s_jump_diseng.combatant_positions[0] = Vector2i(5, 3)
	s_jump_diseng.combatant_positions[1] = Vector2i(6, 3)
	s_jump_diseng.apply_disengage(0)                              # isenta adjacentes
	var jump_diseng_oa := s_jump_diseng.check_opportunity_attacks(0, Vector2i(5, 3), Vector2i(8, 3))
	_true("Desengajar evita OA", jump_diseng_oa.is_empty())

	# Item 4: acoes taticas universais sao classificadas a ESQUERDA.
	var ap_cls := ActionPanel.new()
	for ua in [AcaoEmpurrar.new(), AcaoPular.new(), SkillAjuda.new(), AcaoArremessar.new(), AcaoDip.new(), AcaoEsconder.new()]:
		_true("%s vai p/ esquerda" % ua.label, ap_cls._is_universal_left(ua))
	_true("magia NAO e universal-left", not ap_cls._is_universal_left(SpellFogo.new()))
	var cls_l: Array = []
	var cls_r: Array = []
	ap_cls._classify(AcaoDip.new(), cls_l, cls_r)   # Dip e bonus, mas e universal
	_true("Dip classificado a esquerda", cls_l.size() == 1 and cls_r.is_empty())
	ap_cls.free()

	# Item 3: slots esparsos — acao fixa no slot escolhido (sem _state/arvore).
	var ap_slot := ActionPanel.new()
	ap_slot._place_action("Empurrar", "left", 0, "left", 5)
	_eq("acao fixa no slot vazio 5", int(ap_slot._slot_assign["Empurrar"]["slot"]), 5)
	_eq("acao fixa no lado left", String(ap_slot._slot_assign["Empurrar"]["side"]), "left")
	ap_slot._place_action("Pular", "left", 1, "right", 2)
	_eq("acao movida para a direita", String(ap_slot._slot_assign["Pular"]["side"]), "right")
	_eq("acao no slot 2 da direita", int(ap_slot._slot_assign["Pular"]["slot"]), 2)
	_eq("primeiro livre pula ocupados", ap_slot._first_free_slot({0: 1, 1: 1}, 4), 2)
	ap_slot.free()

	# ── 3.3 B5: Arremessar (Throw) ───────────────────────────────────────────
	_eq("Arremessar cria superfície FIRE (dado do item)", AcaoArremessar.new().creates_surface, SurfaceType.Type.FIRE)

	# Throw de item de fogo cria superfície FIRE no tile-alvo.
	var s_throw := BattleState.new()
	s_throw.active_index = 0
	for i in range(BattleState.TURN_QUEUE.size()):
		s_throw.combatant_positions[i] = Vector2i(i, 0)
	var throw_item := ActionData.new()
	throw_item.aoe_radius = 1
	throw_item.creates_surface = SurfaceType.Type.FIRE
	throw_item.damage_type = ActionData.DamageType.FIRE
	throw_item.damage_dice_count = 0
	s_throw.resolve_throw(Vector2i(5, 5), throw_item)
	_eq("throw cria superfície FIRE no tile", s_throw.tile_surfaces.get(Vector2i(5, 5), {}).get("type", -1), SurfaceType.Type.FIRE)

	# Throw aplica a condição do item a alvos no raio.
	var s_throw_cond := BattleState.new()
	s_throw_cond.active_index = 0
	for i in range(BattleState.TURN_QUEUE.size()):
		s_throw_cond.combatant_positions[i] = Vector2i(20, 20)
	s_throw_cond.combatant_positions[1] = Vector2i(5, 5)
	s_throw_cond.enemy_hp["Goblin Scout"] = 200
	var throw_cond := ActionData.new()
	throw_cond.aoe_radius = 1
	throw_cond.applies_condition = "blinded"
	throw_cond.condition_duration = 2
	throw_cond.damage_dice_count = 0
	s_throw_cond.resolve_throw(Vector2i(5, 5), throw_cond)
	_true("throw aplica condição em alvo no raio", s_throw_cond.combatant_statuses[1].get("blinded", 0) > 0)

	# Task 1: novos ataques
	var arcano := AtqArcano.new()
	_eq("AtqArcano label", arcano.label, "Raio Arcano")
	_eq("AtqArcano damage_attribute is INT", arcano.damage_attribute, ActionData.DamageAttribute.INT)
	_eq("AtqArcano attack_range", arcano.attack_range, 10)  # 50 ft / 5 (D&D 5e tile scale)

	var divino := AtqDivino.new()
	_eq("AtqDivino label", divino.label, "Atq. Divino")
	_eq("AtqDivino damage_attribute is WIS", divino.damage_attribute, ActionData.DamageAttribute.WIS)
	_eq("AtqDivino attack_range", divino.attack_range, 1)

	var soco := AtqSoco.new()
	_eq("AtqSoco label", soco.label, "Soco")
	_eq("AtqSoco damage_attribute is DEX", soco.damage_attribute, ActionData.DamageAttribute.DEX)
	_eq("AtqSoco dice sides", soco.damage_dice_sides, 6)

	# Task 2: skills
	var sv := SkillSegundoVento.new()
	_eq("SkillSegundoVento label", sv.label, "Segundo Vento")
	_eq("SkillSegundoVento pp", sv.pp, 1)
	_eq("SkillSegundoVento max_pp", sv.max_pp, 1)
	_eq("SkillSegundoVento action_type is END_TURN", sv.action_type, ActionData.Type.END_TURN)

	var cf := SkillChuvaFlechas.new()
	_eq("SkillChuvaFlechas label", cf.label, "Chuva de Flechas")
	_eq("SkillChuvaFlechas spell_slot_level", cf.spell_slot_level, 2)
	_eq("SkillChuvaFlechas aoe_radius", cf.aoe_radius, 1)
	_eq("SkillChuvaFlechas damage_attribute is DEX", cf.damage_attribute, ActionData.DamageAttribute.DEX)

	var ca := SkillCuraArea.new()
	_eq("SkillCuraArea label", ca.label, "Cura em Área")
	_eq("SkillCuraArea targets_allies", ca.targets_allies, true)
	_eq("SkillCuraArea spell_slot_level", ca.spell_slot_level, 2)

	# Task 3: HeroData arrays
	var hd := HeroData.new()
	_true("HeroData.actions exists and is empty", hd.actions.is_empty())
	_true("HeroData.skills exists and is empty",  hd.skills.is_empty())

	# Task 4: Guerreiro e Mago actions
	var g_data: HeroData = BattleState.ALL_HERO_DATA["Guerreiro"]
	_true("Guerreiro actions has AtqNormal",       g_data.actions.size() >= 1 and g_data.actions[0] is AtqNormal)
	_true("Guerreiro actions has AcaoMover last",  g_data.actions.size() >= 2 and g_data.actions[g_data.actions.size()-1] is AcaoMover)
	_true("Guerreiro skills has SkillSegundoVento", g_data.skills.size() == 2 and g_data.skills[0] is SkillSegundoVento)
	_true("Guerreiro skills has SkillAjuda",         g_data.skills.size() == 2 and g_data.skills[1] is SkillAjuda)

	var m_data: HeroData = BattleState.ALL_HERO_DATA["Mago"]
	_true("Mago actions has AtqArcano",  m_data.actions.size() >= 1 and m_data.actions[0] is AtqArcano)
	_true("Mago skills has 5 items",     m_data.skills.size() == 5)
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
	# +2: Dash e Desengajar sao inseridos em tab_action para todos os herois
	_true("tab_action at start matches Guerreiro actions (+Dash +Desengajar)",
		s7.tab_action.size() == BattleState.ALL_HERO_DATA["Guerreiro"].actions.size() + 2)
	_true("tab_action[0] is AtqNormal for Guerreiro",
		s7.tab_action[0] is AtqNormal)
	# advance to Mago (TURN_QUEUE[2] = Mago, need 2 advance_turns)
	s7.advance_turn()  # goes to TURN_QUEUE[1] = Goblin Scout (enemy)
	s7.advance_turn()  # goes to TURN_QUEUE[2] = Mago (player)
	_true("tab_action after 2 advances matches Mago actions (+Dash +Desengajar)",
		s7.tab_action.size() == BattleState.ALL_HERO_DATA["Mago"].actions.size() + 2)
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
	_eq("SkillSmite spell_slot_level", sm.spell_slot_level, 1)
	_eq("SkillSmite action_type is ATTACK", sm.action_type, ActionData.Type.ATTACK)
	_eq("SkillSmite attack_range is 1", sm.attack_range, 1)
	_eq("SkillSmite smite_dice_count is 2", sm.smite_dice_count, 2)
	_eq("SkillSmite smite_dice_sides is 8", sm.smite_dice_sides, 8)
	_true("SkillSmite is_weapon_attack", sm.is_weapon_attack)

	var cm := SkillCuraMaos.new()
	_eq("SkillCuraMaos label", cm.label, "Cura das Mãos")
	_eq("SkillCuraMaos spell_slot_level", cm.spell_slot_level, 1)
	_eq("SkillCuraMaos targets_allies", cm.targets_allies, true)
	_eq("SkillCuraMaos damage_attribute is WIS", cm.damage_attribute, ActionData.DamageAttribute.WIS)
	_eq("SkillCuraMaos dice count", cm.damage_dice_count, 2)
	_eq("SkillCuraMaos dice sides", cm.damage_dice_sides, 8)

	# Task 2: PaladinoData stats e actions
	var pal_data: HeroData = BattleState.ALL_HERO_DATA.get("Paladino", null)
	_true("ALL_HERO_DATA contains Paladino", pal_data != null)
	_eq("Paladino strength is 16",    pal_data.strength,   16)
	_eq("Paladino wisdom is 14",      pal_data.wisdom,     14)
	_eq("Paladino max_hp is 110",     pal_data.max_hp,     110)
	_eq("Paladino spell_slots lv4",   pal_data.get_spell_slots_max(), [3, 0, 0, 0, 0, 0])
	_eq("Paladino class is Paladin",  pal_data.hero_class, "Paladin")
	_eq("Paladino ac is 16",          pal_data.ac,         16)
	_eq("Paladino speed is 6",        pal_data.speed,      6)
	_true("Paladino actions[0] is AtqDivino",    pal_data.actions.size() >= 1 and pal_data.actions[0] is AtqDivino)
	_true("Paladino actions[1] is AcaoMover",    pal_data.actions.size() >= 2 and pal_data.actions[1] is AcaoMover)
	_true("Paladino skills[0] is SkillSmite",    pal_data.skills.size() >= 1 and pal_data.skills[0] is SkillSmite)
	_true("Paladino skills[1] is SkillCuraMaos", pal_data.skills.size() >= 2 and pal_data.skills[1] is SkillCuraMaos)

	# Task 3: SkillSmite agora é ataque melee que soma dano radiante (estilo BG3).
	# smite em _apply_attack — adiciona dano radiante e popula last_attack_info.
	# Isolamos o bônus via delta entre AtqNormal e SkillSmite com a mesma seed.
	var s_smite_off := BattleState.new()
	s_smite_off.active_index = 0
	s_smite_off._current_action = AtqNormal.new()
	s_smite_off.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_smite_off.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(15))
	s_smite_off._apply_attack(1)
	var dmg_no_smite: int = s_smite_off.last_attack_info.get("amount", 0)

	var s_pal := BattleState.new()
	s_pal.active_index = 0
	s_pal._current_action = SkillSmite.new()
	s_pal.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_pal.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(15))
	s_pal._apply_attack(1)  # ataca Goblin Scout (TURN_QUEUE[1])
	var smite_amount: int = s_pal.last_attack_info.get("smite_amount", 0)
	_true("smite_amount in [2,16]", smite_amount >= 2 and smite_amount <= 16)
	_true("smite attack registered hit", s_pal.last_attack_info.get("hit", false))
	var smite_delta: int = s_pal.last_attack_info.get("amount", 0) - dmg_no_smite
	_true("smite adds bonus damage in [2,16]", smite_delta >= 2 and smite_delta <= 16)

	# Task 3: is_item_available bloqueia SkillSmite quando não há spell slots
	var s_mp := BattleState.new()
	var saved_slots_g: Array = BattleState.PLAYERS[0]["spell_slots"].duplicate()
	BattleState.PLAYERS[0]["spell_slots"] = [0, 0, 0, 0, 0, 0]
	var sm2 := SkillSmite.new()
	_true("SkillSmite unavailable sem spell slots",
		  not s_mp.is_item_available(sm2))
	BattleState.PLAYERS[0]["spell_slots"] = [1, 0, 0, 0, 0, 0]
	_true("SkillSmite available com 1 slot nv.1",
		  s_mp.is_item_available(sm2))
	BattleState.PLAYERS[0]["spell_slots"] = saved_slots_g  # restaurar

	# ── Monge tests ─────────────────────────────────────────────────────────────

	# Task 1: SkillFlurry (ataque multi-hit) e SkillPassoVento
	var fl := SkillFlurry.new()
	_eq("SkillFlurry label", fl.label, "Flurry of Blows")
	_eq("SkillFlurry ki_cost", fl.ki_cost, 1)
	_eq("SkillFlurry spell_slot_level is 0", fl.spell_slot_level, 0)
	_eq("SkillFlurry action_type is ATTACK", fl.action_type, ActionData.Type.ATTACK)
	_eq("SkillFlurry hit_count is 2", fl.hit_count, 2)
	_true("SkillFlurry is bonus_action", fl.bonus_action)
	_eq("SkillFlurry damage dice", fl.damage_dice_count, 1)
	_eq("SkillFlurry damage sides", fl.damage_dice_sides, 6)
	_eq("SkillFlurry damage attr is DEX", fl.damage_attribute, ActionData.DamageAttribute.DEX)

	var pv := SkillPassoVento.new()
	_eq("SkillPassoVento label", pv.label, "Passo do Vento")
	_eq("SkillPassoVento ki_cost", pv.ki_cost, 1)
	_eq("SkillPassoVento action_type is END_TURN", pv.action_type, ActionData.Type.END_TURN)

	# Task 2: MongeData stats e actions
	var monk_data: HeroData = BattleState.ALL_HERO_DATA.get("Monge", null)
	_true("ALL_HERO_DATA contains Monge", monk_data != null)
	_eq("Monge dexterity is 18",   monk_data.dexterity,  18)
	_eq("Monge max_hp is 90",      monk_data.max_hp,     90)
	_eq("Monge ki_max lv4",        monk_data.ki_max(),   4)
	_eq("Monge spell_slots lv4",   monk_data.get_spell_slots_max(), [0, 0, 0, 0, 0, 0])
	_eq("Monge speed is 10",       monk_data.speed,      10)
	_eq("Monge class is Monk",     monk_data.hero_class, "Monk")
	_true("Monge actions[0] is AtqSoco",       monk_data.actions.size() >= 1 and monk_data.actions[0] is AtqSoco)
	_true("Monge actions[1] is AtqRapido",     monk_data.actions.size() >= 2 and monk_data.actions[1] is AtqRapido)
	_true("Monge actions[2] is AcaoMover",     monk_data.actions.size() >= 3 and monk_data.actions[2] is AcaoMover)
	_true("Monge skills[0] is SkillFlurry",    monk_data.skills.size() >= 1 and monk_data.skills[0] is SkillFlurry)
	_true("Monge skills[1] is SkillPassoVento", monk_data.skills.size() >= 2 and monk_data.skills[1] is SkillPassoVento)

	# Task 3: is_item_available do SkillFlurry — como no BG3, é uma AÇÃO BÔNUS
	# que gasta 1 Ki. Disponível no início do turno; bloqueada sem Ki ou após a
	# ação bônus já ter sido usada.
	var s_ki := BattleState.new()
	s_ki.active_index = 0
	var fl2 := SkillFlurry.new()

	BattleState.PLAYERS[0]["ki"] = 0
	_true("SkillFlurry unavailable when Ki=0",
		  not s_ki.is_item_available(fl2))

	BattleState.PLAYERS[0]["ki"] = 1
	_true("SkillFlurry available when Ki>=1", s_ki.is_item_available(fl2))

	# É ação bônus: continua disponível mesmo após o ataque principal.
	s_ki.has_attacked = true
	_true("SkillFlurry still available after main attack (bonus action)",
		  s_ki.is_item_available(fl2))

	# Indisponível depois de gastar a ação bônus.
	s_ki.has_used_bonus_action = true
	_true("SkillFlurry unavailable after bonus action spent",
		  not s_ki.is_item_available(fl2))

	BattleState.PLAYERS[0]["ki"] = 0  # restaurar

	# Regressão: finalize_attack de uma AÇÃO BÔNUS não pode consumir a ação
	# principal (has_attacked deve continuar false; só has_used_bonus_action).
	var s_bonus := BattleState.new()
	s_bonus._current_attack_is_bonus = true
	s_bonus.finalize_attack()
	_true("Bonus action does NOT consume main action", not s_bonus.has_attacked)
	_true("Bonus action marks bonus action used", s_bonus.has_used_bonus_action)

	# Regressão: ação principal marca has_attacked e não toca na ação bônus.
	var s_main := BattleState.new()
	s_main._current_attack_is_bonus = false
	s_main.finalize_attack()
	_true("Main action consumes main action", s_main.has_attacked)
	_true("Main action leaves bonus action available", not s_main.has_used_bonus_action)

	# --- DungeonState tests ---
	var ds := DungeonState.new()
	ds.generate(42)

	var ds_floor_counts: Dictionary = {}
	for dn in ds.nodes:
		ds_floor_counts[dn.floor_idx] = ds_floor_counts.get(dn.floor_idx, 0) + 1
	_eq("DungeonState: floor 0 has 1 node",  ds_floor_counts.get(0, 0), 1)
	_eq("DungeonState: floor final has 1 node",  ds_floor_counts.get(ds.floor_count - 1, 0), 1)
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
		if dn.floor_idx == ds.floor_count - 1 and dn.type != DungeonState.RoomType.BOSS:
			ds_boss_ok = false
	_true("DungeonState: floor final node is BOSS", ds_boss_ok)

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

	# ── Examine: HeroData new fields ────────────────────────────────────────────
	var hd_new := HeroData.new()
	_eq("HeroData charisma default is 10",           hd_new.charisma,    10)
	_true("HeroData resistances default empty",      hd_new.resistances.is_empty())
	_true("HeroData passive_features default empty", hd_new.passive_features.is_empty())
	var g_dict: Dictionary = BattleState.ALL_HERO_DATA["Guerreiro"].to_combat_dict()
	_true("to_combat_dict has charisma",             g_dict.has("charisma"))
	_true("to_combat_dict has resistances",          g_dict.has("resistances"))
	_true("to_combat_dict has passive_features",     g_dict.has("passive_features"))
	_true("HeroData vulnerabilities default empty",  hd_new.vulnerabilities.is_empty())
	_true("HeroData immunities default empty",       hd_new.immunities.is_empty())
	_true("to_combat_dict has vulnerabilities",      g_dict.has("vulnerabilities"))
	_true("to_combat_dict has immunities",           g_dict.has("immunities"))
	_true("HeroData.to_combat_dict has crit_threshold", g_dict.has("crit_threshold"))
	_true("HeroData.to_combat_dict has weapon",         g_dict.has("weapon"))
	var guerreiro_data: HeroData = BattleState.ALL_HERO_DATA["Guerreiro"]
	_true("Guerreiro weapon is WeaponData", guerreiro_data.weapon != null)
	_eq("Guerreiro weapon dice sides", guerreiro_data.weapon.damage_dice_sides, 8)

	# ── Examine: Hero charisma values ───────────────────────────────────────────
	_eq("Guerreiro charisma is 10", BattleState.ALL_HERO_DATA["Guerreiro"].charisma,  10)
	_eq("Paladino charisma is 16",  BattleState.ALL_HERO_DATA["Paladino"].charisma,   16)
	_eq("Ladrao charisma is 15",    BattleState.ALL_HERO_DATA["Ladrao"].charisma,     15)
	_eq("Bárbaro charisma is 8",    BattleState.ALL_HERO_DATA["Bárbaro"].charisma,    8)
	_eq("Clérigo charisma is 13",   BattleState.ALL_HERO_DATA["Clérigo"].charisma,    13)

	# ── Examine: EnemyData new fields ───────────────────────────────────────────
	var ed_new := EnemyData.new()
	_eq("EnemyData level default is 1",     ed_new.level,      1)
	_eq("EnemyData strength default is 10", ed_new.strength,   10)
	_eq("EnemyData charisma default is 10", ed_new.charisma,   10)
	_true("EnemyData resistances default empty",      ed_new.resistances.is_empty())
	_true("EnemyData passive_features default empty", ed_new.passive_features.is_empty())
	var goblin_ed: EnemyData = BattleState.ALL_ENEMIES["Goblin"]
	var g_edict := goblin_ed.to_combat_dict()
	_true("EnemyData.to_combat_dict has level",           g_edict.has("level"))
	_true("EnemyData.to_combat_dict has strength",        g_edict.has("strength"))
	_true("EnemyData.to_combat_dict has resistances",     g_edict.has("resistances"))
	_true("EnemyData.to_combat_dict has passive_features",g_edict.has("passive_features"))
	_true("EnemyData vulnerabilities default empty",      ed_new.vulnerabilities.is_empty())
	_true("EnemyData immunities default empty",           ed_new.immunities.is_empty())
	_true("EnemyData.to_combat_dict has vulnerabilities", g_edict.has("vulnerabilities"))
	_true("EnemyData.to_combat_dict has immunities",      g_edict.has("immunities"))
	_true("EnemyData.to_combat_dict has proficiency",          g_edict.has("proficiency"))
	_true("EnemyData.to_combat_dict has crit_threshold",       g_edict.has("crit_threshold"))
	_true("EnemyData.to_combat_dict has damage_dice_count",    g_edict.has("damage_dice_count"))
	_true("EnemyData.to_combat_dict has damage_dice_sides",    g_edict.has("damage_dice_sides"))
	_true("EnemyData.to_combat_dict has attack_damage_attribute", g_edict.has("attack_damage_attribute"))

	# ── Examine: Enemy attribute values ─────────────────────────────────────────
	_eq("GoblinScout level is 1",         BattleState.ALL_ENEMIES["Goblin"].level,            1)
	_eq("GoblinScout dexterity is 14",    BattleState.ALL_ENEMIES["Goblin"].dexterity,        14)
	_eq("OrcWarrior level is 3",          BattleState.ALL_ENEMIES["Orc"].level,               3)
	_eq("OrcWarrior strength is 16",      BattleState.ALL_ENEMIES["Orc"].strength,            16)
	_eq("DarkMage level is 4",            BattleState.ALL_ENEMIES["Mage"].level,              4)
	_eq("DarkMage intelligence is 16",    BattleState.ALL_ENEMIES["Mage"].intelligence,       16)
	_eq("SkeletonArcher level is 2",      BattleState.ALL_ENEMIES["Undead"].level,            2)
	_eq("SkeletonArcher dexterity is 14", BattleState.ALL_ENEMIES["Undead"].dexterity,        14)
	_eq("EliteWarrior level is 5",        BattleState.ALL_ENEMIES["EliteWarrior"].level,      5)
	_eq("EliteWarrior strength is 18",    BattleState.ALL_ENEMIES["EliteWarrior"].strength,   18)
	_eq("EliteMage level is 5",           BattleState.ALL_ENEMIES["EliteMage"].level,         5)
	_eq("EliteMage intelligence is 18",   BattleState.ALL_ENEMIES["EliteMage"].intelligence,  18)
	_eq("DungeonGuardian level is 8",     BattleState.ALL_ENEMIES["DungeonGuardian"].level,   8)
	_eq("DungeonGuardian strength is 20", BattleState.ALL_ENEMIES["DungeonGuardian"].strength,20)

	# ── Examine: TurnOrderBar right-click signal ─────────────────────────────────
	var tob := TurnOrderBar.new()
	_true("TurnOrderBar has slot_right_clicked signal",
		tob.has_signal("slot_right_clicked"))
	tob.free()

	# ── Examine: ContextMenu signal ──────────────────────────────────────────────
	var ctx := ContextMenu.new()
	_true("ContextMenu has examine_requested signal",
		ctx.has_signal("examine_requested"))
	ctx.free()

	# ── Examine: ExaminePanel instantiation ─────────────────────────────────────
	var ep := ExaminePanel.new()
	_true("ExaminePanel can be instantiated", ep != null)
	ep._ready()   # _ready() constrói o painel e o esconde (visible=false) por padrão
	_true("ExaminePanel is not visible by default", not ep.visible)
	_true("ExaminePanel tem caixa de Vulnerabilidades", ep._vulnerabilities_box != null)
	_true("ExaminePanel tem caixa de Imunidades",       ep._immunities_box != null)
	ep.free()

	# ── MapLayout ───────────────────────────────────────
	var canvas := Vector2(1000, 800)
	var margin: float = MapLayout.NODE_SIZE * 0.5 + 8.0
	var c0 := MapLayout.node_center(Vector2(0.5, 0.0), canvas)
	_eq("node_center x centro", c0.x, margin + 0.5 * (canvas.x - margin * 2.0))
	_eq("node_center y topo",   c0.y, margin + 0.0 * (canvas.y - margin * 2.0))
	var c1 := MapLayout.node_center(Vector2(1.0, 1.0), canvas)
	_eq("node_center x direita", c1.x, margin + 1.0 * (canvas.x - margin * 2.0))
	_eq("node_center y base",    c1.y, margin + 1.0 * (canvas.y - margin * 2.0))

	var st := DungeonState.new()
	var na := DungeonState.RoomNode.new()
	na.id = 0; na.floor_idx = 0; na.type = DungeonState.RoomType.BATTLE
	na.position = Vector2(0.25, 0.0)
	var nb := DungeonState.RoomNode.new()
	nb.id = 1; nb.floor_idx = 1; nb.type = DungeonState.RoomType.BATTLE
	nb.position = Vector2(0.75, 0.5)
	st.nodes = [na, nb]
	var center_a := MapLayout.node_center(na.position, canvas)
	_eq("node_id_at acerta nó A no centro", MapLayout.node_id_at(st, center_a, canvas), 0)
	_eq("node_id_at acerta nó A na borda interna",
		MapLayout.node_id_at(st, center_a + Vector2(MapLayout.NODE_SIZE * 0.4, 0), canvas), 0)
	_eq("node_id_at erra no vazio",
		MapLayout.node_id_at(st, Vector2(5, 5), canvas), -1)

	var L_a := DungeonState.RoomNode.new()
	L_a.id = 0; L_a.completed = true; L_a.connections = [1]
	var L_b := DungeonState.RoomNode.new()
	L_b.id = 1; L_b.completed = true; L_b.connections = [2, 3]
	var L_c := DungeonState.RoomNode.new()
	L_c.id = 2; L_c.completed = false; L_c.connections = []
	var L_d := DungeonState.RoomNode.new()
	L_d.id = 3; L_d.completed = false; L_d.connections = []
	var lst := DungeonState.new()
	lst.nodes = [L_a, L_b, L_c, L_d]
	lst.current_node_id = 2
	var lit := MapLayout.lit_connections(lst)
	_true("aresta 0:1 acesa (A->B completos)", lit.has("0:1"))
	_true("aresta 1:2 acesa (B completo -> C atual)", lit.has("1:2"))
	_eq("aresta 1:3 NÃO acesa (galho abandonado)", lit.has("1:3"), false)
	_eq("total de arestas acesas", lit.size(), 2)

	var P := DungeonState.new()
	var p0 := DungeonState.RoomNode.new(); p0.id = 0; p0.floor_idx = 0
	var p1 := DungeonState.RoomNode.new(); p1.id = 1; p1.floor_idx = 2
	P.nodes = [p0, p1]
	P.current_node_id = -1
	var prog0 := MapLayout.run_progress(P)
	_eq("progresso inicial andar 1", prog0["current_floor"], 1)
	_eq("progresso nao expoe total", prog0.has("total_floors"), false)
	P.current_node_id = 1
	var prog1 := MapLayout.run_progress(P)
	_eq("progresso no nó floor_idx=2 => andar 3", prog1["current_floor"], 3)

	var band0 := MapLayout.floor_band_rect(0, canvas, DungeonState.FLOOR_COUNT)
	_eq("faixa do andar 0 começa em y=0", band0.position.y, 0.0)
	var bandLast := MapLayout.floor_band_rect(DungeonState.FLOOR_COUNT - 1, canvas, DungeonState.FLOOR_COUNT)
	_eq("faixa do último andar termina na base",
		bandLast.position.y + bandLast.size.y, canvas.y)

	_eq("rótulo andar 0", MapLayout.floor_label(0, DungeonState.FLOOR_COUNT), "Andar 1")
	_eq("rótulo último andar", MapLayout.floor_label(DungeonState.FLOOR_COUNT - 1, DungeonState.FLOOR_COUNT), "Boss")

	# ── DungeonState.apply_rest_heal ────────────────────
	var rh_players := [
		{"name": "A", "hp": 40, "max_hp": 100},   # cura +30 → 70
		{"name": "B", "hp": 90, "max_hp": 100},   # cura +30 mas cap em 100
		{"name": "C", "hp": 0,  "max_hp": 100},   # morto → não cura
	]
	DungeonState.apply_rest_heal(rh_players, 0.30)
	_eq("rest cura membro vivo +30%", rh_players[0]["hp"], 70)
	_eq("rest nao ultrapassa max_hp",  rh_players[1]["hp"], 100)
	_eq("rest ignora membro morto",    rh_players[2]["hp"], 0)

	# ── Geração: estrutura ──────────────────────────────
	for gen_seed in range(1, 41):
		var gds := DungeonState.new()
		gds.generate(gen_seed)
		var fc: int = gds.floor_count
		_true("seed %d: floor_count em [5,7]" % gen_seed, fc >= 5 and fc <= 7)
		var f0: Array = gds.nodes.filter(func(n): return n.floor_idx == 0)
		_eq("seed %d: 1 no no andar 0" % gen_seed, f0.size(), 1)
		_eq("seed %d: andar 0 e BATTLE" % gen_seed, f0[0].type, DungeonState.RoomType.BATTLE)
		var glast: Array = gds.nodes.filter(func(n): return n.floor_idx == fc - 1)
		_eq("seed %d: 1 no no andar final" % gen_seed, glast.size(), 1)
		_eq("seed %d: andar final e BOSS" % gen_seed, glast[0].type, DungeonState.RoomType.BOSS)
		var pre: Array = gds.nodes.filter(func(n): return n.floor_idx == fc - 2 \
			and n.type == DungeonState.RoomType.REST)
		_true("seed %d: REST no andar pre-boss" % gen_seed, pre.size() >= 1)
		var elites: Array = gds.nodes.filter(func(n): return n.type == DungeonState.RoomType.ELITE)
		_true("seed %d: >=1 ELITE" % gen_seed, elites.size() >= 1)

	# ── Geração: conexões ───────────────────────────────
	for cseed in range(1, 41):
		var cd := DungeonState.new()
		cd.generate(cseed)
		var entry_id: int = cd.nodes.filter(func(n): return n.floor_idx == 0)[0].id
		var seen := {}
		var stack := [entry_id]
		while not stack.is_empty():
			var nid: int = stack.pop_back()
			if seen.has(nid):
				continue
			seen[nid] = true
			var nn: DungeonState.RoomNode = cd.get_node_by_id(nid)
			for c in nn.connections:
				stack.append(c)
		_eq("seed %d: todos os nós alcançáveis da entrada" % cseed, seen.size(), cd.nodes.size())
		var boss_id: int = cd.nodes.filter(func(n): return n.type == DungeonState.RoomType.BOSS)[0].id
		for n: DungeonState.RoomNode in cd.nodes:
			if n.id != boss_id:
				_true("seed %d: nó %d tem saída" % [cseed, n.id], n.connections.size() >= 1)
		_true("seed %d: sem arestas cruzadas" % cseed, _no_crossings(cd))

	# ── Geração: garantias suaves + determinismo ────────
	for sseed in range(1, 41):
		var sd := DungeonState.new()
		sd.generate(sseed)
		var elite_floors := {}
		for n: DungeonState.RoomNode in sd.nodes:
			if n.type == DungeonState.RoomType.ELITE:
				elite_floors[n.floor_idx] = true
		var consec := false
		for ff in elite_floors.keys():
			if elite_floors.has(ff + 1):
				consec = true
		_true("seed %d: sem ELITE consecutivos" % sseed, not consec)
		var ev: Array = sd.nodes.filter(func(n): return n.type == DungeonState.RoomType.EVENT)
		_true("seed %d: >=1 EVENT" % sseed, ev.size() >= 1)
	var da := DungeonState.new(); da.generate(123)
	var db := DungeonState.new(); db.generate(123)
	_eq("determinismo: mesmo floor_count", da.floor_count, db.floor_count)
	_eq("determinismo: mesmo n de nós", da.nodes.size(), db.nodes.size())
	var sig_a := ""
	var sig_b := ""
	for n: DungeonState.RoomNode in da.nodes:
		sig_a += "%d:%d:%s;" % [n.id, n.type, str(n.connections)]
	for n: DungeonState.RoomNode in db.nodes:
		sig_b += "%d:%d:%s;" % [n.id, n.type, str(n.connections)]
	_eq("determinismo: mesma assinatura de grafo", sig_a, sig_b)

	# ── Save/load preserva floor_count ──────────────────
	var save_ds := DungeonState.new()
	save_ds.generate(77)
	save_ds.save()
	var loaded := DungeonState.load_save()
	_true("load_save retorna estado", loaded != null)
	_eq("save/load preserva floor_count", loaded.floor_count, save_ds.floor_count)
	DungeonState.delete_save()

	# ── Névoa: seeding na geração ───────────────────────
	var fog_gen := DungeonState.new()
	fog_gen.generate(42)
	var fog_entry: DungeonState.RoomNode = fog_gen.nodes.filter(func(n): return n.floor_idx == 0)[0]
	_true("fog: entrada revelada apos generate", fog_gen.is_revealed(fog_entry.id))
	var fog_entry_conns_hidden := true
	for c in fog_entry.connections:
		if fog_gen.is_revealed(c):
			fog_entry_conns_hidden = false
	_true("fog: conexoes da entrada ocultas ate completar", fog_entry_conns_hidden)
	var fog_far_hidden := true
	for n: DungeonState.RoomNode in fog_gen.nodes:
		if n.floor_idx >= 2 and fog_gen.is_revealed(n.id):
			fog_far_hidden = false
	_true("fog: nos de andar >=2 ocultos apos generate", fog_far_hidden)
	_eq("fog: seen_ids vazio apos generate", fog_gen.seen_ids.size(), 0)

	# ── Névoa: revelação por enter_room + helpers ───────
	var fog_walk := DungeonState.new()
	fog_walk.generate(42)
	var fw_entry: DungeonState.RoomNode = fog_walk.nodes.filter(func(n): return n.floor_idx == 0)[0]
	var fw_revealed_before: int = fog_walk.revealed_ids.size()
	# entrar numa sala NÃO revela os vizinhos (só completá-la revela)
	fog_walk.enter_room(fw_entry.id)
	var fw_conns_hidden_on_enter := true
	for c in fw_entry.connections:
		if fog_walk.is_revealed(c):
			fw_conns_hidden_on_enter = false
	_true("fog: enter_room NAO revela conexoes", fw_conns_hidden_on_enter)
	_true("fog: is_revealed(current) verdadeiro", fog_walk.is_revealed(fog_walk.current_node_id))
	# completar a sala revela os vizinhos diretos
	fog_walk.complete_current_room()
	var fw_conns_revealed := true
	for c in fw_entry.connections:
		if not fog_walk.is_revealed(c):
			fw_conns_revealed = false
	_true("fog: complete_current_room revela conexoes", fw_conns_revealed)
	# nós a 2 hops da entrada continuam ocultos
	var fw_two_hop_hidden := true
	for c in fw_entry.connections:
		var mid: DungeonState.RoomNode = fog_walk.get_node_by_id(c)
		for c2 in mid.connections:
			if fog_walk.is_revealed(c2):
				fw_two_hop_hidden = false
	_true("fog: nos a 2 hops seguem ocultos", fw_two_hop_hidden)
	# monotonicidade: nenhum id revelado some
	var fw_after: Array = fog_walk.revealed_node_ids()
	_true("fog: revelados nao diminuem", fw_after.size() >= fw_revealed_before)
	# newly_revealed vs acknowledge
	_true("fog: ha novos antes de acknowledge", fog_walk.newly_revealed_ids().size() > 0)
	fog_walk.acknowledge_revealed()
	_eq("fog: nada novo apos acknowledge", fog_walk.newly_revealed_ids().size(), 0)
	# max_revealed_floor sobe para 1 após completar a entrada
	_true("fog: max_revealed_floor >= 1 apos completar a entrada", fog_walk.max_revealed_floor() >= 1)
	DungeonState.delete_save()

	# ── Névoa: persistência round-trip ──────────────────
	var fog_save := DungeonState.new()
	fog_save.generate(42)
	var fs_entry: DungeonState.RoomNode = fog_save.nodes.filter(func(n): return n.floor_idx == 0)[0]
	fog_save.enter_room(fs_entry.id)
	fog_save.acknowledge_revealed()
	fog_save.save()
	var fog_loaded := DungeonState.load_save()
	_true("fog: load_save retorna estado", fog_loaded != null)
	if fog_loaded != null:
		_eq("fog: revealed_ids preservado", fog_loaded.revealed_ids.size(), fog_save.revealed_ids.size())
		_eq("fog: seen_ids preservado", fog_loaded.seen_ids.size(), fog_save.seen_ids.size())
		_eq("fog: nada novo apos load (ja visto)", fog_loaded.newly_revealed_ids().size(), 0)
	DungeonState.delete_save()

	# ── Névoa: save legado (sem campos) reconstrói ──────
	var legacy := DungeonState.new()
	legacy.generate(42)
	var lg_entry: DungeonState.RoomNode = legacy.nodes.filter(func(n): return n.floor_idx == 0)[0]
	legacy.current_node_id = lg_entry.id
	var lg_n0: DungeonState.RoomNode = legacy.get_node_by_id(lg_entry.id)
	lg_n0.completed = true
	# grava um JSON sem os campos "revealed"/"seen"
	var lg_dict: Dictionary = {
		"run_seed": legacy.run_seed,
		"floor_count": legacy.floor_count,
		"current_node_id": legacy.current_node_id,
		"pending_room": false,
		"party_names": [],
		"pending_buffs": [],
		"nodes": []
	}
	for n: DungeonState.RoomNode in legacy.nodes:
		(lg_dict["nodes"] as Array).append({
			"id": n.id, "floor": n.floor_idx, "type": n.type,
			"connections": n.connections.duplicate(), "completed": n.completed,
			"pos_x": n.position.x, "pos_y": n.position.y
		})
	var lg_file := FileAccess.open(DungeonState.SAVE_PATH, FileAccess.WRITE)
	lg_file.store_string(JSON.stringify(lg_dict))
	lg_file.close()
	var lg_loaded := DungeonState.load_save()
	_true("fog legado: entrada revelada", lg_loaded.is_revealed(lg_entry.id))
	_eq("fog legado: nada marcado como novo", lg_loaded.newly_revealed_ids().size(), 0)
	DungeonState.delete_save()

	# --- DiceRoller ---
	var r1 := DiceRoller.roll_d(6)
	_true("roll_d(6) in [1,6]",   r1 >= 1 and r1 <= 6)
	var r2 := DiceRoller.roll_d(20)
	_true("roll_d(20) in [1,20]", r2 >= 1 and r2 <= 20)
	var r3 := DiceRoller.roll(2, 6)
	_true("roll(2,6) in [2,12]",  r3 >= 2 and r3 <= 12)
	var r4 := DiceRoller.roll(3, 8)
	_true("roll(3,8) in [3,24]",  r4 >= 3 and r4 <= 24)

	# --- Initiative ---
	# roll_initiative() ordena o TURN_QUEUE estático; snapshot/restore para não
	# corromper a ordem padrão usada por _battlefield() em outros testes.
	var init_queue_snapshot := BattleState.TURN_QUEUE.duplicate(true)
	var init_state := _battlefield()
	init_state.roll_initiative()
	var last_roll := 999999
	var sorted_ok := true
	for entry in BattleState.TURN_QUEUE:
		var ir: int = entry.get("initiative_roll", -99)
		_true("initiative_roll set on " + str(entry["name"]), ir > -99)
		if ir > last_roll:
			sorted_ok = false
		last_roll = ir
	_true("TURN_QUEUE sorted descending by initiative_roll", sorted_ok)
	_eq("roll_initiative resets active_index to 0", init_state.active_index, 0)
	BattleState.TURN_QUEUE = init_queue_snapshot

	# --- Attack Roll pipeline (player) ---
	var atk_state := _battlefield()
	atk_state.active_index = 0  # Guerreiro
	atk_state._current_action = AtqNormal.new()
	atk_state.enter_attack_mode(10, false)  # alcance 10 cobre o Goblin em (9,1)
	atk_state.confirm_attack()
	var atk_info: Dictionary = atk_state.last_attack_info
	_true("last_attack_info has 'hit' key",          atk_info.has("hit"))
	_true("last_attack_info has 'attack_roll' key",  atk_info.has("attack_roll"))
	_true("last_attack_info has 'attack_total' key", atk_info.has("attack_total"))
	_true("last_attack_info has 'target_ac' key",    atk_info.has("target_ac"))
	_true("attack_roll is valid d20",
		  atk_info.get("attack_roll", -1) >= 0 and atk_info.get("attack_roll", -1) <= 20)
	if not atk_info.get("hit", true):
		_eq("miss yields 0 damage", atk_info.get("amount", -1), 0)
	if atk_info.get("is_crit", false):
		_true("crit requires attack_roll >= crit_threshold (default 20)",
			  atk_info.get("attack_roll", 0) >= 20)

	# nat 1 → erro crítico automático (sem dano)
	var nat1_state := _battlefield()
	nat1_state.active_index = 0
	nat1_state._current_action = AtqNormal.new()
	nat1_state.enter_attack_mode(10, false)
	seed(_find_seed_for_d20(1))
	nat1_state.confirm_attack()
	_true("nat 1 is an automatic miss", not nat1_state.last_attack_info.get("hit", true))
	_eq("nat 1 deals 0 damage", nat1_state.last_attack_info.get("amount", -1), 0)

	# nat 20 → acerto crítico (dados de dano dobrados)
	var nat20_state := _battlefield()
	nat20_state.active_index = 0
	nat20_state._current_action = AtqNormal.new()
	nat20_state.enemy_hp["Goblin Scout"] = 500
	nat20_state.enter_attack_mode(10, false)
	seed(_find_seed_for_d20(20))
	nat20_state.confirm_attack()
	_true("nat 20 is a hit",  nat20_state.last_attack_info.get("hit", false))
	_true("nat 20 is a crit", nat20_state.last_attack_info.get("is_crit", false))

	# --- Improvement 3: public attack-roll mods wrapper ---
	var s_advmods := _battlefield()
	s_advmods.combatant_statuses[0]["furtivo"] = 1   # Guerreiro (idx 0) gains advantage
	var _advmods_tgt := -1
	for _advk in range(s_advmods.TURN_QUEUE.size()):
		if not s_advmods.TURN_QUEUE[_advk]["is_player"]:
			_advmods_tgt = _advk
			break
	var _advmods_res: Dictionary = s_advmods.get_attack_roll_mods(0, _advmods_tgt, 1)
	_true("get_attack_roll_mods is public", _advmods_res.has("adv") and _advmods_res.has("dis") and _advmods_res.has("flat"))
	_true("get_attack_roll_mods reflects furtivo advantage", int(_advmods_res.get("adv", 0)) >= 1)

	# --- Attack Roll pipeline (enemy) ---
	# Goblin Scout (idx 1) ataca corpo a corpo (behavior 0, range 1) adjacente
	# ao Guerreiro (idx 0). Seed garante acerto.
	var ebs := _battlefield()
	ebs.active_index = 1                 # Goblin Scout
	ebs.active_enemy_action_idx = 0      # ataque melee (range 1)
	ebs.combatant_positions[1] = Vector2i(3, 3)  # adjacente ao Guerreiro (2,3)
	seed(_find_seed_for_d20(15))
	ebs.apply_enemy_attack()
	var einfo: Dictionary = ebs.last_attack_info
	_true("enemy last_attack_info has 'hit'",         einfo.has("hit"))
	_true("enemy last_attack_info has 'attack_roll'", einfo.has("attack_roll"))
	_true("enemy last_attack_info has 'target_ac'",   einfo.has("target_ac"))
	_true("enemy attack_roll is valid d20",
		  einfo.get("attack_roll", -1) >= 0 and einfo.get("attack_roll", -1) <= 20)
	_true("enemy hit at d20=15 vs Guerreiro", einfo.get("hit", false))

	# enemy nat 1 → miss automático (0 de dano)
	var ebs_miss := _battlefield()
	ebs_miss.active_index = 1
	ebs_miss.active_enemy_action_idx = 0
	ebs_miss.combatant_positions[1] = Vector2i(3, 3)
	seed(_find_seed_for_d20(1))
	ebs_miss.apply_enemy_attack()
	_true("enemy nat 1 is a miss", not ebs_miss.last_attack_info.get("hit", true))
	_eq("enemy nat 1 deals 0 damage", ebs_miss.last_attack_info.get("amount", -1), 0)

	# ── Melee Chebyshev (8-direction) targeting ─────────────────────────────────
	# Guerreiro at (2,3). Diagonal tiles have Chebyshev dist 1 (reachable at range 1)
	# but Manhattan dist 2 (the old, broken behavior excluded them).
	var cheb := _battlefield()
	cheb.active_index = 0
	cheb.current_attack_range = 1
	var melee_tiles := cheb.get_attack_area_tiles()
	_true("melee reaches diagonal (3,4)",        melee_tiles.has(Vector2i(3, 4)))
	_true("melee reaches diagonal (1,2)",        melee_tiles.has(Vector2i(1, 2)))
	_true("melee reaches diagonal (3,2)",        melee_tiles.has(Vector2i(3, 2)))
	_true("melee reaches diagonal (1,4)",        melee_tiles.has(Vector2i(1, 4)))
	_true("melee reaches orthogonal (2,2)",      melee_tiles.has(Vector2i(2, 2)))
	_true("melee does NOT reach (4,3) at range 1", not melee_tiles.has(Vector2i(4, 3)))

	# enter_attack_mode targets a diagonally-adjacent enemy (Chebyshev == 1)
	var cheb2 := _battlefield()
	cheb2.active_index = 0
	cheb2._current_action = AtqNormal.new()
	cheb2.combatant_positions[1] = Vector2i(1, 2)  # Goblin diagonal to Guerreiro (2,3)
	cheb2.enter_attack_mode(1, false)
	_true("melee enter_attack_mode targets diagonal enemy", cheb2.attack_target_indices.has(1))

	# Ranged (range > 1) still uses Manhattan — (4,3) is dist 2 in a straight line, reachable
	var ranged := _battlefield()
	ranged.active_index = 0
	ranged.current_attack_range = 4
	var ranged_tiles := ranged.get_attack_area_tiles()
	_true("ranged still reaches (4,3) at range 4 (Manhattan)", ranged_tiles.has(Vector2i(4, 3)))

	# ── Cover (cobertura) reads tile.object, not tile.ground ────────────────────
	# Sanity: a COVER tile is detectable on tile.object (the old _tile_at never was).
	var cov_chk := _battlefield()
	cov_chk.tile_data_map[3][3].object = TerrainTile.ObjectType.COVER
	_eq("COVER set on tile.object",
		cov_chk.tile_data_map[3][3].object, TerrainTile.ObjectType.COVER)

	# Player attack against a target on COVER agora rola com DESVANTAGEM
	# (substitui o antigo flat 30% miss).
	var cov := _battlefield()
	cov.active_index = 0
	cov._current_action = AtqNormal.new()
	cov.combatant_positions[1] = Vector2i(3, 3)            # alvo adjacente ao Guerreiro
	cov.tile_data_map[3][3].object = TerrainTile.ObjectType.COVER
	cov.enter_attack_mode(1, false)
	cov.confirm_attack()
	_eq("player attack vs COVER target rolls disadvantage",
		cov.last_attack_info.get("roll_mode", ""), "disadvantage")

	# Control: same setup WITHOUT cover rola normal.
	var nocov := _battlefield()
	nocov.active_index = 0
	nocov._current_action = AtqNormal.new()
	nocov.combatant_positions[1] = Vector2i(3, 3)
	nocov.enter_attack_mode(1, false)
	nocov.confirm_attack()
	_eq("no COVER tile → normal roll mode",
		nocov.last_attack_info.get("roll_mode", ""), "normal")

	# ── calc_hit_chance (hover preview math) ────────────────────────────────────
	var hc := _battlefield()
	hc.active_index = 0
	hc._current_action = SpellTrovao.new()  # AOE spell → auto-hit
	_eq("calc_hit_chance auto-hit (AOE) is 1.0", hc.calc_hit_chance(1), 1.0)

	hc._current_action = AtqNormal.new()
	var chance := hc.calc_hit_chance(1)
	_true("calc_hit_chance within [0.05, 0.95]", chance >= 0.05 and chance <= 0.95)

	# Higher target AC → lower (or equal, if clamped) hit chance.
	var hc2 := _battlefield()
	hc2.active_index = 0
	hc2._current_action = AtqNormal.new()
	var _ac_orig: int = BattleState.TURN_QUEUE[1].get("ac", 10)
	BattleState.TURN_QUEUE[1]["ac"] = 5
	var c_lo := hc2.calc_hit_chance(1)
	BattleState.TURN_QUEUE[1]["ac"] = 25
	var c_hi := hc2.calc_hit_chance(1)
	BattleState.TURN_QUEUE[1]["ac"] = _ac_orig  # restore shared static state
	_true("calc_hit_chance: higher AC → lower/equal chance", c_lo >= c_hi)
	_true("calc_hit_chance: very low AC clamps to 0.95", c_lo == 0.95)

	# ── TurnOrderBar HP bar helpers ─────────────────────────────────────────────
	var tob2 := TurnOrderBar.new()
	# Color thresholds: >50% green, 20–50% orange, <20% red.
	_eq("hp_color 80% is green",  tob2._hp_color(0.80), Color(0.2, 0.85, 0.2))
	_eq("hp_color 51% is green",  tob2._hp_color(0.51), Color(0.2, 0.85, 0.2))
	_eq("hp_color 50% is orange", tob2._hp_color(0.50), Color(0.95, 0.6, 0.1))
	_eq("hp_color 20% is orange", tob2._hp_color(0.20), Color(0.95, 0.6, 0.1))
	_eq("hp_color 10% is red",    tob2._hp_color(0.10), Color(0.9, 0.15, 0.15))

	# Player ratio reads static PLAYERS.
	var pl: Dictionary = BattleState.PLAYERS[0]
	var combat_p := {"name": pl["name"], "is_player": true}
	var exp_ratio := clampf(float(pl["hp"]) / maxf(float(pl["max_hp"]), 1.0), 0.0, 1.0)
	_eq("hp_ratio player matches PLAYERS", tob2._hp_ratio(combat_p, 0), exp_ratio)

	# Enemy ratio with no state falls back to a full bar.
	var combat_e := {"name": "Goblin Scout", "is_player": false, "type": "Goblin"}
	_eq("hp_ratio enemy full when no state", tob2._hp_ratio(combat_e, 1), 1.0)

	# Enemy ratio with live state reflects enemy_hp / max_hp.
	var tob_st := _battlefield()
	var gmax := tob_st.get_enemy_max_hp(1)
	tob_st.enemy_hp["Goblin Scout"] = int(gmax / 2)
	tob2._state_ref = tob_st
	var er := tob2._hp_ratio(combat_e, 1)
	_true("hp_ratio enemy with state ~0.5", absf(er - 0.5) < 0.06)
	tob2.free()

	# ── ActionTooltipPanel text builders ────────────────────────────────────────
	var tip := ActionTooltipPanel.new()
	var arc := AtqArcano.new()
	_true("tooltip damage line starts with 'Dano:'", tip._damage_text(arc).begins_with("Dano:"))
	_true("tooltip damage line names INT attribute", tip._damage_text(arc).find("INT") >= 0)
	_eq("tooltip range line for Arcano (10 tiles)", tip._range_text(arc), "Alcance: 10 tiles")
	_eq("tooltip attr name STR", tip._attr_name(ActionData.DamageAttribute.STR), "FOR")

	# Spell de dano fixo sem atributo (Nuvem de Adagas) ainda mostra os dados de dano.
	var cod_tip := SpellCloudOfDaggers.new()
	var cod_dmg := tip._damage_text(cod_tip)
	_true("tooltip CoD damage line starts with 'Dano:'", cod_dmg.begins_with("Dano:"))
	_true("tooltip CoD shows 4d4", cod_dmg.find("4d4") >= 0)
	_true("tooltip CoD has no attribute suffix", cod_dmg.find("—") < 0 and cod_dmg.find("+ ") < 0)

	# Heal action: damage line is framed as "Cura:" and has no attack range line.
	var cura := SpellCura.new()
	_true("tooltip heal line starts with 'Cura:'", tip._damage_text(cura).begins_with("Cura:"))

	# Movement action: no damage and no range line.
	var mover := AcaoMover.new()
	_eq("tooltip no damage for MOVE action", tip._damage_text(mover), "")
	_eq("tooltip no range for MOVE action",  tip._range_text(mover), "")
	tip.free()

	# ── TurnOrderBar HP values (number label "cur/max") ─────────────────────────
	var tob3 := TurnOrderBar.new()
	var pl2: Dictionary = BattleState.PLAYERS[0]
	var hv := tob3._hp_values({"name": pl2["name"], "is_player": true}, 0)
	_eq("hp_values player cur matches PLAYERS", hv.x, int(pl2["hp"]))
	_eq("hp_values player max matches PLAYERS", hv.y, int(pl2["max_hp"]))
	# Enemy with live state.
	var tob3_st := _battlefield()
	var gmx := tob3_st.get_enemy_max_hp(1)
	tob3_st.enemy_hp["Goblin Scout"] = 7
	tob3._state_ref = tob3_st
	var hve := tob3._hp_values({"name": "Goblin Scout", "is_player": false, "type": "Goblin"}, 1)
	_eq("hp_values enemy cur from state", hve.x, 7)
	_eq("hp_values enemy max from EnemyData", hve.y, gmx)
	tob3.free()

	# ── EnemyInfoPanel (Element B) helpers ──────────────────────────────────────
	var eip := EnemyInfoPanel.new()
	_eq("enemy_info hp_color 80% green",  eip._hp_color(0.80), Color(0.3, 0.95, 0.3))
	_eq("enemy_info hp_color 30% orange", eip._hp_color(0.30), Color(0.95, 0.7, 0.2))
	_eq("enemy_info hp_color 5% red",     eip._hp_color(0.05), Color(0.95, 0.35, 0.35))
	_eq("enemy_info portrait null for unknown enemy",
		eip._get_portrait({"name": "Nobody", "is_player": false, "type": "DoesNotExist"}), null)
	eip.free()

	# ── Miss indicators (floater text) ──────────────────────────────────────────
	var fm := FloaterManager.new()
	_true("FloaterManager has spawn_text", fm.has_method("spawn_text"))
	_eq("COLOR_CRIT_MISS is red", FloaterManager.COLOR_CRIT_MISS, Color(0.95, 0.20, 0.20))
	fm.free()

	# A natural-1 attack produces the data that drives the red "Critical Miss!"
	# floater: a 0-damage miss with attack_roll == 1.
	var critm := _battlefield()
	critm.active_index = 0
	critm._current_action = AtqNormal.new()
	critm.combatant_positions[1] = Vector2i(3, 3)  # Goblin adjacent (melee range 1)
	critm.enter_attack_mode(1, false)
	seed(_find_seed_for_d20(1))
	critm.confirm_attack()
	_true("crit-miss: hit is false",     not critm.last_attack_info.get("hit", true))
	_eq("crit-miss: attack_roll is 1",   critm.last_attack_info.get("attack_roll", -1), 1)
	_eq("crit-miss: amount is 0",        critm.last_attack_info.get("amount", -1), 0)

	# ── TurnOrderBar skips dead combatants ──────────────────────────────────────
	var tob_dead := TurnOrderBar.new()
	tob_dead._build_panel()  # build _hbox without needing the scene tree
	var fake_queue: Array = [
		{"name": "A", "is_player": true},
		{"name": "B", "is_player": true},
		{"name": "C", "is_player": true},
		{"name": "D", "is_player": true},
	]
	var dead_state := _battlefield()
	dead_state.dead_indices = {1: true, 3: true}  # B and D dead
	tob_dead.refresh(fake_queue, 0, dead_state)
	_eq("turn bar shows only living slots", tob_dead._hbox.get_child_count(), 2)
	# Each living slot carries its real TURN_QUEUE index (not its visual position),
	# so right-click examine resolves the correct combatant after deaths. A(0), C(2).
	_eq("living slot 0 maps to queue index 0",
		int(tob_dead._hbox.get_child(0).get_meta("queue_index", -1)), 0)
	_eq("living slot 1 maps to queue index 2 (skips dead B)",
		int(tob_dead._hbox.get_child(1).get_meta("queue_index", -1)), 2)
	# With no state (or no deaths) all slots are shown.
	tob_dead.refresh(fake_queue, 0, null)
	_eq("turn bar shows all slots when no state", tob_dead._hbox.get_child_count(), 4)
	tob_dead.free()

	# ════════════════════════════════════════════════════════════
	# SPELL SLOTS (D&D 5e) — substituição do sistema de MP
	# ════════════════════════════════════════════════════════════

	# --- Spell Slots: ActionData ---
	_eq("ActionData spell_slot_level default", ActionData.new().spell_slot_level, 0)
	_eq("ActionData ki_cost default", ActionData.new().ki_cost, 0)

	# --- Spell Slots: Spells ---
	_eq("SpellFogo slot level 2",   SpellFogo.new().spell_slot_level,   2)
	_eq("SpellFogo aoe_radius 1",   SpellFogo.new().aoe_radius,         1)
	_eq("SpellGelo slot level 2",   SpellGelo.new().spell_slot_level,   2)
	_eq("SpellTrovao slot level 2", SpellTrovao.new().spell_slot_level, 2)
	_eq("SpellCura slot level 1",   SpellCura.new().spell_slot_level,   1)

	# --- Spell Slots: HeroData.get_spell_slots_max() escala com level ---
	var mago_hd := MagoData.new()
	mago_hd.level = 4
	_eq("Mago lv4 slots",  mago_hd.get_spell_slots_max(), [4, 3, 0, 0, 0, 0])
	mago_hd.level = 5
	_eq("Mago lv5 slots",  mago_hd.get_spell_slots_max(), [4, 3, 2, 0, 0, 0])
	mago_hd.level = 12
	_eq("Mago lv12 slots", mago_hd.get_spell_slots_max(), [4, 3, 3, 3, 2, 1])

	var pal_hd := PaladinoData.new()
	pal_hd.level = 4
	_eq("Paladino lv4 slots",  pal_hd.get_spell_slots_max(), [3, 0, 0, 0, 0, 0])
	pal_hd.level = 12
	_eq("Paladino lv12 slots", pal_hd.get_spell_slots_max(), [4, 3, 3, 1, 0, 0])

	_eq("Guerreiro slots sempre zero", GuerreiroData.new().get_spell_slots_max(), [0, 0, 0, 0, 0, 0])

	var monge_hd := MongeData.new()
	monge_hd.level = 4
	_eq("Monge ki_max lv4",  monge_hd.ki_max(), 4)
	monge_hd.level = 12
	_eq("Monge ki_max lv12", monge_hd.ki_max(), 12)
	_eq("Monge slots sempre zero", monge_hd.get_spell_slots_max(), [0, 0, 0, 0, 0, 0])

	# --- Spell Slots: is_item_available checa slots ---
	var s_slots := BattleState.new()
	var saved_p0_slots: Array = BattleState.PLAYERS[0]["spell_slots"].duplicate()

	BattleState.PLAYERS[0]["spell_slots"] = [1, 0, 0, 0, 0, 0]
	var smite_t := SkillSmite.new()  # spell_slot_level = 1
	_true("SkillSmite disponivel com slot nv.1", s_slots.is_item_available(smite_t))

	BattleState.PLAYERS[0]["spell_slots"] = [0, 0, 0, 0, 0, 0]
	_true("SkillSmite indisponivel sem slots", not s_slots.is_item_available(smite_t))

	# Upcast: spell de nv.2 usa slot de nv.3 se nv.2 estiver zerado
	var fogo_t := SpellFogo.new()  # spell_slot_level = 2
	BattleState.PLAYERS[0]["spell_slots"] = [0, 0, 1, 0, 0, 0]
	_true("SpellFogo disponivel via upcast slot nv.3", s_slots.is_item_available(fogo_t))
	BattleState.PLAYERS[0]["spell_slots"] = [0, 0, 0, 0, 0, 0]
	_true("SpellFogo indisponivel sem slots nv.2+", not s_slots.is_item_available(fogo_t))

	# --- Spell Slots: consume_spell_slot ---
	BattleState.PLAYERS[0]["spell_slots"] = [2, 3, 0, 0, 0, 0]
	s_slots.consume_spell_slot(1)
	_eq("consume_spell_slot nv.1 decrementa slots[0]", BattleState.PLAYERS[0]["spell_slots"][0], 1)
	_eq("consume_spell_slot nao afeta slots[1]",       BattleState.PLAYERS[0]["spell_slots"][1], 3)

	# Upcast: usa nv.2 quando nv.1 está zerado
	BattleState.PLAYERS[0]["spell_slots"] = [0, 2, 0, 0, 0, 0]
	s_slots.consume_spell_slot(1)
	_eq("consume_spell_slot upcast usa nv.2", BattleState.PLAYERS[0]["spell_slots"][1], 1)

	# consume_spell_slot com nível 0 não faz nada
	BattleState.PLAYERS[0]["spell_slots"] = [3, 0, 0, 0, 0, 0]
	s_slots.consume_spell_slot(0)
	_eq("consume_spell_slot(0) é no-op", BattleState.PLAYERS[0]["spell_slots"][0], 3)

	BattleState.PLAYERS[0]["spell_slots"] = saved_p0_slots  # restaurar

	# --- Spell Slots: reset_players restaura slots ao máximo ---
	# Estabelece uma party conhecida (Mago full caster lv4 = [4,3,0,0,0,0]).
	BattleState.setup_party(["Mago", "Guerreiro"])
	BattleState.PLAYERS[0]["spell_slots"] = [0, 0, 0, 0, 0, 0]  # Mago gastou tudo
	BattleState.reset_players()
	var mago_pdata: HeroData = BattleState.ALL_HERO_DATA.get("Mago")
	_eq("reset_players restaura spell_slots do Mago",
		BattleState.PLAYERS[0]["spell_slots"], mago_pdata.get_spell_slots_max())

	# --- Spell Slots: calc_hit_chance auto-hit para spell com slot ---
	var s_hit := BattleState.new()
	var fogo_hit := SpellFogo.new()
	s_hit._current_action = fogo_hit
	_eq("calc_hit_chance 1.0 para spell com slot", s_hit.calc_hit_chance(1), 1.0)

	# --- Spell Slots: item Éter restaura 1 slot do nível pedido ---
	# Party Mago já ativa (PLAYERS[0] = Mago, ativo no índice 0).
	var s_item := BattleState.new()
	s_item.active_index = 0
	BattleState.PLAYERS[0]["spell_slots"]     = [1, 0, 0, 0, 0, 0]
	BattleState.PLAYERS[0]["spell_slots_max"] = [4, 3, 0, 0, 0, 0]
	s_item.use_item({"label": "Éter", "count": 1, "is_item": true, "spell_slot_restore": 1})
	_eq("Éter restaura +1 slot nv.1", BattleState.PLAYERS[0]["spell_slots"][0], 2)

	# ════════════════════════════════════════════════════════════
	# ADVANTAGE / DISADVANTAGE + SAVING THROWS (D&D 5e)
	# ════════════════════════════════════════════════════════════

	# ── Advantage / Disadvantage (DiceRoller) ────────────────────────────────
	var adv_result = DiceRoller.roll_d20_adv_dis(1, 0)
	_eq("advantage mode string", adv_result["mode"], "advantage")
	_true("advantage result >= other", adv_result["result"] >= adv_result["other"])

	var dis_result = DiceRoller.roll_d20_adv_dis(0, 1)
	_eq("disadvantage mode string", dis_result["mode"], "disadvantage")
	_true("disadvantage result <= other", dis_result["result"] <= dis_result["other"])

	var norm_result = DiceRoller.roll_d20_adv_dis(0, 0)
	_eq("normal (no mod) mode string", norm_result["mode"], "normal")

	var cancel_result = DiceRoller.roll_d20_adv_dis(1, 1)
	_eq("adv+dis cancels to normal", cancel_result["mode"], "normal")

	var multi_adv = DiceRoller.roll_d20_adv_dis(3, 0)
	_eq("multi-advantage still advantage", multi_adv["mode"], "advantage")
	_true("multi-advantage result >= other", multi_adv["result"] >= multi_adv["other"])

	# ── ActionData.save_attribute ─────────────────────────────────────────────
	var default_action := ActionData.new()
	_eq("save_attribute defaults to DEX",
		default_action.save_attribute, ActionData.DamageAttribute.DEX)

	# ── Setup conhecido para A/D + saving throws ──────────────────────────────
	# setup_party adiciona os players primeiro, depois TODOS os inimigos de
	# ALL_ENEMIES (Goblin, Orc, Mage, Undead, ...). Layout resultante:
	#   [0] Guerreiro (player, STR/melee)
	#   [1] Mago      (player, INT/caster)
	#   [2] Goblin Scout (enemy "Goblin", ac 13)  ← primeiro inimigo
	# IMPORTANTE: chamar setup_party ANTES de qualquer BattleState.new(), pois
	# _init() dimensiona combatant_positions/statuses a partir de TURN_QUEUE.
	BattleState.setup_party(["Guerreiro", "Mago"])

	# ── BattleState._get_save_mod ─────────────────────────────────────────────
	var s_sm := BattleState.new()
	# Player (TURN_QUEUE[0] = Guerreiro, is_player=true)
	var p0_dex: int = BattleState.PLAYERS[0].get("dexterity", 10)
	var expected_dex_mod: int = int((p0_dex - 10) / 2.0)
	_eq("_get_save_mod player DEX",
		s_sm._get_save_mod(0, ActionData.DamageAttribute.DEX), expected_dex_mod)

	# Enemy (TURN_QUEUE[2] = Goblin Scout, is_player=false)
	var enemy_type: String = BattleState.TURN_QUEUE[2].get("type", "")
	var edata := BattleState.ALL_ENEMIES.get(enemy_type, null) as EnemyData
	if edata != null:
		var expected_edex_mod: int = int((edata.dexterity - 10) / 2.0)
		_eq("_get_save_mod enemy DEX",
			s_sm._get_save_mod(2, ActionData.DamageAttribute.DEX), expected_edex_mod)
	else:
		_true("EnemyData found for Goblin Scout", false)

	# NONE attribute retorna 0
	_eq("_get_save_mod NONE attr returns 0",
		s_sm._get_save_mod(0, ActionData.DamageAttribute.NONE), 0)

	# ── BattleState._get_attack_roll_mods ────────────────────────────────────
	# Atacante = 0 (Guerreiro), alvo = 2 (Goblin Scout).
	var s_mods := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		s_mods.combatant_positions[i] = Vector2i(i, 0)

	# furtivo no atacante → advantage
	s_mods.combatant_statuses[0]["furtivo"] = 1
	var m_furv := s_mods._get_attack_roll_mods(0, 2, 3)
	_eq("furtivo: adv=1", m_furv["adv"], 1)
	_eq("furtivo: dis=0", m_furv["dis"], 0)
	s_mods.combatant_statuses[0].erase("furtivo")

	# stun no alvo → advantage
	s_mods.combatant_statuses[2]["stun"] = 1
	var m_stun := s_mods._get_attack_roll_mods(0, 2, 1)
	_eq("stunned target: adv=1", m_stun["adv"], 1)
	s_mods.combatant_statuses[2].erase("stun")

	# cover no alvo → disadvantage
	s_mods.tile_data_map[2][0].object = TerrainTile.ObjectType.COVER
	var m_cover := s_mods._get_attack_roll_mods(0, 2, 1)
	_eq("cover: dis=1", m_cover["dis"], 1)
	_eq("cover: adv=0", m_cover["adv"], 0)
	s_mods.tile_data_map[2][0].object = TerrainTile.ObjectType.NONE

	# elevated + ranged → flat +2 (NÃO advantage); elevated + melee → sem bônus
	s_mods.tile_data_map[0][0].ground = TerrainTile.GroundType.ELEVATED
	var m_elev_ranged := s_mods._get_attack_roll_mods(0, 2, 5)
	_eq("elevated+ranged: adv=0",   m_elev_ranged["adv"],  0)
	_eq("elevated+ranged: flat=+2", m_elev_ranged["flat"], 2)
	var m_elev_melee := s_mods._get_attack_roll_mods(0, 2, 1)
	_eq("elevated+melee: flat=0",   m_elev_melee["flat"], 0)
	s_mods.tile_data_map[0][0].ground = TerrainTile.GroundType.NORMAL

	# furtivo + cover → ambos presentes (cancelamento fica com DiceRoller)
	s_mods.combatant_statuses[0]["furtivo"] = 1
	s_mods.tile_data_map[2][0].object = TerrainTile.ObjectType.COVER
	var m_cancel := s_mods._get_attack_roll_mods(0, 2, 1)
	_eq("furtivo+cover: adv=1 dis=1", m_cancel["adv"] == 1 and m_cancel["dis"] == 1, true)
	s_mods.combatant_statuses[0].erase("furtivo")
	s_mods.tile_data_map[2][0].object = TerrainTile.ObjectType.NONE

	# ── _get_save_roll_mods ───────────────────────────────────────────────────
	var s_srm := BattleState.new()
	# stun → dis na save
	s_srm.combatant_statuses[0]["stun"] = 1
	var srm_stun := s_srm._get_save_roll_mods(0)
	_eq("stun: save dis=1", srm_stun["dis"], 1)
	_eq("stun: save adv=0", srm_stun["adv"], 0)
	s_srm.combatant_statuses[0].erase("stun")

	# ── _resolve_saving_throw — testa com DCs extremos (alvo = Goblin idx 2) ───
	var s_rst := BattleState.new()
	var dummy_action := ActionData.new()  # save_attribute = DEX por padrão

	# DC 0 → qualquer roll (total >= 0) passa
	var save_always_pass := s_rst._resolve_saving_throw(2, 0, dummy_action)
	_true("DC 0 always saved", save_always_pass["saved"])

	# DC acima do máximo possível (20 + dex_mod) → sempre falha
	var goblin_type: String = BattleState.TURN_QUEUE[2].get("type", "")
	var goblin_edata := BattleState.ALL_ENEMIES.get(goblin_type, null) as EnemyData
	if goblin_edata != null:
		var goblin_dex_mod: int = int((goblin_edata.dexterity - 10) / 2.0)
		var dc_impossible: int = 21 + goblin_dex_mod
		var save_always_fail := s_rst._resolve_saving_throw(2, dc_impossible, dummy_action)
		_true("DC above max always fails", not save_always_fail["saved"])

	# Estrutura do retorno
	_true("resolve_saving_throw has 'saved'", save_always_pass.has("saved"))
	_true("resolve_saving_throw has 'roll'",  save_always_pass.has("roll"))
	_true("resolve_saving_throw has 'total'", save_always_pass.has("total"))
	_true("resolve_saving_throw has 'mode'",  save_always_pass.has("mode"))
	_true("resolve_saving_throw has 'dc'",    save_always_pass.has("dc"))

	# ── _apply_attack com Advantage/Disadvantage ─────────────────────────────
	# Atacante Guerreiro (idx 0), alvo Goblin Scout (idx 2).

	# Furtivo → roll_mode == "advantage"
	var s_adv := BattleState.new()
	s_adv.active_index = 0
	s_adv._current_action = AtqNormal.new()
	s_adv.combatant_statuses[0]["furtivo"] = 1
	s_adv.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_adv.combatant_positions[i] = Vector2i(i, 0)
	seed(_find_seed_for_d20(18))  # r1=18 → max(18,r2) acerta com advantage
	s_adv._apply_attack(2)
	_eq("furtivo attack: roll_mode is advantage",
		s_adv.last_attack_info.get("roll_mode", ""), "advantage")

	# Cover → roll_mode == "disadvantage"
	var s_dis := BattleState.new()
	s_dis.active_index = 0
	s_dis._current_action = AtqNormal.new()
	s_dis.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_dis.combatant_positions[i] = Vector2i(i, 0)
	s_dis.tile_data_map[2][0].object = TerrainTile.ObjectType.COVER
	seed(_find_seed_for_d20(15))
	s_dis._apply_attack(2)
	_eq("cover: roll_mode is disadvantage",
		s_dis.last_attack_info.get("roll_mode", ""), "disadvantage")

	# ── _apply_attack com Saving Throw ───────────────────────────────────────
	# Mago (idx 1) lança SpellFogo no Goblin (idx 2).
	var s_save := BattleState.new()
	s_save.active_index = 1
	var spell_fogo_t := SpellFogo.new()
	spell_fogo_t.requires_saving_throw = true  # setado manualmente até Task 8
	s_save._current_action = spell_fogo_t
	s_save._attack_targets_allies = false
	s_save.current_attack_range = spell_fogo_t.attack_range
	s_save.current_aoe_radius = 0
	s_save.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_save.combatant_positions[i] = Vector2i(i, 0)
	s_save._apply_attack(2)
	_true("saving throw: is_saving_throw flag", s_save.last_attack_info.get("is_saving_throw", false))
	_true("saving throw: save_dc > 0", s_save.last_attack_info.get("save_dc", 0) > 0)
	_true("saving throw: has save_roll", s_save.last_attack_info.has("save_roll"))
	_true("saving throw: hit flag always true", s_save.last_attack_info.get("hit", false))
	_true("saving throw: amount >= 1", s_save.last_attack_info.get("amount", 0) >= 1)

	# ── apply_enemy_attack com A/D ────────────────────────────────────────────
	# Goblin Scout (idx 2) ataca; Mago (idx 1) adjacente em (1,0).
	var s_ea := BattleState.new()
	s_ea.active_index = 2
	s_ea.current_state = BattleState.State.ENEMY_TURN
	for i in range(BattleState.TURN_QUEUE.size()):
		s_ea.combatant_positions[i] = Vector2i(i, 0)
	BattleState.PLAYERS[0]["hp"] = 100
	BattleState.PLAYERS[1]["hp"] = 100
	seed(_find_seed_for_d20(15))
	s_ea.apply_enemy_attack()
	_true("enemy attack: last_attack_info has roll_mode",
		s_ea.last_attack_info.has("roll_mode"))

	# ── Saving Throw flags nas spells ─────────────────────────────────────────
	_true("SpellFogo requires_saving_throw",     SpellFogo.new().requires_saving_throw)
	_true("SpellGelo requires_saving_throw",     SpellGelo.new().requires_saving_throw)
	_true("SpellTrovao requires_saving_throw",   SpellTrovao.new().requires_saving_throw)
	_true("SkillChuvaFlechas requires_saving_throw", SkillChuvaFlechas.new().requires_saving_throw)
	_eq("SpellFogo save_attribute DEX",
		SpellFogo.new().save_attribute, ActionData.DamageAttribute.DEX)

	# ╔══════════════════════════════════════════════════════════════════════╗
	# ║ BG3/D&D combat-fidelity bug fixes (8 bugs)                            ║
	# ╚══════════════════════════════════════════════════════════════════════╝

	# ── raging: display "Enfurecido" (desambiguado da "Fúria" do Bárbaro) ─────
	var bs_fury_display := _battlefield()
	bs_fury_display.combatant_statuses[0]["raging"] = 1
	_true("raging mostra Enfurecido",
		bs_fury_display.get_active_status_text(0).contains("Enfurecido"))
	_true("raging nao mostra Fúria",
		not bs_fury_display.get_active_status_text(0).contains("Fúria"))
	_eq("raging name_of e Enfurecido", StatusDefinitions.name_of("raging"), "Enfurecido")

	# ── Item B: coerência display × mecânica dos status ──────────────────────
	_true("furtivo desc nao implica Sneak Attack",
		not StatusDefinitions.desc_of("furtivo").contains("Ataque Furtivo"))
	_true("blinded desc sem 'alcance reduzido'",
		not StatusDefinitions.desc_of("blinded").contains("alcance reduzido"))
	_true("frightened desc sem 'Não pode se mover'",
		not StatusDefinitions.desc_of("frightened").contains("Não pode se mover"))
	_true("frightened desc menciona fonte do medo",
		StatusDefinitions.desc_of("frightened").contains("fonte do medo"))

	# ── Bug 3 — normal melee never applies stun ──────────────────────────────
	var bs_stun := _battlefield()
	bs_stun.active_index = 0
	bs_stun._current_action = AtqNormal.new()
	bs_stun.current_attack_range = 1
	bs_stun._attack_targets_allies = false
	bs_stun.enemy_hp["Goblin Scout"] = 100000
	for i in range(BattleState.TURN_QUEUE.size()):
		bs_stun.combatant_positions[i] = Vector2i(i, 0)
	var stun_ever := false
	for s_i in range(200):
		bs_stun.combatant_statuses[1].erase("stun")
		seed(s_i)
		bs_stun._apply_attack(1)  # Guerreiro melee vs Goblin Scout
		if bs_stun.combatant_statuses[1].get("stun", 0) > 0:
			stun_ever = true
	_true("normal melee never applies stun across 200 seeds", not stun_ever)

	# ── Bug 7 — condição Envenenado: disadvantage on attacks & saves ─────────
	var bs_ptickon_atk := _battlefield()
	bs_ptickon_atk.combatant_statuses[0]["poisoned"] = 2
	var pmods_atk := bs_ptickon_atk._get_attack_roll_mods(0, 1, 1)
	_eq("Envenenado attacker has dis=1", pmods_atk["dis"], 1)
	var bs_ptickon_sv := _battlefield()
	bs_ptickon_sv.combatant_statuses[0]["poisoned"] = 2
	var pmods_sv := bs_ptickon_sv._get_save_roll_mods(0)
	_eq("Envenenado saver has dis=1", pmods_sv["dis"], 1)

	# ── Bug 1 — Defender system fully removed ────────────────────────────────
	var bs_def := _battlefield()
	for di in range(bs_def.combatant_statuses.size()):
		_true("no defending status at start idx %d" % di,
			not bs_def.combatant_statuses[di].has("defending"))
	# A stale "defending" key must no longer grant save advantage.
	bs_def.combatant_statuses[0]["defending"] = 1
	var def_mods := bs_def._get_save_roll_mods(0)
	_eq("defending no longer grants save advantage", def_mods["adv"], 0)
	# get_active_status_text must not surface a Defender badge.
	_true("no Defender text in status",
		not bs_def.get_active_status_text(0).contains("Defender"))
	# TAB_END_TURN must not contain an AcaoDefender entry.
	var has_defender_action := false
	for a in BattleState.TAB_END_TURN:
		if a != null and a.label == "Defender":
			has_defender_action = true
	_true("TAB_END_TURN has no Defender action", not has_defender_action)

	# ── Bug 2 — elevated terrain: flat ±2, not advantage ─────────────────────
	var bs_elev := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		bs_elev.combatant_positions[i] = Vector2i(i, 0)
	# Baseline: no elevation, ranged → no flat modifier
	var em_base := bs_elev._get_attack_roll_mods(0, 2, 5)
	_eq("flat: no elevation = 0", em_base.get("flat", 999), 0)
	# Attacker elevated, target not, ranged → +2, adv unchanged
	bs_elev.tile_data_map[0][0].ground = TerrainTile.GroundType.ELEVATED
	var em_high := bs_elev._get_attack_roll_mods(0, 2, 5)
	_eq("high ground: flat=+2", em_high["flat"], 2)
	_eq("high ground: adv=0",   em_high["adv"],  0)
	# Target elevated, attacker not, ranged → -2 (attacking up)
	bs_elev.tile_data_map[0][0].ground = TerrainTile.GroundType.NORMAL
	bs_elev.tile_data_map[2][0].ground = TerrainTile.GroundType.ELEVATED
	var em_low := bs_elev._get_attack_roll_mods(0, 2, 5)
	_eq("attacking up: flat=-2", em_low["flat"], -2)
	# Both elevated (same height) → neutral
	bs_elev.tile_data_map[0][0].ground = TerrainTile.GroundType.ELEVATED
	var em_both := bs_elev._get_attack_roll_mods(0, 2, 5)
	_eq("both elevated: flat=0", em_both["flat"], 0)
	bs_elev.tile_data_map[0][0].ground = TerrainTile.GroundType.NORMAL
	bs_elev.tile_data_map[2][0].ground = TerrainTile.GroundType.NORMAL

	# ── Bug 4 — Sneak Attack conditions ──────────────────────────────────────
	# Rebuild a party containing the Rogue. Earlier tests call setup_party(),
	# which mutates the static TURN_QUEUE, so we cannot rely on default indices.
	BattleState.setup_party(["Ladrao", "Guerreiro"])
	var rogue_i := 0   # Ladrao (Rogue)
	var ally_i  := 1   # Guerreiro (player ally)
	var enemy_i := 2   # first enemy appended by setup_party

	# (a) No hero starts a battle with furtivo (auto-furtivo removed from setup).
	var gen_sa := MapGenerator.new()
	var md_sa := gen_sa.generate(7)
	var bs_setup_sa := BattleState.new()
	bs_setup_sa.setup(md_sa)
	var any_furtivo := false
	for i in range(bs_setup_sa.combatant_statuses.size()):
		if bs_setup_sa.combatant_statuses[i].get("furtivo", 0) > 0:
			any_furtivo = true
	_true("no hero starts with furtivo (auto-furtivo removed)", not any_furtivo)

	# (b) _can_sneak_attack condition matrix.
	var bs_can := BattleState.new()
	bs_can.current_attack_range = 1
	for i in range(BattleState.TURN_QUEUE.size()):
		bs_can.combatant_positions[i] = Vector2i(i % 12, 6)  # parked bottom row
	bs_can.combatant_positions[enemy_i] = Vector2i(5, 2)  # target, isolated
	bs_can.combatant_positions[rogue_i] = Vector2i(8, 6)  # Rogue
	bs_can.combatant_positions[ally_i]  = Vector2i(0, 6)  # ally far from target
	# Non-Rogue (Guerreiro) cannot sneak even with furtivo/advantage.
	bs_can.combatant_statuses[ally_i]["furtivo"] = 1
	_true("non-Rogue cannot sneak attack", not bs_can._can_sneak_attack(ally_i, enemy_i))
	bs_can.combatant_statuses[ally_i].erase("furtivo")
	# Rogue with advantage (furtivo) and no adjacent ally → can sneak.
	bs_can.combatant_statuses[rogue_i]["furtivo"] = 1
	_true("Rogue with advantage can sneak", bs_can._can_sneak_attack(rogue_i, enemy_i))
	bs_can.combatant_statuses[rogue_i].erase("furtivo")
	# Rogue with neither advantage nor adjacent ally → cannot sneak.
	_true("Rogue without advantage/ally cannot sneak", not bs_can._can_sneak_attack(rogue_i, enemy_i))
	# Rogue with an ally adjacent to the target → can sneak.
	bs_can.combatant_positions[ally_i] = Vector2i(5, 3)  # adjacent to (5,2)
	_true("Rogue with adjacent ally can sneak", bs_can._can_sneak_attack(rogue_i, enemy_i))
	# Only once per turn.
	bs_can._sneak_attack_used_this_turn = true
	_true("sneak only once per turn", not bs_can._can_sneak_attack(rogue_i, enemy_i))

	# ── Bug 8 — saving throws include class proficiency ──────────────────────
	BattleState.setup_party(["Guerreiro", "Mago"])
	var bs_sv8 := BattleState.new()
	# Guerreiro (Fighter): proficient in STR & CON, not DEX.
	var g_pidx := bs_sv8._player_index_by_name("Guerreiro")
	var g_prof: int = BattleState.PLAYERS[g_pidx].get("proficiency", 0)
	var g_str_mod := bs_sv8._raw_mod(BattleState.PLAYERS[g_pidx].get("strength", 10))
	var g_dex_mod := bs_sv8._raw_mod(BattleState.PLAYERS[g_pidx].get("dexterity", 10))
	_true("Fighter has proficiency bonus > 0", g_prof > 0)
	_eq("Guerreiro STR save = mod + proficiency",
		bs_sv8._get_save_mod(0, ActionData.DamageAttribute.STR), g_str_mod + g_prof)
	_eq("Guerreiro DEX save = mod only (no proficiency)",
		bs_sv8._get_save_mod(0, ActionData.DamageAttribute.DEX), g_dex_mod)
	# Mago (Wizard): proficient in INT & WIS, not DEX.
	var m_pidx := bs_sv8._player_index_by_name("Mago")
	var m_prof: int = BattleState.PLAYERS[m_pidx].get("proficiency", 0)
	var m_int_mod := bs_sv8._raw_mod(BattleState.PLAYERS[m_pidx].get("intelligence", 10))
	var m_dex_mod := bs_sv8._raw_mod(BattleState.PLAYERS[m_pidx].get("dexterity", 10))
	_eq("Mago INT save = mod + proficiency",
		bs_sv8._get_save_mod(1, ActionData.DamageAttribute.INT), m_int_mod + m_prof)
	_eq("Mago DEX save = mod only (no proficiency)",
		bs_sv8._get_save_mod(1, ActionData.DamageAttribute.DEX), m_dex_mod)
	# HeroData carries the save_proficiencies list.
	_eq("Guerreiro save_proficiencies",
		BattleState.ALL_HERO_DATA["Guerreiro"].save_proficiencies, ["STR", "CON"] as Array[String])

	# ── AoE de DANO: friendly fire — atinge TODOS no raio (inimigos e aliados) ──
	# Cada alvo secundário faz seu próprio saving throw (full/half).
	BattleState.setup_party(["Mago", "Guerreiro", "Clérigo"])
	var bs_aoe := BattleState.new()
	bs_aoe.active_index = 0            # Mago lança (excluído do splash)
	bs_aoe._attack_targets_allies = false
	bs_aoe.current_aoe_radius = 1
	var aoe_action := SpellFogo.new()  # save_attribute = DEX
	for i in range(BattleState.TURN_QUEUE.size()):
		bs_aoe.combatant_positions[i] = Vector2i(i, 6)  # estacionados, espalhados
	var aoe_prim_i := 3                # primeiro inimigo (idx 3 após 3 players)
	var aoe_ally_i := 1               # Guerreiro — aliado do conjurador
	var aoe_enemy_i := 4              # segundo inimigo
	bs_aoe.combatant_positions[aoe_prim_i]  = Vector2i(5, 2)
	bs_aoe.combatant_positions[aoe_ally_i]  = Vector2i(5, 3)  # adjacente (raio 1)
	bs_aoe.combatant_positions[aoe_enemy_i] = Vector2i(5, 1)  # adjacente (raio 1)
	var aoe_ally_pidx := bs_aoe._player_index_by_name("Guerreiro")
	var aoe_enemy_name: String = BattleState.TURN_QUEUE[aoe_enemy_i]["name"]
	# (a) DC impossível → ambos falham o save → dano cheio.
	BattleState.PLAYERS[aoe_ally_pidx]["hp"] = 100
	bs_aoe.enemy_hp[aoe_enemy_name] = 100
	bs_aoe._apply_aoe_splash(aoe_prim_i, 20, 999, aoe_action)
	_eq("AoE dano atinge ALIADO no raio (friendly fire)",
		100 - BattleState.PLAYERS[aoe_ally_pidx]["hp"], 20)
	_eq("AoE dano atinge INIMIGO no raio",
		100 - bs_aoe.enemy_hp[aoe_enemy_name], 20)
	# (b) DC trivial + d20 alto forçado → secundário passa → metade.
	BattleState.PLAYERS[aoe_ally_pidx]["hp"] = 100
	bs_aoe.enemy_hp[aoe_enemy_name] = 100
	seed(_find_seed_for_d20(20))
	bs_aoe._apply_aoe_splash(aoe_prim_i, 20, 1, aoe_action)
	_eq("AoE secundário que passou no save toma metade (aliado)",
		100 - BattleState.PLAYERS[aoe_ally_pidx]["hp"], 10)
	# (c) Chamada legada (dc=0) → dano flat, sem save.
	BattleState.PLAYERS[aoe_ally_pidx]["hp"] = 100
	bs_aoe.enemy_hp[aoe_enemy_name] = 100
	bs_aoe._apply_aoe_splash(aoe_prim_i, 8)
	_eq("AoE legacy splash aplica dano flat (aliado)",
		100 - BattleState.PLAYERS[aoe_ally_pidx]["hp"], 8)
	_eq("AoE legacy splash aplica dano flat (inimigo)",
		100 - bs_aoe.enemy_hp[aoe_enemy_name], 8)

	# ── Respingo de AoE do JOGADOR (centrado em criatura) gera floater por alvo ─
	BattleState.setup_party(["Mago", "Guerreiro", "Clérigo"])
	var bs_spf := BattleState.new()
	bs_spf.active_index = 0
	bs_spf.current_aoe_radius = 1
	var spf_action := SpellFogo.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		bs_spf.combatant_positions[i] = Vector2i(i, 9)
	var spf_prim := 3
	var spf_enemy2 := 4
	bs_spf.combatant_positions[spf_prim]   = Vector2i(5, 2)
	bs_spf.combatant_positions[spf_enemy2] = Vector2i(5, 3)  # raio 1 do primário
	bs_spf.enemy_hp[BattleState.TURN_QUEUE[spf_enemy2]["name"]] = 100
	bs_spf.pending_surface_hits.clear()
	bs_spf._apply_aoe_splash(spf_prim, 20, 999, spf_action)
	var spf_hit := {}
	for h in bs_spf.pending_surface_hits:
		if h.get("target_idx", -1) == spf_enemy2:
			spf_hit = h
			break
	_true("respingo AoE jogador gera floater no secundário", not spf_hit.is_empty())
	_eq("respingo AoE jogador usa cor do tipo (FIRE)", spf_hit.get("color", Color.BLACK),
		ActionData.damage_type_color(ActionData.DamageType.FIRE))

	# ── AoE do INIMIGO gera um floater por alvo (não um agregado no inimigo) ────
	BattleState.setup_party(["Guerreiro", "Mago"])
	var s_eaoe := BattleState.new()
	var eaoe_enemy_i := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		if not BattleState.TURN_QUEUE[i]["is_player"]:
			eaoe_enemy_i = i
			break
	s_eaoe.active_index = eaoe_enemy_i
	var eaoe_origin := Vector2i(5, 5)
	s_eaoe.combatant_positions[eaoe_enemy_i] = eaoe_origin
	s_eaoe.combatant_positions[0] = Vector2i(5, 6)  # Guerreiro, raio 2
	s_eaoe.combatant_positions[1] = Vector2i(6, 5)  # Mago, raio 2
	BattleState.PLAYERS[0]["hp"] = 100
	BattleState.PLAYERS[1]["hp"] = 100
	s_eaoe.pending_surface_hits.clear()
	s_eaoe._apply_enemy_aoe_attack({"aoe_radius": 2, "damage_mult": 1.0})
	var eaoe_targets := {}
	for h in s_eaoe.pending_surface_hits:
		eaoe_targets[h.get("target_idx", -1)] = true
	_true("AoE inimigo: floater para o Guerreiro", eaoe_targets.has(0))
	_true("AoE inimigo: floater para o Mago", eaoe_targets.has(1))
	_true("AoE inimigo: sem floater agregado no próprio inimigo", not eaoe_targets.has(eaoe_enemy_i))

	# ── AoE em TILE VAZIO: detona no ponto, friendly fire, exclui o conjurador ──
	BattleState.setup_party(["Mago", "Guerreiro", "Clérigo"])
	var bs_tile := BattleState.new()
	bs_tile.active_index = 0          # Mago conjura (excluído da detonação)
	bs_tile._current_action = SpellFogo.new()
	bs_tile.current_aoe_radius = 1
	for i in range(BattleState.TURN_QUEUE.size()):
		bs_tile.combatant_positions[i] = Vector2i(0, i)  # todos longe por padrão
	var tile_center := Vector2i(5, 5)   # tile VAZIO (nenhum combatente exatamente nele)
	var tile_ally_i := 1                # Guerreiro (aliado do conjurador)
	var tile_enemy_i := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		if not BattleState.TURN_QUEUE[i]["is_player"]:
			tile_enemy_i = i
			break
	bs_tile.combatant_positions[0]            = Vector2i(0, 0)   # Mago longe (>raio do centro)
	bs_tile.combatant_positions[tile_ally_i]  = Vector2i(5, 4)   # raio 1 do centro
	bs_tile.combatant_positions[tile_enemy_i] = Vector2i(6, 5)   # raio 1 do centro
	var tile_ally_pidx := bs_tile._player_index_by_name("Guerreiro")
	var tile_caster_pidx := bs_tile._player_index_by_name("Mago")
	var tile_enemy_name: String = BattleState.TURN_QUEUE[tile_enemy_i]["name"]
	BattleState.PLAYERS[tile_ally_pidx]["hp"] = 100
	BattleState.PLAYERS[tile_caster_pidx]["hp"] = 100
	bs_tile.enemy_hp[tile_enemy_name] = 100
	bs_tile.apply_aoe_at_tile(tile_center)
	_true("AoE tile vazio atinge inimigo no raio", bs_tile.enemy_hp[tile_enemy_name] < 100)
	_true("AoE tile vazio atinge ALIADO no raio (friendly fire)",
		BattleState.PLAYERS[tile_ally_pidx]["hp"] < 100)
	_eq("AoE tile vazio NAO atinge o conjurador",
		BattleState.PLAYERS[tile_caster_pidx]["hp"], 100)
	_eq("AoE tile vazio deposita superficie FIRE no centro",
		bs_tile.tile_surfaces.get(tile_center, {}).get("type", -1), SurfaceType.Type.FIRE)
	_eq("AoE tile vazio acende inimigo no raio (burning)",
		bs_tile.combatant_statuses[tile_enemy_i].get("burning", 0), 2)
	_true("AoE tile vazio enfileira floaters por alvo",
		not bs_tile.pending_surface_hits.is_empty())

	# ── move_attack_tile_cursor respeita o alcance ─────────────────────────────
	var bs_mv := _battlefield()
	bs_mv.active_index = 0
	bs_mv.current_attack_range = 2
	bs_mv.attack_tile_mode = true
	bs_mv.attack_tile_cursor = bs_mv.combatant_positions[0]
	for _k in range(10):
		bs_mv.move_attack_tile_cursor(Vector2i(1, 0))
	var mv_origin: Vector2i = bs_mv.combatant_positions[0]
	var mv_dist: int = absi(bs_mv.attack_tile_cursor.x - mv_origin.x) + absi(bs_mv.attack_tile_cursor.y - mv_origin.y)
	_true("move_attack_tile_cursor nao passa do alcance", mv_dist <= bs_mv.current_attack_range)
	_true("move_attack_tile_cursor de fato moveu o cursor", mv_dist >= 1)

	# ── AoE preview clampado ao alcance (segue o mouse) ────────────────────────
	var s_hov := _battlefield()
	s_hov.active_index = 0
	s_hov.current_attack_range = 2
	s_hov.attack_tile_mode = true
	var hov_origin: Vector2i = s_hov.combatant_positions[0]
	s_hov.attack_tile_cursor = hov_origin
	var hov_valid := hov_origin + Vector2i(1, 0)   # dist 1 <= 2
	var hov_far := hov_origin + Vector2i(9, 0)      # fora do alcance
	_true("hover válido move o cursor", s_hov.set_attack_tile_cursor_clamped(hov_valid))
	_eq("cursor foi para o tile válido", s_hov.attack_tile_cursor, hov_valid)
	_true("hover fora do alcance é rejeitado", not s_hov.set_attack_tile_cursor_clamped(hov_far))
	_eq("cursor mantém o último válido", s_hov.attack_tile_cursor, hov_valid)

	# ── AoE de CURA respinga nos aliados adjacentes ─────────────────────────
	BattleState.setup_party(["Clérigo", "Guerreiro", "Mago"])
	var bs_heal := BattleState.new()
	bs_heal.active_index = 0            # Clérigo lança (WIS alta → cura > 0)
	bs_heal._attack_targets_allies = true
	bs_heal.current_aoe_radius = 1
	bs_heal._current_action = SkillCuraArea.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		bs_heal.combatant_positions[i] = Vector2i(i, 6)
	var heal_prim := 1                  # Guerreiro — alvo primário
	var heal_sec  := 2                  # Mago — aliado adjacente
	var heal_enemy := 3                 # inimigo adjacente (NÃO deve ser curado)
	bs_heal.combatant_positions[heal_prim]  = Vector2i(5, 2)
	bs_heal.combatant_positions[heal_sec]   = Vector2i(5, 3)  # adjacente
	bs_heal.combatant_positions[heal_enemy] = Vector2i(5, 1)  # adjacente
	var heal_gp := bs_heal._player_index_by_name("Guerreiro")
	var heal_mp := bs_heal._player_index_by_name("Mago")
	var heal_en_name: String = BattleState.TURN_QUEUE[heal_enemy]["name"]
	BattleState.PLAYERS[heal_gp]["hp"] = 1
	BattleState.PLAYERS[heal_mp]["hp"] = 1
	bs_heal.enemy_hp[heal_en_name] = 50
	bs_heal._apply_attack(heal_prim)
	_true("AoE cura restaura o alvo primário", BattleState.PLAYERS[heal_gp]["hp"] > 1)
	_true("AoE cura respinga no aliado adjacente", BattleState.PLAYERS[heal_mp]["hp"] > 1)
	_eq("AoE cura NÃO afeta inimigo no raio", bs_heal.enemy_hp[heal_en_name], 50)

	# ══════════════════════════════════════════════════════════════════════════
	# REACTIONS SYSTEM
	# Testes anteriores mutam o TURN_QUEUE/PLAYERS estáticos via setup_party, então
	# reconstruímos uma party COMPLETA e conhecida. Ordem dos players = ordem passada;
	# inimigos são anexados depois. Logo, para players, índice no TURN_QUEUE == pidx.
	# ══════════════════════════════════════════════════════════════════════════
	BattleState.setup_party(["Guerreiro", "Mago", "Arqueiro", "Clérigo",
		"Ladrao", "Bárbaro", "Paladino", "Monge"])
	var GUER_I := 0
	var LADR_I := 4
	var PALA_I := 6
	var MONG_I := 7
	var GOBL_I := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		if BattleState.TURN_QUEUE[i].get("name", "") == "Goblin Scout":
			GOBL_I = i
			break

	# ── Task 2: stun probabilístico via _maybe_apply_stun ──────────────────────
	var s_stun := BattleState.new()
	seed(0)
	s_stun._maybe_apply_stun(1, 1.0, "TestEnemy")
	_true("_maybe_apply_stun aplica stun com chance 1.0",
		s_stun.combatant_statuses[1].get("stun", 0) > 0)
	var s_nostun := BattleState.new()
	s_nostun._maybe_apply_stun(1, 0.0, "TestEnemy")
	_eq("_maybe_apply_stun nao aplica stun com chance 0.0",
		s_nostun.combatant_statuses[1].get("stun", 0), 0)

	# ── Task 3: recurso de reação ──────────────────────────────────────────────
	var s_react := BattleState.new()
	_true("reação disponível no início", s_react.has_reaction_available(0))
	s_react.consume_reaction(0)
	_true("reação consumida após consume_reaction", not s_react.has_reaction_available(0))
	for _i in range(BattleState.TURN_QUEUE.size()):
		s_react.advance_turn()
	_true("reação reseta no início do próprio turno", s_react.has_reaction_available(0))
	# Settings get/set
	s_react.set_reaction_setting(0, "OA_enabled", false)
	_true("get_reaction_setting lê valor salvo",
		not s_react.get_reaction_setting(0, "OA_enabled", true))
	_true("get_reaction_setting usa default ausente",
		s_react.get_reaction_setting(0, "OA_ask", true))
	# Disengage
	var s_diseng := BattleState.new()
	s_diseng.active_index = 0
	s_diseng.apply_disengage(0)
	_true("disengage seta flag", s_diseng.combatant_statuses[0].get("disengage", false))
	_true("disengage gasta ação principal", s_diseng.has_attacked)

	# ── Task 4: Opportunity Attack ─────────────────────────────────────────────
	var s_oa := BattleState.new()
	s_oa.combatant_positions[GUER_I] = Vector2i(2, 3)  # Guerreiro (player)
	s_oa.combatant_positions[GOBL_I] = Vector2i(2, 4)  # Goblin (inimigo adjacente)
	var oa_reactors := s_oa.check_opportunity_attacks(GUER_I, Vector2i(2, 3), Vector2i(5, 3))
	_true("OA detectado: goblin reage ao guerreiro saindo do alcance",
		oa_reactors.has(GOBL_I))
	# Disengage suprime OA dos inimigos adjacentes no momento (Goblin em (2,4)).
	s_oa.apply_disengage(GUER_I)
	_true("disengage impede OA dos já adjacentes",
		s_oa.check_opportunity_attacks(GUER_I, Vector2i(2, 3), Vector2i(5, 3)).is_empty())
	s_oa.combatant_statuses[GUER_I]["disengage_exempt"] = []
	# Mover dentro do alcance (não sai) não dispara OA
	_true("mover sem sair do alcance não dispara OA",
		s_oa.check_opportunity_attacks(GUER_I, Vector2i(2, 3), Vector2i(3, 4)).is_empty())
	# Execução: Guerreiro (player) faz OA contra Goblin (inimigo)
	var s_oa2 := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		s_oa2.combatant_positions[i] = Vector2i(i, 0)
	s_oa2.enemy_hp["Goblin Scout"] = 100
	seed(_find_seed_for_d20(20))
	s_oa2.apply_opportunity_attack(GUER_I, GOBL_I)
	_true("OA causa dano ao alvo", s_oa2.enemy_hp["Goblin Scout"] < 100)
	_true("OA consome a reação do atacante", not s_oa2.has_reaction_available(GUER_I))

	# ── Task 5: Uncanny Dodge ──────────────────────────────────────────────────
	var s_ud := BattleState.new()
	BattleState.PLAYERS[LADR_I]["hp"] = 50
	s_ud.last_attack_info = {"hit": true, "target_idx": LADR_I, "amount": 20}
	s_ud.apply_uncanny_dodge(LADR_I)
	_eq("uncanny dodge reduz dano à metade", s_ud.last_attack_info.get("amount", -1), 10)
	_eq("uncanny dodge devolve metade do HP", BattleState.PLAYERS[LADR_I]["hp"], 60)
	_true("uncanny dodge consome reação", not s_ud.has_reaction_available(LADR_I))

	# ── Task 5: Deflect Missiles ───────────────────────────────────────────────
	var s_dm := BattleState.new()
	BattleState.PLAYERS[MONG_I]["hp"] = 80
	seed(42)
	s_dm.last_attack_info = {"hit": true, "target_idx": MONG_I, "amount": 5}
	var dm_final: int = s_dm.apply_deflect_missiles(MONG_I)
	_true("deflect missiles não resulta em dano negativo", dm_final >= 0)
	_true("deflect missiles consome reação", not s_dm.has_reaction_available(MONG_I))

	# ── Task 6: Divine Smite via reação ────────────────────────────────────────
	var s_smite := BattleState.new()
	BattleState.PLAYERS[PALA_I]["spell_slots"] = [1, 0, 0, 0, 0, 0]
	s_smite.enemy_hp["Goblin Scout"] = 100
	s_smite.last_attack_info = {"hit": true, "target_idx": GOBL_I, "amount": 10}
	var sm_amt: int = s_smite.apply_divine_smite_reaction(PALA_I, 1, false)
	_true("divine smite reação rola 2d8 (2-16)", sm_amt >= 2 and sm_amt <= 16)
	_eq("dano total inclui smite", s_smite.last_attack_info.get("amount", 0), 10 + sm_amt)
	_eq("divine smite consome spell slot",
		BattleState.PLAYERS[PALA_I]["spell_slots"][0], 0)
	# BG3: Divine Smite NÃO consome o ponto de Reação.
	_true("divine smite NÃO consome reação", s_smite.has_reaction_available(PALA_I))

	# ── Task 6: Stunning Strike via reação ─────────────────────────────────────
	var s_ss := BattleState.new()
	BattleState.PLAYERS[MONG_I]["ki"] = 4
	seed(_find_seed_for_d20(1))  # nat 1 no save → falha garantida
	var ss_stunned: bool = s_ss.apply_stunning_strike(MONG_I, GOBL_I)
	_true("stunning strike atordoa em save falho", ss_stunned)
	_eq("stun aplicado no alvo", s_ss.combatant_statuses[GOBL_I].get("stun", 0), 1)
	_eq("stunning strike consome 1 Ki", BattleState.PLAYERS[MONG_I]["ki"], 3)
	_true("stunning strike consome reação", not s_ss.has_reaction_available(MONG_I))

	# ── Task 7: reações atribuídas aos heróis ──────────────────────────────────
	var rx_pal: HeroData = BattleState.ALL_HERO_DATA["Paladino"]
	_true("Paladino tem ReactionDivineSmite",
		rx_pal.reactions.size() == 1 and rx_pal.reactions[0] is ReactionDivineSmite)
	var rx_lad: HeroData = BattleState.ALL_HERO_DATA["Ladrao"]
	_true("Ladrao tem ReactionUncannyDodge",
		rx_lad.reactions.size() == 1 and rx_lad.reactions[0] is ReactionUncannyDodge)
	var rx_mon: HeroData = BattleState.ALL_HERO_DATA["Monge"]
	_true("Monge tem Deflect + Stunning",
		rx_mon.reactions.size() == 2
		and rx_mon.reactions[0] is ReactionDeflectMissiles
		and rx_mon.reactions[1] is ReactionStunningStrike)
	_true("to_combat_dict inclui reactions",
		rx_pal.to_combat_dict().has("reactions"))
	_true("reactions têm is_reaction=true",
		rx_pal.reactions[0].is_reaction)

	# ── Task 8: Desengajar disponível e gasta a ação principal ─────────────────
	var s_desg := BattleState.new()
	s_desg._load_hero_actions("Guerreiro")
	var has_diseng := false
	for a in s_desg.tab_action:
		if a is AcaoDesengajar:
			has_diseng = true
			break
	_true("tab_action inclui Desengajar para todos os heróis", has_diseng)
	var diseng_act := AcaoDesengajar.new()
	s_desg.has_attacked = false
	_true("Desengajar disponível antes de atacar", s_desg.is_item_available(diseng_act))
	s_desg.has_attacked = true
	_true("Desengajar indisponível após gastar a ação", not s_desg.is_item_available(diseng_act))

	# ── v2 / Change B: Divine Smite não gasta o ponto de Reação ────────────────
	var s_sm2 := BattleState.new()
	BattleState.PLAYERS[PALA_I]["spell_slots"] = [2, 0, 0, 0, 0, 0]
	s_sm2.enemy_hp["Goblin Scout"] = 100
	s_sm2.last_attack_info = {"hit": true, "target_idx": GOBL_I, "amount": 10}
	s_sm2.apply_divine_smite_reaction(PALA_I, 1, false)
	_true("smite mantém a reação disponível", s_sm2.has_reaction_available(PALA_I))
	# Funciona mesmo com a reação já gasta (só depende do spell slot).
	var s_sm3 := BattleState.new()
	BattleState.PLAYERS[PALA_I]["spell_slots"] = [2, 0, 0, 0, 0, 0]
	s_sm3.consume_reaction(PALA_I)
	s_sm3.enemy_hp["Goblin Scout"] = 100
	s_sm3.last_attack_info = {"hit": true, "target_idx": GOBL_I, "amount": 10}
	var sm3_amt: int = s_sm3.apply_divine_smite_reaction(PALA_I, 1, false)
	_true("smite funciona com reação já usada (gasta só o slot)", sm3_amt >= 2 and sm3_amt <= 16)
	_eq("smite com reação usada consome o slot",
		BattleState.PLAYERS[PALA_I]["spell_slots"][0], 1)

	# ── v2 / Change B: crítico dobra o dado do smite (2d8 → 4d8) ────────────────
	var s_smc := BattleState.new()
	BattleState.PLAYERS[PALA_I]["spell_slots"] = [9, 0, 0, 0, 0, 0]
	s_smc.last_attack_info = {"hit": true, "target_idx": GOBL_I, "amount": 0}
	s_smc.enemy_hp["Goblin Scout"] = 9999
	var sm_crit: int = s_smc.apply_divine_smite_reaction(PALA_I, 1, true)
	_true("smite crítico rola 4d8 (4-32)", sm_crit >= 4 and sm_crit <= 32)

	# ── v2 / Change C: Disengage só isenta inimigos já adjacentes ──────────────
	var ORC_I := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		if BattleState.TURN_QUEUE[i].get("name", "") == "Orc Warrior":
			ORC_I = i
			break
	var s_dz := BattleState.new()
	# Posição do disengage: mover adjacente só ao Goblin (A), longe do Orc (B).
	s_dz.combatant_positions[GUER_I] = Vector2i(5, 7)
	s_dz.combatant_positions[GOBL_I] = Vector2i(5, 6)  # adjacente no momento do disengage → isento
	s_dz.combatant_positions[ORC_I]  = Vector2i(6, 5)  # longe no momento do disengage
	s_dz.apply_disengage(GUER_I)
	_true("disengage_exempt contém o Goblin (já adjacente)",
		(s_dz.combatant_statuses[GUER_I]["disengage_exempt"] as Array).has(GOBL_I))
	_true("disengage_exempt NÃO contém o Orc (não-adjacente)",
		not (s_dz.combatant_statuses[GUER_I]["disengage_exempt"] as Array).has(ORC_I))
	# Movimento posterior em que mover sai do alcance de AMBOS (estava adjacente aos 2).
	var dz_oa := s_dz.check_opportunity_attacks(GUER_I, Vector2i(5, 5), Vector2i(1, 1))
	_true("Orc (adjacente só depois) pode fazer OA", dz_oa.has(ORC_I))
	_true("Goblin isento pelo Disengage não faz OA", not dz_oa.has(GOBL_I))

	# ══════════════════════════════════════════════════════════════════════════
	# SURFACE EFFECTS
	# ══════════════════════════════════════════════════════════════════════════

	# ── Deposit: Spell_Fogo cria superficie FIRE no tile do alvo ───────────────
	var sf_state := _battlefield()
	var fogo := SpellFogo.new()
	sf_state.tile_surfaces.clear()
	var fogo_target := Vector2i(9, 1)  # Goblin Scout
	# Acha o indice do combatente que esta exatamente em (9,1) para checar burning.
	var fogo_idx := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		if sf_state.combatant_positions[i] == fogo_target:
			fogo_idx = i
			break
	sf_state._deposit_surface_after_attack(fogo_target, fogo)
	_eq("fogo cria superficie FIRE",
		sf_state.tile_surfaces.get(fogo_target, {}).get("type", -1), SurfaceType.Type.FIRE)
	# Fix B: criar fogo embaixo de um combatente parado o deixa "Em Chamas".
	if fogo_idx >= 0:
		_eq("fogo criado embaixo de parado aplica burning",
			sf_state.combatant_statuses[fogo_idx].get("burning", 0), 2)

	# ── Fonte unica: sobre o fogo, advance_turn causa exatamente 1d4 (so burning) ─
	var fs_state := _battlefield()
	var fs_en_i := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		if not BattleState.TURN_QUEUE[i]["is_player"]:
			fs_en_i = i
			break
	var fs_en_name: String = BattleState.TURN_QUEUE[fs_en_i]["name"]
	fs_state.enemy_hp[fs_en_name] = 100
	fs_state.combatant_positions[fs_en_i] = Vector2i(5, 5)
	fs_state._add_surface(Vector2i(5, 5), SurfaceType.Type.FIRE)
	fs_state.combatant_statuses[fs_en_i]["burning"] = 2
	# Posiciona advance_turn para cair no inimigo sobre o fogo.
	fs_state.active_index = (fs_en_i - 1 + BattleState.TURN_QUEUE.size()) % BattleState.TURN_QUEUE.size()
	fs_state.advance_turn()
	var fs_dmg: int = 100 - int(fs_state.enemy_hp[fs_en_name])
	_true("fonte unica: dano de fogo por turno entre 1 e 4 (1d4)", fs_dmg >= 1 and fs_dmg <= 4)
	_true("fonte unica: burning renovado pelo surface tick", fs_state.combatant_statuses[fs_en_i].get("burning", 0) >= 1)

	# ── Floater de superfície carrega a COR do tipo de dano ────────────────────
	var col_state := _battlefield()
	var col_en_i := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		if not BattleState.TURN_QUEUE[i]["is_player"]:
			col_en_i = i
			break
	col_state.enemy_hp[BattleState.TURN_QUEUE[col_en_i]["name"]] = 100
	col_state.combatant_positions[col_en_i] = Vector2i(5, 5)
	col_state.combatant_statuses[col_en_i]["burning"] = 2
	col_state.active_index = (col_en_i - 1 + BattleState.TURN_QUEUE.size()) % BattleState.TURN_QUEUE.size()
	col_state.advance_turn()  # tick de burning enfileira floater "Fogo"
	var burn_hit := {}
	for h in col_state.pending_surface_hits:
		if h.get("label", "") == "Fogo":
			burn_hit = h
			break
	_true("burning floater existe", not burn_hit.is_empty())
	_eq("burning floater usa cor FIRE", burn_hit.get("color", Color.BLACK),
		ActionData.damage_type_color(ActionData.DamageType.FIRE))

	# ── Superfície de AoE cobre diagonais (Chebyshev) ──────────────────────────
	var surf_diag := _battlefield()
	surf_diag.tile_surfaces.clear()
	var sd_center := Vector2i(5, 5)
	var sd_fogo := SpellFogo.new()  # aoe_radius = 1
	surf_diag._deposit_surface_after_attack(sd_center, sd_fogo)
	_eq("superfície cobre tile diagonal (6,6)",
		surf_diag.tile_surfaces.get(sd_center + Vector2i(1, 1), {}).get("type", -1),
		SurfaceType.Type.FIRE)

	# ── Interacao: Fogo + Agua -> Vapor ────────────────────────────────────────
	var sw_state := _battlefield()
	sw_state._add_surface(Vector2i(5, 5), SurfaceType.Type.WATER)
	sw_state._add_surface(Vector2i(5, 5), SurfaceType.Type.FIRE)
	_eq("fogo+agua=vapor",
		sw_state.tile_surfaces.get(Vector2i(5, 5), {}).get("type", -1), SurfaceType.Type.STEAM)

	# ── Interacao: Fogo + Gelo -> Agua ─────────────────────────────────────────
	var fi_state := _battlefield()
	fi_state._add_surface(Vector2i(5, 5), SurfaceType.Type.ICE)
	fi_state._add_surface(Vector2i(5, 5), SurfaceType.Type.FIRE)
	_eq("fogo+gelo=agua",
		fi_state.tile_surfaces.get(Vector2i(5, 5), {}).get("type", -1), SurfaceType.Type.WATER)

	# ── Prone: ataque melee em alvo caido tem Vantagem ─────────────────────────
	var prone_state := _battlefield()
	prone_state.combatant_statuses[1]["prone"] = 1  # Goblin Scout caido
	var prone_melee := prone_state._get_attack_roll_mods(0, 1, 1)  # range=1 (melee)
	_eq("prone alvo melee = adv", prone_melee["adv"], 1)
	_eq("prone alvo melee = sem dis", prone_melee["dis"], 0)
	# ── Prone: ataque ranged em alvo caido tem Desvantagem ─────────────────────
	var prone_ranged := prone_state._get_attack_roll_mods(0, 1, 5)  # range>1 (ranged)
	_eq("prone alvo ranged = dis", prone_ranged["dis"], 1)

	# ── ICE: superficie de gelo dobra o custo de movimento ─────────────────────
	var ice_state := _battlefield()
	ice_state._add_surface(Vector2i(5, 5), SurfaceType.Type.ICE)
	_eq("gelo custo=2", ice_state._tile_cost(Vector2i(5, 5)), 2)
	_eq("tile normal custo=1", ice_state._tile_cost(Vector2i(2, 2)), 1)

	# ── WATER: aplica status 'wet' ao entrar ───────────────────────────────────
	var wet_state := _battlefield()
	wet_state._add_surface(Vector2i(9, 1), SurfaceType.Type.WATER)
	wet_state.apply_surface_on_enter(1, Vector2i(9, 1))  # idx 1 = Goblin Scout
	_true("agua -> status wet", wet_state.combatant_statuses[1].get("wet", 0) > 0)

	# ── Tick: superficie FIRE aplica/renova "Em Chamas" (fonte unica) ──────────
	# Fonte unica de dano de fogo: o tick de superficie FIRE NAO causa dano direto;
	# ele apenas (re)aplica a condicao burning, e o dano vem do tick de burning em
	# advance_turn. Acha um indice de inimigo dinamicamente.
	var tick_state := _battlefield()
	var tick_en_i := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		if not BattleState.TURN_QUEUE[i]["is_player"]:
			tick_en_i = i
			break
	var tick_en_name: String = BattleState.TURN_QUEUE[tick_en_i]["name"]
	tick_state.enemy_hp[tick_en_name] = 30
	tick_state.combatant_positions[tick_en_i] = Vector2i(5, 5)
	tick_state._add_surface(Vector2i(5, 5), SurfaceType.Type.FIRE)
	tick_state._apply_surface_tick(tick_en_i)
	_eq("fogo tick aplica/renova burning", tick_state.combatant_statuses[tick_en_i].get("burning", 0), 2)
	_eq("fogo tick NAO causa dano direto (fonte unica)", tick_state.enemy_hp[tick_en_name], 30)

	# ── Decaimento: superficie FIRE expira apos DURATION turnos ────────────────
	var exp_state := _battlefield()
	exp_state._add_surface(Vector2i(5, 5), SurfaceType.Type.FIRE)
	for _i in range(SurfaceType.DURATION[SurfaceType.Type.FIRE]):
		exp_state._tick_all_surfaces()
	_eq("fogo expira apos DURATION", exp_state.tile_surfaces.has(Vector2i(5, 5)), false)

	# ── Poisoned (superficie de Veneno): desvantagem em ataques ────────────────
	var pois_state := _battlefield()
	pois_state.combatant_statuses[0]["poisoned"] = 2
	var pois_mods := pois_state._get_attack_roll_mods(0, 1, 1)
	_true("poisoned -> desvantagem", pois_mods["dis"] >= 1)

	# ── Acid: status aparece no texto de status do combatente ──────────────────
	var acid_txt_state := _battlefield()
	acid_txt_state.combatant_statuses[0]["acid"] = 2
	_true("acid aparece no status text",
		acid_txt_state.get_active_status_text(0).contains("Ácido"))

	# ── Trovao em tile SECO -> nenhuma superficie ──────────────────────────────
	var dry_trovao := _battlefield()
	var trovao := SpellTrovao.new()
	dry_trovao._deposit_surface_after_attack(Vector2i(9, 1), trovao)
	_eq("trovao em seco = sem superficie", dry_trovao.tile_surfaces.has(Vector2i(9, 1)), false)

	# ── Trovao em tile com AGUA -> Agua Eletrificada ───────────────────────────
	var wet_trovao := _battlefield()
	wet_trovao._add_surface(Vector2i(9, 1), SurfaceType.Type.WATER)
	wet_trovao._deposit_surface_after_attack(Vector2i(9, 1), trovao)
	_eq("trovao+agua=eletrificada",
		wet_trovao.tile_surfaces.get(Vector2i(9, 1), {}).get("type", -1),
		SurfaceType.Type.ELECTRIFIED_WATER)

	# ── ACID: aplica status 'acid' ao entrar ───────────────────────────────────
	var acid_s := _battlefield()
	acid_s._add_surface(Vector2i(9, 1), SurfaceType.Type.ACID)
	acid_s.apply_surface_on_enter(1, Vector2i(9, 1))
	_true("acid -> status acid", acid_s.combatant_statuses[1].get("acid", 0) > 0)

	# ── Mitigação por tipo de dano: núcleo puro _mitigate() ───────────────────
	var bs_mit := _battlefield()
	var DT_F := ActionData.DamageType.FIRE
	var DT_C := ActionData.DamageType.COLD
	var DT_T := ActionData.DamageType.THUNDER
	var DT_H := ActionData.DamageType.HEALING
	_eq("resistência: metade arredonda p/ baixo", bs_mit._mitigate(7, DT_F, ["FIRE"], [], [], false), 3)
	_eq("vulnerabilidade: dobro",                 bs_mit._mitigate(7, DT_F, [], ["FIRE"], [], false), 14)
	_eq("imunidade: zero",                        bs_mit._mitigate(7, DT_F, [], [], ["FIRE"], false), 0)
	_eq("sem listas: dano normal",                bs_mit._mitigate(7, DT_F, [], [], [], false), 7)
	_eq("case-insensitive (fire == FIRE)",        bs_mit._mitigate(8, DT_F, ["fire"], [], [], false), 4)
	_eq("HEALING nunca mitigado",                 bs_mit._mitigate(7, DT_H, [], [], ["HEALING"], false), 7)
	_eq("resist+vuln do mesmo tipo cancelam",     bs_mit._mitigate(7, DT_F, ["FIRE"], ["FIRE"], [], false), 7)
	_eq("Wet dobra COLD",                         bs_mit._mitigate(5, DT_C, [], [], [], true), 10)
	_eq("Wet dobra THUNDER",                      bs_mit._mitigate(5, DT_T, [], [], [], true), 10)
	_eq("Wet não afeta FIRE",                     bs_mit._mitigate(5, DT_F, [], [], [], true), 5)
	_eq("Wet + resistência COLD cancelam",        bs_mit._mitigate(6, DT_C, ["COLD"], [], [], true), 6)
	_eq("imunidade vence Wet",                    bs_mit._mitigate(6, DT_C, [], [], ["COLD"], true), 0)

	# ── Lookup por alvo: _apply_damage_type_mods() ────────────────────────────
	# setup_party reconstrói TURN_QUEUE = [heróis..., todos os inimigos]; com 1
	# herói, idx 0 = Guerreiro e idx 1 = primeiro inimigo. Salva/restaura o
	# estado global para não perturbar testes posteriores.
	var _look_saved_tq: Array = BattleState.TURN_QUEUE
	var _look_saved_pl: Array = BattleState.PLAYERS
	BattleState.setup_party(["Guerreiro"])
	var bs_look := BattleState.new()
	var look_enemy_type: String = BattleState.TURN_QUEUE[1].get("type", "")
	BattleState.ALL_HERO_DATA["Guerreiro"].immunities.assign(["FIRE"])
	_eq("lookup jogador imune a FIRE → 0", bs_look._apply_damage_type_mods(0, DT_F, 10), 0)
	BattleState.ALL_HERO_DATA["Guerreiro"].immunities.assign([])
	BattleState.ALL_HERO_DATA["Guerreiro"].resistances.assign(["COLD"])
	_eq("lookup jogador resiste COLD → metade", bs_look._apply_damage_type_mods(0, DT_C, 10), 5)
	BattleState.ALL_HERO_DATA["Guerreiro"].resistances.assign([])
	BattleState.ALL_ENEMIES[look_enemy_type].vulnerabilities.assign(["FIRE"])
	_eq("lookup inimigo vulnerável a FIRE → dobro", bs_look._apply_damage_type_mods(1, DT_F, 10), 20)
	BattleState.ALL_ENEMIES[look_enemy_type].vulnerabilities.assign([])
	bs_look.combatant_statuses[1]["wet"] = 2
	_eq("lookup: Wet dobra COLD no inimigo", bs_look._apply_damage_type_mods(1, DT_C, 5), 10)
	BattleState.TURN_QUEUE = _look_saved_tq
	BattleState.PLAYERS = _look_saved_pl

	# ── Integração: mitigação aplicada nos pontos de dano ─────────────────────
	# Usa imunidade (determinística: zera independente da rolagem). Salva/restaura
	# o estado global. setup_party(["Guerreiro"]) → idx 0 herói, idx 1+ inimigos.
	var _int_saved_tq: Array = BattleState.TURN_QUEUE
	var _int_saved_pl: Array = BattleState.PLAYERS

	# (a) Ataque de JOGADOR vs inimigo imune a PHYSICAL → 0 dano
	BattleState.setup_party(["Guerreiro"])
	var bs_pi := BattleState.new()
	bs_pi.active_index = 0
	bs_pi.current_attack_range = 1
	bs_pi._current_action = AtqNormal.new()   # ataque físico básico (PHYSICAL)
	bs_pi.combatant_positions[0] = Vector2i(2, 3)
	bs_pi.combatant_positions[1] = Vector2i(3, 3)  # inimigo adjacente
	var pi_enemy_type: String = BattleState.TURN_QUEUE[1].get("type", "")
	var pi_enemy_name: String = BattleState.TURN_QUEUE[1]["name"]
	BattleState.ALL_ENEMIES[pi_enemy_type].immunities.assign(["PHYSICAL"])
	var pi_hp0: int = bs_pi.enemy_hp[pi_enemy_name]
	seed(_find_seed_for_d20(19))
	bs_pi._apply_attack(1)
	_eq("jogador vs inimigo imune (PHYSICAL): HP intacto", bs_pi.enemy_hp[pi_enemy_name], pi_hp0)
	_eq("last_attack_info.amount = 0 por imunidade", bs_pi.last_attack_info.get("amount", -1), 0)
	BattleState.ALL_ENEMIES[pi_enemy_type].immunities.assign([])

	# (b) Ataque de INIMIGO vs jogador imune a PHYSICAL → 0 dano
	BattleState.setup_party(["Guerreiro"])
	var bs_ei := BattleState.new()
	bs_ei.active_index = 1
	bs_ei.active_enemy_action_idx = 0
	bs_ei.combatant_positions[0] = Vector2i(2, 3)
	bs_ei.combatant_positions[1] = Vector2i(3, 3)  # inimigo adjacente ao Guerreiro
	BattleState.ALL_HERO_DATA["Guerreiro"].immunities.assign(["PHYSICAL"])
	var ei_pidx: int = bs_ei._player_index_by_name("Guerreiro")
	var ei_hp0: int = BattleState.PLAYERS[ei_pidx]["hp"]
	seed(_find_seed_for_d20(19))
	bs_ei.apply_enemy_attack()
	_eq("inimigo vs jogador imune (PHYSICAL): HP intacto", BattleState.PLAYERS[ei_pidx]["hp"], ei_hp0)
	BattleState.ALL_HERO_DATA["Guerreiro"].immunities.assign([])

	# (c) AoE de JOGADOR (splash) em alvo imune a FIRE → 0 dano
	BattleState.setup_party(["Guerreiro"])
	var bs_ao := BattleState.new()
	bs_ao.active_index = 0
	bs_ao.current_aoe_radius = 2
	bs_ao.combatant_positions[2] = Vector2i(5, 5)   # alvo primário do splash
	bs_ao.combatant_positions[1] = Vector2i(6, 5)   # inimigo no raio (dist 1)
	var ao_act := ActionData.new()
	ao_act.damage_type = ActionData.DamageType.FIRE
	var ao_enemy_type: String = BattleState.TURN_QUEUE[1].get("type", "")
	var ao_enemy_name: String = BattleState.TURN_QUEUE[1]["name"]
	BattleState.ALL_ENEMIES[ao_enemy_type].immunities.assign(["FIRE"])
	var ao_hp0: int = bs_ao.enemy_hp[ao_enemy_name]
	bs_ao._apply_aoe_splash(2, 10, 0, ao_act)   # dc=0 → sem save, dano cheio antes da mitigação
	_eq("AoE splash em alvo imune (FIRE): HP intacto", bs_ao.enemy_hp[ao_enemy_name], ao_hp0)
	BattleState.ALL_ENEMIES[ao_enemy_type].immunities.assign([])

	BattleState.TURN_QUEUE = _int_saved_tq
	BattleState.PLAYERS = _int_saved_pl

	# ── POISON: armadilha deixa superficie de Veneno persistente no tile ───────
	var trap_pois := _battlefield()
	trap_pois.tile_data_map[4][3].effect = TerrainTile.EffectType.TRAP_INACTIVE
	trap_pois.combatant_positions[0] = Vector2i(4, 3)
	trap_pois.active_index = 0
	trap_pois.pending_surface_hits.clear()
	trap_pois._check_trap(0, Vector2i(4, 3))
	var trap_hit := {}
	for h in trap_pois.pending_surface_hits:
		if h.get("target_idx", -1) == 0:
			trap_hit = h
			break
	_true("armadilha gera floater", not trap_hit.is_empty())
	_eq("armadilha floater label", trap_hit.get("label", ""), "Armadilha")
	_eq("armadilha cria superficie POISON",
		trap_pois.tile_surfaces.get(Vector2i(4, 3), {}).get("type", -1),
		SurfaceType.Type.POISON)

	# ── Armadilha: dano por dado 2d4 (faixa 2..8, variável) ───────────────────
	var trap_min := 999
	var trap_max := -1
	var trap_distinct := {}
	for _trap_i in range(30):
		var trap_dmg_state := _battlefield()
		trap_dmg_state.tile_data_map[4][3].effect = TerrainTile.EffectType.TRAP_INACTIVE
		trap_dmg_state.combatant_positions[0] = Vector2i(4, 3)
		trap_dmg_state.active_index = 0
		var trap_pidx: int = trap_dmg_state.get_active_player_index()
		BattleState.PLAYERS[trap_pidx]["hp"] = 100  # evita drenar o HP estático entre iterações
		var trap_hp_before: int = BattleState.PLAYERS[trap_pidx]["hp"]
		trap_dmg_state._check_trap(0, Vector2i(4, 3))
		var trap_loss: int = trap_hp_before - BattleState.PLAYERS[trap_pidx]["hp"]
		trap_min = mini(trap_min, trap_loss)
		trap_max = maxi(trap_max, trap_loss)
		trap_distinct[trap_loss] = true
		_eq("armadilha ainda aplica poison=3", trap_dmg_state.combatant_statuses[0].get("poison", 0), 3)
	_true("dano de armadilha >= 2 (2d4)", trap_min >= 2)
	_true("dano de armadilha <= 8 (2d4)", trap_max <= 8)
	_true("dano de armadilha varia (não é fixo)", trap_distinct.size() > 1)

	# ╔══════════════════════════════════════════════════════════════════════╗
	# ║ Concentração de Spells (BG3)                                          ║
	# ╚══════════════════════════════════════════════════════════════════════╝

	# SpellCloudOfDaggers carrega as flags corretas
	var cod := SpellCloudOfDaggers.new()
	_true("SpellCloudOfDaggers.requires_concentration is true", cod.requires_concentration)
	_eq("SpellCloudOfDaggers.spell_slot_level", cod.spell_slot_level, 2)
	_eq("SpellCloudOfDaggers.creates_surface is CLOUD_OF_DAGGERS",
		cod.creates_surface, SurfaceType.Type.CLOUD_OF_DAGGERS)

	# _start_concentration rastreia o spell
	BattleState.setup_party(["Guerreiro", "Mago"])
	var s_conc := BattleState.new()
	_true("not concentrating initially", not s_conc.is_concentrating(0))
	var fake_conc_action := ActionData.new()
	fake_conc_action.label = "Test Spell"
	s_conc._start_concentration(0, fake_conc_action)
	_true("is_concentrating after start", s_conc.is_concentrating(0))

	# Lançar um segundo spell de concentração quebra o primeiro (sem save)
	var fake_conc2 := ActionData.new()
	fake_conc2.label = "Test Spell 2"
	s_conc._start_concentration(0, fake_conc2)
	_true("still concentrating after second cast", s_conc.is_concentrating(0))
	_true("combat log mentions interruption",
		s_conc.combat_log.any(func(e): return "interrompida" in e.get("text", "")))

	# _break_concentration limpa o estado
	s_conc._break_concentration(0)
	_true("not concentrating after break", not s_conc.is_concentrating(0))

	# CON save ao tomar dano: d20=1 (falha garantida → quebra)
	BattleState.setup_party(["Mago"])
	var s_con_save := BattleState.new()
	var fca := ActionData.new()
	fca.label = "Test Conc"
	s_con_save._start_concentration(0, fca)
	seed(_find_seed_for_d20(1))
	s_con_save._check_concentration_after_damage(0, 10)
	_true("CON save d20=1 breaks concentration", not s_con_save.is_concentrating(0))

	# CON save ao tomar dano: d20=20 (sucesso garantido → mantém)
	BattleState.setup_party(["Mago"])
	var s_con_keep := BattleState.new()
	var fca2 := ActionData.new()
	fca2.label = "Test Conc Keep"
	s_con_keep._start_concentration(0, fca2)
	seed(_find_seed_for_d20(20))
	s_con_keep._check_concentration_after_damage(0, 10)
	_true("CON save d20=20 keeps concentration", s_con_keep.is_concentrating(0))

	# Dano 0 não dispara save (mantém concentração)
	BattleState.setup_party(["Mago"])
	var s_con_zero := BattleState.new()
	var fca_z := ActionData.new()
	fca_z.label = "Test Conc Zero"
	s_con_zero._start_concentration(0, fca_z)
	s_con_zero._check_concentration_after_damage(0, 0)
	_true("0 damage does not break concentration", s_con_zero.is_concentrating(0))

	# Stun quebra concentração (via apply_stunning_strike → _break_concentration)
	BattleState.setup_party(["Monge"])
	var s_stun_conc := BattleState.new()
	var fca3 := ActionData.new()
	fca3.label = "Test Stun Conc"
	s_stun_conc._start_concentration(0, fca3)
	s_stun_conc.combatant_statuses[0]["stun"] = 1
	s_stun_conc._break_concentration(0)
	_true("stun break clears concentration", not s_stun_conc.is_concentrating(0))

	# Superfície de Nuvem de Adagas é removida ao quebrar concentração
	BattleState.setup_party(["Mago"])
	var s_cod := BattleState.new()
	var fca4 := ActionData.new()
	fca4.label = "Nuvem de Adagas"
	s_cod._start_concentration(0, fca4)
	s_cod.tile_surfaces[Vector2i(5, 5)] = {
		"type": SurfaceType.Type.CLOUD_OF_DAGGERS, "turns": 10
	}
	s_cod._break_concentration(0)
	_true("CoD surface removed on concentration break",
		not s_cod.tile_surfaces.has(Vector2i(5, 5)))

	# ── Cloud of Daggers: dano de cast 4d4 + fila de floaters de superfície ──────
	_eq("CoD cast damage_dice_count is 4", cod.damage_dice_count, 4)
	_eq("CoD cast damage_dice_sides is 4", cod.damage_dice_sides, 4)

	# get_concentration_action devolve a ActionData passada ao iniciar concentração
	BattleState.setup_party(["Mago"])
	var s_get := BattleState.new()
	var fca_get := SpellCloudOfDaggers.new()
	s_get._start_concentration(0, fca_get)
	_true("get_concentration_action returns the ActionData", s_get.get_concentration_action(0) == fca_get)
	_true("get_concentration_action null when not concentrating", s_get.get_concentration_action(1) == null)

	# pending_surface_hits começa vazio numa nova BattleState
	BattleState.setup_party(["Mago"])
	var s_psh := BattleState.new()
	_true("pending_surface_hits empty initially", s_psh.pending_surface_hits.is_empty())

	# _apply_surface_tick numa Nuvem de Adagas enfileira um hit "Cortante"
	s_psh.tile_surfaces[s_psh.combatant_positions[0]] = {
		"type": SurfaceType.Type.CLOUD_OF_DAGGERS, "turns": 10
	}
	s_psh._apply_surface_tick(0)
	_eq("tick on CoD queues one surface hit", s_psh.pending_surface_hits.size(), 1)
	_eq("surface hit label is Cortante", s_psh.pending_surface_hits[0].get("label", ""), "Cortante")
	_eq("surface hit target_idx is 0", s_psh.pending_surface_hits[0].get("target_idx", -1), 0)

	# apply_surface_on_enter numa Nuvem de Adagas também enfileira um hit
	BattleState.setup_party(["Mago"])
	var s_enter := BattleState.new()
	var cod_pos: Vector2i = s_enter.combatant_positions[0]
	s_enter.tile_surfaces[cod_pos] = {"type": SurfaceType.Type.CLOUD_OF_DAGGERS, "turns": 10}
	s_enter.apply_surface_on_enter(0, cod_pos)
	_eq("on_enter CoD queues one surface hit", s_enter.pending_surface_hits.size(), 1)
	_eq("on_enter hit label is Cortante", s_enter.pending_surface_hits[0].get("label", ""), "Cortante")

	# Bug 1: o dano de início de turno É aplicado via advance_turn() (não silencioso).
	# Coloca a nuvem sob o combatente do índice 1 e avança o turno até ele.
	BattleState.setup_party(["Mago"])
	var s_tick := BattleState.new()
	s_tick.begin_turn()
	var enemy_name_tick: String = BattleState.TURN_QUEUE[1]["name"]
	s_tick.enemy_hp[enemy_name_tick] = 100
	var enemy_pos_tick: Vector2i = s_tick.combatant_positions[1]
	s_tick.tile_surfaces[enemy_pos_tick] = {"type": SurfaceType.Type.CLOUD_OF_DAGGERS, "turns": 10}
	s_tick.advance_turn()  # active_index → 1: tick na nuvem
	_eq("advance_turn reached combatant on cloud", s_tick.active_index, 1)
	_true("Bug 1: turn-start CoD damage applied via advance_turn",
		s_tick.enemy_hp[enemy_name_tick] < 100)
	_true("Bug 1: surface hit enfileirado para floater",
		not s_tick.pending_surface_hits.is_empty())

	# Bug 3: duração de superfície decai 1x por ROUND, não por turno de combatente.
	BattleState.setup_party(["Mago"])
	var s_round := BattleState.new()
	s_round.begin_turn()  # marca o 1º combatente como já tendo agido neste round
	var empty_tile := Vector2i(0, 0)
	# garante um tile sem combatente
	var occupied := {}
	for p in s_round.combatant_positions:
		occupied[p] = true
	var qsize: int = BattleState.TURN_QUEUE.size()
	if occupied.has(empty_tile):
		empty_tile = Vector2i(0, 6)
	s_round.tile_surfaces[empty_tile] = {"type": SurfaceType.Type.CLOUD_OF_DAGGERS, "turns": 10}
	# Um round completo = qsize avanços de turno (volta ao índice 0).
	for _r in range(qsize):
		s_round.advance_turn()
	_eq("Bug 3: surface lost exactly 1 turn after one full round",
		s_round.tile_surfaces[empty_tile]["turns"], 9)
	# Avançar até o último índice (sem voltar a 0) NÃO deve decair de novo.
	for _r in range(maxi(1, qsize - 1)):
		s_round.advance_turn()
	_eq("Bug 3: surface did not decay again before next full round",
		s_round.tile_surfaces[empty_tile]["turns"], 9)

	# Inimigo parado na nuvem toma dano no INÍCIO DE CADA UM DOS SEUS turnos
	# (dano por turno do próprio combatente, estilo BG3 — não no turno do Mago).
	BattleState.setup_party(["Mago"])
	var s_rep := BattleState.new()
	s_rep.begin_turn()
	var rep_enemy: String = BattleState.TURN_QUEUE[1]["name"]
	s_rep.enemy_hp[rep_enemy] = 999
	var rep_pos: Vector2i = s_rep.combatant_positions[1]
	s_rep.tile_surfaces[rep_pos] = {"type": SurfaceType.Type.CLOUD_OF_DAGGERS, "turns": 10}
	var rep_qsize: int = BattleState.TURN_QUEUE.size()
	# 1º turno do inimigo
	s_rep.advance_turn()
	while s_rep.active_index != 1:
		s_rep.advance_turn()
	var hp_after_first: int = s_rep.enemy_hp[rep_enemy]
	_true("CoD: enemy takes damage on its 1st turn in cloud", hp_after_first < 999)
	# Dá a volta na fila até o inimigo agir de novo (continua na nuvem)
	for _r in range(rep_qsize):
		s_rep.advance_turn()
	_eq("CoD: enemy back on its turn", s_rep.active_index, 1)
	_true("CoD: enemy takes damage AGAIN on its next turn in cloud",
		s_rep.enemy_hp[rep_enemy] < hp_after_first)

	# ╔══════════════════════════════════════════════════════════════════════╗
	# ║ Condições D&D/BG3 (infraestrutura)                                     ║
	# ╚══════════════════════════════════════════════════════════════════════╝

	# StatusDefinitions: REGISTRY cobre todas as condições + helpers
	_true("StatusDefinitions tem >=17 chaves", StatusDefinitions.REGISTRY.size() >= 17)
	for _k in ["burning","blinded","frightened","paralyzed","restrained","invisible","charmed","grappled","prone"]:
		_true("REGISTRY tem '%s'" % _k, StatusDefinitions.has(_k))
	_eq("name_of burning", StatusDefinitions.name_of("burning"), "Em Chamas")
	_true("shows_duration burning", StatusDefinitions.shows_duration("burning"))
	_true("shows_duration stun false", not StatusDefinitions.shows_duration("stun"))

	# get_active_status_text usa nomes PT do REGISTRY
	BattleState.setup_party(["Mago"])
	var s_txt := BattleState.new()
	s_txt.combatant_statuses[0]["paralyzed"] = 2
	_true("status text mostra 'Paralisado'", s_txt.get_active_status_text(0).find("Paralisado") >= 0)

	# ── Attack roll mods das novas condições ──────────────────────────────────
	var s_cmods := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		s_cmods.combatant_positions[i] = Vector2i(i, 0)
	# Atacante (0) Cego → desvantagem; Invisível → vantagem
	s_cmods.combatant_statuses[0]["blinded"] = 2
	_eq("blinded attacker: dis=1", s_cmods._get_attack_roll_mods(0, 2, 1)["dis"], 1)
	s_cmods.combatant_statuses[0].erase("blinded")
	s_cmods.combatant_statuses[0]["frightened"] = 2
	_eq("frightened attacker: dis=1", s_cmods._get_attack_roll_mods(0, 2, 1)["dis"], 1)
	s_cmods.combatant_statuses[0].erase("frightened")
	s_cmods.combatant_statuses[0]["restrained"] = 2
	_eq("restrained attacker: dis=1", s_cmods._get_attack_roll_mods(0, 2, 1)["dis"], 1)
	s_cmods.combatant_statuses[0].erase("restrained")
	s_cmods.combatant_statuses[0]["invisible"] = 2
	_eq("invisible attacker: adv=1", s_cmods._get_attack_roll_mods(0, 2, 1)["adv"], 1)
	s_cmods.combatant_statuses[0].erase("invisible")
	# Ataques CONTRA o alvo (2)
	s_cmods.combatant_statuses[2]["paralyzed"] = 2
	_eq("vs paralyzed: adv=1", s_cmods._get_attack_roll_mods(0, 2, 1)["adv"], 1)
	s_cmods.combatant_statuses[2].erase("paralyzed")
	s_cmods.combatant_statuses[2]["restrained"] = 2
	_eq("vs restrained: adv=1", s_cmods._get_attack_roll_mods(0, 2, 1)["adv"], 1)
	s_cmods.combatant_statuses[2].erase("restrained")
	s_cmods.combatant_statuses[2]["blinded"] = 2
	_eq("vs blinded: adv=1", s_cmods._get_attack_roll_mods(0, 2, 1)["adv"], 1)
	s_cmods.combatant_statuses[2].erase("blinded")
	s_cmods.combatant_statuses[2]["invisible"] = 2
	_eq("vs invisible: dis=1", s_cmods._get_attack_roll_mods(0, 2, 1)["dis"], 1)
	s_cmods.combatant_statuses[2].erase("invisible")

	# ── Saving throws ─────────────────────────────────────────────────────────
	var s_sv := BattleState.new()
	var dex_act := ActionData.new(); dex_act.save_attribute = ActionData.DamageAttribute.DEX
	var int_act := ActionData.new(); int_act.save_attribute = ActionData.DamageAttribute.INT
	s_sv.combatant_statuses[0]["paralyzed"] = 2
	var sv_para := s_sv._resolve_saving_throw(0, 10, dex_act)
	_true("paralyzed: auto-falha save DES", not sv_para["saved"])
	_eq("paralyzed: modo auto-fail", sv_para["mode"], "auto-fail")
	# Paralyzed NÃO auto-falha saves que não sejam FOR/DES (INT rola normal)
	var sv_int := s_sv._resolve_saving_throw(0, 0, int_act)  # DC 0 → sempre passa
	_true("paralyzed: save INT rola normalmente (passa DC 0)", sv_int["saved"])

	# ── apply_condition: efeitos colaterais ───────────────────────────────────
	BattleState.setup_party(["Mago"])
	var s_ac := BattleState.new()
	var conc_a := ActionData.new(); conc_a.label = "Teste Conc"
	s_ac._start_concentration(0, conc_a)
	s_ac.apply_condition(0, "paralyzed", 2)
	_true("apply_condition paralyzed quebra concentração", not s_ac.is_concentrating(0))
	s_ac._start_concentration(0, conc_a)
	s_ac.apply_condition(0, "prone", 1)
	_true("apply_condition prone quebra concentração", not s_ac.is_concentrating(0))
	s_ac.apply_condition(1, "charmed", 3, 0)
	_eq("apply_condition charmed grava charmed_by", s_ac.combatant_statuses[1].get("charmed_by", -1), 0)

	# ── Bloqueio de movimento (jogador) ───────────────────────────────────────
	var s_mv := BattleState.new()
	s_mv.active_index = 0
	for _cond2 in ["paralyzed", "restrained", "grappled"]:
		s_mv.combatant_statuses[0].clear()
		s_mv.combatant_statuses[0][_cond2] = 2
		_true("movimento bloqueado por %s" % _cond2, s_mv.get_reachable_tiles().is_empty())

	# ── Amedrontado: pode mover, mas não em direção à fonte ───────────────────
	var s_fright := _battlefield()
	# Goblin Scout (idx 1) em (9,1) é a fonte do medo do Guerreiro (idx 0) em (2,3).
	s_fright.apply_condition(0, "frightened", 2, 1)
	_eq("frightened grava frightened_by", s_fright.combatant_statuses[0].get("frightened_by", -1), 1)
	var fright_tiles := s_fright.get_reachable_tiles()
	_true("frightened ainda pode mover", not fright_tiles.is_empty())
	var fr_src: Vector2i = s_fright.combatant_positions[1]
	var fr_origin: Vector2i = s_fright.combatant_positions[0]
	var fr_origin_dist: int = abs(fr_origin.x - fr_src.x) + abs(fr_origin.y - fr_src.y)
	var fright_ok := true
	for t in fright_tiles.keys():
		var d: int = abs(t.x - fr_src.x) + abs(t.y - fr_src.y)
		if d < fr_origin_dist:
			fright_ok = false
	_true("frightened não inclui tiles que aproximam da fonte", fright_ok)

	# Sem fonte registrada → não filtra (só deixa de bloquear).
	var s_fright2 := _battlefield()
	s_fright2.combatant_statuses[0]["frightened"] = 2   # sem frightened_by
	_true("frightened sem fonte ainda permite mover", not s_fright2.get_reachable_tiles().is_empty())

	# ── Paralyzed pula o turno (advance_turn) ─────────────────────────────────
	BattleState.setup_party(["Mago"])
	var s_par := BattleState.new()
	s_par.begin_turn()
	s_par.combatant_statuses[1]["paralyzed"] = 1
	s_par.advance_turn()  # de 0: próximo seria 1, mas paralisado → pula
	_true("paralyzed pulou o turno (não ficou ativo em 1)", s_par.active_index != 1)
	_eq("paralyzed decrementado para 0", s_par.combatant_statuses[1].get("paralyzed", -1), 0)

	# ── Auto-crit melee vs Paralyzed ──────────────────────────────────────────
	BattleState.setup_party(["Guerreiro"])
	var s_crit := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		s_crit.combatant_positions[i] = Vector2i(i, 0)
	s_crit.active_index = 0
	s_crit.current_attack_range = 1
	s_crit._current_action = AtqNormal.new()
	s_crit.enemy_hp["Goblin Scout"] = 100
	s_crit.combatant_statuses[1]["paralyzed"] = 2
	seed(_find_seed_for_d20(15))  # acerta mas NÃO é 20 natural
	s_crit._apply_attack(1)
	_true("auto-crit: ataque melee vs Paralisado é crítico", s_crit.last_attack_info.get("is_crit", false))

	# ── Burning: tick no início do turno ──────────────────────────────────────
	BattleState.setup_party(["Mago"])
	var s_burn := BattleState.new()
	s_burn.begin_turn()
	var burn_enemy: String = BattleState.TURN_QUEUE[1]["name"]
	s_burn.enemy_hp[burn_enemy] = 100
	s_burn.combatant_statuses[1]["burning"] = 2
	s_burn.advance_turn()  # vira o turno do inimigo (idx 1)
	_eq("burning aplicou no inimigo ativo", s_burn.active_index, 1)
	_true("burning causou dano", s_burn.enemy_hp[burn_enemy] < 100)
	_eq("burning decrementado para 1", s_burn.combatant_statuses[1].get("burning", -1), 1)
	_true("burning enfileirou floater", not s_burn.pending_surface_hits.is_empty())

	# ── Veneno: tick no início do turno gera floater "Veneno" ──────────────────
	BattleState.setup_party(["Mago"])
	var s_venflo := BattleState.new()
	s_venflo.begin_turn()
	var venflo_enemy: String = BattleState.TURN_QUEUE[1]["name"]
	s_venflo.enemy_hp[venflo_enemy] = 100
	s_venflo.combatant_statuses[1]["poison"] = 2
	s_venflo.pending_surface_hits.clear()
	s_venflo.advance_turn()  # vira p/ inimigo idx 1: aplica tick de veneno
	var venflo_hit := {}
	for h in s_venflo.pending_surface_hits:
		if h.get("target_idx", -1) == 1 and h.get("label", "") == "Veneno":
			venflo_hit = h
			break
	_true("veneno tick gera floater", not venflo_hit.is_empty())

	# ── Veneno (DoT): tick de 1d4 no início do turno, sem Desvantagem ─────────
	BattleState.setup_party(["Mago"])
	var s_ptick := BattleState.new()
	s_ptick.begin_turn()
	var pois_enemy: String = BattleState.TURN_QUEUE[1]["name"]
	s_ptick.enemy_hp[pois_enemy] = 100
	s_ptick.combatant_statuses[1]["poison"] = 2
	s_ptick.advance_turn()  # vira o turno do inimigo (idx 1) e dispara o DoT
	var pois_dmg: int = 100 - s_ptick.enemy_hp[pois_enemy]
	_true("veneno causou dano na faixa 1d4", pois_dmg >= 1 and pois_dmg <= 4)
	_eq("veneno decrementado para 1", s_ptick.combatant_statuses[1].get("poison", -1), 1)
	# DoT puro NÃO concede Desvantagem (isso é da condição `poisoned`).
	var s_ptick_nodis := _battlefield()
	s_ptick_nodis.combatant_statuses[0]["poison"] = 2
	_eq("DoT poison NÃO dá desvantagem em ataque", s_ptick_nodis._get_attack_roll_mods(0, 1, 1)["dis"], 0)
	_eq("DoT poison NÃO dá desvantagem em save", s_ptick_nodis._get_save_roll_mods(0)["dis"], 0)

	# ── Surfaces aplicam status / floaters ────────────────────────────────────
	BattleState.setup_party(["Mago"])
	var s_surf := BattleState.new()
	var fpos := s_surf.combatant_positions[1]
	s_surf.tile_surfaces[fpos] = {"type": SurfaceType.Type.FIRE, "turns": 4}
	s_surf.enemy_hp[BattleState.TURN_QUEUE[1]["name"]] = 100
	s_surf.apply_surface_on_enter(1, fpos)
	_eq("Fogo aplica burning=2", s_surf.combatant_statuses[1].get("burning", 0), 2)
	_true("Fogo enfileira floater", not s_surf.pending_surface_hits.is_empty())
	# Água cancela burning
	var wpos := s_surf.combatant_positions[2]
	s_surf.combatant_statuses[2]["burning"] = 2
	s_surf.tile_surfaces[wpos] = {"type": SurfaceType.Type.WATER, "turns": 5}
	s_surf.apply_surface_on_enter(2, wpos)
	_true("Água cancela burning", s_surf.combatant_statuses[2].get("burning", 0) == 0)
	# Electrified water enfileira floater
	s_surf.pending_surface_hits.clear()
	var epos := s_surf.combatant_positions[3]
	s_surf.tile_surfaces[epos] = {"type": SurfaceType.Type.ELECTRIFIED_WATER, "turns": 3}
	s_surf.enemy_hp[BattleState.TURN_QUEUE[3]["name"]] = 100
	s_surf.apply_surface_on_enter(3, epos)
	_true("Electrified water enfileira floater", not s_surf.pending_surface_hits.is_empty())

	# ── Charmed: não pode mirar quem o encantou ───────────────────────────────
	BattleState.setup_party(["Guerreiro", "Mago"])
	var s_ch := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		s_ch.combatant_positions[i] = Vector2i(i, 0)
	# acha um inimigo e um jogador
	var ch_enemy_i := -1
	var ch_player_i := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		if BattleState.TURN_QUEUE[i]["is_player"] and ch_player_i < 0:
			ch_player_i = i
		elif not BattleState.TURN_QUEUE[i]["is_player"] and ch_enemy_i < 0:
			ch_enemy_i = i
	# inimigo encantado pelo jogador ch_player_i não persegue/ataca ele
	s_ch.active_index = ch_enemy_i
	s_ch.combatant_statuses[ch_enemy_i]["charmed"] = 3
	s_ch.combatant_statuses[ch_enemy_i]["charmed_by"] = ch_player_i
	# coloca o jogador encantador adjacente para garantir que seria alvo
	s_ch.combatant_positions[ch_enemy_i] = Vector2i(5, 5)
	s_ch.combatant_positions[ch_player_i] = Vector2i(5, 6)
	var atk_res: Dictionary = s_ch.apply_enemy_attack()
	_true("charmed: inimigo não ataca o encantador adjacente",
		atk_res.get("target", Vector2i(-1,-1)) != s_ch.combatant_positions[ch_player_i])

	# ╔══════════════════════════════════════════════════════════════════════╗
	# ║ Death Saves / Downed (BG3)                                            ║
	# ╚══════════════════════════════════════════════════════════════════════╝

	# Herói a 0 HP → Downed (não morto)
	BattleState.setup_party(["Guerreiro"])
	var s_downed := BattleState.new()
	BattleState.PLAYERS[0]["hp"] = 0
	s_downed._on_death(0)
	_true("player at 0 HP enters Downed (not dead)", s_downed.is_downed(0))
	_true("downed player not in dead_indices", not s_downed.dead_indices.has(0))

	# Inimigo a 0 HP → morre na hora (inalterado)
	BattleState.setup_party(["Guerreiro"])
	var s_enemy_death := BattleState.new()
	s_enemy_death._on_death(1)  # primeiro inimigo (TURN_QUEUE[1])
	_true("enemy dies instantly, not downed", s_enemy_death.dead_indices.has(1))
	_true("enemy is not downed", not s_enemy_death.is_downed(1))

	# 3 falhas de Death Save → morto
	BattleState.setup_party(["Guerreiro"])
	var s_ds_fail := BattleState.new()
	s_ds_fail._enter_downed(0)
	s_ds_fail._add_death_save_failure(0, 1)
	s_ds_fail._add_death_save_failure(0, 1)
	_true("2 failures: still downed", s_ds_fail.is_downed(0))
	_true("2 failures: not dead yet", not s_ds_fail.dead_indices.has(0))
	s_ds_fail._add_death_save_failure(0, 1)  # 3a falha
	_true("3 failures: player is dead", s_ds_fail.dead_indices.has(0))
	_true("3 failures: no longer downed", not s_ds_fail.is_downed(0))

	# 3 sucessos → estabilizado (não morto, ainda caído, para de rolar)
	BattleState.setup_party(["Guerreiro"])
	var s_ds_succ := BattleState.new()
	s_ds_succ._enter_downed(0)
	s_ds_succ.combatant_statuses[0]["death_saves_success"] = 2
	s_ds_succ._check_death_saves(0)
	_true("2 successes: not yet stable", not s_ds_succ.combatant_statuses[0].get("stable", false))
	s_ds_succ.combatant_statuses[0]["death_saves_success"] = 3
	s_ds_succ._check_death_saves(0)
	_true("3 successes: stabilized", s_ds_succ.combatant_statuses[0].get("stable", false))
	_true("3 successes: still downed (needs heal to act)", s_ds_succ.is_downed(0))
	_true("3 successes: not dead", not s_ds_succ.dead_indices.has(0))

	# Estabilizado para de rolar Death Saves
	var prev_fail: int = s_ds_succ.combatant_statuses[0].get("death_saves_failure", 0)
	s_ds_succ._process_death_save(0)
	_eq("stable: _process_death_save is a no-op",
		s_ds_succ.combatant_statuses[0].get("death_saves_failure", 0), prev_fail)

	# Crítico enquanto Downed → 2 falhas automáticas
	BattleState.setup_party(["Guerreiro"])
	var s_ds_crit := BattleState.new()
	s_ds_crit._enter_downed(0)
	s_ds_crit._add_death_save_failure(0, 2)
	_eq("crit adds 2 failures", s_ds_crit.combatant_statuses[0].get("death_saves_failure", 0), 2)

	# Entrar em Downed quebra concentração
	BattleState.setup_party(["Mago"])
	var s_down_conc := BattleState.new()
	var fca_dc := ActionData.new()
	fca_dc.label = "Test Down Conc"
	s_down_conc._start_concentration(0, fca_dc)
	s_down_conc._enter_downed(0)
	_true("entering Downed breaks concentration", not s_down_conc.is_concentrating(0))

	# Todos os jogadores Downed → battle_result = "lose"
	BattleState.setup_party(["Guerreiro"])
	var s_all_down := BattleState.new()
	s_all_down._enter_downed(0)
	_eq("all players Downed -> lose", s_all_down.battle_result, "lose")

	# Ajuda (Help Action) remove Downed e devolve 1 HP
	BattleState.setup_party(["Guerreiro", "Clérigo"])
	var s_help := BattleState.new()
	BattleState.PLAYERS[0]["hp"] = 0
	s_help._enter_downed(0)
	s_help.active_index = 1
	s_help._attack_targets_allies = true
	s_help._current_action = SkillAjuda.new()
	s_help._apply_attack(0)
	_true("Downed removed after Help", not s_help.is_downed(0))
	_true("HP restored to at least 1", BattleState.PLAYERS[0]["hp"] >= 1)

	# Cura também remove Downed
	BattleState.setup_party(["Guerreiro", "Clérigo"])
	var s_heal_down := BattleState.new()
	BattleState.PLAYERS[0]["hp"] = 0
	s_heal_down._enter_downed(0)
	s_heal_down.active_index = 1
	s_heal_down._attack_targets_allies = true
	s_heal_down._current_action = SpellCura.new()
	s_heal_down._apply_attack(0)
	_true("healing removes Downed", not s_heal_down.is_downed(0))
	_true("healing restored HP > 0", BattleState.PLAYERS[0]["hp"] > 0)

	# SkillAjuda flags
	var aj := SkillAjuda.new()
	_true("SkillAjuda revives_downed", aj.revives_downed)
	_true("SkillAjuda clears burning", aj.clears_conditions.has("burning"))
	_true("SkillAjuda é Ação (não Bônus)", not aj.bonus_action)
	_true("SkillAjuda targets_allies", aj.targets_allies)

	# ── Help limpa prone/restrained/burning de aliado não-Downed (BG3) ────────
	BattleState.setup_party(["Guerreiro", "Clérigo"])
	var s_help_clear := BattleState.new()
	s_help_clear.combatant_statuses[0]["prone"] = 1
	s_help_clear.combatant_statuses[0]["restrained"] = 2
	s_help_clear.combatant_statuses[0]["burning"] = 2
	s_help_clear.active_index = 1
	s_help_clear._attack_targets_allies = true
	s_help_clear._current_action = SkillAjuda.new()
	s_help_clear._apply_attack(0)
	_true("Help removeu prone", s_help_clear.combatant_statuses[0].get("prone", 0) == 0)
	_true("Help removeu restrained", s_help_clear.combatant_statuses[0].get("restrained", 0) == 0)
	_true("Help removeu burning", s_help_clear.combatant_statuses[0].get("burning", 0) == 0)

	# ── 3.9 A4: framework de aura (save_bonus a aliados em alcance) ───────────
	BattleState.setup_party(["Guerreiro", "Clérigo"])
	var g_idx := -1
	var c_idx := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		var nm: String = BattleState.TURN_QUEUE[i]["name"]
		if nm == "Guerreiro": g_idx = i
		elif nm == "Clérigo": c_idx = i
	var aura_hd := BattleState.ALL_HERO_DATA["Guerreiro"] as HeroData
	aura_hd.aura_effect = "save_bonus"
	aura_hd.aura_radius = 2
	aura_hd.aura_value = 3
	var s_aura := BattleState.new()
	s_aura.combatant_positions[g_idx] = Vector2i(5, 5)
	s_aura.combatant_positions[c_idx] = Vector2i(6, 6)  # Chebyshev 1 <= 2
	_eq("aura: aliado em alcance recebe +bônus", s_aura._collect_aura_bonus(c_idx, "save_bonus"), 3)
	s_aura.combatant_positions[c_idx] = Vector2i(9, 9)  # Chebyshev 4 > 2
	_eq("aura: aliado fora do alcance não recebe", s_aura._collect_aura_bonus(c_idx, "save_bonus"), 0)
	s_aura.combatant_positions[c_idx] = Vector2i(6, 6)
	s_aura.dead_indices[g_idx] = true  # emissor morto não concede aura
	_eq("aura: emissor morto não concede", s_aura._collect_aura_bonus(c_idx, "save_bonus"), 0)
	# Restaura HeroData estático para não vazar para outros testes.
	aura_hd.aura_effect = ""
	aura_hd.aura_radius = 0
	aura_hd.aura_value = 0

	# ── 3.9 A5: recursos genéricos (pool de cura + ação extra) ───────────────
	BattleState.setup_party(["Guerreiro"])
	BattleState.PLAYERS[0]["pools"] = {"lay_on_hands": {"current": 5, "max": 5}}
	BattleState.PLAYERS[0]["extra_action_charges"] = 1
	var s_res := BattleState.new()
	s_res.active_index = 0
	_true("_spend_pool gasta do pool", s_res._spend_pool(0, "lay_on_hands", 3))
	_eq("pool reduzido após gasto", BattleState.PLAYERS[0]["pools"]["lay_on_hands"]["current"], 2)
	_true("_spend_pool bloqueia quando insuficiente", not s_res._spend_pool(0, "lay_on_hands", 5))
	s_res.has_attacked = true
	_true("grant_extra_action devolve a Ação", s_res.grant_extra_action(0))
	_true("grant_extra_action reseta has_attacked", not s_res.has_attacked)
	_eq("ação extra consumiu a carga", BattleState.PLAYERS[0]["extra_action_charges"], 0)
	_true("grant_extra_action falha sem cargas", not s_res.grant_extra_action(0))

	# ══════════════════════════════════════════════════════════════════════════
	# CHEBYSHEV: alcance e raio de AoE incluem diagonais (área quadrada)
	# Posicionado no FIM de _run_all (usa setup_party; pode deixar o estado
	# estático alterado, mas nenhum teste roda depois).
	# ══════════════════════════════════════════════════════════════════════════

	# Alcance de mira ranged: tile diagonal com Chebyshev<=range entra na área,
	# mesmo com Manhattan>range (antes excluído pelo losango).
	var cheb_area := _battlefield()
	cheb_area.active_index = 0                 # Guerreiro em (2,3)
	cheb_area.current_attack_range = 4
	var cheb_origin: Vector2i = cheb_area.combatant_positions[0]
	var cheb_diag_tile := cheb_origin + Vector2i(3, 3)  # Chebyshev 3 (<=4), Manhattan 6 (>4)
	_true("get_attack_area_tiles inclui tile diagonal ranged (Chebyshev)",
		cheb_area.get_attack_area_tiles().has(cheb_diag_tile))

	# enter_attack_mode (ranged) mira inimigo na diagonal pura fora do alcance Manhattan.
	BattleState.setup_party(["Mago", "Guerreiro"])
	var cheb_tgt := BattleState.new()
	cheb_tgt.active_index = 0
	for i in range(BattleState.TURN_QUEUE.size()):
		cheb_tgt.combatant_positions[i] = Vector2i(0, 0)
	cheb_tgt.combatant_positions[0] = Vector2i(3, 3)
	var cheb_enemy_i := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		if not BattleState.TURN_QUEUE[i]["is_player"]:
			cheb_enemy_i = i
			break
	cheb_tgt.combatant_positions[cheb_enemy_i] = Vector2i(6, 6)  # Cheb 3, Manhattan 6
	cheb_tgt.enter_attack_mode(4, false)
	_true("enter_attack_mode mira inimigo diagonal ranged (Chebyshev)",
		cheb_tgt.attack_target_indices.has(cheb_enemy_i))

	# Raio de AoE: respingo atinge alvo na diagonal pura do primário (Chebyshev).
	BattleState.setup_party(["Mago", "Guerreiro", "Clérigo"])
	var cheb_aoe := BattleState.new()
	cheb_aoe.active_index = 0
	cheb_aoe.current_aoe_radius = 1
	var cheb_act := SpellFogo.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		cheb_aoe.combatant_positions[i] = Vector2i(0, 0)
	var cheb_prim := 3
	var cheb_diag := 4
	cheb_aoe.combatant_positions[cheb_prim] = Vector2i(8, 4)
	cheb_aoe.combatant_positions[cheb_diag] = Vector2i(9, 5)  # diagonal do primário: Cheb 1, Manhattan 2
	cheb_aoe.enemy_hp[BattleState.TURN_QUEUE[cheb_diag]["name"]] = 100
	cheb_aoe.pending_surface_hits.clear()
	cheb_aoe._apply_aoe_splash(cheb_prim, 20, 999, cheb_act)
	var cheb_diag_hit := false
	for h in cheb_aoe.pending_surface_hits:
		if h.get("target_idx", -1) == cheb_diag:
			cheb_diag_hit = true
			break
	_true("respingo de AoE atinge alvo na diagonal (Chebyshev)", cheb_diag_hit)
