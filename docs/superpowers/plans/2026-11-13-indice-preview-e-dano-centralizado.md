# Índice do preview + aplicação de dano centralizada — Plano de implementação

> **Para agentes:** SUB-SKILL OBRIGATÓRIA: use superpowers:subagent-driven-development (recomendado) ou superpowers:executing-plans para executar tarefa a tarefa. Passos usam checkbox (`- [ ]`).

**Objetivo:** (Etapa 1) corrigir o preview de Vantagem/Desvantagem que lê os status do combatente errado; (Etapa 2) fazer toda fonte de dano passar por um único ponto em `BattleState`, que aplica mitigação por tipo exatamente uma vez.

**Arquitetura:** não cria módulo novo. Aprofunda a função que já existe, `_deal_damage_to_combatant`, para ela ser o único lugar que mitiga, escreve HP, testa concentração e trata Downed/morte, devolvendo o dano aplicado. Estatísticas, floaters, `last_attack_info` e logs continuam onde estão; eles só passam a usar o valor devolvido.

**Stack:** Godot 4.7, GDScript tipado, `tests/run_tests.gd` (`_eq` / `_true`).

**Spec:** relatório `architecture-review-20261113-014310.html` (candidato 1) + pedido do usuário de 2026-11-13.

## Restrições globais

- Só GDScript, sem addons; tabs; UTF-8 + LF.
- `BattleState` não toca em nós; `BattleScene` só lê resultados.
- Não alterar `_mitigate` (núcleo puro e já testado).
- Nada das propostas 2–7 (lookup por índice, condições, resolver único, eventos, economia, dados injetados).
- Testes seguem o padrão existente do bloco "Integração: mitigação" (`run_tests.gd:3112-3169`): `setup_party(["Guerreiro"])`, imunidade/vulnerabilidade via `.assign([...])` e restauração ao fim, salvando e restaurando `TURN_QUEUE`/`PLAYERS`.
- Baseline atual: **1827 passed, 0 failed** (os `SCRIPT ERROR ... process_frame` já existem e não são falhas).
- Comando de teste: `"d:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path . --script tests/run_tests.gd`, filtrado com `| Select-String "FAIL|Results"`.

## Achados confirmados (reproduzidos com script fora do repo)

| # | Bug | Repro (código atual) |
|---|---|---|
| 1 | `battle_area.gd:397` passa índice de `PLAYERS` para `get_attack_roll_mods`, que espera índice de `TURN_QUEUE` | Mago cego em `TURN_QUEUE[2]`/`PLAYERS[1]`: o preview lê o Guerreiro → `dis 0`; a rolagem real dá `dis 1`. Na partida, `roll_initiative()` embaralha a fila, então o desalinhamento é o caso comum. |
| 2a | Burning / fogo ao entrar ignoram imunidade | Herói imune a FIRE: HP 50 → 46 |
| 2b | Água eletrificada ignora Wet | Rolou 2 em alvo Wet: aplicou 2 (esperado 4) |
| 2c | AoE inimigo (Frost Nova) ignora mitigação | Herói imune a COLD: HP 50 → 42 |
| 2d | **Mitigação dupla** no splash do ramo de ataque (`_apply_attack:2656`): passa metade do dano **já mitigado pelo primário**, e `_aoe_damage_at` mitiga de novo | Primário imune a FIRE → vizinho **não** imune toma 0 |

Os quatro também valem para inimigos: hoje nenhum conteúdo define resistências, então o impacto em partida vem de Wet (COLD/THUNDER) e de qualquer resistência adicionada no futuro.

### Por que 16 e por que ~24

- **16** = escritas de **dano** em HP: um ramo jogador e um ramo inimigo por site: 375/381, 745/750, 991/996, 1433, 1652/1657, 2493/2502, 2626/2635, 2700/2706, 3318.
- **24** = linhas que o meu `grep` casou para *qualquer* escrita de HP: 15 das 16 de dano (a 381 não casou porque `enemy_hp[entry["name"]]` tem colchete aninhado) **+ 9 que não são dano**: setup 100, devolução de reação 1600/1623, undo 1984/1986, item 2006, revive 2399, cura 2423/2749.
- Fontes **lógicas** de dano: 4 sites mitigam (cobrindo 6 fontes: ataque inimigo, primário do save, primário do ataque, núcleo de AoE = splash do save, splash do ataque e AoE no chão). 9 fontes não mitigam (tabela abaixo).

