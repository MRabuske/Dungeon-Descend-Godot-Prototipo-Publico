# Sistema de Ações por Herói — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Substituir `TAB_ACTION`/`TAB_HABILIDADES` estáticos globais por arrays por herói (`actions`/`skills`) em `HeroData`, com `BattleState` carregando dinamicamente as ações do herói ativo a cada turno.

**Architecture:** `HeroData` ganha `var actions` e `var skills`. Cada subclasse preenche esses arrays em `_init()`. `BattleState` tem `_load_hero_actions(name)` chamado no final de `_init()` e em `advance_turn()` ao entrar em turno de player. `TAB_ACTION`/`TAB_HABILIDADES` tornam-se `var tab_action`/`var tab_habilidades` (instance vars). `TAB_ITEMS` e `TAB_END_TURN` permanecem estáticos e compartilhados.

**Tech Stack:** GDScript 4.6, Godot 4.6. Sem editor ativo — verificação por inspeção de código.

---

## Arquivos

| Ação | Arquivo |
|---|---|
| Criar | `actions/attacks/atq_arcano.gd` |
| Criar | `actions/attacks/atq_divino.gd` |
| Criar | `actions/attacks/atq_soco.gd` |
| Criar | `actions/skills/skill_segundo_vento.gd` |
| Criar | `actions/skills/skill_chuva_flechas.gd` |
| Criar | `actions/skills/skill_cura_area.gd` |
| Modificar | `heroes/hero_data.gd` |
| Modificar | `heroes/guerreiro.gd` |
| Modificar | `heroes/mago.gd` |
| Modificar | `heroes/arqueiro.gd` |
| Modificar | `heroes/clerigo.gd` |
| Modificar | `heroes/ladrao.gd` |
| Modificar | `heroes/barbaro.gd` |
| Modificar | `battle/battle_state.gd` |
| Modificar | `battle/battle_scene.gd` |
| Modificar | `tests/run_tests.gd` |

---

### Task 1: Novos arquivos de ataque — AtqArcano, AtqDivino, AtqSoco

**Files:**
- Create: `actions/attacks/atq_arcano.gd`
- Create: `actions/attacks/atq_divino.gd`
- Create: `actions/attacks/atq_soco.gd`
- Test: `tests/run_tests.gd`

- [ ] **Step 1: Escrever o teste que falha**

Ao final de `tests/run_tests.gd`, antes do último `}` da função `_run_all()`, adicionar:

```gdscript
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
```

- [ ] **Step 2: Verificar que o teste falha (inspeção de código)**

As classes `AtqArcano`, `AtqDivino`, `AtqSoco` não existem — erro de parse.

- [ ] **Step 3: Criar `actions/attacks/atq_arcano.gd`**

```gdscript
class_name AtqArcano
extends ActionData

func _init() -> void:
	label            = "Raio Arcano"
	action_type      = Type.ATTACK
	shape            = SHAPE_SQUARE
	color_idx        = COLOR_ATTACK
	attack_range     = 4
	proj_color       = Color(0.6, 0.4, 1.0)
	damage_attribute = DamageAttribute.INT
	base_damage_min  = 2
	base_damage_max  = 6
```

- [ ] **Step 4: Criar `actions/attacks/atq_divino.gd`**

```gdscript
class_name AtqDivino
extends ActionData

func _init() -> void:
	label            = "Atq. Divino"
	action_type      = Type.ATTACK
	shape            = SHAPE_SQUARE
	color_idx        = COLOR_ATTACK
	attack_range     = 1
	proj_color       = Color(1.0, 0.95, 0.6)
	damage_attribute = DamageAttribute.WIS
	base_damage_min  = 3
	base_damage_max  = 7
```

- [ ] **Step 5: Criar `actions/attacks/atq_soco.gd`**

```gdscript
class_name AtqSoco
extends ActionData

func _init() -> void:
	label            = "Soco"
	action_type      = Type.ATTACK
	shape            = SHAPE_SQUARE
	color_idx        = COLOR_ATTACK
	attack_range     = 1
	proj_color       = Color(0.8, 0.6, 0.3)
	damage_attribute = DamageAttribute.DEX
	base_damage_min  = 2
	base_damage_max  = 5
```

- [ ] **Step 6: Verificar que o teste passa (inspeção de código)**

