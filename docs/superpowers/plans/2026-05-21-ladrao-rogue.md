# Ladrao (Rogue) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adicionar o Ladrao (Rogue) como quinta classe jogável com Ataque Furtivo — bônus de dano consumido ao atacar, recarregado ao usar AcaoEsperar ou no início do combate.

**Architecture:** Nova subclasse `LadraoData` em `heroes/ladrao.gd` registrada em `BattleState.ALL_HERO_DATA`. Status `"furtivo"` usa a infraestrutura de `combatant_statuses` já existente (mesmo padrão de `"defending"`/`"aiming"`). Consumido em `_apply_attack()`, recarregado via `apply_furtivo_status()` chamado de `battle_scene.gd`.

**Tech Stack:** GDScript 4.6, Godot 4.6. Sem editor ativo — sem teste headless; verificação por inspeção de código.

---

## Arquivos

| Ação | Arquivo | Responsabilidade |
|---|---|---|
| Criar | `heroes/ladrao.gd` | Stats do Ladrao, `class_name LadraoData` |
| Modificar | `battle/battle_state.gd` | Registrar herói, inicializar furtivo em `setup()`, `apply_furtivo_status()`, consumo em `_apply_attack()` |
| Modificar | `battle/battle_scene.gd` | Detectar AcaoEsperar + Rogue em `_execute_current_item()` |
| Modificar | `battle/ui/status_panel.gd` | Adicionar `"furtivo"` ao `badge_map` |
| Modificar | `tests/run_tests.gd` | Testes para Tasks 1, 2, 3 |

---

### Task 1: LadraoData — heroes/ladrao.gd + registro em BattleState

**Files:**
- Create: `heroes/ladrao.gd`
- Modify: `battle/battle_state.gd` (linhas 16-50)
- Test: `tests/run_tests.gd`

- [ ] **Step 1: Escrever o teste que falha**

Ao final do bloco de testes em `tests/run_tests.gd` (após linha 377), adicionar:

```gdscript
	# Task 1 (Ladrao): hero data stats
	var ladrao_data: HeroData = BattleState.ALL_HERO_DATA.get("Ladrao", null)
	_true("ALL_HERO_DATA contains Ladrao", ladrao_data != null)
	_eq("Ladrao speed is 9",       ladrao_data.speed,      9)
	_eq("Ladrao dexterity is 18",  ladrao_data.dexterity,  18)
	_eq("Ladrao base_hp is 55",    ladrao_data.base_hp,    55)
	_eq("Ladrao class is Rogue",   ladrao_data.hero_class, "Rogue")
```

- [ ] **Step 2: Verificar que o teste falha (inspeção de código)**

`BattleState.ALL_HERO_DATA` não tem `"Ladrao"` — `ladrao_data` será `null`, `_true` falhará.

- [ ] **Step 3: Criar `heroes/ladrao.gd`**

```gdscript
class_name LadraoData
extends HeroData

func _init() -> void:
	hero_name    = "Ladrao"
	hero_class   = "Rogue"
	level        = 4
	base_hp      = 55
	max_hp       = 100
	base_mp      = 20
	max_mp       = 40
	ac           = 13
	initiative   = 9
	speed        = 9
	proficiency  = 3
	strength     = 10
	dexterity    = 18
	intelligence = 12
	wisdom       = 11
	constitution = 11
```

- [ ] **Step 4: Registrar em `battle_state.gd`**

Modificar `ALL_HERO_DATA` (linha 16):

```gdscript
static var ALL_HERO_DATA: Dictionary = {
	"Guerreiro": GuerreiroData.new(),
	"Mago":      MagoData.new(),
	"Arqueiro":  ArqueiroData.new(),
	"Clérigo":   ClérigoData.new(),
	"Ladrao":    LadraoData.new(),
}
```

Adicionar Ladrao ao final de `TURN_QUEUE` padrão (linha 30) — **inserir no final para não quebrar índices dos testes existentes** (Goblin=1, Orc=4 devem permanecer):

```gdscript
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
]
```

Adicionar Ladrao ao final de `PLAYERS` padrão (linha 41):

```gdscript
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
]
```

- [ ] **Step 5: Verificar que o teste passa (inspeção de código)**