### Quais fontes mitigam, segundo as regras atuais

O enum hoje é `PHYSICAL, ARCANE, RADIANT, FIRE, COLD, THUNDER, HEALING, NECROTIC`. Não existe POISON.

| Fonte | Local | Hoje | Tipo a usar | Base |
|---|---|---|---|---|
| Ataque/spell de jogador (primário) | `_apply_attack` 2618 | mitiga | `action.damage_type` | já correto |
| Spell com save (primário) | 2488 | mitiga | `action.damage_type` | já correto |
| AoE (splash save/ataque, no chão) | `_aoe_damage_at` 2692 | mitiga | `action.damage_type` | já correto |
| Ataque inimigo corpo a corpo/distância | 1430 | mitiga | PHYSICAL | já correto |
| Splash do ramo de ataque | 2656 | **mitiga 2×** | passar metade **pré-mitigação** | bug 2d |
| Burning (tick) | 762 | não | FIRE | floater/label já é Fogo |
| Fogo ao entrar | 939 | não | FIRE | idem |
| Água eletrificada (entrar e tick) | 954, 479 | não | THUNDER | floater "Raio"; o tick hoje usa cor/label PHYSICAL "Cortante" por engano |
| Nuvem de Adagas (entrar e tick) | 965, 479 | não | PHYSICAL | cortante = PHYSICAL no enum |
| Armadilha | 987 | não | PHYSICAL | floater já é PHYSICAL |
| Smite Divino por reação | 1652 | não | RADIANT | log já diz "radiante" |
| AoE inimigo | 3314 | não | por comportamento (ver decisão D1) | floater hoje é sempre COLD |
| DoT de veneno | 741 | não | **sem tipo → não mitiga** | o enum não tem POISON (decisão D2) |

**Fica de fora (simplificação existente, não mexer):** bônus dentro do ataque do jogador (Furtivo, Fúria, Marca, Smite da ação, Arma em chamas) somam ao dano e são mitigados como `action.damage_type`. Separar componentes por tipo é outro trabalho.

### Decisões que preciso que você confirme

- **D1 — tipo do AoE inimigo.** Proposta: chave opcional `"damage_type"` no dicionário de `action_behaviors` (padrão PHYSICAL quando ausente). Frost Nova (Dark Mage) e Ice Storm (Elite Mage) = COLD. Sweeping Strike (Elite Warrior) e Shockwave (Dungeon Guardian) = PHYSICAL. Shockwave poderia ser THUNDER: diga se preferir.
- **D2 — veneno.** Proposta: continua sem mitigação (não há tipo POISON). Adicionar POISON ao enum fica para depois.
- **D3 — concentração em fontes que hoje não testam** (veneno, armadilha, smite). Proposta: sim, testar. É a regra BG3/5e que o código já segue nos outros sites. É **mudança de comportamento**, então tem teste próprio.

---

## Etapa 1 — bug de índice do preview

### Tarefa 1: preview pede os mods do combatente ativo, sem índice

**Arquivos:**
- Modificar: `battle/battle_state.gd:2147-2148` (substitui o repasse `get_attack_roll_mods`)
- Modificar: `battle/battle_area.gd:396-403`
- Teste: `tests/run_tests.gd` (atualizar 713 e 1826; novo teste ao lado de 1826)

**Interfaces:**
- Produz: `BattleState.get_active_attack_roll_mods(target_idx: int) -> Dictionary`, que devolve `_get_attack_roll_mods(active_index, target_idx, current_attack_range)` no turno de jogador e `{"adv": 0, "dis": 0, "flat": 0, "bonus_dice": 0}` fora dele.
- Remove: `get_attack_roll_mods(attacker_idx, target_idx, attack_range)`. O único chamador de produção é `battle_area.gd:401`. Quem precisar de um índice arbitrário (os testes) continua usando `_get_attack_roll_mods`.

**Por que essa forma:** o chamador não escolhe mais índice nenhum, então o erro deixa de ser possível. E o teste exercita exatamente o que o preview chama.

- [ ] **Passo 1: teste que falha**

