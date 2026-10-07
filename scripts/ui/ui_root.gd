class_name UIRoot
extends CanvasLayer
## Toda a interface, desenhada acima do mundo 3D em resolução mais alta
## (640x480 base) para que legendas e documentos fiquem legíveis.
## Não há HUD: só o ponto de mira, legendas, dicas discretas, diário e documentos.

signal title_new_game
signal title_continue
signal title_chapter(level_id: String, spawn: String)
signal pause_to_title

var crosshair: Crosshair
var document_reader: DocumentReader
var diary: DiaryView
var options: OptionsMenu

var _subtitle: Label
var _hint: Label
var _hint_tween: Tween
var _subtitle_tween: Tween
var _card_bg: ColorRect
var _card_label: Label
var _title_root: Control
var _title_buttons: VBoxContainer
var _continue_button: Button
var _chapters_root: Control
var _pause_root: Control
var _pause_buttons: VBoxContainer
var _debug: Label
var _options_return := ""
var _menu_open := false
var _menu_closed_frame := -1


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	var root := Control.new()
	root.name = "Root"
	root.theme = UIStyle.theme()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	crosshair = Crosshair.new()
	root.add_child(crosshair)
	crosshair.visible = false

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subtitle.add_theme_font_size_override(&"font_size", 16)
	_subtitle.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_subtitle.add_theme_constant_override(&"outline_size", 5)
	_subtitle.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_subtitle.offset_left = 50
	_subtitle.offset_right = -50
	_subtitle.offset_top = -110
	_subtitle.offset_bottom = -26
	root.add_child(_subtitle)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint.add_theme_font_size_override(&"font_size", 12)
	_hint.add_theme_color_override(&"font_color", Color(UIStyle.TEXT_DIM, 0.9))
	_hint.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override(&"outline_size", 4)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	_hint.offset_top = 14
	_hint.offset_bottom = 34
	_hint.modulate.a = 0.0
	root.add_child(_hint)

	document_reader = DocumentReader.new()
	root.add_child(document_reader)
	diary = DiaryView.new()
	root.add_child(diary)

	_build_pause(root)
	_build_title(root)
	_build_chapters(root)

	options = OptionsMenu.new()
	root.add_child(options)
	options.back_pressed.connect(_close_options)

	_card_bg = ColorRect.new()
	_card_bg.color = Color.BLACK
	_card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_bg.visible = false
	root.add_child(_card_bg)
	_card_label = Label.new()
	_card_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_card_label.add_theme_font_size_override(&"font_size", 17)
	_card_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card_label.offset_left = 70
	_card_label.offset_right = -70
	_card_bg.add_child(_card_label)

	_debug = Label.new()
	_debug.visible = false
	_debug.add_theme_font_size_override(&"font_size", 11)
	_debug.add_theme_color_override(&"font_color", UIStyle.ACCENT)
	_debug.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_debug.add_theme_constant_override(&"outline_size", 3)
	_debug.position = Vector2(8, 8)
	root.add_child(_debug)

	Narration.line_started.connect(_on_line_started)
	Narration.line_finished.connect(_on_line_finished)
	GameState.diary_entry_added.connect(func(_id: String) -> void: Audio.play_ui("ui_diary_write", -8.0))


# --- Legendas e dicas --------------------------------------------------------

func _on_line_started(text: String, speaker: String, _duration: float) -> void:
	if not Settings.subtitles:
		return
	if _subtitle_tween:
		_subtitle_tween.kill()
	if speaker == "":
		_subtitle.text = text
		_subtitle.add_theme_color_override(&"font_color", UIStyle.TEXT)
	elif speaker == "…":
		_subtitle.text = text
		_subtitle.add_theme_color_override(&"font_color", UIStyle.ACCENT)
	else:
		_subtitle.text = "%s: %s" % [speaker.to_upper(), text]
		_subtitle.add_theme_color_override(&"font_color", Color(0.78, 0.74, 0.9))
	_subtitle.modulate.a = 1.0


func _on_line_finished() -> void:
	if _subtitle_tween:
		_subtitle_tween.kill()
	_subtitle_tween = create_tween()
	_subtitle_tween.tween_property(_subtitle, "modulate:a", 0.0, 0.3)