Cada classe retorna label, damage_attribute e campos corretos.

- [ ] **Step 7: Commit e push**

```
git add actions/attacks/atq_arcano.gd actions/attacks/atq_divino.gd actions/attacks/atq_soco.gd tests/run_tests.gd
git commit -m "feat: add AtqArcano, AtqDivino, AtqSoco attack actions"
git push
```

---

### Task 2: Pasta skills + novos arquivos — SkillSegundoVento, SkillChuvaFlechas, SkillCuraArea

**Files:**
- Create: `actions/skills/skill_segundo_vento.gd`
- Create: `actions/skills/skill_chuva_flechas.gd`
- Create: `actions/skills/skill_cura_area.gd`
- Test: `tests/run_tests.gd`

- [ ] **Step 1: Escrever o teste que falha**

Após os testes da Task 1 em `tests/run_tests.gd`:

```gdscript
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
```

- [ ] **Step 2: Verificar que o teste falha (inspeção de código)**

As classes não existem — erro de parse.

- [ ] **Step 3: Criar `actions/skills/skill_segundo_vento.gd`**

```gdscript
class_name SkillSegundoVento
extends ActionData

func _init() -> void:
	label       = "Segundo Vento"
	action_type = Type.END_TURN
	shape       = SHAPE_HEXAGON
	color_idx   = COLOR_SPELL
	self_target = true
	pp          = 1
	max_pp      = 1
```

- [ ] **Step 4: Criar `actions/skills/skill_chuva_flechas.gd`**

```gdscript
class_name SkillChuvaFlechas
extends ActionData

func _init() -> void:
	label            = "Chuva de Flechas"
	action_type      = Type.ATTACK
	shape            = SHAPE_HEXAGON
	color_idx        = COLOR_SPELL
	attack_range     = 3
	aoe_radius       = 1
	proj_color       = Color(0.6, 1.0, 0.5)
	damage_attribute = DamageAttribute.DEX
	base_damage_min  = 2
	base_damage_max  = 5
	mp_cost          = 15
```

- [ ] **Step 5: Criar `actions/skills/skill_cura_area.gd`**

```gdscript
class_name SkillCuraArea
extends ActionData

func _init() -> void:
	label            = "Cura em Área"
	action_type      = Type.ATTACK
	shape            = SHAPE_HEXAGON
	color_idx        = COLOR_SPELL
	attack_range     = 1
	aoe_radius       = 1
	proj_color       = Color(0.30, 1.00, 0.50)
	targets_allies   = true
	damage_attribute = DamageAttribute.WIS
	base_damage_min  = 8
	base_damage_max  = 12
	mp_cost          = 25
```

- [ ] **Step 6: Verificar que o teste passa (inspeção de código)**

Cada classe retorna propriedades corretas.

- [ ] **Step 7: Commit e push**

```
git add actions/skills/skill_segundo_vento.gd actions/skills/skill_chuva_flechas.gd actions/skills/skill_cura_area.gd tests/run_tests.gd
git commit -m "feat: add SkillSegundoVento, SkillChuvaFlechas, SkillCuraArea"
git push
```

---

### Task 3: HeroData — campos actions e skills

**Files:**
- Modify: `heroes/hero_data.gd`
- Test: `tests/run_tests.gd`

- [ ] **Step 1: Escrever o teste que falha**

Após os testes da Task 2 em `tests/run_tests.gd`:

```gdscript
	# Task 3: HeroData arrays
	var hd := HeroData.new()
	_true("HeroData.actions exists and is empty", hd.actions.is_empty())
	_true("HeroData.skills exists and is empty",  hd.skills.is_empty())
```

- [ ] **Step 2: Verificar que o teste falha (inspeção de código)**

`HeroData` não tem os campos `actions` e `skills`.

- [ ] **Step 3: Adicionar campos em `heroes/hero_data.gd`**

Leia o arquivo. Após a função `to_combat_dict()` (no final do arquivo), adicionar:

```gdscript
var actions: Array[ActionData] = []
var skills:  Array[ActionData] = []
```

O arquivo completo ficará assim ao final:

