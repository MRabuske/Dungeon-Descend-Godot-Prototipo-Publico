# Enemy AI, Status Effects & Defender Action — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir o keyword-parsing de strings na IA inimiga por behaviors tipados, dar personalidade única a cada inimigo, e implementar efeitos de status reais (stunned já funciona; adicionar defending, raging, aiming) e a ação Defender do herói.

**Architecture:** `EnemyData` ganha `action_behaviors: Array[Dictionary]` paralelo ao `action_pool`. `BattleState` usa um novo `active_enemy_action_idx` para referenciar o behavior dict ativo em vez de keyword-parse da string. Os status effects já usam `combatant_statuses[idx]: Dictionary` com chaves como `"stun"` e `"poison"` — os novos status (`defending`, `raging`, `aiming`) seguem o mesmo padrão.

**Tech Stack:** GDScript 4.6, Godot 4.6. Sem editor ativo — todo código é code-only. Testes via `godot --headless --script tests/run_tests.gd`.

**IMPORTANTE:** O editor Godot não está ativo. Não tente abrir o editor para testar. Use apenas o runner headless.

---

### Task 1: EnemyData — campo action_behaviors + popular nos 4 inimigos

**Files:**
- Modify: `enemies/enemy_data.gd`
- Modify: `enemies/goblin_scout.gd`
- Modify: `enemies/orc_warrior.gd`
- Modify: `enemies/dark_mage.gd`
- Modify: `enemies/skeleton_archer.gd`
- Test: `tests/run_tests.gd`

- [ ] **Step 1: Adicionar campo action_behaviors em enemy_data.gd**

O arquivo atual tem apenas os campos `enemy_name`, `enemy_type`, `ac`, `max_hp`, `speed`, `attack_bonus`, `action_pool`. Adicione logo após `action_pool`:

```gdscript
# enemies/enemy_data.gd — linha após @export var action_pool
@export var action_behaviors: Array[Dictionary] = []
```

Arquivo completo resultante:
```gdscript
class_name EnemyData
extends Resource

@export var enemy_name: String = ""
@export var enemy_type: String = ""
@export_group("Stats")
@export var ac: int = 10
@export var max_hp: int = 30
@export var speed: int = 5
@export var attack_bonus: int = 2
@export_group("Actions")
@export var action_pool: Array[String] = []
@export var action_behaviors: Array[Dictionary] = []
```

- [ ] **Step 2: Popular action_behaviors no GoblinScout**

Cada dict corresponde ao mesmo índice no `action_pool`. Chaves: `range` (int), `damage_mult` (float), `aoe_radius` (int), `is_self_buff` (bool), `is_flee` (bool), `applies_status` (String), `status_chance` (float), `buff_type` (String), `buff_value` (int), `buff_turns` (int).

```gdscript
# enemies/goblin_scout.gd — arquivo completo
class_name GoblinScoutData
extends EnemyData

func _init() -> void:
	enemy_name   = "Goblin Scout"
	enemy_type   = "Goblin"
	ac           = 13
	max_hp       = 20
	speed        = 6
	attack_bonus = 2
	action_pool = [
		"Attacking %s...",
		"Attacking %s...",
		"Throwing a dagger at %s...",
		"Throwing a dagger at %s...",
		"Fleeing!",
	]
	action_behaviors = [
		{"range": 1, "damage_mult": 1.0,  "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",        "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.0,  "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",        "buff_value": 0, "buff_turns": 0},
		{"range": 3, "damage_mult": 0.85, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",        "buff_value": 0, "buff_turns": 0},
		{"range": 3, "damage_mult": 0.85, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",        "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0,  "aoe_radius": 0, "is_self_buff": false, "is_flee": true,  "applies_status": "",        "status_chance": 0.0, "buff_type": "",        "buff_value": 0, "buff_turns": 0},
	]
```

- [ ] **Step 3: Popular action_behaviors no OrcWarrior**

```gdscript
# enemies/orc_warrior.gd — arquivo completo
class_name OrcWarriorData
extends EnemyData

func _init() -> void:
	enemy_name   = "Orc Warrior"
	enemy_type   = "Orc"
	ac           = 15
	max_hp       = 40
	speed        = 4
	attack_bonus = 4
	action_pool = [
		"Smashing %s...",
		"Smashing %s...",
		"Charging at %s...",
		"Charging at %s...",
		"Raging!",
	]
	action_behaviors = [
		{"range": 1, "damage_mult": 1.2, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 1.2, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 2, "damage_mult": 1.5, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.2, "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 2, "damage_mult": 1.5, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.2, "buff_type": "",      "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "raging", "buff_value": 3, "buff_turns": 2},
	]
```

