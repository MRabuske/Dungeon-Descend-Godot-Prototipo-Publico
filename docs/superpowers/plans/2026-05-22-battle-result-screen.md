# Battle Result Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformar `BattleResultScreen` em um resumo de batalha roguelike com dois sinais separados (vitória → dungeon map, derrota → main menu) e tabela de heróis por HP final.

**Architecture:** Todas as mudanças estão em dois arquivos: `battle/ui/battle_result_screen.gd` (adiciona sinal `continue_requested`, move botão/separador para `show_result()`, constrói hero rows dinamicamente via `BattleState.PLAYERS`) e `battle/battle_scene.gd` (conecta dois sinais, adiciona handler `_on_continue_requested`). Sem novos arquivos.

**Tech Stack:** GDScript 4.6, Godot 4.6. Sem editor ativo — verificação por inspeção de código.

---

## Arquivos

| Ação | Arquivo |
|---|---|
| Modificar | `battle/ui/battle_result_screen.gd` |
| Modificar | `battle/battle_scene.gd` |

---

### Task 1: Refatorar `battle_result_screen.gd`

**Files:**
- Modify: `battle/ui/battle_result_screen.gd`

Sem testes automatizados — verificação por inspeção de código.

- [ ] **Step 1: Substituir o conteúdo completo de `battle_result_screen.gd`**

Leia o arquivo atual em `battle/ui/battle_result_screen.gd`. Substitua o conteúdo completo por:

