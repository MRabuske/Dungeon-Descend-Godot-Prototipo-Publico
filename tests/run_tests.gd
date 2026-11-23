extends SceneTree

var _passed := 0
var _failed := 0
# Um erro de runtime aborta a função de teste em silêncio e o que vem depois nunca roda. Cada função
# de alto nível registra aqui que chegou ao fim; se faltar, a suíte falha (ver _check_completion).
var _reached: Array = []
const EXPECTED_TO_FINISH := ["_run_all", "_test_architecture_p2p7", "_test_bg3_rules_audit", "_test_movement_8dir", "_test_unified_metric", "_test_pass_through_allies", "_test_potion_cover_initiative", "_test_phase5_bg3_fixes", "_test_area_shapes", "_test_area_integration", "_test_shared_turn", "_test_enemy_target_downed", "_test_member_end_turn", "_test_class_registry", "_test_gamepad_support", "_test_hud_navigation", "_test_battle_scene_smoke", "_test_oa_preview", "_test_focus_ring"]

# Os testes só gravam nesta pasta própria; o save do jogador fica em outro arquivo e nunca é
# aberto para escrita nem apagado. Ao fim, a suíte prova que ele não mudou (_check_save_isolation).
const TEST_SAVE_DIR := "user://test_sandbox"

func _initialize() -> void:
	var player_save_path: String = DungeonState.SAVE_PATH
	var player_save_before: String = _fingerprint(player_save_path)   # só leitura
	DirAccess.make_dir_recursive_absolute(TEST_SAVE_DIR)
	DungeonState.SAVE_PATH = TEST_SAVE_DIR + "/save_sandbox.json"
	await _run_all()
	_check_completion()
	_check_save_isolation(player_save_path, player_save_before)
	_clear_save_sandbox()
	DungeonState.SAVE_PATH = player_save_path
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
			if tile.is_void() or tile.object == TerrainTile.ObjectType.OBSTACLE \
					or tile.object == TerrainTile.ObjectType.COVER:
				continue
			if not visited.has(nxt):
				frontier.append(nxt)
	return visited.keys()

