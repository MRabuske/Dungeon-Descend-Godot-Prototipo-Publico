# MCP tools: one tool per question

Godot reference version: 4.7.2.

| Question | Tool | Notes |
|---|---|---|
| Where is X defined, who calls it, what breaks if I change it | Codebase Memory (`search_graph`, `trace_path`, `get_code_snippet`) | Pass the project name exactly as `list_projects` prints it (derived from the checkout path, case-sensitive). The index auto-refreshes. Known gaps: parse is partial in `battle/battle_state.gd` (line 20) and `heroes/clerigo.gd` (line 1); signals, `call()` and string-keyed lookups are invisible. |
| A literal, a string key, a signal name, a gap in the index | `Grep` / `Read` | Also the check for any ambiguous or empty graph answer. |
| What the running editor or game shows: scene tree, node properties, signal connections, resources, debugger output | Godot MCP (read-only tools) | Needs the editor open with `addons/godot_mcp` enabled. Scenes are one root node built in code, so the tree is only informative at runtime. |
| Engine API, GDScript syntax, version differences | Context7 (`resolve-library-id` once, then `query-docs`) | Use `/websites/godotengine_en` with version `4.7`, or `/godotengine/godot-docs` (`__branch__4.7`); no need to resolve again. Skip it for project-internal logic. |
| Run tests, parse-check a script | `"$GODOT"` via Bash (see `CLAUDE.md`) | Not through Godot MCP. |

- Ask the graph or grep for the same fact, not both. Use the second only to confirm an ambiguous answer.
- Edit GDScript and scenes with `Edit`/`Write`. Do not use Godot MCP's `edit_script`, `modify_node`, `add_node` and similar; two writers on one file lose changes.
- One writer per file at a time: do not edit a file the main thread and a subagent both touch.
- If the editor holds a scene open that you changed on disk, tell the user to reload it instead of saving over it.
