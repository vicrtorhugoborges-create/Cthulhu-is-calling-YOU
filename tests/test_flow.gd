extends TestCase
## Integração: joga o roteiro da fatia vertical e o Julgamento chamando
## as mesmas funções que o jogador aciona (interagir, examinar, ler, andar, olhar).

var main: Node


func _start(level_id: String, spawn := "") -> void:
	GameState.reset()
	Game.pending_level = Game.LEVELS[level_id]
	Game.pending_spawn = spawn
	main = (load(Game.MAIN_SCENE) as PackedScene).instantiate()
	add_child(main)
	await _until(func() -> bool: return is_instance_valid(Game.player) and Game.level != null, 5.0)
	Game.pending_spawn = ""


func _finish() -> void:
	Engine.time_scale = 1.0
	Audio.restore()
	Narration.clear()
	if is_instance_valid(main):
		main.queue_free()
	await get_tree().process_frame
	Game.main = null
	Game.player = null
	Game.level = null
	GameState.reset()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


## Espera uma condição (tempo em segundos de jogo, respeitando time_scale).
func _until(cond: Callable, timeout: float) -> bool:
	var left := timeout
	while not cond.call():
		await get_tree().process_frame
		left -= get_process_delta_time()
		if left <= 0.0:
			return false
	return true


func _face(point: Vector3) -> void:
	var a := Game.player.look_angles_to(point)
	Game.player.set_view(a.x, a.y)


func test_prologue_to_end_of_vertical_slice() -> void:
	await _start("prologo")
	var lvl := Game.level
	var player := Game.player
	check(lvl.level_id == "prologo", "deveria começar no prólogo")

	# A caixa não abre sem a chave.
	var box := lvl.get_node("Interactables/LockedBox") as UseTarget
	box.interact(player)
	check(not GameState.has_flag("box_open"), "a caixa abriu sem a chave")

	# Pega o chaveiro do tio.
	var keys := lvl.get_node("Interactables/Keys") as ExaminableItem
	keys.interact(player)
	check_eq(player.state, Player.State.EXAMINE, "examinar as chaves:")
	await _wait(0.4)
	player.end_examine()
	check(GameState.has_flag("has_angell_keys"), "as chaves deveriam virar flag")
	check(GameState.has_diary_entry("d_chaves"), "o diário deveria anotar as chaves")

	# Abre a caixa.
	box.interact(player)
	check(GameState.has_flag("box_open"), "a caixa deveria abrir com a chave")

	# Examina o baixo-relevo e gira até achar o verso.
	var relief := lvl.get_node("Interactables/BasRelief") as ExaminableItem
	check(relief.enabled, "o baixo-relevo deveria estar disponível com a caixa aberta")
	relief.interact(player)
	await _wait(0.5)
	player.add_look_input(Vector2(PI / Player.EXAMINE_ROTATE_SPEED, 0))
	await _wait(0.2)
	check(GameState.has_flag("relief_back_seen"), "girar o baixo-relevo deveria revelar o verso")
	check(GameState.has_diary_entry("d_wilcox_nome"))
	player.end_examine()
	await _wait(0.5)
	check(GameState.has_flag("examined_relief"))

	# Lê o manuscrito "CTHULHU CULT".
	var manuscript := lvl.get_node("Interactables/Manuscript") as ReadableDocument
	manuscript.interact(player)
	check(main.ui.document_reader.is_open(), "o documento deveria abrir em tela cheia")
	check_eq(player.state, Player.State.READING)
	await _wait(0.2)
	main.ui.document_reader.close()
	await _wait(0.1)
	check(GameState.has_flag("read_cthulhu_cult"), "a leitura deveria ser registrada")
	check(GameState.knowledge > 5.0, "ler deveria dar Conhecimento")
	check_eq(player.state, Player.State.NORMAL)

	# Vira as costas para a mesa: o baixo-relevo muda de lugar fora da vista.
	player.global_position = lvl.to_global(Vector3(2.0, 0, 1.8))
	player.set_view(PI, 0.0)
	var moved := await _until(func() -> bool: return GameState.has_flag("relief_moved"), 6.0)
	check(moved, "o baixo-relevo deveria mudar de lugar quando ninguém olha")
	var spot_b := lvl.get_node("Markers/ReliefSpotB") as Node3D
	check(relief.global_position.distance_to(spot_b.global_position) < 0.01, "deveria estar no outro lugar da mesa")

	# Olha de novo: silêncio, fala, coração; depois a porta libera.
	_face(relief.global_position)
	Engine.time_scale = 3.0
	var done := await _until(func() -> bool: return GameState.has_flag("prologo_done"), 20.0)
	Engine.time_scale = 1.0
	check(done, "notar o baixo-relevo deveria encerrar o prólogo")
	check(GameState.has_diary_entry("d_relevo_mexeu"))

	# Sai pela porta para Providence.
	var door := lvl.get_node("Interactables/Door") as LevelExit
	door.interact(player)
	var arrived := await _until(func() -> bool: return Game.level != null and Game.level.level_id == "atelie" and is_instance_valid(Game.player), 6.0)
	check(arrived, "a porta deveria levar ao ateliê de Wilcox")
	if not arrived:
		await _finish()
		return
	lvl = Game.level
	player = Game.player

	# Conversa com Wilcox (três blocos de falas).
	var talk := lvl.get_node("Interactables/WilcoxTalk") as Talker
	var piece := lvl.get_node("Interactables/MorbidPiece") as UseTarget
	check(not piece.enabled, "a peça só deveria ficar disponível depois da conversa")
	for i in 3:
		Narration.clear()
		talk.interact(player)
	check(GameState.has_flag("wilcox_talked"), "a conversa deveria terminar em três interações")
	check(piece.enabled, "a peça deveria liberar depois da conversa")

	# A saída ainda está fechada.
	var exit := lvl.get_node("Interactables/ExitDoor") as UseTarget
	exit.interact(player)
	check(Game.level == lvl, "não deveria sair antes da visão")

	# Toca a peça: visão de Wilcox.
	piece.interact(player)
	Engine.time_scale = 3.0
	var in_vision := await _until(func() -> bool: return Game.level != null and Game.level.level_id == "visao_wilcox" and is_instance_valid(Game.player), 15.0)
	check(in_vision, "tocar a peça deveria levar à visão")
	if in_vision:
		check(GameState.knowledge >= 26.0, "a visão deveria passar o Conhecimento da primeira faixa (veio %.0f)" % GameState.knowledge)
		var end_trigger := Game.level.get_node("Triggers/End") as Node3D
		Game.player.global_position = end_trigger.global_position + Vector3(0, -1.9, 0)
		var back := await _until(func() -> bool: return Game.level != null and Game.level.level_id == "atelie" and Game.current_spawn == "after_vision", 10.0)
		check(back, "o fim da passarela deveria cortar de volta ao ateliê")
		check(GameState.has_flag("vision_done"))
		await _until(func() -> bool: return is_instance_valid(Game.player) and Game.player.control == Player.ControlMode.FULL, 10.0)
		var exit2 := Game.level.get_node("Interactables/ExitDoor") as UseTarget
		exit2.interact(Game.player)
		var titled := await _until(func() -> bool: return Game.level == null and main.ui._title_root.visible, 30.0)
		check(titled, "sair do ateliê deveria encerrar a fatia e voltar ao título")
	Engine.time_scale = 1.0
	await _finish()


