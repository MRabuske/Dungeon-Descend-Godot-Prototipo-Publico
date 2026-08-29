# Enemy AI, Status Effects & End-Turn Actions — Design Spec

## Goal

Substituir o sistema de IA inimiga baseado em keyword-parsing de strings por um sistema de behaviors tipados, implementar efeitos de status reais (stunned, defending, raging, aiming) e dar efeito mecânico à ação Defender do herói.

## Arquitetura

**Abordagem:** Struct de ação inimiga como `Array[Dictionary]` paralelo ao `action_pool` existente (`action_behaviors`). Status effects em `combatant_statuses` (já existe, sempre vazio). Nenhum arquivo novo — apenas modificações nos arquivos existentes.

**Tech Stack:** GDScript 4.6, Godot 4.6. Sem editor ativo — todo código é code-only.

---

## Seção 1: EnemyData — action_behaviors

### Campo novo em `enemies/enemy_data.gd`

```gdscript
@export var action_behaviors: Array[Dictionary] = []
```

Cada dict descreve mecanicamente uma ação. Índice i do dict corresponde ao índice i do `action_pool`:

```gdscript
{
    "range": int,            # alcance em tiles (manhattan distance). 0 = não ataca
    "damage_mult": float,    # multiplicador sobre randi_range(5,12) + attack_bonus
    "aoe_radius": int,       # 0 = alvo único, 1+ = todos no raio ao redor do alvo/caster
    "is_self_buff": bool,    # não ataca, aplica buff em si mesmo
    "is_flee": bool,         # move-se para longe dos heróis
    "applies_status": String, # "" = nenhum, "stunned" = atordoar
    "status_chance": float,  # probabilidade de aplicar applies_status (0.0–1.0)
    "buff_type": String,     # tipo do self_buff: "raging", "aiming", "teleporting", "rattling"
    "buff_value": int,       # valor numérico do buff
    "buff_turns": int,       # duração do buff em turnos
}
```

### Behaviors por inimigo

**GoblinScout** — foge quando HP < 40%, senão ataca aleatoriamente:
```
action_pool[0] "Attacking %s..."      → {range:1, damage_mult:1.0,  aoe:0, self:false, flee:false, status:"",        chance:0.0, buff:"",           val:0, turns:0}
action_pool[1] "Attacking %s..."      → {range:1, damage_mult:1.0,  aoe:0, self:false, flee:false, status:"",        chance:0.0, buff:"",           val:0, turns:0}
action_pool[2] "Throwing a dagger…"  → {range:3, damage_mult:0.85, aoe:0, self:false, flee:false, status:"",        chance:0.0, buff:"",           val:0, turns:0}
action_pool[3] "Throwing a dagger…"  → {range:3, damage_mult:0.85, aoe:0, self:false, flee:false, status:"",        chance:0.0, buff:"",           val:0, turns:0}
action_pool[4] "Fleeing!"             → {range:0, damage_mult:0.0,  aoe:0, self:false, flee:true,  status:"",        chance:0.0, buff:"",           val:0, turns:0}
```

**OrcWarrior** — usa Raging quando HP < 50% e não está em rage, senão melee:
```
action_pool[0] "Smashing %s..."       → {range:1, damage_mult:1.2,  aoe:0, self:false, flee:false, status:"",        chance:0.0, buff:"",           val:0, turns:0}
action_pool[1] "Smashing %s..."       → {range:1, damage_mult:1.2,  aoe:0, self:false, flee:false, status:"",        chance:0.0, buff:"",           val:0, turns:0}
action_pool[2] "Charging at %s..."    → {range:2, damage_mult:1.5,  aoe:0, self:false, flee:false, status:"stunned", chance:0.2, buff:"",           val:0, turns:0}
action_pool[3] "Charging at %s..."    → {range:2, damage_mult:1.5,  aoe:0, self:false, flee:false, status:"stunned", chance:0.2, buff:"",           val:0, turns:0}
action_pool[4] "Raging!"              → {range:0, damage_mult:0.0,  aoe:0, self:true,  flee:false, status:"",        chance:0.0, buff:"raging",     val:3, turns:2}
```