```gdscript
# ── Preview usa o combatente ATIVO (índice de TURN_QUEUE, não de PLAYERS) ──
var _pv_tq: Array = BattleState.TURN_QUEUE
var _pv_pl: Array = BattleState.PLAYERS
BattleState.setup_party(["Guerreiro", "Mago"])
var _pv_en: Dictionary = BattleState.TURN_QUEUE[2]
BattleState.TURN_QUEUE.remove_at(2)
BattleState.TURN_QUEUE.insert(0, _pv_en)          # [inimigo, Guerreiro, Mago, ...]
var s_pv := BattleState.new()
s_pv.active_index = 2                              # Mago: PLAYERS[1], TURN_QUEUE[2]
s_pv.current_attack_range = 1
s_pv.combatant_statuses[2]["blinded"] = 2
_eq("preview: mods do ativo (Mago cego → dis 1)", s_pv.get_active_attack_roll_mods(3)["dis"], 1)
_eq("preview: Guerreiro (PLAYERS idx 1 ≠ ativo) não contamina", s_pv.get_active_attack_roll_mods(3)["adv"], 0)
s_pv.active_index = 0                              # turno de inimigo
_eq("preview: fora do turno de jogador → neutro", s_pv.get_active_attack_roll_mods(3)["dis"], 0)
BattleState.TURN_QUEUE = _pv_tq
BattleState.PLAYERS = _pv_pl
```

- [ ] **Passo 2: rodar.** Esperado: erro de método inexistente (`get_active_attack_roll_mods`).
- [ ] **Passo 3: implementar** `get_active_attack_roll_mods` no lugar de `get_attack_roll_mods`. Em `battle_area.gd`, trocar o bloco `pidx`/`get_attack_roll_mods` por `var rm := _state.get_active_attack_roll_mods(cidx)`, lendo `adv`/`dis` dali.
- [ ] **Passo 4: atualizar testes antigos.** Em 713 (`s_hide_adv`, active 0) e 1826 (`s_advmods`, active 0, range 1): trocar para `get_active_attack_roll_mods(alvo)`, setando `current_attack_range = 1` em 713. Renomear o label de 1827 para "get_active_attack_roll_mods is public".
- [ ] **Passo 5: suíte completa.** Esperado: `Results: 1830 passed, 0 failed` (1827 + 3).
- [ ] **Passo 6: verificação manual** (`godot --path .`): Mago cego mirando um inimigo mostra "Desvantagem" no preview.
- [ ] **Passo 7: commit** `fix(ui): preview de Vantagem usa o combatente ativo (indice de TURN_QUEUE)`

**Rollback:** `git revert` desse commit. Não há dependência com a Etapa 2.
**Aceitação:** o preview e a rolagem real usam a mesma fonte de status; `get_attack_roll_mods` não existe mais; 1830/0.

---

## Etapa 2 — aplicação de dano centralizada

Ordem pensada para cada commit ser revertível sozinho e a suíte ficar verde a cada passo.

### Tarefa 2: aprofundar `_deal_damage_to_combatant` + superfícies e Burning

**Arquivos:**
- Modificar: `battle/battle_state.gd:368-383` (função), 461-480 (`_apply_surface_tick`), 756-764 (Burning), 936-966 (`apply_surface_on_enter`), 428 (corrigir o comentário "Engrenagem ÚNICA")
- Teste: `tests/run_tests.gd`, novo bloco depois de 3169

**Interfaces:**
- Produz: `const UNTYPED_DAMAGE := -1` e `_deal_damage_to_combatant(idx: int, amount: int, damage_type: int, is_crit: bool = false) -> int`. Devolve o dano aplicado depois da mitigação. Regras, nesta ordem:
  1. Mitiga com `_apply_damage_type_mods`, a menos que `damage_type == UNTYPED_DAMAGE`. Esse guarda é obrigatório: `keys()[-1]` resolveria para NECROTIC.
  2. Se o aplicado for `<= 0`, devolve 0 **sem** tocar em HP, concentração nem morte.
  3. Escreve HP (jogador em `PLAYERS`, inimigo em `enemy_hp`, `maxi(0, …)`).
  4. `_check_concentration_after_damage(idx, aplicado)` para qualquer lado. Hoje só heróis concentram, então para inimigos é no-op.
  5. Se HP `<= 0`: herói que já estava Downed → `_add_death_save_failure(idx, 2 if is_crit else 1)`. Senão → `_on_death(idx)`.
