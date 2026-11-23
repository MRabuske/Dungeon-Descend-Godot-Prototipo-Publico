# Dungeon Map — Design Spec

## Context

Jogo RPG tático roguelike baseado em salas. Após vencer uma batalha, o jogador retorna ao mapa do dungeon e escolhe qual sala entrar. Ao perder, volta ao menu principal (run perdida). Este spec cobre o Sub-projeto 2: Mapa do Dungeon.

Visão de longo prazo documentada em `docs/vision/dungeon-run-longa.md`. Esta implementação cobre a **Run Média**: 5 andares normais + 1 boss.

---

## Arquitetura

### Arquivos

| Ação | Arquivo | Responsabilidade |
|---|---|---|
| Criar | `dungeon/dungeon_state.gd` | Grafo, geração, estado da run, save/load |
| Criar | `ui/dungeon_map.gd` | Tela de renderização e interação |
| Criar | `ui/dungeon_map.tscn` | Cena mínima referenciando o script |
| Modificar | `battle/battle_scene.gd` | `_on_continue_requested()` completa a sala antes de navegar |
| Modificar | `ui/main_menu.gd` | Botões "Nova Run" e "Continuar" |

### Acesso Global

`DungeonState` expõe `static var current_run: DungeonState` — padrão consistente com `BattleState`.

---

## Modelo de Dados

```gdscript
class_name DungeonState
extends RefCounted

enum RoomType { BATTLE, ELITE, BOSS, EVENT, MYSTERY }

class RoomNode:
    var id: int
    var floor: int            # 0 = entrada, 1-4 = normais, 5 = boss
    var type: RoomType
    var connections: Array[int]   # ids das salas do próximo andar
    var completed: bool = false
    var position: Vector2    # coordenada normalizada (0.0–1.0) para rendering

static var current_run: DungeonState = null

var nodes: Array[RoomNode] = []
var current_node_id: int = -1   # sala atualmente selecionada/sendo jogada
var run_seed: int = 0
```

---

## Geração do Grafo

**Estrutura da Run Média (6 andares):**

| Andar | Nós | Tipos disponíveis | Distribuição |
|---|---|---|---|
| 0 | 1 | BATTLE | obrigatório (entrada) |
| 1 | 2–3 | BATTLE, MYSTERY | 70% BATTLE, 30% MYSTERY |
| 2 | 2–3 | BATTLE, EVENT, MYSTERY | 50% BATTLE, 20% EVENT, 30% MYSTERY |
| 3 | 2–3 | BATTLE, ELITE, MYSTERY | 40% BATTLE, 30% ELITE, 30% MYSTERY |
| 4 | 2–3 | ELITE, EVENT, MYSTERY | 40% ELITE, 30% EVENT, 30% MYSTERY |
| 5 | 1 | BOSS | obrigatório |

**Regras de conexão:**
- Cada nó do andar N conecta a 1–2 nós do andar N+1
- Todo nó tem ao menos uma entrada (exceto andar 0) e uma saída (exceto andar 5)
- Grafo conexo garantido: todos os nós são alcançáveis a partir do andar 0
- Boss (andar 5) conecta de todos os nós do andar 4

**Posições para rendering:** distribuídas uniformemente no eixo X (normalizado 0.0–1.0) por andar, Y calculado por `floor / (floor_count - 1)`.

---

## Visual e Interação

### Layout da Tela

- Fundo: `Color(0.04, 0.05, 0.09)` — consistente com o restante do jogo
- Título "MAPA DO DUNGEON" no topo em dourado (`Color(0.90, 0.78, 0.20)`)
- Andar 0 (entrada) no topo, Boss na base
- Grafo ocupa área central (~80% da tela)
- Painel lateral direito: informações da sala selecionada + botão "Entrar"
- Botão "Voltar ao Menu" no rodapé

### Nós

Círculos desenhados via `_draw()` com raio 28px:

| Tipo | Cor | Label |
|---|---|---|
| BATTLE | `Color(0.35, 0.45, 0.70)` | ⚔ |
| ELITE | `Color(0.80, 0.50, 0.15)` | ☠ |
| BOSS | `Color(0.80, 0.20, 0.20)` | ☆ |
| EVENT | `Color(0.25, 0.70, 0.40)` | ★ |
| MYSTERY | `Color(0.55, 0.30, 0.75)` | ? |

### Estados Visuais

| Estado | Visual |
|---|---|
| Disponível | borda branca (`Color(0.90, 0.90, 0.90)`), largura 2px, clicável |
| Selecionado | borda dourada (`Color(0.90, 0.78, 0.20)`), largura 3px |
| Completado | alpha 0.4, sem borda, não clicável |
| Bloqueado | cor base sem borda, não clicável |

### Linhas de Conexão

`Line2D` largura 2px, `Color(0.28, 0.28, 0.36)`.

### Interação

1. Clique em sala disponível → sala selecionada, painel lateral mostra tipo + descrição + botão "Entrar"
2. Botão "Entrar" → `DungeonState.current_run.enter_room(id)` → save → `SceneTransition.fade_to("res://battle/battle_scene.tscn")`
3. Botão "Voltar ao Menu" → deleta save → `BattleState.reset_players()` → `SceneTransition.fade_to("res://ui/main_menu.tscn")`

---

## Save / Load

**Arquivo:** `user://dungeon_save.json`

**Formato:**
```json
{
  "run_seed": 12345,
  "current_node_id": 3,
  "nodes": [
    {
      "id": 0, "floor": 0, "type": 0,
      "connections": [1, 2],
      "completed": true,
      "pos_x": 0.5, "pos_y": 0.0
    }
  ]
}
```

**Quando salvar:** após `enter_room()` e após `complete_current_room()`.

**Quando deletar o save:**
- Jogador abandona pelo botão "Voltar ao Menu"
- Boss completado (run finalizada)
- Derrota em batalha (tratado em `battle_scene.gd` — `_on_restart_requested()`)

---

## Integração com Código Existente

### `battle/battle_scene.gd` — `_on_continue_requested()`

```gdscript
func _on_continue_requested() -> void:
    if DungeonState.current_run != null:
        DungeonState.current_run.complete_current_room()
    if ResourceLoader.exists("res://ui/dungeon_map.tscn"):
        SceneTransition.fade_to("res://ui/dungeon_map.tscn")
    else:
        BattleState.reset_players()
        SceneTransition.fade_to("res://ui/main_menu.tscn")
```

### `battle/battle_scene.gd` — `_on_restart_requested()` (derrota)

```gdscript
func _on_restart_requested() -> void:
    if DungeonState.current_run != null:
        DungeonState.current_run.delete_save()
        DungeonState.current_run = null
    BattleState.reset_players()
    SceneTransition.fade_to("res://ui/main_menu.tscn")
```

### `ui/main_menu.gd` — Novos botões

- **"Nova Run":** `DungeonState.current_run = DungeonState.new()` → `generate()` → `save()` → `fade_to("res://ui/party_select.tscn")` (party select antes do dungeon)
- **"Continuar":** visível apenas se `user://dungeon_save.json` existir → carrega save → `fade_to("res://ui/dungeon_map.tscn")`

---

## Fluxo Completo

```
Menu Principal
  ├─ Nova Run → party_select → DungeonState.generate() → dungeon_map.tscn
  └─ Continuar (se save existe) → DungeonState.load() → dungeon_map.tscn

dungeon_map.tscn
  └─ Clica sala disponível → enter_room() → battle_scene.tscn
       ├─ Derrota → delete_save() → reset_players() → main_menu.tscn
       └─ Vitória → complete_current_room() → dungeon_map.tscn
             └─ Boss completado → delete_save() → main_menu.tscn
```

---

## Fora do Escopo

- Animações de transição no mapa
- Conteúdo das salas EVENT e MYSTERY (retornam batalha normal por ora)
- Sistema de XP / progressão entre salas
- Múltiplos saves / perfis de jogador
- Run Longa (ver `docs/vision/dungeon-run-longa.md`)
