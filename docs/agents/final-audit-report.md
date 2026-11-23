# Dungeon Descend: relatório da auditoria final

Data: 2026-11-13. Godot 4.7.2. Branch `fix/dano-centralizado`. Versão visual: [final-audit-report.html](final-audit-report.html). Registro de execução: [final-audit-progress.md](final-audit-progress.md).

> **Atualização:** a pendência alta 1 (save) e as médias 4, 5 e 7 foram tratadas depois deste relatório; ver [save-and-hardening-report.md](save-and-hardening-report.md). Os números abaixo são os do momento (suíte então em 2040).

**Classificação: PRONTO COM RESSALVAS.** Não há bloqueio crítico conhecido, mas há decisões suas pendentes (seção Pendências) e limites reais de validação (seção Testes).

## Resumo executivo

- **Estado inicial:** suíte reportava `1995 passed, 0 failed` com exit 0, mas emitia 11 `SCRIPT ERROR` que o runner ignora. Um deles mutilava um teste: as asserções finais de `_test_architecture_p2p7` nunca executavam.
- **Estado final:** `2040 passed, 0 failed`, 0 `SCRIPT ERROR`, 124 scripts compilam com os autoloads, menu e cena de combate sobem sem erro no log do jogo.
- **Principais correções:** teste mutilado; **a suíte apagava o save real do jogador**; `save()` não atômico e `load_save()` frágil; 5 regras de BG3 divergentes da wiki; 2 erros de runtime ao abrir o combate fora do fluxo normal; sobra da proposta 2 e leitura de privados da proposta 6.
- **Ponto de recuperação:** tag local `checkpoint/pre-final-audit` -> `6545c37`. Nada foi enviado ao remoto.

## Avaliação de qualidade (0 a 10)

Notas são **julgamento meu**, apoiado nas evidências abaixo; não são métricas medidas.

| Critério | Nota | Evidência |
|---|---|---|
| Arquitetura | 7 | `BattleState` separado da UI; dano, condições, economia e janela de reação centralizados (propostas 1 a 7). Mas `battle_state.gd` tem 3.498 linhas e `run_tests.gd` 4.5 mil. |
| Qualidade do código | 7 | Tipado, consistente. Restam código morto e duplicações pequenas (Pendências, baixas). |
| Confiabilidade | 7 | Bugs de save e de runtime achados e corrigidos; falta versionamento do save e verificação visual. |
| Testabilidade | 7 | 2040 asserções determinísticas (`DiceRoller.force_next`). Fixtures estáticos globais mutáveis e função gigante foram a causa do teste mutilado. |
| Fidelidade das mecânicas | 7 | 10 regras conferidas na bg3.wiki (5 corrigidas); várias não verificadas (Pendências). |
| Manutenibilidade | 6,5 | Arquivos muito grandes; docs de arquitetura e regras agora versionados. |
| Extensibilidade | 7 | Habilidades quase só por dados (`ActionData`), condições por `apply_condition`. |
| **Geral** | **7** | |

## Arquitetura

**`improve-codebase-architecture`: não foi executada por mim.** A ferramenta Skill recusou (`disable-model-invocation`: só o usuário pode invocá-la, com `/mattpocock-skills:improve-codebase-architecture`). Segui a instrução do pedido para esse caso: análise equivalente à mão, com o grafo, o código, a skill `codebase-design` disponível e os critérios do pedido. Não é saída da skill e não gerei HTML com o modelo dela. O relatório antigo (`architecture-review-20261113-014310.html`, em `%TEMP%`) foi usado só como histórico; nenhum problema foi aceito sem verificar no código atual.

### As sete propostas, verificadas no código atual

| # | Proposta | Resultado | Evidência |
|---|---|---|---|
| 1 | Dano centralizado | **Concluída e validada** | `_deal_damage_to_combatant` (`battle_state.gd:411`) é o único ponto; mitigação por componente; escritas de HP só em `_set_hp` e Help. |
| 2 | Acesso por índice | **Concluída** (sobra corrigida) | `get_hp/get_max_hp/_set_hp/player_index_of`. `CombatantLayer` ainda duplicava o ramo jogador/inimigo: corrigido (`6fe070d`) com o primeiro teste da classe. |
| 3 | Ciclo de vida das condições | **Concluída com ressalvas** | `apply_condition/remove_condition`. Restam 3 escritas diretas (`:2564` Help, furtivo, `coated_fire`) sem companheiros a limpar; sem bug demonstrado. |
| 4 | Resolvedor de ataque | **Concluída com ressalvas** | `_effective_ac`, `_player_attack_bonus`, `_enemy_attack_profile`, `_hit_probability` e agora `_melee_auto_crit` são compartilhados. `_apply_attack` (~250 linhas) e `_resolve_enemy_attack` seguem como dois caminhos; unificar não se justifica sem bug. |
| 5 | Eventos ordenados | **Parcial, por decisão documentada** | Janela de reação (`pending_hit`, `commit_pending_hit`) feita. Canais efêmeros (`last_attack_info`, `pending_surface_hits`, `pending_deaths`) mantidos: o plano anterior os deixou fora de escopo. |
| 6 | Economia de ações | **Concluída com ressalvas** | `spend_action_cost`, `is_item_available`. A UI lia `_state._current_action` em 6 pontos: trocado por `get_current_action()` (`188d3e2`). Restam leituras de `_undo_move_pos`, `_check_battle_end`, `_break_concentration`, `_attack_targets_allies`. |
| 7 | Determinismo | **Concluída com ressalvas** | `DiceRoller.force_next`. Aleatoriedade fora dele só em IA e no atordoamento probabilístico de inimigo (`battle_state.gd` `randf()`/`randi()`), por design. A suíte agora também usa arquivo de save próprio. |

