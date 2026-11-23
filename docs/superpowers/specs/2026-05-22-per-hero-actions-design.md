# Sistema de Ações por Herói — Design Spec

## Objetivo

Substituir os arrays globais estáticos `TAB_ACTION` e `TAB_HABILIDADES` por arrays individuais definidos em cada `HeroData`. Cada herói passa a ter seu próprio conjunto de ataques e habilidades. Os tabs ITEMS e END_TURN permanecem compartilhados.

## Arquitetura

### HeroData — novos campos

```gdscript
var actions: Array[ActionData] = []   # aba ACTION (ataques + mover)
var skills:  Array[ActionData] = []   # aba HABILIDADES (magias/skills)
```

Cada subclasse de `HeroData` preenche esses arrays em `_init()`. Ações reutilizáveis (ex: `AtqNormal`) são instanciadas e configuradas lá — o mesmo tipo pode ter atributos diferentes por herói (ex: Ladrao usa `AtqNormal` com `DamageAttribute.DEX`).

### BattleState — refatoração de tab_action / tab_habilidades

Remover o `static` de:
```gdscript
static var TAB_ACTION:      Array[ActionData]
static var TAB_HABILIDADES: Array[ActionData]
```

Tornar instance vars:
```gdscript
var tab_action:      Array[ActionData] = []
var tab_habilidades: Array[ActionData] = []
```

Adicionar método:
```gdscript
func _load_hero_actions(player_name: String) -> void:
    var hdata: HeroData = ALL_HERO_DATA.get(player_name, null)
    if hdata == null:
        return
    tab_action      = hdata.actions
    tab_habilidades = hdata.skills
```

Chamar `_load_hero_actions(TURN_QUEUE[active_index]["name"])` em dois pontos:
1. No final de `setup()`, para o primeiro combatente (se for player)
2. Em `advance_turn()`, ao mudar para um combatente `is_player == true`

### PP (Power Points) — disponibilidade

`is_item_available()` deve verificar se `action.max_pp > 0 and action.pp <= 0 → return false`. Isso bloqueia skills de uso limitado quando esgotadas.

Decremento de PP: feito em `_execute_current_item()` ao executar a skill, ou em `_apply_attack()` para skills de ataque — antes de finalizar a ação.

### Referências a atualizar

Todos os usos de `BattleState.TAB_ACTION` e `BattleState.TAB_HABILIDADES` (acesso estático) devem migrar para `_state.tab_action` e `_state.tab_habilidades` nos arquivos:
- `battle/battle_scene.gd`
- `battle/ui/action_panel.gd`
- `tests/run_tests.gd`

## Novos Arquivos de Action

### Ataques

**`actions/attacks/atq_arcano.gd`** — Mago, ataque à distância com INT
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

**`actions/attacks/atq_divino.gd`** — Clérigo e Paladino, melee WIS
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

**`actions/attacks/atq_soco.gd`** — Monge, soco leve DEX
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

### Skills

**`actions/skills/skill_segundo_vento.gd`** — Guerreiro, auto-cura limitada (1 uso)
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

**`actions/skills/skill_chuva_flechas.gd`** — Arqueiro, ataque AoE DEX
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

**`actions/skills/skill_cura_area.gd`** — Clérigo, cura AoE aliados
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

## Action Sets por Herói

### Guerreiro (Fighter)
```gdscript
# actions:
actions = [AtqNormal.new(), AtqPesado.new(), AcaoMover.new()]
# AtqNormal: STR, range 1 (padrão)
# AtqPesado: STR, range 1, 6-12 dano (padrão)

# skills:
skills = [SkillSegundoVento.new()]
```

**Handler de SkillSegundoVento em `_execute_current_item()`:**
```gdscript
elif item is SkillSegundoVento:
    if item.pp > 0:
        item.pp -= 1
        var pidx: int = _state.get_active_player_index()
        if pidx >= 0:
            BattleState.PLAYERS[pidx]["hp"] = mini(
                BattleState.PLAYERS[pidx]["hp"] + 15,
                BattleState.PLAYERS[pidx]["max_hp"]
            )
            _state._log("Guerreiro usa Segundo Vento! +15 HP", "status")
    _state.advance_turn()
```

