# Ladrao (Rogue) — Design Spec

## Objetivo

Adicionar o Ladrao como quinta classe jogável. Archetype: alta mobilidade, burst damage via Ataque Furtivo, fragilidade como trade-off.

## Stats

| Stat | Valor |
|---|---|
| hero_name | "Ladrao" |
| hero_class | "Rogue" |
| level | 4 |
| base_hp / max_hp | 55 / 100 |
| base_mp / max_mp | 20 / 40 |
| ac | 13 |
| initiative | 9 |
| speed | 9 |
| proficiency | 3 |
| strength | 10 |
| dexterity | 18 |
| intelligence | 12 |
| wisdom | 11 |
| constitution | 11 |

## Mecânica: Ataque Furtivo

**Status `"furtivo"`** — armazenado em `combatant_statuses[queue_idx]["furtivo"] = 1`. Não decrementa por turno; só é consumido ao atacar.

### Quando é aplicado

1. **Início do combate:** `setup()` em `battle_state.gd` itera o `TURN_QUEUE` e, para cada entrada com `is_player == true` cujo nome corresponda a um herói com `hero_class == "Rogue"` em `ALL_HERO_DATA`, aplica `combatant_statuses[i]["furtivo"] = 1`.

2. **Após AcaoEsperar:** `_execute_current_item()` em `battle_scene.gd`, no branch do `AcaoEsperar`, checa se o player ativo tem `class == "Rogue"` (via `PLAYERS[get_active_player_index()]["class"]`) e chama `_state.apply_furtivo_status(player_idx)`.

### apply_furtivo_status(player_idx: int) -> void

Novo método em `BattleState`:
- Recebe índice PLAYERS
- Busca o índice TURN_QUEUE pelo nome (mesmo padrão de `apply_defender_action`)
- Define `combatant_statuses[i]["furtivo"] = 1`
- Loga `"X está em posição furtiva"`

### Quando é consumido

Em `apply_player_attack()` em `battle_state.gd`, após calcular o dano base e antes de aplicá-lo:
- Se `combatant_statuses[attacker_queue_idx].get("furtivo", 0) > 0`:
  - Gera bônus: `var sneak := randi_range(3, 8)`
  - Adiciona ao dano total
  - Remove: `combatant_statuses[attacker_queue_idx].erase("furtivo")`
  - Loga `"Ataque Furtivo! +X dano"`

O índice `attacker_queue_idx` é o índice TURN_QUEUE do player ativo (já disponível como `active_index` quando é turno do player).

## StatusPanel

Adicionar ao `badge_map` em `_refresh_status_badges()` em `status_panel.gd`:

| Chave | Texto | Cor |
|---|---|---|
| `"furtivo"` | `"Furtivo"` | `Color(0.7, 0.4, 1.0)` |

## Arquivos

**Criar:**
- `heroes/ladrao.gd` — `class_name LadraoData extends HeroData`, stats acima

**Modificar:**
- `battle/battle_state.gd`
  - `ALL_HERO_DATA`: adicionar `"Ladrao": LadraoData.new()`
  - `TURN_QUEUE` padrão: adicionar entrada para o Ladrao
  - `setup()`: inicializar `furtivo` para o Ladrao se estiver no party
  - Novo método `apply_furtivo_status(player_idx: int) -> void`
  - `apply_player_attack()`: consumir `furtivo` e aplicar bônus de dano
- `battle/battle_scene.gd`
  - `_execute_current_item()`: ao detectar `AcaoEsperar`, checar classe Rogue e chamar `apply_furtivo_status`
- `battle/ui/status_panel.gd`
  - `_refresh_status_badges()`: adicionar entrada `"furtivo"` ao badge_map
- `tests/run_tests.gd`
  - Teste: `LadraoData` stats corretos (speed 9, DEX 18, HP 55)
  - Teste: `apply_furtivo_status` define `combatant_statuses[queue_idx]["furtivo"] == 1`
  - Teste: `apply_player_attack()` consome `furtivo` e aumenta dano

## Fora do Escopo

- Alterações em `party_select.gd` (já itera `ALL_HERO_DATA` automaticamente)
- Sprites ou ícones (projeto é code-only sem editor ativo)
- Habilidades além do Ataque Furtivo