func show_hint(hint_id: String) -> void:
	if not Settings.control_hints:
		return
	var flag := "hint:" + hint_id
	if GameState.has_flag(flag):
		return
	var text := Hints.text(hint_id)
	if text == "":
		return
	GameState.set_flag(flag)
	_hint.text = text
	if _hint_tween:
		_hint_tween.kill()
	_hint_tween = create_tween()
	_hint_tween.tween_property(_hint, "modulate:a", 1.0, 0.4)
	_hint_tween.tween_interval(4.0)
	_hint_tween.tween_property(_hint, "modulate:a", 0.0, 1.0)


func set_crosshair_focus(focused: bool) -> void:
	crosshair.focused = focused


func set_gameplay_visible(on: bool) -> void:
	crosshair.visible = on


# --- Cartões de texto sobre tela preta ---------------------------------------

func show_card(text: String, hold := 4.0, fade := 1.0) -> void:
	_card_label.text = text
	_card_label.modulate.a = 0.0
	_card_bg.visible = true
	_card_bg.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_card_label, "modulate:a", 1.0, fade)
	tw.tween_interval(hold)
	tw.tween_property(_card_label, "modulate:a", 0.0, fade)
	await tw.finished


func hide_card(fade := 1.0) -> void:
	if not _card_bg.visible:
		return
	var tw := create_tween()
	tw.tween_property(_card_bg, "modulate:a", 0.0, fade)
	await tw.finished
	_card_bg.visible = false


func cover_black() -> void:
	_card_label.text = ""
	_card_bg.modulate.a = 1.0
	_card_bg.visible = true


# --- Documentos e diário -----------------------------------------------------

func open_document(doc: DocumentData, on_closed := Callable()) -> void:
	if diary.is_open():
		diary.close()
	document_reader.open(doc, on_closed)


func is_reading() -> bool:
	return document_reader.is_open() or diary.is_open()


func toggle_diary() -> void:
	var player := Game.player
	if diary.is_open():
		diary.close()
		if is_instance_valid(player):
			player.set_state(Player.State.NORMAL)
	elif is_instance_valid(player) and player.state == Player.State.NORMAL:
		player.set_state(Player.State.READING)
		diary.open()


func _process(_delta: float) -> void:
	if _debug.visible:
		_update_debug()
	if _menu_open or _card_bg.visible or document_reader.is_open():
		return
	if Engine.get_process_frames() <= _menu_closed_frame + 1:
		return
	var player := Game.player
	if not is_instance_valid(player):
		return
	if Engine.get_process_frames() <= player.last_state_change_frame + 1:
		return
	if Input.is_action_just_pressed(&"diary") and player.control == Player.ControlMode.FULL:
		toggle_diary()
	elif Input.is_action_just_pressed(&"pause"):
		if diary.is_open():
			toggle_diary()
		elif player.state != Player.State.EXAMINE:
			open_pause()


# --- Título ------------------------------------------------------------------

func _build_title(root: Control) -> void:
	_title_root = ColorRect.new()
	(_title_root as ColorRect).color = Color.BLACK
	_title_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_title_root.visible = false
	root.add_child(_title_root)
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override(&"separation", 26)
	_title_root.add_child(vbox)
	var logo := LogoLabel.new()
	logo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(logo)
	_title_buttons = VBoxContainer.new()
	_title_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_title_buttons.add_theme_constant_override(&"separation", 4)
	vbox.add_child(_title_buttons)
	_continue_button = _button(_title_buttons, "Continuar", func() -> void: title_continue.emit())
	_button(_title_buttons, "Novo jogo", func() -> void: title_new_game.emit())
	_button(_title_buttons, "Opções", func() -> void: _open_options("title"))
	if OS.is_debug_build():
		_button(_title_buttons, "Capítulos (desenvolvimento)", _open_chapters)
	_button(_title_buttons, "Sair", func() -> void: get_tree().quit())
	var foot := Label.new()
	foot.text = "baseado em \"The Call of Cthulhu\" (1928), de H. P. Lovecraft"
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.add_theme_font_size_override(&"font_size", 11)
	foot.add_theme_color_override(&"font_color", UIStyle.TEXT_DIM)
	vbox.add_child(foot)


