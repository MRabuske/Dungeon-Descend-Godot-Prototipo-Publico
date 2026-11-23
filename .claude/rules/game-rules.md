---
paths:
  - "battle/**"
  - "actions/**"
  - "heroes/**"
  - "enemies/**"
  - "items/**"
  - "dungeon/**"
  - "tests/**"
---
# Rules reference: the single source of truth

Other files point here. Do not copy these rules elsewhere.

## Who decides what

| Area | Reference |
|---|---|
| **Combat system**: action economy (Action, Bonus Action, Reaction), movement, Shove, Jump, Dash, Disengage, drinking potions, turns, attack vs AC, saving throws, crits, advantage/disadvantage, damage types, resistances/vulnerabilities/immunities, conditions, concentration, Downed and death saves, opportunity attacks, surfaces, tactical interactions | **Baldur's Gate 3**, in full, except the approved exceptions below. Check bg3.wiki. |
| **Classes, subclasses, levels, attributes, proficiencies, feats, spell slots, Pact Magic, spells, cantrips, spell preparation, class resources, species, progression** | **D&D 5e, 2024 revision** (PHB/DMG 2024). D&D 2014 is secondary: never mix 2014 and 2024 without user approval. |
| **Grid and distances** | Tabletop D&D (see "Grid and distances"). |
| **Homebrew** | Allowed (own classes such as the Pirate, items, boons, roguelike systems, DLCs). Always identified as homebrew, never presented as an official rule. |

Classes that BG3 does not have (for example the Artificer) may be added with user approval.

## How to resolve doubts

- BG3 is not D&D. Never assume a 5e or 2024 rule for combat, and never assume a BG3 rule for characters beyond what BG3 has.
- For combat, look it up on bg3.wiki (WebFetch/WebSearch) before coding and name the page in the plan or commit message.
- For characters, spells and progression, verify against D&D 2024.
- When a spell or feature differs between D&D 2024 and BG3 and the difference changes combat, name the difference and ask the user. Do not choose silently.
- If the source is silent or ambiguous, ask the user. Never fall back silently to another edition or reference.
- Do not invent BG3 class extensions for levels BG3 does not have.
- Where the game already deviates on purpose (no MP, slot-based spells, Ki for the Monk), keep the existing behavior.

## Approved exceptions to BG3

- **Initiative = 1d20 + DEX modifier + applicable bonuses (the D&D 2024 rule), not BG3's 1d4.** Reason: it scales better over a long roguelike progression. Bonuses must be calibrated for a d20, not copied from BG3; they enter through `BattleState._initiative_bonus()` (features and effects only: there is no fixed per-character initiative value). The current code (`BattleState.roll_initiative()`, d20 + DEX + bonus, higher DEX breaks ties) is correct and must not be changed back to d4.

## Project decisions (combat, on top of BG3)

Kept on purpose; the table of what was checked and what is pending is in `docs/architecture/battle.md`.

- **Disengage lasts the whole turn against every enemy.** Opportunity Attacks are checked **per step** of a path.
- **Potion:** a Potion of Healing (2d4+2): Bonus Action to drink, Action to throw (the cloud heals anyone in it). There is no "give" action; heal an ally by throwing it. The Ether (restores a spell slot) was removed: BG3 has none.
- **Spells add no attribute modifier to damage** (BG3 "Damage"); weapon and physical attacks do. `ActionData.is_spell` marks the spells.
- **AI target priority vs Downed heroes (BG3 not verified):** when a Downed and a standing hero are both in reach, the enemy picks the Downed one 50% of the time (rolled through `DiceRoller`), otherwise the lowest-HP hero.
- **Frightened cannot move** (bg3.wiki "Frightened").

## Grid and distances

- 1 square = 5 ft ≈ 1.5 m (game convention).
- D&D 2024 (feet): squares = feet ÷ 5 (30 ft = 6). BG3 (metres): squares = metres ÷ 1.5 (9 m = 6).
- This applies to movement, range, spells, areas, shoves, jumps and forced movement.
- A value that does not give a whole number of squares: point it out and ask the user. Never round silently.
- **One distance metric: Chebyshev (diagonal = 1 square)** for everything that measures proximity: melee reach (the 8 squares around the target), ranges, Opportunity Attacks, Disengage, Sneak Attack's adjacent ally, AI target choice. Map generation keeps Manhattan only to separate spawn points (not a rule).
- **Movement is in 8 directions** (D&D 2024 "Playing on a Grid"): each square entered costs 1 square (5 ft), the diagonal too; difficult terrain (mud, the Ice surface) costs 2, also diagonally. A diagonal cannot cross the corner of a square that an object fills (Obstacle, Statue, Cover); creatures and holes do not block the diagonal. Heroes and enemies use the same pathfinder (`BattleState._search_movement`), including the enemy AI.
- **Moving through creatures:** you can pass through an ally's square (no extra cost: D&D 2024 makes another creature's space difficult terrain "unless that creature is Tiny or your ally") but never end the move on it. The other side blocks, even when incapacitated (stricter than the SRD, a project decision).
- **Obstacle, Statue and Cover block movement and sight.** The Chest is low and blocks neither.
- **Cover is not a rule.** BG3 has no cover system: the Cover object only blocks movement and sight, never changes the attack roll, and gives no Hide exception. Hide follows BG3 as far as the game has the data: it is denied while any enemy has line of sight (there is no obscurity system), and out of every enemy's sight it rolls Stealth.
- **Area shapes are implemented** with the D&D 2024 drawing (`battle/area_shape.gd`): sphere and cylinder are aimed at an **intersection** of squares, a square is affected if the area covers **at least half** of it (exactly half counts), and cube, cone, line and emanation follow the 2024 definitions (emanation = from the creature's square outward, origin square excluded unless the ability says it includes it; a "Self" cone or line starts at the corner of the caster's square nearest the aimed direction, a project convention). Sizes are in feet. The preview shows exactly the squares the effect hits. Current abilities and their shapes are in `docs/architecture/battle.md` ("Areas of effect"); the hero abilities are provisional until the class review redoes them with the D&D 2024 spells.
- **Shared turns (BG3):** consecutive living heroes in the initiative order form one block of up to 10 that acts interchangeably (the player swaps freely between them, each with his own Action, Bonus Action and movement); enemies act one at a time. **Each hero ends his own turn** (control passes to the next one who has not ended; the block ends, and the turn passes on, when the last available hero ends; until then a hero who ended can cancel and keeps what he had left); a hero who becomes unable to act mid block (Downed, Stunned, Paralyzed) hands control over by himself. Start-of-turn effects still run per creature. The turn bar shows no "shared turn" indicator, only the order of the portraits (allies blue, enemies red). Initiative stays d20.
- The combat camera is isometric (definitive).

## Progression and level cap

- The game is not limited to BG3's level 12. The maximum level is not yet defined.
- Levels 13–20: D&D 2024 is the reference.
- Above level 20: own design, only with user approval. Do not assume it exists.

## Sources and where things are recorded

- Rules as implemented, rules checked on bg3.wiki, and unverified rules: "BG3 conformance" in `docs/architecture/battle.md`.
- Divergences from D&D 2024 that are not yet fixed: "Pending rules" in `docs/architecture/battle.md`.
- New rule logic goes in `BattleState` as data on `ActionData`/`StatusDefinitions` when the generic fields cover it, with a deterministic test (`seed()`, `DiceRoller.force_next`) in `tests/run_tests.gd`.