`ALL_HERO_DATA["Ladrao"]` retorna `LadraoData` com `speed=9`, `dexterity=18`, `base_hp=55`, `hero_class="Rogue"`. Todos os asserts passam.

- [ ] **Step 6: Commit**

```
git add heroes/ladrao.gd battle/battle_state.gd tests/run_tests.gd
git commit -m "feat: add LadraoData (Rogue) hero class and register in BattleState"
```

---

### Task 2: BattleState — apply_furtivo_status() + inicializar furtivo em setup()

**Files:**
- Modify: `battle/battle_state.gd`
- Test: `tests/run_tests.gd`

- [ ] **Step 1: Escrever o teste que falha**

Após os testes da Task 1 em `tests/run_tests.gd`:

```gdscript
	# Task 2 (Ladrao): apply_furtivo_status
	var s_furtivo := BattleState.new()
	s_furtivo.apply_furtivo_status(0)  # PLAYERS[0] = Guerreiro → TURN_QUEUE[0]
	_true("apply_furtivo_status sets furtivo on queue idx 0",
		  s_furtivo.combatant_statuses[0].get("furtivo", 0) > 0)
```

- [ ] **Step 2: Verificar que o teste falha (inspeção de código)**

Método `apply_furtivo_status` não existe — erro de parse ou runtime.

- [ ] **Step 3: Adicionar `apply_furtivo_status()` em `battle_state.gd`**

Adicionar logo após `apply_defender_action()` (linha ~715):

```gdscript
func apply_furtivo_status(player_idx: int) -> void:
	if player_idx < 0 or player_idx >= PLAYERS.size():
		return
	var pname: String = PLAYERS[player_idx]["name"]
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i]["is_player"] and TURN_QUEUE[i]["name"] == pname:
			combatant_statuses[i]["furtivo"] = 1
			break
	_log("%s está em posição furtiva" % pname, "status")
```

- [ ] **Step 4: Inicializar furtivo em `setup()` para o Ladrao**

Em `setup()`, após o loop que inicializa `combatant_statuses` (após linha ~165):

```gdscript
	for i in range(TURN_QUEUE.size()):
		if TURN_QUEUE[i].get("is_player", false):
			var pname: String = TURN_QUEUE[i]["name"]
			var hdata := ALL_HERO_DATA.get(pname, null) as HeroData
			if hdata != null and hdata.hero_class == "Rogue":
				combatant_statuses[i]["furtivo"] = 1
```

- [ ] **Step 5: Verificar que o teste passa (inspeção de código)**

`apply_furtivo_status(0)` busca `PLAYERS[0]["name"] = "Guerreiro"`, encontra `TURN_QUEUE[0]`, define `combatant_statuses[0]["furtivo"] = 1`. Assert passa.

- [ ] **Step 6: Commit**

```
git add battle/battle_state.gd tests/run_tests.gd
git commit -m "feat: add apply_furtivo_status and init furtivo in setup() for Rogue"
```

---

### Task 3: BattleState — consumir furtivo em _apply_attack()

**Files:**
- Modify: `battle/battle_state.gd` (função `_apply_attack`, linha ~947)
- Test: `tests/run_tests.gd`

- [ ] **Step 1: Escrever o teste que falha**

Após os testes da Task 2 em `tests/run_tests.gd`:

```gdscript
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
```

- [ ] **Step 2: Verificar que o teste falha (inspeção de código)**

`furtivo` nunca é consumido em `_apply_attack()` — `combatant_statuses[0]["furtivo"]` permanece 1 após o ataque. Primeiro assert falha.

- [ ] **Step 3: Adicionar consumo de furtivo em `_apply_attack()`**

Em `battle_state.gd`, dentro de `_apply_attack()`, no branch `else` (ataques a inimigos), após a multiplicação de crítico (linha ~978) e antes de `battle_stats["player_damage_dealt"]` (linha ~979):

**Contexto atual (linhas 974-979):**
```gdscript
		var is_crit: bool = randf() < CRIT_CHANCE
		var damage: int = _roll_player_damage()
		if is_crit:
			damage *= 2
			battle_stats["crits"] = battle_stats.get("crits", 0) + 1
		battle_stats["player_damage_dealt"] = ...
```

