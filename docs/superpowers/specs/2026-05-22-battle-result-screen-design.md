# Battle Result Screen — Design Spec

## Context

O jogo é um RPG tático roguelike baseado em salas. Cada batalha é uma sala do dungeon. Ao vencer, o jogador avança para o mapa do dungeon para escolher a próxima sala. Ao perder, volta ao menu principal (game over).

A tela de resultado serve como resumo da batalha encerrada — não é uma tela de vitória final. `BattleResultScreen` já existe em `battle/ui/battle_result_screen.gd` com UI básica e stats. Este design expande e corrige essa tela.

---

## Arquitetura

### Sinais

`BattleResultScreen` emite dois sinais separados:

```gdscript
signal continue_requested   # vitória → dungeon map
signal restart_requested    # derrota → main menu
```

`BattleScene` conecta cada sinal ao handler correto:
- `continue_requested` → `SceneTransition.fade_to("res://ui/dungeon_map.tscn")`
- `restart_requested` → `BattleState.reset_players()` + `SceneTransition.fade_to("res://ui/main_menu.tscn")`

### Leitura de dados

`show_result()` lê `BattleState.PLAYERS` diretamente (contém apenas os heróis da party selecionada, populado por `setup_party()`). Nenhuma mudança de assinatura:

```gdscript
func show_result(result: String, stats: Dictionary) -> void
```

---

## Componentes Visuais

### Título

| Resultado | Texto | Cor |
|---|---|---|
| win  | "BATALHA CONCLUÍDA!" | `Color(0.90, 0.78, 0.20)` dourado |
| lose | "DERROTA..."          | `Color(0.78, 0.25, 0.22)` vermelho |

### Seção de estatísticas (existente, mantida)

Seis linhas chave/valor:
- Turnos jogados
- Dano infligido
- Dano recebido
- Críticos
- Inimigos derrotados
- Heróis perdidos

### Seção de heróis (nova)

Separador + cabeçalho "Heróis" + uma linha por herói em `BattleState.PLAYERS`:

```
Nome        Classe      HP Final    Status
Guerreiro   Fighter     45 / 95     Vivo
Ladrao      Rogue        0 / 75     Morto
```

Regras de cor:
- HP text: `Color(0.4, 1.0, 0.5)` se vivo, `Color(0.55, 0.55, 0.60)` se morto
- Status "Vivo": `Color(0.4, 1.0, 0.5)` verde
- Status "Morto": `Color(0.75, 0.25, 0.25)` vermelho escuro

Herói está morto se `p["hp"] <= 0`.

### Botão

| Resultado | Texto | Ação |
|---|---|---|
| win  | "Continuar"      | emite `continue_requested` |
| lose | "Menu Principal" | emite `restart_requested`  |

### Tamanho do painel

Expandido de `offset_top=-185 / offset_bottom=185` para `offset_top=-260 / offset_bottom=260` para acomodar até 4 heróis.

---

## Arquivos

| Ação | Arquivo |
|---|---|
| Modificar | `battle/ui/battle_result_screen.gd` |
| Modificar | `battle/battle_scene.gd` |

---

## Fluxo completo

```
batalha termina
    └─ _check_battle_end() → delay 1.5s → show_result(result, stats)
            ├─ win → título dourado + stats + heróis + botão "Continuar"
            │         └─ clique → continue_requested → dungeon_map.tscn
            └─ lose → título vermelho + stats + heróis + botão "Menu Principal"
                      └─ clique → restart_requested → reset_players() → main_menu.tscn
```

---

## Fora do escopo

- XP / progressão de nível
- Loot / itens dropados
- Animações de entrada
- Música/sfx
- dungeon_map.tscn (Sub-projeto 2)