- [ ] **Step 4: Popular action_behaviors no DarkMage**

```gdscript
# enemies/dark_mage.gd — arquivo completo
class_name DarkMageData
extends EnemyData

func _init() -> void:
	enemy_name   = "Dark Mage"
	enemy_type   = "Mage"
	ac           = 11
	max_hp       = 25
	speed        = 5
	attack_bonus = 5
	action_pool = [
		"Casting Shadow Bolt at %s...",
		"Casting Shadow Bolt at %s...",
		"Casting Frost Nova!",
		"Casting Frost Nova!",
		"Teleporting...",
	]
	action_behaviors = [
		{"range": 5, "damage_mult": 1.2, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",           "buff_value": 0, "buff_turns": 0},
		{"range": 5, "damage_mult": 1.2, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "",           "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 0.8, "aoe_radius": 1, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.4, "buff_type": "",           "buff_value": 0, "buff_turns": 0},
		{"range": 1, "damage_mult": 0.8, "aoe_radius": 1, "is_self_buff": false, "is_flee": false, "applies_status": "stunned", "status_chance": 0.4, "buff_type": "",           "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "",        "status_chance": 0.0, "buff_type": "teleporting", "buff_value": 0, "buff_turns": 0},
	]
```

- [ ] **Step 5: Popular action_behaviors no SkeletonArcher**

```gdscript
# enemies/skeleton_archer.gd — arquivo completo
class_name SkeletonArcherData
extends EnemyData

func _init() -> void:
	enemy_name   = "Skeleton Archer"
	enemy_type   = "Undead"
	ac           = 12
	max_hp       = 30
	speed        = 5
	attack_bonus = 3
	action_pool = [
		"Shooting an arrow at %s...",
		"Shooting an arrow at %s...",
		"Aiming at %s...",
		"Aiming at %s...",
		"Rattling bones...",
	]
	action_behaviors = [
		{"range": 5, "damage_mult": 1.0, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "", "status_chance": 0.0, "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 5, "damage_mult": 1.0, "aoe_radius": 0, "is_self_buff": false, "is_flee": false, "applies_status": "", "status_chance": 0.0, "buff_type": "",       "buff_value": 0, "buff_turns": 0},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "", "status_chance": 0.0, "buff_type": "aiming", "buff_value": 2, "buff_turns": 1},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "", "status_chance": 0.0, "buff_type": "aiming", "buff_value": 2, "buff_turns": 1},
		{"range": 0, "damage_mult": 0.0, "aoe_radius": 0, "is_self_buff": true,  "is_flee": false, "applies_status": "", "status_chance": 0.0, "buff_type": "rattling","buff_value": 0, "buff_turns": 0},
	]
```

- [ ] **Step 6: Escrever testes para action_behaviors**

Adicione ao final da função `_run_all()` em `tests/run_tests.gd`:

```gdscript
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
```

- [ ] **Step 7: Rodar testes**

```
godot --headless --script tests/run_tests.gd
```

Esperado: todos os novos testes PASS.

- [ ] **Step 8: Commit**

```
git add enemies/enemy_data.gd enemies/goblin_scout.gd enemies/orc_warrior.gd enemies/dark_mage.gd enemies/skeleton_archer.gd tests/run_tests.gd
git commit -m "feat: add action_behaviors to EnemyData and populate all 4 enemies"
```

---

### Task 2: BattleState — active_enemy_action_idx + _get_active_behavior() + substituir keyword-parsing

**Files:**
- Modify: `battle/battle_state.gd` (campos de instância ~linha 107–128, funções `_enemy_action_range` e `_enemy_action_is_self` ~linhas 446–460)

- [ ] **Step 1: Adicionar campo active_enemy_action_idx**

No bloco de campos de instância (após `var enemy_action_text: String = ""`, que está na linha ~111), adicione:

```gdscript
var active_enemy_action_idx: int = 0
```

O bloco resultante deve ficar:
```gdscript
var current_state:             State     = State.PLAYER_TURN
var active_index:              int       = 0
var active_tab:                int       = 0
var cursor_position:           int       = 0
var enemy_action_text:         String    = ""
var active_enemy_action_idx:   int       = 0   # ← NOVO
var has_moved:                 bool      = false
# ... resto dos campos ...
```