**Após a edição:**
```gdscript
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
		battle_stats["player_damage_dealt"] = ...
```

- [ ] **Step 4: Verificar que o teste passa (inspeção de código)**

Após `_apply_attack(1)`: `combatant_statuses[0]["furtivo"]` foi removido com `erase()`. `last_attack_info["amount"]` é dano base + sneak_bonus (≥ 1). Ambos os asserts passam.

- [ ] **Step 5: Commit**

```
git add battle/battle_state.gd tests/run_tests.gd
git commit -m "feat: consume furtivo status in _apply_attack for Sneak Attack bonus"
```

---

### Task 4: BattleScene + StatusPanel — AcaoEsperar reconhece Rogue + badge furtivo

**Files:**
- Modify: `battle/battle_scene.gd` (função `_execute_current_item`, linha ~204)
- Modify: `battle/ui/status_panel.gd` (função `_refresh_status_badges`, linha ~276)

Nota: sem testes automáticos para esta task — verificação por inspeção de código.

- [ ] **Step 1: Adicionar badge `"furtivo"` em `status_panel.gd`**

Em `_refresh_status_badges()`, adicionar entrada ao `badge_map` após `"aiming"` (linha ~281):

**Contexto atual:**
```gdscript
	var badge_map := [
		["defending", "Defender +2 AC",  Color(0.3, 0.6, 1.0)],
		["stun",      "Atordoado",        Color(1.0, 0.9, 0.2)],
		["stunned",   "Atordoado",        Color(1.0, 0.9, 0.2)],
		["raging",    "Furia +3 dano",    Color(1.0, 0.3, 0.2)],
		["aiming",    "Mirando +2 alc",   Color(0.6, 1.0, 0.6)],
	]
```

**Após a edição:**
```gdscript
	var badge_map := [
		["defending", "Defender +2 AC",  Color(0.3, 0.6, 1.0)],
		["stun",      "Atordoado",        Color(1.0, 0.9, 0.2)],
		["stunned",   "Atordoado",        Color(1.0, 0.9, 0.2)],
		["raging",    "Furia +3 dano",    Color(1.0, 0.3, 0.2)],
		["aiming",    "Mirando +2 alc",   Color(0.6, 1.0, 0.6)],
		["furtivo",   "Furtivo",          Color(0.7, 0.4, 1.0)],
	]
```

- [ ] **Step 2: Verificar badge (inspeção de código)**

`_refresh_status_badges()` itera `badge_map`. Quando `combatant_statuses[queue_idx].get("furtivo", 0) > 0`, cria Label roxo com texto "Furtivo". Correto.

- [ ] **Step 3: Conectar AcaoEsperar + Rogue em `battle_scene.gd`**

Em `_execute_current_item()`, no branch `ActionData.Type.END_TURN` (linha ~204):

**Contexto atual:**
```gdscript
			ActionData.Type.END_TURN:
				if item is AcaoDefender:
					_state.apply_defender_action(_state.get_active_player_index())
				_state.advance_turn()
				_after_advance()
```

**Após a edição:**
```gdscript
			ActionData.Type.END_TURN:
				if item is AcaoDefender:
					_state.apply_defender_action(_state.get_active_player_index())
				elif item is AcaoEsperar:
					var pidx: int = _state.get_active_player_index()
					if pidx >= 0 and BattleState.PLAYERS[pidx]["class"] == "Rogue":
						_state.apply_furtivo_status(pidx)
				_state.advance_turn()
				_after_advance()
```

- [ ] **Step 4: Verificar lógica (inspeção de código)**

- Apenas `AcaoEsperar` (não `AcaoFugir`) recarrega furtivo — correto, `elif` garante exclusividade.
- `pidx >= 0` garante que é turno de um player — correto.
- `PLAYERS[pidx]["class"] == "Rogue"` garante que só o Ladrao recebe furtivo — correto.
- `apply_furtivo_status(pidx)` define `combatant_statuses[queue_idx]["furtivo"] = 1` — correto.

- [ ] **Step 5: Commit**

```
git add battle/battle_scene.gd battle/ui/status_panel.gd
git commit -m "feat: recharge furtivo on AcaoEsperar for Rogue and add Furtivo badge to StatusPanel"
```
