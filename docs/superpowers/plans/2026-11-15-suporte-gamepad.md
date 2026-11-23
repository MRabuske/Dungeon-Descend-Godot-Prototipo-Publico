# Suporte a controle (gamepad) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Jogar o Dungeon Descend 100% por controle (layout Xbox; PlayStation pelo mapeamento padrão do Godot), com troca instantânea entre controle e mouse/teclado, cursor de grid unificado, exame pela barra de turnos, dicas de botões dinâmicas e vibração configurável.

**Architecture:** Um autoload `InputDevice` classifica cada evento (via `InputDeviceTracker`, lógica pura) e define o dispositivo ativo ("o último manda"), esconde/mostra o mouse e **traduz** A/B/D-pad/analógico-digital/LB/RB/Start em teclas sintéticas (Enter/Esc/setas/Q/E/P). Assim todas as telas que já leem `KEY_*` passam a funcionar sem reescrita e o teclado não regride. Comandos exclusivos do combate (X, Y/Tab, View, R3, L3) são `InputMap` actions registradas em código; analógicos (cursor livre, câmera, LT) são lidos por polling. No combate, a lógica de cursor vive em `BattleState` (`cursor_tile`, validade, confirmação), alimentada por mouse, analógico e D-pad/setas; `BattleArea` só desenha e move câmera. Sem sinais novos: `HintBar` consulta `InputDevice.active_device` por polling.

**Tech Stack:** Godot 4.7.2, GDScript tipado, suíte `tests/run_tests.gd`.

**Spec:** prompt da sessão "FEATURE: Suporte completo a controle (gamepad) com troca dinâmica de dispositivo" (seções 3.1–3.8, 4, 8, 9, 10, 11); regras de combate de `.claude/rules/game-rules.md` não mudam.

## Global Constraints

- Nenhuma regra de combate muda: alcance, linha de visão, elevação, validade de alvo, economia de ação e resolução idênticos. Grid 1 quadrado = 5 ft; áreas e métricas de distância intactas; câmera isométrica intacta.
- Mapeamento direcional atual das setas no grid fica: UP `(0,-1)`, DOWN `(0,1)`, LEFT `(-1,0)`, RIGHT `(1,0)` (WASD igual). D-pad usa o mesmo.
- Elevação nunca interfere na navegação por quadrado; D-pad/setas na borda do grid mantêm o último quadrado válido.
- Mapa de botões aprovado: stick E = menus/cursor livre; D-pad = menus/pular quadrado; A confirmar; B voltar (= Esc atual); X encerrar turno; Y exame; LB/RB aba (Q/E); LT segurar = visão dos inimigos (Shift); stick D = câmera; R3 = zoom; Start = pausa; View = log.
- Scripts: tipados, tabs, UTF-8/LF; arquivos de autoload sem `class_name`; `GameSettings` é o único escritor de settings; testes só gravam em `user://test_sandbox/` e nunca no settings/save reais.
- Fora de escopo: co-op local, remapeamento, ícones PlayStation, arte final (glifos são placeholders desenhados em código). Sem commit/push.
- Mira (teclado e controle): em todos os modos setas/D-pad andam de quadrado em quadrado; Confirmar só executa em quadrado válido; inválido → feedback e nenhum recurso consumido.
- `SAVE_VERSION` não muda (settings ganham chave nova com default; save intocado).

## Decisões de design (propostas; veto no review do plano)

1. **Ponte de teclas sintéticas** em vez de reescrever 12 scripts. Eventos reais de joypad das teclas-ponte são consumidos (`set_input_as_handled`) para não ativar `ui_accept` duas vezes. Eventos sintéticos levam `set_meta("bridged", true)` e não contam para a troca de dispositivo.
2. **O primeiro botão que "acorda" o controle só troca o dispositivo** (não confirma nada às cegas). Teclado/mouse nunca são engolidos.
3. **Sem equivalente de teclado = dica escondida** (X fim de turno, View log, R3 zoom/câmera têm mouse; o teclado ganha só o que a spec pede: Tab = exame).
4. **L3 (clicar analógico esquerdo) = ciclar filtro de ações** (Action/Bonus/slots/Ki) e tecla `F` no teclado: é a única forma de dar função aos indicadores clicáveis da HUD (3.8) sem inventar tela nova. **Único botão fora da tabela aprovada.**
5. Analógico esquerdo no grid usa cursor virtual (`BattleArea.pointer_pos`), nunca `warp_mouse` (warp geraria evento de mouse e voltaria o dispositivo).
6. Limites da câmera: o analógico/borda só rola se o mapa ainda extrapola a tela naquela direção, além do `MAX_PAN` atual. Arrastar com mouse mantém o clamp atual.
7. Popup de reação com 2+ opções ganha navegação (cima/baixo; Enter alterna a caixa destacada; descer até "Confirmar"/"Não Reagir"); com 1 opção Enter aceita e Esc recusa, como hoje.

## Review Focus

- Controle conecta/desconecta no meio do jogo: dispositivo cai para teclado/mouse, dicas viram teclas, sem pausa nem erro. (Task 1, Task 4)
- Drift do analógico (<0.5 não troca dispositivo; <0.25 não move cursor/menu). (Task 1, Task 5)
- Cursor fora do grid / quadrado vazio / `(-1,-1)` do mouse fora da área: Confirmar não executa nem gasta recurso. (Task 3)
- Estado muda no meio de um modo (mirando com o mouse e pegando o controle; ordem de turnos muda com morte durante o exame). (Task 3, Task 6)
- Vários eventos de vibração no mesmo instante (crítico + Downed) não geram vibração longa ou contínua; vibração desligada ou sem controle: nenhum erro. (Task 4)

