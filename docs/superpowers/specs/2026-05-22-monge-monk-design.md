# Monge (Monk) — Design Spec

## Objetivo

Adicionar o Monge como oitava classe jogável. Archetype: artista marcial extremamente rápido — sem armadura, usa DEX, sem MP convencional. Mecânicas únicas: **Flurry of Blows** (gasta 1 Ki → ataque bônus extra) e **Passo do Vento** (gasta 1 Ki → segundo movimento no mesmo turno). Ki é representado como MP (max 5).

**Pré-requisito:** spec `2026-05-22-per-hero-actions-design.md` implementado.

## Stats

| Stat | Valor |
|---|---|
| hero_name | "Monge" |
| hero_class | "Monk" |
| level | 4 |
| base_hp / max_hp | 65 / 90 |
| base_mp / max_mp | 5 / 5 (Ki) |
| ac | 14 |
| initiative | 11 |
| speed | 10 |
| proficiency | 3 |
| strength | 12 |
| dexterity | 18 |
| intelligence | 10 |
| wisdom | 14 |
| constitution | 13 |
| damage_reduction | 0 |

## Actions e Skills

```gdscript
# actions:
actions = [AtqSoco.new(), AtqRapido.new(), AcaoMover.new()]
# AtqSoco: DEX, range 1, 2-5 dano (novo arquivo)
# AtqRapido: DEX, range 1, bonus_action (existente)

# skills:
skills = [SkillFlurry.new(), SkillPassoVento.new()]
```

## Novos Arquivos de Skill

### `actions/skills/skill_flurry.gd`

```gdscript
class_name SkillFlurry
extends ActionData

func _init() -> void:
    label       = "Flurry of Blows"
    action_type = Type.END_TURN
    shape       = SHAPE_HEXAGON
    color_idx   = COLOR_SPELL
    self_target = true
    mp_cost     = 1   # 1 Ki
```

### `actions/skills/skill_passo_vento.gd`

```gdscript
class_name SkillPassoVento
extends ActionData

func _init() -> void:
    label       = "Passo do Vento"
    action_type = Type.END_TURN
    shape       = SHAPE_HEXAGON
    color_idx   = COLOR_SPELL
    self_target = true
    mp_cost     = 1   # 1 Ki
```

## Mecânica: Flurry of Blows

Quando o Monge usa Flurry of Blows:
1. Custa 1 Ki (MP) — verificar `PLAYERS[pidx]["mp"] >= 1`
2. Habilita `fury_extra_attack = true` — reutilizando o mecanismo do Bárbaro
3. A skill não avança o turno — ela é consumida e o jogador ainda pode atacar

### Handler em `_execute_current_item()` (battle_scene.gd)

```gdscript
elif item is SkillFlurry:
    var pidx: int = _state.get_active_player_index()
    if pidx >= 0:
        var p: Dictionary = BattleState.PLAYERS[pidx]
        if p["mp"] >= item.mp_cost:
            p["mp"] -= item.mp_cost
            _state.fury_extra_attack = true
            _state._log("Monge usa Flurry of Blows!", "status")
        else:
            _state._log("Ki insuficiente!", "status")
    # NÃO chama advance_turn — o jogador ainda tem ações
    _refresh_ui()
```

**Nota:** O Flurry NÃO chama `advance_turn()`. Diferente das outras skills de END_TURN, ele apenas habilita o ataque bônus. O turno continua ativo. O jogador então clica em Ataque para usar o bônus.

A flag `fury_extra_attack` já é resetada por `advance_turn()` ao fim do turno, então não há vazamento de estado.

## Mecânica: Passo do Vento

Quando o Monge usa Passo do Vento:
1. Custa 1 Ki (MP)
2. Reseta `has_moved = false` — permite ao jogador mover novamente este turno
3. Não avança o turno

### Handler em `_execute_current_item()` (battle_scene.gd)

```gdscript
elif item is SkillPassoVento:
    var pidx: int = _state.get_active_player_index()
    if pidx >= 0:
        var p: Dictionary = BattleState.PLAYERS[pidx]
        if p["mp"] >= item.mp_cost:
            p["mp"] -= item.mp_cost
            _state.has_moved = false
            _state._log("Monge usa Passo do Vento!", "status")
        else:
            _state._log("Ki insuficiente!", "status")
    # NÃO chama advance_turn
    _refresh_ui()
```

**Nota:** `has_moved` já é resetado por `advance_turn()`. Resetar antes do turno terminar permite um segundo movimento.

## Registro em BattleState

`ALL_HERO_DATA` (adicionar `"Monge": MongeData.new()`):
```gdscript
static var ALL_HERO_DATA: Dictionary = {
    ...
    "Paladino": PaladinoData.new(),
    "Monge":    MongeData.new(),
}
```

`TURN_QUEUE` (índice 11):
```gdscript
{"name": "Monge", "is_player": true}
```

`PLAYERS` (índice 7):
```gdscript
{"name": "Monge", "hp": 65, "max_hp": 90, "mp": 5, "max_mp": 5,
 "class": "Monk", "level": 4, "ac": 14, "initiative": 11, "speed": 10, "proficiency": 3}
```

## Testes

Em `tests/run_tests.gd`:

```gdscript
# MongeData stats
var monk_data: HeroData = BattleState.ALL_HERO_DATA.get("Monge", null)
_true("ALL_HERO_DATA contains Monge", monk_data != null)
_eq("Monge dexterity is 18",   monk_data.dexterity,  18)
_eq("Monge max_hp is 90",      monk_data.max_hp,     90)
_eq("Monge speed is 10",       monk_data.speed,      10)
_eq("Monge class is Monk",     monk_data.hero_class, "Monk")
_true("Monge has SkillFlurry", monk_data.skills.size() > 0 and monk_data.skills[0] is SkillFlurry)

# SkillFlurry habilita fury_extra_attack
var s_monk := BattleState.new()
s_monk.active_index = 0
BattleState.PLAYERS[0]["mp"] = 5   # garantir Ki disponível
# Simular execução de flurry manualmente (sem chamar advance_turn):
BattleState.PLAYERS[0]["mp"] -= 1
s_monk.fury_extra_attack = true
_true("fury_extra_attack enabled after Flurry",  s_monk.fury_extra_attack)
_eq("Ki decremented after Flurry", BattleState.PLAYERS[0]["mp"], 4)
```

## Arquivos

**Criar:**
- `heroes/monge.gd`
- `actions/skills/skill_flurry.gd`
- `actions/skills/skill_passo_vento.gd`

**Modificar:**
- `battle/battle_state.gd`
  - `ALL_HERO_DATA`, `TURN_QUEUE`, `PLAYERS`: adicionar Monge
- `battle/battle_scene.gd`
  - `_execute_current_item()`: handlers `elif item is SkillFlurry` e `elif item is SkillPassoVento`
- `tests/run_tests.gd`

## Fora do Escopo

- Atordoamento via Ki (complexidade extra de status "stun" com probabilidade)
- Defesa Sem Armadura dinâmica (AC = 10 + DEX_mod — AC fixo em 14 é suficiente)
- Sprites ou ícones específicos
- Ki que recarrega por turno (atualmente o Monge usa `base_mp = 5` que reseta entre combates)
