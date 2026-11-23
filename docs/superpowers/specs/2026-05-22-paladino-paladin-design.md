# Paladino (Paladin) — Design Spec

## Objetivo

Adicionar o Paladino como sétima classe jogável. Archetype: guerreiro divino — melee resistente com suporte a aliados. Mecânicas únicas: **Smite Divino** (buff de dano via MP que se aplica ao próximo ataque) e **Cura das Mãos** (cura single-target por toque).

**Pré-requisito:** spec `2026-05-22-per-hero-actions-design.md` implementado.

## Stats

| Stat | Valor |
|---|---|
| hero_name | "Paladino" |
| hero_class | "Paladin" |
| level | 4 |
| base_hp / max_hp | 80 / 110 |
| base_mp / max_mp | 40 / 60 |
| ac | 16 |
| initiative | 6 |
| speed | 6 |
| proficiency | 3 |
| strength | 16 |
| dexterity | 10 |
| intelligence | 8 |
| wisdom | 14 |
| constitution | 15 |
| damage_reduction | 0 |

## Actions e Skills

```gdscript
# actions:
actions = [AtqDivino.new(), AcaoMover.new()]

# skills:
skills = [SkillSmite.new(), SkillCuraMaos.new()]
```

## Novos Arquivos de Skill

### `actions/skills/skill_smite.gd`

```gdscript
class_name SkillSmite
extends ActionData

func _init() -> void:
    label       = "Smite Divino"
    action_type = Type.END_TURN
    shape       = SHAPE_HEXAGON
    color_idx   = COLOR_SPELL
    self_target = true
    mp_cost     = 15
```

### `actions/skills/skill_cura_maos.gd`

```gdscript
class_name SkillCuraMaos
extends ActionData

func _init() -> void:
    label            = "Cura das Mãos"
    action_type      = Type.ATTACK
    shape            = SHAPE_HEXAGON
    color_idx        = COLOR_SPELL
    attack_range     = 1
    proj_color       = Color(0.30, 1.00, 0.50)
    targets_allies   = true
    self_target      = true
    damage_attribute = DamageAttribute.WIS
    base_damage_min  = 15
    base_damage_max  = 25
    mp_cost          = 20
```

## Mecânica: Smite Divino

### Status `"smite"`

Armazenado em `combatant_statuses[queue_idx]["smite"] = 1`. Consumido no próximo ataque do Paladino. Não decrementa por turno — persiste até ser usado.

### apply_smite_status(player_idx: int) -> void

Novo método em `BattleState` (mesmo padrão de `apply_defender_action` e `apply_fury_status`):
- Recebe índice PLAYERS
- Busca índice TURN_QUEUE pelo nome
- Define `combatant_statuses[i]["smite"] = 1`
- Loga `"Paladino ativa Smite Divino!"`

### Handler em `_execute_current_item()` (battle_scene.gd)

Na branch END_TURN, adicionar após `elif item is AcaoDefender`:

```gdscript
elif item is SkillSmite:
    var pidx: int = _state.get_active_player_index()
    if pidx >= 0:
        var p: Dictionary = BattleState.PLAYERS[pidx]
        if p["mp"] >= item.mp_cost:
            p["mp"] -= item.mp_cost
            _state.apply_smite_status(pidx)
        else:
            _state._log("MP insuficiente para Smite!", "status")
    _state.advance_turn()
```

### Efeito do Smite em `_apply_attack()`

Após o bloco de fury (+4 dano), adicionar:

```gdscript
if combatant_statuses[active_index].get("smite", 0) > 0:
    var smite_bonus: int = randi_range(8, 16)
    combatant_statuses[active_index].erase("smite")
    _log("%s aplica Smite Divino! +%d dano" % [get_active_combatant()["name"], smite_bonus], "status")
    damage += smite_bonus
```

Smite é consumido (`erase`) — aplica apenas uma vez.

### StatusPanel — badge "smite"

Adicionar ao `badge_map` em `_refresh_status_badges()`:

```gdscript
["smite", "Smite", Color(1.0, 0.9, 0.2)]
```

### get_active_status_text()

Adicionar após o bloco de fury:

```gdscript
if status.get("smite", 0) > 0: parts.append("Smite +8-16 dano")
```

## Registro em BattleState

`ALL_HERO_DATA` (adicionar `"Paladino": PaladinoData.new()`):
```gdscript
static var ALL_HERO_DATA: Dictionary = {
    ...
    "Bárbaro":  BarbaroData.new(),
    "Paladino": PaladinoData.new(),
}
```

`TURN_QUEUE` (índice 10):
```gdscript
{"name": "Paladino", "is_player": true}
```

`PLAYERS` (índice 6):
```gdscript
{"name": "Paladino", "hp": 80, "max_hp": 110, "mp": 40, "max_mp": 60,
 "class": "Paladin", "level": 4, "ac": 16, "initiative": 6, "speed": 6, "proficiency": 3}
```

## Testes

Em `tests/run_tests.gd`:

```gdscript
# PaladinoData stats
var pal_data: HeroData = BattleState.ALL_HERO_DATA.get("Paladino", null)
_true("ALL_HERO_DATA contains Paladino", pal_data != null)
_eq("Paladino strength is 16",  pal_data.strength, 16)
_eq("Paladino max_hp is 110",   pal_data.max_hp,   110)
_eq("Paladino class is Paladin", pal_data.hero_class, "Paladin")
_true("Paladino has SkillSmite in skills", pal_data.skills.size() > 0 and pal_data.skills[0] is SkillSmite)

# apply_smite_status
var s_smite := BattleState.new()
s_smite.apply_smite_status(0)  # Guerreiro (PLAYERS[0]) → TURN_QUEUE[0]
_true("apply_smite_status sets smite on queue idx 0",
      s_smite.combatant_statuses[0].get("smite", 0) > 0)

# _apply_attack com smite
var s_pal := BattleState.new()
s_pal.active_index = 0
s_pal.combatant_statuses[0]["smite"] = 1
s_pal.enemy_hp["Goblin Scout"] = 200
for i in range(BattleState.TURN_QUEUE.size()):
    s_pal.combatant_positions[i] = Vector2i(i, 0)
s_pal._apply_attack(1)
_true("smite adds damage (minimum base + prof + 8 = 15)",
      s_pal.last_attack_info.get("amount", 0) >= 15)
_true("smite is consumed after attack",
      s_pal.combatant_statuses[0].get("smite", 0) == 0)
```

## Arquivos

**Criar:**
- `heroes/paladino.gd`
- `actions/skills/skill_smite.gd`
- `actions/skills/skill_cura_maos.gd`

**Modificar:**
- `battle/battle_state.gd`
  - `ALL_HERO_DATA`, `TURN_QUEUE`, `PLAYERS`: adicionar Paladino
  - Método `apply_smite_status(player_idx: int) -> void`
  - `_apply_attack()`: bloco de smite (dano + consume)
- `battle/battle_scene.gd`
  - `_execute_current_item()`: handler `elif item is SkillSmite`
- `battle/ui/status_panel.gd`
  - `_refresh_status_badges()`: badge `"smite"`
- `battle/battle_state.gd`
  - `get_active_status_text()`: linha de smite
- `tests/run_tests.gd`

## Fora do Escopo

- Aura de Proteção passiva (buff de AC para aliados adjacentes)
- Ressurreição de aliados caídos
- Sprites ou ícones específicos
