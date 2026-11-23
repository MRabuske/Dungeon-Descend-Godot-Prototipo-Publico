# Save do jogador, UID, código morto e divergências do Git

Data: 2026-11-13. Continuação de [final-audit-report.md](final-audit-report.md); as pendências altas 1 e médias 4, 5 e 7 dele foram tratadas aqui. A skill `improve-codebase-architecture` não foi executada nem imitada nesta etapa (você a roda manualmente).

## 1. O save do jogador foi apagado pela suíte?

**Conclusão: não é possível provar se havia um save, e não existe cópia para recuperar.**

- **A suíte tocava no save real.** Desde o commit `03997a4` (2026-05-22) os testes de `DungeonState` chamavam `save()` e `delete_save()` no `SAVE_PATH` do jogo. Cada rodada da suíte, de qualquer pessoa, apagava ou sobrescrevia o `user://dungeon_save.json`. Isso é comprovado pelo código, não pelo arquivo.
- **O arquivo hoje não existe.** O diretório de dados do projeto tem só `logs`, `objectdb_snapshots`, `shader_cache` e `vulkan`; não há `.tmp`, `.bak`, `.corrupt*` nem outro `*.json`.
- **Ausência não prova perda.** O próprio jogo apaga o save ao fim da run (`battle_scene.gd`) e se o grupo está vazio (`main_menu.gd`); sem run em andamento, a ausência é o estado normal.
- **Recuperação procurada e não encontrada:** perfil do usuário (busca por `dungeon_save*`), Lixeira (0 itens relacionados), OneDrive (nada com esse nome) e File History do Windows (serviço parado). Nenhuma recuperação foi tentada ou inventada.
- **Cuidado tomado:** a suíte não foi executada de novo até o isolamento ser provado por revisão estática de todos os acessos a `user://`.

## 2. Isolamento definitivo dos testes

- **Pasta própria:** a suíte grava só em `user://test_sandbox/` (`TEST_SAVE_DIR`), criada no início e removida no fim; antes usava um arquivo na mesma pasta do save real.
- **Só leitura no caminho real:** a suíte tira uma impressão digital (SHA-256 e data de modificação, ou "absent") do save real antes e depois e falha se mudar.
- **Testes novos:** o caminho dos testes está na pasta própria e difere do real; `delete_save` e `save` mexem só no `SAVE_PATH` atual (um "save do jogador" simulado ao lado sobrevive, com conteúdo idêntico); o guarda detecta ausência, alteração e remoção; o fonte da suíte não cita o nome do arquivo real; o save real não foi criado, alterado nem apagado.
- **Prova pós-execução:** o diretório de dados antes e depois da suíte é igual, e a pasta `test_sandbox` não sobra.

## 3. Formato do save, compatibilidade e botão Continuar

- **Versão:** `save()` grava `"version": SAVE_VERSION` (1). Save sem o campo é legado (v0) e carrega como antes, inclusive a reconstrução da névoa. Versão maior é `NEWER`: não carrega e o arquivo fica intacto. Versão inválida (texto, negativa, `null`) é `CORRUPT`.
- **Status:** `_read_save` devolve `NONE`, `VALID`, `CORRUPT`, `NEWER` ou `UNREADABLE`; ler nunca altera o arquivo.
- **Continuar:** só aparece com save `VALID`. Corrompido vai para `<nome>.corrupt.json` (`-2`, `-3`... se já houver), nunca é apagado, e o menu avisa. `NEWER` e `UNREADABLE` não mexem no arquivo e avisam.
- **Verificação:** 20 testes no runner; a lógica do menu foi verificada num script de rascunho contra uma pasta temporária (corrompido movido e avisado, versão mais nova intacta, sem save sem aviso). A tela do menu não foi aberta nem vista.

## 4. Avisos de UID

- **Causa:** `*.uid` estava ignorado e cada checkout gerava UIDs novos. Das 40 referências `uid://` em cenas, 4 divergiam do script; em clone limpo apareciam **5 avisos** (`battle_scene`, `event_scene`, `main_menu`, `impact_fire`, `fireball_projectile`).
- **Correção:** os 113 `.uid` do projeto passam a ser versionados; os do addon de terceiros continuam ignorados, para manter o addon idêntico ao upstream. `projectile_vfx.gd` era citado com dois UIDs (5 cenas contra 2): as 2 minoritárias foram alinhadas. `battle_scene.gd.uid` e `event_scene.gd.uid` agora são os UIDs que suas cenas já citavam. Antes, conferi que nenhum outro arquivo usava os valores trocados.
- **Prova:** clone limpo do commit, importação e carga de todas as cenas: **0 avisos**; suíte `2065 passed`, 0 `WARNING`; o Godot não modificou nenhum `.uid`; 40 de 40 referências resolvem.
- **Efeito para quem usa a outra branch:** o `.gitignore` muda (seção 6); um colaborador com `.uid` locais não rastreados precisa apagá-los ou aceitar os versionados ao puxar.

