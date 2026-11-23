# Party Select — Limite de 4 Heróis — Design Spec

## Objetivo

Limitar a party a no máximo 4 heróis. Com 8 heróis disponíveis (6 existentes + Paladino + Monge), o jogador deve escolher quais 4 participam da batalha. O mínimo continua sendo 1.

## Mudanças em `ui/party_select.gd`

### Estado inicial — nenhum herói selecionado por padrão

Atualmente: `_selected[hname] = true` para todos. Mudar para `_selected[hname] = false`. O jogador clica para selecionar até 4.

### Subtítulo

Antes: `"Escolha os heróis que vão combater (mínimo 1)"`
Depois: `"Escolha até 4 heróis (mínimo 1)"`

### Contador — novo label `_counter_lbl`

Adicionar `var _counter_lbl: Label` ao nó (inserido entre o subtítulo e a linha de cards):

```gdscript
_counter_lbl = Label.new()
_counter_lbl.add_theme_font_size_override("font_size", 14)
_counter_lbl.add_theme_color_override("font_color", Color(0.80, 0.80, 0.55))
_counter_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
center.add_child(_counter_lbl)
```

Atualizado em `_update_counter()`:
```gdscript
func _update_counter() -> void:
    var count := _count_selected()
    _counter_lbl.text = "%d / 4 selecionados" % count
    _counter_lbl.add_theme_color_override(
        "font_color",
        Color(0.4, 1.0, 0.5) if count >= 1 else Color(0.8, 0.4, 0.4)
    )
```

### _toggle_hero — enforce max 4 e mínimo 1

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

func _count_selected() -> int:
    var c := 0
    for v in _selected.values():
        if v: c += 1
    return c
```

### Botão "Iniciar Batalha" — habilitado apenas quando >= 1 selecionado

```gdscript
func _update_start_btn() -> void:
    _start_btn.disabled = _count_selected() == 0
```

Chamar `_update_start_btn()` em `_toggle_hero()` e na inicialização (quando count=0, botão começa desativado).

### _on_start — sem mudança de lógica

Passa apenas os nomes selecionados para `BattleState.setup_party()`. A lógica existente já funciona.

## Layout — Cards em scroll caso > 6 heróis

Com 8 heróis, os cards podem não caber horizontalmente. Envolver `cards_row` (HBoxContainer) em um `ScrollContainer` com scroll horizontal:

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

## Testes

Sem testes automatizados — verificação por inspeção de código:
- `_count_selected()` retorna 0 inicialmente
- `_toggle_hero` não seleciona 5º herói quando 4 já estão selecionados
- `_toggle_hero` não deseleciona último herói quando count = 1

## Arquivos

**Modificar:**
- `ui/party_select.gd`

## Fora do Escopo

- Ordem dos heróis na party (todos entram na ordem do TURN_QUEUE)
- Filtragem ou busca de heróis
- Preview de stats ao hover
