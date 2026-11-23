# Mystery Rooms Design

**Goal:** Implement MYSTERY room type as a randomised outcome scene reusing the existing EventScene and EventData infrastructure.

**Architecture:** A new `MysteryRegistry` static class resolves a deterministic random outcome per node. Four outcomes (event/treasure/battle/curse) are each returned as an `EventData`. EventScene detects MYSTERY rooms and uses `MysteryRegistry.resolve()` instead of `EventData.get_for_node()`. A new `GO_TO_BATTLE` consequence type redirects to battle without completing the room.

**Tech Stack:** GDScript 4.6, Godot 4.6, code-only.

---

## File Map

| File | Status | Change |
|------|--------|--------|
| `dungeon/event_data.gd` | Modify | Add `GO_TO_BATTLE = 8` to `ConsequenceType` enum |
| `dungeon/mystery_registry.gd` | Create | Static `resolve(node_id)` + 4 outcome builders |
| `ui/event_scene.gd` | Modify | `_go_to_battle` flag; MYSTERY detection in `_ready()`; GO_TO_BATTLE in `_apply_one`; flag check in `_on_choice` |
| `ui/dungeon_map.gd` | Modify | Add `MYSTERY` branch to routing match |

---

## 1. ConsequenceType extension

Add `GO_TO_BATTLE = 8` to the existing `ConsequenceType` enum in `dungeon/event_data.gd`.

When this consequence is applied in `_apply_one()`, it sets a `_go_to_battle: bool` flag on the EventScene. `_on_choice()` checks this flag immediately after applying consequences — if true, it calls `SceneTransition.fade_to("res://battle/battle_scene.tscn")` and returns, skipping the result screen and `complete_current_room()`. The battle scene handles room completion on win as usual.

---

## 2. MysteryRegistry (`dungeon/mystery_registry.gd`)

Static class (no `extends`, uses RefCounted implicitly).

### Outcome weights

| Range | Probability | Outcome |
|-------|-------------|---------|
| 0–39  | 40% | Random event from `EventData.REGISTRY` |
| 40–69 | 30% | Treasure |
| 70–89 | 20% | Battle surprise |
| 90–99 | 10% | Curse |

### Seed

```gdscript
rng.seed = abs(node_id) * 31337 + 42
```

Deterministic per node — same mystery room always yields the same outcome, even after save/load.

### Outcome EventData

**Evento (40%)** — returns `EventData.REGISTRY[keys[rng.randi() % keys.size()]]`

**Tesouro (30%):**
- Title: "Tesouro Escondido"
- Desc: "Atrás de uma parede falsa, vocês encontram provisões escondidas."
- Choice: "Pegar" → HEAL_PARTY 40 + MP_RESTORE_PARTY 30 (compound, is_random=false)
- result_text: "A party recolhe as provisões. Todos curam 40 HP."
- secondary_text: "Todos recuperam 30 MP."

**Batalha (20%):**
- Title: "Encontro Inesperado!"
- Desc: "Uma criatura surge das sombras. Não há tempo para negociar."
- Choice: "Entrar em Combate" → GO_TO_BATTLE (no secondary, no result_text needed)

**Maldição (10%):**
- Title: "Armadilha Arcana"
- Desc: "Uma armadilha mágica dispara ao pisarem na sala. Energia negativa envolve a party."
- Choice: "Aceitar o destino" → DAMAGE_PARTY 20 + BUFF_NEXT_BATTLE value=-5 target="ATK_UP" (compound)
- result_text: "A armadilha debilita a party. Todos perdem 20 HP."
- secondary_text: "ATK -5 na próxima batalha."

Note: `BUFF_NEXT_BATTLE` with value=-5 and target="ATK_UP" pushes `{"type":"ATK_UP","value":-5}` to `pending_buffs`. In `BattleState.setup()`, `p["bonus_atk"] += -5` reduces player damage by 5. No BattleState code changes needed — `_roll_player_damage` already adds `bonus_atk` which can be negative.

---

## 3. EventScene changes (`ui/event_scene.gd`)

### New field
```gdscript
var _go_to_battle: bool = false
```

### `_ready()` — MYSTERY detection
After resolving `node_id`, check the room type:
```gdscript
var node: DungeonState.RoomNode = null
if DungeonState.current_run != null:
    node = DungeonState.current_run.get_node_by_id(node_id)
if node != null and node.type == DungeonState.RoomType.MYSTERY:
    _event = MysteryRegistry.resolve(node_id)
else:
    _event = EventData.get_for_node(node_id)
```

### `_apply_one()` — new GO_TO_BATTLE branch
```gdscript
C.GO_TO_BATTLE:
    _go_to_battle = true
```

### `_on_choice()` — flag check after consequences, before result display
```gdscript
if _go_to_battle:
    SceneTransition.fade_to("res://battle/battle_scene.tscn")
    return
```
Placed after consequence application and before hiding buttons / showing result.

---

## 4. dungeon_map routing

In `_on_enter_room()`, the existing match:
```gdscript
match node.type:
    DungeonState.RoomType.EVENT:
        SceneTransition.fade_to("res://ui/event_scene.tscn")
    _:
        SceneTransition.fade_to("res://battle/battle_scene.tscn")
```

Add MYSTERY:
```gdscript
match node.type:
    DungeonState.RoomType.EVENT, DungeonState.RoomType.MYSTERY:
        SceneTransition.fade_to("res://ui/event_scene.tscn")
    _:
        SceneTransition.fade_to("res://battle/battle_scene.tscn")
```

---

## Out of scope

- Visual differentiation of mystery outcome type before player commits (intentional — the unknown is the feature)
- Enemy scaling inside the mystery battle (covered by point 3 of the roadmap)
- Audio/sound effects per outcome