```gdscript
func to_combat_dict() -> Dictionary:
	return {
		"name":         hero_name,
		"class":        hero_class,
		"level":        level,
		"hp":           base_hp,
		"max_hp":       max_hp,
		"mp":           base_mp,
		"max_mp":       max_mp,
		"ac":           ac,
		"initiative":   initiative,
		"speed":        speed,
		"proficiency":      proficiency,
		"damage_reduction": damage_reduction,
		"strength":         strength,
		"dexterity":    dexterity,
		"intelligence": intelligence,
		"wisdom":       wisdom,
		"constitution": constitution,
	}

var actions: Array[ActionData] = []
var skills:  Array[ActionData] = []
```

- [ ] **Step 4: Verificar que o teste passa (inspeção de código)**

`HeroData.new()` terá `actions = []` e `skills = []` como arrays vazios tipados.

- [ ] **Step 5: Commit e push**

```
git add heroes/hero_data.gd tests/run_tests.gd
git commit -m "feat: add actions and skills arrays to HeroData"
git push
```

---

### Task 4: Guerreiro e Mago — popular actions e skills

**Files:**
- Modify: `heroes/guerreiro.gd`
- Modify: `heroes/mago.gd`
- Test: `tests/run_tests.gd`

- [ ] **Step 1: Escrever o teste que falha**

Após os testes da Task 3 em `tests/run_tests.gd`:

```gdscript
	# Task 4: Guerreiro e Mago actions
	var g_data: HeroData = BattleState.ALL_HERO_DATA["Guerreiro"]
	_true("Guerreiro actions has AtqNormal",       g_data.actions.size() >= 1 and g_data.actions[0] is AtqNormal)
	_true("Guerreiro actions has AcaoMover last",  g_data.actions.size() >= 2 and g_data.actions[g_data.actions.size()-1] is AcaoMover)
	_true("Guerreiro skills has SkillSegundoVento", g_data.skills.size() == 1 and g_data.skills[0] is SkillSegundoVento)

	var m_data: HeroData = BattleState.ALL_HERO_DATA["Mago"]
	_true("Mago actions has AtqArcano",  m_data.actions.size() >= 1 and m_data.actions[0] is AtqArcano)
	_true("Mago skills has 4 items",     m_data.skills.size() == 4)
	_true("Mago skills[0] is SpellFogo", m_data.skills[0] is SpellFogo)
```

- [ ] **Step 2: Verificar que o teste falha (inspeção de código)**

`g_data.actions` e `g_data.skills` estão vazios — os arrays foram adicionados em Task 3 mas ainda não populados.

- [ ] **Step 3: Atualizar `heroes/guerreiro.gd`**

Leia o arquivo atual (apenas `_init()` com stats). Adicionar ao final de `_init()`:

```gdscript
func _init() -> void:
	hero_name    = "Guerreiro"
	hero_class   = "Fighter"
	level        = 4
	base_hp      = 80
	max_hp       = 100
	base_mp      = 40
	max_mp       = 80
	ac           = 16
	initiative   = 8
	speed        = 7
	proficiency  = 3
	strength     = 16
	dexterity    = 12
	intelligence = 8
	wisdom       = 10
	constitution = 15
	actions = [AtqNormal.new(), AtqPesado.new(), AcaoMover.new()]
	skills  = [SkillSegundoVento.new()]
```

- [ ] **Step 4: Atualizar `heroes/mago.gd`**

Leia o arquivo atual. Adicionar ao final de `_init()`:

```gdscript
	actions = [AtqArcano.new(), AcaoMover.new()]
	skills  = [SpellFogo.new(), SpellGelo.new(), SpellTrovao.new(), SpellCura.new()]
```

- [ ] **Step 5: Verificar que o teste passa (inspeção de código)**

`ALL_HERO_DATA["Guerreiro"].actions[0]` é `AtqNormal`, `actions.last()` é `AcaoMover`, `skills[0]` é `SkillSegundoVento`. `ALL_HERO_DATA["Mago"].actions[0]` é `AtqArcano`, `skills.size()` é 4.

- [ ] **Step 6: Commit e push**

```
git add heroes/guerreiro.gd heroes/mago.gd tests/run_tests.gd
git commit -m "feat: populate actions and skills for Guerreiro and Mago"
git push
```

---

### Task 5: Arqueiro e Clérigo — popular actions e skills

**Files:**
- Modify: `heroes/arqueiro.gd`
- Modify: `heroes/clerigo.gd`
- Test: `tests/run_tests.gd`

