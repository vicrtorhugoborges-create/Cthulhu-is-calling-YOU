class_name OptionsMenu
extends PanelContainer
## Opções de conforto e acessibilidade (campo de visão, tremor, balanço,
## filtro de TV, legendas). Tudo é salvo na hora.

signal back_pressed

var _first_focus: Control


func _ready() -> void:
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(440, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override(&"separation", 6)
	add_child(vbox)
	var title := Label.new()
	title.text = "Opções"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 20)
	vbox.add_child(title)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override(&"h_separation", 18)
	vbox.add_child(grid)

	_slider(grid, "Campo de visão", "fov", 60.0, 100.0, 1.0, "%d°")
	_slider(grid, "Sensibilidade do mouse", "mouse_sensitivity", 0.03, 0.4, 0.01, "%.2f")
	_slider(grid, "Tremor dos vértices", "jitter", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider(grid, "Deformação das texturas", "affine", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider(grid, "Balanço da câmera", "head_bob", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_slider(grid, "Volume", "master_volume", 0.0, 1.0, 0.05, "%d%%", 100.0)
	_check(grid, "Inverter eixo vertical", "invert_y")
	_check(grid, "Filtro de TV de tubo", "crt_filter")
	_check(grid, "Legendas", "subtitles")
	_check(grid, "Dicas de controle", "control_hints")
	_check(grid, "Linha final antes dos créditos", "end_line")

	var back := Button.new()
	back.text = "Voltar"
	back.pressed.connect(func() -> void: back_pressed.emit())
	vbox.add_child(back)


func open() -> void:
	visible = true
	if _first_focus:
		_first_focus.grab_focus()


func _label(grid: GridContainer, text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 14)
	grid.add_child(l)
	return l


func _slider(grid: GridContainer, text: String, key: String, min_v: float, max_v: float, step: float, fmt: String, display_scale := 1.0) -> void:
	_label(grid, text)
	var row := HBoxContainer.new()
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = Settings.get(key)
	slider.custom_minimum_size = Vector2(150, 16)
	var value_label := Label.new()
	value_label.custom_minimum_size = Vector2(48, 0)
	value_label.add_theme_font_size_override(&"font_size", 13)
	var update := func(v: float) -> void:
		value_label.text = fmt % (v * display_scale)
	update.call(slider.value)
	slider.value_changed.connect(func(v: float) -> void:
		update.call(v)
		Settings.set_value(key, v))
	row.add_child(slider)
	row.add_child(value_label)
	grid.add_child(row)
	if _first_focus == null:
		_first_focus = slider


func _check(grid: GridContainer, text: String, key: String) -> void:
	_label(grid, text)
	var box := CheckBox.new()
	box.button_pressed = Settings.get(key)
	box.toggled.connect(func(on: bool) -> void: Settings.set_value(key, on))
	grid.add_child(box)