## 5. Código morto

- **Removido:** 3 ramos `elif x.has("portrait"/"sprite")` (todo inimigo estende `EnemyData`, que define `to_combat_dict()`, e `Resource` não tem `has()`), e `ui/dungeon_map.bkp.gd` com seu `.uid` (nenhuma referência em scripts, cenas, recursos ou `project.godot`; a classe `DungeonMapScreenBkp` não é usada). Recuperável com `git show 7487d45:ui/dungeon_map.bkp.gd`.
- **Mantido:** `revealed_node_ids()` (só os testes a usam, mas é API testada).

## 6. Divergências do Git

- `origin/develop` = `develop` (`e6dba8c`): nada novo no remoto.
- `fix/dano-centralizado` está 32 commits à frente de `develop` (mais os desta etapa) e `chore/claude-code-setup` 8, **ambas só locais**. Nada foi enviado, então esse trabalho existe apenas nesta máquina.
- **Conflito real entre as duas:** só `.gitignore` e `CLAUDE.md`; o restante, inclusive addon e `project.godot`, coincide ou entra limpo.
- **Merge de teste** (worktree descartável e destacada, sem tocar nas branches): resolvido; `tools/godot.sh check` com 107 scripts ok e `tools/godot.sh test` com `2065 passed`, exit 0. Resolução: `.gitignore` com a política de `.uid` desta branch mais a exceção `!.claude/settings.json` da `chore`; `CLAUDE.md` com o bloco de comandos da `chore` (`tools/godot.sh`, que falha também em `SCRIPT ERROR`) e a linha de linguagem dela (cita o addon), mantendo BG3 fiel, política de mudança e delegação desta branch; as seções "Tools" e "Skills" da `chore` viram um ponteiro para `.claude/rules/`, porque duplicavam.
- **Nenhuma das duas branches foi alterada.** O resultado fica na tag local `proposal/merge-chore-into-fix`. Para adotar, estando em `fix/dano-centralizado`: `git merge --ff-only proposal/merge-chore-into-fix`. Para descartar: `git tag -d proposal/merge-chore-into-fix`.

## 7. Arquivo de testes grande

`tests/run_tests.gd` tem ~4,7 mil linhas e 15 funções; `_run_all` sozinha tem ~4,2 mil linhas, e há 67 chamadas a `setup_party` mutando estado global estático. O risco comprovado não é o tamanho, é que um erro de runtime aborta a função em silêncio. Mitigação aplicada sem refatorar: marcadores de conclusão (`_reached`, `EXPECTED_TO_FINISH`), testados com um erro injetado e revertido (exit 1 e 2 `FAIL` nomeando a função). Dividir o arquivo por sistema só vale quando uma área for tocada; fica como recomendação (a `chore` registra o débito em `docs/tech-debt.md`).

## 8. BG3: Downed e a IA

A regra "corpo a corpo em Downed é crítico, 2 falhas" foi confirmada e mantida (os testes existentes passam). A política de alvo da IA **não** foi alterada; o impacto na dificuldade está em [battle.md](../architecture/battle.md), seção "Downed heroes and enemy targeting".

## 9. Verificações

| Item | Resultado |
|---|---|
| Suíte final | `2067 passed, 0 failed`, 0 `SCRIPT ERROR`, exit 0 |
| Compilação do projeto | `check_scripts_compile.gd`: 123 scripts, 0 quebrados |
| Clone limpo | importação sem erro, 0 avisos de UID, suíte `2065 passed` |
| Dados do jogador | diretório de dados igual antes e depois de cada execução |
| Merge de teste | `check` e `test` da `chore` verdes sobre o resultado combinado |

## 10. Commits desta etapa

`e036b4c` isolamento, versão do save e Continuar · `7487d45` `.uid` e referências · `744213e` código morto · `dd856ea` marcadores de conclusão · mais o commit desta documentação.

## 11. Pendências

1. O save possivelmente apagado não é recuperável (seção 1); nada a fazer.
2. Decidir a política de alvo da IA contra heróis Downed (seção 8).
3. Adotar ou descartar `proposal/merge-chore-into-fix`; quem tiver `.uid` locais não rastreados precisa lidar com eles ao puxar.
4. Backup de saves: o jogo mantém um único arquivo, sem rotação; considerar uma cópia `.bak` na gravação (decisão sua).
5. Regras BG3 ainda não verificadas e a skill `improve-codebase-architecture` (você roda manualmente).
6. Sem teste visual: a tela do menu com os avisos novos não foi vista.