- [ ] **Step 1: Escrever o teste que falha**

Após os testes da Task 4 em `tests/run_tests.gd`:

```gdscript
	# Task 5: Arqueiro e Clérigo
	var a_data: HeroData = BattleState.ALL_HERO_DATA["Arqueiro"]
	_true("Arqueiro actions[0] is AtqRapido",      a_data.actions.size() >= 1 and a_data.actions[0] is AtqRapido)
	_true("Arqueiro actions[1] is AtqPreciso",     a_data.actions.size() >= 2 and a_data.actions[1] is AtqPreciso)
	_true("Arqueiro skills[0] is SkillChuvaFlechas", a_data.skills.size() == 1 and a_data.skills[0] is SkillChuvaFlechas)

	var c_data: HeroData = BattleState.ALL_HERO_DATA["Clérigo"]
	_true("Clérigo actions[0] is AtqDivino",     c_data.actions.size() >= 1 and c_data.actions[0] is AtqDivino)
	_true("Clérigo skills has SpellCura",        c_data.skills.size() >= 1 and c_data.skills[0] is SpellCura)
	_true("Clérigo skills has SkillCuraArea",    c_data.skills.size() == 2 and c_data.skills[1] is SkillCuraArea)
```

- [ ] **Step 2: Verificar que o teste falha (inspeção de código)**

`a_data.actions` e `c_data.actions` estão vazios.

- [ ] **Step 3: Atualizar `heroes/arqueiro.gd`**

Leia o arquivo atual. Adicionar ao final de `_init()`:

```gdscript
	actions = [AtqRapido.new(), AtqPreciso.new(), AcaoMover.new()]
	skills  = [SkillChuvaFlechas.new()]
```

Nota: `AtqPreciso` já usa `DamageAttribute.DEX` e `attack_range = 4` por padrão — reutilizado sem modificação.

- [ ] **Step 4: Atualizar `heroes/clerigo.gd`**

Leia o arquivo atual. Adicionar ao final de `_init()`:

```gdscript
	actions = [AtqDivino.new(), AcaoMover.new()]
	skills  = [SpellCura.new(), SkillCuraArea.new()]
```

- [ ] **Step 5: Verificar que o teste passa (inspeção de código)**

Arrays populados corretamente para Arqueiro e Clérigo.

- [ ] **Step 6: Commit e push**

```
git add heroes/arqueiro.gd heroes/clerigo.gd tests/run_tests.gd
git commit -m "feat: populate actions and skills for Arqueiro and Clérigo"
git push
```

---

### Task 6: Ladrao e Bárbaro — popular actions e skills

**Files:**
- Modify: `heroes/ladrao.gd`
- Modify: `heroes/barbaro.gd`
- Test: `tests/run_tests.gd`

- [ ] **Step 1: Escrever o teste que falha**

Após os testes da Task 5 em `tests/run_tests.gd`:

```gdscript
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
```

- [ ] **Step 2: Verificar que o teste falha (inspeção de código)**

Arrays vazios ainda.

- [ ] **Step 3: Atualizar `heroes/ladrao.gd`**

Leia o arquivo atual. Substituir/adicionar ao final de `_init()` (Ladrao usa AtqNormal com DEX override):

```gdscript
	var an := AtqNormal.new()
	an.damage_attribute = ActionData.DamageAttribute.DEX
	actions = [an, AtqRapido.new(), AcaoMover.new()]
	skills  = []
```

- [ ] **Step 4: Atualizar `heroes/barbaro.gd`**

Leia o arquivo atual. Adicionar ao final de `_init()`:

```gdscript
	actions = [AtqNormal.new(), AtqPesado.new(), AcaoMover.new()]
	skills  = []
```

- [ ] **Step 5: Verificar que o teste passa (inspeção de código)**

Ladrao tem AtqNormal com `damage_attribute == DEX`, AtqRapido, AcaoMover, skills vazio. Bárbaro tem AtqNormal, AtqPesado, AcaoMover, skills vazio.

- [ ] **Step 6: Commit e push**

```
git add heroes/ladrao.gd heroes/barbaro.gd tests/run_tests.gd
git commit -m "feat: populate actions and skills for Ladrao and Bárbaro"
git push
```

---

### Task 7: BattleState — tab_action/tab_habilidades + _load_hero_actions + PP check + testes