func _run_all() -> void:
	var s := BattleState.new()

	# Initial state
	_eq("initial state is PLAYER_TURN", s.current_state, BattleState.State.PLAYER_TURN)
	_eq("initial active_index is 0",    s.active_index,    0)
	_eq("initial enemy_action_text is empty", s.enemy_action_text, "")
	_true("first combatant is player", s.is_player_turn())
	_eq("get_active_player_index returns 0 for Guerreiro", s.get_active_player_index(), 0)

	# PLAYERS have new fields
	_true("PLAYERS[0] has class field",       BattleState.PLAYERS[0].has("class"))
	_true("PLAYERS[0] has level field",       BattleState.PLAYERS[0].has("level"))
	_true("PLAYERS[0] has ac field",          BattleState.PLAYERS[0].has("ac"))
	_true("PLAYERS[0] não tem initiative fixa (D9: bônus só por features e efeitos)", not BattleState.PLAYERS[0].has("initiative"))
	_true("PLAYERS[0] has speed field",       BattleState.PLAYERS[0].has("speed"))
	_true("PLAYERS[0] has proficiency field", BattleState.PLAYERS[0].has("proficiency"))

	# TURN_QUEUE enemies have type and ac
	var enemy: Dictionary = BattleState.TURN_QUEUE[1]
	_true("enemy has is_player=false", not enemy["is_player"])
	_true("enemy has type field",      enemy.has("type"))
	_true("enemy has ac field",        enemy.has("ac"))

	# advance_turn to enemy: sets enemy_action_text
	s.advance_turn()
	_eq("advance_turn increments active_index to 1", s.active_index, 1)
	_eq("index 1 is ENEMY_TURN", s.current_state, BattleState.State.ENEMY_TURN)
	_true("enemy_action_text is non-empty after enemy turn", s.enemy_action_text.length() > 0)
	_eq("get_active_player_index returns -1 on enemy turn", s.get_active_player_index(), -1)

	# advance_turn to player: clears enemy_action_text
	s.advance_turn()
	_eq("index 2 (Mago) is PLAYER_TURN", s.current_state, BattleState.State.PLAYER_TURN)
	_eq("enemy_action_text cleared on player turn", s.enemy_action_text, "")

	# Full queue wrap. Com o turno compartilhado (D6) heróis consecutivos agem no MESMO turno, então
	# uma rodada completa são tantos advance_turn quanto "blocos" na fila (cada inimigo é um bloco).
	# Antes eram size() avanços (um por combatente).
	var s2 := BattleState.new()
	var round_blocks := 0
	var prev_was_hero := false
	for entry in BattleState.TURN_QUEUE:
		var is_hero: bool = entry["is_player"]
		if not (is_hero and prev_was_hero):
			round_blocks += 1
		prev_was_hero = is_hero
	for _i in range(round_blocks):
		s2.advance_turn()
	_eq("full queue wrap returns active_index to 0", s2.active_index, 0)
	_true("a fila tem menos blocos que combatentes (heróis consecutivos agrupam)", round_blocks < BattleState.TURN_QUEUE.size())
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

	# step_cursor within speed range (Guerreiro speed=7)
	m.step_cursor(Vector2i(1, 0))
	_eq("step_cursor(1,0) moves cursor right to (3,3)", m.cursor_tile, Vector2i(3, 3))

	# O cursor passa do limite de velocidade (seleção livre); o que bloqueia é a validade.
	# Guerreiro at (2,3), speed=7. Moving right 7 times = (9,3) válido. O 8º passo (10,3) é inválido.
	var ms := _battlefield()
	ms.enter_move_mode()
	for _i in range(7):
		ms.step_cursor(Vector2i(1, 0))
	_eq("cursor em (9,3), o limite de velocidade", ms.cursor_tile, Vector2i(9, 3))
	_true("tile no limite de velocidade é válido", ms.get_cursor_feedback()["valid"])
	ms.step_cursor(Vector2i(1, 0))
	_eq("cursor passa do limite de velocidade", ms.cursor_tile, Vector2i(10, 3))
	_true("tile além da velocidade é inválido", not ms.get_cursor_feedback()["valid"])
	_true("confirmar tile além da velocidade é rejeitado", not ms.apply_cursor_selection())
	_eq("seleção inválida não altera move_cursor", ms.move_cursor, Vector2i(2, 3))

	# Tile ocupado: o cursor entra nele (seleção livre), mas é inválido.
	# (3,4) is occupied by Clérigo (combatant_positions[5])
	var mb := _battlefield()
	mb.enter_move_mode()
	mb.step_cursor(Vector2i(1, 0))   # (2,3) → (3,3)
	mb.step_cursor(Vector2i(0, 1))   # (3,4) — ocupado
	_eq("cursor entra em tile ocupado", mb.cursor_tile, Vector2i(3, 4))
	_true("tile ocupado é inválido para mover", not mb.get_cursor_feedback()["valid"])

	# step_cursor clamped at grid boundary
	# Cursor starts at active position (2,3). Move left 4 times — should stop at x=0.
	var mg := _battlefield()
	mg.enter_move_mode()
	for _i in range(4):
		mg.step_cursor(Vector2i(-1, 0))
	_eq("cursor clamped at left grid boundary", mg.cursor_tile, Vector2i(0, 3))

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
	mx.step_cursor(Vector2i(2, 0))
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

	# get_enemy_move_path — Goblin Scout at (9,1), alcance 1, speed=6. Com a métrica única
	# (Chebyshev, diagonal = 1) o herói mais próximo é o Clérigo em (3,4), a 6 casas; o
	# pathfinder de 8 direções chega a uma casa adjacente a ele em 5 passos (antes: o alvo era
	# o Mago por Manhattan e o caminho andava 6 casas em linha reta).
	var en := _battlefield()
	en.advance_turn()  # active_index=1: Goblin Scout
	var en_path: Array[Vector2i] = en.get_enemy_move_path()
	_eq("enemy path usa a diagonal: 5 passos até junto do alvo mais próximo", en_path.size(), 5)
	_eq("enemy path termina adjacente (Chebyshev) ao Clérigo", BattleState.king_dist(en_path[-1], Vector2i(3, 4)), 1)

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

	# No spawn on VOID, OBSTACLE or COVER (Cobertura bloqueia o movimento, como o Obstáculo)
	var spawns_clean := true
	for pos in md.hero_spawns + md.enemy_spawns:
		var tile: TerrainTile = md.tile_data_map[pos.x][pos.y]
		if tile.is_void() or tile.object == TerrainTile.ObjectType.OBSTACLE \
				or tile.object == TerrainTile.ObjectType.COVER:
			spawns_clean = false
	_true("no spawn on VOID, OBSTACLE or COVER", spawns_clean)

	# Connectivity: all accessible tiles reachable from hero_spawns[0]
	var accessible: Array[Vector2i] = []
	for col in range(md.grid_cols):
		for row in range(md.grid_rows):
			var tile: TerrainTile = md.tile_data_map[col][row]
			if not tile.is_void() and tile.object != TerrainTile.ObjectType.OBSTACLE \
					and tile.object != TerrainTile.ObjectType.COVER:
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
	# Com 8 direções: (2,3)→(3,2)→…→(7,2) custa 5 e a diagonal para (8,3) entra na lama (2): total 7
	# (antes, em 4 direções, (8,3) custava 9). (8,2) custa 6. (9,3): 6 + 2 = 8 > 7, fora do alcance.
	var bm := _battlefield()
	bm.enter_move_mode()
	for c in range(3, 11):
		bm.tile_data_map[c][3].ground = TerrainTile.GroundType.MUD
	var mud_tiles := bm.get_reachable_tiles()
	_true("(8,2) reachable going around MUD row", Vector2i(8, 2) in mud_tiles)
	_eq("(8,3) alcançável pela diagonal, custo 5 + 2 (lama)", mud_tiles.get(Vector2i(8, 3), -1), 7)
	_true("(9,3) blocked by MUD cost >7",         not (Vector2i(9, 3) in mud_tiles))

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
	_eq("mage frost nova: emanação de 5 ft (era raio 1)", mage.action_behaviors[2].get("aoe_ft", 0), 5)
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
	var hmods := s_hide_adv._get_attack_roll_mods(0, 1, 1)
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

	# D5 (Q6): à vista, mesmo ao lado de Cobertura, o Hide é NEGADO (a exceção da cobertura saiu;
	# o jogo não tem obscuridade). Antes este caso "pode ter sucesso"; o teste foi invertido.
	var s_hide_cover := BattleState.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		if i != 0 and i != 1:
			s_hide_cover.dead_indices[i] = true
	s_hide_cover.combatant_positions[0] = Vector2i(1, 1)
	s_hide_cover.combatant_positions[1] = Vector2i(5, 1)              # vê (1,1)
	s_hide_cover.tile_data_map[1][2].object = TerrainTile.ObjectType.COVER   # cobertura vizinha, fora da linha
	seed(_find_seed_for_d20(20))
	_true("hide à vista, mesmo junto de Cobertura, é negado (D5)", not s_hide_cover.resolve_hide(0))
	_eq("hide negado junto de Cobertura não concede Oculto", s_hide_cover.combatant_statuses[0].get("hidden", 0), 0)

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

	# Sem regressão: alvo SOBRE cobertura (endpoint) continua mirável; a Cobertura não altera mais a rolagem (D5).
	var s_oncov := _battlefield()
	s_oncov.active_index = 0
	s_oncov._current_action = AtqNormal.new()
	s_oncov.combatant_positions[0] = Vector2i(2, 3)
	s_oncov.combatant_positions[1] = Vector2i(6, 3)
	s_oncov.tile_data_map[6][3].object = TerrainTile.ObjectType.COVER  # tile do ALVO
	s_oncov.enter_attack_mode(10, false)
	_true("alvo sobre cobertura (linha limpa) é mirável", 1 in s_oncov.attack_target_indices)
	_eq("alvo sobre cobertura rola SEM Desvantagem (D5: BG3 não tem cobertura)", s_oncov._get_attack_roll_mods(0, 1, 10)["dis"], 0)

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
	throw_item.area_kind = AreaShape.Kind.SPHERE
	throw_item.area_size_ft = 5
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
	throw_cond.area_kind = AreaShape.Kind.SPHERE
	throw_cond.area_size_ft = 5
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
	_eq("SkillChuvaFlechas área: esfera de 5 ft", [cf.area_kind, cf.area_size_ft], [AreaShape.Kind.SPHERE, 5])
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
	# Usos por combate: contados no estado (por herói), não no pp do Resource.
	var sv2 := SkillSegundoVento.new()
	s7._uses_spent[s7._uses_key(s7.get_active_player_index(), sv2)] = sv2.max_pp
	_true("is_item_available returns false when uses are spent",
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

	# Save: caminho isolado, gravação via temporário e saves malformados.
	_eq("save isolado: testes usam arquivo da pasta própria", DungeonState.SAVE_PATH, TEST_SAVE_DIR + "/save_sandbox.json")
	# delete_save e save mexem só no SAVE_PATH atual: um "save do jogador" simulado ao lado sobrevive.
	var decoy: String = TEST_SAVE_DIR + "/player_decoy.json"
	_write_save_text('{"decoy":true}', decoy)
	var decoy_state := DungeonState.new()
	decoy_state.generate(3)
	decoy_state.save()
	DungeonState.delete_save()
	_true("isolamento: delete_save não apaga o save simulado do jogador", FileAccess.file_exists(decoy))
	_eq("isolamento: o save simulado do jogador segue idêntico", FileAccess.get_file_as_string(decoy), '{"decoy":true}')
	# O guarda de impressão digital não é vacuoso: acusa criação, alteração e remoção.
	_eq("guarda: arquivo ausente = absent", _fingerprint(decoy + ".nope"), "absent")
	var fp_a: String = _fingerprint(decoy)
	_write_save_text('{"decoy":false}', decoy)
	_true("guarda: detecta alteração de conteúdo", _fingerprint(decoy) != fp_a)
	DirAccess.remove_absolute(decoy)
	_eq("guarda: detecta remoção", _fingerprint(decoy), "absent")
	# O fonte da suíte não pode citar o arquivo de save real (nome montado em runtime para não se achar).
	var real_name: String = "dungeon" + "_save.json"
	_true("isolamento: tests/run_tests.gd não cita o arquivo de save real",
		not FileAccess.get_file_as_string("res://tests/run_tests.gd").contains(real_name))
	var sgv := DungeonState.new()
	sgv.generate(7)
	sgv.save()
	sgv.enter_room(0)
	sgv.save()   # segundo save troca o arquivo existente
	_true("save: sem temporário sobrando", not FileAccess.file_exists(DungeonState.SAVE_PATH + ".tmp"))
	var sgv_loaded := DungeonState.load_save()
	_true("save: regravar mantém um save legível", sgv_loaded != null and sgv_loaded.nodes.size() == sgv.nodes.size())
	DungeonState.delete_save()
	_true("save: delete_save remove o arquivo do caminho atual", not FileAccess.file_exists(DungeonState.SAVE_PATH))
	var sgv_good := '{"id":0,"floor":0,"type":0,"completed":false,"pos_x":1,"pos_y":2,"connections":[]}'
	var sgv_bad := {
		"JSON inválido": "{nao e json",
		"raiz não é objeto": "[1,2,3]",
		"sem nós": '{"run_seed":1,"nodes":[]}',
		"nó sem chave": '{"nodes":[{"id":0,"floor":0}]}',
		"nó não é objeto": '{"nodes":[5]}',
		"connections não é lista": '{"nodes":[{"id":0,"floor":0,"type":0,"completed":false,"pos_x":1,"pos_y":2,"connections":7}]}',
		"nodes null": '{"nodes":null}',
	}
	for sgv_lbl in sgv_bad:
		_write_save_text(sgv_bad[sgv_lbl])
		_true("save malformado (%s) devolve null" % sgv_lbl, DungeonState.load_save() == null)
	_write_save_text('{"party_names":null,"pending_buffs":5,"revealed":"x","nodes":[%s]}' % sgv_good)
	var sgv_tol := DungeonState.load_save()
	_true("save com listas inválidas fora dos nós ainda carrega", sgv_tol != null and sgv_tol.nodes.size() == 1 and sgv_tol.party_names.is_empty())
	DungeonState.delete_save()

	# Versão do formato e status do save.
	_eq("status: sem arquivo = NONE", DungeonState.save_status(), DungeonState.SaveStatus.NONE)
	var sgv_ver := DungeonState.new()
	sgv_ver.generate(11)
	sgv_ver.save()
	var sgv_saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(DungeonState.SAVE_PATH))
	_eq("versão: save() grava o campo version", int(sgv_saved.get("version", -1)), DungeonState.SAVE_VERSION)
	_eq("status: save recém-gravado = VALID", DungeonState.save_status(), DungeonState.SaveStatus.VALID)
	# Saves anteriores (sem o campo version = v0) seguem carregando como antes.
	sgv_saved.erase("version")
	_write_save_text(JSON.stringify(sgv_saved))
	var sgv_legacy := DungeonState.load_save()
	_true("compat: save legado sem version carrega", sgv_legacy != null and sgv_legacy.nodes.size() == sgv_ver.nodes.size() and sgv_legacy.run_seed == sgv_ver.run_seed)
	sgv_saved["version"] = 0
	_write_save_text(JSON.stringify(sgv_saved))
	_eq("compat: version 0 explícita = VALID", DungeonState.save_status(), DungeonState.SaveStatus.VALID)
	# Versão mais nova: não carrega, não é "corrompido" e o arquivo fica intacto.
	sgv_saved["version"] = DungeonState.SAVE_VERSION + 1
	var sgv_newer_text: String = JSON.stringify(sgv_saved)
	_write_save_text(sgv_newer_text)
	_eq("versão mais nova = NEWER", DungeonState.save_status(), DungeonState.SaveStatus.NEWER)
	_true("versão mais nova: load_save devolve null", DungeonState.load_save() == null)
	_eq("versão mais nova: arquivo intacto", FileAccess.get_file_as_string(DungeonState.SAVE_PATH), sgv_newer_text)
	_eq("versão mais nova: quarentena não é pedida pelo status", DungeonState.save_status() == DungeonState.SaveStatus.CORRUPT, false)
	# Versão inválida = corrompido.
	for sgv_badver in ["1", -1, null]:
		sgv_saved["version"] = sgv_badver
		_write_save_text(JSON.stringify(sgv_saved))
		_eq("versão inválida (%s) = CORRUPT" % str(sgv_badver), DungeonState.save_status(), DungeonState.SaveStatus.CORRUPT)
	# Quarentena: guarda os bytes do save corrompido em vez de apagá-los (botão Continuar).
	_write_save_text("{lixo 1")
	var sgv_q1: String = DungeonState.quarantine_corrupt_save()
	_true("quarentena: caminho .corrupt.json", sgv_q1.ends_with(".corrupt.json"))
	_true("quarentena: save original saiu do lugar", not FileAccess.file_exists(DungeonState.SAVE_PATH))
	_eq("quarentena: bytes preservados", FileAccess.get_file_as_string(sgv_q1), "{lixo 1")
	_eq("quarentena: depois dela o status é NONE (botão Continuar some)", DungeonState.save_status(), DungeonState.SaveStatus.NONE)
	_write_save_text("{lixo 2")
	var sgv_q2: String = DungeonState.quarantine_corrupt_save()
	_true("quarentena: segunda não sobrescreve a primeira", sgv_q2 != sgv_q1 and FileAccess.get_file_as_string(sgv_q1) == "{lixo 1" and FileAccess.get_file_as_string(sgv_q2) == "{lixo 2")
	_eq("quarentena sem save devolve vazio", DungeonState.quarantine_corrupt_save(), "")
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
	s_advmods.active_index = 0
	s_advmods.current_attack_range = 1
	var _advmods_res: Dictionary = s_advmods.get_active_attack_roll_mods(_advmods_tgt)
	_true("get_active_attack_roll_mods is public", _advmods_res.has("adv") and _advmods_res.has("dis") and _advmods_res.has("flat"))
	_true("get_active_attack_roll_mods reflects furtivo advantage", int(_advmods_res.get("adv", 0)) >= 1)

	# ── Preview usa o combatente ATIVO (índice de TURN_QUEUE, não de PLAYERS) ──
	var _pv_tq: Array = BattleState.TURN_QUEUE
	var _pv_pl: Array = BattleState.PLAYERS
	BattleState.setup_party(["Guerreiro", "Mago"])
	var _pv_en: Dictionary = BattleState.TURN_QUEUE[2]
	BattleState.TURN_QUEUE.remove_at(2)
	BattleState.TURN_QUEUE.insert(0, _pv_en)          # [inimigo, Guerreiro, Mago, ...]
	var s_pv := BattleState.new()
	s_pv.active_index = 2                              # Mago: PLAYERS[1], TURN_QUEUE[2]
	s_pv.current_attack_range = 1
	s_pv.combatant_statuses[2]["blinded"] = 2
	_eq("preview: mods do ativo (Mago cego → dis 1)", s_pv.get_active_attack_roll_mods(3)["dis"], 1)
	s_pv.combatant_statuses[1]["invisible"] = 2        # TURN_QUEUE[1] = índice PLAYERS do Mago
	_eq("preview: status de TURN_QUEUE[idx PLAYERS] não contamina", s_pv.get_active_attack_roll_mods(3)["adv"], 0)
	s_pv.active_index = 0                              # turno de inimigo
	_eq("preview: fora do turno de jogador → neutro", s_pv.get_active_attack_roll_mods(3)["dis"], 0)
	BattleState.TURN_QUEUE = _pv_tq
	BattleState.PLAYERS = _pv_pl

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

	# D5: Player attack against a target on COVER rola NORMAL (a cobertura deixou de dar Desvantagem)
	# (substitui o antigo flat 30% miss).
	var cov := _battlefield()
	cov.active_index = 0
	cov._current_action = AtqNormal.new()
	cov.combatant_positions[1] = Vector2i(3, 3)            # alvo adjacente ao Guerreiro
	cov.tile_data_map[3][3].object = TerrainTile.ObjectType.COVER
	cov.enter_attack_mode(1, false)
	cov.confirm_attack()
	_eq("player attack vs COVER target rolls normal (D5)",
		cov.last_attack_info.get("roll_mode", ""), "normal")

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
	var gi_r: int = 1   # identidade = índice da fila (inimigo atual em TURN_QUEUE[1])
	var gmax := tob_st.get_enemy_max_hp(gi_r)
	tob_st.enemy_hp[BattleState.TURN_QUEUE[gi_r]["name"]] = int(gmax / 2)
	tob2._state_ref = tob_st
	var er := tob2._hp_ratio(combat_e, gi_r)
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
	var gi_v: int = 1
	var gmx := tob3_st.get_enemy_max_hp(gi_v)
	tob3_st.enemy_hp[BattleState.TURN_QUEUE[gi_v]["name"]] = 7
	tob3._state_ref = tob3_st
	var hve := tob3._hp_values({"name": "Goblin Scout", "is_player": false, "type": "Goblin"}, gi_v)
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
	_eq("SpellFogo área: esfera de 5 ft", [SpellFogo.new().area_kind, SpellFogo.new().area_size_ft], [AreaShape.Kind.SPHERE, 5])
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

	# --- Éter removido (D7: não existe no BG3, era resto do antigo sistema de mana) ---
	# Antes este teste provava que o Éter devolvia +1 slot; agora prova que isso não existe mais.
	# Party Mago já ativa (PLAYERS[0] = Mago, ativo no índice 0).
	var s_item := BattleState.new()
	s_item.active_index = 0
	BattleState.PLAYERS[0]["spell_slots"]     = [1, 0, 0, 0, 0, 0]
	BattleState.PLAYERS[0]["spell_slots_max"] = [4, 3, 0, 0, 0, 0]
	s_item.use_item({"label": "Éter", "count": 1, "is_item": true, "spell_slot_restore": 1})
	_eq("item com spell_slot_restore não devolve slot", BattleState.PLAYERS[0]["spell_slots"][0], 1)
	var item_labels: Array = []
	for it in BattleState.TAB_ITEMS:
		item_labels.append(it["label"])
	_eq("o único item de combate é a Poção", item_labels, ["Poção"])

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

	# cover no alvo → sem efeito (D5)
	s_mods.tile_data_map[2][0].object = TerrainTile.ObjectType.COVER
	var m_cover := s_mods._get_attack_roll_mods(0, 2, 1)
	_eq("cover: dis=0 (D5)", m_cover["dis"], 0)
	_eq("cover: adv=0", m_cover["adv"], 0)
	s_mods.tile_data_map[2][0].object = TerrainTile.ObjectType.NONE

	# elevated: flat +2 em QUALQUER ataque (NÃO advantage); BG3 High_ground: "apply to all attack rolls, even melee ones"
	s_mods.tile_data_map[0][0].ground = TerrainTile.GroundType.ELEVATED
	var m_elev_ranged := s_mods._get_attack_roll_mods(0, 2, 5)
	_eq("elevated+ranged: adv=0",   m_elev_ranged["adv"],  0)
	_eq("elevated+ranged: flat=+2", m_elev_ranged["flat"], 2)
	var m_elev_melee := s_mods._get_attack_roll_mods(0, 2, 1)
	_eq("elevated+melee: flat=+2 (Fase 5: vale também no corpo a corpo)", m_elev_melee["flat"], 2)
	s_mods.tile_data_map[0][0].ground = TerrainTile.GroundType.NORMAL

	# furtivo + cover → só a Vantagem do furtivo (a cobertura não conta mais)
	s_mods.combatant_statuses[0]["furtivo"] = 1
	s_mods.tile_data_map[2][0].object = TerrainTile.ObjectType.COVER
	var m_cancel := s_mods._get_attack_roll_mods(0, 2, 1)
	_eq("furtivo+cover: adv=1 dis=0", m_cancel["adv"] == 1 and m_cancel["dis"] == 0, true)
	s_mods.combatant_statuses[0].erase("furtivo")
	s_mods.tile_data_map[2][0].object = TerrainTile.ObjectType.NONE

	# ── _get_save_roll_mods ───────────────────────────────────────────────────
	var s_srm := BattleState.new()
	# stun (BG3): não dá desvantagem em saves; falha FOR/DES sozinho (ver _resolve_saving_throw)
	s_srm.combatant_statuses[0]["stun"] = 1
	var srm_stun := s_srm._get_save_roll_mods(0)
	_eq("stun: save dis=0 (BG3 usa falha automática)", srm_stun["dis"], 0)
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

	# Cover → roll_mode == "normal" (D5)
	var s_dis := BattleState.new()
	s_dis.active_index = 0
	s_dis._current_action = AtqNormal.new()
	s_dis.enemy_hp["Goblin Scout"] = 200
	for i in range(BattleState.TURN_QUEUE.size()):
		s_dis.combatant_positions[i] = Vector2i(i, 0)
	s_dis.tile_data_map[2][0].object = TerrainTile.ObjectType.COVER
	seed(_find_seed_for_d20(15))
	s_dis._apply_attack(2)
	_eq("cover: roll_mode is normal (D5)",
		s_dis.last_attack_info.get("roll_mode", ""), "normal")

	# ── _apply_attack com Saving Throw ───────────────────────────────────────
	# Mago (idx 1) lança SpellFogo no Goblin (idx 2).
	var s_save := BattleState.new()
	s_save.active_index = 1
	var spell_fogo_t := SpellFogo.new()
	spell_fogo_t.requires_saving_throw = true  # setado manualmente até Task 8
	s_save._current_action = spell_fogo_t
	s_save._attack_targets_allies = false
	s_save.current_attack_range = spell_fogo_t.attack_range
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
	# Fase 5: estes dois descrevem regras que o BG3 tem e o jogo passou a implementar (Cego reduz o
	# alcance a 3 m; Amedrontado "Cannot move"). As asserções eram o oposto, enquanto não existiam.
	_true("blinded desc cita o alcance reduzido (3 m = 2 casas)",
		StatusDefinitions.desc_of("blinded").contains("alcance reduzido"))
	_true("frightened desc: 'Não pode se mover' (BG3)",
		StatusDefinitions.desc_of("frightened").contains("Não pode se mover"))
	_true("frightened desc não fala mais de fonte do medo",
		not StatusDefinitions.desc_of("frightened").contains("fonte do medo"))

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
	# BG3: Envenenado = desvantagem em ataques e testes de habilidade, NÃO em saving throws.
	_eq("Envenenado saver has dis=0 (BG3)", pmods_sv["dis"], 0)

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
	var aoe_action := SpellFogo.new()  # save_attribute = DEX
	for i in range(BattleState.TURN_QUEUE.size()):
		bs_aoe.combatant_positions[i] = Vector2i(i, 6)  # estacionados, espalhados
	var aoe_prim_i := 3                # primeiro inimigo (idx 3 após 3 players)
	var aoe_ally_i := 1               # Guerreiro — aliado do conjurador
	var aoe_enemy_i := 4              # segundo inimigo
	bs_aoe.combatant_positions[aoe_prim_i]  = Vector2i(5, 2)
	bs_aoe.combatant_positions[aoe_ally_i]  = Vector2i(5, 3)  # dentro da esfera de 5 ft no cruzamento (6,3)
	bs_aoe.combatant_positions[aoe_enemy_i] = Vector2i(6, 2)  # idem
	var aoe_tiles := bs_aoe.area_footprint(aoe_action, Vector2i(6, 3), 0)   # esfera de 5 ft: (5,2),(6,2),(5,3),(6,3)
	var aoe_ally_pidx := bs_aoe._player_index_by_name("Guerreiro")
	var aoe_enemy_name: String = BattleState.TURN_QUEUE[aoe_enemy_i]["name"]
	# (a) DC impossível → ambos falham o save → dano cheio.
	BattleState.PLAYERS[aoe_ally_pidx]["hp"] = 100
	bs_aoe.enemy_hp[aoe_enemy_name] = 100
	bs_aoe._area_damage(aoe_tiles, 20, 999, aoe_action, [0, aoe_prim_i], true)
	_eq("AoE dano atinge ALIADO no raio (friendly fire)",
		100 - BattleState.PLAYERS[aoe_ally_pidx]["hp"], 20)
	_eq("AoE dano atinge INIMIGO no raio",
		100 - bs_aoe.enemy_hp[aoe_enemy_name], 20)
	# (b) DC trivial + d20 alto forçado → secundário passa → metade.
	BattleState.PLAYERS[aoe_ally_pidx]["hp"] = 100
	bs_aoe.enemy_hp[aoe_enemy_name] = 100
	seed(_find_seed_for_d20(20))
	bs_aoe._area_damage(aoe_tiles, 20, 1, aoe_action, [0, aoe_prim_i], true)
	_eq("AoE secundário que passou no save toma metade (aliado)",
		100 - BattleState.PLAYERS[aoe_ally_pidx]["hp"], 10)
	# (c) Chamada legada (dc=0) → dano flat, sem save.
	BattleState.PLAYERS[aoe_ally_pidx]["hp"] = 100
	bs_aoe.enemy_hp[aoe_enemy_name] = 100
	bs_aoe._area_damage(aoe_tiles, 8, 0, aoe_action, [0, aoe_prim_i])
	_eq("AoE legacy splash aplica dano flat (aliado)",
		100 - BattleState.PLAYERS[aoe_ally_pidx]["hp"], 8)
	_eq("AoE legacy splash aplica dano flat (inimigo)",
		100 - bs_aoe.enemy_hp[aoe_enemy_name], 8)

	# ── Respingo de AoE do JOGADOR (centrado em criatura) gera floater por alvo ─
	BattleState.setup_party(["Mago", "Guerreiro", "Clérigo"])
	var bs_spf := BattleState.new()
	bs_spf.active_index = 0
	var spf_action := SpellFogo.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		bs_spf.combatant_positions[i] = Vector2i(i, 9)
	var spf_prim := 3
	var spf_enemy2 := 4
	bs_spf.combatant_positions[spf_prim]   = Vector2i(5, 2)
	bs_spf.combatant_positions[spf_enemy2] = Vector2i(5, 3)  # raio 1 do primário
	bs_spf.enemy_hp[BattleState.TURN_QUEUE[spf_enemy2]["name"]] = 100
	bs_spf.pending_surface_hits.clear()
	bs_spf._area_damage(bs_spf.area_footprint(spf_action, Vector2i(6, 3), 0), 20, 999, spf_action, [0, spf_prim], true)
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
	s_eaoe._apply_enemy_aoe_attack({"aoe_ft": 10, "damage_mult": 1.0})
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
	for i in range(BattleState.TURN_QUEUE.size()):
		bs_tile.combatant_positions[i] = Vector2i(0, i)  # todos longe por padrão
	var tile_center := Vector2i(6, 5)   # CRUZAMENTO (esfera de 5 ft): casas (5,4), (6,4), (5,5), (6,5); nenhuma criatura sobre (5,5)
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
	bs_tile.apply_area_at(tile_center)
	_true("AoE tile vazio atinge inimigo no raio", bs_tile.enemy_hp[tile_enemy_name] < 100)
	_true("AoE tile vazio atinge ALIADO no raio (friendly fire)",
		BattleState.PLAYERS[tile_ally_pidx]["hp"] < 100)
	_eq("AoE tile vazio NAO atinge o conjurador",
		BattleState.PLAYERS[tile_caster_pidx]["hp"], 100)
	_eq("AoE no cruzamento deposita superficie FIRE nas casas da esfera",
		bs_tile.tile_surfaces.get(Vector2i(5, 5), {}).get("type", -1), SurfaceType.Type.FIRE)
	_eq("AoE tile vazio acende inimigo no raio (burning)",
		bs_tile.combatant_statuses[tile_enemy_i].get("burning", 0), 2)
	_true("AoE tile vazio enfileira floaters por alvo",
		not bs_tile.pending_surface_hits.is_empty())

	# ── AoE em ponto: o cursor anda livre; o alcance só vale na confirmação ────
	var bs_mv := _battlefield()
	bs_mv.active_index = 0
	bs_mv.current_state = BattleState.State.ATTACK_MODE
	bs_mv.current_attack_range = 2
	bs_mv.attack_tile_mode = true
	bs_mv.cursor_tile = bs_mv.combatant_positions[0]
	for _k in range(10):
		bs_mv.step_cursor(Vector2i(1, 0))
	var mv_origin: Vector2i = bs_mv.combatant_positions[0]
	_true("step_cursor ignora o alcance de mira", BattleState.king_dist(bs_mv.cursor_tile, mv_origin) > bs_mv.current_attack_range)
	_eq("cursor além do alcance: Fora de alcance", bs_mv.get_cursor_feedback()["reason"], "Fora de alcance")

	# ── AoE: confirmar só em tile válido do alcance ────────────────────────────
	var s_hov := _battlefield()
	s_hov.active_index = 0
	s_hov.current_state = BattleState.State.ATTACK_MODE
	s_hov.current_attack_range = 2
	s_hov.attack_tile_mode = true
	var hov_origin: Vector2i = s_hov.combatant_positions[0]
	s_hov.attack_tile_cursor = hov_origin
	var hov_valid := hov_origin + Vector2i(1, 0)   # dist 1 <= 2
	var hov_far := hov_origin + Vector2i(9, 0)      # fora do alcance
	s_hov.set_cursor_tile(hov_valid)
	_true("hover válido é aceito na confirmação", s_hov.apply_cursor_selection())
	_eq("seleção foi para o tile válido", s_hov.attack_tile_cursor, hov_valid)
	s_hov.set_cursor_tile(hov_far)
	_true("hover fora do alcance é rejeitado", not s_hov.apply_cursor_selection())
	_eq("seleção mantém o último válido", s_hov.attack_tile_cursor, hov_valid)

	# ── AoE de CURA respinga nos aliados adjacentes ─────────────────────────
	BattleState.setup_party(["Clérigo", "Guerreiro", "Mago"])
	var bs_heal := BattleState.new()
	bs_heal.active_index = 0            # Clérigo lança (WIS alta → cura > 0)
	bs_heal._attack_targets_allies = true
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
	s_oa.combatant_statuses[GUER_I]["disengage"] = false   # volta a provocar para os testes abaixo
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

	# ── Disengage vale para o turno INTEIRO, contra qualquer inimigo (decisão do projeto: BG3 e
	# D&D 2024 concordam). Antes só isentava quem já estava adjacente no momento do uso; este
	# teste foi reescrito (não removido) para a regra nova. ───────────────────────────────────
	var ORC_I := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		if BattleState.TURN_QUEUE[i].get("name", "") == "Orc Warrior":
			ORC_I = i
			break
	var s_dz := BattleState.new()
	s_dz.combatant_positions[GUER_I] = Vector2i(5, 7)
	s_dz.combatant_positions[GOBL_I] = Vector2i(5, 6)  # adjacente no momento do disengage
	s_dz.combatant_positions[ORC_I]  = Vector2i(6, 5)  # longe no momento do disengage
	# Sem Disengage, sair do alcance de AMBOS provoca os dois.
	s_dz.combatant_positions[GUER_I] = Vector2i(5, 5)
	var dz_before := s_dz.check_opportunity_attacks(GUER_I, Vector2i(5, 5), Vector2i(1, 1))
	_true("sem Disengage: Goblin e Orc fazem OA ao sair do alcance dos dois",
		dz_before.has(GOBL_I) and dz_before.has(ORC_I))
	s_dz.apply_disengage(GUER_I)
	var dz_oa := s_dz.check_opportunity_attacks(GUER_I, Vector2i(5, 5), Vector2i(1, 1))
	_true("Disengage: nem o Orc (adjacente só depois) nem o Goblin fazem OA", dz_oa.is_empty())
	_true("Disengage dura o turno todo: segue valendo em movimentos posteriores",
		s_dz.check_opportunity_attacks(GUER_I, Vector2i(1, 1), Vector2i(5, 5)).is_empty())
	# O flag some quando o turno do próprio Guerreiro recomeça (a rodada seguinte).
	s_dz.advance_turn()
	_true("Disengage ainda vale durante os turnos dos outros", s_dz.combatant_statuses[GUER_I].get("disengage", false))
	var dz_guard := 0
	while s_dz.active_index != GUER_I and dz_guard < BattleState.TURN_QUEUE.size() + 2:
		s_dz.advance_turn()
		dz_guard += 1
	_true("Disengage acaba no início do turno seguinte do Guerreiro",
		s_dz.active_index == GUER_I and not s_dz.combatant_statuses[GUER_I].get("disengage", false))

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
	var sd_fogo := SpellFogo.new()  # esfera de 5 ft: a mira é um CRUZAMENTO
	surf_diag._deposit_surface_after_attack(sd_center, sd_fogo)
	_eq("superfície cobre a casa diagonal do cruzamento (4,4)",
		surf_diag.tile_surfaces.get(sd_center + Vector2i(-1, -1), {}).get("type", -1),
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
	# ── Prone (BG3): vantagem a até 3 m (<= 2 tiles); sem desvantagem à distância ──
	var prone_ranged := prone_state._get_attack_roll_mods(0, 1, 5)  # ranged, alvo a 7 tiles
	_eq("prone alvo ranged distante = sem dis (BG3)", prone_ranged["dis"], 0)
	_eq("prone alvo ranged distante = sem adv", prone_ranged["adv"], 0)
	prone_state.combatant_positions[1] = Vector2i(4, 3)   # Guerreiro em (2,3): 2 tiles
	_eq("prone alvo ranged a 2 tiles = adv", prone_state._get_attack_roll_mods(0, 1, 5)["adv"], 1)
	prone_state.combatant_positions[1] = Vector2i(5, 3)   # 3 tiles: fora dos 3 m
	_eq("prone alvo ranged a 3 tiles = sem adv", prone_state._get_attack_roll_mods(0, 1, 5)["adv"], 0)

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
	var DT_L := ActionData.DamageType.LIGHTNING
	_eq("Wet dobra LIGHTNING (BG3)",              bs_mit._mitigate(5, DT_L, [], [], [], true), 10)
	_eq("Wet não afeta THUNDER (BG3)",            bs_mit._mitigate(5, DT_T, [], [], [], true), 5)
	_eq("Wet: resistência a FIRE (BG3)",          bs_mit._mitigate(5, DT_F, [], [], [], true), 2)
	_eq("Wet + vulnerável a FIRE cancelam",       bs_mit._mitigate(5, DT_F, [], ["FIRE"], [], true), 5)
	_eq("Wet + resistência COLD cancelam",        bs_mit._mitigate(6, DT_C, ["COLD"], [], [], true), 6)
	_eq("imunidade vence Wet",                    bs_mit._mitigate(6, DT_C, [], [], ["COLD"], true), 0)
	_true("HUD do Wet descreve resistência a Fogo (BG3)", String(StatusDefinitions.REGISTRY["wet"]["desc"]).contains("Fogo"))

	# ── Tipos de dano BG3 (13 tipos + HEALING) ───────────────────────────────
	var dt_keys: Array = ActionData.DamageType.keys()
	for _dtn in ["SLASHING", "PIERCING", "BLUDGEONING", "ACID", "COLD", "FIRE", "FORCE",
			"LIGHTNING", "NECROTIC", "POISON", "PSYCHIC", "RADIANT", "THUNDER", "HEALING"]:
		_true("DamageType tem %s" % _dtn, dt_keys.has(_dtn))
	_true("DamageType sem PHYSICAL/ARCANE (não são tipos BG3)", not dt_keys.has("PHYSICAL") and not dt_keys.has("ARCANE"))
	_eq("cor definida p/ POISON", ActionData.damage_type_color(ActionData.DamageType.POISON) != Color.WHITE, true)
	# Armas (BG3): tipo físico por arma
	var DTY := ActionData.DamageType
	_eq("Longsword = SLASHING",     BattleState.ALL_HERO_DATA["Guerreiro"].weapon.damage_type, DTY.SLASHING)
	_eq("Greataxe = SLASHING",      BattleState.ALL_HERO_DATA["Bárbaro"].weapon.damage_type, DTY.SLASHING)
	_eq("Shortsword = PIERCING",    BattleState.ALL_HERO_DATA["Ladrao"].weapon.damage_type, DTY.PIERCING)
	_eq("Longbow = PIERCING",       BattleState.ALL_HERO_DATA["Arqueiro"].weapon.damage_type, DTY.PIERCING)
	_eq("Mace = BLUDGEONING",       BattleState.ALL_HERO_DATA["Clérigo"].weapon.damage_type, DTY.BLUDGEONING)
	_eq("Quarterstaff = BLUDGEONING", BattleState.ALL_HERO_DATA["Mago"].weapon.damage_type, DTY.BLUDGEONING)
	_eq("Unarmed = BLUDGEONING",    BattleState.ALL_HERO_DATA["Monge"].weapon.damage_type, DTY.BLUDGEONING)
	_eq("Trovão eletrifica água → LIGHTNING", SpellTrovao.new().damage_type, DTY.LIGHTNING)
	_eq("Raio Arcano → FORCE",      AtqArcano.new().damage_type, DTY.FORCE)
	_eq("Nuvem de Adagas → SLASHING", SpellCloudOfDaggers.new().damage_type, DTY.SLASHING)
	_eq("Soco → BLUDGEONING",       AtqSoco.new().damage_type, DTY.BLUDGEONING)
	_eq("Chuva de Flechas → PIERCING", SkillChuvaFlechas.new().damage_type, DTY.PIERCING)
	# Inimigos: tipo padrão do ataque + override por comportamento
	_eq("Goblin ataca SLASHING",    BattleState.ALL_ENEMIES["Goblin"].attack_damage_type, DTY.SLASHING)
	_eq("Goblin adaga arremessada PIERCING", BattleState.ALL_ENEMIES["Goblin"].action_behaviors[2].get("damage_type", -1), DTY.PIERCING)
	_eq("Skeleton Archer PIERCING", BattleState.ALL_ENEMIES["Undead"].attack_damage_type, DTY.PIERCING)
	_eq("Dark Mage Shadow Bolt NECROTIC (padrão)", BattleState.ALL_ENEMIES["Mage"].attack_damage_type, DTY.NECROTIC)
	_eq("Dark Mage Frost Nova COLD", BattleState.ALL_ENEMIES["Mage"].action_behaviors[2].get("damage_type", -1), DTY.COLD)
	_eq("Elite Mage Ice Storm COLD", BattleState.ALL_ENEMIES["EliteMage"].action_behaviors[2].get("damage_type", -1), DTY.COLD)
	_eq("Guardian Shockwave THUNDER", BattleState.ALL_ENEMIES["DungeonGuardian"].action_behaviors[2].get("damage_type", -1), DTY.THUNDER)

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

	# (a) Ataque de JOGADOR (Longsword = SLASHING) vs inimigo imune a SLASHING → 0 dano
	BattleState.setup_party(["Guerreiro"])
	var bs_pi := BattleState.new()
	bs_pi.active_index = 0
	bs_pi.current_attack_range = 1
	bs_pi._current_action = AtqNormal.new()   # ataque com arma: tipo vem da arma (Longsword)
	bs_pi.combatant_positions[0] = Vector2i(2, 3)
	bs_pi.combatant_positions[1] = Vector2i(3, 3)  # inimigo adjacente
	var pi_enemy_type: String = BattleState.TURN_QUEUE[1].get("type", "")
	var pi_enemy_name: String = BattleState.TURN_QUEUE[1]["name"]
	BattleState.ALL_ENEMIES[pi_enemy_type].immunities.assign(["SLASHING"])
	var pi_hp0: int = bs_pi.enemy_hp[pi_enemy_name]
	seed(_find_seed_for_d20(19))
	bs_pi._apply_attack(1)
	_eq("jogador vs inimigo imune (SLASHING da arma): HP intacto", bs_pi.enemy_hp[pi_enemy_name], pi_hp0)
	_eq("last_attack_info.amount = 0 por imunidade", bs_pi.last_attack_info.get("amount", -1), 0)
	_eq("ataque com arma registra o tipo da arma", bs_pi.last_attack_info.get("damage_type", -1), ActionData.DamageType.SLASHING)
	BattleState.ALL_ENEMIES[pi_enemy_type].immunities.assign(["PIERCING"])   # imune a outro tipo físico
	var pi_hp1: int = bs_pi.enemy_hp[pi_enemy_name]
	seed(_find_seed_for_d20(19))
	bs_pi._apply_attack(1)
	_true("imune a PIERCING não protege de Longsword (SLASHING)", bs_pi.enemy_hp[pi_enemy_name] < pi_hp1)
	BattleState.ALL_ENEMIES[pi_enemy_type].immunities.assign([])

	# (b) Ataque de INIMIGO vs jogador imune a dano físico (B/P/S) → 0 dano
	BattleState.setup_party(["Guerreiro"])
	var bs_ei := BattleState.new()
	bs_ei.active_index = 1
	bs_ei.active_enemy_action_idx = 0
	bs_ei.combatant_positions[0] = Vector2i(2, 3)
	bs_ei.combatant_positions[1] = Vector2i(3, 3)  # inimigo adjacente ao Guerreiro
	BattleState.ALL_HERO_DATA["Guerreiro"].immunities.assign(["SLASHING", "PIERCING", "BLUDGEONING"])
	var ei_pidx: int = bs_ei._player_index_by_name("Guerreiro")
	var ei_hp0: int = BattleState.PLAYERS[ei_pidx]["hp"]
	seed(_find_seed_for_d20(19))
	bs_ei.apply_enemy_attack()
	_eq("inimigo vs jogador imune (físico): HP intacto", BattleState.PLAYERS[ei_pidx]["hp"], ei_hp0)
	BattleState.ALL_HERO_DATA["Guerreiro"].immunities.assign([])

	# (c) AoE de JOGADOR (splash) em alvo imune a FIRE → 0 dano
	BattleState.setup_party(["Guerreiro"])
	var bs_ao := BattleState.new()
	bs_ao.active_index = 0
	bs_ao.combatant_positions[2] = Vector2i(5, 5)   # alvo primário do splash
	bs_ao.combatant_positions[1] = Vector2i(6, 5)   # inimigo no raio (dist 1)
	var ao_act := ActionData.new()
	ao_act.damage_type = ActionData.DamageType.FIRE
	var ao_enemy_type: String = BattleState.TURN_QUEUE[1].get("type", "")
	var ao_enemy_name: String = BattleState.TURN_QUEUE[1]["name"]
	BattleState.ALL_ENEMIES[ao_enemy_type].immunities.assign(["FIRE"])
	var ao_hp0: int = bs_ao.enemy_hp[ao_enemy_name]
	bs_ao._area_damage([Vector2i(6, 5)] as Array[Vector2i], 10, 0, ao_act, [])   # dc=0 → sem save, dano cheio antes da mitigação
	_eq("AoE splash em alvo imune (FIRE): HP intacto", bs_ao.enemy_hp[ao_enemy_name], ao_hp0)
	BattleState.ALL_ENEMIES[ao_enemy_type].immunities.assign([])

	BattleState.TURN_QUEUE = _int_saved_tq
	BattleState.PLAYERS = _int_saved_pl

	# ── Dano centralizado: _deal_damage_to_combatant ─────────────────────────
	var _dd_tq: Array = BattleState.TURN_QUEUE
	var _dd_pl: Array = BattleState.PLAYERS
	BattleState.setup_party(["Guerreiro"])
	var DDT := ActionData.DamageType
	var hd_dd: HeroData = BattleState.ALL_HERO_DATA["Guerreiro"]
	var s_dd := BattleState.new()
	var p_dd: Dictionary = BattleState.PLAYERS[0]
	var dd_en: String = BattleState.TURN_QUEUE[1]["name"]
	var dd_et: String = BattleState.TURN_QUEUE[1]["type"]

	hd_dd.immunities.assign(["FIRE"]); p_dd["hp"] = 50
	_eq("dano: imune devolve 0", s_dd._deal_damage_to_combatant(0, 8, DDT.FIRE), 0)
	_eq("dano: imune não altera HP", p_dd["hp"], 50)
	hd_dd.immunities.assign([])

	BattleState.ALL_ENEMIES[dd_et].resistances.assign(["COLD"])
	var dd_hp0: int = s_dd.enemy_hp[dd_en]
	_eq("dano: inimigo resistente → metade", s_dd._deal_damage_to_combatant(1, 9, DDT.COLD), 4)
	_eq("dano: HP inimigo -4", s_dd.enemy_hp[dd_en], dd_hp0 - 4)
	BattleState.ALL_ENEMIES[dd_et].resistances.assign([])

	# Componentes: cada tipo mitigado separadamente, somados num único dano
	p_dd["hp"] = 50
	hd_dd.resistances.assign(["SLASHING"]); hd_dd.immunities.assign(["RADIANT"])
	_eq("dano: componentes mitigados por tipo (6 SLASH resist + 4 RAD imune)",
		s_dd._deal_damage_to_combatant(0, 6, DDT.SLASHING, false, {DDT.RADIANT: 4}), 3)
	hd_dd.immunities.assign([])
	_eq("dano: componentes somados (3 SLASH + 4 RAD)",
		s_dd._deal_damage_to_combatant(0, 6, DDT.SLASHING, false, {DDT.RADIANT: 4}), 7)
	hd_dd.resistances.assign([])

	# Concentração: dano 0 não dispara teste (BG3)
	p_dd["hp"] = 50
	s_dd.concentration_by_caster[0] = {"label": "x", "action": ActionData.new()}
	hd_dd.immunities.assign(["POISON"])
	s_dd._deal_damage_to_combatant(0, 30, DDT.POISON)
	_true("dano 0 não quebra concentração", s_dd.concentration_by_caster.has(0))
	hd_dd.immunities.assign([])
	s_dd.concentration_by_caster.erase(0)

	# Downed: imune não gera falha; dano = 1 falha; crítico = 2 (BG3)
	p_dd["hp"] = 1
	s_dd._deal_damage_to_combatant(0, 5, DDT.BLUDGEONING)
	_true("dano: 0 HP → Downed", s_dd.is_downed(0))
	hd_dd.immunities.assign(["FIRE"])
	s_dd._deal_damage_to_combatant(0, 5, DDT.FIRE)
	_eq("dano: imune em Downed não soma falha", s_dd.combatant_statuses[0].get("death_saves_failure", 0), 0)
	hd_dd.immunities.assign([])
	s_dd._deal_damage_to_combatant(0, 5, DDT.BLUDGEONING)
	_eq("dano em Downed soma 1 falha", s_dd.combatant_statuses[0].get("death_saves_failure", 0), 1)
	s_dd.combatant_statuses[0]["death_saves_failure"] = 0
	s_dd._deal_damage_to_combatant(0, 5, DDT.BLUDGEONING, true)
	_eq("crítico em Downed soma 2 falhas", s_dd.combatant_statuses[0].get("death_saves_failure", 0), 2)

	# Superfícies e Burning roteados (repro: imunidade/Wet eram ignorados)
	var s_sf := BattleState.new()
	p_dd = BattleState.PLAYERS[0]
	p_dd["hp"] = 50
	s_sf.combatant_statuses[0].erase("downed")
	hd_dd.immunities.assign(["FIRE"])
	s_sf.tile_surfaces[Vector2i(4, 3)] = {"type": SurfaceType.Type.FIRE, "turns": 3}
	s_sf.pending_surface_hits.clear()
	s_sf.apply_surface_on_enter(0, Vector2i(4, 3))
	_eq("fogo ao entrar vs imune FIRE: HP intacto", p_dd["hp"], 50)
	_eq("imune: nenhum floater de dano", s_sf.pending_surface_hits.size(), 0)
	hd_dd.immunities.assign([])
	p_dd["hp"] = 50
	s_sf.combatant_statuses[0]["wet"] = 2
	s_sf.tile_surfaces[Vector2i(5, 3)] = {"type": SurfaceType.Type.ELECTRIFIED_WATER, "turns": 3}
	seed(1)
	var sf_roll: int = DiceRoller.roll(1, 4)
	seed(1)
	s_sf.apply_surface_on_enter(0, Vector2i(5, 3))
	_eq("água eletrificada vs Wet: dobro (LIGHTNING)", 50 - p_dd["hp"], sf_roll * 2)
	# Tick no início do turno sobre água eletrificada: rótulo "Raio" e valor aplicado
	p_dd["hp"] = 50
	s_sf.combatant_statuses[0].erase("wet")
	s_sf.combatant_positions[0] = Vector2i(5, 3)
	s_sf.pending_surface_hits.clear()
	s_sf._apply_surface_tick(0)
	var sf_hit: Dictionary = s_sf.pending_surface_hits[0] if s_sf.pending_surface_hits.size() > 0 else {}
	_eq("tick eletrificado: rótulo Raio", sf_hit.get("label", ""), "Raio")
	_eq("tick eletrificado: floater = dano aplicado", sf_hit.get("damage", -1), 50 - p_dd["hp"])
	# Burning tick vs imune a FIRE
	var s_bt := BattleState.new()
	BattleState.PLAYERS[0]["hp"] = 50
	hd_dd.immunities.assign(["FIRE"])
	s_bt.combatant_statuses[0]["burning"] = 2
	s_bt.active_index = BattleState.TURN_QUEUE.size() - 1   # próximo turno = idx 0
	s_bt.advance_turn()
	_eq("Burning vs imune FIRE: HP intacto", BattleState.PLAYERS[0]["hp"], 50)
	hd_dd.immunities.assign([])

	# ── Veneno (DoT POISON), armadilha (PIERCING) e Smite por reação (RADIANT) ──
	var s_pz := BattleState.new()
	BattleState.PLAYERS[0]["hp"] = 50
	hd_dd.immunities.assign(["POISON"])
	s_pz.combatant_statuses[0]["poison"] = 2
	s_pz.active_index = BattleState.TURN_QUEUE.size() - 1
	s_pz.pending_surface_hits.clear()
	s_pz.advance_turn()
	_eq("DoT veneno vs imune POISON: HP intacto", BattleState.PLAYERS[0]["hp"], 50)
	_eq("DoT veneno imune: sem floater", s_pz.pending_surface_hits.size(), 0)
	hd_dd.immunities.assign([])
	hd_dd.resistances.assign(["POISON"])
	s_pz.combatant_statuses[0]["poison"] = 2
	s_pz.active_index = BattleState.TURN_QUEUE.size() - 1
	seed(3)
	var pz_roll: int = DiceRoller.roll(1, 4)
	seed(3)
	s_pz.advance_turn()
	_eq("DoT veneno vs resistente: metade", 50 - BattleState.PLAYERS[0]["hp"], pz_roll / 2)
	hd_dd.resistances.assign([])

	var s_tr := BattleState.new()
	BattleState.PLAYERS[0]["hp"] = 50
	s_tr.tile_data_map[4][3].effect = TerrainTile.EffectType.TRAP_INACTIVE
	hd_dd.immunities.assign(["PIERCING"])
	s_tr._check_trap(0, Vector2i(4, 3))
	_eq("armadilha vs imune PIERCING: HP intacto", BattleState.PLAYERS[0]["hp"], 50)
	_eq("armadilha imune ainda aplica DoT poison", s_tr.combatant_statuses[0].get("poison", 0), 3)
	_eq("armadilha imune ainda deixa superfície POISON",
		s_tr.tile_surfaces.get(Vector2i(4, 3), {}).get("type", -1), SurfaceType.Type.POISON)
	hd_dd.immunities.assign([])
	# Herói pisa na armadilha fora do próprio turno (ex.: turno de inimigo) → toma dano
	var s_tr2 := BattleState.new()
	BattleState.PLAYERS[0]["hp"] = 50
	s_tr2.tile_data_map[4][3].effect = TerrainTile.EffectType.TRAP_INACTIVE
	s_tr2.active_index = 1
	s_tr2._check_trap(0, Vector2i(4, 3))
	_true("armadilha fora do turno do herói causa dano", BattleState.PLAYERS[0]["hp"] < 50)
	# D3: armadilha em herói concentrando, save forçado a falhar → concentração quebra
	var s_tr3 := BattleState.new()
	BattleState.PLAYERS[0]["hp"] = 50
	s_tr3.tile_data_map[4][3].effect = TerrainTile.EffectType.TRAP_INACTIVE
	s_tr3.concentration_by_caster[0] = {"label": "x", "action": ActionData.new()}
	DiceRoller.force_next([2, 2, 1])   # 2d4 da armadilha, depois o save de concentração = 1
	s_tr3._check_trap(0, Vector2i(4, 3))
	DiceRoller.clear_forced()
	_true("armadilha (dano>0, save falho) quebra concentração", not s_tr3.concentration_by_caster.has(0))

	var s_rsm := BattleState.new()
	var sm_tgt: int = 1
	var sm_name: String = BattleState.TURN_QUEUE[sm_tgt]["name"]
	var sm_type: String = BattleState.TURN_QUEUE[sm_tgt]["type"]
	BattleState.ALL_ENEMIES[sm_type].immunities.assign(["RADIANT"])
	s_rsm.last_attack_info = {"hit": true, "target_idx": sm_tgt, "amount": 5}
	BattleState.PLAYERS[0]["spell_slots"] = [1, 0, 0, 0, 0, 0]   # há slot: o 0 vem da imunidade
	var sm_hp0: int = s_rsm.enemy_hp[sm_name]
	_eq("Smite reação vs imune RADIANT devolve 0", s_rsm.apply_divine_smite_reaction(0, 1, false), 0)
	_eq("Smite reação vs imune RADIANT: HP intacto", s_rsm.enemy_hp[sm_name], sm_hp0)
	_eq("Smite reação imune: amount não muda", s_rsm.last_attack_info.get("amount", -1), 5)
	BattleState.ALL_ENEMIES[sm_type].immunities.assign([])

	# ── AoE inimigo: tipo do comportamento (Frost Nova = COLD) ────────────────
	var s_typed_aoe := BattleState.new()
	var eaoe_mage := -1
	for _i in range(BattleState.TURN_QUEUE.size()):
		if BattleState.TURN_QUEUE[_i].get("type", "") == "Mage":
			eaoe_mage = _i
	for _i in range(BattleState.TURN_QUEUE.size()):
		s_typed_aoe.combatant_positions[_i] = Vector2i(20 + _i, 20)
	s_typed_aoe.combatant_positions[0] = Vector2i(5, 5)
	s_typed_aoe.combatant_positions[eaoe_mage] = Vector2i(6, 5)
	s_typed_aoe.active_index = eaoe_mage
	var frost_b: Dictionary = BattleState.ALL_ENEMIES["Mage"].action_behaviors[2]
	BattleState.PLAYERS[0]["hp"] = 50
	hd_dd.immunities.assign(["COLD"])
	s_typed_aoe.pending_surface_hits.clear()
	s_typed_aoe._apply_enemy_aoe_attack(frost_b)
	_eq("Frost Nova vs imune COLD: HP intacto", BattleState.PLAYERS[0]["hp"], 50)
	_eq("Frost Nova imune: sem floater", s_typed_aoe.pending_surface_hits.size(), 0)
	hd_dd.immunities.assign([])
	# Sem "damage_type" no comportamento → usa EnemyData.attack_damage_type (Mage = NECROTIC)
	hd_dd.immunities.assign(["NECROTIC"])
	s_typed_aoe._apply_enemy_aoe_attack({"aoe_ft": 5, "damage_mult": 1.0})
	_eq("AoE sem tipo usa attack_damage_type do inimigo", BattleState.PLAYERS[0]["hp"], 50)
	hd_dd.immunities.assign([])
	s_typed_aoe.pending_surface_hits.clear()
	s_typed_aoe._apply_enemy_aoe_attack(frost_b)
	var eaoe_hit: Dictionary = s_typed_aoe.pending_surface_hits[0] if s_typed_aoe.pending_surface_hits.size() > 0 else {}
	_eq("Frost Nova: floater = dano aplicado", eaoe_hit.get("damage", -1), 50 - BattleState.PLAYERS[0]["hp"])
	_eq("Frost Nova: cor do floater = COLD", eaoe_hit.get("color", Color.BLACK), ActionData.damage_type_color(ActionData.DamageType.COLD))

	# ── Ataque do jogador com componentes (BG3: cada tipo separado) ───────────
	var cm_name: String = BattleState.TURN_QUEUE[1]["name"]
	var cm_type: String = BattleState.TURN_QUEUE[1]["type"]
	var cm_ed: EnemyData = BattleState.ALL_ENEMIES[cm_type]
	var _cm_attack := func(action: ActionData, coated: int) -> BattleState:
		var cm_s := BattleState.new()
		cm_s.active_index = 0
		cm_s.current_attack_range = 1
		cm_s._current_action = action
		cm_s.combatant_positions[0] = Vector2i(2, 3)
		cm_s.combatant_positions[1] = Vector2i(3, 3)
		if coated > 0:
			cm_s.combatant_statuses[0]["coated_fire"] = coated
		seed(_find_seed_for_d20(19))
		cm_s._apply_attack(1)
		return cm_s
	# Smite (arma SLASHING + 2d8 RADIANT) vs imune a RADIANT: só a arma entra
	cm_ed.immunities.assign(["RADIANT"])
	var s_cm1: BattleState = _cm_attack.call(SkillSmite.new(), 0)
	var cm1_lost: int = BattleState.new().enemy_hp[cm_name] - s_cm1.enemy_hp[cm_name]
	_eq("Smite vs imune RADIANT: smite_amount exibido = 0", s_cm1.last_attack_info.get("smite_amount", -1), 0)
	_eq("Smite vs imune RADIANT: amount = HP perdido", s_cm1.last_attack_info.get("amount", -1), cm1_lost)
	# Smite vs imune a SLASHING: só o radiante entra
	cm_ed.immunities.assign(["SLASHING"])
	var s_cm2: BattleState = _cm_attack.call(SkillSmite.new(), 0)
	_true("Smite vs imune SLASHING: radiante ainda causa dano", s_cm2.last_attack_info.get("amount", 0) > 0)
	_eq("Smite vs imune SLASHING: amount = smite_amount", s_cm2.last_attack_info.get("amount", -1), s_cm2.last_attack_info.get("smite_amount", -2))
	# Arma em chamas (+1d4 FIRE) vs imune a SLASHING: só o fogo entra (1..4)
	var s_cm3: BattleState = _cm_attack.call(AtqNormal.new(), 2)
	var cm3_amt: int = s_cm3.last_attack_info.get("amount", 0)
	_true("arma em chamas vs imune SLASHING: só 1d4 de fogo", cm3_amt >= 1 and cm3_amt <= 4)
	_eq("arma em chamas: bônus exibido = fogo aplicado", s_cm3.last_attack_info.get("status_bonus_amount", -1), cm3_amt)
	cm_ed.immunities.assign([])
	# Undo do ataque restaura o HP (Review Focus)
	var s_cm4: BattleState = _cm_attack.call(AtqNormal.new(), 0)
	var cm4_hp0: int = BattleState.new().enemy_hp[cm_name]
	_true("ataque normal causou dano", s_cm4.enemy_hp[cm_name] < cm4_hp0)
	s_cm4.has_attacked = true
	s_cm4.cancel_confirmed_attack()
	_eq("cancelar ataque restaura HP", s_cm4.enemy_hp[cm_name], cm4_hp0)
	# Alvo já morto não sofre dano nem morre de novo
	var s_dead := BattleState.new()
	s_dead.dead_indices[1] = true
	s_dead.pending_deaths.clear()
	_eq("alvo morto: dano 0", s_dead._deal_damage_to_combatant(1, 10, ActionData.DamageType.FIRE), 0)
	_eq("alvo morto: sem nova morte", s_dead.pending_deaths.size(), 0)
	# Esquiva Sobrenatural reembolsa sobre o dano já mitigado (Review Focus)
	var s_udodge := BattleState.new()
	s_udodge.active_index = 1
	s_udodge.active_enemy_action_idx = 0
	s_udodge.combatant_positions[0] = Vector2i(2, 3)
	s_udodge.combatant_positions[1] = Vector2i(3, 3)
	hd_dd.resistances.assign(["SLASHING", "PIERCING", "BLUDGEONING"])
	BattleState.PLAYERS[0]["hp"] = 80
	seed(_find_seed_for_d20(19))
	s_udodge.apply_enemy_attack()
	var ud_amt: int = s_udodge.last_attack_info.get("amount", 0)
	_eq("ataque inimigo: HP cai pelo dano mitigado", BattleState.PLAYERS[0]["hp"], 80 - ud_amt)
	s_udodge.apply_uncanny_dodge(0)
	_eq("Esquiva Sobrenatural: HP = 80 - (mitigado - metade)", BattleState.PLAYERS[0]["hp"], 80 - (ud_amt - ud_amt / 2))
	hd_dd.resistances.assign([])

	# ── Área: cada criatura é mitigada pelo PRÓPRIO perfil (uma rolagem de dano, sem alvo primário) ──
	# Antes: "splash não mitiga duas vezes". Sem primário/respingo isso virou: a imunidade ou a
	# vulnerabilidade de um alvo da área não altera o dano do vizinho.
	var sp_t1: String = BattleState.TURN_QUEUE[1]["type"]
	var sp_n2: String = BattleState.TURN_QUEUE[2]["name"]
	var _splash := func() -> int:
		var sp := BattleState.new()
		sp.active_index = 0
		var act := ActionData.new()
		act.damage_type = ActionData.DamageType.FIRE
		act.damage_dice_count = 2
		act.damage_dice_sides = 6
		act.area_kind = AreaShape.Kind.SPHERE
		act.area_size_ft = 5
		sp._current_action = act
		for _k in range(BattleState.TURN_QUEUE.size()):
			sp.combatant_positions[_k] = Vector2i(20 + _k, 20)
		sp.combatant_positions[0] = Vector2i(0, 0)
		sp.combatant_positions[1] = Vector2i(5, 5)
		sp.combatant_positions[2] = Vector2i(6, 5)
		var hp0: int = sp.enemy_hp[sp_n2]
		seed(77)
		sp.apply_area_at(Vector2i(6, 6))      # esfera de 5 ft no cruzamento: (5,5), (6,5), (5,6), (6,6)
		return hp0 - sp.enemy_hp[sp_n2]
	var sp_plain: int = _splash.call()
	BattleState.ALL_ENEMIES[sp_t1].immunities.assign(["FIRE"])
	_true("área: vizinho imune não zera o outro alvo", _splash.call() > 0)
	_eq("área: um alvo imune → o outro toma o mesmo", _splash.call(), sp_plain)
	BattleState.ALL_ENEMIES[sp_t1].immunities.assign([])
	BattleState.ALL_ENEMIES[sp_t1].vulnerabilities.assign(["FIRE"])
	_eq("área: um alvo vulnerável não dobra o outro", _splash.call(), sp_plain)
	BattleState.ALL_ENEMIES[sp_t1].vulnerabilities.assign([])
	BattleState.TURN_QUEUE = _dd_tq
	BattleState.PLAYERS = _dd_pl

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

	# ── Amedrontado: NÃO pode se mover (BG3, bg3.wiki/wiki/Frightened: "Cannot move") ───────────────
	# Antes (D&D): podia mover, só não em direção à fonte do medo. Os testes foram reescritos.
	var s_fright := _battlefield()
	# Goblin Scout (idx 1) em (9,1) é a fonte do medo do Guerreiro (idx 0) em (2,3).
	s_fright.apply_condition(0, "frightened", 2, 1)
	_eq("frightened grava frightened_by", s_fright.combatant_statuses[0].get("frightened_by", -1), 1)
	_true("frightened não pode mover", s_fright.get_reachable_tiles().is_empty())

	# Com ou sem fonte registrada, o movimento é o mesmo: nenhum.
	var s_fright2 := _battlefield()
	s_fright2.combatant_statuses[0]["frightened"] = 2   # sem frightened_by
	_true("frightened sem fonte também não pode mover", s_fright2.get_reachable_tiles().is_empty())

	# ── Paralyzed pula o turno (advance_turn) ─────────────────────────────────
	BattleState.setup_party(["Mago"])
	var s_par := BattleState.new()
	s_par.begin_turn()
	s_par.combatant_statuses[1]["paralyzed"] = 1
	s_par.advance_turn()  # de 0: próximo seria 1, mas paralisado → pula
	_true("paralyzed pulou o turno (não ficou ativo em 1)", s_par.active_index != 1)
	_eq("paralyzed expira (sai da lista ao chegar a 0)", s_par.combatant_statuses[1].get("paralyzed", 0), 0)

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
	var cheb_act := SpellFogo.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		cheb_aoe.combatant_positions[i] = Vector2i(0, 0)
	var cheb_prim := 3
	var cheb_diag := 4
	cheb_aoe.combatant_positions[cheb_prim] = Vector2i(8, 4)
	cheb_aoe.combatant_positions[cheb_diag] = Vector2i(9, 5)  # diagonal do primário: Cheb 1, Manhattan 2
	cheb_aoe.enemy_hp[BattleState.TURN_QUEUE[cheb_diag]["name"]] = 100
	cheb_aoe.pending_surface_hits.clear()
	cheb_aoe._area_damage(cheb_aoe.area_footprint(cheb_act, Vector2i(9, 5), 0), 20, 999, cheb_act, [0, cheb_prim], true)
	var cheb_diag_hit := false
	for h in cheb_aoe.pending_surface_hits:
		if h.get("target_idx", -1) == cheb_diag:
			cheb_diag_hit = true
			break
	_true("respingo de AoE atinge alvo na diagonal (Chebyshev)", cheb_diag_hit)
	_test_architecture_p2p7()
	_test_bg3_rules_audit()
	_test_movement_8dir()
	_test_unified_metric()
	_test_pass_through_allies()
	_test_potion_cover_initiative()
	_test_phase5_bg3_fixes()
	_test_area_shapes()
	_test_area_integration()
	_test_shared_turn()
	_test_enemy_target_downed()
	_test_member_end_turn()
	_test_class_registry()
	_test_gamepad_support()
	await _test_hud_navigation()
	await _test_battle_scene_smoke()
	await _test_oa_preview()
	await _test_focus_ring()
	_reached.append("_run_all")

# ── Auditoria BG3: regras conferidas na bg3.wiki (Poisoned, Prone, Stunned, Downed, Sneak Attack) ──
func _test_bg3_rules_audit() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS

	# Atordoado (BG3): falha automática em saves de FOR e DES; outros saves rolam normal.
	BattleState.setup_party(["Guerreiro", "Mago"])
	var b := BattleState.new()
	b.apply_condition(0, "stun", 1)
	var dex_save := ActionData.new()   # save_attribute = DEX por padrão
	var str_save := ActionData.new()
	str_save.save_attribute = ActionData.DamageAttribute.STR
	var wis_save := ActionData.new()
	wis_save.save_attribute = ActionData.DamageAttribute.WIS
	_eq("BG3: Atordoado falha save de DES mesmo com CD 0", b._resolve_saving_throw(0, 0, dex_save)["mode"], "auto-fail")
	_eq("BG3: Atordoado falha save de FOR mesmo com CD 0", b._resolve_saving_throw(0, 0, str_save)["saved"], false)
	var stun_wis: Dictionary = b._resolve_saving_throw(0, 0, wis_save)
	_true("BG3: Atordoado rola save de SAB normalmente (sem desvantagem)", stun_wis["saved"] and stun_wis["mode"] == "normal")
	b.remove_condition(0, "stun")
	# Envenenado (BG3): sem desvantagem em saving throws.
	b.apply_condition(0, "poisoned", 2)
	_eq("BG3: Envenenado não dá desvantagem em save de DES", b._resolve_saving_throw(0, 0, dex_save)["mode"], "normal")

	# Auto-crítico: melee em Downed; ataque feito de até 3 m (2 casas) em Paralisado (Fase 5).
	var c := BattleState.new()
	c.combatant_positions[0] = Vector2i(3, 3)    # alvo
	c.combatant_positions[1] = Vector2i(4, 3)    # atacante adjacente
	_true("BG3: melee em alvo normal não é auto-crítico", not c._auto_crit(1, 0, 1))
	c.combatant_statuses[0]["downed"] = true
	_true("BG3: melee em alvo Downed é auto-crítico", c._auto_crit(1, 0, 1))
	_true("BG3: ataque à distância em Downed não é auto-crítico", not c._auto_crit(1, 0, 5))
	c.combatant_statuses[0].erase("downed")
	c.apply_condition(0, "paralyzed", 1)
	_true("BG3: melee em alvo Paralisado segue auto-crítico", c._auto_crit(1, 0, 1))
	c.combatant_positions[1] = Vector2i(5, 3)    # a 2 casas = 3 m: ainda dentro da regra de Paralisado
	_true("BG3 Paralysed: ataque à distância feito a 3 m também é crítico", c._auto_crit(1, 0, 5))
	c.combatant_positions[1] = Vector2i(6, 3)    # a 3 casas = 4,5 m: fora
	_true("BG3 Paralysed: a mais de 3 m não é crítico automático", not c._auto_crit(1, 0, 5))

	# Furtivo (BG3): arma sutil ou à distância; aliado só vale sem Desvantagem; dados por nível.
	BattleState.setup_party(["Ladrao", "Guerreiro"])
	var rogue_i := 0
	var ally_i := 1
	var enemy_i := 2
	var r := BattleState.new()
	r.active_index = rogue_i
	r.current_attack_range = 1
	r._current_action = AtqNormal.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		r.combatant_positions[i] = Vector2i(i % 12, 6)
	r.combatant_positions[enemy_i] = Vector2i(5, 2)
	r.combatant_positions[rogue_i] = Vector2i(8, 6)
	r.combatant_positions[ally_i] = Vector2i(5, 3)   # aliado adjacente ao alvo
	_true("BG3: Furtivo com arma sutil e aliado adjacente", r._can_sneak_attack(rogue_i, enemy_i))
	r.combatant_statuses[rogue_i]["restrained"] = 1   # Desvantagem nos próprios ataques
	_true("BG3: aliado adjacente NÃO vale com Desvantagem", not r._can_sneak_attack(rogue_i, enemy_i))
	r.combatant_statuses[rogue_i]["furtivo"] = 1       # 1 adv + 1 dis cancelam: sem Desvantagem líquida
	_true("BG3: Vantagem e Desvantagem se cancelam: aliado volta a valer", r._can_sneak_attack(rogue_i, enemy_i))
	r.combatant_statuses[rogue_i].erase("restrained")
	r.combatant_statuses[rogue_i].erase("furtivo")
	var maul := HeroData.make_weapon("Maul", 2, 6, ActionData.DamageAttribute.STR, false, 0, ActionData.DamageType.BLUDGEONING)
	var rogue_weapon: WeaponData = BattleState.PLAYERS[rogue_i]["weapon"]
	BattleState.PLAYERS[rogue_i]["weapon"] = maul
	_true("BG3: arma pesada (sem finesse) em melee não faz Furtivo", not r._can_sneak_attack(rogue_i, enemy_i))
	r.current_attack_range = 5
	_true("BG3: arma sem finesse à distância faz Furtivo", r._can_sneak_attack(rogue_i, enemy_i))
	r.current_attack_range = 1
	BattleState.PLAYERS[rogue_i]["weapon"] = rogue_weapon
	r._current_action = ActionData.new()   # não é ataque com arma (is_weapon_attack = false)
	_true("BG3: ação que não é ataque com arma não faz Furtivo", not r._can_sneak_attack(rogue_i, enemy_i))

	# Dados do Furtivo por nível do Ladrão: 1d6 (nv 1), 2d6 (nv 4), 6d6 (nv 12).
	for lvl_dice in [[1, 1], [4, 2], [12, 6]]:
		var sd := BattleState.new()
		sd.active_index = rogue_i
		sd.current_attack_range = 1
		sd._current_action = AtqNormal.new()
		BattleState.PLAYERS[rogue_i]["level"] = lvl_dice[0]
		sd.combatant_statuses[rogue_i]["furtivo"] = 1
		for i in range(BattleState.TURN_QUEUE.size()):
			sd.combatant_positions[i] = Vector2i(i, 0)
		sd.enemy_hp[BattleState.TURN_QUEUE[enemy_i]["name"]] = 500
		DiceRoller.force_next([15, 3])   # d20 com Vantagem: max(15, 3) acerta
		sd._apply_attack(enemy_i)
		DiceRoller.clear_forced()
		_true("BG3: Furtivo nível %d = %dd6" % [lvl_dice[0], lvl_dice[1]], str(sd.combat_log).contains("Furtivo! +%dd6=" % lvl_dice[1]))

	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	_reached.append("_test_bg3_rules_audit")

# ── Movimento em 8 direções (D&D 2024 "Playing on a Grid") ─────────────────
# Heróis: Guerreiro (idx 0, speed 7) e Mago (idx 1); inimigos nos idx 2..8 (ordem de ALL_ENEMIES:
# Goblin 2, Orc 3, Mage 4, Undead 5, EliteWarrior 6, EliteMage 7, DungeonGuardian 8). Todos
# estacionados na linha 0; cada teste põe o que precisa em outro lugar. Grid 12×7 NORMAL.
func _move_fixture() -> BattleState:
	BattleState.setup_party(["Guerreiro", "Mago"])
	var bs := BattleState.new()
	for i in range(bs.combatant_positions.size()):
		bs.combatant_positions[i] = Vector2i(i, 0)
	bs.combatant_positions[0] = Vector2i(5, 3)
	bs.active_index = 0
	bs.move_points_remaining = 7
	return bs

# Soma o custo de entrada de cada casa do caminho (o que o jogador paga ao andar por ele).
func _path_cost(bs: BattleState, path: Array[Vector2i]) -> int:
	var total := 0
	for p in path:
		total += bs._tile_cost(p)
	return total

func _test_movement_8dir() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS

	# Diagonal custa 1 casa (5 ft); alcance em Chebyshev.
	var m := _move_fixture()
	var r := m.get_reachable_tiles()
	_eq("diagonal: (6,4) custa 1", r.get(Vector2i(6, 4), -1), 1)
	_eq("diagonal: (8,6) custa 3 (três diagonais)", r.get(Vector2i(8, 6), -1), 3)
	_eq("reto: (11,3) custa 6", r.get(Vector2i(11, 3), -1), 6)
	_true("origem alcançável com custo 0", r.get(Vector2i(5, 3), -1) == 0)
	_true("tile ocupado por outro combatente não é destino", not r.has(Vector2i(4, 0)))
	var p_diag := m.get_path_to(Vector2i(8, 6))
	_eq("caminho diagonal (8,6) tem 3 passos", p_diag.size(), 3)
	_eq("caminho diagonal termina em (8,6)", p_diag[-1], Vector2i(8, 6))

	# Terreno difícil custa o dobro, também na diagonal (lama e superfície de Gelo).
	var mud := _move_fixture()
	mud.tile_data_map[6][4].ground = TerrainTile.GroundType.MUD
	_eq("lama na diagonal: (6,4) custa 2", mud.get_reachable_tiles().get(Vector2i(6, 4), -1), 2)
	var ice := _move_fixture()
	ice.tile_surfaces[Vector2i(6, 4)] = {"type": SurfaceType.Type.ICE, "turns": 3}
	_eq("gelo na diagonal: (6,4) custa 2", ice.get_reachable_tiles().get(Vector2i(6, 4), -1), 2)

	# A diagonal não cruza a quina de um objeto que enche a casa (Obstáculo, Estátua, Cobertura).
	for obj in [TerrainTile.ObjectType.OBSTACLE, TerrainTile.ObjectType.STATUE, TerrainTile.ObjectType.COVER]:
		var w := _move_fixture()
		w.tile_data_map[6][3].object = obj
		var wr := w.get_reachable_tiles()
		_true("objeto %d bloqueia a própria casa" % obj, not wr.has(Vector2i(6, 3)))
		_eq("objeto %d: diagonal (6,4) pela quina custa 2 (dá a volta)" % obj, wr.get(Vector2i(6, 4), -1), 2)
		_eq("objeto %d: diagonal (6,2) pela quina custa 2" % obj, wr.get(Vector2i(6, 2), -1), 2)
		var wp := w.get_path_to(Vector2i(7, 4))
		var steps_ok := true
		var prev: Vector2i = w.combatant_positions[0]
		for step in wp:
			if not w._step_allowed(prev, step):
				steps_ok = false
			prev = step
		_true("objeto %d: o caminho nunca cruza a quina" % obj, steps_ok)
	# Objeto baixo (baú) não enche a casa: anda por cima e a diagonal passa.
	var chest := _move_fixture()
	chest.tile_data_map[6][3].object = TerrainTile.ObjectType.CHEST
	var cr := chest.get_reachable_tiles()
	_eq("baú não bloqueia: (6,3) custa 1", cr.get(Vector2i(6, 3), -1), 1)
	_eq("baú não bloqueia a diagonal (6,4)", cr.get(Vector2i(6, 4), -1), 1)
	# Criaturas e vazio não travam a diagonal (SRD: só terreno que enche a casa).
	var crea := _move_fixture()
	crea.combatant_positions[2] = Vector2i(6, 3)   # inimigo na quina
	_eq("criatura na quina não bloqueia a diagonal", crea.get_reachable_tiles().get(Vector2i(6, 4), -1), 1)
	var hole := _move_fixture()
	hole.tile_data_map[6][3].ground = TerrainTile.GroundType.VOID
	var hr := hole.get_reachable_tiles()
	_true("vazio não é pisável", not hr.has(Vector2i(6, 3)))
	_eq("vazio na quina não bloqueia a diagonal", hr.get(Vector2i(6, 4), -1), 1)

	# Caminho e custo vêm do mesmo algoritmo: o custo do caminho é o custo cobrado, em todo destino.
	var mix := _move_fixture()
	mix.tile_data_map[6][3].ground = TerrainTile.GroundType.MUD
	mix.tile_data_map[7][4].object = TerrainTile.ObjectType.OBSTACLE
	mix.tile_data_map[6][5].object = TerrainTile.ObjectType.STATUE
	mix.tile_surfaces[Vector2i(7, 2)] = {"type": SurfaceType.Type.ICE, "turns": 3}
	var mr := mix.get_reachable_tiles()
	var consistent := true
	for dest in mr.keys():
		if dest == mix.combatant_positions[0]:
			continue
		if _path_cost(mix, mix.get_path_to(dest)) != int(mr[dest]):
			consistent = false
	_true("custo do caminho == custo do mapa de alcance em todos os destinos", consistent)

	# Inimigo: anda pelas diagonais (alvo mais próximo por Chebyshev).
	var ai := _move_fixture()
	ai.combatant_positions[0] = Vector2i(2, 2)
	ai.combatant_positions[2] = Vector2i(8, 6)   # Goblin, speed 6
	ai.active_index = 2
	ai.active_enemy_action_idx = 0               # ataque corpo a corpo (alcance 1)
	ai.enemy_action_text = "Attacking"
	var ai_path := ai.get_enemy_move_path()
	_eq("IA anda 5 passos pela diagonal até junto do alvo", ai_path.size(), 5)
	_eq("IA termina em (3,3), adjacente ao herói", ai_path[-1], Vector2i(3, 3))

	# Inimigo contorna uma parede de obstáculos em vez de travar nela.
	var wall := _move_fixture()
	wall.combatant_positions[0] = Vector2i(2, 2)
	wall.combatant_positions[2] = Vector2i(8, 2)
	wall.active_index = 2
	wall.active_enemy_action_idx = 0
	wall.enemy_action_text = "Attacking"
	for row in range(0, 6):
		wall.tile_data_map[5][row].object = TerrainTile.ObjectType.OBSTACLE
	var wall_path := wall.get_enemy_move_path()
	var wall_ok := not wall_path.is_empty()
	var wprev: Vector2i = wall.combatant_positions[2]
	for step in wall_path:
		if not wall._step_allowed(wprev, step):
			wall_ok = false
		wprev = step
	_true("IA contorna a parede (se move, sem atravessar nem cortar quinas)", wall_ok)
	_true("IA contornando a parede desceu rumo à abertura", not wall_path.is_empty() and wall_path[-1].y > 2)

	# Fuga: termina mais longe do herói; reposicionamento: outra casa a exatamente o alcance.
	var flee := _move_fixture()
	flee.combatant_positions[0] = Vector2i(5, 3)
	flee.combatant_positions[2] = Vector2i(6, 3)
	flee.active_index = 2
	flee.enemy_action_text = "Fleeing!"
	var flee_path := flee.get_enemy_move_path()
	_true("fuga: termina mais longe do herói", not flee_path.is_empty() \
		and BattleState.king_dist(flee_path[-1], Vector2i(5, 3)) > 1)
	var rep := _move_fixture()
	rep.combatant_positions[0] = Vector2i(5, 3)
	rep.combatant_positions[2] = Vector2i(6, 3)
	rep.active_index = 2
	var rep_search: Dictionary = rep._search_movement(2, 6)
	var rep_tile: Vector2i = rep._enemy_reposition_tile(rep_search, Vector2i(5, 3), 1)
	_true("reposição: outra casa adjacente (Chebyshev) ao herói", rep_tile != Vector2i(6, 3) \
		and BattleState.king_dist(rep_tile, Vector2i(5, 3)) == 1)

	# Gerador: Cobertura e Obstáculo são paredes; spawns livres e mapa conexo em várias seeds.
	var gen := MapGenerator.new()
	var gen_ok := true
	for sd in range(1, 31):
		var md: MapGenerator.MapData = gen.generate(sd)
		var blocked := func(t: TerrainTile) -> bool:
			return t.is_void() or t.object == TerrainTile.ObjectType.OBSTACLE or t.object == TerrainTile.ObjectType.COVER
		var open := 0
		for col in range(md.grid_cols):
			for row in range(md.grid_rows):
				if not blocked.call(md.tile_data_map[col][row]):
					open += 1
		for sp in md.hero_spawns + md.enemy_spawns:
			if blocked.call(md.tile_data_map[sp.x][sp.y]):
				gen_ok = false
		if _flood_fill_map(md, md.hero_spawns[0]).size() != open:
			gen_ok = false
	_true("30 seeds: spawns fora das paredes e mapa conexo sem Cobertura/Obstáculo", gen_ok)

	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	_reached.append("_test_movement_8dir")

# ── Métrica única de distância (Chebyshev, diagonal = 1) ────────────────────
# Mesmo fixture de _move_fixture: Guerreiro idx 0, Mago 1, Goblin 2, Orc 3, Mage 4, Undead 5…
func _test_unified_metric() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS

	# OA: sair da casa DIAGONAL de um inimigo provoca Ataque de Oportunidade.
	var oa := _move_fixture()
	oa.combatant_positions[2] = Vector2i(6, 4)    # Goblin na diagonal do Guerreiro (5,3)
	_true("OA: sair da diagonal provoca", oa.check_opportunity_attacks(0, Vector2i(5, 3), Vector2i(3, 3)).has(2))
	_true("OA: continuar na diagonal (ainda adjacente) não provoca",
		oa.check_opportunity_attacks(0, Vector2i(5, 3), Vector2i(5, 4)).is_empty())
	_true("OA: passar de uma casa adjacente a outra não provoca",
		oa.check_opportunity_attacks(0, Vector2i(5, 3), Vector2i(7, 5)).is_empty())

	# OA por PASSO: o caminho só termina fora do alcance se algum passo saiu dele.
	var step := _move_fixture()
	step.combatant_positions[2] = Vector2i(6, 3)  # Goblin ao lado
	var leaves: Array[Vector2i] = [Vector2i(4, 3), Vector2i(5, 3)]     # sai e volta a ficar adjacente
	_true("OA por passo: sair do alcance e voltar provoca (início e fim adjacentes)",
		step.check_opportunity_attacks_along(0, Vector2i(5, 3), leaves).has(2))
	_true("OA por passo: início e fim ADJACENTES, mas sem sair no meio, não provoca",
		step.check_opportunity_attacks_along(0, Vector2i(5, 3), [Vector2i(5, 4), Vector2i(5, 2)] as Array[Vector2i]).is_empty())
	var along: Array[int] = step.check_opportunity_attacks_along(0, Vector2i(5, 3), [Vector2i(4, 3), Vector2i(3, 3)] as Array[Vector2i])
	_eq("OA por passo: cada reator aparece uma vez", along.count(2), 1)

	# Disengage cobre as 8 casas e qualquer inimigo.
	var dg := _move_fixture()
	dg.combatant_positions[2] = Vector2i(6, 4)    # diagonal
	dg.combatant_positions[3] = Vector2i(4, 2)    # outra diagonal
	dg.apply_disengage(0)
	_true("Disengage: nenhum OA saindo das duas diagonais",
		dg.check_opportunity_attacks(0, Vector2i(5, 3), Vector2i(8, 3)).is_empty())
	dg.combatant_statuses[0]["disengage"] = false
	var dg_list := dg.check_opportunity_attacks(0, Vector2i(5, 3), Vector2i(8, 3))
	_true("sem Disengage: as duas diagonais provocam", dg_list.has(2) and dg_list.has(3))

	# Sneak Attack: aliado na DIAGONAL do alvo conta como adjacente.
	_true("king_dist diagonal = 1", BattleState.king_dist(Vector2i(5, 3), Vector2i(6, 4)) == 1)
	BattleState.setup_party(["Ladrao", "Guerreiro"])     # idx 0 Ladrão, 1 Guerreiro, 2 Goblin
	var sn := BattleState.new()
	for i in range(sn.combatant_positions.size()):
		sn.combatant_positions[i] = Vector2i(i, 0)
	sn.combatant_positions[0] = Vector2i(2, 5)    # Ladrão, quem ataca (não está ao lado do alvo)
	sn.combatant_positions[2] = Vector2i(7, 5)    # alvo: Goblin
	sn.combatant_positions[1] = Vector2i(6, 4)    # aliado na DIAGONAL do alvo
	sn.active_index = 0
	_true("Furtivo: aliado na diagonal do alvo habilita (Chebyshev)", sn._can_sneak_attack(0, 2))
	sn.combatant_positions[1] = Vector2i(9, 5)    # aliado a 2 casas do alvo
	_true("Furtivo: aliado a 2 casas não habilita", not sn._can_sneak_attack(0, 2))

	# Frightened (Fase 5, BG3 "Cannot move"): sem movimento algum, nem se afastando da fonte. A
	# restrição por distância que a D2 pedia em Chebyshev deixou de existir (a regra virou "não anda").
	var fr := _move_fixture()
	fr.combatant_positions[2] = Vector2i(9, 3)    # fonte do medo
	fr.apply_condition(0, "frightened", 2, 2)
	_true("frightened: nenhuma casa alcançável, nem para longe da fonte", fr.get_reachable_tiles().is_empty())
	var fr_ai := _move_fixture()
	fr_ai.active_index = 2
	fr_ai.combatant_statuses[2]["frightened"] = 2
	_true("frightened (IA): o inimigo também não anda", fr_ai.get_enemy_move_path().is_empty())

	# IA: o herói na DIAGONAL já está ao alcance corpo a corpo (distância de ação = Chebyshev).
	var ai := _move_fixture()
	ai.combatant_positions[0] = Vector2i(5, 3)
	ai.combatant_positions[2] = Vector2i(6, 4)
	ai.active_index = 2
	ai.active_enemy_action_idx = 0
	ai.enemy_action_text = "Attacking"
	_eq("IA: distância ao herói mais próximo na diagonal = 1", ai._closest_hero_distance(), 1)
	_eq("IA: Goblin na diagonal ataca sem precisar se mover", ai.apply_enemy_attack().get("target", Vector2i(-1, -1)), Vector2i(5, 3))

	# Teleporte inimigo: maximiza a distância de Chebyshev ao herói mais próximo.
	var tp := _move_fixture()
	tp.combatant_positions[2] = Vector2i(5, 3)
	tp.combatant_positions[0] = Vector2i(5, 2)
	tp.active_index = 2
	tp._teleport_enemy()
	var tp_pos: Vector2i = tp.combatant_positions[2]
	var tp_best := 0
	for col in range(tp.grid_cols):
		for row in range(tp.grid_rows):
			tp_best = maxi(tp_best, mini(BattleState.king_dist(Vector2i(col, row), tp.combatant_positions[0]),
				BattleState.king_dist(Vector2i(col, row), tp.combatant_positions[1])))
	_true("teleporte: foge pela métrica Chebyshev", BattleState.king_dist(tp_pos, tp.combatant_positions[0]) >= tp_best - 1)

	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	_reached.append("_test_unified_metric")

# ── Atravessar aliados (D&D 2024: dá para passar pelo espaço de um aliado, não para parar nele) ──
# Corredor: o muro de Obstáculos na coluna 6 só deixa a casa (6,3) livre; ela é onde fica o outro combatente.
func _corridor_fixture() -> BattleState:
	var bs := _move_fixture()          # Guerreiro (5,3), speed 7; Mago idx 1; Goblin idx 2
	for row in [0, 1, 2, 4, 5, 6]:
		bs.tile_data_map[6][row].object = TerrainTile.ObjectType.OBSTACLE
	return bs

func _test_pass_through_allies() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS

	# Aliado no único vão do corredor: dá para atravessar, sem custo extra, e chegar do outro lado.
	var ally := _corridor_fixture()
	ally.combatant_positions[1] = Vector2i(6, 3)       # Mago, aliado do Guerreiro
	var ar := ally.get_reachable_tiles()
	_eq("aliado: o outro lado do vão é alcançável, custo 2 (sem custo extra)", ar.get(Vector2i(7, 3), -1), 2)
	_true("aliado: não dá para terminar o movimento sobre ele", not ar.has(Vector2i(6, 3)))
	var apath := ally.get_path_to(Vector2i(7, 3))
	_eq("aliado: o caminho atravessa a casa do aliado", apath, [Vector2i(6, 3), Vector2i(7, 3)] as Array[Vector2i])
	_eq("aliado: o custo do caminho é o do mapa", _path_cost(ally, apath), 2)
	# Aliado Downed também é atravessável (continua sendo aliado).
	ally.combatant_statuses[1]["downed"] = true
	_true("aliado Downed: ainda atravessável", ally.get_reachable_tiles().has(Vector2i(7, 3)))
	# Aliado morto (casa vaga): livre para parar.
	ally.dead_indices[1] = true
	_true("aliado morto: a casa fica livre para parar", ally.get_reachable_tiles().has(Vector2i(6, 3)))

	# Inimigo no vão bloqueia, como antes.
	var foe := _corridor_fixture()
	foe.combatant_positions[2] = Vector2i(6, 3)        # Goblin, inimigo
	var fr := foe.get_reachable_tiles()
	_true("inimigo: bloqueia a casa", not fr.has(Vector2i(6, 3)))
	_true("inimigo: não dá para passar por ele", not fr.has(Vector2i(7, 3)))
	# Inimigo incapacitado também continua bloqueando (decisão do projeto, mais estrita que o SRD).
	foe.combatant_statuses[2]["paralyzed"] = 2
	_true("inimigo paralisado: continua bloqueando", not foe.get_reachable_tiles().has(Vector2i(7, 3)))

	# Inimigo (IA) atravessa os próprios aliados, mas não os heróis.
	var ai := _corridor_fixture()
	ai.combatant_positions[0] = Vector2i(2, 3)
	ai.combatant_positions[2] = Vector2i(8, 3)         # Goblin, speed 6
	ai.combatant_positions[3] = Vector2i(6, 3)         # Orc (aliado do Goblin) no vão
	ai.active_index = 2
	var ai_search: Dictionary = ai._search_movement(2, 6)
	_true("IA: atravessa o aliado no vão", ai_search["cost"].has(Vector2i(5, 3)))
	_true("IA: não termina sobre o aliado", not ai._enemy_end_tiles(ai_search).has(Vector2i(6, 3)))
	ai.combatant_positions[3] = Vector2i(11, 3)
	ai.combatant_positions[1] = Vector2i(6, 3)         # agora um herói bloqueia o vão
	_true("IA: herói no vão bloqueia", not ai._search_movement(2, 6)["cost"].has(Vector2i(5, 3)))

	# A superfície da casa do aliado ainda se aplica ao atravessar (entrada em cada casa do caminho).
	var surf := _corridor_fixture()
	surf.combatant_positions[1] = Vector2i(6, 3)
	surf.tile_data_map[6][3].ground = TerrainTile.GroundType.MUD
	_eq("atravessar a casa do aliado em lama custa 2 (terreno difícil vale)", surf.get_reachable_tiles().get(Vector2i(7, 3), -1), 3)

	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	_reached.append("_test_pass_through_allies")

# ── Poção BG3, Éter removido, Cobertura sem efeito no ataque, iniciativa sem valor fixo ─────────────
func _test_potion_cover_initiative() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS
	var saved_items: Array = BattleState.TAB_ITEMS

	# Beber: Ação Bônus, 2d4+2 (dados forçados 3 e 4 → 9), apaga Em Chamas, gasta uma Poção.
	var pot := _move_fixture()
	BattleState.TAB_ITEMS = BattleState._new_items()
	var potion: Dictionary = BattleState.TAB_ITEMS[0]
	BattleState.PLAYERS[0]["hp"] = 50
	pot.combatant_statuses[0]["burning"] = 2
	_true("Poção disponível com Ação Bônus livre", pot.is_item_available(potion))
	DiceRoller.force_next([3, 4])
	pot.use_item(potion)
	DiceRoller.clear_forced()
	_eq("Poção cura 2d4+2 (3+4+2 = 9)", pot.get_hp(0), 59)
	_true("Poção gasta a Ação Bônus", pot.has_used_bonus_action)
	_true("Poção não gasta a Ação principal", not pot.has_attacked)
	_eq("Poção gasta uma unidade", potion["count"], 2)
	_eq("Poção apaga Em Chamas", pot.combatant_statuses[0].get("burning", 0), 0)
	_true("sem Ação Bônus a Poção fica indisponível", not pot.is_item_available(potion))
	pot.use_item(potion)
	_eq("sem Ação Bônus beber não faz nada", potion["count"], 2)
	# Não passa do máximo de PV.
	var pot_full := _move_fixture()
	BattleState.PLAYERS[0]["hp"] = BattleState.PLAYERS[0]["max_hp"] - 3
	DiceRoller.force_next([4, 4])
	pot_full.use_item(BattleState.TAB_ITEMS[0])
	DiceRoller.clear_forced()
	_eq("Poção não passa do PV máximo", pot_full.get_hp(0), BattleState.PLAYERS[0]["max_hp"])
	# Estoque zerado: indisponível.
	BattleState.TAB_ITEMS[0]["count"] = 0
	_true("sem estoque a Poção fica indisponível", not _move_fixture().is_item_available(BattleState.TAB_ITEMS[0]))

	# Arremessar: Ação, alcance 12 (18 m), a nuvem cura quem estiver nela (uma rolagem, aliado ou inimigo).
	BattleState.TAB_ITEMS = BattleState._new_items()
	var thr := _move_fixture()                        # Guerreiro idx 0 (5,3); Mago idx 1; Goblin idx 2
	var thr_action := AcaoArremessarPocao.new()
	_eq("Arremessar Poção: alcance 12 casas (18 m ÷ 1,5)", thr_action.attack_range, 12)
	_true("Arremessar Poção: custa a Ação principal (não é bônus)", not thr_action.bonus_action)
	var in_tab := false
	for a in thr.tab_habilidades:
		if a is AcaoArremessarPocao:
			in_tab = true
	_true("Arremessar Poção entra nas habilidades de todos", in_tab)
	_true("Arremessar Poção disponível com estoque", thr.is_item_available(thr_action))
	thr.combatant_positions[1] = Vector2i(9, 3)       # Mago aliado dentro da nuvem
	thr.combatant_positions[2] = Vector2i(10, 3)      # Goblin inimigo, também na nuvem (raio 1)
	thr.combatant_positions[3] = Vector2i(9, 6)       # Orc fora da nuvem
	BattleState.PLAYERS[1]["hp"] = 10
	thr.enemy_hp["Goblin Scout"] = 5
	thr.enemy_hp["Orc Warrior"] = 5
	thr.combatant_statuses[1]["downed"] = true
	thr.combatant_statuses[1]["burning"] = 2
	DiceRoller.force_next([2, 2])                     # 2d4+2 = 6
	thr._current_action = thr_action
	thr.resolve_potion_throw(Vector2i(10, 4))
	DiceRoller.clear_forced()
	_eq("nuvem cura o aliado Downed (10 → 16) e o levanta", thr.get_hp(1), 16)
	_true("nuvem tira o Downed", not thr.is_downed(1))
	_eq("nuvem apaga Em Chamas do aliado", thr.combatant_statuses[1].get("burning", 0), 0)
	_eq("nuvem cura também o inimigo na área (BG3: quem estiver nela)", thr.get_hp(2), 11)
	_eq("fora da nuvem, sem cura", thr.get_hp(3), 5)
	_eq("arremessar gasta uma Poção", BattleState.TAB_ITEMS[0]["count"], 2)
	_eq("os floaters de cura saem do canal de superfície (2 alvos)", thr.pending_surface_hits.size(), 2)
	_true("floater marcado como cura", thr.pending_surface_hits[0].get("is_heal", false))
	# Ação gasta: o Arremessar fica indisponível; sem estoque também.
	thr.has_attacked = true
	_true("Arremessar Poção indisponível depois de usar a Ação", not thr.is_item_available(thr_action))
	thr.has_attacked = false
	BattleState.TAB_ITEMS[0]["count"] = 0
	_true("Arremessar Poção indisponível sem estoque", not thr.is_item_available(thr_action))

	# Cobertura não altera mais a rolagem de ataque (D5); continua bloqueando linha de visão.
	var cov := _move_fixture()
	cov.combatant_positions[2] = Vector2i(7, 3)
	cov.tile_data_map[7][3].object = TerrainTile.ObjectType.COVER
	var cm: Dictionary = cov._get_attack_roll_mods(0, 2, 5)
	_true("alvo sobre Cobertura: sem Vantagem nem Desvantagem", cm["adv"] == 0 and cm["dis"] == 0)
	cov.tile_data_map[7][3].object = TerrainTile.ObjectType.NONE
	cov.tile_data_map[6][3].object = TerrainTile.ObjectType.COVER
	_true("Cobertura ainda bloqueia a linha de visão", not cov._has_los(Vector2i(5, 3), Vector2i(7, 3)))

	# Iniciativa: d20 + DEX + bônus aplicável; nenhum valor fixo por personagem.
	BattleState.setup_party(["Guerreiro", "Mago"])
	var ini := BattleState.new()
	for p in BattleState.PLAYERS:
		_true("herói %s sem campo initiative" % p["name"], not p.has("initiative"))
	BattleState.PLAYERS[1]["initiative_bonus"] = 20          # feature fictícia no Mago
	var flat: Array = []
	for _i in range(BattleState.TURN_QUEUE.size()):
		flat.append(10)
	DiceRoller.force_next(flat)
	ini.roll_initiative()
	DiceRoller.clear_forced()
	_eq("bônus de iniciativa (ponto de entrada) põe o Mago em primeiro", BattleState.TURN_QUEUE[0]["name"], "Mago")
	_eq("rolagem = d20 + mod DEX + bônus (Mago DEX %d)" % ini._combatant_dex(BattleState.TURN_QUEUE[0]),
		BattleState.TURN_QUEUE[0]["initiative_roll"], 10 + ini._raw_mod(ini._combatant_dex(BattleState.TURN_QUEUE[0])) + 20)
	BattleState.PLAYERS[1].erase("initiative_bonus")

	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	BattleState.TAB_ITEMS = saved_items
	_reached.append("_test_potion_cover_initiative")

# ── Fase 5: correções da auditoria BG3 (cada uma com a página do bg3.wiki que a sustenta) ──────────
func _test_phase5_bg3_fixes() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS

	# Terreno elevado: o inimigo (atacante elevado) ganha +1 de alcance à distância. Antes o bônus nunca
	# disparava (o antigo _tile_at nunca devolvia ELEVATED). BG3 High_ground: alcance extra ao mirar mais baixo.
	var el := _move_fixture()
	el.combatant_positions[0] = Vector2i(2, 3)
	el.combatant_positions[2] = Vector2i(6, 3)       # Goblin, ação 2 = alcance 3; o herói está a 4 casas
	el.active_index = 2
	el.active_enemy_action_idx = 2
	_eq("inimigo no chão: alcance 3 não alcança 4 casas", el.apply_enemy_attack().get("target", Vector2i(-1, -1)), Vector2i(-1, -1))
	el.tile_data_map[6][3].ground = TerrainTile.GroundType.ELEVATED
	_eq("inimigo elevado: +1 de alcance alcança 4 casas", el.apply_enemy_attack().get("target", Vector2i(-1, -1)), Vector2i(2, 3))

	# OA: arma à distância, Prone e alvo Invisível não fazem/provocam OA (bg3.wiki/wiki/Opportunity_Attack).
	var oa := _move_fixture()
	oa.combatant_positions[0] = Vector2i(5, 3)
	oa.combatant_positions[3] = Vector2i(6, 3)       # Orc (corpo a corpo)
	oa.combatant_positions[5] = Vector2i(5, 4)       # Skeleton Archer (arco)
	var oa_list := oa.check_opportunity_attacks(0, Vector2i(5, 3), Vector2i(2, 3))
	_true("OA: o Orc reage", oa_list.has(3))
	_true("OA: o Esqueleto Arqueiro (arco) não reage", not oa_list.has(5))
	oa.combatant_statuses[3]["prone"] = 1
	_true("OA: reator Prone não reage", not oa.check_opportunity_attacks(0, Vector2i(5, 3), Vector2i(2, 3)).has(3))
	oa.combatant_statuses[3].erase("prone")
	oa.combatant_statuses[0]["invisible"] = 2
	_true("OA: não provoca quem está Invisível", oa.check_opportunity_attacks(0, Vector2i(5, 3), Vector2i(2, 3)).is_empty())
	BattleState.setup_party(["Arqueiro", "Guerreiro"])      # idx 0 Arqueiro (arco), 1 Guerreiro, 2 Goblin
	var oh := BattleState.new()
	for i in range(oh.combatant_positions.size()):
		oh.combatant_positions[i] = Vector2i(i, 0)
	oh.combatant_positions[2] = Vector2i(6, 3)
	oh.combatant_positions[0] = Vector2i(5, 3)
	oh.combatant_positions[1] = Vector2i(6, 4)
	var oh_list := oh.check_opportunity_attacks(2, Vector2i(6, 3), Vector2i(9, 3))
	_true("OA: o Guerreiro reage ao inimigo que foge", oh_list.has(1))
	_true("OA: o Arqueiro (Longbow) não reage", not oh_list.has(0))

	# Concentração: 20 natural passa e 1 natural falha, mesmo contra a conta (bg3.wiki/wiki/Concentration).
	BattleState.setup_party(["Mago", "Guerreiro"])
	var cc := BattleState.new()
	BattleState.PLAYERS[0]["constitution"] = 30          # +10: o d20 sozinho decide nos dois casos abaixo
	cc.concentration_by_caster[0] = {"label": "teste", "action": null}
	DiceRoller.force_next([20, 5])
	cc._check_concentration_after_damage(0, 100)         # CD 50: só o 20 natural salva
	_true("concentração: 20 natural salva mesmo contra CD 50", cc.is_concentrating(0))
	DiceRoller.force_next([1, 5])
	cc._check_concentration_after_damage(0, 1)           # CD 10: 1+10 passaria, mas 1 natural falha
	_true("concentração: 1 natural falha mesmo com bônus que passaria", not cc.is_concentrating(0))

	# Sneak Attack no crítico: todos os dados dobram (nível 4: 2d6 → 4d6).
	BattleState.setup_party(["Ladrao", "Guerreiro"])
	var sc := BattleState.new()
	for i in range(sc.combatant_positions.size()):
		sc.combatant_positions[i] = Vector2i(i, 0)
	sc.enemy_hp["Goblin Scout"] = 500
	sc.combatant_statuses[0]["furtivo"] = 1
	DiceRoller.force_next([20, 3])                       # d20 com Vantagem: 20 = crítico
	sc._apply_attack(2)
	DiceRoller.clear_forced()
	_true("Furtivo no crítico rola 4d6", str(sc.combat_log).contains("Furtivo! +4d6="))
	var sn := BattleState.new()
	for i in range(sn.combatant_positions.size()):
		sn.combatant_positions[i] = Vector2i(i, 0)
	sn.enemy_hp["Goblin Scout"] = 500
	sn.combatant_statuses[0]["furtivo"] = 1
	DiceRoller.force_next([15, 3])                       # acerta sem crítico
	sn._apply_attack(2)
	DiceRoller.clear_forced()
	_true("Furtivo sem crítico segue 2d6", str(sn.combat_log).contains("Furtivo! +2d6="))

	# Magia não soma o modificador de atributo ao dano; ataque com arma soma (classificação da Q12).
	BattleState.setup_party(["Mago", "Guerreiro"])
	var sp := BattleState.new()
	var spells: Array = [AtqArcano.new(), AtqDivino.new(), SkillChuvaFlechas.new(), SpellFogo.new(),
		SpellGelo.new(), SpellTrovao.new(), SpellCloudOfDaggers.new()]
	for a in spells:
		_true("%s é magia" % a.label, a.is_spell)
		_eq("%s: mínimo = só os dados (sem modificador)" % a.label, sp.get_damage_range(a).x, a.damage_dice_count)
	for a in [AtqNormal.new(), AtqPesado.new(), AtqPreciso.new(), AtqRapido.new(), AtqSoco.new(), SkillSmite.new(), SkillFlurry.new()]:
		_true("%s não é magia (soma o modificador)" % a.label, not a.is_spell)
	sp.active_index = 1
	var guer_normal := AtqNormal.new()
	_true("ataque com arma do Guerreiro soma o modificador", sp.get_damage_range(guer_normal).x > 1)
	sp.active_index = 0
	sp._current_action = SpellFogo.new()
	sp.enemy_hp["Goblin Scout"] = 500
	DiceRoller.force_next([1, 1, 3, 4])                  # save de DES do Goblin falha (1, 1); dano 3+4
	sp._apply_attack(2)
	DiceRoller.clear_forced()
	_eq("Fogo causa exatamente os dados (3+4), sem o +INT do Mago", sp.last_attack_info.get("amount", -1), 7)

	# Ajuda (Help): alcance de 1 casa — adjacente, diagonal incluída (Q9).
	var hp := _move_fixture()
	hp.combatant_positions[1] = Vector2i(6, 4)            # Mago na diagonal do Guerreiro (5,3)
	hp.combatant_positions[2] = Vector2i(5, 5)            # a 2 casas: fora
	var help_act := SkillAjuda.new()
	_eq("Ajuda tem alcance 1", help_act.attack_range, 1)
	hp._current_action = help_act
	hp.enter_attack_mode(help_act.attack_range, true)
	_true("Ajuda alcança o aliado na diagonal", hp.attack_target_indices.has(1))
	hp.cancel_attack()
	hp.combatant_positions[1] = Vector2i(7, 3)            # aliado a 2 casas
	hp.enter_attack_mode(help_act.attack_range, true)
	_true("Ajuda não alcança aliado a 2 casas", not hp.attack_target_indices.has(1))
	hp.cancel_attack()

	# Cego: o alcance de ataques e magias cai para 3 m = 2 casas.
	var bl := _move_fixture()
	bl.combatant_positions[2] = Vector2i(8, 3)           # 3 casas do Guerreiro (5,3)
	bl._current_action = AtqArcano.new()
	bl.enter_attack_mode(10, false)
	_true("sem Cego, o alvo a 3 casas é mirável", bl.attack_target_indices.has(2))
	bl.cancel_attack()
	bl.combatant_statuses[0]["blinded"] = 2
	bl.enter_attack_mode(10, false)
	_eq("Cego: alcance cai para 2 casas", bl.current_attack_range, 2)
	_true("Cego: o alvo a 3 casas deixa de ser mirável", not bl.attack_target_indices.has(2))

	# Prone no PRÓPRIO turno encerra o turno; em outro combatente não.
	var pr := _move_fixture()
	pr.apply_condition(1, "prone", 1)
	_true("Prone em quem não está agindo não encerra o turno", not pr.turn_forced_end)
	pr.apply_condition(0, "prone", 1)
	_true("Prone no próprio turno marca o fim do turno", pr.turn_forced_end)
	pr.advance_turn()
	_true("o flag zera ao mudar de turno", not pr.turn_forced_end)

	# Invisível: some ao ficar Molhado, ao levar dano, ao atacar e ao gastar Ação/Ação Bônus.
	var iv := _move_fixture()
	iv.combatant_statuses[0]["invisible"] = 3
	iv.apply_condition(0, "wet", 3)
	_eq("Invisível some ao ficar Molhado", iv.combatant_statuses[0].get("invisible", 0), 0)
	iv.combatant_statuses[0]["invisible"] = 3
	iv._deal_damage_to_combatant(0, 1, ActionData.DamageType.SLASHING)
	_eq("Invisível some ao levar dano", iv.combatant_statuses[0].get("invisible", 0), 0)
	iv.combatant_statuses[0]["invisible"] = 3
	iv.finalize_attack()
	_eq("Invisível some ao atacar", iv.combatant_statuses[0].get("invisible", 0), 0)
	iv.combatant_statuses[0]["invisible"] = 3
	iv.spend_action_cost(AcaoDesengajar.new())
	_eq("Invisível some ao gastar uma Ação", iv.combatant_statuses[0].get("invisible", 0), 0)

	# Mergulhar: alcance de 3 m (2 casas) até uma superfície de Fogo.
	var dp := _move_fixture()
	dp.tile_surfaces[Vector2i(7, 3)] = {"type": SurfaceType.Type.FIRE, "turns": 3, "dc": 0}   # a 2 casas
	_true("Mergulhar alcança Fogo a 2 casas", dp.resolve_dip(0))
	var dp3 := _move_fixture()
	dp3.tile_surfaces[Vector2i(8, 3)] = {"type": SurfaceType.Type.FIRE, "turns": 3, "dc": 0}  # a 3 casas
	_true("Mergulhar não alcança Fogo a 3 casas", not dp3.resolve_dip(0))

	# Superfícies: Água permanente; Eletrificada dura 2 e volta a Água; Veneno = save de CON, 1 turno; Vapor = Molhado.
	var sf := _move_fixture()
	sf._add_surface(Vector2i(4, 4), SurfaceType.Type.WATER)
	for _i in range(20):
		sf._tick_all_surfaces()
	_eq("Água é permanente", sf.tile_surfaces.get(Vector2i(4, 4), {}).get("type", -1), SurfaceType.Type.WATER)
	sf.tile_surfaces[Vector2i(4, 4)] = {"type": SurfaceType.Type.ELECTRIFIED_WATER, "turns": SurfaceType.DURATION[SurfaceType.Type.ELECTRIFIED_WATER], "dc": 0}
	sf._tick_all_surfaces()
	_eq("Água Eletrificada ainda dura no 1º turno", sf.tile_surfaces[Vector2i(4, 4)]["type"], SurfaceType.Type.ELECTRIFIED_WATER)
	sf._tick_all_surfaces()
	_eq("Água Eletrificada volta a Água após 2 turnos", sf.tile_surfaces[Vector2i(4, 4)]["type"], SurfaceType.Type.WATER)
	_eq("... e a Água é permanente", sf.tile_surfaces[Vector2i(4, 4)]["turns"], SurfaceType.PERMANENT)

	var pz := _move_fixture()
	pz.tile_surfaces[Vector2i(6, 3)] = {"type": SurfaceType.Type.POISON, "turns": 4, "dc": 0}
	BattleState.PLAYERS[0]["constitution"] = 30
	DiceRoller.force_next([10, 10])
	pz.apply_surface_on_enter(0, Vector2i(6, 3))
	DiceRoller.clear_forced()
	_eq("Veneno: save de CON passa (10+10 ≥ 11), sem Envenenado", pz.combatant_statuses[0].get("poisoned", 0), 0)
	BattleState.PLAYERS[0]["constitution"] = 1
	DiceRoller.force_next([5, 5])
	pz.apply_surface_on_enter(0, Vector2i(6, 3))
	DiceRoller.clear_forced()
	_eq("Veneno: save de CON falha, Envenenado por 1 turno", pz.combatant_statuses[0].get("poisoned", 0), 1)

	var st := _move_fixture()
	st.tile_surfaces[Vector2i(6, 3)] = {"type": SurfaceType.Type.STEAM, "turns": 1, "dc": 0}
	st.combatant_statuses[0]["burning"] = 2
	st.apply_surface_on_enter(0, Vector2i(6, 3))
	_eq("Vapor aplica Molhado (3 turnos)", st.combatant_statuses[0].get("wet", 0), 3)
	_eq("Molhado apaga Em Chamas", st.combatant_statuses[0].get("burning", 0), 0)

	# Gelo de magia: a CD do save é a de quem conjurou; o save dispara na criação (chão sem outra superfície).
	var ic := _move_fixture()
	ic.active_index = 1                                  # Mago conjura Gelo
	ic.combatant_positions[3] = Vector2i(8, 3)           # Orc no centro da área
	var gelo := SpellGelo.new()
	DiceRoller.force_next([1, 1])                        # DEX do Orc falha na criação
	ic._deposit_surface_after_attack(Vector2i(8, 3), gelo)
	DiceRoller.clear_forced()
	_eq("Gelo: a CD da superfície é a CD de magia do Mago", ic.tile_surfaces[Vector2i(8, 3)].get("dc", 0),
		ic._spell_save_dc(1, ActionData.DamageAttribute.INT))
	_true("Gelo: o Orc no centro cai Prone na criação", ic.combatant_statuses[3].get("prone", 0) > 0)
	_true("Gelo sob outro combatente não encerra o turno do Mago", not ic.turn_forced_end)
	var ic2 := _move_fixture()
	ic2.active_index = 1
	ic2.combatant_positions[1] = Vector2i(8, 3)
	BattleState.PLAYERS[1]["dexterity"] = 1
	DiceRoller.force_next([1, 1])
	ic2._deposit_surface_after_attack(Vector2i(8, 3), SpellGelo.new())
	DiceRoller.clear_forced()
	_true("Gelo sob o próprio conjurador: cai Prone e o turno acaba", ic2.turn_forced_end)

	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	_reached.append("_test_phase5_bg3_fixes")

# ── Motor de formas de área (D&D 2024: origem num cruzamento; casa afetada se coberta pela metade) ─
func _sorted_tiles(tiles: Array) -> Array:
	var out: Array = tiles.duplicate()
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return out

func _has_all(tiles: Array, wanted: Array) -> bool:
	for w in wanted:
		if not tiles.has(w):
			return false
	return true

func _test_area_shapes() -> void:
	# Esfera/cilindro: círculo com centro num cruzamento.
	var s5 := AreaShape.sphere(Vector2(3, 3), 5)
	_eq("esfera de 5 ft num cruzamento = bloco 2×2 em volta dele",
		_sorted_tiles(s5), [Vector2i(2, 2), Vector2i(2, 3), Vector2i(3, 2), Vector2i(3, 3)])
	var s10 := AreaShape.sphere(Vector2(5, 5), 10)
	_eq("esfera de 10 ft = 4×4 menos os 4 cantos (12 casas)", s10.size(), 12)
	_true("esfera de 10 ft: os cantos do 4×4 cobrem < metade e ficam de fora",
		not s10.has(Vector2i(3, 3)) and not s10.has(Vector2i(6, 3)) and not s10.has(Vector2i(3, 6)) and not s10.has(Vector2i(6, 6)))
	_true("esfera de 10 ft: as casas das bordas (cobertura ~91%) entram", _has_all(s10, [Vector2i(4, 3), Vector2i(5, 3), Vector2i(3, 4), Vector2i(6, 5)]))
	_eq("esfera de 15 ft = 32 casas", AreaShape.sphere(Vector2(10, 10), 15).size(), 32)
	var s20 := AreaShape.sphere(Vector2(10, 10), 20)
	_eq("esfera de 20 ft (Bola de Fogo) = 52 casas", s20.size(), 52)
	var sym := true
	for t in s20:
		if not s20.has(Vector2i(19 - t.x, 19 - t.y)) or not s20.has(Vector2i(t.x, 19 - t.y)):
			sym = false
	_true("a esfera é simétrica em torno do cruzamento", sym)
	_eq("cilindro (visto de cima) = esfera", AreaShape.cylinder(Vector2(5, 5), 10), s10)
	_eq("a forma é determinística (mesma entrada, mesma lista)", AreaShape.sphere(Vector2(5, 5), 10), s10)

	# Emanação: quadrado da criatura expandido por um disco; a casa de origem fica de fora (ou entra).
	var e5 := AreaShape.emanation(Vector2i(3, 3), 5)
	_eq("emanação de 5 ft = as 8 casas vizinhas (diagonal conta)", e5.size(), 8)
	_true("emanação de 5 ft não inclui a casa de origem", not e5.has(Vector2i(3, 3)))
	_true("emanação de 5 ft com origem inclui a própria casa",
		AreaShape.emanation(Vector2i(3, 3), 5, true).has(Vector2i(3, 3)))
	var e10 := AreaShape.emanation(Vector2i(3, 3), 10)
	_eq("emanação de 10 ft = 5×5 menos origem e os 4 cantos (20 casas)", e10.size(), 20)
	_true("emanação de 10 ft: cantos (±2,±2) cobrem ~31% e ficam de fora",
		not e10.has(Vector2i(1, 1)) and not e10.has(Vector2i(5, 1)) and not e10.has(Vector2i(1, 5)) and not e10.has(Vector2i(5, 5)))
	_true("emanação de 10 ft: (±2,±1) cobrem ~91% e entram", _has_all(e10, [Vector2i(5, 4), Vector2i(1, 2), Vector2i(2, 5), Vector2i(4, 1)]))
	_eq("emanação de 15 ft = 44 casas", AreaShape.emanation(Vector2i(3, 3), 15).size(), 44)

	# Cubo: alinhado (a casa mirada) e em direção livre.
	_eq("cubo de 5 ft alinhado = exatamente a casa mirada", AreaShape.cube_square(Vector2i(4, 4), 5), [Vector2i(4, 4)])
	_eq("cubo de 15 ft alinhado = 3×3 (9 casas)", AreaShape.cube_square(Vector2i(4, 4), 15).size(), 9)
	_eq("cubo de 5 ft em direção livre, face centrada numa borda = 1 casa",
		AreaShape.cube(Vector2(2, 2.5), Vector2(9, 2.5), 5), [Vector2i(2, 2)])
	_eq("cubo de 15 ft com a face centrada num cruzamento: 3 colunas × 4 linhas (as bordas cobrem exatamente metade)",
		AreaShape.cube(Vector2(0, 0), Vector2(5, 0), 15).size(), 12)

	# Cone: a largura em cada ponto = distância da origem.
	var cone := AreaShape.cone(Vector2(0, 0), Vector2(5, 0), 15)
	_eq("cone de 15 ft em eixo, origem num cruzamento: 4 casas",
		_sorted_tiles(cone), [Vector2i(1, -1), Vector2i(1, 0), Vector2i(2, -1), Vector2i(2, 0)])
	_true("cone: a casa junto da origem cobre só 25% e fica de fora", not cone.has(Vector2i(0, 0)) and not cone.has(Vector2i(0, -1)))
	_eq("cone de 15 ft na diagonal = 6 casas",
		_sorted_tiles(AreaShape.cone(Vector2(0, 0), Vector2(5, 5), 15)),
		[Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(1, 2), Vector2i(2, 1)])

	# Linha: comprimento × largura; EXATAMENTE metade entra ("pelo menos metade").
	var line_on_edge := AreaShape.line(Vector2(0, 0), Vector2(5, 0), 30, 5)
	_eq("linha 30×5 ft sobre uma linha do grid: as duas fileiras cobrem exatamente metade e entram (12)", line_on_edge.size(), 12)
	var line_centered := AreaShape.line(Vector2(0, 0.5), Vector2(5, 0.5), 30, 5)
	_eq("linha 30×5 ft centrada numa fileira: 6 casas",
		_sorted_tiles(line_centered), [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0)])
	var line_off := AreaShape.line(Vector2(0, 0.4), Vector2(5, 0.4), 30, 5)
	_true("linha deslocada 0,1 casa: a fileira de cima cobre 60% (entra) e a de baixo 40% (sai)",
		line_off.has(Vector2i(2, 0)) and not line_off.has(Vector2i(2, -1)))

	# Origem das áreas "Self" (cone, linha): canto da casa do conjurador mais próximo da direção mirada.
	_eq("origem Self para a direita e para cima: canto direito-superior", AreaShape.self_origin(Vector2i(3, 3), Vector2i(6, 1)), Vector2(4, 3))
	_eq("origem Self para a esquerda e para baixo: canto esquerdo-inferior", AreaShape.self_origin(Vector2i(3, 3), Vector2i(1, 5)), Vector2(3, 4))
	_eq("origem Self em eixo exato: empate vai para o canto de cima", AreaShape.self_origin(Vector2i(3, 3), Vector2i(6, 3)), Vector2(4, 3))

	_reached.append("_test_area_shapes")

