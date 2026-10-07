extends TestCase
## Salvamento automático: o estado sobrevive à ida e volta pelo disco.


func test_state_roundtrip_through_json() -> void:
	GameState.reset()
	GameState.set_knowledge(33.0)
	GameState.set_flag("box_open")
	GameState.add_knowledge(4.0, "doc:teste")
	GameState.add_diary_entry("d_organizar")
	GameState.add_diary_entry("d_caixa")
	GameState.complete_diary_entry("d_organizar")
	var json := JSON.stringify(GameState.to_dict())
	GameState.reset()
	GameState.from_dict(JSON.parse_string(json))
	check_near(GameState.knowledge, 37.0)
	check(GameState.has_flag("box_open"), "flag perdida")
	check(not GameState.add_knowledge(4.0, "doc:teste"), "fonte de Conhecimento deveria continuar contada")
	check_eq(GameState.diary.size(), 2, "entradas do diário:")
	check(GameState.diary[0]["done"], "entrada concluída deveria continuar riscada")
	check(not GameState.diary[1]["done"])
	GameState.reset()


func test_checkpoint_write_and_read() -> void:
	check(SaveSystem.path != SaveSystem.PATH, "os testes não podem usar o save do jogador")
	GameState.reset()
	GameState.set_flag("teste_save")
	SaveSystem.checkpoint(Game.LEVELS["prologo"], "start", "teste")
	var data := SaveSystem.read_save()
	check(not data.is_empty(), "save não foi lido")
	check_eq(data.get("level", ""), Game.LEVELS["prologo"])
	check_eq(data.get("spawn", ""), "start")
	check(data.get("state", {}).get("flags", {}).get("teste_save", false), "flag não foi salva")
	SaveSystem.clear_save()
	check(not SaveSystem.has_save(), "save deveria ter sido apagado")
	GameState.reset()