### Segunda passagem (diferencial)

- As refatorações não criaram acoplamento novo: `_melee_auto_crit` e `_array_of` são helpers privados de uso local; `SAVE_PATH` virou `static var`, no mesmo padrão dos demais estados globais em maiúsculas.
- Problema estrutural **não** tratado, com a evidência: monólito de testes. O teste mutilado nasceu de uma função de 300 linhas que troca `PLAYERS`/`TURN_QUEUE` estáticos várias vezes. A defesa adotada foi tratar `SCRIPT ERROR` como falha (comando do `CLAUDE.md`). Dividir `run_tests.gd` por sistema com um construtor de fixture é o próximo passo recomendado, mas é refatoração grande sem bug aberto.
- Não criei ADR nem GLOSSARY (o `CLAUDE.md` os define como criados sob demanda). Decisões estão neste relatório e nos commits.

## Combate (BG3)

Detalhes e status por regra: seção "BG3 conformance" de [battle.md](../architecture/battle.md).

- **Conferem com a wiki:** resistência/vulnerabilidade/imunidade, concentração, death saves, Queimando, crítico (dados dobrados).
- **Corrigidas (`aa3e8ad`):** Envenenado (sem desvantagem em saves), Atordoado (falha automática em FOR/DES), Prone (vantagem a até 3 m, sem desvantagem à distância), Furtivo (arma sutil ou à distância, aliado só sem desvantagem, dados por nível), melee em alvo Downed sempre crítico.
- **Efeito de jogo a decidir:** com o auto-crítico, um golpe corpo a corpo em herói Downed vale 2 falhas, e a IA inimiga escolhe o alvo de menor HP (Downed = 0 HP). Um herói caído com 1 falha morre num golpe. É o que a wiki descreve, mas muda a dificuldade.
- **Não verificadas:** Ataque de Oportunidade e Dash/Disengage (página 404), nat 20 em death save (wiki silenciosa), Furtivo dobrando no crítico (wiki silenciosa), iniciativa, armadura que anula crítico (não implementada).

## Testes

| Item | Resultado |
|---|---|
| Baseline | `1995 passed, 0 failed`, exit 0, **11 `SCRIPT ERROR`** |
| Final | `2040 passed, 0 failed`, exit 0, **0 `SCRIPT ERROR`**, 1 aviso (UID obsoleto) |
| Acrescentados ou alterados | +45 asserções: 3 reativadas (P4), 12 de save, 4 de `CombatantLayer`, 20 de BG3 (17 novas + 3 de Prone), 6 de fallback/retrato; 4 testes existentes atualizados para a regra BG3 |
| Comando completo | `"$GODOT" --headless --script tests/run_tests.gd 2>&1 \| grep -E "FAIL\|Results\|SCRIPT ERROR"` |
| Verificação rápida | `"$GODOT" --headless --check-only --script res://arquivo.gd` (não conhece autoloads) |
| Projeto inteiro | `check_scripts_compile.gd` (skill `godot-gdscript`, com autoloads): 124 scripts, 0 quebrados, exit 0 |
| Clone limpo (etapa anterior) | importação sem erro e suíte igual ao original |
| Execução real (Godot MCP) | `battle_scene.tscn` e `main_menu.tscn` rodaram; log do jogo sem `SCRIPT ERROR`. Antes das correções, o combate aberto direto gerava 2 erros |

**Não realizado:** teste visual ou interativo (nenhuma captura de tela, nenhum clique de gameplay, nenhum fluxo completo de run), profiling de desempenho (nenhuma afirmação de ganho), verificação de salvamento pela interface. O Godot MCP só confirmou carregamento e log; a saída do `get_debug_output` veio vazia, então usei o `godot.log`.

