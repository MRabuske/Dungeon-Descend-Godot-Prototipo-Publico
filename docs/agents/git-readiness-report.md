# Relatório: Git pronto para a auditoria geral

Data: 2026-11-13. Branch: `fix/dano-centralizado`. Nada foi enviado ao remoto, nenhum merge, rebase ou reset.

## Ponto de recuperação

**`97436c5`** (`chore(godot): versionar addon Godot MCP e habilitar no projeto`), sobre `0e32505`, sobre `344a7fb` (último commit de jogo, intacto). O commit deste relatório vem logo depois e só adiciona este arquivo. Para voltar ao estado anterior a esta etapa: `git reset --soft 344a7fb` desfaz os commits sem perder arquivos (não executado). Cópias dos arquivos de configuração anteriores: `.claude/backups/git-readiness-20261113/` (local, ignorada).

## Problemas encontrados

1. `.gitignore` ignorava `docs/` e `.claude/` inteiros. `docs/architecture/battle.md` (citado pelo `CLAUDE.md`), `docs/agents/*`, os agentes e as regras estavam fora do Git.
2. O addon do Godot MCP estava habilitado em `project.godot` mas não versionado: o editor quebraria em outro checkout.
3. **Falha de segurança ativa:** o addon upstream chama `tcp_server.listen(6505)` sem endereço, então o servidor de controle do editor (cria, edita e apaga arquivos, sem autenticação) escutava em `0.0.0.0` e `[::]`. Confirmado por `netstat` antes da correção.
4. Dados pessoais (perfil do Windows e nome do projeto derivado do caminho) nos documentos que passariam a ser versionados.
5. Existe a branch local `chore/claude-code-setup` (worktree irmã, 8 commits de 13/11, não enviada) com trabalho sobreposto. Ver "Pendências".
6. `*.uid` é ignorado por política do repositório (a Godot recomenda versionar). Não alterado.

## Correções

- `.gitignore`: removido `docs/`; `.claude/*` com exceções `!.claude/agents/` e `!.claude/rules/`; adicionados `.superpowers/`, `undefined/`, `.env`, `.env.*`, `*.log`, `*.tmp`, `*.bak`. Mantidos `.godot/`, `/android/`, `*.uid`, `refs/`, `prompts/`.
- Addon versionado com o `LICENSE` upstream (hash conferido com o upstream pela API do GitHub) e o patch de segurança de uma linha (`listen(PORT, "127.0.0.1")`).
- Caminhos pessoais removidos de `mcp-tools.md`, `plugin-audit-handoff.md` e `skills-audit-final.md`.

## Commits

| Commit | Conteúdo |
|---|---|
| `0e32505` | `.gitignore`, `CLAUDE.md`, `skills-lock.json`, 3 agentes, 3 regras, `docs/agents/*` (5), `docs/architecture/battle.md` (15 arquivos) |
| `97436c5` | `addons/godot_mcp/` (17 arquivos + `LICENSE`) e `project.godot` (4 linhas: `4.7` e plugin habilitado) |

Nenhum `.gd`, cena, recurso ou shader do jogo entrou nos commits nem foi modificado (`git diff 344a7fb..HEAD` fora de `addons/`, `docs/`, `.claude/`: só `.gitignore`, `CLAUDE.md`, `project.godot`, `skills-lock.json`).

## Versionado / ignorado

- **Versionado (novo):** `CLAUDE.md` (consolidado), `.claude/agents/`, `.claude/rules/`, `skills-lock.json`, `docs/` inteiro, `addons/godot_mcp/`.
- **Ignorado de propósito:** `.claude/settings.local.json`, `.claude/backups/`, `.claude/skills/`, `.superpowers/`, `.godot/`, `*.uid`, `.env*`, logs e temporários, `undefined/`, `prompts/`, `refs/`.
- **Skills de terceiros não são rastreadas.** São cópias de repositórios MIT e Apache-2.0 sem os avisos de licença junto; a fonte principal é o `skills-lock.json` (14 skills, sem duplicata de `find-skills`). Restaurar com a CLI do skills.sh (o fluxo de restauração a partir do lock não foi testado aqui).
- **`.claude/settings.json` compartilhado não foi criado.** A versão pronta está na branch `chore/claude-code-setup`.

## Verificações de segurança

- Varredura do índice antes de cada commit: 0 ocorrências de perfil do Windows, e-mail, chaves ou tokens; nenhum arquivo `.env`, `.pem`, `.key`, `.log`, `.tmp` ou `.bak` rastreado (nem antes).
- `git check-ignore` confirma: `settings.local.json`, `.claude/skills`, `.claude/backups`, `.env`, `*.log`, `undefined/` e `.superpowers/` ignorados; `agents`, `rules`, `CLAUDE.md`, `skills-lock.json`, `battle.md`, o addon e o `LICENSE` não ignorados.
- Licença do addon: Apache-2.0 com Commons Clause (não vender o software) e Fair Revenue (grátis até US$250 mil/ano de receita; acima disso exige licença comercial). Versionar com o `LICENSE` é redistribuição permitida. A condição de receita vale para você ou sua organização: confirme se o projeto a atinge.
- Nenhuma credencial rastreada; histórico não tocado.

## Alterações preexistentes

- `.vscode/settings.json` continua modificado e **fora dos commits**: a mudança troca o caminho do editor por um caminho local seu. Preservado.
- Nenhuma alteração de GDScript, cena ou teste estava pendente.
- `CLAUDE.md` (reestruturação anterior, 279 linhas) entrou inteiro em `0e32505`, depois de revisado.

## Godot MCP

Habilitado em `project.godot`; os arquivos estão versionados; `claude mcp list` mostra o servidor conectado. Em **clone limpo local** (sem `.godot`, `.uid` nem `.claude/skills`): `--import` sem erro e `Results: 1995 passed, 0 failed`, igual ao projeto original. O patch de 127.0.0.1 só vale **depois de reiniciar o editor ou reativar o plugin**: o editor em execução ainda escutava em `0.0.0.0:6505` e `[::]:6505` ao fim desta etapa.

## Pendências

1. **Reiniciar o editor Godot** (ou desligar e ligar o plugin Godot MCP) para fechar a porta 6505 à rede. Até lá, o servidor continua exposto.
2. **Decidir o destino de `chore/claude-code-setup`.** Simulação de merge (`git merge-tree`): conflito só em `.gitignore` e `CLAUDE.md`; addon, `project.godot` e docs coincidem. A branch traz extras não incorporados: `tools/godot.sh`, CI de testes, hook de GDScript e `.claude/settings.json` com permissões e confirmações para o Godot MCP.
3. **Erros de script que a suíte não detecta** (o runner só falha por `FAIL`): 10 em `battle/ui/examine_panel.gd:485` (`process_frame` em instância nula) e 1 em `tests/run_tests.gd:4472` (índice fora do limite). Pré-existentes; candidatos à auditoria geral.
4. `*.uid` continua ignorado; a Godot recomenda versionar.
5. `.vscode/settings.json` com caminho local permanece modificado.
6. Aviso de UID inválido em `vfx/effects/impact/fire/impact_fire.tscn:3` (usa o caminho de texto).
