# Elite/Boss Scaling Design

**Goal:** ELITE and BOSS rooms have distinct enemy compositions with purpose-built EnemyData subclasses. ELITE presents 2 powerful enemies; BOSS presents 1 massive guardian with AOE mechanics and self-buffs.

**Architecture:** Three new EnemyData subclasses (EliteWarrior, EliteMage, DungeonGuardian) registered in `BattleState.ALL_ENEMIES`. A new static `BattleState.setup_enemies_for_room(room_type)` rebuilds the enemy portion of `TURN_QUEUE` before `BattleState.new()` is called. `BattleScene` reads the current room type from `DungeonState` and calls this method before instantiating the state.

**Tech Stack:** GDScript 4.6, Godot 4.6, code-only. Branch: `feature/elite-boss-scaling`.

---

## Compositions

| Room | Enemies | Feel |
|------|---------|------|
| BATTLE | Goblin Scout + Orc Warrior + Dark Mage + Skeleton Archer (unchanged) | Standard mix |
| ELITE | Elite Warrior + Elite Mage | 2 tough enemies, high sustained threat |
| BOSS | Dungeon Guardian | 1 massive enemy with big AOE and self-buff |

---

## New Enemy Data

### EliteWarriorData (`enemies/elite_warrior.gd`)

```
enemy_name = "Elite Warrior"   enemy_type = "EliteWarrior"
ac = 17   max_hp = 70   speed = 4   attack_bonus = 7
sprites: reuses orc_warrior assets
```

Action pool & behaviors (5 cycling):
1. "Crushing Blow on %s..." — range 1, mult 1.4
2. "Crushing Blow on %s..." — range 1, mult 1.4
3. "Sweeping Strike!" — range 1, mult 1.0, aoe_radius 1
4. "Charging at %s..." — range 2, mult 1.6, applies_status "stunned", status_chance 0.25
5. "Enraging!" — is_self_buff true, buff_type "raging", buff_value 4, buff_turns 2

### EliteMageData (`enemies/elite_mage.gd`)

```
enemy_name = "Elite Mage"   enemy_type = "EliteMage"
ac = 13   max_hp = 55   speed = 5   attack_bonus = 8
sprites: reuses dark_mage assets
```

Action pool & behaviors (5 cycling):
1. "Casting Arcane Bolt at %s..." — range 6, mult 1.4
2. "Casting Arcane Bolt at %s..." — range 6, mult 1.4
3. "Casting Ice Storm!" — range 2, mult 1.0, aoe_radius 2, applies_status "stunned", status_chance 0.30
4. "Casting Ice Storm!" — range 2, mult 1.0, aoe_radius 2, applies_status "stunned", status_chance 0.30
5. "Channeling dark power..." — is_self_buff true, buff_type "raging", buff_value 3, buff_turns 2

### DungeonGuardianData (`enemies/dungeon_guardian.gd`)

```
enemy_name = "Dungeon Guardian"   enemy_type = "DungeonGuardian"
ac = 18   max_hp = 180   speed = 3   attack_bonus = 9
sprites: reuses orc_warrior assets
```

Action pool & behaviors (6 cycling):
1. "Guardian Smash on %s..." — range 1, mult 1.6
2. "Guardian Smash on %s..." — range 1, mult 1.6
3. "Shockwave!" — range 1, mult 1.2, aoe_radius 2
4. "Shockwave!" — range 1, mult 1.2, aoe_radius 2
5. "Enraging!" — is_self_buff true, buff_type "raging", buff_value 5, buff_turns 3
6. "Ground Slam at %s..." — range 2, mult 2.0, applies_status "stunned", status_chance 0.40

---

## BattleState changes

### ALL_ENEMIES — add 3 new types

```gdscript
static var ALL_ENEMIES: Dictionary = {
    "Goblin":           GoblinScoutData.new(),
    "Orc":              OrcWarriorData.new(),
    "Mage":             DarkMageData.new(),
    "Undead":           SkeletonArcherData.new(),
    "EliteWarrior":     EliteWarriorData.new(),
    "EliteMage":        EliteMageData.new(),
    "DungeonGuardian":  DungeonGuardianData.new(),
}
```

### setup_enemies_for_room(room_type) — new static method

Strips all enemy entries from `TURN_QUEUE` (keeps only `is_player == true`), then appends enemy entries for the given room type.

```gdscript
static func setup_enemies_for_room(room_type: int) -> void:
    TURN_QUEUE = TURN_QUEUE.filter(func(e: Dictionary) -> bool:
        return e.get("is_player", false))

    var enemy_keys: Array
    match room_type:
        DungeonState.RoomType.ELITE:
            enemy_keys = ["EliteWarrior", "EliteMage"]
        DungeonState.RoomType.BOSS:
            enemy_keys = ["DungeonGuardian"]
        _:
            enemy_keys = ["Goblin", "Orc", "Mage", "Undead"]

    for key in enemy_keys:
        var edata: EnemyData = ALL_ENEMIES.get(key, null)
        if edata != null:
            TURN_QUEUE.append({
                "name": edata.enemy_name,
                "is_player": false,
                "type": edata.enemy_type,
                "ac": edata.ac,
            })
```

Must be called BEFORE `BattleState.new()` because `_init()` reads `TURN_QUEUE` to build `enemy_hp` and `combatant_positions`.

---

## BattleScene changes

### New helper `_get_current_room_type()`

```gdscript
func _get_current_room_type() -> int:
    if DungeonState.current_run == null:
        return DungeonState.RoomType.BATTLE
    var node: DungeonState.RoomNode = DungeonState.current_run.get_node_by_id(
        DungeonState.current_run.current_node_id)
    if node == null:
        return DungeonState.RoomType.BATTLE
    return node.type
```

### `_ready()` — call setup_enemies_for_room before new()

Add before `_state = BattleState.new()`:
```gdscript
BattleState.setup_enemies_for_room(_get_current_room_type())
```

### `_initialize_state()` — update context panel per room type

Replace the hardcoded `_context_panel.setup("Battle Arena", "Procedural Map", "Explore the terrain.")` with:

```gdscript
const ROOM_TITLES := {
    DungeonState.RoomType.BATTLE: "Batalha",
    DungeonState.RoomType.ELITE:  "Batalha Elite",
    DungeonState.RoomType.BOSS:   "CHEFE DO DUNGEON",
}
var rtype := _get_current_room_type()
var floor_lbl := ""
if DungeonState.current_run != null:
    var node := DungeonState.current_run.get_node_by_id(
        DungeonState.current_run.current_node_id)
    if node != null:
        floor_lbl = "Boss" if node.floor == DungeonState.FLOOR_COUNT - 1 \
            else "Andar %d" % (node.floor + 1)
_context_panel.setup(
    ROOM_TITLES.get(rtype, "Batalha"),
    floor_lbl if floor_lbl != "" else "Dungeon",
    "Prepare-se para o combate.")
```

---

## Out of scope

- New sprite/portrait assets for elite and boss (reuse orc/mage assets for now)
- Loot/rewards after elite/boss battles
- Boss HP bar UI (standard enemy HP display unchanged)