---

## File Structure

| Arquivo | Ação | Responsabilidade |
|---|---|---|
| `input/input_device_tracker.gd` | criar | `InputDeviceTracker`: dispositivo ativo, zona morta, direção 4-way (puro) |
| `input/input_glyphs.gd` | criar | `InputGlyphs.label(action, device)`: texto da dica por dispositivo (puro) |
| `input/input_rumble.gd` | criar | `InputRumble`: perfis e decisão de vibrar (puro) |
| `input/input_bindings.gd` | criar | `InputBindings.register()`: actions `act_*` no `InputMap` |
| `input/input_device.gd` | criar (autoload `InputDevice`) | classificação de eventos, cursor do mouse, ponte de teclas, eixos, vibração |
| `ui/hint_bar.gd` | criar | `HintBar` + glifos placeholder desenhados |
| `battle/battle_camera.gd` | criar | `BattleCamera`: matemática de rolagem de borda e limites (estático) |
| `game_settings.gd` | modificar | `static var PATH`, chave `vibration` |
| `project.godot` | modificar | autoload `InputDevice` |
| `battle/battle_state.gd` | modificar | cursor unificado, feedback, exame, `pending_downed`, `hit_rumble_kind` |
| `battle/battle_area.gd` | modificar | cursor virtual, borda/câmera, zoom R3, desenho de validade, destaque de exame |
| `battle/battle_scene.gd` | modificar | roteamento de input, confirmação por cursor, exame, vibração, dicas |
| `battle/ui/turn_order_bar.gd`, `context_menu.gd`, `reaction_popup.gd`, `pause_menu.gd`, `examine_panel.gd`, `action_panel.gd`, `battle_result_screen.gd` | modificar | borda de exame, Enter no menu, navegação, dicas, foco, filtro |
| `ui/main_menu.gd`, `party_select.gd`, `dungeon_map.gd`, `options_panel.gd`, `event_scene.gd` | modificar | dicas, foco, toggle de vibração |
| `tests/run_tests.gd` | modificar | `_test_gamepad_support` + ajustes dos testes de navegação antiga |
| `CLAUDE.md`, `docs/architecture/input.md` | modificar/criar | autoload novo e referência do input |

---

### Task 0: Spike das premissas do Godot (descartável)

**Files:** script temporário no scratchpad (não entra no repo).

**Interfaces:** Produces: respostas às 4 premissas que a ponte exige.

- [ ] **Step 1:** Escrever um `SceneTree` script que adiciona um `Node` com `_input` que registra eventos e faz: (a) `Input.parse_input_event()` de um `InputEventKey` com `set_meta("bridged", true)`; (b) injeta Enter com um `Button` focado e conta quantos `pressed`; (c) `Input.start_joy_vibration(0, .5, .5, .1)` sem controle; (d) um autoload-like filho adicionado depois de outro nó recebe `_input` antes ou depois.
- [ ] **Step 2:** Rodar `"$GODOT" --headless --script <arquivo>`. Esperado: (a) o `_input` recebe o MESMO evento com a meta, de forma síncrona; (b) 1 `pressed`; (c) sem erro; (d) ordem registrada. Se (a) falhar, trocar a marca por flag `_injecting` ao redor de `parse_input_event`; registrar a escolha no topo de `input/input_device.gd`.

---

### Task 1: Rastreador de dispositivo e rótulos (lógica pura)

**Files:**
- Create: `input/input_device_tracker.gd`, `input/input_glyphs.gd`
- Test: `tests/run_tests.gd` (nova função `_test_gamepad_support`, listada em `EXPECTED_TO_FINISH`, terminando com `_reached.append("_test_gamepad_support")`)

**Interfaces:**
- Produces:
  - `InputDeviceTracker extends RefCounted`; `enum Device { KEYBOARD_MOUSE, GAMEPAD }`; `const AXIS_SWITCH_THRESHOLD := 0.5`; `const STICK_DEADZONE := 0.25`; `var active: Device`; `var gamepad_id: int = -1`
  - `note_key() -> bool`, `note_mouse_motion(relative: Vector2) -> bool` (ignora `relative.length() < 0.5`), `note_mouse_button() -> bool`, `note_joy_button(device_id: int) -> bool`, `note_joy_axis(device_id: int, value: float) -> bool` (só `abs(value) >= AXIS_SWITCH_THRESHOLD`), `note_joy_disconnected(device_id: int) -> bool`; todos retornam `true` se `active` mudou
  - `static apply_deadzone(v: Vector2, deadzone: float = STICK_DEADZONE) -> Vector2` (radial, reescalado a 0..1), `static stick_dir4(v: Vector2, threshold: float = AXIS_SWITCH_THRESHOLD) -> Vector2i` (eixo dominante; `Vector2i.ZERO` abaixo do limiar)
  - `InputGlyphs.label(action: StringName, device: int) -> String`; `""` = sem equivalente (dica escondida). Ações: `confirm, back, end_turn, examine, tabs, los, log, pause, zoom, camera, navigate, cursor, filter, toggle`.