func test_judgment_plays_to_the_end() -> void:
	await _start("rlyeh", "plateau")
	var lvl := Game.level
	var judgment := lvl.get_node("Judgment") as JudgmentSequence
	var cthulhu := lvl.get_node("Creature/Cthulhu") as MeshInstance3D
	check(not cthulhu.visible, "Cthulhu não pode aparecer antes do Julgamento")
	Game.player.global_position = lvl.to_global(Vector3(0, 4.7, -76))
	var started := await _until(func() -> bool: return judgment.running, 6.0)
	check(started, "entrar no gatilho deveria começar o Julgamento")
	check(not GameState.eyes_close_allowed, "no Julgamento os olhos não fecham")
	Engine.time_scale = 4.0
	await _until(func() -> bool: return judgment.t >= 21.0, 30.0)
	check_eq(Game.player.control, Player.ControlMode.LOOK_ONLY, "aos 20 s o jogador para:")
	await _until(func() -> bool: return judgment.t >= 31.0, 30.0)
	check(cthulhu.visible, "aos 30 s ele já emergiu")
	check(Audio.get_heartbeat_bpm() > 0.0, "o coração bate durante o olhar")
	await _until(func() -> bool: return judgment.t >= 41.0, 30.0)
	check_eq(Audio.get_heartbeat_bpm(), 0.0, "o coração para aos 40 s:")
	await _until(func() -> bool: return judgment.t >= 43.0, 30.0)
	check_eq(Game.player.control, Player.ControlMode.NONE, "aos 42 s não há mais controle:")
	await _until(func() -> bool: return judgment.t >= 51.0, 30.0)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index(&"Master")), "silêncio total aos 50 s")
	var titled := await _until(func() -> bool: return Game.level == null and main.ui._title_root.visible, 60.0)
	check(titled, "depois dos créditos o jogo volta ao título")
	check(not SaveSystem.has_save(), "terminar o jogo apaga o save automático")
	await _finish()