- Os 5 chamadores passam: Burning FIRE, fogo ao entrar FIRE, eletrificada ao entrar THUNDER, Nuvem ao entrar PHYSICAL, tick conforme a superfície (ELECTRIFIED_WATER → THUNDER, rótulo "Raio"; CLOUD_OF_DAGGERS → PHYSICAL, rótulo "Cortante").
- Floaters e logs passam a ser registrados **depois** da chamada, com o valor devolvido.

- [ ] **Passo 1: testes que falham**

```gdscript
# ── Dano centralizado: _deal_damage_to_combatant ─────────────────────────
var _dd_tq: Array = BattleState.TURN_QUEUE
var _dd_pl: Array = BattleState.PLAYERS
BattleState.setup_party(["Guerreiro"])
var hd_dd: HeroData = BattleState.ALL_HERO_DATA["Guerreiro"]
var s_dd := BattleState.new()
var p_dd: Dictionary = BattleState.PLAYERS[0]
var dd_en: String = BattleState.TURN_QUEUE[1]["name"]
var dd_et: String = BattleState.TURN_QUEUE[1]["type"]

hd_dd.immunities.assign(["FIRE"]); p_dd["hp"] = 50
_eq("dano: imune devolve 0", s_dd._deal_damage_to_combatant(0, 8, ActionData.DamageType.FIRE), 0)
_eq("dano: imune não altera HP", p_dd["hp"], 50)
hd_dd.immunities.assign([])

BattleState.ALL_ENEMIES[dd_et].resistances.assign(["COLD"])
var dd_hp0: int = s_dd.enemy_hp[dd_en]
_eq("dano: inimigo resistente → metade", s_dd._deal_damage_to_combatant(1, 9, ActionData.DamageType.COLD), 4)
_eq("dano: HP inimigo -4", s_dd.enemy_hp[dd_en], dd_hp0 - 4)
BattleState.ALL_ENEMIES[dd_et].resistances.assign([])

p_dd["hp"] = 50; s_dd.combatant_statuses[0]["wet"] = 2
_eq("dano: UNTYPED ignora Wet/listas", s_dd._deal_damage_to_combatant(0, 3, BattleState.UNTYPED_DAMAGE), 3)
s_dd.combatant_statuses[0].erase("wet")

# Downed: imune não gera falha; crit gera 2
p_dd["hp"] = 1
s_dd._deal_damage_to_combatant(0, 5, ActionData.DamageType.PHYSICAL)   # entra em Downed
_true("dano: 0 HP → Downed", s_dd.is_downed(0))
hd_dd.immunities.assign(["FIRE"])
s_dd._deal_damage_to_combatant(0, 5, ActionData.DamageType.FIRE)
_eq("dano: imune em Downed não soma falha", s_dd.combatant_statuses[0].get("death_saves_failure", 0), 0)
hd_dd.immunities.assign([])
s_dd._deal_damage_to_combatant(0, 5, ActionData.DamageType.PHYSICAL, true)
_eq("dano: crit em Downed soma 2 falhas", s_dd.combatant_statuses[0].get("death_saves_failure", 0), 2)

# Superfícies/Burning roteadas (repro 2a/2b)
var s_sf := BattleState.new()
BattleState.PLAYERS[0]["hp"] = 50
hd_dd.immunities.assign(["FIRE"])
s_sf.tile_surfaces[Vector2i(4, 3)] = {"type": SurfaceType.Type.FIRE, "turns": 3}
s_sf.apply_surface_on_enter(0, Vector2i(4, 3))
_eq("fogo ao entrar vs imune FIRE: HP intacto", BattleState.PLAYERS[0]["hp"], 50)
hd_dd.immunities.assign([])
BattleState.PLAYERS[0]["hp"] = 50
s_sf.combatant_statuses[0]["wet"] = 2
s_sf.tile_surfaces[Vector2i(5, 3)] = {"type": SurfaceType.Type.ELECTRIFIED_WATER, "turns": 3}
seed(1); var sf_roll: int = DiceRoller.roll(1, 4); seed(1)
s_sf.apply_surface_on_enter(0, Vector2i(5, 3))
_eq("eletrificada vs Wet: dobro (THUNDER)", 50 - BattleState.PLAYERS[0]["hp"], sf_roll * 2)
BattleState.TURN_QUEUE = _dd_tq
BattleState.PLAYERS = _dd_pl
```

Mais um teste para o **tick** (`_apply_surface_tick` em ELECTRIFIED_WATER): o floater em `pending_surface_hits` tem `label == "Raio"` e `damage == valor aplicado`.