### Mago (Wizard)
```gdscript
# actions:
actions = [AtqArcano.new(), AcaoMover.new()]

# skills:
skills = [SpellFogo.new(), SpellGelo.new(), SpellTrovao.new(), SpellCura.new()]
```

### Arqueiro (Ranger)
```gdscript
# actions:
actions = [AtqRapido.new(), AtqPreciso.new(), AcaoMover.new()]
# AtqRapido: DEX, range 1, bonus_action (padrão)
# AtqPreciso: DEX, range 4 (padrão — já usa DEX)

# skills:
skills = [SkillChuvaFlechas.new()]
```

### Clérigo (Cleric)
```gdscript
# actions:
actions = [AtqDivino.new(), AcaoMover.new()]

# skills:
skills = [SpellCura.new(), SkillCuraArea.new()]
```

### Ladrao (Rogue)
```gdscript
# actions — AtqNormal configurado com DEX:
func _init() -> void:
    ...
    var an := AtqNormal.new()
    an.damage_attribute = DamageAttribute.DEX
    an.label = "Atq. Normal"
    actions = [an, AtqRapido.new(), AcaoMover.new()]

# skills: (vazio — Ataque Furtivo é passivo)
skills = []
```

### Bárbaro (Barbarian)
```gdscript
# actions:
actions = [AtqNormal.new(), AtqPesado.new(), AcaoMover.new()]

# skills: (vazio — Fúria é automática)
skills = []
```

## Testes

Em `tests/run_tests.gd`, adicionar:

```gdscript
# Per-hero actions
var g_data: HeroData = BattleState.ALL_HERO_DATA["Guerreiro"]
_true("Guerreiro has actions", g_data.actions.size() > 0)
_true("Guerreiro has SegundoVento in skills", g_data.skills.size() > 0 and g_data.skills[0] is SkillSegundoVento)

var m_data: HeroData = BattleState.ALL_HERO_DATA["Mago"]
_true("Mago has AtqArcano in actions", m_data.actions.size() > 0 and m_data.actions[0] is AtqArcano)
_true("Mago has 4 skills", m_data.skills.size() == 4)

var s := BattleState.new()
# Setup puts Guerreiro first in TURN_QUEUE[0]
_true("tab_action loads from active hero after advance_turn", s.tab_action.size() > 0)
```

## Arquivos

**Criar:**
- `actions/attacks/atq_arcano.gd`
- `actions/attacks/atq_divino.gd`
- `actions/attacks/atq_soco.gd`
- `actions/skills/skill_segundo_vento.gd`
- `actions/skills/skill_chuva_flechas.gd`
- `actions/skills/skill_cura_area.gd`

**Modificar:**
- `heroes/hero_data.gd` — campos `actions` e `skills`
- `heroes/guerreiro.gd` — popular `actions` e `skills`
- `heroes/mago.gd` — popular `actions` e `skills`
- `heroes/arqueiro.gd` — popular `actions` e `skills`
- `heroes/clerigo.gd` — popular `actions` e `skills`
- `heroes/ladrao.gd` — popular `actions` (com DEX override) e `skills = []`
- `heroes/barbaro.gd` — popular `actions` e `skills = []`
- `battle/battle_state.gd`
  - Remover `static` de `TAB_ACTION` e `TAB_HABILIDADES`
  - Renomear para `tab_action` e `tab_habilidades`
  - Adicionar `_load_hero_actions(name)`
  - Chamar em `setup()` e `advance_turn()`
  - Adicionar verificação de PP em `is_item_available()`
- `battle/battle_scene.gd`
  - Atualizar referências estáticas para `_state.tab_action` / `_state.tab_habilidades`
  - Adicionar handler `elif item is SkillSegundoVento`
- `battle/ui/action_panel.gd` — atualizar referências
- `tests/run_tests.gd` — atualizar referências + novos testes

## Fora do Escopo

- Paladino, Monge (specs separados)
- Inventário por herói
- Skills com cooldown (além do PP de 1 uso)
- Animações ou ícones específicos por herói