**Files:**
- Modify: `battle/battle_state.gd` (linhas ~86-99, ~140-200, ~228-255, ~273-341)
- Modify: `tests/run_tests.gd` (linhas 69-70, 86, 95, 130-131)

- [ ] **Step 1: Escrever os novos testes e atualizar os existentes em `tests/run_tests.gd`**

**Atualizar linha 69-70** (era `BattleState.TAB_ACTION`, agora usa instância):

```gdscript
	# get_active_tab_items
	_eq("get_active_tab_items returns tab_action at start",
		s.get_active_tab_items(), s.tab_action)
```

**Atualizar linha 86** (era `BattleState.TAB_ACTION.size()`):

```gdscript
	# move_cursor_tab wrap to next tab
	for _i in range(s.tab_action.size()):
		s.move_cursor_tab(1)
```

**Atualizar linha 94-95** (era `BattleState.TAB_ACTION.size() - 1`):

```gdscript
	_eq("wrap left: cursor at last ACTION slot",
		s.cursor_position, s.tab_action.size() - 1)
```

**Atualizar linhas 130-131** (era `BattleState.TAB_ACTION[...]`):

```gdscript
	# tab_action has Mover slot as AcaoMover instance
	var mover_slot: ActionData = s.tab_action[s.tab_action.size() - 1]
	_eq("last tab_action slot label is Mover", mover_slot.label, "Mover")
	_true("Mover slot is AcaoMover instance", mover_slot is AcaoMover)
```

**Adicionar novos testes** após os existentes (após a linha do `# Task 6`):

```gdscript
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
```

- [ ] **Step 2: Verificar que os novos testes falham (inspeção de código)**

`s7.tab_action` não existe ainda — `tab_action` é `static var TAB_ACTION` — erro ao tentar acessar como instance var.

- [ ] **Step 3: Converter `TAB_ACTION` e `TAB_HABILIDADES` de static para instance vars em `battle_state.gd`**

Leia `battle/battle_state.gd`. Encontrar as declarações:

```gdscript
static var TAB_ACTION: Array[ActionData] = [
	AtqNormal.new(),
	AtqPesado.new(),
	AtqRapido.new(),
	AtqPreciso.new(),
	AcaoMover.new(),
]

static var TAB_HABILIDADES: Array[ActionData] = [
	SpellFogo.new(),
	SpellGelo.new(),
	SpellTrovao.new(),
	SpellCura.new(),
]
```

Substituir por:

```gdscript
var tab_action:      Array[ActionData] = []
var tab_habilidades: Array[ActionData] = []
```

- [ ] **Step 4: Atualizar `get_active_tab_items()` em `battle_state.gd`**

Encontrar:

```gdscript
func get_active_tab_items() -> Array:
	match active_tab:
		0: return TAB_ACTION
		1: return TAB_HABILIDADES
		2: return TAB_ITEMS
		3: return TAB_END_TURN
	return []
```

Substituir por:

```gdscript
func get_active_tab_items() -> Array:
	match active_tab:
		0: return tab_action
		1: return tab_habilidades
		2: return TAB_ITEMS
		3: return TAB_END_TURN
	return []
```

- [ ] **Step 5: Adicionar `_load_hero_actions()` em `battle_state.gd`**

Após `get_active_player_index()` (linha ~226), adicionar:

```gdscript
func _load_hero_actions(player_name: String) -> void:
	var hdata: HeroData = ALL_HERO_DATA.get(player_name, null)
	if hdata == null:
		return
	tab_action      = hdata.actions
	tab_habilidades = hdata.skills
```

- [ ] **Step 6: Chamar `_load_hero_actions()` no final de `_init()` em `battle_state.gd`**

Encontrar `func _init() -> void:`. Adicionar ao final (após a linha `combatant_statuses.append({})`):

```gdscript
	if TURN_QUEUE.size() > 0 and TURN_QUEUE[0].get("is_player", false):
		_load_hero_actions(TURN_QUEUE[0]["name"])
```

- [ ] **Step 7: Chamar `_load_hero_actions()` em `advance_turn()` em `battle_state.gd`**

Encontrar o bloco no final de `advance_turn()`:

```gdscript
	if is_player_turn():
		current_state = State.PLAYER_TURN
		enemy_action_text = ""
	else:
		current_state = State.ENEMY_TURN
		_roll_enemy_action()
```