# ── Áreas integradas: cursor em cruzamento, prévia = resultado, formas por habilidade ───────────────
# Mago (idx 1) é o conjurador em (2,3); Guerreiro idx 0 aliado; inimigos nos idx 2.. (parados na linha 0).
func _area_fixture() -> BattleState:
	var f := _move_fixture()
	f.active_index = 1
	f.combatant_positions[1] = Vector2i(2, 3)
	f.combatant_positions[0] = Vector2i(5, 6)
	for i in range(2, f.combatant_positions.size()):
		f.combatant_positions[i] = Vector2i(11, i - 2)     # longe, fora de qualquer área testada
	return f

func _test_area_integration() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS

	# Fogo (esfera de 5 ft): o cursor é um CRUZAMENTO; a prévia é exatamente o que o efeito atinge.
	var f := _area_fixture()
	var fogo := SpellFogo.new()
	f._current_action = fogo
	f.enter_attack_mode(fogo.attack_range, false, fogo.proj_color, false, fogo.bonus_action)
	_true("esfera: mira no chão", f.attack_tile_mode)
	_true("esfera: o cursor anda por cruzamentos", f.attack_corner_mode)
	f.cursor_tile = Vector2i(7, 3)                       # cruzamento: casas (6,2), (7,2), (6,3), (7,3)
	_true("cruzamento no alcance é válido", f.get_cursor_feedback()["valid"])
	var preview := f.get_area_preview_tiles()
	_eq("prévia = esfera de 5 ft no cruzamento", _sorted_tiles(preview),
		[Vector2i(6, 2), Vector2i(6, 3), Vector2i(7, 2), Vector2i(7, 3)])
	f.combatant_positions[2] = Vector2i(6, 2)            # Goblin: dentro
	f.combatant_positions[3] = Vector2i(7, 3)            # Orc: dentro
	f.combatant_positions[4] = Vector2i(8, 3)            # Mage: fora (1 casa além da esfera)
	f.combatant_positions[0] = Vector2i(6, 3)            # Guerreiro aliado: dentro (friendly fire)
	for n in ["Goblin Scout", "Orc Warrior", "Dark Mage"]:
		f.enemy_hp[n] = 500
	BattleState.PLAYERS[0]["hp"] = 100
	BattleState.PLAYERS[1]["hp"] = 100
	_true("apply_cursor_selection aceita o cruzamento", f.apply_cursor_selection())
	f.confirm_attack()
	_eq("resultado = prévia (a mesma lista de casas)", _sorted_tiles(f.last_area_tiles), _sorted_tiles(preview))
	_true("atingiu o Goblin na área", f.enemy_hp["Goblin Scout"] < 500)
	_true("atingiu o Orc na área", f.enemy_hp["Orc Warrior"] < 500)
	_true("friendly fire: atingiu o Guerreiro na área", BattleState.PLAYERS[0]["hp"] < 100)
	_eq("não atingiu o Mage fora da esfera", f.enemy_hp["Dark Mage"], 500)
	_eq("não atingiu o conjurador", BattleState.PLAYERS[1]["hp"], 100)
	_eq("a superfície de Fogo cobre exatamente a pegada",
		_sorted_tiles(f.tile_surfaces.keys().filter(func(p): return f.tile_surfaces[p]["type"] == SurfaceType.Type.FIRE)), _sorted_tiles(preview))

	# Limites do cursor em cruzamento: 0..cols e 0..rows (inclusive); fora do alcance é recusado.
	var lim := _area_fixture()
	lim._current_action = SpellFogo.new()
	lim.enter_attack_mode(10, false)
	lim.cursor_tile = Vector2i(lim.grid_cols - 1, lim.grid_rows - 1)
	lim.step_cursor(Vector2i(1, 1))
	_eq("cursor de cruzamento chega ao canto (cols, rows)", lim.cursor_tile, Vector2i(lim.grid_cols, lim.grid_rows))
	lim.step_cursor(Vector2i(1, 1))
	_eq("... e não passa dele", lim.cursor_tile, Vector2i(lim.grid_cols, lim.grid_rows))
	lim.current_attack_range = 2
	lim.cursor_tile = Vector2i(9, 3)
	_eq("cruzamento fora do alcance é recusado", lim.get_cursor_feedback()["reason"], "Fora de alcance")
	_true("... e não confirma", not lim.apply_cursor_selection())

	# Trovão: esfera de 10 ft = 12 casas (4×4 sem os cantos). A criatura numa casa-canto fica de fora.
	var trv := _area_fixture()
	var trovao := SpellTrovao.new()
	trv._current_action = trovao
	_eq("Trovão: esfera de 10 ft", [trovao.area_kind, trovao.area_size_ft], [AreaShape.Kind.SPHERE, 10])
	var tr_tiles := trv.area_footprint(trovao, Vector2i(7, 3), 1)
	_eq("Trovão cobre 12 casas", tr_tiles.size(), 12)
	_true("Trovão: a casa-canto do 4×4 fica de fora", not tr_tiles.has(Vector2i(5, 1)) and not tr_tiles.has(Vector2i(8, 4)))

	# Nuvem de Adagas: cubo de 5 ft numa casa; sem save; concentração; superfície só nessa casa.
	var cl := _area_fixture()
	var nuvem := SpellCloudOfDaggers.new()
	cl._current_action = nuvem
	cl.enter_attack_mode(nuvem.attack_range, false, nuvem.proj_color, false, nuvem.bonus_action)
	_true("cubo: mira numa casa livre (não em cruzamento)", cl.attack_tile_mode and not cl.attack_corner_mode)
	cl.combatant_positions[2] = Vector2i(6, 3)
	cl.combatant_positions[3] = Vector2i(7, 3)
	cl.enemy_hp["Goblin Scout"] = 500
	cl.enemy_hp["Orc Warrior"] = 500
	cl.cursor_tile = Vector2i(6, 3)
	_eq("cubo de 5 ft = só a casa mirada", cl.get_area_preview_tiles(), [Vector2i(6, 3)])
	_true("apply_cursor_selection aceita a casa", cl.apply_cursor_selection())
	cl.confirm_attack()
	_true("Nuvem de Adagas atinge quem está na casa", cl.enemy_hp["Goblin Scout"] < 500)
	_eq("... e só ele", cl.enemy_hp["Orc Warrior"], 500)
	_true("Nuvem de Adagas inicia concentração", cl.is_concentrating(1))
	_eq("Nuvem de Adagas deposita a superfície na casa", cl.tile_surfaces.get(Vector2i(6, 3), {}).get("type", -1), SurfaceType.Type.CLOUD_OF_DAGGERS)
	_true("sem saving throw no log da Nuvem", not str(cl.combat_log).contains("Saving Throw"))

	# Cura em Área: emanação de 5 ft em volta do alvo (inclui o alvo); aliado a 2 casas não é curado.
	BattleState.setup_party(["Clérigo", "Guerreiro", "Mago"])
	var ch := BattleState.new()
	ch.active_index = 0
	ch._attack_targets_allies = true
	ch._current_action = SkillCuraArea.new()
	for i in range(BattleState.TURN_QUEUE.size()):
		ch.combatant_positions[i] = Vector2i(i, 6)
	ch.combatant_positions[1] = Vector2i(5, 2)           # Guerreiro: alvo primário
	ch.combatant_positions[2] = Vector2i(6, 3)           # Mago na DIAGONAL: dentro da emanação
	var ch_tiles := ch.area_footprint(ch._current_action, Vector2i(5, 2), 0)
	_eq("emanação de 5 ft com origem: 9 casas (o alvo e as 8 em volta)", ch_tiles.size(), 9)
	_true("a diagonal do alvo está na emanação", ch_tiles.has(Vector2i(6, 3)))
	_true("a casa a 2 de distância não está", not ch_tiles.has(Vector2i(7, 4)))

	# Emanações dos inimigos: 10 ft = 5×5 sem os cantos; (±2,±1) entra e (±2,±2) não.
	BattleState.setup_party(["Guerreiro", "Mago"])
	var en := BattleState.new()
	var en_i := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		if not BattleState.TURN_QUEUE[i]["is_player"]:
			en_i = i
			break
	en.active_index = en_i
	for i in range(BattleState.TURN_QUEUE.size()):
		en.combatant_positions[i] = Vector2i(0, i)
	en.combatant_positions[en_i] = Vector2i(5, 3)
	en.combatant_positions[0] = Vector2i(7, 4)           # offset (+2,+1): dentro
	en.combatant_positions[1] = Vector2i(7, 5)           # offset (+2,+2): o canto, fora
	BattleState.PLAYERS[0]["hp"] = 100
	BattleState.PLAYERS[1]["hp"] = 100
	en.pending_surface_hits.clear()
	en._apply_enemy_aoe_attack({"aoe_ft": 10, "damage_mult": 1.0})
	var en_hit := {}
	for h in en.pending_surface_hits:
		en_hit[h.get("target_idx", -1)] = true
	_true("emanação de 10 ft atinge o herói a (+2,+1)", en_hit.has(0))
	_true("emanação de 10 ft não atinge o herói no canto (+2,+2)", not en_hit.has(1))
	_eq("a pegada da emanação do inimigo tem 20 casas", en.last_area_tiles.size(), 20)

	# Poção e Arremessar: a nuvem é uma esfera de 5 ft num cruzamento.
	_eq("Arremessar Poção: esfera de 5 ft", [AcaoArremessarPocao.new().area_kind, AcaoArremessarPocao.new().area_size_ft], [AreaShape.Kind.SPHERE, 5])
	_eq("Arremessar: esfera de 5 ft", [AcaoArremessar.new().area_kind, AcaoArremessar.new().area_size_ft], [AreaShape.Kind.SPHERE, 5])
	var sp5 := _area_fixture().area_footprint(AcaoArremessar.new(), Vector2i(5, 5), 1)
	_eq("Arremessar no cruzamento (5,5): casas (4,4), (5,4), (4,5), (5,5)", _sorted_tiles(sp5),
		[Vector2i(4, 4), Vector2i(4, 5), Vector2i(5, 4), Vector2i(5, 5)])

	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	_reached.append("_test_area_integration")