- [ ] **Step 1: Testes que falham** (todos em `_test_gamepad_support`): inicia em `KEYBOARD_MOUSE`; `note_joy_button(3)` → `GAMEPAD`, `gamepad_id == 3`, retorna `true`, segunda chamada retorna `false`; `note_key()` volta a teclado; `note_mouse_motion(Vector2(0.1,0))` não troca; `note_mouse_motion(Vector2(4,0))` troca; `note_joy_axis(0, 0.3)` não troca (drift), `note_joy_axis(0, 0.7)` troca; dois controles: o último a ser usado vira `gamepad_id`; `note_joy_disconnected(gamepad_id)` → teclado e `gamepad_id == -1`; desconectar outro id não muda nada; `apply_deadzone(Vector2(0.2,0.2))` = zero e `apply_deadzone(Vector2(1,0)).length()` ≈ 1; `stick_dir4(Vector2(0.9,0.4)) == Vector2i(1,0)`, `stick_dir4(Vector2(0,-0.8)) == Vector2i(0,-1)`, `stick_dir4(Vector2(0.3,0.3)) == Vector2i.ZERO`; `label(&"confirm", GAMEPAD) == "A"`, teclado `"Enter"`; `label(&"back", …)` `"B"`/`"Esc"`; `label(&"end_turn", KEYBOARD_MOUSE) == ""`; `label(&"examine", KEYBOARD_MOUSE) == "Tab"`, gamepad `"Y"`; `label(&"filter", …)` `"L3"`/`"F"`; ação desconhecida → `""`.
- [ ] **Step 2:** `"$GODOT" --headless --script tests/run_tests.gd 2>&1 | grep -E "FAIL|Results|SCRIPT ERROR"` → falha por classes inexistentes.
- [ ] **Step 3:** Implementar as duas classes conforme a Interface.
- [ ] **Step 4:** Rodar a suíte → os novos asserts passam, `0 failed`, sem `SCRIPT ERROR`.

---

### Task 2: Settings com vibração

**Files:**
- Modify: `game_settings.gd`, `ui/options_panel.gd:125-137,322-352,364-369` (toggle "Vibração" como item 2; resolução vira 3, fechar vira 4; ajustar `_focused_opt == 2` → `3`), `tests/run_tests.gd`

**Interfaces:**
- Produces: `GameSettings.PATH` vira `static var PATH := "user://settings.cfg"`; `load_settings()` devolve também `"vibration": bool` (default `true`, seção `"input"`); `save_settings` grava; `static var vibration_enabled: bool = true` atualizado por `apply_settings(settings)`.

- [ ] **Step 1: Testes que falham:** com `GameSettings.PATH = TEST_SAVE_DIR + "/settings_sandbox.cfg"` (restaurado ao fim e arquivo removido em `_clear_save_sandbox`): default sem arquivo → `vibration == true`; `save_settings({"vibration": false})` e `load_settings()["vibration"] == false`; arquivo legado só com `[display]` → `vibration == true`; `apply_settings` com `vibration:false` deixa `GameSettings.vibration_enabled == false`; o caminho real nunca é aberto (asserção igual à de `DungeonState.SAVE_PATH`).
- [ ] **Step 2:** Rodar → falha.
- [ ] **Step 3:** Implementar em `game_settings.gd`; no `options_panel.gd` adicionar `_vibration_btn = _add_toggle(parent, "Vibração", settings.get("vibration", true), func(on: bool): _save_and_apply("vibration", on))` e registrar sua linha em `_option_items` junto das duas existentes (ordem: Tela Cheia, Vsync, Vibração, Resolução, Fechar), atualizando `_activate_focused_opt` e os checks `_focused_opt == 2` para o novo índice da resolução.
- [ ] **Step 4:** Parse-check de `options_panel.gd` (`--check-only`) e suíte → passa.

---

### Task 3: Cursor unificado, validade e exame em `BattleState`

**Files:**
- Modify: `battle/battle_state.gd` (`enter_move_mode` ~1094, `move_cursor_grid` ~1126 [remover], `cycle_attack_target`/`move_attack_tile_cursor`/`set_attack_tile_cursor_clamped` ~2026-2111 [remover], `enter_attack_mode` ~2066, `_enter_downed` ~3256)
- Test: `tests/run_tests.gd` (atualizar blocos 220-270 e 2788-2812 para a navegação nova; novos testes em `_test_gamepad_support`)

**Interfaces:**
- Produces (em `BattleState`):
  - `var cursor_tile: Vector2i = Vector2i(-1, -1)`; `var pending_downed: Array[int] = []`
  - `set_cursor_tile(pos: Vector2i) -> void` (aceita qualquer valor, inclusive fora do grid)
  - `step_cursor(delta: Vector2i) -> void` (se `cursor_tile` fora do grid parte da posição do ativo; clampa em `[0,grid_cols)×[0,grid_rows)`; ignora elevação, terreno e alcance)
  - `get_cursor_feedback() -> Dictionary` `{"valid": bool, "reason": String}`; só em `MOVE_MODE`/`ATTACK_MODE`, senão `{"valid": false, "reason": ""}`. Razões: mover → `"Impossível movimentar até aqui"`; Pulo → `"Pulo impossível"` (via `is_valid_jump_landing`); AoE em ponto → válido se `get_attack_area_tiles().has(pos)`, senão `"Fora de alcance"` (distância `king_dist > current_attack_range`) ou `"Sem linha de visão"` ou `"Alvo inválido"` (obstáculo); alvo único/aliado/self → válido se há criatura viva em `pos` presente em `attack_target_indices`, senão `"Sem alvo"` (nenhuma criatura), `"Fora de alcance"`, `"Sem linha de visão"` ou `"Alvo inválido"` (lado errado, Charmed). Fora do grid → `valid:false, reason:""`.
  - `apply_cursor_selection() -> bool`: se válido, grava a seleção (`move_cursor`; `attack_tile_cursor`; `attack_cursor_idx` = índice da criatura em `attack_target_indices`) e retorna `true`; se inválido não altera nada e retorna `false`
  - `enter_move_mode()` e `enter_attack_mode()` inicializam `cursor_tile` (posição do ativo / primeiro alvo, senão `_initial_attack_tile()`, senão posição do ativo)
  - `living_turn_order() -> Array[int]` (índices de `TURN_QUEUE` em ordem, sem `dead_indices`); `examine_step(current_idx: int, delta: int) -> int` (anda na ordem viva com wrap; `current_idx` morto/inexistente → primeiro vivo; `-1` se não há vivos; `delta == 0` só saneia)
  - `hit_rumble_kind(info: Dictionary) -> StringName`: `&"crit_dealt"`/`&"crit_taken"` se `hit and is_crit and not is_heal` e alvo não-jogador/jogador; senão `&""`
  - `_enter_downed(idx)` anexa `idx` a `pending_downed`

