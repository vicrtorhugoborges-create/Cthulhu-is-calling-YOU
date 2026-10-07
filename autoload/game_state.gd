extends Node
## Estado da partida: Conhecimento oculto (0–100), flags, diário e olhos fechados.
##
## O Conhecimento não pune o jogador: ele corrompe o mundo ("saber é o perigo").
## Faixas do documento de design: 0–25, 26–50, 51–75, 76–100.

signal knowledge_changed(value: float, tier: int)
signal tier_changed(tier: int)
signal flag_changed(flag: String, value: bool)
signal diary_changed
signal diary_entry_added(id: String)
signal eyes_changed(closed: bool)

const KNOWLEDGE_MAX := 100.0
## Valor mínimo de cada faixa acima da primeira.
const TIER_THRESHOLDS: Array[float] = [26.0, 51.0, 76.0]

var knowledge := 0.0
var flags := {}
## Cada entrada: {"id": String, "text": String, "done": bool}
var diary: Array[Dictionary] = []
## Fontes de Conhecimento já contadas (ler o mesmo documento duas vezes não conta).
var knowledge_sources := {}
var eyes_closed := false
## Falso durante o Julgamento: Thurston não consegue fechar os olhos.
var eyes_close_allowed := true
var chapter := "prologo"


static func tier_for(value: float) -> int:
	var tier := 0
	for threshold in TIER_THRESHOLDS:
		if value >= threshold:
			tier += 1
	return tier


func get_tier() -> int:
	return tier_for(knowledge)


## Soma Conhecimento. Com `source_id`, cada fonte só conta uma vez.
func add_knowledge(amount: float, source_id := "") -> bool:
	if source_id != "":
		if knowledge_sources.has(source_id):
			return false
		knowledge_sources[source_id] = amount
	set_knowledge(knowledge + amount)
	return true


func set_knowledge(value: float) -> void:
	var old_tier := get_tier()
	knowledge = clampf(value, 0.0, KNOWLEDGE_MAX)
	var tier := get_tier()
	knowledge_changed.emit(knowledge, tier)
	if tier != old_tier:
		tier_changed.emit(tier)


## Garante um mínimo (o ato final começa sempre na última faixa).
func ensure_knowledge_at_least(value: float) -> void:
	if knowledge < value:
		set_knowledge(value)


func set_flag(flag: String, value := true) -> void:
	if flags.get(flag, false) == value:
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


func has_flag(flag: String) -> bool:
	return flags.get(flag, false)


func add_diary_entry(id: String, text := "") -> void:
	if text == "":
		text = DiaryEntries.text(id)
	if text == "":
		push_warning("Entrada de diário sem texto: %s" % id)
		return
	for entry in diary:
		if entry["id"] == id:
			return
	diary.append({"id": id, "text": text, "done": false})
	diary_entry_added.emit(id)
	diary_changed.emit()


func complete_diary_entry(id: String) -> void:
	for entry in diary:
		if entry["id"] == id and not entry["done"]:
			entry["done"] = true
			diary_changed.emit()
			return


func has_diary_entry(id: String) -> bool:
	return diary.any(func(e: Dictionary) -> bool: return e["id"] == id)


func set_eyes_closed(closed: bool) -> void:
	if closed and not eyes_close_allowed:
		closed = false
	if closed == eyes_closed:
		return
	eyes_closed = closed
	eyes_changed.emit(closed)


func set_eyes_close_allowed(allowed: bool) -> void:
	eyes_close_allowed = allowed
	if not allowed:
		set_eyes_closed(false)


## Registra a leitura de um documento: Conhecimento, diário e flag.
func register_document(doc: DocumentData) -> bool:
	var first_time := add_knowledge(doc.knowledge, "doc:" + doc.id)
	if doc.diary_id != "":
		add_diary_entry(doc.diary_id)
	if doc.sets_flag != "":
		set_flag(doc.sets_flag)
	set_flag("read:" + doc.id)
	return first_time


func reset() -> void:
	knowledge = 0.0
	flags.clear()
	diary.clear()
	knowledge_sources.clear()
	eyes_close_allowed = true
	set_eyes_closed(false)
	chapter = "prologo"
	knowledge_changed.emit(knowledge, get_tier())
	diary_changed.emit()


func to_dict() -> Dictionary:
	return {
		"knowledge": knowledge,
		"flags": flags.duplicate(),
		"diary": diary.duplicate(true),
		"knowledge_sources": knowledge_sources.duplicate(),
		"chapter": chapter,
	}


func from_dict(data: Dictionary) -> void:
	reset()
	flags = data.get("flags", {}).duplicate()
	knowledge_sources = data.get("knowledge_sources", {}).duplicate()
	chapter = data.get("chapter", "prologo")
	for entry in data.get("diary", []):
		diary.append({"id": str(entry.get("id", "")), "text": str(entry.get("text", "")), "done": bool(entry.get("done", false))})
	set_knowledge(float(data.get("knowledge", 0.0)))
	diary_changed.emit()
