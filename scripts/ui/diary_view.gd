class_name DiaryView
extends Control
## Diário de Thurston: resumo das pistas (anotações à mão, riscadas quando
## resolvidas) e o estado mental dele, que piora com o Conhecimento.

const PAPER_TEXTURE := "res://assets/textures/draft/paper_diary.png"

var _text: RichTextLabel
var _mood: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.6)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var paper := PanelContainer.new()
	paper.custom_minimum_size = Vector2(400, 400)
	paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(PAPER_TEXTURE):
		var sb := StyleBoxTexture.new()
		sb.texture = load(PAPER_TEXTURE)
		sb.set_content_margin_all(28)
		paper.add_theme_stylebox_override(&"panel", sb)
	else:
		paper.add_theme_stylebox_override(&"panel", UIStyle.paper_box(Color(0.86, 0.82, 0.7)))
	center.add_child(paper)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 8)
	paper.add_child(vbox)
	var header := Label.new()
	header.text = "Diário — F. W. Thurston"
	header.add_theme_font_override(&"font", UIStyle.handwriting())
	header.add_theme_font_size_override(&"font_size", 19)
	header.add_theme_color_override(&"font_color", UIStyle.INK)
	vbox.add_child(header)
	_mood = Label.new()
	_mood.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mood.add_theme_font_override(&"font", UIStyle.handwriting())
	_mood.add_theme_font_size_override(&"font_size", 14)
	_mood.add_theme_color_override(&"font_color", UIStyle.INK_FADED)
	vbox.add_child(_mood)
	_text = RichTextLabel.new()
	_text.bbcode_enabled = true
	_text.scroll_active = true
	_text.scroll_following = true
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.add_theme_font_override(&"normal_font", UIStyle.handwriting())
	_text.add_theme_font_size_override(&"normal_font_size", 15)
	_text.add_theme_color_override(&"default_color", UIStyle.INK)
	vbox.add_child(_text)
	GameState.diary_changed.connect(_refresh)


func is_open() -> bool:
	return visible


func open() -> void:
	_refresh()
	visible = true
	Audio.play_ui("ui_page")


func close() -> void:
	visible = false
	Audio.play_ui("ui_page", -10.0)


func _refresh() -> void:
	if _mood == null:
		return
	_mood.text = DiaryEntries.mood(GameState.get_tier())
	var lines: PackedStringArray = []
	if GameState.diary.is_empty():
		lines.append("[color=#6b5a45](nada ainda)[/color]")
	for entry in GameState.diary:
		var t: String = entry["text"]
		if entry["done"]:
			lines.append("[color=#6b5a45][s]%s[/s][/color]" % t)
		else:
			lines.append("— %s" % t)
	_text.text = "\n\n".join(lines)
