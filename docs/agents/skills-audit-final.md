# Auditoria final de skills e plugins

Data: 2026-11-13. Godot 4.7.2. Complementa `plugin-audit-handoff.md` (auditoria anterior, não repetida aqui).

**Estado no Git na data desta auditoria:** `docs/` e `.claude/` estavam no `.gitignore`; `skills-lock.json` não era rastreado. Corrigido na etapa seguinte (ver `git-readiness-report.md`).

## 1. Inventário real

| Fonte | Conteúdo | Estado |
|---|---|---|
| `.claude/skills/` (projeto) | 14 skills, cópias físicas (`installMode: copy`), sem symlinks | instaladas, descobertas, habilitadas |
| `~/.claude/skills/find-skills` | 1 skill (CLI skills.sh, `-g`) | instalada, descoberta |
| `~/.claude/skills/codebase-memory` | skill do MCP | descoberta |
| `~/.claude/skills/synced/…` | 13 skills da conta claude.ai | descobertas; gerenciadas no claude.ai |
| `.agents/skills/` (projeto e usuário) | não existe | ausente |
| Locks | `skills-lock.json` (projeto, v2, 14 entradas) e `~/.agents/.skill-lock.json` (v3, só `find-skills`) | consistentes depois da correção |
| Plugins ativos | superpowers 7.0.2, ponytail 5.3.3, context7, mattpocock-skills 1.3.2, claude-code-setup (usuário); automode 0.10.0, godot-mcp (projeto) | ok |
| MCPs (`claude mcp list`) | codebase-memory-mcp, context7, godot-mcp, Claude Docs | os 4 conectados |
| Agentes do projeto | architecture-advisor, godot-debugger, godot-implementer | válidos |
| Hooks | só `codebase-memory-mcp hook-augment` (PreToolUse `Grep|Glob`, SessionStart x4, SubagentStart); superpowers SessionStart; automode via `register.ts` | sem repetição: cada evento aparece uma vez |

"Descoberta" foi comprovada pela listagem de skills do próprio Claude Code nesta sessão.

## 2. As 14 skills selecionadas

Todas existem em `.claude/skills/<nome>/`, com `SKILL.md` íntegro (frontmatter válido, `name` igual à pasta). Nenhuma tem symlink, hook ou `allowed-tools`. A varredura de comandos de risco (curl, rm, sudo, eval, instalação de pacotes, push) não achou nada; as URLs são só referências de documentação. Versão identificável: o `computedHash` do lock (hash de pasta, não verificável localmente) mais a data "Last verified" quando existe.

| Skill | Origem | Revisão | Godot 4.7.2 / GDScript | Relevância | Decisão |
|---|---|---|---|---|---|
| godot-gdscript | gamedev-skills/awesome-gamedev-agent-skills | 2026-11-11 | verificada contra 4.7.2 | alta | mantida; **funcional** (ver §5) |
| godot-nodes-scenes | idem | 2026-11-11 | 4.7.2-stable | média | mantida; checker `.py` sem Python |
| godot-signals-groups | idem | 2026-11-11 | 4.7.2-stable | média | mantida com ressalva (event bus) |
| godot-resources | idem | 2026-11-11 | 4.7.2-stable | média | mantida com ressalva (`.tres`) |
| godot-ui-control | idem | 2026-11-11 | 4.7.2-stable | alta (HUD em código) | mantida |
| godot-gdscript-headless-testing | idem | 2026-11-11 | binário 4.7.2 | alta | mantida; coerente com `tests/run_tests.gd` |
| gdscript-advanced | jame581/GodotPrompter | sem data; cita mudanças do 4.7 | sim | média | mantida |
| game-testing | mejbaurbahar/software-tester-skills | metadata v2.0 | genérica (Unity/Unreal; cita GUT/GdUnit4) | baixa | mantida com ressalva |
| rpg | gamedev-skills | 2026-11-11 | engine-neutra | **conflita com BG3** | mantida com ressalva forte |
| game-ai | gamedev-skills | 2026-11-11 | engine-neutra | média | mantida com ressalva |
| game-ui-ux | gamedev-skills | 2026-11-11 | engine-neutra | média | mantida |
| save-systems | gamedev-skills | 2026-11-11 | engine-neutra | média | mantida com ressalva |
| level-design | gamedev-skills | 2026-11-11 | engine-neutra (foco em plataforma/metroidvania) | baixa | mantida |
| game-feel | gamedev-skills | 2026-11-11 | engine-neutra | média (VFX/hit stop já existem) | mantida |

Requisitos externos e scripts: só dois executáveis. `godot-gdscript/assets/check_scripts_compile.gd` (somente leitura) e `godot-nodes-scenes/scripts/check_godot_project.py` (somente leitura, declarado no próprio cabeçalho). O `.py` exige Python 3, que **não está instalado** (só o atalho da Microsoft Store), então não é funcional hoje. As skills não dependem de nada além disso.