- [ ] **Step 1: Testes que falham** em `_test_gamepad_support` (usar `_battlefield()`): `step_cursor` de `(2,3)` por `(1,0)` vai a `(3,3)` mesmo se o tile `(3,3)` for `ELEVATED` e mesmo se estiver além do alcance de movimento; na borda `(0,0)` + `(-1,0)` permanece `(0,0)`; `cursor_tile = (-1,-1)` + `step_cursor` parte do ativo; `enter_move_mode` põe `cursor_tile == combatant_positions[active_index]`; feedback de mover: tile alcançável `valid`, tile além da velocidade `reason == "Impossível movimentar até aqui"`, fora do grid `reason == ""`; `apply_cursor_selection()` num tile inválido retorna `false`, mantém `move_cursor` e `current_state == MOVE_MODE`; corpo a corpo com alvo adjacente: cursor sobre o goblin `valid` e `apply_cursor_selection` fixa `attack_cursor_idx`; cursor em quadrado vazio `reason == "Sem alvo"` e `has_attacked == false`; cursor sobre inimigo fora do alcance `"Fora de alcance"`; ação em aliado: cursor sobre o aliado `valid`, sobre inimigo `"Alvo inválido"`; self-target: cursor no próprio quadrado `valid`; AoE em ponto: tile no alcance `valid`, fora `"Fora de alcance"`, e confirmar inválido não gasta spell slot (comparar slots antes/depois); Pulo: feedback segue `is_valid_jump_landing`; `examine_step` pula morto (marcar `dead_indices[1] = true`), faz wrap, saneia índice morto e retorna `-1` com todos mortos; `hit_rumble_kind` para crítico em herói → `&"crit_taken"`, crítico em inimigo → `&"crit_dealt"`, acerto normal/cura/erro → `&""`; matar um herói (`_deal_damage_to_combatant(<idx herói>, 999, …)`) preenche `pending_downed`.
- [ ] **Step 2:** Rodar a suíte → novos asserts falham (funções inexistentes).
- [ ] **Step 3:** Implementar as funções acima em `battle_state.gd` reaproveitando `get_reachable_tiles`, `get_attack_area_tiles`, `king_dist`, `_has_los`, `is_valid_jump_landing`, `_combatant_at`, `_initial_attack_tile`. Remover `move_cursor_grid`, `cycle_attack_target`, `move_attack_tile_cursor`, `set_attack_tile_cursor_clamped` (substituídas) e trocar seus usos em `battle_scene.gd` na Task 6.
- [ ] **Step 4:** Reescrever os blocos de teste antigos 220-270 (limite de velocidade, tile ocupado, borda) e 2788-2812 (alcance do cursor de tile, hover válido/inválido) para a regra nova: o cursor passa por esses quadrados e o que é bloqueado agora é a **validade** (`get_cursor_feedback`/`apply_cursor_selection`), nunca o movimento do cursor.
- [ ] **Step 5:** Suíte completa → `0 failed`, sem `SCRIPT ERROR`.

---

### Task 4: Vibração e autoload `InputDevice`

**Files:**
- Create: `input/input_rumble.gd`, `input/input_bindings.gd`, `input/input_device.gd`
- Modify: `project.godot` (autoload `InputDevice="*res://input/input_device.gd"` depois de `SfxManager`)
- Test: `tests/run_tests.gd`

