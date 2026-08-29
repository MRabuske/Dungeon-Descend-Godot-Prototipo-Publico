# Party Select — Limite de 4 Heróis — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Limitar a party a no máximo 4 heróis e mínimo 1, iniciando com nenhum selecionado, adicionando contador "X/4" e colocando os cards em um ScrollContainer horizontal.

**Architecture:** Todas as mudanças são em `ui/party_select.gd`. Nenhum teste automatizado — verificação por inspeção de código. As mudanças são: estado inicial zerado, subtítulo atualizado, novo label contador, lógica de toggle com max 4 / min 1, botão de início desabilitado quando count=0, e ScrollContainer horizontal nos cards.

**Tech Stack:** GDScript 4.6, Godot 4.6. Sem editor ativo — verificação por inspeção de código.

---

## Arquivos

| Ação | Arquivo |
|---|---|
| Modificar | `ui/party_select.gd` |

---

### Task 1: Estado inicial, subtítulo, contador e lógica de toggle

**Files:**
- Modify: `ui/party_select.gd`

Sem testes automatizados — verificação por inspeção de código.

- [ ] **Step 1: Adicionar `var _counter_lbl: Label` às variáveis de classe**

Leia `ui/party_select.gd`. Na seção de variáveis de classe (linhas 9-11), adicionar `_counter_lbl` após `_cards`:

```gdscript
var _selected: Dictionary = {}
var _cards: Dictionary = {}
var _start_btn: Button
var _counter_lbl: Label
```

- [ ] **Step 2: Atualizar texto do subtítulo**

Encontrar na linha 43:
```gdscript
	sub.text = "Escolha os heróis que vão combater (mínimo 1)"
```

Substituir por:
```gdscript
	sub.text = "Escolha até 4 heróis (mínimo 1)"
```

- [ ] **Step 3: Criar `_counter_lbl` em `_ready()` — entre subtítulo e cards_row**

Após `center.add_child(sub)` (linha 47) e ANTES da criação de `cards_row` (linha 49), inserir:

```gdscript
	_counter_lbl = Label.new()
	_counter_lbl.add_theme_font_size_override("font_size", 14)
	_counter_lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.55))
	_counter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	center.add_child(_counter_lbl)
```

- [ ] **Step 4: Mudar estado inicial — todos começam deselecionados**

No loop de criação de cards (linha 55), mudar `true` para `false`:

```gdscript
	for hname in BattleState.ALL_HERO_DATA.keys():
		_selected[hname] = false
		var card := _make_card(hname)
		_cards[hname] = card
		cards_row.add_child(card)
		_update_card_style(hname)
```

- [ ] **Step 5: Chamar `_update_counter()` e `_update_start_btn()` ao final do `_ready()`**

Após o loop dos cards e antes de criar `buttons_row`, adicionar:

```gdscript
	_update_counter()
	_update_start_btn()
```

O trecho final do `_ready()` antes de `buttons_row` ficará assim:

```gdscript
	for hname in BattleState.ALL_HERO_DATA.keys():
		_selected[hname] = false
		var card := _make_card(hname)
		_cards[hname] = card
		cards_row.add_child(card)
		_update_card_style(hname)

	_update_counter()
	_update_start_btn()

	var buttons_row := HBoxContainer.new()
```

- [ ] **Step 6: Adicionar função `_count_selected() -> int`**

Após `_toggle_hero()` no arquivo, adicionar:

```gdscript
func _count_selected() -> int:
	var c := 0
	for v in _selected.values():
		if v: c += 1
	return c
```

- [ ] **Step 7: Adicionar função `_update_counter()`**

Após `_count_selected()`, adicionar:

```gdscript
func _update_counter() -> void:
	var count := _count_selected()
	_counter_lbl.text = "%d / 4 selecionados" % count
	_counter_lbl.add_theme_color_override(
		"font_color",
		Color(0.4, 1.0, 0.5) if count >= 1 else Color(0.8, 0.4, 0.4)
	)
```

- [ ] **Step 8: Adicionar função `_update_start_btn()`**

Após `_update_counter()`, adicionar:

```gdscript
func _update_start_btn() -> void:
	_start_btn.disabled = _count_selected() == 0
```

- [ ] **Step 9: Refatorar `_toggle_hero()` — max 4, min 1, chamar counter e start_btn**

Substituir a função `_toggle_hero()` atual (linhas 142-153) por:

```gdscript
func _toggle_hero(hname: String) -> void:
	if _selected.get(hname, false):
		if _count_selected() <= 1:
			return   # mínimo 1
		_selected[hname] = false
	else:
		if _count_selected() >= 4:
			return   # máximo 4
		_selected[hname] = true
	_update_card_style(hname)
	_update_counter()
	_update_start_btn()
```

- [ ] **Step 10: Verificar a lógica (inspeção de código)**

- `_selected` inicializa `false` para todos → `_count_selected()` retorna 0 inicialmente ✅
- `_update_start_btn()` → `_start_btn.disabled = true` quando count=0 ✅
- `_toggle_hero` com count=0: `else` branch → verifica `>= 4` (false) → `_selected[hname] = true` ✅
- `_toggle_hero` com count=4: `else` branch → verifica `>= 4` (true) → `return` sem selecionar ✅
- `_toggle_hero` com count=1, tentando desselecionar: `if` branch → verifica `<= 1` (true) → `return` ✅
- `_counter_lbl.text` mostra "0 / 4 selecionados" em vermelho ao iniciar ✅

- [ ] **Step 11: Commit e push**

```
git add ui/party_select.gd
git commit -m "feat: party select limit 4 heroes — counter, toggle constraints, start btn disabled"
git push
```

---

### Task 2: ScrollContainer horizontal para cards_row

**Files:**
- Modify: `ui/party_select.gd`

Sem testes automatizados — verificação por inspeção de código.

- [ ] **Step 1: Identificar onde `cards_row` é criado em `_ready()`**

Leia o arquivo atualizado. Localizar o trecho:

```gdscript
	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 16)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(cards_row)
```

- [ ] **Step 2: Envolver `cards_row` em um `ScrollContainer`**

Substituir o trecho acima por:

```gdscript
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.vertical_scroll_mode   = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.custom_minimum_size    = Vector2(0, 260)
	center.add_child(scroll)

	var cards_row := HBoxContainer.new()
	cards_row.add_theme_constant_override("separation", 16)
	cards_row.alignment = BoxContainer.ALIGNMENT_CENTER
	scroll.add_child(cards_row)
```

**Atenção:** `cards_row` passa de filho de `center` para filho de `scroll`. Os cards continuam sendo adicionados a `cards_row` — o loop de criação de cards permanece sem modificações.

- [ ] **Step 3: Verificar a lógica (inspeção de código)**

- `ScrollContainer` é filho de `center` (VBoxContainer) ✅
- `cards_row` é filho de `scroll` (não de `center`) ✅
- `scroll.horizontal_scroll_mode = SCROLL_MODE_AUTO` → barra horizontal aparece apenas quando necessário ✅
- `scroll.vertical_scroll_mode = SCROLL_MODE_DISABLED` → sem scroll vertical ✅
- `scroll.custom_minimum_size = Vector2(0, 260)` → altura mínima para os cards ✅
- O loop `for hname in BattleState.ALL_HERO_DATA.keys()` ainda adiciona cards a `cards_row` ✅

- [ ] **Step 4: Commit e push**

```
git add ui/party_select.gd
git commit -m "feat: wrap party select cards in horizontal ScrollContainer for 8+ heroes"
git push
```