- [ ] **Passo 2: rodar.** Esperado: FAIL nos testes de chamada (assinatura) e nos de superfície.
- [ ] **Passo 3: implementar** a função e atualizar os 5 chamadores.
- [ ] **Passo 4: suíte completa.** Esperado: 0 failed. Conferir que os testes existentes de Burning/superfície (floater "Fogo", tick 1×/turno) continuam verdes.
- [ ] **Passo 5: commit** `refactor(combat): _deal_damage_to_combatant mitiga e trata morte; superficies e Burning roteados`

**Rollback:** revert do commit; as tarefas seguintes dependem dele, então reverter na ordem inversa.

### Tarefa 3: veneno, armadilha e Smite por reação

**Arquivos:** `battle/battle_state.gd:739-755` (veneno), 980-1004 (`_check_trap`), 1646-1659 (smite); testes.

**Interfaces:** consome a Tarefa 2. Veneno usa `UNTYPED_DAMAGE` (D2); armadilha usa PHYSICAL e **`combatant_idx`**, o que também elimina o `get_active_player_index()` errado da linha 989; smite usa RADIANT, com `last_attack_info["amount"]`/`smite_amount` somando o valor **aplicado**.

- [ ] **Passo 1: testes que falham:**
  - armadilha em herói imune a PHYSICAL → HP intacto, ainda fica `poison = 3` e deixa superfície POISON;
  - armadilha disparada por herói fora do turno dele (`active_index` = inimigo) → toma dano (hoje não toma);
  - smite em inimigo imune a RADIANT → HP intacto e `apply_divine_smite_reaction` devolve 0;
  - D3: herói concentrando (`concentration_by_caster[0] = {"label": "x", "action": ActionData.new()}`) toma dano de armadilha com save forçado a falhar → `concentration_by_caster` não tem mais a chave 0. `_find_seed_for_d20` não serve aqui, porque o 2d4 da armadilha é rolado antes do d20 do save. Escreva um laço local: para `s` em `range(200000)`, faça `seed(s)`, `DiceRoller.roll(2, 4)` e pare quando `DiceRoller.roll_d(20) == 1`; depois `seed(s)` e dispare `_check_trap`.
- [ ] **Passo 2: rodar.** Esperado: FAIL nos quatro.
- [ ] **Passo 3: implementar** (substituir os blocos jogador/inimigo de cada site pela chamada).
- [ ] **Passo 4: suíte completa.** 0 failed (os testes existentes de armadilha 3172-3187 e de veneno devem continuar verdes).
- [ ] **Passo 5: commit** `fix(combat): veneno, armadilha e Smite por reacao passam pelo dano centralizado`

**Rollback:** revert isolado (só depende da Tarefa 2).

### Tarefa 4: AoE inimigo com tipo por comportamento

**Arquivos:** `battle/battle_state.gd:3288-3337`; `enemies/dark_mage.gd:36-37`, `enemies/elite_mage.gd:37-38` (adicionar `"damage_type": ActionData.DamageType.COLD`); testes.

**Interfaces:** `_apply_enemy_aoe_attack(b)` lê `b.get("damage_type", ActionData.DamageType.PHYSICAL)`, chama `_deal_damage_to_combatant(i, damage, dtype)`, soma `enemy_damage_dealt` e registra o floater com o **aplicado**, colorido por `damage_type_color(dtype)`.

- [ ] **Passo 1: testes que falham:** Frost Nova (`{"aoe_radius": 1, "damage_mult": 0.8, "damage_type": COLD}`) vs herói imune a COLD → HP intacto e nenhum floater; sem a chave → herói imune a PHYSICAL fica intacto; o comportamento real do Dark Mage (`ALL_ENEMIES["Mage"].action_behaviors[2]["damage_type"]`) é COLD.
- [ ] **Passo 2: rodar → FAIL. Passo 3: implementar. Passo 4: suíte → 0 failed.**
- [ ] **Passo 5: commit** `fix(combat): AoE inimigo mitigado pelo tipo do comportamento (Frost Nova/Ice Storm = COLD)`

**Rollback:** revert isolado.

### Tarefa 5: os 4 sites que já mitigam passam a usar a função

**Arquivos:** `battle/battle_state.gd` 1429-1439 (ataque inimigo), 2488-2504 (save primário), 2617-2637 (ataque primário), 2691-2708 (`_aoe_damage_at`); `docs/architecture/battle.md` (seção de dano: "todo dano passa por `_deal_damage_to_combatant`").