# ── Turno compartilhado (BG3): heróis consecutivos na iniciativa agem no mesmo turno ─────────────────
# Fila de teste (sem rolar iniciativa): [Guerreiro 0, Mago 1, Arqueiro 2, Goblin 3, Orc 4, ...].
func _shared_fixture(party: Array = ["Guerreiro", "Mago", "Arqueiro"]) -> BattleState:
	BattleState.setup_party(party)
	var bs := BattleState.new()
	for i in range(bs.combatant_positions.size()):
		bs.combatant_positions[i] = Vector2i(i, 0)
	bs.begin_turn()
	return bs

func _test_shared_turn() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS

	# O bloco: heróis vivos consecutivos desde o 1º da fila; o 1º herói é o ativo.
	var st := _shared_fixture()
	_eq("bloco = os 3 heróis consecutivos", st.turn_block, [0, 1, 2] as Array[int])
	_eq("o primeiro do bloco é o ativo", st.active_index, 0)
	_eq("todos podem receber o controle", st.switchable_members(), [0, 1, 2] as Array[int])

	# Cada herói tem a PRÓPRIA Ação, Ação Bônus e movimento; trocar guarda e restaura.
	var g_speed: int = BattleState.PLAYERS[0]["speed"]
	var m_speed: int = BattleState.PLAYERS[1]["speed"]
	_eq("Guerreiro começa com o movimento cheio", st.move_points_remaining, g_speed)
	st.has_attacked = true
	st.has_used_bonus_action = true
	st.move_points_remaining = 2
	_true("troca para o Mago", st.switch_active_member(1))
	_eq("o Mago é o ativo", st.active_index, 1)
	_true("o Mago tem a Ação livre (estado próprio)", not st.has_attacked and not st.has_used_bonus_action)
	_eq("o Mago tem o movimento cheio dele", st.move_points_remaining, m_speed)
	_eq("as ações do Mago foram carregadas", st.tab_habilidades.any(func(a): return a is SpellFogo), true)
	st.has_attacked = true
	_true("volta ao Guerreiro", st.switch_active_member(0))
	_true("o Guerreiro mantém a Ação e a Ação Bônus gastas", st.has_attacked and st.has_used_bonus_action)
	_eq("o Guerreiro mantém o movimento que sobrou", st.move_points_remaining, 2)
	_true("o Mago mantém a Ação gasta ao voltar", st.switch_active_member(1) and st.has_attacked)

	# Regras da troca: só sem modo ativo, só para herói do bloco, não para si mesmo, nem para quem não age.
	st.switch_active_member(0)
	st.current_state = BattleState.State.MOVE_MODE
	_true("não troca no meio do modo de movimento", not st.switch_active_member(1))
	st.current_state = BattleState.State.PLAYER_TURN
	_true("não troca para si mesmo", not st.switch_active_member(0))
	_true("não troca para um inimigo", not st.switch_active_member(3))
	st.combatant_statuses[2]["stun"] = 1
	_true("não troca para um herói Atordoado", not st.switch_active_member(2))
	_eq("Atordoado sai dos selecionáveis", st.switchable_members(), [0, 1] as Array[int])
	st.combatant_statuses[2].erase("stun")
	st.combatant_statuses[2]["downed"] = true
	_true("não troca para um herói Downed", not st.switch_active_member(2))
	st.combatant_statuses[2].erase("downed")

	# Girar pelos heróis do bloco.
	var cy := _shared_fixture()
	_true("ciclo para o próximo", cy.cycle_active_member(1) and cy.active_index == 1)
	_true("ciclo para o próximo (2)", cy.cycle_active_member(1) and cy.active_index == 2)
	_true("ciclo dá a volta", cy.cycle_active_member(1) and cy.active_index == 0)
	_true("ciclo para o anterior dá a volta", cy.cycle_active_member(-1) and cy.active_index == 2)
	var solo := _shared_fixture(["Guerreiro"])
	_true("com um herói só, não há o que ciclar", not solo.cycle_active_member(1))

	# Teto de 10 criaturas por posição compartilhada (bg3.wiki/wiki/Combat).
	var big_q: Array = []
	for i in range(12):
		big_q.append({"name": "H%d" % i, "is_player": true})
	BattleState.TURN_QUEUE = big_q
	var big := BattleState.new()
	_eq("o bloco tem no máximo 10 heróis", big.block_from(0).size(), 10)
	_eq("o 11º começa outro bloco", big.block_from(10).size(), 2)

	# Inimigos agem um a um; "Fim de turno" encerra o bloco inteiro.
	var en := _shared_fixture()
	en.advance_turn()
	_eq("depois do bloco de heróis vem o 1º inimigo, sozinho", en.turn_block, [3] as Array[int])
	_eq("o inimigo é o ativo", en.active_index, 3)
	_eq("estado de inimigo", en.current_state, BattleState.State.ENEMY_TURN)
	en.advance_turn()
	_eq("o inimigo seguinte também é um bloco só", en.turn_block, [4] as Array[int])

	# Dois grupos de heróis separados por um inimigo NÃO se fundem; uma rodada volta ao 1º bloco.
	var rd := _shared_fixture()
	var guard := 0
	while guard < 20:
		rd.advance_turn()
		guard += 1
		if rd.active_index == 0:
			break
	_eq("a rodada volta ao bloco de heróis do começo", rd.turn_block, [0, 1, 2] as Array[int])

	# Início de turno POR CRIATURA: dano de Fogo no Mago, Atordoado perde o turno, Downed rola Death Save.
	var ps := _shared_fixture()
	ps.combatant_statuses[1]["burning"] = 2
	ps.combatant_statuses[2]["stun"] = 1
	ps.combatant_statuses[0]["reaction_used"] = true
	BattleState.PLAYERS[1]["hp"] = 100
	var g_hp_before: int = BattleState.PLAYERS[0]["hp"]
	var ps_guard := 0
	while ps_guard < 20:
		ps.advance_turn()
		ps_guard += 1
		if ps.turn_block.has(0) and ps.turn_block.size() == 3:
			break
	_true("o Mago em chamas tomou o dano de Fogo no início do turno dele", BattleState.PLAYERS[1]["hp"] < 100)
	_eq("o Guerreiro não tomou dano de ninguém", BattleState.PLAYERS[0]["hp"], g_hp_before)
	_eq("o Arqueiro Atordoado perdeu o turno (não é selecionável)", ps.switchable_members(), [0, 1] as Array[int])
	_true("a reação do Guerreiro foi renovada no início do turno", not ps.combatant_statuses[0].get("reaction_used", true))
	_eq("o 1º herói que pode agir fica ativo", ps.active_index, 0)

	var dw := _shared_fixture()
	dw.combatant_statuses[1]["downed"] = true
	dw.combatant_statuses[1]["death_saves_success"] = 0
	dw.combatant_statuses[1]["death_saves_failure"] = 0
	var dw_guard := 0
	while dw_guard < 20:
		dw.advance_turn()
		dw_guard += 1
		if dw.turn_block.size() == 3:
			break
	_true("o herói Downed do bloco rolou o Death Save", str(dw.combat_log).contains("Death Save"))
	_eq("o Downed não é selecionável", dw.switchable_members(), [0, 2] as Array[int])

	# Levantar de Prone custa metade do movimento do PRÓPRIO herói.
	var pr := _shared_fixture()
	pr.combatant_statuses[1]["prone"] = 1
	var pr_guard := 0
	while pr_guard < 20:
		pr.advance_turn()
		pr_guard += 1
		if pr.turn_block.size() == 3:
			break
	pr.switch_active_member(1)
	_eq("o Mago levantou de Prone e perdeu metade do movimento", pr.move_points_remaining, m_speed - m_speed / 2)
	pr.switch_active_member(0)
	_eq("o Guerreiro não perdeu movimento", pr.move_points_remaining, g_speed)

	# Fúria do Bárbaro entra no início do turno dele (agora em BattleState, por membro do bloco).
	BattleState.setup_party(["Guerreiro", "Bárbaro"])
	var bb := BattleState.new()
	for i in range(bb.combatant_positions.size()):
		bb.combatant_positions[i] = Vector2i(i, 0)
	BattleState.PLAYERS[1]["hp"] = 10                    # menos de 50% do máximo (120)
	bb.begin_turn()
	_true("Bárbaro abaixo de 50% de HP entra em Fúria ao começar o turno", bb.combatant_statuses[1].get("fury", 0) > 0)
	bb.switch_active_member(1)
	_true("... e tem o ataque extra da Fúria ao assumir o controle", bb.fury_extra_attack)
	bb.switch_active_member(0)
	_true("o ataque extra da Fúria não vaza para o Guerreiro", not bb.fury_extra_attack)

	# Sem begin_turn (testes antigos): o "bloco" é só o ativo.
	BattleState.setup_party(["Guerreiro", "Mago"])
	var nb := BattleState.new()
	_eq("sem bloco calculado, o turno é só do ativo", nb.get_turn_block(), [0] as Array[int])

	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	_reached.append("_test_shared_turn")

