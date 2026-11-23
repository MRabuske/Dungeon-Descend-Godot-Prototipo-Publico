# Auditoria de plugins e skills: handoff

Data: 2026-11-13. Escopo: ambiente Claude Code (VS Code) do Dungeon Descend. Godot de referência: 4.7.2.

## Problemas identificados

1. **Dados do AutoMode gravados no lugar errado.** No Windows o AutoMode não encontra `HOME`, então grava em `<projeto>/undefined/.claude/plugins/data/automode/`. Sintoma: `am-routes.mjs` dizia "No request records". A pasta `undefined/` já está no `.gitignore`.
2. **Sobreposição de skills de processo** entre Matt Pocock (`diagnosing-bugs`, `tdd`, `code-review`, `grilling`) e Superpowers (`systematic-debugging`, `test-driven-development`, `requesting-code-review`, `brainstorming`).
3. **Sobreposição de agentes:** os `automode:*` (implementer, reviewer, explorer…) cobrem papéis parecidos com `godot-implementer`. Ficam ociosos porque `autoWorkflow` e `builder` estão desligados.
4. **Skills sincronizadas da conta claude.ai** (docx, pdf, pptx, xlsx, docs, morning…) não servem a um jogo Godot e gastam contexto com descrições.
5. **Hooks `.cmd` órfãos** em `~/.claude/hooks/` (`cbm-*.cmd`), não referenciados em `settings.json`. Inofensivos.
6. **Find Skills** (na época não instalado) foi instalado depois, junto com 14 skills de domínio; ver `skills-audit-final.md`.
7. **Índice do Codebase Memory** com parsing parcial em `battle/battle_state.gd` (linha 20) e `heroes/clerigo.gd` (linha 1).

Não encontrei: injeção duplicada de contexto, roteador concorrente (Effortless), fixação de modelo ou esforço que bloqueie o roteamento, nem skill incompatível com Godot 4.7.2.

## Correções realizadas

1. **Dados do AutoMode (resolvido em 2026-11-13).** Causa: o motor de hooks lê o ambiente real do processo (`HOME` não existe no Windows) e ignora o bloco `env` de `settings.local.json`. Correção: `claudeCode.environmentVariables = [{HOME: "<diretório do usuário>"}]` nas configurações de usuário do VS Code (só afeta a extensão; backup `settings.json.bak-automode-20261113`). Verificado: registros novos em `~/.claude/plugins/data/automode/records/`; `undefined/` migrada e apagada. O `HOME` antigo em `settings.local.json` foi removido.
2. **Integração do workflow (2026-11-13).** `CLAUDE.md` consolidado; regras em `.claude/rules/` (`workflow.md`, `mcp-tools.md`, `game-rules.md`); descrições dos agentes ajustadas.

## Plugins e skills

Mantidos, nada desativado (não há jeito suportado de desativar skill individual dentro de um plugin):

| Plugin | Escopo | Papel |
|---|---|---|
| superpowers 7.0.2 | usuário | planejamento, execução, verificação |
| ponytail 5.3.3 | usuário | menor mudança, economia de tokens (`full`) |
| automode 0.10.0 | local | roteamento de modelo e esforço |
| mattpocock-skills 1.3.2 | usuário | `domain-modeling`, `research`, `pr`, `wizard`, `codebase-design` sem equivalente |
| context7 | usuário | documentação de bibliotecas |
| claude-code-setup 1.0.0 | usuário | recomendações de automação |
| godot-mcp | local | ponte com o editor (4.7.2) |
| codebase-memory-mcp | usuário (MCP) | grafo de código |

## Configuração atual do AutoMode

`activation: always`, `mode: auto`, `policy: auto`, `defaultPath: direct`, `autoWorkflow: false`, `maxConcurrency: 1`, `blockGitWritesWhenActive: true`, `builder: off`, `delegation: off` (leituras grandes delegadas, não a delegação normal), `subagentsEverySession: true`, `reviewPolicy: risk`.

Evidências medidas: o app pede Opus/medium, e o roteador enviou `sonnet-5-5/high` (11 requisições) e `sonnet-5-5/medium` (2). O `am-routes` confirmou 11 de 13 no transcript e 2 divergiram (não investigadas). Subagente `automode:explorer` rodou em haiku/medium. `architecture-advisor` rodou em `claude-fable-5-2`/high (modelo fixado no agente é respeitado). O AutoMode não escolhe o Fable.

Subagentes do projeto: `architecture-advisor` (fable/high), `godot-debugger` (opus/high), `godot-implementer` (sonnet/medium). Globais: `codebase-memory-scout` (haiku/low), `codebase-memory` (sonnet/medium), `codebase-memory-auditor` (opus/high).

MCPs testados: Codebase Memory (índice pronto, 1776 nós), Godot MCP (conectado, 4.7.2-stable), Context7 (resolve Godot 4.5 a 4.7).

## Decisões

- **Superpowers:** é o único planejador. `autoWorkflow: false` impede o planejador do AutoMode de concorrer.
- **Ponytail:** permanece em `full`.
- **Matt Pocock:** mantido. Para processo (debug, TDD, review, brainstorming) vale o Superpowers; do Matt Pocock usa-se o que não tem equivalente (`domain-modeling`, `research`, `pr`, `wizard`, `codebase-design`). `domain-modeling` é referenciada pelo `CLAUDE.md`.

## Pendências

1. Decidir sobre as skills sincronizadas da conta (gerenciadas no claude.ai, fora do alcance local).
2. Investigar as 2 requisições que divergem entre o enviado e o transcript.
3. O índice do Codebase Memory pode não cobrir sinais e referências dinâmicas de GDScript; confirmar com grep.
4. (Resolvido em 2026-11-13) `.claude/` e `docs/` estavam no `.gitignore`; ver `git-readiness-report.md`.

## Próximas etapas

Auditoria final do Dungeon Descend: rodar `"$GODOT" --headless --script tests/run_tests.gd`, revisar o código contra `docs/architecture/battle.md` e delegar o que for especializado.