- [ ] **Step 2: Adicionar _get_active_behavior() logo antes de _enemy_action_range()**

Localize `func _enemy_action_range() -> int:` (~linha 446) e insira a nova função ANTES dela:

```gdscript
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
```

- [ ] **Step 3: Substituir corpo de _enemy_action_range()**

Substitua o corpo completo de `_enemy_action_range()` (atualmente faz keyword-parsing):

```gdscript
func _enemy_action_range() -> int:
	return _get_active_behavior().get("range", 1)
```

- [ ] **Step 4: Substituir corpo de _enemy_action_is_self()**

Substitua o corpo completo de `_enemy_action_is_self()`:

```gdscript
func _enemy_action_is_self() -> bool:
	var b := _get_active_behavior()
	return b.get("is_self_buff", false)
```

- [ ] **Step 5: Rodar testes para confirmar que nada quebrou**

```
godot --headless --script tests/run_tests.gd
```

Esperado: todos os testes anteriores ainda PASS (o comportamento de range e is_self ainda é usado pela lógica de movimento — que agora lê do behavior dict).

- [ ] **Step 6: Commit**

```
git add battle/battle_state.gd
git commit -m "feat: replace enemy keyword-parsing with behavior dict lookup"
```

---

### Task 3: BattleState — IA com personalidade por inimigo

**Files:**
- Modify: `battle/battle_state.gd` (função `_roll_enemy_action` ~linha 1031, adicionar novas funções após ela)
- Test: `tests/run_tests.gd`

- [ ] **Step 1: Adicionar _closest_hero_distance() e _pick_enemy_action_idx()**

Após a função `_roll_enemy_action()` (que termina ~linha 1040), adicione:

```gdscript
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

	return randi() % 2  # fallback: ataque normal (índices 0 ou 1)
```

- [ ] **Step 2: Atualizar _roll_enemy_action() para usar _pick_enemy_action_idx()**

Substitua o corpo completo de `_roll_enemy_action()`:

```gdscript
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
```

- [ ] **Step 3: Escrever testes para _pick_enemy_action_idx()**

Adicione ao final de `_run_all()` em `tests/run_tests.gd`:

```gdscript
	# Task 3: AI personality
	# Goblin com HP baixo deve escolher Fleeing (idx 4)
	var s2 := BattleState.new()
	# active_index 1 é o Goblin Scout no TURN_QUEUE padrão
	s2.active_index = 1
	s2.enemy_hp["Goblin Scout"] = 1  # HP crítico (< 40% de 20)
	# combatant_positions precisa ter tamanho correto
	s2.combatant_positions.resize(BattleState.TURN_QUEUE.size())
	for i in range(BattleState.TURN_QUEUE.size()):
		s2.combatant_positions[i] = Vector2i(i, 0)
	_eq("goblin picks Fleeing when HP < 40%", s2._pick_enemy_action_idx(), 4)

	# Orc com HP normal deve escolher ataque (0 ou 1)
	var s3 := BattleState.new()
	s3.active_index = 4  # Orc Warrior no TURN_QUEUE padrão (índice 4)
	s3.enemy_hp["Orc Warrior"] = 40  # HP cheio
	s3.combatant_positions.resize(BattleState.TURN_QUEUE.size())
	for i in range(BattleState.TURN_QUEUE.size()):
		s3.combatant_positions[i] = Vector2i(i, 0)
	var orc_action := s3._pick_enemy_action_idx()
	_true("orc with full HP picks normal attack (0 or 1)", orc_action == 0 or orc_action == 1)
```

- [ ] **Step 4: Rodar testes**

```
godot --headless --script tests/run_tests.gd
```

Esperado: novos testes PASS.

- [ ] **Step 5: Commit**

```
git add battle/battle_state.gd tests/run_tests.gd
git commit -m "feat: add enemy personality AI with per-type decision logic"
```

---

### Task 4: BattleState — apply_enemy_attack() com damage_mult, AoE e self-buffs

**Files:**
- Modify: `battle/battle_state.gd` (funções `apply_enemy_attack` ~linha 606, adicionar `_apply_enemy_self_buff`, `_teleport_enemy`, `_apply_enemy_aoe_attack`)

- [ ] **Step 1: Adicionar _teleport_enemy()**

Adicione após `_apply_enemy_self_buff` (ambas são funções novas, coloque-as após `_pick_enemy_action_idx`):