# ── Fim de turno POR HERÓI no bloco compartilhado (BG3) ──────────────────────────────────────────
func _test_member_end_turn() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS

	# Encerrar um herói NÃO encerra o bloco: o controle passa ao próximo que ainda não encerrou.
	var b := _shared_fixture()                         # Guerreiro 0, Mago 1, Arqueiro 2
	var turns0: int = b.battle_stats.get("turns", 0)
	_eq("encerrar o 1º herói: passa o controle", b.end_member_turn(), BattleState.EndResult.SWITCHED)
	_eq("o controle foi para o Mago", b.active_index, 1)
	_true("o Guerreiro está marcado como encerrado", b.is_member_ended(0) and not b.is_member_ended(1))
	_eq("o bloco continua o mesmo", b.turn_block, [0, 1, 2] as Array[int])
	_eq("o turno não avançou", b.battle_stats.get("turns", 0), turns0)
	_eq("segue a vez dos heróis", b.current_state, BattleState.State.PLAYER_TURN)
	_eq("só os que não encerraram ainda agem", b.pending_members(), [1, 2] as Array[int])
	_true("o Mago começa com os recursos cheios (estado próprio)", not b.has_attacked and not b.has_used_bonus_action)

	# Trocar à vontade entre os que não encerraram (H / L3): pula o que encerrou.
	_true("ciclo vai para o Arqueiro", b.cycle_active_member(1) and b.active_index == 2)
	_true("ciclo dá a volta sem passar pelo Guerreiro que encerrou", b.cycle_active_member(1) and b.active_index == 1)

	# Cancelar: o herói que encerrou volta a agir com o que ainda tinha (nada reiniciado).
	var c := _shared_fixture()
	c.has_attacked = true
	c.has_used_bonus_action = true
	c.move_points_remaining = 2
	c.end_member_turn()
	c.has_attacked = true                              # o Mago gasta a Ação dele
	_true("selecionar o herói que encerrou é permitido", c.switch_active_member(0))
	_true("ele aparece como encerrado e sem ações", c.active_ended() and not c.is_item_available(AtqNormal.new()))
	c.enter_move_mode()
	_eq("encerrado, ele não entra em modo de movimento", c.current_state, BattleState.State.PLAYER_TURN)
	_true("cancelar o fim de turno funciona", c.cancel_member_end(0))
	_true("ele deixou de estar encerrado", not c.active_ended() and not c.is_member_ended(0))
	_true("recursos restantes preservados: Ação e Ação Bônus gastas", c.has_attacked and c.has_used_bonus_action)
	_eq("... e o movimento que sobrava", c.move_points_remaining, 2)
	_true("o Mago manteve a Ação gasta dele ao trocar", c.switch_active_member(1) and c.has_attacked)
	_true("cancelar quem não encerrou não faz nada", not c.cancel_member_end(1))
	c.switch_active_member(0)
	_eq("pode encerrar de novo depois de cancelar", c.end_member_turn(), BattleState.EndResult.SWITCHED)

	# O bloco só termina quando o ÚLTIMO herói disponível encerra.
	var d := _shared_fixture()
	d.end_member_turn()
	_eq("2º herói encerra: ainda há um", d.end_member_turn(), BattleState.EndResult.SWITCHED)
	_eq("o último herói disponível está ativo", d.active_index, 2)
	_eq("3º herói encerra: o bloco terminou", d.end_member_turn(), BattleState.EndResult.BLOCK_DONE)
	d.advance_turn()                                   # quem chamou passa a vez
	_eq("a vez passa ao próximo da iniciativa (inimigo)", d.turn_block, [3] as Array[int])
	_true("os marcadores de encerrado zeram com o bloco", not d.is_member_ended(0) and not d.is_member_ended(2))
	_true("não dá para cancelar depois que o bloco terminou", not d.cancel_member_end(0))
	_eq("inimigo não usa o fim de turno por herói", d.end_member_turn(), BattleState.EndResult.INVALID)

	# Herói sozinho no bloco: encerrar passa a vez na hora.
	var s1 := _shared_fixture(["Guerreiro"])
	_eq("bloco de um herói: encerrar termina o bloco", s1.end_member_turn(), BattleState.EndResult.BLOCK_DONE)

	# Herói que perdeu o turno (Atordoado no início) não é esperado: o bloco termina sem ele.
	var st := _shared_fixture()
	st.combatant_statuses[2]["stun"] = 1
	var guard := 0
	while guard < 20:
		st.advance_turn()
		guard += 1
		if st.turn_block.size() == 3:
			break
	_eq("o Atordoado fora do jogo: só 2 heróis esperados", st.pending_members(), [0, 1] as Array[int])
	st.end_member_turn()
	_eq("encerrar o 2º disponível termina o bloco (o Atordoado não conta)", st.end_member_turn(), BattleState.EndResult.BLOCK_DONE)

	# Herói ativo fica incapaz no meio do bloco: o controle passa sozinho ao próximo disponível.
	var inc := _shared_fixture()
	inc.combatant_statuses[0]["downed"] = true
	_eq("Downed no ativo: o controle passa (1)", inc.pass_control_if_incapable(), 1)
	_eq("... para o Mago", inc.active_index, 1)
	_eq("herói capaz: nada a fazer (0)", inc.pass_control_if_incapable(), 0)
	inc.combatant_statuses[1]["stun"] = 1
	_eq("Atordoado no ativo: passa para o Arqueiro", inc.pass_control_if_incapable(), 1)
	_eq("... o Arqueiro assumiu", inc.active_index, 2)
	inc.combatant_statuses[2]["paralyzed"] = 1
	_eq("Paralisado e ninguém mais disponível: o bloco acabou (2)", inc.pass_control_if_incapable(), 2)
	# Quem já encerrou não é "disponível": se o ativo cai e os outros já encerraram, o bloco acaba.
	var ended_all := _shared_fixture()
	ended_all.end_member_turn()
	ended_all.end_member_turn()                        # Guerreiro e Mago encerraram; ativo = Arqueiro
	ended_all.combatant_statuses[2]["downed"] = true
	_eq("o último disponível cai e os outros já encerraram: bloco acabou", ended_all.pass_control_if_incapable(), 2)

	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	_reached.append("_test_member_end_turn")

