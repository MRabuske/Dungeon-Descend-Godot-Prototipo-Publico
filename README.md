# Battle Arena

Jogo de combate tático por turnos em perspectiva isométrica, desenvolvido em Godot 4.

## Requisitos

- [Godot 4.6](https://godotengine.org/download) (versão mínima 4.3)

## Como executar

### Via Godot Editor

1. Abra o Godot Engine
2. Clique em **Import** e selecione a pasta do projeto (`new-game-project/`)
3. Aguarde a importação dos assets
4. Pressione **F5** ou clique no botão **Play** para iniciar

### Via linha de comando

```bash
godot --path "caminho/para/new-game-project"
```

Ou para exportar e rodar diretamente um executável (requer template de exportação instalado):

```bash
godot --path "caminho/para/new-game-project" --export-release "Windows Desktop" BattleArena.exe
```

## Controles

### Navegação de menu
| Tecla | Ação |
|-------|------|
| `↑ / ↓` ou `W / S` | Navegar entre abas de ação |
| `← / →` ou `A / D` | Navegar entre itens da aba |
| `Enter / Espaço` | Confirmar seleção |
| `ESC` | Cancelar ação / Abrir menu de pausa |
| `P` | Abrir / fechar menu de pausa |

### Modo de movimento
| Tecla | Ação |
|-------|------|
| `W / A / S / D` ou setas | Mover cursor |
| `Enter / Espaço` | Confirmar movimento |
| `ESC` | Cancelar |

### Modo de ataque
| Tecla | Ação |
|-------|------|
| `← / →` ou `A / D` | Trocar alvo |
| `Enter / Espaço` | Confirmar ataque |
| `ESC` | Cancelar |

### Câmera
| Input | Ação |
|-------|------|
| Scroll do mouse | Zoom in / out |
| Botão do meio ou direito + arrastar | Mover câmera |
| Clique esquerdo | Selecionar tile / alvo |

## Funcionalidades implementadas

- Combate tático por turnos com fila de iniciativa
- Mapa isométrico gerado proceduralmente com 6 tipos de terreno
- 4 heróis jogáveis (Guerreiro, Mago, Arqueiro, Clérigo)
- 4 tipos de inimigos com IA autônoma
- Sistema de habilidades com ataques normais, magias e cura
- Ataques de área (AoE) com preview visual
- Críticos (15% de chance, dano dobrado)
- Status effects: veneno e atordoamento
- Terrenos especiais: lama, elevado, cobertura, armadilha, obstáculo
- Menu principal, menu de pause e tela de resultado
- Log de combate com histórico colorido
- Câmera com pan e zoom

## Estrutura do projeto

```
new-game-project/
├── battle/
│   ├── battle_scene.gd       # Controlador principal da batalha
│   ├── battle_state.gd       # Estado do jogo e lógica de combate
│   ├── battle_area.gd        # Renderização isométrica e animações
│   ├── action_panel.gd       # Painel de ações do jogador
│   ├── status_panel.gd       # Painel de status do combatente ativo
│   ├── combat_log_panel.gd   # Log de combate
│   ├── context_panel.gd      # Painel de informações contextuais
│   ├── turn_order_bar.gd     # Barra de ordem de turno
│   ├── battle_result_screen.gd # Tela de vitória/derrota
│   ├── pause_menu.gd         # Menu de pause
│   └── map_generator.gd      # Gerador procedural de mapas
├── main_menu.gd              # Menu principal
├── main_menu.tscn
├── battle/battle_scene.tscn
└── project.godot
```