**Interfaces:**
- Produces:
  - `InputRumble`: `const COOLDOWN_MS := 250`; `const CRIT_DEALT := &"crit_dealt"`, `CRIT_TAKEN := &"crit_taken"`, `DOWNED := &"downed"`; `static profile(kind: StringName) -> Dictionary` `{weak, strong, duration, priority}` (dealt: curta 0.10 s, strong 0.7, prio 1; taken: 0.20 s, weak 0.8/strong 0.5, prio 2; downed: 0.45 s, 0.6/1.0, prio 3; desconhecido → `{}`); `static decide(kind, enabled: bool, gamepad_active: bool, now_ms: int, last_ms: int, last_priority: int) -> Dictionary` (`{}` se desligado, sem controle ativo, desconhecido, ou dentro do cooldown sem prioridade estritamente maior; senão o perfil)
  - `InputBindings.register() -> void` (idempotente): actions `act_end_turn` (joy X), `act_examine` (joy Y + `KEY_TAB`), `act_log` (joy Back/View), `act_zoom_cycle` (joy R3), `act_filter` (joy L3 + `KEY_F`)
  - Autoload `InputDevice` (`Node`, sem `class_name`): `var tracker := InputDeviceTracker.new()`; `var active_device: int` (leitura de `tracker.active`); `var stick_drives_cursor: bool` (a cena de combate liga/desliga); `func is_gamepad() -> bool`; `func cursor_axis() -> Vector2` (stick E com deadzone radial; zero se `not is_gamepad()`); `func camera_axis() -> Vector2` (stick D); `func is_los_held() -> bool` (Shift OU LT > 0.5 com controle ativo); `func rumble(kind: StringName) -> void`
  - Comportamento: `_ready` registra bindings, lê `GameSettings.load_settings()` para `vibration_enabled`, conecta `Input.joy_connection_changed`; `_input` classifica evento (ignora `bridged`), troca `Input.mouse_mode` (`HIDDEN` com controle, `VISIBLE` com teclado/mouse), `Input.stop_joy_vibration` ao sair do controle; o botão que acorda o controle é consumido; ponte: A→`KEY_ENTER`, B→`KEY_ESCAPE`, D-pad→setas, LB→`KEY_Q`, RB→`KEY_E`, Start→`KEY_P`, e stick E→setas **só se** `not stick_drives_cursor`, com repetição (0.35 s inicial, 0.12 s) e histerese (solta em 0.3); eventos reais das teclas-ponte são consumidos, X/Y/View/R3/L3 não.

- [ ] **Step 1: Testes que falham:** `decide` desligado → `{}`; sem controle → `{}`; `CRIT_TAKEN` livre → perfil com `duration < 0.5`; mesmo instante `CRIT_DEALT` depois de `DOWNED` (prio 3, dentro do cooldown) → `{}`; `DOWNED` depois de `CRIT_DEALT` dentro do cooldown → perfil; passado o cooldown qualquer um vibra; os três perfis têm `duration` distintas; `profile(&"x") == {}`; `InputBindings.register()` duas vezes não duplica (`InputMap.action_get_events(&"act_examine").size()` igual); `InputMap.has_action(&"act_end_turn")`.
- [ ] **Step 2:** Rodar → falha.
- [ ] **Step 3:** Implementar os quatro arquivos e registrar o autoload; `rumble()` consulta `InputRumble.decide(...)` com `GameSettings.vibration_enabled`, `Time.get_ticks_msec()` e chama `Input.start_joy_vibration(tracker.gamepad_id, weak, strong, duration)`.
- [ ] **Step 4:** Parse-check (`--check-only`) de cada arquivo novo; suíte → passa. Rodar o jogo uma vez (`"$GODOT" --path .`, fechar) e confirmar ausência de erro no console.

---

### Task 5: Câmera, cursor virtual e desenho em `BattleArea`

**Files:**
- Create: `battle/battle_camera.gd`
- Modify: `battle/battle_area.gd` (vars ~53-77, `setup` ~264, `_process` ~284, `_gui_input` ~440, `_draw` ~918-981, `_draw_move_path` ~1106, `_draw_move_cursor`/`_draw_attack_cursor`/`_draw_aoe_splash`)
- Test: `tests/run_tests.gd`

**Interfaces:**
- Produces:
  - `BattleCamera` (`class_name`, só `static`): `edge_pan_velocity(pointer: Vector2, view: Vector2, margin: float, stick: Vector2, speed: float) -> Vector2` (velocidade de `_pan_offset`; só empurra se o ponteiro está dentro de `margin` da borda E o stick aponta para ela; sinal oposto ao do ponteiro); `can_pan(map_rect: Rect2, view: Vector2, dir: Vector2) -> Vector2` (zera o componente que não tem mapa além da borda: direita só se `map_rect.end.x > view.x`, esquerda só se `map_rect.position.x < 0`, idem y); `const ZOOM_LEVELS := [0.75, 1.0, 1.5, 2.0]`; `static next_zoom(current: float) -> float` (próximo nível maior; wrap ao menor)
  - `BattleArea`: `var pointer_pos: Vector2` (local); `func snap_pointer_to_tile(gp: Vector2i) -> void` (move `pointer_pos` ao centro do tile, `_hovered_grid = gp`, rola a câmera o mínimo para o tile ficar visível com margem, chama `_update_hit_preview()` e `queue_redraw()`; **não** emite `tile_hovered`); `func cycle_zoom() -> void`; `func set_examine_highlight(combatant_idx: int) -> void` (-1 limpa; desenha polilinha branca de 3 px no tile do combatente)
  - `_process`: se `InputDevice.is_gamepad()` e `InputDevice.stick_drives_cursor`, move `pointer_pos` por `cursor_axis() * 700 px/s * delta` (clamp ao rect da área), recalcula `gp = _screen_to_grid(pointer_pos)` e, se mudou, atualiza `_hovered_grid`, emite `tile_hovered(gp)`, `_update_hit_preview()`; com `camera_axis()` do stick D rola a câmera (360 px/s, clamp `±MAX_PAN` + `can_pan`); borda via `edge_pan_velocity`; o ponteiro continua sob o stick enquanto a câmera anda (reconverter a cada frame)
  - `_draw`: cursor de MOVE/ATTACK usa `_hovered_grid` (igual a `_state.cursor_tile` nesses modos); quadrado inválido (`get_cursor_feedback().valid == false` e dentro do grid) desenha losango vermelho translúcido e o texto `reason` (se não vazio) junto ao ponteiro (generaliza o desenho atual de "Pulo impossível": posição = `get_local_mouse_position()` com mouse ativo, senão `pointer_pos`); `_draw_aoe_splash`/`_draw_attack_cursor` só quando o cursor é válido; reticle pequeno em `pointer_pos` só com controle ativo e `stick_drives_cursor`
  - `mouse_exited` chama o handler existente (emite `tile_hovered(Vector2i(-1,-1))`) apenas se `InputDevice.is_gamepad()` é falso