# ── IA contra heróis Downed (decisão do projeto: 50% de escolher o Downed quando há de pé ao alcance) ──
func _test_enemy_target_downed() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS

	var d := _move_fixture()                      # Guerreiro 0 e Mago 1 (heróis); Goblin 2 (inimigo)
	d.active_index = 2
	d.active_enemy_action_idx = 0                 # ataque corpo a corpo (alcance 1)
	d.enemy_action_text = "Attacking"
	d.combatant_positions[0] = Vector2i(5, 3)
	d.combatant_positions[1] = Vector2i(5, 4)
	d.combatant_positions[2] = Vector2i(6, 3)
	BattleState.PLAYERS[0]["hp"] = 80
	BattleState.PLAYERS[1]["hp"] = 30

	# Só heróis de pé: regra base — o de menor HP.
	_eq("só de pé: ataca o de menor HP", d._pick_enemy_target([0, 1] as Array[int]), 1)
	# Só Downed: todos com 0 HP — o primeiro da fila.
	d.combatant_statuses[0]["downed"] = true
	BattleState.PLAYERS[0]["hp"] = 0
	d.combatant_statuses[1]["downed"] = true
	BattleState.PLAYERS[1]["hp"] = 0
	_eq("só Downed: o primeiro da fila", d._pick_enemy_target([0, 1] as Array[int]), 0)
	_eq("ninguém ao alcance: nenhum alvo", d._pick_enemy_target([] as Array[int]), -1)

	# Misto: Guerreiro Downed (0), Mago de pé (1) com 30 HP. O d2 decide (1 = o Downed).
	d.combatant_statuses[1].erase("downed")
	BattleState.PLAYERS[1]["hp"] = 30
	DiceRoller.force_next([1])
	_eq("misto, d2 = 1: escolhe o Downed", d._pick_enemy_target([0, 1] as Array[int]), 0)
	DiceRoller.force_next([2])
	_eq("misto, d2 = 2: escolhe o herói de pé", d._pick_enemy_target([0, 1] as Array[int]), 1)
	DiceRoller.clear_forced()

	# A escolha vale no ataque de verdade (last_attack_info guarda o alvo, acerte ou erre).
	DiceRoller.force_next([1])
	d.apply_enemy_attack()
	DiceRoller.clear_forced()
	_eq("apply_enemy_attack: com d2 = 1 mira o Downed", d.last_attack_info.get("target_idx", -1), 0)
	DiceRoller.force_next([2])
	d.apply_enemy_attack()
	DiceRoller.clear_forced()
	_eq("apply_enemy_attack: com d2 = 2 mira o herói de pé", d.last_attack_info.get("target_idx", -1), 1)

	# Distribuição: ~50% (semente fixa, determinístico).
	seed(2024)
	var downed_picks := 0
	for _i in range(400):
		if d._pick_enemy_target([0, 1] as Array[int]) == 0:
			downed_picks += 1
	_true("misto: o Downed é escolhido em ~50%% das vezes (%d/400)" % downed_picks, downed_picks >= 160 and downed_picks <= 240)

	# Dois de pé e um Downed: entre os de pé, vale o de menor HP.
	BattleState.setup_party(["Guerreiro", "Mago", "Arqueiro"])
	var t3 := BattleState.new()
	t3.combatant_statuses[0]["downed"] = true
	BattleState.PLAYERS[0]["hp"] = 0
	BattleState.PLAYERS[1]["hp"] = 60
	BattleState.PLAYERS[2]["hp"] = 25
	DiceRoller.force_next([2])
	_eq("com o d2 caindo nos de pé, o de menor HP entre eles", t3._pick_enemy_target([0, 1, 2] as Array[int]), 2)
	DiceRoller.clear_forced()

	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	_reached.append("_test_enemy_target_downed")

# ── Architecture review P2–P7: testes de regressão ─────────────────────────
# Cada bloco salva/restaura o estado estático que altera.
func _test_architecture_p2p7() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS

	# P2a: identidade estável — dois inimigos do mesmo tipo não compartilham HP.
	BattleState.setup_party(["Guerreiro"])
	BattleState._append_enemy(BattleState.ALL_ENEMIES["Goblin"])
	var gob: Array = []
	for i in range(BattleState.TURN_QUEUE.size()):
		if BattleState.TURN_QUEUE[i].get("type", "") == "Goblin":
			gob.append(i)
	_eq("P2: dois Goblins na fila", gob.size(), 2)
	_true("P2: nomes de inimigos únicos",
		BattleState.TURN_QUEUE[gob[0]]["name"] != BattleState.TURN_QUEUE[gob[1]]["name"])
	var s := BattleState.new()
	var g_max: int = s.get_max_hp(gob[1])
	s._deal_damage_to_combatant(gob[0], 5, ActionData.DamageType.SLASHING)
	_eq("P2: dano no 1º Goblin não afeta o 2º", s.get_hp(gob[1]), g_max)
	_eq("P2: get_hp do 1º Goblin", s.get_hp(gob[0]), g_max - 5)
	# Acessores por índice de TURN_QUEUE (herói e inimigo)
	_eq("P2: get_hp herói lê PLAYERS", s.get_hp(0), BattleState.PLAYERS[0]["hp"])
	_eq("P2: get_max_hp herói", s.get_max_hp(0), BattleState.PLAYERS[0]["max_hp"])
	s._set_hp(0, 99999)
	_eq("P2: _set_hp limita ao máximo", s.get_hp(0), BattleState.PLAYERS[0]["max_hp"])
	s._set_hp(0, -5)
	_eq("P2: _set_hp limita a 0", s.get_hp(0), 0)
	_eq("P2: player_index_of herói", s.player_index_of(0), 0)
	_eq("P2: player_index_of inimigo = -1", s.player_index_of(gob[0]), -1)

	# P2b: Examinar mostra HP/CA vivos (PLAYERS, não HeroData) e o nome único do inimigo.
	BattleState.setup_party(["Guerreiro"])
	BattleState._append_enemy(BattleState.ALL_ENEMIES["Goblin"])
	var s_ex := BattleState.new()
	BattleState.PLAYERS[0]["max_hp"] = 123
	BattleState.PLAYERS[0]["hp"] = 50
	BattleState.PLAYERS[0]["ac"] = 19
	var ep := ExaminePanel.new()
	ep._ready()
	ep.show_for(s_ex, 0)
	var ex_txt: String = _labels_text(ep._combat_stats_box)
	_true("P2: Examinar herói mostra HP vivo (50 / 123)", ex_txt.contains("50 / 123"))
	_true("P2: Examinar herói mostra CA viva (19)", ex_txt.contains(" 19"))
	var g2 := BattleState.TURN_QUEUE.size() - 1
	s_ex._deal_damage_to_combatant(g2, 3, ActionData.DamageType.SLASHING)
	ep.show_for(s_ex, g2)
	_eq("P2: Examinar inimigo mostra o nome único", ep._name_label.text, BattleState.TURN_QUEUE[g2]["name"])
	_true("P2: Examinar inimigo mostra HP vivo", _labels_text(ep._combat_stats_box).contains("%d / %d" % [s_ex.get_hp(g2), s_ex.get_max_hp(g2)]))
	ep.free()

	# P3a: ciclo de vida das condições.
	BattleState.setup_party(["Guerreiro"])
	var sc := BattleState.new()
	var conc := {"label": "x", "action": ActionData.new()}
	# Atordoado de inimigo (incapacitado) quebra concentração como o do Monge (BG3)
	sc.concentration_by_caster[0] = conc
	sc._maybe_apply_stun(0, 1.0, "Teste")
	_eq("P3: stun de inimigo aplica stun", sc.combatant_statuses[0].get("stun", 0), 1)
	_true("P3: stun de inimigo quebra concentração", not sc.concentration_by_caster.has(0))
	# Wet (BG3): remove Burning e impede nova ignição
	sc.apply_condition(0, "burning", 2)
	sc.apply_condition(0, "wet", 3)
	_eq("P3: Wet remove Burning", sc.combatant_statuses[0].get("burning", 0), 0)
	sc._ignite(0)
	_eq("P3: Wet é imune a Burning", sc.combatant_statuses[0].get("burning", 0), 0)
	sc.remove_condition(0, "wet")
	sc._ignite(0)
	_eq("P3: sem Wet, ignição volta a funcionar", sc.combatant_statuses[0].get("burning", 0), 2)
	# remove_condition limpa dados associados
	sc.apply_condition(0, "charmed", 2, 1)
	sc.remove_condition(0, "charmed")
	_true("P3: remover Charmed limpa charmed_by", not sc.combatant_statuses[0].has("charmed_by") and not sc.combatant_statuses[0].has("charmed"))
	sc.apply_mark(0, 1, 1, 6, 3)
	sc.remove_condition(0, "marked")
	_true("P3: remover Marca limpa marked_*", not sc.combatant_statuses[0].has("marked_by") and not sc.combatant_statuses[0].has("marked_n"))
	# Superfícies e armadilha passam por apply_condition (Prone no gelo quebra concentração)
	var sc2 := BattleState.new()
	sc2.tile_surfaces[Vector2i(4, 3)] = {"type": SurfaceType.Type.WATER, "turns": 3}
	sc2.apply_condition(0, "burning", 2)
	sc2.apply_surface_on_enter(0, Vector2i(4, 3))
	_eq("P3: água aplica Wet", sc2.combatant_statuses[0].get("wet", 0), 3)
	_eq("P3: água apaga Burning", sc2.combatant_statuses[0].get("burning", 0), 0)
	# Help remove condições pela via central (Charmed/Frightened não ficam com sobra)
	var sc3 := BattleState.new()
	sc3.apply_condition(0, "frightened", 2, 1)
	sc3.remove_condition(0, "frightened")
	_true("P3: remover Frightened limpa frightened_by", not sc3.combatant_statuses[0].has("frightened_by"))

	# P3b: tick de turno — expiração pela via única e regras por condição.
	BattleState.setup_party(["Guerreiro"])
	var st := BattleState.new()
	var last := BattleState.TURN_QUEUE.size() - 1
	st.apply_condition(0, "frightened", 1, 1)
	st.apply_condition(0, "charmed", 1, 1)
	st.apply_mark(0, 1, 1, 6, 1)
	st.apply_condition(0, "wet", 2)
	st.active_index = last
	st.advance_turn()
	_true("P3: Frightened expira e limpa frightened_by", not st.combatant_statuses[0].has("frightened_by") and st.combatant_statuses[0].get("frightened", 0) == 0)
	_true("P3: Charmed expira e limpa charmed_by", not st.combatant_statuses[0].has("charmed_by"))
	_true("P3: Marca expira e limpa marked_*", not st.combatant_statuses[0].has("marked_n"))
	_eq("P3: Wet perde 1 turno no início do turno", st.combatant_statuses[0].get("wet", 0), 1)
	# Atordoado: perde o turno e decai; o turno passa ao próximo vivo
	var st2 := BattleState.new()
	st2.apply_condition(0, "stun", 1)
	st2.active_index = last
	st2.advance_turn()
	_true("P3: atordoado perde o turno", st2.active_index != 0)
	_eq("P3: stun decai ao perder o turno", st2.combatant_statuses[0].get("stun", 0), 0)
	# Burning decai no próprio tick (não duas vezes no mesmo turno)
	var st3 := BattleState.new()
	st3.apply_condition(0, "burning", 2)
	st3.active_index = last
	st3.advance_turn()
	_eq("P3: Burning perde só 1 turno por tick", st3.combatant_statuses[0].get("burning", 0), 1)

	# P4: matemática de ataque compartilhada entre rolagem real e preview.
	BattleState.setup_party(["Guerreiro", "Mago"])
	var sa := BattleState.new()
	sa.active_index = 0
	sa.current_attack_range = 1
	sa._current_action = AtqNormal.new()
	var tgt4: int = 2   # primeiro inimigo
	var base_ch: float = sa.calc_hit_chance(tgt4)
	_eq("P4: chance = enumeração exata do d20 (sem mods)", base_ch, sa._hit_probability(sa._player_attack_bonus(0, sa._current_action)["bonus"], sa._effective_ac(tgt4), sa._player_attack_bonus(0, sa._current_action)["crit_threshold"], 0, 0, 0))
	sa.apply_condition(tgt4, "acid", 2)
	_true("P4: Ácido (-2 CA) aumenta a chance do preview", sa.calc_hit_chance(tgt4) > base_ch)
	_eq("P4: CA efetiva com Ácido", sa._effective_ac(tgt4), int(BattleState.TURN_QUEUE[tgt4]["ac"]) - 2)
	sa.remove_condition(tgt4, "acid")
	sa.apply_condition(tgt4, "blinded", 2)   # atacar alvo cego = Vantagem
	var p1: float = base_ch
	_true("P4: Vantagem no preview = 1-(1-p)^2", absf(sa.calc_hit_chance(tgt4) - (1.0 - (1.0 - p1) * (1.0 - p1))) < 0.0001)
	sa.remove_condition(tgt4, "blinded")
	sa.apply_condition(0, "bonus_d4", 1)
	_true("P4: bonus_d4 entra no preview", sa.calc_hit_chance(tgt4) > base_ch)
	sa.remove_condition(0, "bonus_d4")
	# Probabilidade exata: nat 1 sempre erra, crítico sempre acerta
	_eq("P4: bônus enorme ainda erra no nat 1", sa._hit_probability(100, 10, 20, 0, 0, 0), 0.95)
	_eq("P4: bônus mínimo ainda acerta no crítico", sa._hit_probability(-100, 30, 20, 0, 0, 0), 0.05)
	_eq("P4: precisa de 11 → 50%", sa._hit_probability(0, 11, 20, 0, 0, 0), 0.5)
	_eq("P4: modificador arredonda para baixo (9 → -1, BG3)", sa._raw_mod(9), -1)
	_eq("P4: modificador 7 → -2", sa._raw_mod(7), -2)

	# P5: janela de reação ANTES do dano (golpe pendente + commit único).
	BattleState.setup_party(["Ladrao"])
	var hdl: HeroData = BattleState.ALL_HERO_DATA["Ladrao"]
	var e5: int = 1
	var mk5 := func() -> BattleState:
		var s5 := BattleState.new()
		s5.active_index = e5
		s5.active_enemy_action_idx = 0
		s5.combatant_positions[0] = Vector2i(2, 3)
		s5.combatant_positions[e5] = Vector2i(3, 3)
		return s5
	# Golpe pendente não altera HP até o commit
	var r1: BattleState = mk5.call()
	BattleState.PLAYERS[0]["hp"] = 50
	r1.hold_hits_for_reactions = true
	seed(_find_seed_for_d20(19))
	r1.apply_enemy_attack()
	r1.hold_hits_for_reactions = false
	var r1_amt: int = r1.last_attack_info.get("amount", 0)
	_true("P5: ataque segurado acerta com dano projetado", r1.last_attack_info.get("hit", false) and r1_amt > 0)
	_eq("P5: HP intacto antes do commit", BattleState.PLAYERS[0]["hp"], 50)
	_eq("P5: commit aplica o dano projetado", r1.commit_pending_hit(), r1_amt)
	_eq("P5: HP cai no commit", BattleState.PLAYERS[0]["hp"], 50 - r1_amt)
	_eq("P5: commit é único (2º commit = 0)", r1.commit_pending_hit(), 0)
	# Esquiva Sobrenatural reduz ANTES: herói a 1 HP com dano 2 não cai (antes caía e voltava)
	var r2: BattleState = mk5.call()
	BattleState.PLAYERS[0]["hp"] = 50
	r2.hold_hits_for_reactions = true
	seed(_find_seed_for_d20(19))
	r2.apply_enemy_attack()
	r2.hold_hits_for_reactions = false
	var r2_amt: int = r2.last_attack_info.get("amount", 0)
	BattleState.PLAYERS[0]["hp"] = r2_amt / 2 + 1   # sobrevive só se reduzir antes
	r2.apply_uncanny_dodge(0)
	_eq("P5: Esquiva atualiza o dano exibido (metade)", r2.last_attack_info.get("amount", -1), r2_amt / 2)
	r2.commit_pending_hit()
	_true("P5: Esquiva antes do dano evita Downed", not r2.is_downed(0) and BattleState.PLAYERS[0]["hp"] == 1)
	# Concentração usa o dano já reduzido (CD max(10, dano/2) — dano 0 não testa)
	var r3: BattleState = mk5.call()
	BattleState.PLAYERS[0]["hp"] = 80
	r3.concentration_by_caster[0] = {"label": "x", "action": ActionData.new()}
	r3.hold_hits_for_reactions = true
	seed(_find_seed_for_d20(19))
	r3.apply_enemy_attack()
	r3.hold_hits_for_reactions = false
	r3.pending_hit["post_flat"] = 999   # redução total (ex.: Defletir zerando)
	_eq("P5: golpe reduzido a 0 não aplica dano", r3.commit_pending_hit(), 0)
	_true("P5: dano 0 após reação não testa concentração", r3.concentration_by_caster.has(0))
	# Smite por reação vira componente RADIANT do MESMO golpe (1 falha de Death Save, não 2)
	BattleState.setup_party(["Paladino", "Guerreiro"])
	var r4 := BattleState.new()
	r4.active_index = 0
	r4.current_attack_range = 1
	r4._current_action = AtqNormal.new()
	r4.combatant_positions[0] = Vector2i(2, 3)
	r4.combatant_positions[1] = Vector2i(3, 3)
	BattleState.PLAYERS[1]["hp"] = 0
	r4._enter_downed(1)
	r4.hold_hits_for_reactions = true
	seed(_find_seed_for_d20(15))
	r4._apply_attack(1)
	r4.hold_hits_for_reactions = false
	r4.apply_divine_smite_reaction(0, 1, false)
	r4.commit_pending_hit()
	# BG3: golpe corpo a corpo em Downed é crítico = 2 falhas; arma + Smite contam como UM golpe (não 4).
	_eq("P5: arma + Smite no aliado Downed = 2 falhas (um golpe crítico só)", r4.combatant_statuses[1].get("death_saves_failure", 0), 2)

	# P6: economia de ações centralizada no BattleState.
	BattleState.setup_party(["Guerreiro", "Monge", "Mago"])
	var se := BattleState.new()
	se.active_index = 0
	se._load_hero_actions("Guerreiro")
	var sw := SkillSegundoVento.new()
	_true("P6: Segundo Vento disponível", se.is_item_available(sw))
	BattleState.PLAYERS[0]["hp"] = 10
	seed(5)
	var sw_roll: int = DiceRoller.roll(1, 10)
	seed(5)
	se.use_second_wind(sw)
	_eq("P6: Segundo Vento cura 1d10 + nível de Guerreiro (BG3)", BattleState.PLAYERS[0]["hp"], 10 + sw_roll + int(BattleState.PLAYERS[0].get("level", 1)))
	_true("P6: Segundo Vento gasta a Ação Bônus", se.has_used_bonus_action and not se.has_attacked)
	se.has_used_bonus_action = false
	se._load_hero_actions("Guerreiro")   # recarga das ações (início de turno)
	_true("P6: Segundo Vento é 1x por combate (não volta ao recarregar ações)", not se.is_item_available(SkillSegundoVento.new()))
	_eq("P6: Resource compartilhado não é mutado (pp)", sw.pp, 1)
	# Passo do Vento (BG3: Ação Bônus + 1 Ki, dobra o deslocamento)
	se.active_index = 1
	se._refill_move_points()
	se.has_used_bonus_action = false
	var mv0: int = se.move_points_remaining
	var ki0: int = int(BattleState.PLAYERS[1]["ki"])
	se.use_step_of_the_wind(SkillPassoVento.new())
	_eq("P6: Passo do Vento soma o deslocamento", se.move_points_remaining, mv0 + int(BattleState.PLAYERS[1]["speed"]))
	_eq("P6: Passo do Vento gasta 1 Ki", int(BattleState.PLAYERS[1]["ki"]), ki0 - 1)
	_true("P6: Passo do Vento gasta a Ação Bônus", se.has_used_bonus_action)
	_true("P6: sem Ação Bônus, Passo do Vento indisponível", not se.is_item_available(SkillPassoVento.new()))
	# Esconder gasta a Ação; Mergulhar gasta a Ação Bônus (via spend_action_cost)
	se.active_index = 0
	se.has_attacked = false
	se.has_used_bonus_action = false
	se.has_used_bonus_action = false
	se.spend_action_cost(AcaoEsconder.new())
	_true("P6: Esconder gasta a Ação principal", se.has_attacked and not se.has_used_bonus_action)
	se.spend_action_cost(AcaoDip.new())
	_true("P6: Mergulhar gasta a Ação Bônus", se.has_used_bonus_action)
	# Slots: upcast único (nível 1 vazio → gasta o de nível 2) e Ki de ataque
	se.active_index = 2
	BattleState.PLAYERS[2]["spell_slots"] = [0, 1, 0, 0, 0, 0]
	se.has_attacked = false
	se.has_used_bonus_action = false
	var cura := SpellCura.new()
	_true("P6: magia de nível 1 disponível via upcast", se.is_item_available(cura))
	se.spend_action_cost(cura)
	_eq("P6: upcast gasta o slot de nível 2", BattleState.PLAYERS[2]["spell_slots"], [0, 0, 0, 0, 0, 0])
	_true("P6: sem slots, magia indisponível", not se.is_item_available(cura))
	se.active_index = 1
	var flurry := SkillFlurry.new()
	var ki1: int = int(BattleState.PLAYERS[1]["ki"])
	se.spend_action_cost(flurry)
	_eq("P6: custo de Ki do ataque gasto no estado", int(BattleState.PLAYERS[1]["ki"]), ki1 - flurry.ki_cost)

	# P7: rolagens determinísticas sem depender da ordem global do RNG.
	DiceRoller.force_next([3, 4, 20])
	_eq("P7: force_next define a próxima rolagem (d6)", DiceRoller.roll_d(6), 3)
	_eq("P7: roll(n, s) consome um valor por dado", DiceRoller.roll(1, 4), 4)
	_eq("P7: d20 forçado", DiceRoller.roll_d20_adv_dis(0, 0)["result"], 20)
	DiceRoller.force_next([9])
	_eq("P7: valor forçado é limitado ao dado (9 num d4 → 4)", DiceRoller.roll_d(4), 4)
	DiceRoller.force_next([5])
	DiceRoller.clear_forced()
	var p7_r: int = DiceRoller.roll_d(20)
	_true("P7: clear_forced volta ao RNG", p7_r >= 1 and p7_r <= 20)
	# Uso real: armadilha (2d4) seguida do save de concentração (d20 = 1)
	BattleState.setup_party(["Guerreiro"])
	var s7f := BattleState.new()
	BattleState.PLAYERS[0]["hp"] = 50
	s7f.tile_data_map[4][3].effect = TerrainTile.EffectType.TRAP_INACTIVE
	s7f.concentration_by_caster[0] = {"label": "x", "action": ActionData.new()}
	DiceRoller.force_next([2, 2, 1])
	s7f._check_trap(0, Vector2i(4, 3))
	DiceRoller.clear_forced()
	_eq("P7: armadilha com dados forçados causa 2+2", BattleState.PLAYERS[0]["hp"], 46)
	_true("P7: save forçado em 1 quebra a concentração", not s7f.concentration_by_caster.has(0))

	# Final review: incapacitado (Downed/Atordoado/Paralisado) não reage (BG3).
	BattleState.setup_party(["Monge"])
	var sx := BattleState.new()
	_true("reação disponível para combatente apto", sx.has_reaction_available(0))
	sx.combatant_statuses[0]["downed"] = true
	_true("Downed não pode reagir", not sx.has_reaction_available(0))
	sx.combatant_statuses[0].erase("downed")
	sx.apply_condition(0, "stun", 1)
	_true("Atordoado não pode reagir", not sx.has_reaction_available(0))
	sx.remove_condition(0, "stun")
	sx.apply_condition(0, "paralyzed", 1)
	_true("Paralisado não pode reagir", not sx.has_reaction_available(0))
	# Os blocos acima trocaram o grupo (estáticos globais): restaura Guerreiro + Mago.
	# Sem isto, PLAYERS[1] não existia, o erro abortava a função e as asserções abaixo
	# nunca rodavam (e o runner contava "passou" mesmo assim).
	BattleState.setup_party(["Guerreiro", "Mago"])
	sa = BattleState.new()
	# CD de magia usa o conjurador informado, não o ativo
	sa.active_index = 0
	BattleState.PLAYERS[1]["intelligence"] = 18
	_eq("P4: _spell_save_dc usa o atacante", sa._spell_save_dc(1, ActionData.DamageAttribute.INT),
		8 + int(BattleState.PLAYERS[1].get("proficiency", 2)) + 4)
	# Ataque de Oportunidade de inimigo usa os stats e o tipo de dano do inimigo
	var oa_e: int = 2
	var oa_ed: EnemyData = BattleState.ALL_ENEMIES[BattleState.TURN_QUEUE[oa_e]["type"]]
	var so := BattleState.new()
	so.combatant_positions[0] = Vector2i(2, 3)
	so.combatant_positions[oa_e] = Vector2i(3, 3)
	seed(_find_seed_for_d20(15))
	so.apply_opportunity_attack(oa_e, 0)
	var oa_atk_mod: int = so._enemy_attack_profile(oa_e)["bonus"]
	_eq("P4: OA de inimigo soma o bônus do inimigo", so.last_attack_info.get("attack_total", -1), 15 + oa_atk_mod)
	_eq("P4: OA de inimigo causa o tipo do inimigo", so.last_attack_info.get("damage_type", -1) if so.last_attack_info.get("hit", false) else oa_ed.attack_damage_type, oa_ed.attack_damage_type)

	# StatusPanel: sem "portrait" no dicionário do herói (grupo legado), cai no HeroData sem erro.
	var sp_panel: StatusPanel = StatusPanel.new()
	_true("StatusPanel: retrato do HeroData quando o dicionário não tem", sp_panel._get_portrait_from_player({"name": "Arqueiro"}) is Texture2D)
	_true("StatusPanel: retrato de inimigo", sp_panel._get_portrait_from_enemy({"type": BattleState.ALL_ENEMIES.keys()[0]}) is Texture2D)
	sp_panel.free()
	# SpriteProvider: 4 cores para 8 heróis. Herói de índice >= 4 sem sprite estourava o array.
	for fb_hero in ["Guerreiro", "Ladrao", "Paladino", "Monge"]:
		var fb_tex: Texture2D = SpriteProvider.create_fallback_texture({"is_player": true, "name": fb_hero}, 0)
		_true("SpriteProvider: textura de fallback para %s" % fb_hero, fb_tex != null)
	# CombatantLayer lê o HP pelo índice da fila, igual para herói e inimigo.
	BattleState.setup_party(["Guerreiro", "Mago"])
	var cl_state := BattleState.new()
	# load() em runtime: citar as classes direto quebra a compilação do runner (usam autoloads).
	var cl: Node = load("res://vfx/components/combatant_layer.gd").new()
	var cn_script: GDScript = load("res://vfx/components/combatant_node.gd")
	for _q in BattleState.TURN_QUEUE.size():
		cl.add_child(cn_script.new())
	cl_state._set_hp(0, 7)
	cl_state._set_hp(2, 3)
	cl.update_all_combatant_ui(cl_state)
	_eq("CombatantLayer: HP do herói pelo índice", cl.get_child(0)._current_hp, 7)
	_eq("CombatantLayer: HP máx do herói", cl.get_child(0)._max_hp, cl_state.get_max_hp(0))
	_eq("CombatantLayer: HP do inimigo pelo índice", cl.get_child(2)._current_hp, 3)
	_eq("CombatantLayer: HP máx do inimigo", cl.get_child(2)._max_hp, cl_state.get_max_hp(2))
	cl.free()

	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	_reached.append("_test_architecture_p2p7")

