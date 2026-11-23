# Auditoria final: registro de progresso

Atualizado em marcos. Se o contexto for compactado, retome por aqui, por `git log` e pelos resultados reais.

## Estado inicial (2026-11-13)

- Raiz: `Dungeon-Descend-Godot-Prototype`, `project.godot` com features `4.7`; Godot `4.7.2.stable`.
- Branch `fix/dano-centralizado` @ `6545c37`. Worktree limpa, exceto `.vscode/settings.json` (caminho local, nunca commitar).
- **Checkpoint:** tag local `checkpoint/pre-final-audit` -> `6545c37` (`git reset --soft 344a7fb` desfaz só os 3 commits de config; o último commit de jogo é `344a7fb`).
- Outra worktree: `Dungeon-Descend-Godot-Prototype-claude-setup` (branch `chore/claude-code-setup`, intocada).
- Baseline: `Results: 1995 passed, 0 failed`, exit 0, mas **11 `SCRIPT ERROR`** (ver diagnósticos).
- Porta 6505 do Godot MCP: agora `127.0.0.1` (editor reiniciado).
- Codebase Memory: projeto `<nome do projeto no grafo, derivado do caminho do checkout>`; reindexação completa feita: 1865 nós, 5576 arestas, `index_mode=full`, `generation_matches=true`. Parse parcial: `battle/battle_state.gd:20` e `heroes/clerigo.gd:1` (causa: identificador com acento, `ClérigoData`). 363 arquivos ignorados por design (`*.uid`, imagens).
- `improve-codebase-architecture` (mattpocock-skills 1.3.2): **a ferramenta Skill recusou** (`disable-model-invocation`: só o usuário pode invocar, `/mattpocock-skills:improve-codebase-architecture`). Não foi executada. A análise arquitetural abaixo é equivalente, feita à mão, e não deve ser apresentada como saída da skill.

## Diagnósticos confirmados

| # | Achado | Classe | Evidência |
|---|---|---|---|
| D1 | `_test_architecture_p2p7` aborta em `tests/run_tests.gd:4472` (`PLAYERS[1]` com um único herói, depois do bloco "incapacitado" do commit `344a7fb`); os testes de `_spell_save_dc` e de OA de inimigo nunca executam | falta de cobertura (teste mutilado) | `SCRIPT ERROR: Out of bounds get index '1'` |
| D2 | A suíte apaga o `user://dungeon_save.json` real (`delete_save()` em `run_tests.gd` 1350, 1646, 1702, 1717, 1748) e escreve nele | bug comprovado (perda de dados do dev) | leitura do código |
| D3 | `ExaminePanel._build_section_with_header` usa `await get_tree()` fora da árvore: 10 `SCRIPT ERROR` na suíte | risco técnico / erro de teste | `examine_panel.gd:485` |
| D4 | `DungeonState.save()` grava direto (sem temporário nem checagem de erro) e `load_save()` indexa chaves sem validar | risco técnico + bug em save malformado | `dungeon_state.gd:330-333, 360-368` |
| D5 | `combatant_layer.gd:163-171` duplica o ramo jogador/inimigo de HP (sobra da proposta 2) | melhoria arquitetural pequena | leitura |
| D6 | Runner só falha por `FAIL`; `SCRIPT ERROR` passa em silêncio | falta de cobertura / processo | exit 0 com 11 erros |

## Sete propostas anteriores (estado verificado no código atual)

| # | Proposta | Estado |
|---|---|---|
| 1 | Dano centralizado | Concluída e validada: `_deal_damage_to_combatant` (`battle_state.gd:411`) é o ponto único; mitigação por componente; escritas diretas de HP só em `_set_hp` e Help (`:2569`, `maxi(1, ...)`). |
| 2 | Acesso por índice | Concluída com ressalvas: `get_hp/get_max_hp/_set_hp/player_index_of` ok; sobra D5. |
| 3 | Ciclo de vida das condições | Concluída com ressalvas: `apply_condition/remove_condition` (`:2916/:2942`); restam escritas diretas em `:2564` (Help), `:2739` (furtivo), `:2770` (coated_fire). |
| 4 | Resolvedor de ataque | A conferir (funções `_apply_attack`, `_resolve_enemy_attack`, `_effective_ac`, `_player_attack_bonus` existem). |
| 5 | Eventos ordenados | Parcial por decisão: janela de reação com `pending_hit` feita; canais efêmeros (`last_attack_info`, `pending_surface_hits`, `pending_deaths`) mantidos (fora de escopo justificado no plano). |
| 6 | Economia de ações | Concluída com ressalvas: `spend_action_cost`, `is_item_available`; a scene/area ainda lêem privados (`_state._current_action`, `_undo_move_pos`, `_check_battle_end`, `_break_concentration`, `_attack_targets_allies`; 13 sítios). |
| 7 | Determinismo | Concluída com ressalvas: `DiceRoller.force_next`; aleatoriedade fora do `DiceRoller` só em IA e stun probabilístico (`battle_state.gd:1389, 1647, 3356, 3390-3413`). |

## Execução (concluída em 2026-11-13)

| Tarefa | Estado | Commit |
|---|---|---|
| D1/D6: teste mutilado, runner e `SCRIPT ERROR` | concluída | `83a1109` |
| D2/D4: save atômico, `load_save` validado, isolamento do save real | concluída | `e178ddc` |
| D5: `CombatantLayer` por índice | concluída | `6fe070d` |
| BG3: Envenenado, Atordoado, Prone, Furtivo, Downed (bg3.wiki) | concluída | `aa3e8ad` |
| Erros de runtime do combate (fallback de sprite, retrato) | concluída | `b7da3b3` |
| Proposta 6: UI usa `get_current_action()` | concluída | `188d3e2` |
| Reindexação final do grafo | concluída | 1878 nós, 5628 arestas |
| Segunda passagem arquitetural, docs, relatórios | concluída | commit de documentação |

## Estado final

- Suíte: `2040 passed, 0 failed`, 0 `SCRIPT ERROR`; `check_scripts_compile.gd`: 124 scripts, 0 quebrados.
- Grafo: reindexação `full` depois das mudanças, validada por consultas (ver relatório).
- Classificação: PRONTO COM RESSALVAS. Relatório: `final-audit-report.md` e `final-audit-report.html`.

## Próxima ação exata

Nada pendente de execução. Decisões do usuário (relatório, Pendências altas): destino de `chore/claude-code-setup`, efeito do auto-crítico em heróis Downed, e rodar `/mattpocock-skills:improve-codebase-architecture` se quiser a saída oficial da skill.