```gdscript
class_name BattleResultScreen
extends Control

signal continue_requested
signal restart_requested

const WIN_COLOR  := Color(0.90, 0.78, 0.20)
const LOSE_COLOR := Color(0.78, 0.25, 0.22)
const BG_COLOR   := Color(0.05, 0.06, 0.10)

var _title_lbl: Label
var _stat_lbls: Array = []
var _vbox: VBoxContainer

func _ready() -> void:
	anchor_right  = 1.0
	anchor_bottom = 1.0
	mouse_filter  = Control.MOUSE_FILTER_STOP
	visible       = false

	var overlay := ColorRect.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.color = Color(0.0, 0.0, 0.0, 0.78)
	add_child(overlay)

	var panel := PanelContainer.new()
	panel.anchor_left   = 0.5
	panel.anchor_right  = 0.5
	panel.anchor_top    = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left   = -220
	panel.offset_right  =  220
	panel.offset_top    = -260
	panel.offset_bottom =  260
	var bg := StyleBoxFlat.new()
	bg.bg_color            = BG_COLOR
	bg.border_color        = Color(0.30, 0.30, 0.38)
	bg.border_width_left   = 2
	bg.border_width_right  = 2
	bg.border_width_top    = 2
	bg.border_width_bottom = 2
	bg.corner_radius_top_left     = 8
	bg.corner_radius_top_right    = 8
	bg.corner_radius_bottom_left  = 8
	bg.corner_radius_bottom_right = 8
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   28)
	margin.add_theme_constant_override("margin_right",  28)
	margin.add_theme_constant_override("margin_top",    28)
	margin.add_theme_constant_override("margin_bottom", 28)
	panel.add_child(margin)

	_vbox = VBoxContainer.new()
	_vbox.add_theme_constant_override("separation", 10)
	_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(_vbox)

	_title_lbl = Label.new()
	_title_lbl.add_theme_font_size_override("font_size", 28)
	_title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(_title_lbl)

	var sep := HSeparator.new()
	sep.add_theme_color_override("color", Color(0.22, 0.22, 0.28))
	_vbox.add_child(sep)

	var stat_keys := [
		"Turnos jogados",
		"Dano infligido",
		"Dano recebido",
		"Críticos",
		"Inimigos derrotados",
		"Heróis perdidos",
	]
	for key in stat_keys:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)

		var key_lbl := Label.new()
		key_lbl.text = key
		key_lbl.add_theme_font_size_override("font_size", 11)
		key_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70))
		key_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(key_lbl)

		var val_lbl := Label.new()
		val_lbl.add_theme_font_size_override("font_size", 11)
		val_lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 0.95))
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(val_lbl)
		_stat_lbls.append(val_lbl)

		_vbox.add_child(row)

func show_result(result: String, stats: Dictionary) -> void:
	if result == "win":
		_title_lbl.text = "BATALHA CONCLUÍDA!"
		_title_lbl.add_theme_color_override("font_color", WIN_COLOR)
	else:
		_title_lbl.text = "DERROTA..."
		_title_lbl.add_theme_color_override("font_color", LOSE_COLOR)

	var values := [
		str(stats.get("turns", 0)),
		str(stats.get("player_damage_dealt", 0)),
		str(stats.get("enemy_damage_dealt", 0)),
		str(stats.get("crits", 0)),
		str(stats.get("enemy_deaths", 0)),
		str(stats.get("player_deaths", 0)),
	]
	for i in range(_stat_lbls.size()):
		(_stat_lbls[i] as Label).text = values[i]

	var sep2 := HSeparator.new()
	sep2.add_theme_color_override("color", Color(0.22, 0.22, 0.28))
	_vbox.add_child(sep2)

	var heroes_lbl := Label.new()
	heroes_lbl.text = "Heróis"
	heroes_lbl.add_theme_font_size_override("font_size", 12)
	heroes_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.70))
	heroes_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_vbox.add_child(heroes_lbl)

	for p in BattleState.PLAYERS:
		var alive: bool = p["hp"] > 0

		var hero_row := HBoxContainer.new()
		hero_row.add_theme_constant_override("separation", 0)

		var name_lbl := Label.new()
		name_lbl.text = p["name"]
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", Color(0.90, 0.90, 0.95))
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hero_row.add_child(name_lbl)

		var class_lbl := Label.new()
		class_lbl.text = p["class"]
		class_lbl.add_theme_font_size_override("font_size", 11)
		class_lbl.add_theme_color_override("font_color", Color(0.55, 0.62, 0.80))
		class_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hero_row.add_child(class_lbl)

		var hp_lbl := Label.new()
		hp_lbl.text = "%d / %d" % [p["hp"], p["max_hp"]]
		hp_lbl.add_theme_font_size_override("font_size", 11)
		hp_lbl.add_theme_color_override("font_color",
			Color(0.4, 1.0, 0.5) if alive else Color(0.55, 0.55, 0.60))
		hp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		hero_row.add_child(hp_lbl)

		var status_lbl := Label.new()
		status_lbl.text = "Vivo" if alive else "Morto"
		status_lbl.add_theme_font_size_override("font_size", 11)
		status_lbl.add_theme_color_override("font_color",
			Color(0.4, 1.0, 0.5) if alive else Color(0.75, 0.25, 0.25))
		hero_row.add_child(status_lbl)

		_vbox.add_child(hero_row)

	var sep3 := HSeparator.new()
	sep3.add_theme_color_override("color", Color(0.22, 0.22, 0.28))
	_vbox.add_child(sep3)

	var btn := Button.new()
	btn.text = "Continuar" if result == "win" else "Menu Principal"
	btn.add_theme_font_size_override("font_size", 13)
	btn.custom_minimum_size = Vector2(180, 38)
	var btn_style := StyleBoxFlat.new()
	btn_style.bg_color                   = Color(0.18, 0.30, 0.52)
	btn_style.corner_radius_top_left     = 5
	btn_style.corner_radius_top_right    = 5
	btn_style.corner_radius_bottom_left  = 5
	btn_style.corner_radius_bottom_right = 5
	btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover := btn_style.duplicate() as StyleBoxFlat
	btn_hover.bg_color = Color(0.25, 0.42, 0.68)
	btn.add_theme_stylebox_override("hover", btn_hover)
	btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if result == "win":
		btn.pressed.connect(func() -> void: continue_requested.emit())
	else:
		btn.pressed.connect(func() -> void: restart_requested.emit())
	_vbox.add_child(btn)

	visible = true
```