**Interfaces:** cada site faz `damage = _deal_damage_to_combatant(idx, damage, tipo, is_crit)` e só depois soma stats, monta `last_attack_info` e loga. `_save_undo_hp` continua **antes** da chamada. O save primário passa `is_crit = false`, mantendo a 1 falha atual.

- [ ] **Passo 1: rede de segurança antes de mexer:** rodar a suíte e anotar que os testes de mitigação de integração (3112-3169), death saves e concentração estão verdes. É refactor puro: nenhum teste novo deve ser necessário, e nenhum existente pode mudar.
- [ ] **Passo 2: implementar** site a site, rodando a suíte depois de cada um.
- [ ] **Passo 3: suíte completa.** 0 failed, mesma contagem do passo 1.
- [ ] **Passo 4: grep de aceitação:** `_apply_damage_type_mods(` aparece só na definição e dentro de `_deal_damage_to_combatant`; escritas de dano em HP (`["hp"] = maxi(0` / `enemy_hp[...] = ` de dano) aparecem só dentro dela.
- [ ] **Passo 5: commit** `refactor(combat): todos os pontos de dano usam _deal_damage_to_combatant`

**Rollback:** revert isolado (não muda comportamento).

### Tarefa 6: corrigir a mitigação dupla no splash do ataque

**Arquivos:** `battle/battle_state.gd:2616-2656`; testes.

**Interfaces:** guardar `var pre_mit: int = damage` logo após `damage = maxi(1, damage)` e chamar `_apply_aoe_splash(target_idx, int(pre_mit / 2.0), 0, action)`.

- [ ] **Passo 1: teste que falha** (repro 2d): ação FIRE com `aoe_radius = 1`, primário imune a FIRE, vizinho sem listas → o vizinho toma `> 0`. Segundo caso: primário vulnerável a FIRE, vizinho sem listas → splash = metade do **pré-mitigação**. Para fixar o valor, use `seed(n)` e calcule o esperado com a mesma sequência de rolagens.
- [ ] **Passo 2: rodar → FAIL. Passo 3: implementar. Passo 4: suíte → 0 failed.**
- [ ] **Passo 5: commit** `fix(combat): splash de AoE do ataque nao mitiga duas vezes`

**Rollback:** revert isolado. É uma linha, e só ela muda números de splash.

---

## Review Focus

1. **Imune com 0 HP / Downed:** dano mitigado a 0 não pode somar falha de Death Save nem chamar `_on_death`. Coberto na Tarefa 2.
2. **`UNTYPED_DAMAGE` chegando em `_mitigate`:** `keys()[-1]` = NECROTIC, ou seja, veneno passaria a ser mitigado como necrótico sem erro visível. Coberto pelo teste "UNTYPED ignora Wet/listas" na Tarefa 2.
3. **Floater mostrando valor bruto:** todo floater registrado depois da chamada, com o aplicado; imune → nenhum floater. Coberto nas Tarefas 2 e 4.
4. **Undo de ataque** (`cancel_confirmed_attack`): `_save_undo_hp` tem que continuar antes da escrita de HP. Adicionar à Tarefa 5 um teste: ataque em inimigo, cancelar → HP volta ao valor inicial.
5. **Reações Esquiva Sobrenatural / Desviar Projéteis** continuam reembolsando sobre o valor **já mitigado** (comportamento atual). Adicionar à Tarefa 5 um teste: herói resistente toma ataque inimigo, aplica Uncanny Dodge → HP final = inicial − (mitigado − mitigado/2).

## Critérios de aceitação gerais

- Etapa 1: preview e rolagem usam o mesmo combatente; suíte verde.
- Etapa 2: as 9 fontes da tabela aplicam a mitigação definida, uma única vez; os 4 repros 2a–2d viram testes verdes; nenhum teste antigo muda de expectativa, exceto os renomeados na Tarefa 1; o grep da Tarefa 5 bate.
- Comportamentos intencionalmente novos, cada um com teste: concentração em veneno/armadilha/smite (D3); armadilha fora do próprio turno; splash não mitiga duas vezes; tick da água eletrificada com rótulo "Raio".

---

## Revisão pós-aprovação (2026-11-13)