```gdscript
func _teleport_enemy() -> void:
	var best_pos  := combatant_positions[active_index]
	var best_dist := 0
	for x in range(grid_cols):
		for y in range(grid_rows):
			var pos := Vector2i(x, y)
			var t: int = tile_map[x][y]
			if t == MapGenerator.TileType.VOID or t == MapGenerator.TileType.OBSTACLE:
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
```

- [ ] **Step 2: Adicionar _apply_enemy_self_buff()**

```gdscript
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
```

- [ ] **Step 3: Adicionar _apply_enemy_aoe_attack()**

AoE do Dark Mage: dano a todos os heróis no raio ao redor do CASTER (não do alvo). Retorna o dict de resultado que `battle_scene` usa para animar.

```gdscript
func _apply_enemy_aoe_attack(b: Dictionary) -> Dictionary:
	var origin: Vector2i  = combatant_positions[active_index]
	var radius: int       = b.get("aoe_radius", 1)
	var damage_mult: float = b.get("damage_mult", 1.0)
	var enemy_type: String = get_active_combatant().get("type", "")
	var edata_a    := ALL_ENEMIES.get(enemy_type, null) as EnemyData
	var atk_bonus: int = edata_a.attack_bonus if edata_a != null else 2
	var first_target: Vector2i = Vector2i(-1, -1)
	var total_damage := 0
	for i in range(TURN_QUEUE.size()):
		if not TURN_QUEUE[i]["is_player"] or dead_indices.has(i):
			continue
		var dist := absi(combatant_positions[i].x - origin.x) + absi(combatant_positions[i].y - origin.y)
		if dist > radius:
			continue
		var damage: int  = maxi(1, int(randi_range(5, 12) * damage_mult) + atk_bonus)
		var tname: String = TURN_QUEUE[i]["name"]
		var pidx: int    = _player_index_by_name(tname)
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
```

- [ ] **Step 4: Substituir apply_enemy_attack() completo**

Substitua a função inteira (da linha `func apply_enemy_attack() -> Dictionary:` até o `return {...}` final, inclusive):

```gdscript
func apply_enemy_attack() -> Dictionary:
	var b := _get_active_behavior()

	if b.get("is_flee", false):
		return {"target": Vector2i(-1, -1)}

	if b.get("is_self_buff", false):
		_apply_enemy_self_buff(b)
		return {"target": Vector2i(-1, -1)}

	if b.get("aoe_radius", 0) > 0:
		return _apply_enemy_aoe_attack(b)

	var attack_range := b.get("range", 1)
	var my_status: Dictionary = combatant_statuses[active_index]
	if my_status.get("aiming", 0) > 0:
		attack_range += 2  # aiming sempre concede +2 de range
	if attack_range > 1 and _tile_at(active_index) == MapGenerator.TileType.ELEVATED:
		attack_range += 1

	var origin: Vector2i = combatant_positions[active_index]
	var target_idx := -1
	var best_hp    := 99999
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"] and not dead_indices.has(i):
			var d: int = absi(combatant_positions[i].x - origin.x) + absi(combatant_positions[i].y - origin.y)
			if d <= attack_range:
				if attack_range == 1 or _has_los(origin, combatant_positions[i]):
					var pidx: int = _player_index_by_name(TURN_QUEUE[i]["name"])
					var phpi: int = PLAYERS[pidx]["hp"] if pidx >= 0 else 99999
					if phpi < best_hp:
						best_hp   = phpi
						target_idx = i
	if target_idx == -1:
		return {"target": Vector2i(-1, -1)}

	var target_tile: int = _tile_at(target_idx)
	var is_aiming: bool  = my_status.get("aiming", 0) > 0
	if is_aiming:
		my_status.erase("aiming")  # consome o buff de mira

	# miss: cobertura (30%) ou defesa ativa (40%)
	var target_status: Dictionary = combatant_statuses[target_idx]
	if target_tile == MapGenerator.TileType.COVER and not is_aiming and randf() < 0.30:
		last_attack_info = {"amount": 0, "is_heal": false, "target_idx": target_idx}
		context_message = "%s attacked %s but missed! (COVER)" % [get_active_combatant()["name"], TURN_QUEUE[target_idx]["name"]]
		_log("%s atacou %s mas errou (Cobertura)" % [get_active_combatant()["name"], TURN_QUEUE[target_idx]["name"]], "miss")
		return {"target": combatant_positions[target_idx], "is_ranged": attack_range > 1, "color": _get_enemy_projectile_color()}
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
	var pidx: int           = _player_index_by_name(target_name)
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
```