- [ ] **Step 2: Verificar a lógica (inspeção de código)**

- `signal continue_requested` declarado ✅
- `signal restart_requested` declarado ✅
- `_vbox` armazenado como class var para uso em `show_result()` ✅
- `_ready()` NÃO cria segundo separador nem botão (removidos) ✅
- `show_result()` cria sep2 + "Heróis" label + hero rows + sep3 + btn dinamicamente ✅
- Título WIN: "BATALHA CONCLUÍDA!" (corrige "VITORIA!" original) ✅
- Herói vivo: `p["hp"] > 0` → HP em verde, status "Vivo" em verde ✅
- Herói morto: `p["hp"] <= 0` → HP em cinza, status "Morto" em vermelho ✅
- Botão WIN: texto "Continuar", emite `continue_requested` ✅
- Botão LOSE: texto "Menu Principal", emite `restart_requested` ✅
- Painel expandido: offset_top=-260, offset_bottom=260 ✅
- `BattleState.PLAYERS` contém apenas heróis da party selecionada (populado por `setup_party()`) ✅

- [ ] **Step 3: Commit**

```
git add battle/ui/battle_result_screen.gd
git commit -m "feat: refactor BattleResultScreen — dual signals, hero summary, roguelike flow"
git push
```

---

### Task 2: Atualizar `battle_scene.gd` — dois handlers de sinal

**Files:**
- Modify: `battle/battle_scene.gd`

Sem testes automatizados — verificação por inspeção de código.

- [ ] **Step 1: Adicionar conexão de `continue_requested` em `_ready()`**

Leia `battle/battle_scene.gd`. Localize a linha 63:

```gdscript
	_result_screen.restart_requested.connect(_on_restart_requested)
```

Substitua por:

```gdscript
	_result_screen.continue_requested.connect(_on_continue_requested)
	_result_screen.restart_requested.connect(_on_restart_requested)
```

- [ ] **Step 2: Adicionar `_on_continue_requested()` e atualizar `_on_restart_requested()`**

Localize ao final do arquivo (linha 519):

```gdscript
func _on_restart_requested() -> void:
	BattleState.reset_players()
	SceneTransition.fade_to("res://ui/main_menu.tscn")
```

Substitua por:

```gdscript
func _on_continue_requested() -> void:
	SceneTransition.fade_to("res://ui/dungeon_map.tscn")

func _on_restart_requested() -> void:
	BattleState.reset_players()
	SceneTransition.fade_to("res://ui/main_menu.tscn")
```

**Nota:** `res://ui/dungeon_map.tscn` ainda não existe — será criado no Sub-projeto 2 (Mapa do Dungeon). Por enquanto a navegação ficará inerte se acionada antes dessa cena existir. Isso é intencional.

- [ ] **Step 3: Verificar a lógica (inspeção de código)**

- `_result_screen.continue_requested.connect(_on_continue_requested)` conectado ✅
- `_result_screen.restart_requested.connect(_on_restart_requested)` mantido ✅
- `_on_continue_requested()` navega para `dungeon_map.tscn` (será criado no Sub-projeto 2) ✅
- `_on_restart_requested()` chama `reset_players()` + navega para main menu ✅
- Nenhuma outra chamada a `_on_restart_requested()` no arquivo (buscar: apenas `PauseMenu.menu_requested.connect(_on_restart_requested)` na linha 68 — esse sinal continua correto, pois no pause menu voltar ao menu é sempre derrota/abandono, reset se aplica) ✅

- [ ] **Step 4: Commit e push**

```
git add battle/battle_scene.gd
git commit -m "feat: connect dual result signals in BattleScene — continue vs restart"
git push
```
