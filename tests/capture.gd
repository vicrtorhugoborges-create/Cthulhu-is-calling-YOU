extends Node
## Tira capturas de tela dos níveis para revisão visual (precisa de janela, não roda headless).
##
##   godot --path . res://tests/capture.tscn -- --out=C:/pasta/das/capturas [--only=nome]
##
## Cada captura carrega um nível, posiciona a câmera e espera alguns quadros.

var _out := "user://captures"
var _only := ""


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out = arg.substr(6)
		elif arg.begins_with("--only="):
			_only = arg.substr(7)
	DirAccess.make_dir_recursive_absolute(_out)
	SaveSystem.path = "user://capture_autosave.json"
	_start.call_deferred()


func _start() -> void:
	# A cena principal entra ao lado desta, que continua viva para fotografar.
	var main := (load(Game.MAIN_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	await _frames(10)
	await get_tree().create_timer(5.5).timeout
	if _wanted("00"):
		await _shot("00_titulo")
	await _level_shot("01_teste", "teste", "start", 0.0, -5.0)
	await _level_shot("02_prologo_mesa", "prologo", "start", 0.0, -12.0)
	await _level_shot("03_prologo_janela", "prologo", "start", 75.0, -5.0)
	await _level_shot("04_atelie", "atelie", "start", 0.0, -5.0)
	await _level_shot("05_atelie_wilcox", "atelie", "start", -25.0, -8.0)
	await _level_shot("06_visao", "visao_wilcox", "start", 0.0, 4.0)
	await _level_shot("07_rlyeh_barco", "rlyeh", "start", 0.0, 0.0)
	await _level_shot("08_rlyeh_plato", "rlyeh", "plateau", 0.0, 10.0)
	await _ui_shots()
	await _corruption_shot()
	await _judgment_shots()
	Engine.time_scale = 1.0
	get_tree().quit()


func _wanted(name: String) -> bool:
	if _only == "":
		return true
	for prefix in _only.split(","):
		if name.begins_with(prefix):
			return true
	return false


func _level_shot(name: String, level: String, spawn: String, yaw_deg: float, pitch_deg: float, knowledge := 0.0) -> void:
	if not _wanted(name):
		return
	GameState.reset()
	GameState.set_knowledge(knowledge)
	await Game.load_level(level, spawn, 0.0)
	await _frames(5)
	Game.player.set_view(Game.player.get_yaw() + deg_to_rad(yaw_deg), deg_to_rad(pitch_deg))
	await get_tree().create_timer(0.8).timeout
	await _shot(name)


func _ui_shots() -> void:
	if not _wanted("09"):
		return
	GameState.reset()
	await Game.load_level("prologo", "start", 0.0)
	await _frames(5)
	Game.open_document(load("res://data/documents/cthulhu_cult.tres"))
	await get_tree().create_timer(0.5).timeout
	await _shot("09_documento")
	Game.main.ui.document_reader.close()
	GameState.add_diary_entry("d_organizar")
	GameState.add_diary_entry("d_caixa")
	GameState.complete_diary_entry("d_organizar")
	Game.main.ui.toggle_diary()
	await get_tree().create_timer(0.4).timeout
	await _shot("09_diario")
	Game.main.ui.toggle_diary()
	await _frames(3)
	var relief := Game.level.get_node("Interactables/BasRelief") as ExaminableItem
	relief.enabled = true
	Game.player.begin_examine(relief)
	await get_tree().create_timer(0.6).timeout
	await _shot("09_examinar")
	Game.player.end_examine()


func _corruption_shot() -> void:
	if not _wanted("10"):
		return
	GameState.reset()
	GameState.set_knowledge(90.0)
	await Game.load_level("atelie", "start", 0.0)
	await _frames(5)
	Game.player.set_view(Game.player.get_yaw() + deg_to_rad(28.0), deg_to_rad(-4.0))
	await get_tree().create_timer(2.5).timeout
	await _shot("10_conhecimento_90")
	RenderingServer.global_shader_parameter_set(&"corruption_flash", 1.0)
	await _frames(3)
	await _shot("10_tijolo_vira_escama")
	RenderingServer.global_shader_parameter_set(&"corruption_flash", 0.0)
	Input.action_press(&"close_eyes")
	await get_tree().create_timer(0.6).timeout
	await _shot("10_olhos_fechados")
	Input.action_release(&"close_eyes")


func _judgment_shots() -> void:
	if not _wanted("11"):
		return
	GameState.reset()
	await Game.load_level("rlyeh", "plateau", 0.0)
	await _frames(5)
	# Anda até o gatilho para disparar o Julgamento como um jogador faria.
	Game.player.global_position = Vector3(0, 4.7, -74)
	var judgment := Game.level.get_node("Judgment") as JudgmentSequence
	while not judgment.running:
		await _frames(1)
	Engine.time_scale = 3.0
	for mark in [[8.0, "11_julgamento_08s_porta"], [16.0, "11_julgamento_16s_escuridao"], [26.0, "11_julgamento_26s_emerge"], [34.0, "11_julgamento_34s_olhar"], [41.0, "11_julgamento_41s"], [44.5, "11_julgamento_44s_escurece"]]:
		while judgment.t < mark[0]:
			await _frames(1)
		Engine.time_scale = 1.0
		await _shot(mark[1])
		Engine.time_scale = 3.0
	Engine.time_scale = 1.0


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(name + ".png"))
	print("captura: ", name)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
