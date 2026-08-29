# Event Rooms Implementation Design

**Goal:** Implement EVENT room type as a dedicated text-choice scene with mechanical consequences and optional map effects.

**Architecture:** EventData Resource + EventRegistry (follows existing ActionData/HeroData pattern) + EventScene dedicated screen. Three new files, three modified files.

**Tech Stack:** GDScript 4.6, Godot 4.6, code-only (no scene editor).

---

## 1. Data Model

### `dungeon/event_data.gd`

Defines two inner classes and a static registry.

**`EventChoice`** (plain class, not Resource):
- `label: String` — button text
- `consequence_type: int` — value from `ConsequenceType` enum
- `value: int` — magnitude (HP amount, MP amount, buff value, etc.)
- `target: String` — `"party"`, `"random_hero"`, `"weakest_hero"`, `"none"`
- `result_text: String` — shown after the choice is made

**`EventData`** extends `Resource`:
- `id: String`
- `title: String`
- `description: String`
- `choices: Array` — Array of `EventChoice`

**`ConsequenceType` enum** (inside `EventData`):
```
NOTHING, HEAL_PARTY, DAMAGE_PARTY,
HEAL_TARGET, DAMAGE_TARGET,
MP_RESTORE_PARTY, BUFF_NEXT_BATTLE, REVEAL_CONNECTIONS
```

**`EventRegistry`** — static Dictionary `{ id: EventData }` with all 6 events.  
Helper: `static func get_for_node(node_id: int) -> EventData` — uses `abs(node_id) % registry.size()` for deterministic selection.

---

## 2. The 6 Events

| id | Título | Choices | Consequências |
|----|--------|---------|---------------|
| `arcane_fountain` | Fonte Arcana | Beber | `MP_RESTORE_PARTY`, 30% do max_mp de cada herói |
| | | Examinar | `NOTHING` |
| `cursed_altar` | Altar Maldito | Ativar | `BUFF_NEXT_BATTLE` ATK+10 **ou** `DAMAGE_TARGET` random 25 HP (50/50 via rng) |
| | | Destruir | `DAMAGE_PARTY` 10 HP + `BUFF_NEXT_BATTLE` DEF+8 |
| | | Ignorar | `NOTHING` |
| `prisoner` | Prisioneiro | Libertar | `REVEAL_CONNECTIONS` |
| | | Ignorar | `NOTHING` |
| `trapped_chest` | Baú Armadilhado | Abrir com Cuidado | `HEAL_PARTY` 20 HP cada |
| | | Arrombar | `HEAL_PARTY` 35 HP + `DAMAGE_TARGET` random 30 HP |
| `ritual` | Ritual Interrompido | Absorver | `MP_RESTORE_PARTY` 40% max_mp **ou** `DAMAGE_PARTY` 15 HP (50/50) |
| | | Purificar | `NOTHING` (expansível para remover debuffs) |
| `campfire` | Fogueira | Descansar | `HEAL_PARTY` 30 HP + `MP_RESTORE_PARTY` 20 MP cada |
| | | Manter Guarda | `HEAL_TARGET` weakest_hero 60 HP |

---

## 3. DungeonState Changes

**New fields:**
```gdscript
var pending_buffs: Array = []  # list of {"type": String, "value": int}
```

**New method:**
```gdscript
func reveal_extra_connections(from_node_id: int) -> void
# Finds nodes on the same floor as from_node_id and adds one extra
# connection to a node on the next floor that wasn't connected before.
```

**Save/load:** `pending_buffs` serialized as array of dicts in `dungeon_save.json`.  
`complete_current_room()` does NOT clear `pending_buffs` — they persist until consumed by the next battle.

---

## 4. BattleState Changes

`setup()` reads `DungeonState.current_run.pending_buffs` (if not null), applies each buff to the relevant PLAYERS entry, then clears the list.

Buff types supported at launch:
- `"ATK_UP"` — adds `value` to a `bonus_atk` field on all PLAYERS
- `"DEF_UP"` — adds `value` to a `bonus_def` field on all PLAYERS

These fields are read during damage calculation in the existing attack logic.

---

## 5. EventScene

**File:** `ui/event_scene.gd` + `ui/event_scene.tscn`

**Visual structure** (code-only, same dark palette as rest of game):
- Full-screen dark background
- Centered panel (VBoxContainer):
  - Title label (large, gold)
  - Description label (autowrap, medium)
  - Separator
  - 1–3 choice buttons (standard TextureButton style)
- Result area (hidden until choice made):
  - Result text label
  - "Continuar" button → `complete_current_room()` + `fade_to("res://ui/dungeon_map.tscn")`

**Flow:**
1. `_ready()` → calls `EventRegistry.get_for_node(current_node_id)` → renders event
2. Player clicks choice → `_apply_consequence(choice)` runs
3. Choice buttons hidden, result text + Continuar appear
4. Continuar → `DungeonState.current_run.complete_current_room()` + scene transition

**`_apply_consequence(choice: EventChoice)`** handles all `ConsequenceType` values:
- HP/MP changes operate directly on `BattleState.PLAYERS` dicts
- `BUFF_NEXT_BATTLE` pushes to `DungeonState.current_run.pending_buffs`
- `REVEAL_CONNECTIONS` calls `DungeonState.current_run.reveal_extra_connections(node_id)`
- For 50/50 consequences, use `randi() % 2 == 0`; result_text describes which branch occurred

---

## 6. dungeon_map.gd Routing Change

`_on_enter_room()` gains a match on `node.type`:

```gdscript
match node.type:
    DungeonState.RoomType.EVENT:
        SceneTransition.fade_to("res://ui/event_scene.tscn")
    _:
        SceneTransition.fade_to("res://battle/battle_scene.tscn")
```

---

## 7. Out of Scope

- Visual illustrations per event (future art pass)
- Audio/sound effects per event
- MYSTERY room routing (next sub-project)
- Debuff clearing (Purificar no-op for now, marked expansível)
