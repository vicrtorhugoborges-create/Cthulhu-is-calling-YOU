class_name DocumentReader
extends Control
## Documento em tela cheia: papel amarelado, fonte de máquina de escrever
## (ou letra à mão, ou jornal). O mundo continua rodando enquanto se lê.

signal closed

const PAPER_TEXTURE := "res://assets/textures/draft/paper_aged.png"

var _doc: DocumentData
var _page := 0
var _on_closed := Callable()
var _paper: PanelContainer
var _title: Label
var _body: RichTextLabel
var _footer: Label


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.78)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	_paper = PanelContainer.new()
	_paper.custom_minimum_size = Vector2(440, 420)
	_paper.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_paper.add_theme_stylebox_override(&"panel", _paper_style())
	center.add_child(_paper)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 10)
	_paper.add_child(vbox)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.add_theme_color_override(&"font_color", UIStyle.INK)
	vbox.add_child(_title)

	_body = RichTextLabel.new()
	_body.bbcode_enabled = true
	_body.fit_content = false
	_body.scroll_active = false
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_theme_color_override(&"default_color", UIStyle.INK)
	vbox.add_child(_body)

	_footer = Label.new()
	_footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_footer.add_theme_color_override(&"font_color", UIStyle.INK_FADED)
	_footer.add_theme_font_size_override(&"font_size", 12)
	vbox.add_child(_footer)


func _paper_style() -> StyleBox:
	if ResourceLoader.exists(PAPER_TEXTURE):
		var sb := StyleBoxTexture.new()
		sb.texture = load(PAPER_TEXTURE)
		sb.set_content_margin_all(30)
		return sb
	return UIStyle.paper_box()


func is_open() -> bool:
	return visible


func open(doc: DocumentData, on_closed := Callable()) -> void:
	_doc = doc
	_page = 0
	_on_closed = on_closed
	var body_font: Font = UIStyle.typewriter()
	var title_font: Font = UIStyle.typewriter()
	var body_size := 15
	match doc.kind:
		DocumentData.Kind.HANDWRITTEN:
			body_font = UIStyle.handwriting()
			title_font = UIStyle.handwriting()
			body_size = 16
		DocumentData.Kind.NEWSPAPER:
			title_font = UIStyle.serif()
			body_size = 14
		DocumentData.Kind.TELEGRAM:
			body_size = 15
	_body.add_theme_font_override(&"normal_font", body_font)
	_body.add_theme_font_size_override(&"normal_font_size", body_size)
	_body.add_theme_font_size_override(&"bold_font_size", body_size)
	_body.add_theme_font_size_override(&"italics_font_size", body_size)
	_title.add_theme_font_override(&"font", title_font)
	_title.add_theme_font_size_override(&"font_size", 20 if doc.kind == DocumentData.Kind.NEWSPAPER else 17)
	_title.text = doc.title
	_show_page()
	visible = true
	Game.show_hint("document")


func _show_page() -> void:
	var pages := _doc.pages
	var text := pages[_page] if _page < pages.size() else ""
	if _doc.kind == DocumentData.Kind.TELEGRAM:
		text = text.to_upper()
	_body.text = text
	_footer.text = "%d / %d" % [_page + 1, maxi(pages.size(), 1)] if pages.size() > 1 else ""


func _process(_delta: float) -> void:
	if not visible:
		return
	if Input.is_action_just_pressed(&"back"):
		close()
	elif Input.is_action_just_pressed(&"page_next"):
		_turn(1)
	elif Input.is_action_just_pressed(&"page_prev"):
		_turn(-1)
	elif Input.is_action_just_pressed(&"interact"):
		if _page < _doc.pages.size() - 1:
			_turn(1)
		else:
			close()


func _input(event: InputEvent) -> void:
	if visible and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_turn(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_turn(-1)


func _turn(direction: int) -> void:
	var new_page := clampi(_page + direction, 0, maxi(_doc.pages.size() - 1, 0))
	if new_page != _page:
		_page = new_page
		Audio.play_ui("ui_page")
		_show_page()


func close() -> void:
	if not visible:
		return
	visible = false
	Audio.play_sfx("sfx_paper", -10.0)
	var cb := _on_closed
	_on_closed = Callable()
	closed.emit()
	if cb.is_valid():
		cb.call()