- [ ] **Step 5: Rodar testes**

```
godot --headless --script tests/run_tests.gd
```

Esperado: todos os testes PASS.

- [ ] **Step 6: Commit**

```
git add battle/battle_state.gd
git commit -m "feat: enemy attacks use damage_mult, AoE, status effects and self-buffs"
```

---

### Task 5: BattleState — buff decrements em advance_turn() + apply_defender_action()

**Files:**
- Modify: `battle/battle_state.gd` (função `advance_turn` ~linha 257, função `get_active_status_text` ~linha 985)
- Test: `tests/run_tests.gd`

- [ ] **Step 1: Adicionar decrement de buffs ao final de advance_turn()**

No final de `advance_turn()`, logo ANTES de `active_index = next` (que está na linha ~303), adicione o bloco de decrement de buffs persistentes:

```gdscript
	# Decrementar buffs que duram N turnos do próprio combatente
	var next_status: Dictionary = combatant_statuses[next]
	if next_status.get("defending", 0) > 0:
		next_status["defending"] -= 1
	if next_status.get("raging", 0) > 0:
		next_status["raging"] -= 1
	if next_status.get("aiming", 0) > 0:
		next_status["aiming"] -= 1
	active_index = next   # esta linha já existia
```

O contexto em `advance_turn()` após a while loop é:
```gdscript
	# ... while loop ends with break ...
	# ← INSIRA O BLOCO ACIMA AQUI
	active_index = next    # ← linha já existente, não duplique
	active_tab = 0
	cursor_position = 0
	has_moved = false
```

- [ ] **Step 2: Adicionar apply_defender_action()**

Adicione após `apply_enemy_move()` (ou em qualquer lugar conveniente, antes de `_log()`):

```gdscript
func apply_defender_action(player_idx: int) -> void:
	if player_idx < 0 or player_idx >= PLAYERS.size():
		return
	var pname: String = PLAYERS[player_idx]["name"]
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"] and TURN_QUEUE[i]["name"] == pname:
			combatant_statuses[i]["defending"] = 1
			break
	_log("%s está se defendendo (+2 AC)" % pname, "status")
```

- [ ] **Step 3: Atualizar get_active_status_text() para incluir novos status**

Substitua o corpo completo de `get_active_status_text()`:

```gdscript
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
	return "  ".join(parts)
```

- [ ] **Step 4: Escrever testes para apply_defender_action e buff decrement**

Adicione ao final de `_run_all()`:

```gdscript
	# Task 5: defending status
	var s4 := BattleState.new()
	s4.apply_defender_action(0)  # Guerreiro é PLAYERS[0] e TURN_QUEUE[0]
	_true("apply_defender_action sets defending on turn queue index 0",
		  s4.combatant_statuses[0].get("defending", 0) > 0)
	_eq("get_active_status_text returns Defender string",
		s4.get_active_status_text(0), "Defender +2 AC")
```

- [ ] **Step 5: Rodar testes**

```
godot --headless --script tests/run_tests.gd
```

Esperado: todos PASS.

- [ ] **Step 6: Commit**

```
git add battle/battle_state.gd tests/run_tests.gd
git commit -m "feat: add defending/raging/aiming buff decrements and apply_defender_action"
```

---

### Task 6: BattleScene — conectar ação Defender

**Files:**
- Modify: `battle/battle_scene.gd` (~linha 204, case `ActionData.Type.END_TURN`)

- [ ] **Step 1: Detectar AcaoDefender no case END_TURN**

No arquivo `battle/battle_scene.gd`, localize o trecho (linhas ~204–206):

```gdscript
			ActionData.Type.END_TURN:
				_state.advance_turn()
				_after_advance()
```

Substitua por:

```gdscript
			ActionData.Type.END_TURN:
				if action is AcaoDefender:
					_state.apply_defender_action(_state.get_active_player_index())
				_state.advance_turn()
				_after_advance()
```

- [ ] **Step 2: Verificar que AcaoDefender está acessível**

`AcaoDefender` tem `class_name AcaoDefender` em `actions/endturn/acao_defender.gd`. O GDScript 4 resolve class_names globalmente, então `item is AcaoDefender` deve funcionar sem imports.

- [ ] **Step 3: Rodar testes**

```
godot --headless --script tests/run_tests.gd
```

Esperado: todos PASS (nenhum teste novo aqui — o Defender é integração, não testável unitariamente).

- [ ] **Step 4: Commit**

```
git add battle/battle_scene.gd
git commit -m "feat: wire Defender action to apply_defender_action in BattleState"
```