- [ ] **Step 1: Testes que falham** (`BattleCamera`): ponteiro no centro com stick forte → `Vector2.ZERO`; ponteiro a 20 px da borda direita com stick `(1,0)` → `velocity.x < 0`; ponteiro na borda direita mas stick `(-1,0)` → 0; `can_pan` com `map_rect` totalmente dentro da tela → `Vector2.ZERO`; mapa que ultrapassa a direita → permite `x` negativo mas não positivo; `next_zoom(1.0) == 1.5`, `next_zoom(2.0) == 0.75`, `next_zoom(0.9)` = 1.0.
- [ ] **Step 2:** Rodar → falha.
- [ ] **Step 3:** Implementar `BattleCamera`; em `BattleArea` adicionar o cursor virtual, borda, zoom e desenhos. Em `_draw_move_path`, trocar o fallback `_state.move_cursor` por `_state.cursor_tile` quando alcançável. Manter intactos o clamp de arrastar com mouse, a roda do mouse e o clique (clique continua emitindo `tile_clicked`).
- [ ] **Step 4:** Parse-check de `battle_area.gd` e suíte → passa.

---

### Task 6: Roteamento de input em `BattleScene` (grid, ações, exame, vibração)

**Files:**
- Modify: `battle/battle_scene.gd` (`_input` 328-361, `_handle_*` 365-461, `_process` 1241, `_on_tile_hovered`/`_on_tile_clicked` 1251-1303, `_after_advance`, `_show_floater_if_needed` 1368, `_process_pending_deaths` 1363, `_refresh_ui` 306, `_on_portrait_right_clicked` 1537, toggle do log 178-184), `battle/ui/turn_order_bar.gd`, `battle/ui/context_menu.gd`, `battle/ui/action_panel.gd`
- Test: `tests/run_tests.gd` (lógica já coberta na Task 3) + smoke da cena (Step 6)

**Interfaces:**
- Consumes: `BattleState.step_cursor/set_cursor_tile/get_cursor_feedback/apply_cursor_selection/examine_step/living_turn_order/hit_rumble_kind/pending_downed`; `BattleArea.snap_pointer_to_tile/cycle_zoom/set_examine_highlight`; `InputDevice.stick_drives_cursor/is_los_held/rumble`; actions `act_*`.
- Produces: `TurnOrderBar.set_examine_highlight(queue_idx: int)` (-1 limpa; reaplicado a cada `refresh`; borda branca de 2 px no slot, via `StyleBoxFlat` num `Panel` filho do slot); `ActionPanel.cycle_filter() -> void` (None → Action → Bonus → slots 1-6 visíveis → Ki → None, reusando `_filter_mode`/`_slot_filter_level`); `ContextMenu.confirm() -> void` (emite `examine_requested` e se libera, mesma ação do botão); `ContextMenu.show_at` continua igual.

