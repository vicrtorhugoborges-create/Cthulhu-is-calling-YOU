class_name UIStyle
extends RefCounted
## Fontes e cores da interface. As fontes são do sistema (com alternativas)
## até o projeto ganhar fontes próprias de licença livre, por exemplo
## Special Elite ou Courier Prime (máquina de escrever) e Homemade Apple (à mão).

const TEXT := Color(0.85, 0.82, 0.74)
const TEXT_DIM := Color(0.55, 0.53, 0.48)
const INK := Color(0.16, 0.12, 0.08)
const INK_FADED := Color(0.42, 0.35, 0.27)
const PAPER := Color(0.83, 0.76, 0.6)
const ACCENT := Color(0.55, 0.72, 0.42)
const BLOOD := Color(0.45, 0.06, 0.05)

static var _typewriter: Font
static var _handwriting: Font
static var _serif: Font
static var _theme: Theme


static func typewriter() -> Font:
	if _typewriter == null:
		_typewriter = _system(["Courier Prime", "Special Elite", "Courier New", "Courier", "Liberation Mono", "DejaVu Sans Mono", "monospace"])
	return _typewriter


static func handwriting() -> Font:
	if _handwriting == null:
		_handwriting = _system(["Homemade Apple", "Ink Free", "Segoe Print", "Bradley Hand", "URW Chancery L", "Comic Neue", "cursive"])
	return _handwriting


static func serif() -> Font:
	if _serif == null:
		_serif = _system(["Georgia", "Times New Roman", "Liberation Serif", "DejaVu Serif", "serif"], 700)
	return _serif


static func _system(names: Array, weight := 400) -> SystemFont:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(names)
	f.font_weight = weight
	f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
	f.hinting = TextServer.HINTING_NONE
	return f


static func theme() -> Theme:
	if _theme:
		return _theme
	var t := Theme.new()
	t.default_font = typewriter()
	t.default_font_size = 15
	t.set_color(&"font_color", &"Label", TEXT)
	t.set_color(&"font_color", &"Button", TEXT_DIM)
	t.set_color(&"font_hover_color", &"Button", TEXT)
	t.set_color(&"font_focus_color", &"Button", ACCENT)
	t.set_color(&"font_pressed_color", &"Button", ACCENT)
	t.set_font_size(&"font_size", &"Button", 18)
	var empty := StyleBoxEmpty.new()
	for state in [&"normal", &"hover", &"pressed", &"disabled"]:
		t.set_stylebox(state, &"Button", empty)
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color(0, 0, 0, 0)
	focus.border_color = Color(ACCENT, 0.5)
	focus.border_width_bottom = 1
	t.set_stylebox(&"focus", &"Button", focus)
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.02, 0.02, 0.02, 0.92)
	panel.border_color = Color(TEXT_DIM, 0.4)
	panel.set_border_width_all(1)
	panel.set_content_margin_all(16)
	t.set_stylebox(&"panel", &"PanelContainer", panel)
	_theme = t
	return t


static func paper_box(color := PAPER) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 6
	return sb
