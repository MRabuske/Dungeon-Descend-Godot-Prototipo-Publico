# Bárbaro (Barbarian) — Design Spec

## Objetivo

Adicionar o Bárbaro como sexta classe jogável. Archetype: o mais resistente do grupo, zero magia, entra em Fúria automaticamente ao atingir HP crítico — ganhando +dano e segundo ataque, ao custo de AC baixa.

## Stats

| Stat | Valor |
|---|---|
| hero_name | "Bárbaro" |
| hero_class | "Barbarian" |
| level | 4 |
| base_hp / max_hp | 95 / 120 |
| base_mp / max_mp | 0 / 0 |
| ac | 12 |
| initiative | 7 |
| speed | 6 |
| proficiency | 3 |
| strength | 20 |
| dexterity | 8 |
| intelligence | 6 |
| wisdom | 8 |
| constitution | 18 |
| damage_reduction | 1 |

## Campo novo em HeroData

Adicionar `@export var damage_reduction: int = 0` em `heroes/hero_data.gd`. Todos os heróis existentes ficam com o valor padrão 0, sem efeito no comportamento atual.

## Mecânica: Resistência (redução de dano passiva)

Em `apply_enemy_attack()` em `battle_state.gd`, após calcular o dano final sobre um alvo player:

1. Buscar `hdata := ALL_HERO_DATA.get(target_name, null) as HeroData`
2. Se `hdata == null` ou `hdata.damage_reduction == 0`: sem redução
3. Calcular redução:
   - Se alvo tem `combatant_statuses[target_queue_idx].get("fury", 0) > 0`: redução = **2**
   - Senão: redução = `hdata.damage_reduction` (Bárbaro = 1; outros = 0)
4. Aplicar: `damage = maxi(1, damage - reducao)`

Sem badge visual — a resistência é passiva e sempre ativa.

## Mecânica: Fúria

### Status `"fury"`

Armazenado em `combatant_statuses[queue_idx]["fury"] = 1`. **Não decrementa por turno** — permanece pelo resto do combate uma vez ativado.

### apply_fury_status(player_idx: int) -> void

Novo método em `BattleState` (mesmo padrão de `apply_defender_action` e `apply_furtivo_status`):
- Recebe índice PLAYERS
- Busca o índice TURN_QUEUE pelo nome
- Define `combatant_statuses[i]["fury"] = 1`
- Define `fury_extra_attack = true`
- Loga `"Bárbaro entra em Fúria!"`

### Trigger automático

No início do turno do Bárbaro, em `battle_scene.gd` dentro de `_on_turn_changed()` (processamento de turno do player), **após** o check de stunned:

```gdscript
var pidx: int = _state.get_active_player_index()
if pidx >= 0:
    var p: Dictionary = BattleState.PLAYERS[pidx]
    if p["class"] == "Barbarian" and not _state.has_fury(pidx):
        if float(p["hp"]) / float(p["max_hp"]) < 0.5:
            _state.apply_fury_status(pidx)
```

### has_fury(player_idx: int) -> bool

Método auxiliar em `BattleState`:
- Busca queue_idx do player por nome
- Retorna `combatant_statuses[queue_idx].get("fury", 0) > 0`

### Efeitos da Fúria

**+4 dano em ataques:**
Em `_apply_attack()`, na branch `else` (dano), após o crit e sneak attack:

```gdscript
if combatant_statuses[active_index].get("fury", 0) > 0:
    damage += 4
```

O status `"fury"` NÃO é consumido — permanece.

**Segundo ataque:**
Nova variável `var fury_extra_attack: bool = false` em `BattleState`.

- Definida como `true` em `apply_fury_status()`
- Definida como `true` no início de cada turno do Bárbaro em fúria (em `_on_turn_changed()`, após o trigger de fúria)
- Em `is_item_available()` para `ActionData.Type.ATTACK`:
  ```gdscript
  if action.action_type == ActionData.Type.ATTACK and has_attacked:
      return action.bonus_action or fury_extra_attack
  ```
- Consumida (`false`) após o segundo ataque: em `_apply_attack()`, se `has_attacked` já era `true` quando o ataque foi confirmado (i.e., é o segundo ataque), setar `fury_extra_attack = false`

  Detecção do segundo ataque: verificar `has_attacked` no início de `_apply_attack()` e guardar em variável local. Após o ataque, se `was_attacked` era `true` (era o segundo ataque), consumir `fury_extra_attack`.

- Resetada em `advance_turn()` (ao mudar o combatente ativo): `fury_extra_attack = false`

### StatusPanel

Adicionar ao `badge_map` em `_refresh_status_badges()`:

| Chave | Texto | Cor |
|---|---|---|
| `"fury"` | `"Fúria"` | `Color(1.0, 0.2, 0.0)` |

## Arquivos

**Criar:**
- `heroes/barbaro.gd` — `class_name BarbaroData extends HeroData`

**Modificar:**
- `heroes/hero_data.gd` — campo `damage_reduction: int = 0`
- `battle/battle_state.gd`
  - `ALL_HERO_DATA`: adicionar `"Bárbaro": BarbaroData.new()`
  - `TURN_QUEUE` padrão: Bárbaro no final (índice 9)
  - `PLAYERS` padrão: Bárbaro no final (índice 5)
  - Campo: `var fury_extra_attack: bool = false`
  - Método: `apply_fury_status(player_idx: int) -> void`
  - Método: `has_fury(player_idx: int) -> bool`
  - `advance_turn()`: resetar `fury_extra_attack = false` ao mudar combatente
  - `is_item_available()`: incluir `fury_extra_attack` na condição de ATTACK
  - `_apply_attack()`: +4 dano em fúria, consumir `fury_extra_attack` no segundo ataque
  - `apply_enemy_attack()`: aplicar `damage_reduction` do alvo player
- `battle/battle_scene.gd`
  - `_on_turn_changed()`: trigger automático de fúria
- `battle/ui/status_panel.gd`
  - `_refresh_status_badges()`: badge `"fury"`
- `tests/run_tests.gd`
  - Teste: `BarbaroData` stats corretos (STR 20, HP 95, damage_reduction 1)
  - Teste: `apply_fury_status` define `combatant_statuses[queue_idx]["fury"] == 1`
  - Teste: `_apply_attack()` com fury adiciona +4 ao dano
  - Teste: `fury_extra_attack` permite segundo ataque via `is_item_available()`

## Fora do Escopo

- Alterações em `party_select.gd` (já itera `ALL_HERO_DATA` automaticamente)
- Sprites ou ícones (projeto code-only sem editor ativo)
- Fúria manual (é sempre automática ao <50% HP)
- Rage quit / saída de fúria