# ── Suporte a controle: dispositivo ativo, cursor unificado, exame, vibração, settings ──
func _test_gamepad_support() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS

	# Dispositivo ativo: o último a ser usado manda.
	var trk := InputDeviceTracker.new()
	_eq("dispositivo: começa em teclado/mouse", trk.active, InputDeviceTracker.Device.KEYBOARD_MOUSE)
	_true("dispositivo: botão do controle troca", trk.note_joy_button(3))
	_eq("dispositivo: controle ativo", trk.active, InputDeviceTracker.Device.GAMEPAD)
	_eq("dispositivo: guarda o id do controle", trk.gamepad_id, 3)
	_true("dispositivo: repetir o controle não é troca", not trk.note_joy_button(3))
	_true("dispositivo: tecla volta ao teclado", trk.note_key())
	_eq("dispositivo: teclado ativo", trk.active, InputDeviceTracker.Device.KEYBOARD_MOUSE)
	_true("dispositivo: tremor do mouse não troca", not trk.note_mouse_motion(Vector2(0.1, 0.0)))
	_true("dispositivo: drift do analógico não troca", not trk.note_joy_axis(0, 0.3))
	_eq("dispositivo: drift não vira controle", trk.active, InputDeviceTracker.Device.KEYBOARD_MOUSE)
	_true("dispositivo: empurrão do analógico troca", trk.note_joy_axis(0, 0.7))
	_true("dispositivo: mexer o mouse volta", trk.note_mouse_motion(Vector2(4.0, 0.0)))
	trk.note_joy_button(1)
	trk.note_joy_button(2)
	_eq("dispositivo: vários controles, o último usado manda", trk.gamepad_id, 2)
	_true("dispositivo: desconectar outro controle não muda nada", not trk.note_joy_disconnected(1))
	_eq("dispositivo: continua no controle 2", trk.active, InputDeviceTracker.Device.GAMEPAD)
	_true("dispositivo: desconectar o ativo volta ao teclado", trk.note_joy_disconnected(2))
	_eq("dispositivo: teclado após desconexão", trk.active, InputDeviceTracker.Device.KEYBOARD_MOUSE)
	_eq("dispositivo: id limpo após desconexão", trk.gamepad_id, -1)

	_eq("zona morta: ruído vira zero", InputDeviceTracker.apply_deadzone(Vector2(0.15, 0.15)), Vector2.ZERO)
	_true("zona morta: empurrão total chega a 1",
		is_equal_approx(InputDeviceTracker.apply_deadzone(Vector2(1.0, 0.0)).length(), 1.0))
	_eq("direção 4 vias: eixo dominante x", InputDeviceTracker.stick_dir4(Vector2(0.9, 0.4)), Vector2i(1, 0))
	_eq("direção 4 vias: cima", InputDeviceTracker.stick_dir4(Vector2(0.0, -0.8)), Vector2i(0, -1))
	_eq("direção 4 vias: abaixo do limiar", InputDeviceTracker.stick_dir4(Vector2(0.3, 0.3)), Vector2i.ZERO)

	_eq("dica: confirmar no controle", InputGlyphs.label(&"confirm", InputDeviceTracker.Device.GAMEPAD), "A")
	_eq("dica: confirmar no teclado", InputGlyphs.label(&"confirm", InputDeviceTracker.Device.KEYBOARD_MOUSE), "Enter")
	_eq("dica: voltar no controle", InputGlyphs.label(&"back", InputDeviceTracker.Device.GAMEPAD), "B")
	_eq("dica: fim de turno no teclado é Space (BG3), no controle X", [InputGlyphs.label(&"end_turn", InputDeviceTracker.Device.KEYBOARD_MOUSE), InputGlyphs.label(&"end_turn", InputDeviceTracker.Device.GAMEPAD)], ["Space", "X"])
	_eq("dica: exame no teclado é Tab", InputGlyphs.label(&"examine", InputDeviceTracker.Device.KEYBOARD_MOUSE), "Tab")
	_eq("dica: exame no controle é Y", InputGlyphs.label(&"examine", InputDeviceTracker.Device.GAMEPAD), "Y")
	_eq("dica: ação desconhecida some", InputGlyphs.label(&"nada", InputDeviceTracker.Device.GAMEPAD), "")

	# ── Cursor unificado, validade na confirmação, exame e vibração ──────────────
	# Índices: 0 Guerreiro, 1 Mago, 2 Clérigo, 3.. inimigos (3 = Goblin Scout).
	BattleState.setup_party(["Guerreiro", "Mago", "Clérigo"])
	var cs := BattleState.new()
	cs.combatant_positions[0] = Vector2i(2, 3)
	cs.combatant_positions[1] = Vector2i(1, 1)
	cs.combatant_positions[2] = Vector2i(3, 4)
	for ci in range(3, BattleState.TURN_QUEUE.size()):
		cs.combatant_positions[ci] = Vector2i(11, ci - 3)

	# Navegação por quadrado ignora elevação; borda mantém o último quadrado.
	cs.tile_data_map[3][3].ground = TerrainTile.GroundType.ELEVATED
	cs.enter_move_mode()
	cs.step_cursor(Vector2i(1, 0))
	_eq("cursor: entra no quadrado elevado vizinho", cs.cursor_tile, Vector2i(3, 3))
	cs.cursor_tile = Vector2i(0, 0)
	cs.step_cursor(Vector2i(-1, 0))
	cs.step_cursor(Vector2i(0, -1))
	_eq("cursor: borda esquerda/topo mantém o último quadrado", cs.cursor_tile, Vector2i(0, 0))
	cs.cursor_tile = Vector2i(cs.grid_cols - 1, cs.grid_rows - 1)
	cs.step_cursor(Vector2i(1, 0))
	cs.step_cursor(Vector2i(0, 1))
	_eq("cursor: borda direita/base mantém o último quadrado", cs.cursor_tile, Vector2i(cs.grid_cols - 1, cs.grid_rows - 1))
	cs.set_cursor_tile(Vector2i(-1, -1))
	cs.step_cursor(Vector2i(1, 0))
	_eq("cursor: fora do grid parte do combatente ativo", cs.cursor_tile, Vector2i(3, 3))

	# Mover: feedback e confirmação.
	cs.set_cursor_tile(Vector2i(4, 3))
	_true("mover: tile alcançável é válido", cs.get_cursor_feedback()["valid"])
	cs.set_cursor_tile(Vector2i(11, 3))
	_eq("mover: tile inalcançável avisa", cs.get_cursor_feedback()["reason"], "Impossível movimentar até aqui")
	_true("mover: confirmar inalcançável é rejeitado", not cs.apply_cursor_selection())
	_eq("mover: rejeição não sai do modo", cs.current_state, BattleState.State.MOVE_MODE)
	cs.set_cursor_tile(Vector2i(-3, 40))
	_true("mover: fora do grid é inválido", not cs.get_cursor_feedback()["valid"])
	_eq("mover: fora do grid não mostra aviso", cs.get_cursor_feedback()["reason"], "")
	cs.set_cursor_tile(Vector2i(4, 3))
	_true("mover: confirmar alcançável fixa o destino", cs.apply_cursor_selection())
	_eq("mover: move_cursor recebe o destino", cs.move_cursor, Vector2i(4, 3))
	cs.cancel_move()
	_eq("feedback: fora de MOVE/ATTACK não é válido", cs.get_cursor_feedback()["valid"], false)

	# Mira de alvo único (corpo a corpo): só confirma sobre alvo válido.
	cs.combatant_positions[3] = Vector2i(3, 3)   # Goblin adjacente
	cs.enter_attack_mode(1)
	_eq("mira: cursor começa no primeiro alvo", cs.cursor_tile, Vector2i(3, 3))
	_true("mira: cursor sobre o alvo é válido", cs.get_cursor_feedback()["valid"])
	_true("mira: confirmar sobre o alvo fixa o índice", cs.apply_cursor_selection() and cs.attack_cursor_idx == 0)
	cs.step_cursor(Vector2i(1, 0))
	_eq("mira: quadrado vazio avisa Sem alvo", cs.get_cursor_feedback()["reason"], "Sem alvo")
	_true("mira: confirmar no vazio é rejeitado", not cs.apply_cursor_selection())
	_true("mira: rejeição não gasta a ação", not cs.has_attacked and cs.current_state == BattleState.State.ATTACK_MODE)
	cs.set_cursor_tile(Vector2i(11, 1))   # inimigo longe
	_eq("mira: inimigo fora do alcance avisa", cs.get_cursor_feedback()["reason"], "Fora de alcance")
	cs.cancel_attack()

	# Mira em aliado (cura) e em si mesmo.
	cs.enter_attack_mode(5, true)
	cs.set_cursor_tile(cs.combatant_positions[1])
	_true("aliado: cursor sobre aliado é válido", cs.get_cursor_feedback()["valid"])
	cs.set_cursor_tile(Vector2i(3, 3))   # inimigo dentro do alcance, lado errado
	_eq("aliado: inimigo é alvo inválido", cs.get_cursor_feedback()["reason"], "Alvo inválido")
	cs.cancel_attack()
	cs.enter_attack_mode(1, true, Color.WHITE, true)
	cs.set_cursor_tile(cs.combatant_positions[0])
	_true("self: cursor no próprio quadrado é válido", cs.get_cursor_feedback()["valid"])
	cs.cancel_attack()

	# AoE em ponto: qualquer tile do alcance confirma; fora não gasta slot.
	var slots_before: Array = BattleState.PLAYERS[0]["spell_slots"].duplicate()
	cs._current_action = SpellFogo.new()
	cs.enter_attack_mode(6, false, Color.WHITE, false)
	_true("AoE: modo de ponto ligado", cs.attack_tile_mode)
	cs.set_cursor_tile(Vector2i(5, 3))
	_true("AoE: tile dentro do alcance é válido", cs.get_cursor_feedback()["valid"])
	cs.set_cursor_tile(Vector2i(11, 0))
	_eq("AoE: tile fora do alcance avisa", cs.get_cursor_feedback()["reason"], "Fora de alcance")
	_true("AoE: confirmar fora é rejeitado", not cs.apply_cursor_selection())
	_eq("AoE: rejeição não consome slot", BattleState.PLAYERS[0]["spell_slots"], slots_before)
	cs.cancel_attack()

	# Pulo: o feedback segue is_valid_jump_landing.
	cs._current_action = AcaoPular.new()
	cs.enter_attack_mode(2, false, Color.WHITE, false)
	cs.set_cursor_tile(Vector2i(11, 6))
	_eq("Pulo: pouso inválido avisa", cs.get_cursor_feedback()["reason"], "Pulo impossível")
	var landing: Array[Vector2i] = cs.get_jump_landing_tiles(0)
	if not landing.is_empty():
		cs.set_cursor_tile(landing[0])
		_true("Pulo: pouso válido confirma", cs.get_cursor_feedback()["valid"] and cs.apply_cursor_selection())
	cs.cancel_attack()
	cs._current_action = null

	# Exame: ordem de turnos sem mortos, com volta.
	var ex := BattleState.new()
	var living: Array[int] = ex.living_turn_order()
	_eq("exame: sem mortos, todos na ordem", living.size(), BattleState.TURN_QUEUE.size())
	_eq("exame: próximo", ex.examine_step(0, 1), 1)
	_eq("exame: anterior com volta", ex.examine_step(0, -1), BattleState.TURN_QUEUE.size() - 1)
	ex.dead_indices[1] = true
	_eq("exame: pula combatente morto", ex.examine_step(0, 1), 2)
	_eq("exame: índice morto cai no primeiro vivo", ex.examine_step(1, 0), 0)
	_eq("exame: índice inexistente cai no primeiro vivo", ex.examine_step(99, 1), 0)
	for ei in range(BattleState.TURN_QUEUE.size()):
		ex.dead_indices[ei] = true
	_eq("exame: sem vivos devolve -1", ex.examine_step(0, 1), -1)

	# Vibração: quais eventos do golpe merecem vibrar.
	_eq("vibração: crítico em herói", cs.hit_rumble_kind({"hit": true, "is_crit": true, "target_idx": 0}), InputRumble.CRIT_TAKEN)
	_eq("vibração: crítico em inimigo", cs.hit_rumble_kind({"hit": true, "is_crit": true, "target_idx": 3}), InputRumble.CRIT_DEALT)
	_eq("vibração: acerto normal não vibra", cs.hit_rumble_kind({"hit": true, "is_crit": false, "target_idx": 0}), &"")
	_eq("vibração: erro não vibra", cs.hit_rumble_kind({"hit": false, "is_crit": true, "target_idx": 0}), &"")
	_eq("vibração: cura não vibra", cs.hit_rumble_kind({"hit": true, "is_crit": true, "is_heal": true, "target_idx": 0}), &"")
	_eq("vibração: sem info não vibra", cs.hit_rumble_kind({}), &"")
	cs.pending_downed.clear()
	cs._deal_damage_to_combatant(0, 9999, ActionData.DamageType.SLASHING)
	_eq("vibração: herói Downed entra em pending_downed", cs.pending_downed, [0])
	cs.pending_downed.clear()
	cs._deal_damage_to_combatant(3, 9999, ActionData.DamageType.SLASHING)
	_eq("vibração: inimigo morto não entra em pending_downed", cs.pending_downed, [])

	# Decisão de vibrar: desligado, sem controle, cooldown e prioridade.
	var now := 10000
	_eq("rumble: desligado não vibra", InputRumble.decide(InputRumble.DOWNED, false, true, now, 0, 0), {})
	_eq("rumble: sem controle ativo não vibra", InputRumble.decide(InputRumble.DOWNED, true, false, now, 0, 0), {})
	_eq("rumble: evento desconhecido não vibra", InputRumble.decide(&"x", true, true, now, 0, 0), {})
	_true("rumble: crítico recebido é curto", InputRumble.decide(InputRumble.CRIT_TAKEN, true, true, now, 0, 0)["duration"] < 0.5)
	_eq("rumble: crítico logo depois de Downed é ignorado",
		InputRumble.decide(InputRumble.CRIT_DEALT, true, true, now + 50, now, 3), {})
	_true("rumble: Downed interrompe um crítico no cooldown",
		not InputRumble.decide(InputRumble.DOWNED, true, true, now + 50, now, 1).is_empty())
	_true("rumble: passado o cooldown qualquer evento vibra",
		not InputRumble.decide(InputRumble.CRIT_DEALT, true, true, now + InputRumble.COOLDOWN_MS, now, 3).is_empty())
	var durations := {}
	for rk in [InputRumble.CRIT_DEALT, InputRumble.CRIT_TAKEN, InputRumble.DOWNED]:
		durations[InputRumble.profile(rk)["duration"]] = true
	_eq("rumble: os três eventos têm durações distintas", durations.size(), 3)
	_eq("rumble: perfil desconhecido é vazio", InputRumble.profile(&"x"), {})

	# Navegação da HUD (lógica pura): ordem de leitura com volta; cima/baixo na coluna mais próxima.
	var hud_entries: Array = [
		{"id": "A", "row": 0, "col": 0}, {"id": "B", "row": 0, "col": 1}, {"id": "C", "row": 0, "col": 5},
		{"id": "D", "row": 1, "col": 0}, {"id": "E", "row": 1, "col": 6},
		{"id": "I0", "row": 4, "col": 0}, {"id": "I1", "row": 4, "col": 1},
	]
	_eq("HUD: direita anda na ordem de leitura", HudNav.step(hud_entries, "A", Vector2i(1, 0)), "B")
	_eq("HUD: direita no fim da linha vai à próxima linha", HudNav.step(hud_entries, "C", Vector2i(1, 0)), "D")
	_eq("HUD: direita no último dá a volta", HudNav.step(hud_entries, "I1", Vector2i(1, 0)), "A")
	_eq("HUD: esquerda no primeiro dá a volta", HudNav.step(hud_entries, "A", Vector2i(-1, 0)), "I1")
	_eq("HUD: baixo escolhe a coluna mais próxima", HudNav.step(hud_entries, "C", Vector2i(0, 1)), "E")
	_eq("HUD: baixo pula linhas vazias até a barra de itens", HudNav.step(hud_entries, "D", Vector2i(0, 1)), "I0")
	_eq("HUD: cima na primeira linha não dá a volta", HudNav.step(hud_entries, "B", Vector2i(0, -1)), "B")
	_eq("HUD: cima volta da barra de itens (coluna mais próxima)", HudNav.step(hud_entries, "I1", Vector2i(0, -1)), "D")
	_eq("HUD: cursor inválido cai no primeiro", HudNav.step(hud_entries, "ZZ", Vector2i(1, 0)), "A")
	_eq("HUD: sem entradas devolve vazio", HudNav.step([], "A", Vector2i(1, 0)), "")

	# Painel de detalhes da HUD: posição junto ao item (dentro da tela, sem cobrir o item) e texto de itens.
	var tip_vp := Vector2(1280, 720)
	var tip_size := Vector2(220, 120)
	var hud_item := Rect2(300, 590, 50, 50)
	var p_above: Vector2 = ActionTooltipPanel.place(hud_item, tip_size, tip_vp)
	_true("painel: fica acima do item da HUD", p_above.y + tip_size.y <= hud_item.position.y)
	_true("painel: acima do item não o cobre", not Rect2(p_above, tip_size).intersects(hud_item))
	var p_left: Vector2 = ActionTooltipPanel.place(Rect2(0, 590, 50, 50), tip_size, tip_vp)
	_true("painel: item na borda esquerda mantém o painel dentro da tela", Rect2(Vector2.ZERO, tip_vp).encloses(Rect2(p_left, tip_size)))
	var p_right: Vector2 = ActionTooltipPanel.place(Rect2(1250, 590, 30, 30), tip_size, tip_vp)
	_true("painel: item na borda direita mantém o painel dentro da tela", Rect2(Vector2.ZERO, tip_vp).encloses(Rect2(p_right, tip_size)))
	var top_item := Rect2(500, 10, 50, 50)
	var p_below: Vector2 = ActionTooltipPanel.place(top_item, tip_size, tip_vp)
	_true("painel: sem espaço acima, vai abaixo do item", p_below.y >= top_item.end.y)
	_true("painel: abaixo do item não o cobre", not Rect2(p_below, tip_size).intersects(top_item))
	var tall := Vector2(220, 400)
	var mid_item := Rect2(500, 150, 50, 50)
	var p_side: Vector2 = ActionTooltipPanel.place(mid_item, tall, Vector2(1280, 560))
	_true("painel: sem espaço acima nem abaixo, vai ao lado sem cobrir o item",
		not Rect2(p_side, tall).intersects(mid_item) and Rect2(Vector2.ZERO, Vector2(1280, 560)).encloses(Rect2(p_side, tall)))
	_eq("painel: texto da Poção", ActionTooltipPanel.item_description(BattleState.TAB_ITEMS[0]), "Restaura 2d4+2 HP e apaga Em Chamas. Ação Bônus.")
	_eq("painel: o Éter não existe mais (sem texto para spell_slot_restore)", ActionTooltipPanel.item_description({"spell_slot_restore": 1}), "")
	_eq("painel: item sem efeito conhecido não inventa texto", ActionTooltipPanel.item_description({"label": "X"}), "")

	# Câmera: rolagem de borda, limites do mapa e níveis de zoom.
	var view := Vector2(1000, 600)
	_eq("câmera: ponteiro no centro não rola",
		BattleCamera.edge_pan_velocity(Vector2(500, 300), view, 56.0, Vector2(1, 0), 420.0), Vector2.ZERO)
	_true("câmera: borda direita empurrando para a direita rola (pan diminui)",
		BattleCamera.edge_pan_velocity(Vector2(980, 300), view, 56.0, Vector2(1, 0), 420.0).x < 0.0)
	_true("câmera: borda esquerda empurrando para a esquerda rola (pan aumenta)",
		BattleCamera.edge_pan_velocity(Vector2(20, 300), view, 56.0, Vector2(-1, 0), 420.0).x > 0.0)
	_eq("câmera: na borda mas empurrando para dentro não rola",
		BattleCamera.edge_pan_velocity(Vector2(980, 300), view, 56.0, Vector2(-1, 0), 420.0), Vector2.ZERO)
	_true("câmera: borda inferior rola no eixo y",
		BattleCamera.edge_pan_velocity(Vector2(500, 590), view, 56.0, Vector2(0, 1), 420.0).y < 0.0)
	_eq("câmera: mapa todo visível não rola",
		BattleCamera.can_pan(Rect2(100, 50, 600, 400), view, Vector2(-30, -30)), Vector2.ZERO)
	var big_map := Rect2(-200, 10, 1400, 800)   # passa da direita e da base; cabe na esquerda e no topo
	_eq("câmera: há mapa à direita, pode rolar para lá", BattleCamera.can_pan(big_map, view, Vector2(-30, 0)).x, -30.0)
	_eq("câmera: sem mapa além da esquerda, para", BattleCamera.can_pan(Rect2(0, 10, 1400, 800), view, Vector2(30, 0)).x, 0.0)
	_eq("câmera: há mapa abaixo, pode rolar para lá", BattleCamera.can_pan(big_map, view, Vector2(0, -30)).y, -30.0)
	_eq("zoom: 1.0 vai para 1.5", BattleCamera.next_zoom(1.0), 1.5)
	_eq("zoom: o maior volta ao menor", BattleCamera.next_zoom(2.0), 0.75)
	_eq("zoom: valor fora dos níveis (roda do mouse) vai ao próximo", BattleCamera.next_zoom(0.9), 1.0)
	_eq("zoom: acima do maior volta ao menor", BattleCamera.next_zoom(2.5), 0.75)

	# Ponte e actions do controle.
	InputBindings.register()
	var examine_events: int = InputMap.action_get_events(InputBindings.EXAMINE).size()
	InputBindings.register()
	_eq("bindings: registrar duas vezes não duplica eventos", InputMap.action_get_events(InputBindings.EXAMINE).size(), examine_events)
	for act in [InputBindings.END_TURN, InputBindings.EXAMINE, InputBindings.LOG, InputBindings.ZOOM_CYCLE]:
		_true("bindings: action %s registrada" % act, InputMap.has_action(act))
	var tab_ev := InputEventKey.new()
	tab_ev.keycode = KEY_TAB
	_true("bindings: Tab dispara o exame", InputMap.event_is_action(tab_ev, InputBindings.EXAMINE))
	var y_ev := InputEventJoypadButton.new()
	y_ev.button_index = JOY_BUTTON_Y
	_true("bindings: Y dispara o exame", InputMap.event_is_action(y_ev, InputBindings.EXAMINE))
	_eq("ponte: A vira Enter", InputBindings.bridge_key(JOY_BUTTON_A), KEY_ENTER)
	_eq("ponte: B vira Esc", InputBindings.bridge_key(JOY_BUTTON_B), KEY_ESCAPE)
	_eq("ponte: D-pad esquerdo vira seta", InputBindings.bridge_key(JOY_BUTTON_DPAD_LEFT), KEY_LEFT)
	_eq("ponte: LB vira Q (aba anterior)", InputBindings.bridge_key(JOY_BUTTON_LEFT_SHOULDER), KEY_Q)
	_eq("ponte: RB vira E (próxima aba)", InputBindings.bridge_key(JOY_BUTTON_RIGHT_SHOULDER), KEY_E)
	_eq("ponte: Start vira P (pausa)", InputBindings.bridge_key(JOY_BUTTON_START), KEY_P)
	_eq("ponte: X não é ponteado (action de fim de turno)", InputBindings.bridge_key(JOY_BUTTON_X), 0)
	_eq("ponte: Y não é ponteado (action de exame)", InputBindings.bridge_key(JOY_BUTTON_Y), 0)
	_true("ponte: setas repetem", InputBindings.repeats(KEY_UP))
	_true("ponte: Enter não repete", not InputBindings.repeats(KEY_ENTER))
	var idev: Node = root.get_node_or_null("InputDevice")
	_true("autoload InputDevice existe", idev != null)
	if idev != null:
		_true("autoload: começa em teclado/mouse", not idev.is_gamepad())
		_eq("autoload: sem controle o cursor virtual é zero", idev.cursor_axis(), Vector2.ZERO)
		idev.rumble(InputRumble.DOWNED)   # sem controle ativo: não faz nada, nem erra

	# Settings: vibração persistida só no sandbox, nunca no settings.cfg real.
	var real_settings_path: String = GameSettings.PATH
	var real_vibration: bool = GameSettings.vibration_enabled
	var real_settings_before: String = _fingerprint(real_settings_path)
	GameSettings.PATH = TEST_SAVE_DIR + "/settings_sandbox.cfg"
	DirAccess.remove_absolute(GameSettings.PATH)
	_true("settings: vibração liga por padrão (sem arquivo)", GameSettings.load_settings()["vibration"])
	GameSettings.save_settings({"fullscreen": false, "vsync": true, "resolution": "1280x720", "vibration": false})
	_eq("settings: vibração desligada persiste", GameSettings.load_settings()["vibration"], false)
	GameSettings.save_settings({"fullscreen": false, "vsync": true, "resolution": "1280x720", "vibration": true})
	_eq("settings: vibração ligada persiste", GameSettings.load_settings()["vibration"], true)
	var legacy := ConfigFile.new()
	legacy.set_value("display", "vsync", false)
	legacy.save(GameSettings.PATH)
	_true("settings: arquivo legado sem a chave liga a vibração", GameSettings.load_settings()["vibration"])
	_eq("settings: arquivo legado mantém as demais chaves", GameSettings.load_settings()["vsync"], false)
	GameSettings.apply_settings({"fullscreen": false, "vsync": true, "resolution": "1280x720", "vibration": false})
	_eq("settings: apply_settings espelha a vibração", GameSettings.vibration_enabled, false)
	DirAccess.remove_absolute(GameSettings.PATH)
	GameSettings.PATH = real_settings_path
	GameSettings.vibration_enabled = real_vibration
	_true("settings: o caminho real foi restaurado", GameSettings.PATH == "user://settings.cfg")
	_eq("settings: o settings.cfg real não foi tocado", _fingerprint(real_settings_path), real_settings_before)

	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	_reached.append("_test_gamepad_support")

func _frames(n: int) -> void:
	for _i in range(n):
		await process_frame