**DarkMage** — Frost Nova se herói adjacente (dist ≤ 1); Teleport se HP < 30%; senão Shadow Bolt:
```
action_pool[0] "Casting Shadow Bolt…"→ {range:5, damage_mult:1.2,  aoe:0, self:false, flee:false, status:"",        chance:0.0, buff:"",           val:0, turns:0}
action_pool[1] "Casting Shadow Bolt…"→ {range:5, damage_mult:1.2,  aoe:0, self:false, flee:false, status:"",        chance:0.0, buff:"",           val:0, turns:0}
action_pool[2] "Casting Frost Nova!" → {range:1, damage_mult:0.8,  aoe:1, self:false, flee:false, status:"stunned", chance:0.4, buff:"",           val:0, turns:0}
action_pool[3] "Casting Frost Nova!" → {range:1, damage_mult:0.8,  aoe:1, self:false, flee:false, status:"stunned", chance:0.4, buff:"",           val:0, turns:0}
action_pool[4] "Teleporting..."       → {range:0, damage_mult:0.0,  aoe:0, self:true,  flee:false, status:"",        chance:0.0, buff:"teleporting",val:0, turns:0}
```

**SkeletonArcher** — Aiming se herói > 3 tiles e não está aiming; senão Arrow:
```
action_pool[0] "Shooting an arrow…" → {range:5, damage_mult:1.0,  aoe:0, self:false, flee:false, status:"",        chance:0.0, buff:"",           val:0, turns:0}
action_pool[1] "Shooting an arrow…" → {range:5, damage_mult:1.0,  aoe:0, self:false, flee:false, status:"",        chance:0.0, buff:"",           val:0, turns:0}
action_pool[2] "Aiming at %s..."     → {range:0, damage_mult:0.0,  aoe:0, self:true,  flee:false, status:"",        chance:0.0, buff:"aiming",     val:2, turns:1}
action_pool[3] "Aiming at %s..."     → {range:0, damage_mult:0.0,  aoe:0, self:true,  flee:false, status:"",        chance:0.0, buff:"aiming",     val:2, turns:1}
action_pool[4] "Rattling bones..."   → {range:0, damage_mult:0.0,  aoe:0, self:true,  flee:false, status:"",        chance:0.0, buff:"rattling",   val:0, turns:0}
```

---

## Seção 2: Sistema de Status Effects

### Estrutura em `battle_state.gd`

`combatant_statuses: Array` (já existe) passa a conter dicts:
```gdscript
{ "idx": int, "type": String, "turns": int, "value": int }
```

### Tipos de status

| type | Efeito mecânico | Aplicado por | Duração |
|---|---|---|---|
| `"stunned"` | Pula o turno completo | Orc Charging (20%), Frost Nova (40%), Atq Normal jogador (20%) | 1 turno |
| `"defending"` | +value de AC contra próximo ataque inimigo | Ação Defender do herói | 1 turno (expira no próximo turno do herói) |
| `"raging"` | +value ao dano em todos os ataques do Orc | Orc Raging | 2 turnos |
| `"aiming"` | +value ao alcance e ignora bônus de cobertura | Skeleton Aiming | 1 turno |

### Funções novas em `battle_state.gd`

```gdscript
func add_status(idx: int, type: String, turns: int, value: int) -> void
func get_statuses_for(idx: int) -> Array  # retorna lista de dicts do combatente
func has_status(idx: int, type: String) -> bool
func remove_status(idx: int, type: String) -> void
func process_turn_start(idx: int) -> bool  # retorna true se turno foi pulado (stunned)
```

### Processamento no início de cada turno

```
process_turn_start(active_index):
  1. Para cada status do combatente:
     - Se "stunned": loga "X ficou atordoado e perdeu o turno", decrementa turns, retorna true (skip)
     - Se "defending": decrementa turns (expira ao próprio turno chegar)
     - Se "raging": decrementa turns
     - Se "aiming": decrementa turns
  2. Remove statuses com turns <= 0
  3. Retorna false (turno normal)
```

### Integração com `apply_enemy_attack()`

- Lê behavior dict do `active_enemy_action_idx` para obter `damage_mult`, `aoe_radius`, `applies_status`, `status_chance`
- Dano base: `randi_range(5, 12) + attack_bonus` → multiplicado por `damage_mult`
- Se alvo tem status `"defending"`: AC efetivo += status.value para esse ataque
- Se alvo tem status de "raging" no Orc: `damage_mult` já está no behavior (não acumula com raging, raging é separado)
- Se enemy tem status `"raging"`: adiciona `status.value` ao dano final
- Se `applies_status != ""` e `randf() < status_chance`: `add_status(target_idx, applies_status, 1, 0)`
- Se `aoe_radius > 0`: aplica dano a todos os heróis vivos dentro do raio ao redor do caster (Frost Nova) ou do alvo