O usuário aprovou com decisões mais amplas: **D1** tipos de dano BG3 reais e dano em componentes; **D2** tipo POISON com mitigação; **D3** concentração BG3. Regras verificadas na bg3.wiki:

- 13 tipos: Bludgeoning, Piercing, Slashing, Acid, Cold, Fire, Force, Lightning, Necrotic, Poison, Psychic, Radiant, Thunder. "Each damage type is dealt separately."
- Wet: vulnerável a Cold e Lightning, **resistente a Fire**, imune a Burning. Resistência + vulnerabilidade se anulam.
- Concentração: CD = max(10, metade do dano); dano reduzido a 0 não dispara o teste.
- Downed: dano = 1 falha, crítico = 2 falhas; corpo a corpo em Downed é sempre crítico.
- Burning 1d4 Fire/turno. Electrified Water 1d4 **Lightning**. Cloud of Daggers 4d4 **Slashing**. Dip in Fire +1d4 Fire. Hunter's Mark 1d6 do tipo da arma. Simple Toxin 1d4 Poison.

### Tarefa nova 2 (antes da centralização): tipos BG3

Esta tarefa troca a numeração das tarefas: a antiga 2 vira 3, e assim por diante até a 6, que vira 7.

- `ActionData.DamageType` = `{SLASHING, PIERCING, BLUDGEONING, ACID, COLD, FIRE, FORCE, LIGHTNING, NECROTIC, POISON, PSYCHIC, RADIANT, THUNDER, HEALING}`. Somem PHYSICAL e ARCANE. O padrão de `ActionData.damage_type` passa a ser BLUDGEONING.
- Os ints do enum não são persistidos em lugar nenhum: grep em `dungeon/` e `ui/` não acha nada.
- `WeaponData.damage_type` + parâmetro em `HeroData.make_weapon`. Longsword/Greataxe = SLASHING; Shortsword/Longbow = PIERCING; Mace/Quarterstaff/Unarmed = BLUDGEONING.
- Ataque com arma (`is_weapon_attack`) causa o tipo da arma. Fúria, Furtivo e Marca somam ao componente da arma.
- `EnemyData.attack_damage_type` (padrão BLUDGEONING) + chave opcional `"damage_type"` em cada `action_behaviors`.
- Wet em `_mitigate`: COLD/LIGHTNING vulnerável, FIRE resistente.

### Rulings

- Trovão vira LIGHTNING: eletrifica água, usa VFX de raio e save de DEX, que é a mecânica de raio na BG3. O rótulo "Trovao" fica como está; renomear é decisão de conteúdo.
- Raio Arcano (ARCANE) vira FORCE: ARCANE não é tipo BG3, e Force é o equivalente do 1d10 arcano.
- Atq. Rápido, Soco e Flurry viram BLUDGEONING (golpe desarmado BG3). Chuva de Flechas e Atq. Preciso usam flechas, então PIERCING.
- Inimigos são conteúdo original sem fonte BG3, então o tipo vem do que a ação descreve:
  - Goblin: SLASHING (cimitarra); a adaga arremessada é PIERCING.
  - Orc "Smashing": BLUDGEONING. Skeleton Archer: PIERCING.
  - Dark Mage: Shadow Bolt NECROTIC, Frost Nova COLD.
  - Elite Mage: Arcane Bolt FORCE, Ice Storm COLD.
  - Elite Warrior: BLUDGEONING. Dungeon Guardian: BLUDGEONING, e Shockwave THUNDER.
- Armadilha: 2d4 PIERCING (dardo envenenado: perfura e aplica o DoT). O DoT `poison` vira 1d4 POISON (Simple Toxin), separado da condição `poisoned` (Desvantagem).
- Componentes: `_deal_damage_to_combatant(idx, amount, type, is_crit := false, extra := {})`. `extra` = {tipo: valor}, cada componente mitigado separadamente e somado num único dano. Uma escrita de HP, um teste de concentração sobre o total aplicado; a wiki não fala de um teste por componente. Smite (RADIANT) e Arma em chamas (FIRE) entram como componentes.
- Splash do ataque: metade do total **pré-mitigação**, do tipo principal; os componentes extras não respingam.
- Fora do escopo, ficam como diferenças conhecidas:
  - Wet imune a Burning;
  - corpo a corpo em Downed sempre crítico;
  - Fúria como redução fixa, e não como resistência B/P/S;
  - Ice Storm com componente Bludgeoning.