---

### Task 7: StatusPanel — badges de status

**Files:**
- Modify: `battle/ui/status_panel.gd`

- [ ] **Step 1: Adicionar variável _status_row e chamada em refresh()**

No bloco de variáveis de instância do StatusPanel (linha ~111–124), adicione:

```gdscript
var _status_row: HBoxContainer
```

- [ ] **Step 2: Construir _status_row no _ready()**

No final do método `_ready()`, após a última linha de `stats_hbox` (após o for loop de stat_kinds, ~linha 199), adicione:

```gdscript
	_status_row = HBoxContainer.new()
	_status_row.add_theme_constant_override("separation", 6)
	outer_vbox.add_child(_status_row)
```

- [ ] **Step 3: Adicionar _refresh_status_badges()**

Adicione após o método `_show_enemy()` (após linha ~317):

```gdscript
func _refresh_status_badges(queue_idx: int) -> void:
	for child in _status_row.get_children():
		child.queue_free()
	if _state == null:
		return
	var status_text: String = _state.get_active_status_text(queue_idx)
	if status_text.is_empty():
		return
	for part in status_text.split("  "):
		if part.is_empty():
			continue
		var lbl := Label.new()
		lbl.text = part
		lbl.add_theme_font_size_override("font_size", 9)
		var col := Color(0.55, 0.55, 0.60)
		if "Defender" in part:    col = Color(0.30, 0.60, 1.00)
		elif "Atordoado" in part: col = Color(1.00, 0.90, 0.20)
		elif "Fúria" in part:     col = Color(1.00, 0.35, 0.20)
		elif "Mirando" in part:   col = Color(0.45, 1.00, 0.55)
		elif "Veneno" in part:    col = Color(0.40, 0.85, 0.30)
		lbl.add_theme_color_override("font_color", col)
		_status_row.add_child(lbl)
```

- [ ] **Step 4: Chamar _refresh_status_badges() em refresh()**

O método `refresh(active_index: int)` atualmente (~linha 251):

```gdscript
func refresh(active_index: int) -> void:
	var combatant: Dictionary = BattleState.TURN_QUEUE[active_index % BattleState.TURN_QUEUE.size()]
	if combatant["is_player"]:
		_show_player(_find_player_index(combatant["name"]))
	else:
		_show_enemy(combatant, active_index)
```

Adicione a chamada de badges ao final:

```gdscript
func refresh(active_index: int) -> void:
	var combatant: Dictionary = BattleState.TURN_QUEUE[active_index % BattleState.TURN_QUEUE.size()]
	if combatant["is_player"]:
		_show_player(_find_player_index(combatant["name"]))
	else:
		_show_enemy(combatant, active_index)
	_refresh_status_badges(active_index)
```

- [ ] **Step 5: Rodar testes**

```
godot --headless --script tests/run_tests.gd
```

Esperado: todos PASS.

- [ ] **Step 6: Commit**

```
git add battle/ui/status_panel.gd
git commit -m "feat: add status badges display in StatusPanel"
```

---

### Task 8: Revisão final e testes de regressão

**Files:**
- Read: `tests/run_tests.gd`

- [ ] **Step 1: Rodar suite completa de testes**

```
godot --headless --script tests/run_tests.gd
```

Esperado: todos os testes PASS (os pré-existentes + todos os adicionados nas Tasks 1, 3, 5).

- [ ] **Step 2: Verificar consistência de active_enemy_action_idx**

Confirme que `active_enemy_action_idx` é resetado para `0` no início de cada turno inimigo. Abra `battle_state.gd` e procure onde `enemy_action_text = ""` é atribuído (~linha 312). A linha seguinte chama `_roll_enemy_action()`, que já seta `active_enemy_action_idx`. O reset implícito acontece via `_roll_enemy_action()` — não precisa de reset manual.

Confirme que o `_get_active_behavior()` é chamado APÓS `_roll_enemy_action()` ter sido chamado no mesmo turno. A chamada de `_roll_enemy_action()` ocorre em `advance_turn()` (linha ~315). As chamadas de `_get_active_behavior()` ocorrem em `get_enemy_move_path()` (via `_enemy_action_is_self` e `_enemy_action_range`) e em `apply_enemy_attack()`, ambas APÓS `advance_turn()` ter sido chamado.

- [ ] **Step 3: Commit final**

```
git add .
git commit -m "feat: complete enemy AI + status effects + Defender action implementation"
```