func _press_key(code: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code as Key
		ev.physical_keycode = code as Key
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _frames(2)

func _press_joy(button: int) -> void:
	for pressed in [true, false]:
		var ev := InputEventJoypadButton.new()
		ev.device = 0
		ev.button_index = button as JoyButton
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _frames(2)

# Navegação da HUD de combate por eventos reais de controle e teclado (a mesma rota do jogo:
# autoload InputDevice -> teclas -> BattleScene -> ActionPanel). Prova que o cursor anda pelas
# células VISÍVEIS, que o anel branco está no item que Enter/A executa e que a barra
# Confirmar/Voltar aciona o botão focado.
func _test_hud_navigation() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS
	var saved_run = DungeonState.current_run
	DungeonState.current_run = null
	BattleState.setup_party(["Guerreiro", "Mago", "Clérigo"])
	DiceRoller.force_next([20, 20, 20, 1, 1, 1, 1])   # heróis jogam primeiro
	var scene = load("res://battle/battle_scene.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	DiceRoller.clear_forced()
	var waited := 0
	while waited < 1500 and (scene._animating or scene._state.current_state != BattleState.State.PLAYER_TURN):
		await process_frame
		waited += 1
	var st: BattleState = scene._state
	var panel = scene._action_panel
	var idev: Node = root.get_node("InputDevice")
	_true("HUD: a cena chegou num turno de herói livre", not scene._animating and st.current_state == BattleState.State.PLAYER_TURN)

	await _press_joy(JOY_BUTTON_A)   # acorda o controle (só troca o dispositivo)
	_true("HUD: controle ativo", idev.is_gamepad())
	_eq("HUD: o botão que acorda o controle não age", st.current_state, BattleState.State.PLAYER_TURN)

	# Seleção inicial válida e marcada pelo anel branco
	_true("HUD: há seleção inicial", panel.nav_id() != "" and panel.nav_selected() != null)
	_true("HUD: o anel está no item selecionado",
		panel._nav_ring != null and panel._nav_ring.visible and panel._nav_ring.get_parent() == panel._nav_control(panel.nav_id()))

	# D-pad direita/esquerda andam na ordem visível; o anel acompanha
	var before: String = panel.nav_id()
	var want_right: String = HudNav.step(panel._nav_entries(), before, Vector2i(1, 0))
	await _press_joy(JOY_BUTTON_DPAD_RIGHT)
	_eq("HUD: D-pad direita move o cursor", panel.nav_id(), want_right)
	_true("HUD: anel acompanha o D-pad", panel._nav_ring.get_parent() == panel._nav_control(panel.nav_id()))
	await _press_joy(JOY_BUTTON_DPAD_LEFT)
	_eq("HUD: D-pad esquerda volta", panel.nav_id(), before)
	var want_down: String = HudNav.step(panel._nav_entries(), before, Vector2i(0, 1))
	await _press_joy(JOY_BUTTON_DPAD_DOWN)
	_eq("HUD: D-pad baixo move na vertical", panel.nav_id(), want_down)
	await _press_joy(JOY_BUTTON_DPAD_UP)

	# Teclado faz o mesmo que o D-pad
	await _press_key(KEY_RIGHT)
	_eq("HUD: seta direita equivale ao D-pad", panel.nav_id(), want_right)
	await _press_key(KEY_LEFT)

	# A executa exatamente o item sob o anel: navega até "Mover" e confirma
	var guard := 0
	while not (panel.nav_selected() is AcaoMover) and guard < 40:
		await _press_joy(JOY_BUTTON_DPAD_RIGHT)
		guard += 1
	_true("HUD: o cursor alcança a ação Mover pelo D-pad", panel.nav_selected() is AcaoMover)
	await _press_joy(JOY_BUTTON_A)
	_eq("HUD: A executa o item selecionado (Mover entra no modo de movimento)", st.current_state, BattleState.State.MOVE_MODE)
	await _press_joy(JOY_BUTTON_B)
	_eq("HUD: B cancela e volta à HUD", st.current_state, BattleState.State.PLAYER_TURN)

	# Item indisponível pode ser selecionado, mas A não o executa
	st.has_attacked = true
	scene._refresh_ui()
	var attack_id := ""
	for e in panel._nav_entries():
		var ctl: Control = panel._nav_control(e["id"])
		if ctl is ActionPanel.GridCell and (ctl as ActionPanel.GridCell).action != null \
				and (ctl as ActionPanel.GridCell).action.action_type == ActionData.Type.ATTACK:
			attack_id = e["id"]
			break
	if attack_id != "":
		panel._nav_set(attack_id)
		_eq("HUD: item indisponível é selecionável", panel.nav_id(), attack_id)
		_true("HUD: item indisponível mantém o anel", panel._nav_ring.visible)
		await _press_joy(JOY_BUTTON_A)
		_eq("HUD: A não executa item indisponível", st.current_state, BattleState.State.PLAYER_TURN)
	st.has_attacked = false
	scene._refresh_ui()

	# LB/RB trocam o filtro do grid (a "aba" da HUD) e voltam ao fim do ciclo
	_eq("HUD: começa sem filtro", [panel._filter_mode, panel._slot_filter_level], [0, 0])
	await _press_joy(JOY_BUTTON_RIGHT_SHOULDER)
	_eq("HUD: RB ativa o filtro Action", [panel._filter_mode, panel._slot_filter_level], [1, 0])
	_true("HUD: o ícone do filtro ativo ganha a borda", panel._action_dot.active)
	await _press_joy(JOY_BUTTON_RIGHT_SHOULDER)
	_eq("HUD: RB seguinte ativa o filtro Bonus", [panel._filter_mode, panel._slot_filter_level], [2, 0])
	await _press_joy(JOY_BUTTON_LEFT_SHOULDER)
	await _press_joy(JOY_BUTTON_LEFT_SHOULDER)
	_eq("HUD: LB LB volta ao início", [panel._filter_mode, panel._slot_filter_level], [0, 0])
	await _press_key(KEY_E)
	_eq("HUD: E equivale a RB", [panel._filter_mode, panel._slot_filter_level], [1, 0])
	await _press_key(KEY_Q)
	_true("HUD: o cursor continua válido após trocar de filtro", panel.nav_selected() != null)

	# Teclas 1-6 selecionam a célula de mesmo número (o do canto da célula)
	var numbered_ok := false
	for group in [panel._left_cells, panel._right_cells]:
		for c in group:
			if c.action != null and c.num_lbl.text == "1":
				numbered_ok = panel.nav_select_by_number(1) and panel.nav_selected() == c.action
	_true("HUD: tecla 1 seleciona a célula numerada 1", numbered_ok)

	# Um único indicador por vez: o anel da HUD some durante o exame e volta ao sair
	await _press_key(KEY_TAB)
	await _frames(2)
	_true("HUD: o anel da HUD some durante o exame", not panel._nav_ring.visible)
	await _press_key(KEY_ESCAPE)
	await _frames(2)
	_true("HUD: o anel da HUD volta ao sair do exame", panel._nav_ring.visible)

	# O hover do mouse não move o cursor (só o clique move; ver _test_focus_ring)
	var some_cell = panel._left_cells[0]
	for c in panel._left_cells + panel._right_cells:
		if c.action != null:
			some_cell = c
	var id_before: String = panel.nav_id()
	some_cell.mouse_entered.emit()
	_eq("HUD: o hover do mouse não move o cursor", panel.nav_id(), id_before)
	panel._nav_set("%s%d" % ["L" if some_cell.side == "left" else "R", some_cell.slot_index])   # como o clique
	_eq("HUD: o cursor está na célula escolhida", panel._nav_control(panel.nav_id()), some_cell)

	# Barra Confirmar/Voltar: ←/→ movem o foco; A aciona exatamente o botão focado
	var counts := {"confirm": 0, "cancel": 0}
	await _press_joy(JOY_BUTTON_A)   # as teclas acima devolveram o teclado: reacorda o controle
	_true("HUD: controle reativado", idev.is_gamepad())
	panel.confirm_action.connect(func() -> void: counts["confirm"] += 1)
	panel.cancel_action.connect(func() -> void: counts["cancel"] += 1)
	panel.show_action_bar("Teste", "desc", true)
	await _frames(2)
	_true("barra: Confirmar começa focado", panel._confirm_btn.has_focus())
	await _press_joy(JOY_BUTTON_DPAD_RIGHT)
	_true("barra: D-pad direita foca Voltar", panel._back_btn.has_focus())
	await _press_joy(JOY_BUTTON_DPAD_LEFT)
	_true("barra: D-pad esquerda foca Confirmar", panel._confirm_btn.has_focus())
	await _press_joy(JOY_BUTTON_DPAD_RIGHT)
	await _press_joy(JOY_BUTTON_A)
	_eq("barra: A com Voltar focado só volta", [counts["confirm"], counts["cancel"]], [0, 1])
	_true("barra: a barra fecha ao voltar", not panel._action_bar_active)
	panel.show_action_bar("Teste", "desc", true)
	await _frames(2)
	await _press_joy(JOY_BUTTON_A)
	_eq("barra: A com Confirmar focado confirma", counts["confirm"], 1)
	panel.show_action_bar("Teste", "desc", true)
	await _frames(2)
	await _press_joy(JOY_BUTTON_B)
	_eq("barra: B volta", counts["cancel"], 2)

	await _test_hud_tooltip(scene, panel, st, idev)

	scene.queue_free()
	await _frames(2)
	idev.tracker.note_key()
	idev._after_note(true)
	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	DungeonState.current_run = saved_run
	_reached.append("_test_hud_navigation")

# ── Registro de classes globais: o cache do Godot tem de bater com o que os arquivos declaram ─────
# O check de parse e a suíte resolvem nomes como `BattleArea` pelo cache global de classes
# (.godot/global_script_class_cache.cfg), que só o editor ou `--import` reconstroem. Um `class_name`
# apagado de um arquivo continua "existindo" para eles enquanto o cache estiver velho, e o erro só
# aparece quando o editor reabre ("Could not find type"). Este teste compara cache e arquivos.
func _gd_files(dir_path: String, out: Array) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for sub in d.get_directories():
		if sub.begins_with(".") or sub == "addons":
			continue
		_gd_files(dir_path.path_join(sub), out)
	for file_name in d.get_files():
		if file_name.ends_with(".gd"):
			out.append(dir_path.path_join(file_name))

func _test_class_registry() -> void:
	var files: Array = []
	_gd_files("res://", files)
	var declared: Dictionary = {}   # nome -> caminho, lido do próprio arquivo
	for path in files:
		for line in FileAccess.get_file_as_string(path).split("\n").slice(0, 12):
			if line.begins_with("class_name "):
				declared[line.get_slice(" ", 1).strip_edges()] = path
				break
	var cached: Dictionary = {}     # nome -> caminho, lido do cache global de classes
	for entry in ProjectSettings.get_global_class_list():
		cached[str(entry["class"])] = str(entry["path"])
	var missing_in_cache: Array = []
	var stale_in_cache: Array = []
	for cname in declared:
		if cached.get(cname, "") != declared[cname]:
			missing_in_cache.append("%s (%s)" % [cname, declared[cname]])
	for cname in cached:
		if declared.get(cname, "") != cached[cname]:
			stale_in_cache.append("%s (%s)" % [cname, cached[cname]])
	_true("há classes globais declaradas (o scanner achou os arquivos)", declared.size() > 40)
	_eq("toda class_name declarada num arquivo está no cache (rode `--import` se faltar)", missing_in_cache, [])
	_eq("todo item do cache ainda é declarado pelo arquivo (um class_name apagado aparece aqui)", stale_in_cache, [])
	for must in ["BattleArea", "BattleScene", "BattleState", "AreaShape", "ActionData"]:
		_true("%s declara class_name no próprio arquivo" % must, declared.has(must))
	_reached.append("_test_class_registry")

# ── Fumaça da cena de batalha: carrega, instancia com party + inimigos e roda um ciclo de turno ──
# Passa pelo mesmo caminho do jogo (`battle_scene.tscn` → `_ready` → HUD, BattleArea, BattleState).
# Qualquer erro de script na construção da cena ou num turno vira SCRIPT ERROR e derruba a suíte
# (marcador em EXPECTED_TO_FINISH). Sandbox: sem corrida ativa, nada grava save.
func _test_battle_scene_smoke() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS
	var saved_run = DungeonState.current_run
	DungeonState.current_run = null
	BattleState.setup_party(["Guerreiro", "Mago", "Arqueiro"])        # + os 7 inimigos de ALL_ENEMIES
	DiceRoller.force_next([20, 20, 20, 1, 1, 1, 1])                   # iniciativa: heróis primeiro
	var packed: PackedScene = load("res://battle/battle_scene.tscn")
	_true("a cena de batalha carrega", packed != null)
	var scene = packed.instantiate()
	root.add_child(scene)
	await _frames(3)
	DiceRoller.clear_forced()
	var waited := 0
	while waited < 1500 and (scene._animating or scene._state.current_state != BattleState.State.PLAYER_TURN):
		await process_frame
		waited += 1
	var st: BattleState = scene._state
	# Sem citar o tipo `BattleArea` aqui: o arquivo de teste é compilado antes de os autoloads existirem.
	_true("a cena montou o BattleArea", scene._battle_area != null)
	_eq("o BattleArea é o script que declara class_name BattleArea", scene._battle_area.get_script().get_global_name(), &"BattleArea")
	_true("a cena montou a HUD (turno, ações, status)", scene._turn_bar != null and scene._action_panel != null and scene._status_panel != null)
	_true("há heróis e inimigos na fila", BattleState.TURN_QUEUE.size() >= 4 and st.turn_block.size() == 3)
	_true("a batalha abre no turno dos heróis", st.current_state == BattleState.State.PLAYER_TURN and not scene._animating)
	var turns_before: int = st.battle_stats.get("turns", 0)
	# Um ciclo: cada herói do bloco encerra o PRÓPRIO turno (o 1º e o 2º só passam o controle); quando o
	# último encerra, os inimigos agem (IA, movimento, ataque, animações) e a vez volta.
	var first_hero: int = st.active_index
	scene._on_end_turn_pressed()
	_true("encerrar o 1º herói passa o controle e não avança o turno", st.active_index != first_hero \
		and st.battle_stats.get("turns", 0) == turns_before and st.current_state == BattleState.State.PLAYER_TURN)
	# Selecionar o herói que encerrou (como o clique no retrato) e cancelar o fim de turno pelo MESMO comando.
	scene._switch_hero_to(first_hero)
	_true("o herói que encerrou pode ser selecionado", st.active_index == first_hero and st.active_ended())
	_true("o botão vira 'VOLTAR' num herói que já encerrou", scene._end_turn_btn.text.contains("VOLTAR"))
	scene._on_end_turn_pressed()
	_true("o mesmo comando cancela o fim de turno e devolve o controle", st.active_index == first_hero and not st.active_ended())
	_true("o botão volta a 'FIM'", scene._end_turn_btn.text.contains("FIM") and not scene._end_turn_btn.text.contains("VOLTAR"))
	# Herói ativo cai no meio do bloco: o controle passa sozinho (a cena checa ao atualizar a HUD).
	st.combatant_statuses[first_hero]["downed"] = true
	scene._refresh_ui()
	_true("o herói Downed passa o controle sozinho", st.active_index != first_hero and st.current_state == BattleState.State.PLAYER_TURN)
	scene._on_end_turn_pressed()                       # encerra o herói que assumiu: sobra um
	_eq("ainda não avançou o turno (sobra um herói)", st.battle_stats.get("turns", 0), turns_before)
	scene._on_end_turn_pressed()                       # o último herói disponível: passa a vez
	waited = 0
	while waited < 3000 and (st.battle_stats.get("turns", 0) < turns_before + 2 or scene._animating):
		await process_frame
		waited += 1
	_true("pelo menos um ciclo de turno rodou (heróis → inimigo → próximo)", st.battle_stats.get("turns", 0) >= turns_before + 2)
	_true("a cena segue de pé depois do ciclo", is_instance_valid(scene) and scene.is_inside_tree())
	scene.queue_free()
	await _frames(2)
	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	DungeonState.current_run = saved_run
	_reached.append("_test_battle_scene_smoke")

# ── Aviso de Ataque de Oportunidade: a prévia e o movimento usam a MESMA regra, no lugar certo ────────
# Regressão: o texto "⚠ Ataque de Oportunidade!" era posicionado com coordenada de MUNDO (o mapa é
# desenhado sob zoom/pan, o Label não), então só coincidia com a casa em zoom 1 e pan 0. Cena real:
# herói adjacente a um inimigo corpo a corpo em (5,3)/(6,3).
func _oa_arena() -> Dictionary:
	DungeonState.current_run = null
	BattleState.setup_party(["Guerreiro", "Mago", "Arqueiro"])
	DiceRoller.force_next([20, 20, 20, 1, 1, 1, 1])
	var scene = load("res://battle/battle_scene.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	DiceRoller.clear_forced()
	var waited := 0
	while waited < 1500 and (scene._animating or scene._state.current_state != BattleState.State.PLAYER_TURN):
		await process_frame
		waited += 1
	var st: BattleState = scene._state
	var hero: int = st.active_index
	var foe := -1
	for i in range(BattleState.TURN_QUEUE.size()):
		st.combatant_positions[i] = Vector2i(i, 0)
		if foe < 0 and not BattleState.TURN_QUEUE[i]["is_player"]:
			foe = i
	st.combatant_positions[hero] = Vector2i(5, 3)
	st.combatant_positions[foe] = Vector2i(6, 3)
	scene._refresh_ui()
	return {"scene": scene, "st": st, "area": scene._battle_area, "hero": hero, "foe": foe}

func _wait_scene_idle(scene, frames_max: int = 3000) -> void:
	var waited := 0
	while waited < frames_max and (scene._animating or scene._reaction_pending or not scene._pending_reaction_queue.is_empty()):
		await process_frame
		waited += 1

# O texto fica sobre a casa `tile` na tela, com qualquer zoom e pan, e sempre dentro da área visível.
func _check_oa_label_tracks_tile(area, tile: Vector2i, tag: String) -> void:
	var lbl: Label = area._oa_warn_lbl
	var checked := 0
	for cfg in [[1.0, Vector2.ZERO], [1.5, Vector2(60, -40)], [0.75, Vector2(-80, 30)], [2.0, Vector2(120, 80)]]:
		area.size = Vector2(1280, 600)                  # a área em headless nasce sem altura
		area._zoom = cfg[0]
		area._pan_offset = cfg[1]
		area._place_oa_warning(tile, area._get_offset())
		var want: Vector2 = area._tile_screen_pos(tile)  # centro da casa na tela (caminho independente)
		var half_w: float = lbl.size.x * 0.5
		var top: float = want.y - lbl.size.y - 26.0
		_true("%s zoom %.2f: texto dentro da área visível" % [tag, cfg[0]], lbl.visible and lbl.position.x >= 4.0 - 0.01 \
			and lbl.position.y >= 4.0 - 0.01 and lbl.position.x + lbl.size.x <= area.size.x - 4.0 + 0.01 \
			and lbl.position.y + lbl.size.y <= area.size.y - 4.0 + 0.01)
		if want.x - half_w >= 4.0 and want.x + half_w <= area.size.x - 4.0 and top >= 4.0 and want.y <= area.size.y - 4.0:
			checked += 1
			_true("%s zoom %.2f: texto exatamente acima da casa (x)" % [tag, cfg[0]], absf(lbl.position.x + half_w - want.x) < 0.5)
			_true("%s zoom %.2f: texto exatamente acima da casa (y)" % [tag, cfg[0]], absf(lbl.position.y - top) < 0.5)
	_true("%s: ao menos 2 combinações de câmera conferidas sem corte" % tag, checked >= 2)
	area._zoom = 1.0
	area._pan_offset = Vector2.ZERO

func _test_oa_preview() -> void:
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS
	var saved_run = DungeonState.current_run

	# ── Movimento A: o destino TIRA o herói do alcance do inimigo → aviso na prévia E OA no movimento.
	var a: Dictionary = await _oa_arena()
	var sa: BattleState = a["st"]
	var area_a = a["area"]
	var hero: int = a["hero"]
	var foe: int = a["foe"]
	sa.enter_move_mode()
	var out_tile := Vector2i(3, 3)
	sa.cursor_tile = out_tile
	area_a.queue_redraw()
	await _frames(3)
	var rule_a := sa.check_opportunity_attacks_along(hero, sa.combatant_positions[hero], sa.get_path_to(out_tile))
	_true("regra: sair do alcance do corpo a corpo provoca o inimigo", rule_a.has(foe))
	_true("prévia: a casa laranja e o texto aparecem quando a regra diz OA", area_a._oa_warn_lbl.visible)
	_check_oa_label_tracks_tile(area_a, out_tile, "movimento")
	_true("o cursor é aceito", sa.apply_cursor_selection())
	a["scene"]._execute_confirm_move()
	await _wait_scene_idle(a["scene"])
	_true("execução: o OA aconteceu (o que a prévia avisou)", str(sa.combat_log).contains("Ataque de Oportunidade"))
	_true("execução: o inimigo gastou a reação no OA", sa.combatant_statuses[foe].get("reaction_used", false))
	a["scene"].queue_free()
	await _frames(2)

	# ── Movimento B: o destino CONTINUA no alcance → sem aviso e sem OA.
	var b: Dictionary = await _oa_arena()
	var sb: BattleState = b["st"]
	sb.enter_move_mode()
	var stay_tile := Vector2i(5, 4)                     # adjacente ao inimigo em (6,3)
	sb.cursor_tile = stay_tile
	b["area"].queue_redraw()
	await _frames(3)
	var rule_b := sb.check_opportunity_attacks_along(b["hero"], sb.combatant_positions[b["hero"]], sb.get_path_to(stay_tile))
	_true("regra: ficar no alcance não provoca", rule_b.is_empty())
	_true("prévia: sem aviso quando a regra não manda", not b["area"]._oa_warn_lbl.visible)
	sb.apply_cursor_selection()
	b["scene"]._execute_confirm_move()
	await _wait_scene_idle(b["scene"])
	_true("execução: sem OA (o que a prévia não avisou)", not str(sb.combat_log).contains("Ataque de Oportunidade"))
	b["scene"].queue_free()
	await _frames(2)

	# ── Pulo: a prévia usa a mesma regra e o mesmo posicionamento; executar dispara o OA.
	var j: Dictionary = await _oa_arena()
	var sj: BattleState = j["st"]
	j["scene"]._execute_action(AcaoPular.new())
	_eq("a mira do Pulo está ativa", sj.current_state, BattleState.State.ATTACK_MODE)
	var land_out := Vector2i(2, 3)                      # a 3 casas: sai do alcance do inimigo
	_true("o pouso é válido", sj.is_valid_jump_landing(j["hero"], land_out))
	sj.cursor_tile = land_out
	j["area"].queue_redraw()
	await _frames(3)
	_true("prévia do Pulo: aviso de OA visível", j["area"]._oa_warn_lbl.visible)
	_check_oa_label_tracks_tile(j["area"], land_out, "pulo")
	var land_stay := Vector2i(6, 4)                     # adjacente ao inimigo em (6,3): não provoca
	_true("o 2º pouso é válido", sj.is_valid_jump_landing(j["hero"], land_stay))
	sj.cursor_tile = land_stay
	j["area"].queue_redraw()
	await _frames(3)
	_true("prévia do Pulo: sem aviso quando continua no alcance", not j["area"]._oa_warn_lbl.visible)
	sj.cursor_tile = land_out
	_true("o cursor do Pulo é aceito", sj.apply_cursor_selection())
	j["scene"]._execute_confirm_attack()
	await _wait_scene_idle(j["scene"])
	_true("execução do Pulo: o OA aconteceu", str(sj.combat_log).contains("Ataque de Oportunidade"))
	j["scene"].queue_free()
	await _frames(2)

	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	DungeonState.current_run = saved_run
	_reached.append("_test_oa_preview")

# ── Anel de seleção (FocusGlow): só com teclado/controle; o mouse o oculta em todas as telas ──────────
func _test_focus_ring() -> void:
	# 1) Rastreador (lógica pura): o último input decide se o mouse está "ativo".
	var trk := InputDeviceTracker.new()
	_true("anel: começa sem mouse ativo", not trk.pointer_active)
	trk.note_mouse_motion(Vector2(0.1, 0.0))
	_true("anel: tremor sub-pixel do mouse não conta", not trk.pointer_active)
	trk.note_mouse_motion(Vector2(5, 0))
	_true("anel: mover o mouse ativa o mouse", trk.pointer_active)
	trk.note_key()
	_true("anel: tecla devolve o anel", not trk.pointer_active)
	trk.note_mouse_button()
	_true("anel: clique ativa o mouse", trk.pointer_active)
	trk.note_joy_button(0)
	_true("anel: botão do controle devolve o anel", not trk.pointer_active)
	trk.note_mouse_button()
	trk.note_joy_axis(0, 0.1)
	_true("anel: drift do analógico não devolve o anel", trk.pointer_active)
	trk.note_joy_axis(0, 0.9)
	_true("anel: empurrão do analógico devolve o anel", not trk.pointer_active)

	# 2) Anéis reais: o alfa segue o autoload; o marcador de exame (follows_device=false) não some.
	var idev: Node = root.get_node("InputDevice")
	var saved_pointer: bool = idev.tracker.pointer_active
	var holder := Control.new()
	var ring: Panel = FocusGlow.make_ring()
	var examine: Panel = FocusGlow.make_ring(false)
	holder.add_child(ring)
	holder.add_child(examine)
	root.add_child(holder)
	idev.tracker.pointer_active = true
	await _frames(2)
	_eq("anel: oculto (alfa 0) com o mouse", ring.modulate.a, 0.0)
	_eq("anel: o marcador de exame continua visível com o mouse", examine.modulate.a, 1.0)
	idev.tracker.pointer_active = false
	await _frames(2)
	_eq("anel: volta (alfa 1) com teclado/controle", ring.modulate.a, 1.0)
	holder.queue_free()

	# 3) Seleção de grupo: o clique move o cursor para o card clicado e o anel acompanha.
	var ps = load("res://ui/party_select.tscn").instantiate()
	root.add_child(ps)
	await _frames(2)
	_eq("grupo: o cursor começa no 1º card", ps._cursor, 0)
	var target_name: String = ps._hero_names[2]
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ps._cards[target_name].gui_input.emit(ev)
	_eq("grupo: o clique move o cursor para o card clicado", ps._hero_names[ps._cursor], target_name)
	_true("grupo: o anel está no card clicado", ps._sel_ring.get_parent() == ps._cards[target_name])
	_true("grupo: o card clicado foi selecionado", ps._selected[target_name])
	ps._set_area(1)
	ps._cards[target_name].gui_input.emit(ev)
	_eq("grupo: clicar um card volta o cursor para a área dos cards", ps._area, 0)
	idev.tracker.pointer_active = true
	await _frames(2)
	_eq("grupo: o anel some com o mouse", ps._sel_ring.modulate.a, 0.0)
	idev.tracker.pointer_active = false
	ps.queue_free()

	# 4) HUD de combate: hover não move o cursor, clique move, trocar de herói volta ao 1º item.
	var saved_tq: Array = BattleState.TURN_QUEUE
	var saved_pl: Array = BattleState.PLAYERS
	var saved_run = DungeonState.current_run
	DungeonState.current_run = null
	BattleState.setup_party(["Guerreiro", "Mago", "Clérigo"])
	DiceRoller.force_next([20, 20, 20, 1, 1, 1, 1])
	var scene = load("res://battle/battle_scene.tscn").instantiate()
	root.add_child(scene)
	await _frames(3)
	DiceRoller.clear_forced()
	var waited := 0
	while waited < 1500 and (scene._animating or scene._state.current_state != BattleState.State.PLAYER_TURN):
		await process_frame
		waited += 1
	var st: BattleState = scene._state
	var panel = scene._action_panel
	var cells: Array = []
	for e in panel._nav_entries():
		var ctl: Control = panel._nav_control(e["id"])
		if ctl is ActionPanel.GridCell:
			cells.append([e["id"], ctl])
	_true("HUD: há ao menos duas células de ação", cells.size() >= 2)
	var first_id: String = HudNav.step(panel._nav_entries(), "", Vector2i.ZERO)
	_eq("HUD: o cursor começa no 1º item", panel.nav_id(), first_id)
	var last_id: String = cells[cells.size() - 1][0]
	(cells[cells.size() - 1][1] as Control).mouse_entered.emit()
	_eq("HUD: o hover não move o cursor", panel.nav_id(), first_id)
	for c in panel.grid_action_clicked.get_connections():
		panel.grid_action_clicked.disconnect(c["callable"])   # o clique não deve acionar a ação aqui
	var up := InputEventMouseButton.new()
	up.button_index = MOUSE_BUTTON_LEFT
	up.pressed = false
	(cells[cells.size() - 1][1] as ActionPanel.GridCell)._gui_input(up)
	_eq("HUD: o clique move o cursor para o item clicado", panel.nav_id(), last_id)
	idev.tracker.pointer_active = true
	await _frames(2)
	_eq("HUD: o anel some com o mouse (mesmo parado no item)", panel._nav_ring.modulate.a, 0.0)
	idev.tracker.pointer_active = false
	await _frames(2)
	_eq("HUD: o anel volta no último item clicado", [panel._nav_ring.modulate.a, panel._nav_ring.get_parent() == panel._nav_control(last_id)], [1.0, true])
	var other := -1
	for m in st.switchable_members():
		if m != st.active_index:
			other = m
			break
	_true("HUD: há outro herói para trocar", other != -1)
	if other != -1:
		scene._switch_hero_to(other)
		_eq("HUD: a troca de herói leva o cursor ao 1º item", panel.nav_id(), first_id)
	idev.tracker.pointer_active = saved_pointer
	scene.queue_free()
	await _frames(2)
	BattleState.TURN_QUEUE = saved_tq
	BattleState.PLAYERS = saved_pl
	DungeonState.current_run = saved_run
	_reached.append("_test_focus_ring")

# Painel de detalhes (nome, descrição, dano, alcance, custo) na navegação por controle: o mesmo
# ActionTooltipPanel do hover do mouse, junto ao item sob o anel.
func _test_hud_tooltip(scene, panel, st: BattleState, idev: Node) -> void:
	var tip = scene._action_tooltip
	var wait := ActionTooltipPanel.HOVER_DELAY + 0.25
	await _press_joy(JOY_BUTTON_LEFT_STICK)   # acorda o controle sem acionar nada
	_true("painel: controle ativo", idev.is_gamepad())
	_eq("painel: nada aberto no início", st.current_state, BattleState.State.PLAYER_TURN)
	tip.hide_tooltip()

	var tip_nodes := 0
	for c in scene.get_children():
		if c is ActionTooltipPanel:
			tip_nodes += 1
	_eq("painel: existe um único painel de detalhes", tip_nodes, 1)

	# Aparece após o mesmo atraso do mouse, com o nome do item selecionado
	panel.nav_move(Vector2i(1, 0))   # direto: a checagem do atraso não pode depender de frames
	_true("painel: agendado, mas não aparece antes do atraso", not tip.visible and tip._pending_subject != null)
	await create_timer(wait).timeout
	var sel = panel.nav_selected()
	_true("painel: aparece após o atraso", tip.visible)
	_eq("painel: mostra o nome do item selecionado", tip._name_lbl.text, sel.label)
	var anchor: Rect2 = panel._nav_control(panel.nav_id()).get_global_rect()
	# (A viewport do headless é minúscula; a geometria em si é coberta pelos testes de place().)
	_eq("painel: posicionado junto ao item selecionado (place)", tip.position,
		ActionTooltipPanel.place(anchor, tip.size, scene.get_viewport_rect().size))

	# Atualiza na hora ao mover a seleção (sem novo atraso)
	var before_name: String = tip._name_lbl.text
	await _press_joy(JOY_BUTTON_DPAD_RIGHT)
	sel = panel.nav_selected()
	_eq("painel: acompanha a seleção imediatamente", tip._name_lbl.text, sel.label)
	_true("painel: o item mudou de fato", sel.label != before_name)

	# Itens consumíveis (Dictionary) também mostram o painel
	var guard := 0
	while not panel.nav_id().begins_with("I") and guard < 8:
		await _press_joy(JOY_BUTTON_DPAD_DOWN)
		guard += 1
	_true("painel: o cursor alcança a barra de itens", panel.nav_id().begins_with("I"))
	await create_timer(wait).timeout
	var item_sel: Dictionary = panel.nav_selected()
	_true("painel: item mostra o painel", tip.visible)
	_eq("painel: item mostra o nome", tip._name_lbl.text, item_sel["label"])
	_true("painel: item mostra o efeito", tip._desc_lbl.text.begins_with("Restaura 2d4+2"))
	_true("painel: item mostra a quantidade", tip._cost_lbl.text.begins_with("Quantidade"))
	_true("painel: item não mostra dano", not tip._damage_lbl.visible)

	# Mouse: o hover de um item (Dictionary) também funciona e não duplica o painel
	# (o item é o 0: a Poção; o Éter, que era o 1, foi removido na D7)
	tip.hide_tooltip()
	panel.grid_action_hovered.emit(panel._item_cells[0]["item"])
	await create_timer(wait).timeout
	_true("mouse: hover de item mostra o painel", tip.visible)
	_eq("mouse: hover mostra o item sob o mouse", tip._name_lbl.text, panel._item_cells[0]["item"]["label"])
	panel.grid_action_hovered.emit(null)
	_true("mouse: sair do item esconde o painel", not tip.visible)

	# Some ao confirmar e ao entrar em outro modo; volta ao retornar à HUD (controle)
	var mover_id := ""
	for e in panel._nav_entries():
		var ctl: Control = panel._nav_control(e["id"])
		if ctl is ActionPanel.GridCell and (ctl as ActionPanel.GridCell).action is AcaoMover:
			mover_id = e["id"]
	panel._nav_set(mover_id)
	panel.announce_selection()
	await create_timer(wait).timeout
	_true("painel: aberto sobre Mover", tip.visible and tip._name_lbl.text == "Mover")
	await _press_joy(JOY_BUTTON_A)
	_eq("painel: A entra no modo de movimento", st.current_state, BattleState.State.MOVE_MODE)
	_true("painel: some ao confirmar e entrar em outro modo", not tip.visible)
	await _press_joy(JOY_BUTTON_B)
	await create_timer(wait).timeout
	_eq("painel: B volta à HUD", st.current_state, BattleState.State.PLAYER_TURN)
	_true("painel: no controle, reaparece ao voltar à HUD", tip.visible and tip._name_lbl.text == "Mover")

	# Some ao examinar e ao pausar
	await _press_joy(JOY_BUTTON_Y)
	_true("painel: some ao entrar no exame", not tip.visible)
	await _press_joy(JOY_BUTTON_B)
	await create_timer(wait).timeout
	_true("painel: reaparece ao sair do exame", tip.visible)
	await _press_joy(JOY_BUTTON_START)
	_true("painel: some ao pausar", not tip.visible)
	await _press_joy(JOY_BUTTON_B)
	await create_timer(0.4).timeout
	await _frames(3)

func _write_save_text(text: String, path: String = DungeonState.SAVE_PATH) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

# "absent", ou hash + data de modificação. Só leitura.
func _fingerprint(path: String) -> String:
	if not FileAccess.file_exists(path):
		return "absent"
	return FileAccess.get_sha256(path) + "@" + str(FileAccess.get_modified_time(path))

func _missing_markers(expected: Array, reached: Array) -> Array:
	return expected.filter(func(n: String) -> bool: return not reached.has(n))

func _check_completion() -> void:
	for name in _missing_markers(EXPECTED_TO_FINISH, _reached):
		_eq("conclusão: %s chegou ao fim (um erro de runtime a abortou)" % name, false, true)
	_eq("conclusão: todas as funções de teste chegaram ao fim", _missing_markers(EXPECTED_TO_FINISH, _reached), [])
	_eq("conclusão: detecta marcador ausente", _missing_markers(["a", "b"], ["a"]), ["b"])

func _check_save_isolation(player_path: String, before: String) -> void:
	_true("isolamento: a suíte usa a pasta própria, não o save do jogador",
		DungeonState.SAVE_PATH.begins_with(TEST_SAVE_DIR + "/") and DungeonState.SAVE_PATH != player_path)
	_eq("isolamento: o save do jogador não foi criado, alterado nem apagado pela suíte",
		_fingerprint(player_path), before)

func _clear_save_sandbox() -> void:
	for fname in DirAccess.get_files_at(TEST_SAVE_DIR):
		DirAccess.remove_absolute(TEST_SAVE_DIR + "/" + fname)
	DirAccess.remove_absolute(TEST_SAVE_DIR)

# Concatena o texto de todos os Labels descendentes (para checar painéis de UI).
func _labels_text(node: Node) -> String:
	var out := ""
	for c in node.get_children():
		if c is Label:
			out += (c as Label).text + "|"
		out += _labels_text(c)
	return out