### Integração com `apply_enemy_move()` — Teleport

Quando `buff_type == "teleporting"`: posiciona o inimigo no tile mais distante de todos os heróis vivos que esteja livre de obstáculos e ocupantes.

### Integração com ações do herói

**Defender** (`acao_defender.gd` → `BattleState.apply_defender_action(player_idx)`):
- Adiciona `{idx: player_idx, type: "defending", turns: 1, value: 2}` a `combatant_statuses`
- Encerra turno do herói

**Esperar / Fugir**: encerram turno sem efeito adicional (comportamento atual mantido).

---

## Seção 3: StatusPanel — exibição de status

### Modificação em `battle/ui/status_panel.gd`

Nova função `_refresh_status_badges(statuses: Array)` chamada dentro do `refresh()` existente.

Renderiza uma linha horizontal de `Label` coloridos abaixo das stats existentes:

| status | Texto | Cor |
|---|---|---|
| `defending` | `Defender +2 AC` | `Color(0.3, 0.6, 1.0)` |
| `stunned` | `Atordoado` | `Color(1.0, 0.9, 0.2)` |
| `raging` | `Furia +3 dano` | `Color(1.0, 0.3, 0.2)` |
| `aiming` | `Mirando +2 alc` | `Color(0.6, 1.0, 0.6)` |

Se não houver status ativos, a linha fica vazia (sem ocupar espaço visual desnecessário).

`refresh()` em `battle_scene.gd` já chama `_status_panel.refresh(combatant)` — a modificação é apenas interna ao `status_panel.gd`, passando o array de statuses via `BattleState.get_statuses_for(active_index)`.

---

## Seção 4: battle_scene.gd — integração de turno

### Modificações

**`_do_enemy_turn()`** — antes de qualquer movimento/ataque:
```gdscript
if _state.process_turn_start(_state.active_index):
    # stunned: log já foi feito em process_turn_start
    _end_turn_delayed()
    return
```

**`_on_turn_changed()`** (turno do herói) — antes de mostrar ações:
```gdscript
if _state.process_turn_start(_state.active_index):
    _battle_area.show_transition("Atordoado!\n" + combatant_name, func() -> void:
        _state.advance_turn()
        _on_turn_changed()
    )
    return
```

**`_execute_current_item()`** — caso `AcaoDefender`:
```gdscript
ActionData.Type.END_TURN:
    if item is AcaoDefender:
        _state.apply_defender_action(_state.active_player_index())
    _state.advance_turn()
```

---

## Seção 5: Lógica de decisão por inimigo — `_pick_enemy_action_idx()`

Nova função em `BattleState` substituindo `_roll_enemy_action()`:

```gdscript
func _pick_enemy_action_idx() -> int:
    var enemy := get_active_combatant()
    var enemy_type: String = enemy.get("type", "Goblin")
    var edata := ALL_ENEMIES.get(enemy_type, null) as EnemyData
    if edata == null:
        return 0
    var hp_ratio: float = float(enemy_hp.get(active_index, edata.max_hp)) / float(edata.max_hp)

    match enemy_type:
        "Goblin":
            if hp_ratio < 0.40:
                return 4  # Fleeing!
        "Orc":
            if hp_ratio < 0.50 and not has_status(active_index, "raging"):
                return 4  # Raging!
        "Mage":
            if _closest_hero_distance() <= 1:
                return randi_range(2, 3)  # Frost Nova
            if hp_ratio < 0.30:
                return 4  # Teleporting
        "Undead":
            if _closest_hero_distance() > 3 and not has_status(active_index, "aiming"):
                return randi_range(2, 3)  # Aiming

    # Fallback: sorteio aleatório entre as ações de ataque (índices 0-1)
    return randi() % 2
```

Função auxiliar:
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
```

---

## Restrições

- O editor Godot não está ativo — nenhum teste via editor, apenas lógica de código
- Nenhum arquivo novo — apenas modificações nos arquivos listados
- Manter compatibilidade com `enemy_action_text` para exibição no log (o texto ainda é formatado a partir do `action_pool[idx]`)
