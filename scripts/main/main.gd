extends Node
## Cena principal. O mundo 3D é renderizado num SubViewport de 320x240
## e ampliado sem suavização; o pós-processo (cor de 15 bits, pontilhado,
## grão, vinheta, olhos fechados, TV de tubo) roda nessa imagem pequena.
## A interface fica por cima, numa CanvasLayer em resolução maior.

const WORLD_SIZE := Vector2i(320, 240)
const EYES_SPEED := 4.0

@onready var world_container: SubViewportContainer = $WorldContainer
@onready var world_viewport: SubViewport = $WorldContainer/WorldViewport
@onready var level_root: Node3D = $WorldContainer/WorldViewport/LevelRoot
@onready var ui: UIRoot = $UI
@onready var fade_rect: ColorRect = $Fade/FadeRect

var _post: ShaderMaterial
var _eyes := 0.0
var _loading := false
var _level: Node
var _player: Player


func _ready() -> void:
	Game.register_main(self)
	_post = world_container.material as ShaderMaterial
	Settings.changed.connect(_apply_settings)
	_apply_settings()
	ui.title_new_game.connect(func() -> void: Game.new_game())
	ui.title_continue.connect(func() -> void: Game.continue_game())
	ui.title_chapter.connect(_start_chapter)
	ui.pause_to_title.connect(func() -> void: Game.return_to_title())
	fade_rect.color.a = 1.0
	if Game.pending_level != "":
		var path := Game.pending_level
		Game.pending_level = ""
		ui.hide_title()
		await load_level(path, Game.pending_spawn, 0.5)
	else:
		_boot()


func _boot() -> void:
	ui.cover_black()
	fade_rect.color.a = 0.0
	await ui.show_card("Este jogo tem cenas de terror, sons altos e imagens distorcidas.\nNão há flashes rápidos.", 3.0, 0.8)
	await return_to_title()


func _apply_settings() -> void:
	if _post:
		_post.set_shader_parameter(&"crt_enabled", Settings.crt_filter)


# --- Entrada -----------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if is_instance_valid(_player) and not get_tree().paused:
			_player.add_look_input(event.relative)
	if OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		_debug_key(event.physical_keycode)


func _debug_key(key: Key) -> void:
	match key:
		KEY_F1:
			GameState.set_knowledge(GameState.knowledge + 10.0)
		KEY_F2:
			GameState.set_knowledge(GameState.knowledge - 10.0)
		KEY_F3:
			ui.toggle_debug()
		KEY_F5:
			if not _loading and Game.current_level_path != "":
				load_level(Game.current_level_path, Game.current_spawn, 0.5)
		KEY_F8:
			if not _loading:
				_start_chapter("rlyeh", "plateau")


# --- Quadro a quadro ---------------------------------------------------------

func _process(delta: float) -> void:
	var target := 1.0 if GameState.eyes_closed else 0.0
	_eyes = move_toward(_eyes, target, EYES_SPEED * delta)
	_post.set_shader_parameter(&"eyes_closed", _eyes)
	if is_instance_valid(_player):
		ui.set_crosshair_focus(_player.focus != null)
		ui.set_gameplay_visible(_player.state == Player.State.NORMAL and _player.control == Player.ControlMode.FULL and not _loading and not GameState.eyes_closed)


# --- Níveis ------------------------------------------------------------------

func load_level(path: String, spawn := "", fade := 1.0) -> void:
	if _loading:
		return
	_loading = true
	if fade > 0.0 and fade_rect.color.a < 1.0:
		await fade_screen(1.0, fade)
	fade_rect.color.a = 1.0
	Narration.clear()
	get_tree().paused = false
	GameState.set_eyes_closed(false)
	_post.set_shader_parameter(&"world_fade", 0.0)
	if is_instance_valid(_level):
		_level.queue_free()
		await get_tree().process_frame
	_player = null
	Game.player = null

	var packed := load(path) as PackedScene
	if packed == null:
		push_error("Nível não encontrado: %s" % path)
		_loading = false
		return
	_level = packed.instantiate()
	if _level is Level:
		(_level as Level).hosted = true
	level_root.add_child(_level)

	_player = (load(Game.PLAYER_SCENE) as PackedScene).instantiate() as Player
	var marker := _find_spawn(_level, spawn)
	if marker:
		_player.transform = Transform3D(Basis(Vector3.UP, marker.global_rotation.y), marker.global_position)
		spawn = marker.name
	_level.add_child(_player)
	Game.on_level_loaded(_level, _player, path, spawn)
	if _level is Level:
		(_level as Level).on_player_spawned(_player, spawn)
	ui.hide_title()
	await ui.hide_card(0.01)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	Game.show_hint("move")
	_loading = false
	await fade_screen(0.0, maxf(fade, 0.3))


func _find_spawn(level: Node, spawn: String) -> Node3D:
	var markers := get_tree().get_nodes_in_group(&"spawn").filter(func(n: Node) -> bool: return level.is_ancestor_of(n))
	if markers.is_empty():
		return null
	for m in markers:
		if m.name == spawn:
			return m
	return markers[0]


func unload_level() -> void:
	if is_instance_valid(_level):
		_level.queue_free()
	_level = null
	_player = null
	Game.player = null
	Game.level = null


# --- Fluxo -------------------------------------------------------------------

func start_new_game() -> void:
	ui.hide_title()
	ui.cover_black()
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	await get_tree().create_timer(1.0).timeout
	# Tela preta, primeira fala, depois o quarto de Thurston.
	Narration.say("abertura")
	await Narration.queue_emptied
	await get_tree().create_timer(1.0).timeout
	await load_level(Game.resolve_level("prologo"), "", 0.0)


func _start_chapter(level_id: String, spawn: String) -> void:
	GameState.reset()
	ui.hide_title()
	await load_level(Game.resolve_level(level_id), spawn, 0.8)


func return_to_title() -> void:
	await fade_screen(1.0, 0.8)
	unload_level()
	Narration.clear()
	Audio.restore()
	Audio.stop_all_ambience(0.5)
	Audio.stop_music(0.5)
	Audio.stop_chant()
	Audio.set_heartbeat(0.0)
	Audio.set_drips(false)
	Audio.play_ambience("base", "amb_rain_loop", -14.0, 2.0)
	GameState.set_eyes_close_allowed(true)
	_post.set_shader_parameter(&"world_fade", 0.0)
	await ui.hide_card(0.01)
	ui.show_title()
	await fade_screen(0.0, 1.0)


# --- Escurecimentos ----------------------------------------------------------

func fade_screen(target: float, time: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade_rect, "color:a", target, maxf(time, 0.01))
	await tw.finished


func fade_world(target: float, time: float) -> void:
	var from: float = _post.get_shader_parameter(&"world_fade")
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _post.set_shader_parameter(&"world_fade", v), from, target, maxf(time, 0.01))
	await tw.finished
