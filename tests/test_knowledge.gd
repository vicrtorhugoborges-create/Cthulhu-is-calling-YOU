extends TestCase
## Conhecimento: faixas do documento de design e efeitos ligados a ele.


func test_tier_boundaries_match_design() -> void:
	# 0–25, 26–50, 51–75, 76–100
	var cases := {0.0: 0, 25.0: 0, 25.9: 0, 26.0: 1, 50.0: 1, 51.0: 2, 75.0: 2, 76.0: 3, 100.0: 3}
	for value in cases:
		check_eq(GameState.tier_for(value), cases[value], "faixa de %.1f:" % value)


func test_knowledge_sources_count_once() -> void:
	GameState.reset()
	check(GameState.add_knowledge(5.0, "doc:x"), "primeira leitura deveria contar")
	check(not GameState.add_knowledge(5.0, "doc:x"), "segunda leitura não deveria contar")
	check_near(GameState.knowledge, 5.0)
	GameState.add_knowledge(3.0)
	GameState.add_knowledge(3.0)
	check_near(GameState.knowledge, 11.0, 0.001, "sem fonte conta sempre:")
	GameState.reset()


func test_knowledge_is_clamped() -> void:
	GameState.reset()
	GameState.set_knowledge(250.0)
	check_near(GameState.knowledge, 100.0)
	GameState.set_knowledge(-10.0)
	check_near(GameState.knowledge, 0.0)
	GameState.reset()


func test_chant_is_inaudible_at_start_and_grows() -> void:
	# "toca desde o prólogo, inaudível no começo e mais nítido conforme o Conhecimento sobe"
	check(AudioDirector_chant(0.0).x <= -79.0, "canto deveria ser inaudível com Conhecimento 0")
	check(AudioDirector_chant(20.0).x <= -79.0, "canto deveria seguir inaudível até 20")
	var last := -1000.0
	for k in range(21, 101, 5):
		var p := AudioDirector_chant(float(k))
		check(p.x >= last, "volume do canto não pode cair (%d)" % k)
		last = p.x
	check(AudioDirector_chant(26.0).x <= -35.0, "26–50: o canto deveria estar no limite da audição")
	check(AudioDirector_chant(100.0).x > AudioDirector_chant(50.0).x + 10.0, "o canto deveria ficar bem mais nítido no fim")


func test_distortion_only_in_last_tier() -> void:
	check_near(CorruptionDirector.distortion_for(75.0), 0.0, 0.0001, "geometria errada antes de 76:")
	check(CorruptionDirector.distortion_for(76.0) > 0.0, "geometria errada deveria começar em 76")
	check(CorruptionDirector.distortion_for(100.0) <= 1.0)


func test_narration_variant_follows_tier() -> void:
	check_eq(NarrationLines.pick("atelie_estatua_mudou", 0), NarrationLines.LINES["atelie_estatua_mudou"]["calm"])
	check_eq(NarrationLines.pick("atelie_estatua_mudou", 2), NarrationLines.LINES["atelie_estatua_mudou"]["uneasy"])
	check_eq(NarrationLines.pick("atelie_estatua_mudou", 3), NarrationLines.LINES["atelie_estatua_mudou"]["shaken"])
	# Sem variante "shaken", cai para a mais próxima abaixo.
	check_eq(NarrationLines.pick("prologo_manuscrito", 3), NarrationLines.LINES["prologo_manuscrito"]["uneasy"])


func test_eyes_cannot_close_when_blocked() -> void:
	GameState.reset()
	GameState.set_eyes_close_allowed(false)
	GameState.set_eyes_closed(true)
	check(not GameState.eyes_closed, "no Julgamento os olhos não fecham")
	GameState.set_eyes_close_allowed(true)
	GameState.set_eyes_closed(true)
	check(GameState.eyes_closed)
	GameState.reset()


func AudioDirector_chant(k: float) -> Vector2:
	return load("res://autoload/audio_director.gd").chant_params(k)