func show_title() -> void:
	_menu_open = true
	_title_root.visible = true
	_continue_button.visible = SaveSystem.has_save()
	crosshair.visible = false
	_subtitle.text = ""
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_focus_first(_title_buttons)


func hide_title() -> void:
	_title_root.visible = false
	_chapters_root.visible = false
	options.visible = false
	_menu_open = false


func _build_chapters(root: Control) -> void:
	_chapters_root = PanelContainer.new()
	_chapters_root.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_chapters_root.visible = false
	root.add_child(_chapters_root)
	var vbox := VBoxContainer.new()
	_chapters_root.add_child(vbox)
	var title := Label.new()
	title.text = "Capítulos (desenvolvimento)"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	for entry in Game.DEV_CHAPTERS:
		var level_id: String = entry[1]
		var spawn: String = entry[2]
		_button(vbox, entry[0], func() -> void: title_chapter.emit(level_id, spawn))
	_button(vbox, "Voltar", func() -> void:
		_chapters_root.visible = false
		_title_buttons.get_parent().visible = true
		_focus_first(_title_buttons))


func _open_chapters() -> void:
	_title_buttons.get_parent().visible = false
	_chapters_root.visible = true
	_focus_first(_chapters_root.get_child(0))


# --- Pausa e opções ----------------------------------------------------------

func _build_pause(root: Control) -> void:
	_pause_root = ColorRect.new()
	(_pause_root as ColorRect).color = Color(0, 0, 0, 0.75)
	_pause_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_root.visible = false
	root.add_child(_pause_root)
	_pause_buttons = VBoxContainer.new()
	_pause_buttons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_pause_root.add_child(_pause_buttons)
	_button(_pause_buttons, "Continuar", close_pause)
	_button(_pause_buttons, "Opções", func() -> void: _open_options("pause"))
	_button(_pause_buttons, "Voltar ao título", func() -> void:
		close_pause()
		pause_to_title.emit())
	_button(_pause_buttons, "Sair do jogo", func() -> void: get_tree().quit())


func open_pause() -> void:
	_menu_open = true
	get_tree().paused = true
	_pause_root.visible = true
	Audio.set_muffled(true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_focus_first(_pause_buttons)


func close_pause() -> void:
	_pause_root.visible = false
	options.visible = false
	get_tree().paused = false
	_menu_open = false
	_menu_closed_frame = Engine.get_process_frames()
	Audio.set_muffled(GameState.eyes_closed)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _open_options(from: String) -> void:
	_options_return = from
	if from == "title":
		_title_buttons.get_parent().visible = false
	else:
		_pause_buttons.visible = false
	options.open()


func _close_options() -> void:
	options.visible = false
	if _options_return == "title":
		_title_buttons.get_parent().visible = true
		_focus_first(_title_buttons)
	else:
		_pause_buttons.visible = true
		_focus_first(_pause_buttons)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"back") and options.visible:
		_close_options()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"pause") and _pause_root.visible and not options.visible:
		close_pause()
		get_viewport().set_input_as_handled()


func _button(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	b.focus_entered.connect(func() -> void: Audio.play_ui("ui_page", -16.0))
	parent.add_child(b)
	return b


func _focus_first(container: Node) -> void:
	for child in container.get_children():
		if child is Button and child.visible:
			(child as Button).grab_focus.call_deferred()
			return


# --- Depuração ---------------------------------------------------------------

func toggle_debug() -> void:
	_debug.visible = not _debug.visible


func _update_debug() -> void:
	var player := Game.player
	var lines := [
		"Conhecimento %.0f (faixa %d)" % [GameState.knowledge, GameState.get_tier()],
		"olhos %s%s" % ["fechados" if GameState.eyes_closed else "abertos", "" if GameState.eyes_close_allowed else " (bloqueado)"],
		"nível %s" % Game.current_level_path.get_file(),
		"%d fps" % Engine.get_frames_per_second(),
	]
	if is_instance_valid(player):
		lines.append("estamina %.1f%s" % [player.stamina, " ofegante" if player.exhausted else ""])
	_debug.text = "\n".join(lines)
