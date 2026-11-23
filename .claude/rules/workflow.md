# Workflow: who does what

Superpowers decides *what* and *in which order*. Ponytail decides *how little code* it takes. AutoMode decides *which model and effort* run the main session. They do not overlap if each stays in its role.

## Superpowers: the planner

- New feature or behavior change: `brainstorming` (requirements, design) -> `writing-plans` -> execution. Bug: `systematic-debugging`. Before saying "done": `verification-before-completion`.
- Execution: `executing-plans` by default (inline; the session's context cache stays warm). Use `subagent-driven-development` when the plan has independent tasks **and** it touches 3+ files across systems or an elevated-risk area (`BattleState` rules, reactions, `ActionData`/`HeroData` fields, save format), so an independent review pays off.
- Trivial work (typo, one-line fix, doc edit, rename inside one file): no plan. Do it, run the quick check.
- A consultant prompt that says "plan only" means no file edits (see `CLAUDE.md`).
- Matt Pocock skills are specialists: `domain-modeling`, `codebase-design`, `research`, `grilling`, `pr`, `wizard`. For debugging, TDD, review and brainstorming use the Superpowers skills; never run both for the same step. Their `diagnosing-bugs`, `tdd` and `code-review` duplicate Superpowers and stay unused.
- `claude-code-setup` only when the user asks for automation recommendations.
- Find Skills (`find-skills`, global) may search; never run `npx skills add` (especially `-g -y`) unless the user approved that exact skill in this conversation.

## Domain skills (project `.claude/skills/`, installed via skills.sh)

They are references for Godot 4.7 and GDScript, not process: Superpowers still plans and verifies. `CLAUDE.md` and `game-rules.md` win over any skill. Known clashes:

| Skill | Use it for | Do not follow |
|---|---|---|
| `rpg` | item/equipment/quest structure only | its damage, crit, XP and defense formulas: combat is BG3 (d20, AC, saves), never ratio damage or +/-10% variance |
| `godot-signals-groups` | typed signals, Callable syntax, "fired twice" bugs | event-bus autoloads: here signals go child to parent only (`CLAUDE.md`) |
| `godot-resources` | `Resource` and `duplicate_deep()` semantics | `.tres` content files: content is defined in GDScript `_init()` here |
| `save-systems` | atomic writes, versioning ideas | changing the `DungeonState` save format: that is an architecture decision (`architecture-advisor`) |
| `game-testing` | playtest and bug-report checklists | GUT/GdUnit4 and Unity/Unreal advice: tests are `tests/run_tests.gd` |
| `game-ai` | FSM/pathfinding vocabulary | replacing `EnemyData` `action_pool`/`action_behaviors` |

`godot-gdscript-headless-testing` matches the project runner (`quit(1)` on failure) and `godot-gdscript/assets/check_scripts_compile.gd` is a valid whole-project parse check (run by absolute path, read-only). `godot-nodes-scenes/scripts/check_godot_project.py` needs Python 3, which is not installed.

## Ponytail (full): how the plan is implemented

- Smallest complete change, reuse existing code, no speculative abstraction, read each file once, fix shared code once.
- Ponytail never removes a requirement, a test or a verification step from an approved plan or spec, and never loosens a BG3 rule. If a lazy shortcut conflicts with a plan step, the plan wins; say in one line what was skipped.
- The "one small test for new logic" is the project's test in `tests/run_tests.gd`; do not add a second one.

## AutoMode: model and effort routing

- Active for every session (`activation: always`, `policy: auto`). It picks model and effort for the main session **per prompt**. It does not switch model in the middle of a task; do not promise that.
- `autoWorkflow: false` and `builder: off` on purpose: Superpowers is the only planner. Do not use `am:run`. One-prompt overrides if needed: `am:opus`, `am:high`, `am:reset`.
- Subagents keep the `model`/`effort` in their own frontmatter; AutoMode respects it.
- Its records live in `~/.claude/plugins/data/automode/`. They only land there because the VS Code user setting `claudeCode.environmentVariables` injects `HOME`. If a stray `undefined/` folder appears in the repo, that setting stopped working.
