# Architecture review — propostas 2 a 7 (P1 concluída) — Plano

> Execução: superpowers:executing-plans (Native). Ponytail full. Spec: relatório `architecture-review-20261113-014310.html` + pedido do usuário de 2026-11-13 ("refatoração completa"). Regra: combate fiel à BG3 (bg3.wiki); sem ampliar features.

**Base:** branch `fix/dano-centralizado` @ 3fcd2e9, suíte 1918/0. P1 (dano centralizado) concluída e revisada (ledger anterior: 0 Critical/0 Important).

## Global
- GDScript tipado, tabs, sem addons; `BattleState` não toca em nós.
- Cada tarefa: teste que falha → implementação → suíte completa → commit próprio.
- Comando: `godot --headless --path . --script tests/run_tests.gd` (helper `.superpowers/t.sh`).

## Tarefas (ordem por dependência)

1. **P2a — identidade e acesso por índice no BattleState.**
   - Nomes de inimigos únicos no setup (tipo repetido vira "Nome 2"), para `enemy_hp` não compartilhar HP.
   - Acessores por índice de TURN_QUEUE: `get_hp(idx)`, `get_max_hp(idx)`, `_set_hp(idx, v)` (clamp 0..max), `player_index_of(idx)`.
   - Trocar os ramos is_player/enemy_hp internos: cura, undo, `_save_undo_hp`, reembolsos e `_deal_damage_to_combatant`.
   - Teste: dois Goblins não compartilham HP; os acessores leem e escrevem PLAYERS e enemy_hp.
2. **P2b — scene e UI usam os acessores.**
   - `turn_order_bar`, `status_panel`, `examine_panel` (HP/CA vivos, não HeroData) e floaters do `battle_scene`.
   - `_find_player_idx` e `_state._player_index_by_name` na scene viram `player_index_of`.
3. **P3a — ciclo de vida das condições.**
   - `remove_condition(idx, key)` limpa as chaves companheiras (charmed_by, marked_*).
   - As escritas diretas de condição visível passam por `apply_condition` / `remove_condition`.
   - Atordoado/Paralisado quebram concentração de forma uniforme (BG3: Incapacitated quebra concentração).
   - Testes por caminho (Monge e inimigo).
4. **P3b — tick de turno.**
   - Os 4 loops copiados de "perde o turno" viram um helper.
   - Decaimento dos contadores numa tabela única, preservando o momento de cada um (Burning e veneno decaem no próprio tick; os outros no início do turno do portador).
   - Testes de regressão por condição.
5. **P4 — matemática de ataque compartilhada.**
   - `_attack_bonus(attacker, action)` e `_effective_ac(target)` (Ácido -2) usados pela rolagem real e por `calc_hit_chance`.
   - O preview inclui flat de elevação, bonus_d4 e Vantagem/Desvantagem como probabilidade, sem rolar dados.
   - `_spell_save_dc(attacker)` usa o atacante.
   - Ataque de oportunidade de inimigo usa os stats do inimigo.
6. **P5 — janela de reação antes do dano.**
   - `hold_hits_for_reactions` + `pending_hit`: com o hold ativo, os ataques de alvo único guardam o golpe; `commit_pending_hit()` aplica uma vez só.
   - Esquiva Sobrenatural e Defletir Projéteis reduzem o golpe pendente (pós-mitigação), antes de HP, concentração e Downed.
   - Smite por reação vira componente RADIANT do mesmo golpe.
   - A scene ativa o hold e faz o commit depois da fila de reações.
7. **P6 — economia de ações no BattleState.**
   - `can_use_action(action)` e `spend_action_cost(action)` cobrindo Ação, Bônus, slot (upcast), Ki e pool.
   - Ki, Second Wind, Hide e Dip deixam de ser gastos na scene.
   - `pp` deixa de ser mutado no Resource compartilhado.
   - Um único helper de upcast.
8. **P7 — rolagens determinísticas.**
   - Avaliar. Se justificado: `DiceRoller.force_next([...])` (fila de resultados) para testes, sem RNG injetado.
   - Documentar o que não for feito.

## Fora do escopo (justificar no fim)
- Substituir todos os canais efêmeros por uma lista de eventos única: só onde a P6/P5 provar ganho.