- [ ] **Step 1:** `_input`: tratar primeiro eventos de action (`act_end_turn`, `act_examine`, `act_log`, `act_zoom_cycle`, `act_filter`) respeitando os mesmos bloqueios das teclas (`_reaction_pending`, pausa visível, `_animating`, resultado final); depois o fluxo de teclas existente. `act_end_turn` → `_on_end_turn_pressed()`; `act_log` → função extraída `_toggle_log()` (a lambda do botão 💬 passa a chamá-la); `act_zoom_cycle` → `_battle_area.cycle_zoom()`; `act_filter` → `_action_panel.cycle_filter()` (só em `PLAYER_TURN` sem barra de confirmação).
- [ ] **Step 2:** Mover/Mirar: `_handle_move_mode` e `_handle_attack_mode` passam a usar `_state.step_cursor(dir)` + `_after_cursor_moved()` (`_battle_area.snap_pointer_to_tile(_state.cursor_tile)`, `_refresh_ui()`, `_update_attack_outlines()`); Enter → `_confirm_cursor()`; Esc continua `cancel_move`/`cancel_attack`. `_confirm_cursor()`: `if not _state.apply_cursor_selection()` → `feedback = _state.get_cursor_feedback()`, se `reason != ""` mostrar `_battle_area.show_text_floater(_state.cursor_tile, reason, FloaterManager.COLOR_MISS, 16, false)`; retornar sem gastar nada; se válido chamar `_execute_confirm_move()` ou `_execute_confirm_attack()` (o fluxo atual de Pulo/Empurrar/AoE/multi-hit fica intacto). `_on_tile_clicked` em `MOVE_MODE`/`ATTACK_MODE` vira `_state.set_cursor_tile(gp)` + `_confirm_cursor()` (ramo `PLAYER_TURN` de clicar no personagem fica como está). `_on_tile_hovered` em MOVE/ATTACK faz `_state.set_cursor_tile(gp)` e `queue_redraw`. Ao entrar em MOVE/ATTACK com o mouse ativo e o hover dentro do grid, começar o cursor nesse tile (preserva o preview imediato do mouse); caso contrário o padrão do estado + `snap_pointer_to_tile`. `_update_attack_outlines`: `selected` = alvo sob `cursor_tile` se válido, senão `-1`.
- [ ] **Step 3:** `_process`: `want = InputDevice.is_los_held() and …`; também publicar `InputDevice.stick_drives_cursor = (estado MOVE/ATTACK) and not _animating and not _action_panel._action_bar_active and not _pause_menu.visible and not _reaction_pending and _examine_focus == NONE`; limpar em `_exit_tree`.
- [ ] **Step 4:** Exame: `enum ExamineFocus { NONE, BAR, MENU, PANEL }`, `_examine_idx: int`, `_examine_via_bar: bool`. `act_examine`/Tab em `PLAYER_TURN` (sem barra de ação, sem `_animating`) → `BAR` com `_examine_idx = _state.active_index`. Em `BAR`: ←/→/A/D (e D-pad/stick via ponte) → `_examine_idx = _state.examine_step(_examine_idx, ±1)`; Enter → `MENU` (instancia `ContextMenu` ancorado na posição do slot na barra, mesma criação de `_on_portrait_right_clicked`); Esc → `NONE`. Em `MENU`: Enter → `_context_menu.confirm()` (abre o painel → `PANEL`); Esc → fecha o menu e volta a `BAR`. Em `PANEL`: ←/→ → `_examine_idx = _state.examine_step(...)` e `_examine_panel.show_for(_state, _examine_idx)`; Esc → `_examine_panel.hide_panel()` e volta a `BAR` (ou `NONE` se veio do clique direito). Toda mudança chama `_turn_bar.set_examine_highlight(_examine_idx)` e `_battle_area.set_examine_highlight(_examine_idx)` (-1 ao sair). Antes de agir, sanear com `examine_step(_examine_idx, 0)`; `-1` → sair do exame. O clique direito atual continua abrindo o menu; `_on_examine_requested` seta `PANEL`.
- [ ] **Step 5:** Vibração: em `_show_floater_if_needed`, `var kind := _state.hit_rumble_kind(_state.last_attack_info)`; se `kind != &""` e `not last_attack_info.get("rumbled", false)` → `InputDevice.rumble(kind)` e marcar `"rumbled": true`. Em `_refresh_ui`, drenar `_state.pending_downed` chamando `InputDevice.rumble(InputRumble.DOWNED)` por herói (limpar a lista).
- [ ] **Step 6: Verificação:** parse-check de `battle_scene.gd`, `turn_order_bar.gd`, `context_menu.gd`, `action_panel.gd`; suíte completa; smoke da cena: script temporário (scratchpad) que instancia `BattleScene`, aguarda 2 frames, injeta `InputEventKey` (setas/Enter/Esc/Tab) via `Input.parse_input_event` e verifica `_state.current_state`, `cursor_tile`, `_examine_focus` e que `Enter` em quadrado inválido não altera `_state.has_attacked` nem gasta slot.

---

### Task 7: Dicas de botões e telas fora do combate

**Files:**
- Create: `ui/hint_bar.gd`
- Modify: `ui/main_menu.gd`, `ui/party_select.gd:428-434` (substituir o `Label` de dica fixa), `ui/dungeon_map.gd`, `ui/options_panel.gd`, `ui/event_scene.gd:185-203`, `battle/ui/battle_result_screen.gd` (`show_result`), `battle/ui/pause_menu.gd`, `battle/ui/reaction_popup.gd:102-191`, `battle/ui/examine_panel.gd`, `battle/battle_scene.gd` (barra do combate)

**Interfaces:**
- Produces: `HintBar extends HBoxContainer` (`class_name`); `func set_hints(hints: Array) -> void` com `hints = [[&"confirm", "Confirmar"], …]`; no `_process` compara `InputDevice.active_device` com o último desenhado e reconstrói (sem sinais); omite entradas cujo `InputGlyphs.label(...)` é `""`; cada entrada = glifo + rótulo, glifo placeholder desenhado em `_draw` (círculo com letra A verde/B vermelho/X azul/Y amarelo; retângulo arredondado para LB/RB/LT/Start/View/L3/R3/D-pad/"L-stick"; teclas em "keycap" retangular cinza). `mouse_filter = IGNORE`, fonte pequena, alinhada de forma consistente (rodapé central nas telas; canto inferior esquerdo da `BattleArea`, acima da HUD, no combate).

- [ ] **Step 1:** Implementar `HintBar` e usá-la: menu principal/pausa/opções (`navigate`, `confirm`, `back`), seleção de party (substitui o texto fixo: `navigate`, `confirm` Selecionar, `back` Voltar; "F Confirmar" só no teclado via `InputGlyphs` ação `&"toggle"` → `""` no controle), mapa (`navigate`, `confirm` Entrar, `back` Desmarcar), evento e resultado (`confirm`), reação (`confirm` Reagir, `back` Não reagir), exame (`navigate` Combatente, `back` Fechar), combate: conjuntos por estado escolhidos em `BattleScene._refresh_ui` (neutro: `confirm`, `tabs`, `end_turn`, `examine`, `los`, `log`, `pause`, `filter`; mover: `cursor`, `confirm`, `back`, `camera`, `zoom`; mirar: idem; exame: `navigate`, `confirm`, `back`).
- [ ] **Step 2: Foco nas telas só de mouse:** `event_scene.gd`: após criar os botões, `_choice_buttons[0].grab_focus()`; ao mostrar "Continuar", `grab_focus()` nele; `battle_result_screen.gd`: `_action_btn.grab_focus()` em `show_result`. Estilo de foco legível: ao `focus_entered`, `modulate = Color(1.18, 1.12, 0.88)`; `focus_exited` restaura. D-pad/stick/Enter funcionam via ponte + navegação nativa do Godot (`ui_up/ui_down/ui_accept`).
- [ ] **Step 3: Popup de reação:** em `reaction_popup.gd`, com 2+ opções manter `_cursor` (destaque visual igual ao foco acima) sobre `[opção…, Confirmar, Não Reagir]`; setas ↑/↓ movem; Enter alterna a caixa sob o cursor ou aciona o botão; Esc recusa. Com 1 opção o comportamento atual (Enter aceita, Esc recusa) não muda.
- [ ] **Step 4:** `ContextMenu` e `ExaminePanel` não escutam mais teclas quando o exame é conduzido pela `BattleScene` (o roteamento fica lá); manter seus `Esc` atuais como fallback do clique direito.
- [ ] **Step 5:** Parse-check de todos os arquivos tocados e suíte; abrir o jogo (`"$GODOT" --path .`), percorrer menu → party → mapa só com teclado e confirmar dicas trocando para teclas.

