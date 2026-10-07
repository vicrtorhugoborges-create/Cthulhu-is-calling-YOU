extends Node
## Fila de falas (narração em off de Thurston e diálogos curtos).
## A legenda é desenhada pela UI, que escuta line_started / line_finished.
## Se existir gravação em assets/audio/final/voice/<id>.ogg, ela toca junto.

signal line_started(text: String, speaker: String, duration: float)
signal line_finished
signal queue_emptied

const MIN_DURATION := 2.4
const MAX_DURATION := 9.0

var _queue: Array[Dictionary] = []
var _current := {}
var _time_left := 0.0


## Enfileira uma fala pelo id do roteiro. `interrupt` corta a fala atual.
func say(id: String, interrupt := false) -> void:
	if not NarrationLines.has_line(id):
		push_warning("Fala inexistente no roteiro: %s" % id)
		return
	_enqueue({"id": id}, interrupt)


## Fala só uma vez por partida (fica registrado nas flags e vai para o save).
func say_once(id: String, interrupt := false) -> bool:
	var flag := "said:" + id
	if GameState.has_flag(flag):
		return false
	GameState.set_flag(flag)
	say(id, interrupt)
	return true


## Texto livre (cartões, testes). Duração automática se negativa.
func say_text(text: String, speaker := "", duration := -1.0, interrupt := false) -> void:
	_enqueue({"text": text, "speaker": speaker, "duration": duration}, interrupt)


func is_speaking() -> bool:
	return not _current.is_empty()


func clear() -> void:
	_queue.clear()
	if not _current.is_empty():
		_current = {}
		line_finished.emit()


static func duration_for(text: String) -> float:
	return clampf(1.4 + text.length() * 0.06, MIN_DURATION, MAX_DURATION)


func _enqueue(entry: Dictionary, interrupt: bool) -> void:
	if interrupt:
		_queue.clear()
		_current = {}
	_queue.append(entry)
	if _current.is_empty():
		_next()


func _next() -> void:
	if _queue.is_empty():
		_current = {}
		queue_emptied.emit()
		return
	_current = _queue.pop_front()
	var text: String
	var speaker: String
	var duration: float = _current.get("duration", -1.0)
	if _current.has("id"):
		var id: String = _current["id"]
		text = NarrationLines.pick(id, GameState.get_tier())
		speaker = NarrationLines.get_speaker(id)
		var voice_len := Audio.play_voice(id)
		if voice_len > 0.0:
			duration = voice_len + 0.4
	else:
		text = _current.get("text", "")
		speaker = _current.get("speaker", "")
	if duration <= 0.0:
		duration = duration_for(text)
	_time_left = duration
	line_started.emit(text, speaker, duration)


func _process(delta: float) -> void:
	if _current.is_empty():
		return
	_time_left -= delta
	if _time_left <= 0.0:
		_current = {}
		line_finished.emit()
		_next()