## Codebase Memory

- **Projeto:** `<nome do projeto no grafo, derivado do caminho do checkout>` (a caixa importa).
- **Antes:** 1865 nós, 5576 arestas, índice com watcher. **Primeira atualização:** reindexação `full`, mesmos números, `generation_matches=true`.
- **Atualização final (depois das mudanças):** reindexação `full`, **1878 nós, 5628 arestas**, `indexed_at 2026-11-13T19:20:30Z`.
- **Consultas:** `_melee_auto_crit` em `battle_state.gd:648-649` com chamadores `_resolve_enemy_attack` e `_apply_attack` (e, indiretos, `apply_enemy_attack`, `apply_opportunity_attack`, `apply_attack_at_cursor`); `_array_of` em `dungeon_state.gd:344-346`; `_test_bg3_rules_audit` em `run_tests.gd:4214-4295`; `_can_sneak_attack` em `battle_state.gd:579-613`.
- **Limites reais:** `battle/battle_state.gd:20` e `heroes/clerigo.gd:1` com parse parcial. Causa: identificador com acento (`ClérigoData`); chamadas a essa classe não aparecem no grafo. Sinais e chamadas dinâmicas também não. 363 arquivos ignorados por design (`*.uid`, imagens). Arquivos "sem problema registrado" não são prova de cobertura completa.

## Git

- **Commits desta etapa (todos locais):** `83a1109` teste mutilado e `SCRIPT ERROR`; `e178ddc` save atômico, `load_save` e isolamento dos testes; `6fe070d` `CombatantLayer`; `aa3e8ad` regras BG3; `b7da3b3` erros de runtime do combate; `188d3e2` leitura por `get_current_action()`; mais o commit de documentação que inclui este relatório.
- **Preservado fora de commit:** `.vscode/settings.json` (caminho local).
- **Fora de alcance:** worktree e branch `chore/claude-code-setup` (intocadas). Sem push, merge, rebase ou reset.

## Pendências

**Críticas:** nenhuma conhecida.

**Altas**
1. O save real do jogador pode ter sido apagado pelas rodadas de teste anteriores à correção (a suíte chamava `delete_save()` no caminho real). Não há como recuperar; o diretório de dados estava sem `dungeon_save.json` ao verificar. Daqui para frente a suíte não toca nele.
2. Decidir sobre o efeito do auto-crítico em heróis Downed (ver Combate) e se a IA deve evitá-los.
3. Decidir o destino da branch `chore/claude-code-setup` (conflita só em `.gitignore` e `CLAUDE.md`).

**Médias**
4. `*.uid` ignorado: avisos de UID obsoleto em `battle_scene.tscn:3` e `impact_fire.tscn:3` (cai no caminho de texto); a Godot recomenda versionar.
5. Save sem campo de versão (mudança de formato é decisão de arquitetura). Botão "Continuar" fica inerte se o save existir e estiver corrompido.
6. Regras BG3 não verificadas (lista acima).
7. `run_tests.gd` monolítico com estáticos globais; `battle_state.gd` com 3.498 linhas.

**Baixas**
8. Código morto: `ui/dungeon_map.bkp.gd` (citado no `CLAUDE.md`), 3 ramos `elif x.has("sprite"/"portrait")` inalcançáveis em `enemy_info_panel.gd`, `turn_order_bar.gd` e `sprite_provider.gd`, `revealed_node_ids()` só em teste.
9. `_find_player_index` duplicado em `status_panel.gd` e `sprite_provider.gd`; constantes de botão repetidas em `dungeon_map.gd`; comentários "NOVO MÉTODO" obsoletos.
10. `_process` de `dungeon_map.gd` chama `queue_redraw()` todo frame (anima o brilho e o hover do mapa, então é intencional; o custo não foi medido). `DungeonState.generate()` reinicia o RNG global com `seed()`.

**Bloqueios externos:** `/mattpocock-skills:improve-codebase-architecture` só pode ser rodada por você; o ataque de oportunidade na bg3.wiki precisa de outra página.

**Funcionalidades não implementadas (não são bugs):** armadura que anula crítico, versionamento de save, ADRs e GLOSSARY.

## Prontidão

- **Pode receber novas funcionalidades?** Sim. A base compila, a suíte é confiável de novo (falha também por `SCRIPT ERROR`) e o save está isolado nos testes.
- **Limitações:** validação visual ausente; fidelidade BG3 parcial; arquivos grandes.
- **Observar daqui para frente:** rodar sempre o comando com `SCRIPT ERROR`; funções de teste não devem trocar `PLAYERS`/`TURN_QUEUE` sem restaurar; qualquer regra nova de combate deve citar a página da bg3.wiki e entrar na tabela de conformidade.