Substituir por:

```gdscript
	if is_player_turn():
		current_state = State.PLAYER_TURN
		enemy_action_text = ""
		_load_hero_actions(TURN_QUEUE[active_index]["name"])
	else:
		current_state = State.ENEMY_TURN
		_roll_enemy_action()
```

- [ ] **Step 8: Adicionar check de PP em `is_item_available()` em `battle_state.gd`**

Encontrar:

```gdscript
func is_item_available(item) -> bool:
	if item is ActionData:
		var action := item as ActionData
		if action.action_type == ActionData.Type.ATTACK and has_attacked:
			return action.bonus_action or fury_extra_attack
		if action.action_type == ActionData.Type.MOVE and has_moved:
			return false
		if action.mp_cost > 0:
			var pidx := get_active_player_index()
			if pidx >= 0 and PLAYERS[pidx]["mp"] < action.mp_cost:
				return false
		return true
```

Adicionar após o check de `mp_cost` e antes do `return true`:

```gdscript
		if action.max_pp > 0 and action.pp <= 0:
			return false
```

Resultado final:

```gdscript
func is_item_available(item) -> bool:
	if item is ActionData:
		var action := item as ActionData
		if action.action_type == ActionData.Type.ATTACK and has_attacked:
			return action.bonus_action or fury_extra_attack
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
```

- [ ] **Step 9: Verificar que todos os testes passam (inspeção de código)**

- `s.tab_action` após `_init()` carrega Guerreiro's actions (AtqNormal, AtqPesado, AcaoMover)
- Após 2 `advance_turn()`, `tab_action` carrega Mago's actions (AtqArcano, AcaoMover)
- `is_item_available(sv2)` com `pp=0` retorna false
- Testes antigos atualizados: `s.tab_action.size()` para wrap tests, `s.tab_action[...]` para slot tests

- [ ] **Step 10: Commit e push**

```
git add battle/battle_state.gd tests/run_tests.gd
git commit -m "feat: refactor TAB_ACTION/TAB_HABILIDADES to per-hero tab_action/tab_habilidades with _load_hero_actions"
git push
```

---

### Task 8: battle_scene.gd — handler de SkillSegundoVento

**Files:**
- Modify: `battle/battle_scene.gd` (função `_execute_current_item()`, linhas ~184-217)

Sem testes automáticos — verificação por inspeção de código.

- [ ] **Step 1: Ler `_execute_current_item()` em `battle/battle_scene.gd`**

Encontrar o bloco `ActionData.Type.END_TURN:`. Atualmente:

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

- [ ] **Step 2: Inserir handler de `SkillSegundoVento`**

```gdscript
			ActionData.Type.END_TURN:
				if item is AcaoDefender:
					_state.apply_defender_action(_state.get_active_player_index())
				elif item is AcaoEsperar:
					var pidx: int = _state.get_active_player_index()
					if pidx >= 0 and BattleState.PLAYERS[pidx]["class"] == "Rogue":
						_state.apply_furtivo_status(pidx)
				elif item is SkillSegundoVento:
					var pidx: int = _state.get_active_player_index()
					if pidx >= 0 and item.pp > 0:
						item.pp -= 1
						var p: Dictionary = BattleState.PLAYERS[pidx]
						p["hp"] = mini(p["hp"] + 15, p["max_hp"])
						_state._log("Guerreiro usa Segundo Vento! +15 HP", "status")
				_state.advance_turn()
				_after_advance()
```

- [ ] **Step 3: Verificar a lógica (inspeção de código)**

- `item is SkillSegundoVento` detecta a skill corretamente ✅
- `item.pp > 0` verifica se ainda tem uso disponível ✅
- `item.pp -= 1` consome o uso (a instância do item vem de `tab_action`/`tab_habilidades`, que é a instância do herói, persistindo o estado entre usos) ✅
- `p["hp"] = mini(p["hp"] + 15, p["max_hp"])` cura sem ultrapassar HP máximo ✅
- `_state.advance_turn()` e `_after_advance()` ainda são chamados ✅

- [ ] **Step 4: Commit e push**

```
git add battle/battle_scene.gd
git commit -m "feat: add SkillSegundoVento handler in _execute_current_item"
git push
```