---

### Task 8: Documentação e verificação final

**Files:** `CLAUDE.md` (tabela de Autoloads: `InputDevice`, e a nota de que ele e o `class_name`-less), `docs/architecture/input.md` (novo, curto: tracker, ponte, actions, cursor unificado, vibração, como adicionar uma dica), `docs/architecture/battle.md` (trocar a descrição da mira antiga).

- [ ] **Step 1:** Atualizar os três documentos.
- [ ] **Step 2:** `"$GODOT" --headless --script tests/run_tests.gd 2>&1 | grep -E "FAIL|Results|SCRIPT ERROR"` → `0 failed`, nenhuma linha `SCRIPT ERROR`; rodar `"$GODOT" --headless --check-only --script res://<arquivo>` em cada arquivo novo/alterado.
- [ ] **Step 3:** Entregar checklist de teste manual (Xbox e PlayStation) cobrindo os 10 critérios de aceitação, resumo do que mudou, decisões técnicas e pendências. Sem commit.

---

## Self-review (cobertura da spec)

- 3.1 dispositivo/troca/drift/mouse oculto → Tasks 1, 4. Escopo de um jogador e co-op futuro: `gamepad_id` é o controle ativo, mas `note_*` já recebem `device_id`, então associar controle→herói depois não exige refazer o rastreador.
- 3.2 mapa de botões → Task 4 (ponte + actions + LT/stick por polling) e Task 6 (X/Y/View/R3/L3, Start via P, B via Esc).
- 3.3/3.4 navegação, cursor livre, D-pad por quadrado, seleção livre, feedback, mudança da mira, câmera → Tasks 3, 5, 6.
- 3.5 exame → Tasks 3 (`examine_step`), 6 (máquina de estados, borda branca), 7 (dica).
- 3.6 dicas → Task 7. 3.7 vibração + opção → Tasks 2, 3, 4, 6. 3.8 telas → Task 7 (+ filtro da HUD na Task 6, zoom/câmera na Task 5, reação na Task 7).
- Casos extremos (seção 8): desconexão (T1/T4), drift (T1/T5), bordas e fora do grid (T3), bloqueios durante animação/reação/pausa (T6 `_input`), exame com mortos (T3), vibração off/sem suporte (T4: `decide` + `start_joy_vibration` sem controle é no-op), teclas 1–6 intactas (T6 só mexe em mover/mirar), troca de dispositivo no meio de modo (T6: o estado vive em `BattleState`, os dois dispositivos só o escrevem).
- Tipos consistentes: `cursor_tile`, `get_cursor_feedback`, `apply_cursor_selection`, `examine_step`, `hit_rumble_kind`, `InputRumble.*`, `InputDevice.*` e `HintBar.set_hints` aparecem com a mesma assinatura em todas as tasks.

---

## Execução: desvios do plano

- **L3 / filtro de ações da HUD (decisão 4) NÃO foi implementado.** É o único botão fora da tabela aprovada; fica aguardando o veto ou a aprovação do usuário. Consequência: os indicadores clicáveis de Action/Bonus/spell slots/Ki continuam só com mouse. `InputGlyphs` e `InputBindings` não têm `filter`.
- Ação `toggle` virou `start_party` (tecla F da seleção de party; sem equivalente no controle).
- Analógico direito usa o mesmo clamp `MAX_PAN` do arrasto do mouse; só a rolagem por borda do cursor respeita o limite do mapa (`BattleCamera.can_pan`).
- `HintBar` lê o dispositivo ativo por caminho (`/root/InputDevice`) em vez do identificador do autoload, para compilar onde os autoloads ainda não existem (a suíte instancia `ExaminePanel`).
- O aviso de quadrado inválido é um `Label` com `z_index` alto (não `draw_string`), para ficar acima dos sprites.
- `--check-only` isolado não serve para scripts que citam autoloads; usar `check_scripts_compile.gd` (ver `CLAUDE.md`). Novo `class_name` exige `--import` antes de a suíte enxergá-lo.

## Correção posterior: navegação da HUD

A navegação da HUD de combate estava quebrada, não só invisível: o grid de ações substituíra as abas, mas a `BattleScene` seguia dirigindo o modelo oculto `active_tab`/`cursor_position` (removido). Corrigido em `ActionPanel` (`nav_*`, `cycle_filter`), `HudNav` e `FocusGlow`; o L3/filtro ficou desnecessário (LB/RB cicla o filtro). Ver `docs/architecture/input.md`.