## 3. Duplicações e conflitos

**Duplicação real resolvida:** `find-skills` existia em `.claude/skills/` (projeto) e em `~/.claude/skills/` (global), com `SKILL.md` byte a byte idêntico (5472 bytes). Mantive a global (serve a todos os projetos; não toquei nela). A cópia do projeto foi movida para `.claude/backups/skills-audit-20261113/find-skills-project-copy.disabled-dir/` e a entrada foi removida de `skills-lock.json` (cópia do lock original no mesmo backup). Para desfazer: mover a pasta de volta e restaurar o lock.

**Sem duplicação real:** as 14 skills não têm cópias em outros diretórios. Sobreposição parcial com Superpowers (`godot-gdscript-headless-testing` e `game-testing` com TDD/verificação) não é duplicação: tratam de execução de testes Godot e de playtest, não de processo. Nenhuma foi desativada.

**Conflitos com o projeto, resolvidos por regra** (tabela "Domain skills" em `.claude/rules/workflow.md`, sempre carregada), sem editar conteúdo de terceiros:

| Skill | Conflito | Resolução |
|---|---|---|
| rpg | fórmulas de dano por razão, variância ±10%, crítico 1,5–2x contradizem d20/CA/saves do BG3 | só estrutura de itens, equipamento e quests; combate é BG3 |
| godot-signals-groups | recomenda event bus em autoload; o `CLAUDE.md` define sinais só de filho para pai | não seguir o event bus |
| godot-resources | recomenda conteúdo em `.tres`; o projeto define conteúdo em GDScript `_init()` | usar só a semântica de `Resource` |
| save-systems | propõe mudar o formato de save | mudar `DungeonState` é decisão de arquitetura |
| game-testing | sugere GUT/GdUnit4 e Unity/Unreal | testes são `tests/run_tests.gd` |
| game-ai | arquitetura de IA genérica | não substituir `action_pool`/`action_behaviors` |

**Risco de instalação automática:** `find-skills` instrui `npx skills add <pacote> -g -y` (global, sem confirmação). Regra adicionada: nunca rodar `npx skills add` sem aprovação do usuário para aquela skill exata.

**Hooks e agentes:** sem hooks repetidos. Os agentes `automode:*` seguem inativos (`builder: off`, `autoWorkflow: false`) e não duplicam os do projeto, já que o `CLAUDE.md` manda usar os do projeto.

## 4. Tokens (só medições)

Soma dos caracteres das descrições (o que entra na listagem de skills): 14 skills do projeto = 4910; `find-skills` = 303; 13 skills sincronizadas da conta = 9122 (docx, pdf, pptx, xlsx, docs, morning etc., irrelevantes para o jogo). Não há medição de tokens nem de economia. As skills sincronizadas são o maior custo fixo e não podem ser desativadas localmente.

## 5. Testes executados

| Teste | Resultado |
|---|---|
| Frontmatter das 14 skills + `find-skills` + 13 sincronizadas | todos válidos, `name` = pasta |
| `check_scripts_compile.gd` (godot-gdscript) por caminho absoluto | `scripts checked: 124, broken: 0`, exit 0, sem arquivos novos no Git |
| `claude mcp list` | codebase-memory-mcp, context7, godot-mcp e Claude Docs conectados |
| Godot MCP (`godot_status`) | conectado, 4.7.2 |
| Suíte do jogo | `Results: 1995 passed, 0 failed` |
| Registros do AutoMode | `HOME` no processo = diretório do usuário; registros em `~/.claude/plugins/data/automode/records/`; nenhuma pasta `undefined/` no repositório |
| Subagente | `codebase-memory-scout` respondeu corretamente (auditoria anterior) |

Observação do `check_scripts_compile.gd`: aviso de UID inválido em `vfx/effects/impact/fire/impact_fire.tscn:3` (usa o caminho de texto). Não é erro nem foi alterado.

## 6. Configuração resultante

Superpowers planeja; Ponytail `full` otimiza; AutoMode roteia (`autoWorkflow: false`, `builder: off`); Matt Pocock como especialista; Codebase Memory, Godot MCP e Context7 conforme `.claude/rules/mcp-tools.md`. Skills de domínio subordinadas ao `CLAUDE.md` e a `game-rules.md`.

## 7. Pendências reais

1. Python 3 não instalado: `check_godot_project.py` fica inutilizável. Instalar é decisão sua.
2. (Resolvido) Regras de versionamento do `.gitignore` e `skills-lock.json`: ver `git-readiness-report.md`.
3. 13 skills sincronizadas da conta continuam gastando contexto; só dá para gerenciá-las no claude.ai.
4. Hooks `.cmd` órfãos em `~/.claude/hooks/` (inofensivos, globais; não tocados).
5. O `computedHash` do lock não pôde ser verificado localmente (algoritmo da CLI não documentado).
6. Há `*.md.bak` em `~/.claude/agents/` (não são carregados; não tocados).
