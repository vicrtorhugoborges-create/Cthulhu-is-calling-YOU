extends Node
## Diretor de áudio. O som carrega metade do terror e segue a lógica lo-fi da imagem.
##
## - Barramentos: World (abafado com olhos fechados) recebe Ambience, SFX e Chant;
##   Music, Voice, Body (coração, respiração) e UI vão direto para o Master.
## - O canto do culto toca desde o prólogo: inaudível no começo,
##   mais nítido conforme o Conhecimento sobe.
## - Coração, gotas d'água (a partir do cap. III) e o corte de silêncio
##   de 2–3 s antes de cada momento-chave.
##
## Sons são procurados primeiro em assets/audio/final/ (gravações definitivas,
## .ogg ou .wav) e depois em assets/audio/draft/ (rascunhos gerados por
## tools/gen_draft_audio.js). Pedir "sfx_step_wood" sorteia entre _1.._9.

const FINAL_DIR := "res://assets/audio/final/"
const DRAFT_DIR := "res://assets/audio/draft/"
const VOICE_DIR := "res://assets/audio/final/voice/"
const CHANT_STREAM := "vox_chant_loop"

## [nome, envia para]. A ordem importa: um barramento só envia para outro anterior.
const BUSES := [
	["World", "Master"],
	["Ambience", "World"],
	["SFX", "World"],
	["Chant", "World"],
	["Music", "Master"],
	["Voice", "Master"],
	["Body", "Master"],
	["UI", "Master"],
]

## Curva do canto: [Conhecimento, volume dB, corte do filtro passa-baixa Hz].
const CHANT_CURVE := [
	[0.0, -80.0, 300.0],
	[20.0, -80.0, 300.0],
	[26.0, -40.0, 450.0],
	[50.0, -31.0, 1200.0],
	[75.0, -23.0, 3200.0],
	[100.0, -14.0, 9000.0],
]

var _cache := {}
var _warned := {}
var _ambience := {}
var _music: AudioStreamPlayer
var _chant: AudioStreamPlayer
var _chant_filter: AudioEffectLowPassFilter
var _muffle_filter: AudioEffectLowPassFilter
var _heart_timer: Timer
var _heart_bpm := 0.0
var _heart_volume_db := -4.0
var _drip_timer: Timer
var _muffle_tween: Tween
var _chant_tween: Tween
var _silenced := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_music = _make_player(&"Music")
	_chant = _make_player(&"Chant")
	_chant.volume_db = -80.0
	_heart_timer = Timer.new()
	_heart_timer.one_shot = false
	_heart_timer.timeout.connect(_on_heart_timer)
	add_child(_heart_timer)
	_drip_timer = Timer.new()
	_drip_timer.one_shot = true
	_drip_timer.timeout.connect(_on_drip_timer)
	add_child(_drip_timer)
	GameState.knowledge_changed.connect(_on_knowledge_changed)
	GameState.eyes_changed.connect(_on_eyes_changed)


# --- Barramentos -------------------------------------------------------------

func _setup_buses() -> void:
	for spec in BUSES:
		if AudioServer.get_bus_index(spec[0]) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, spec[0])
	for spec in BUSES:
		AudioServer.set_bus_send(AudioServer.get_bus_index(spec[0]), spec[1])
	_muffle_filter = AudioEffectLowPassFilter.new()
	_muffle_filter.cutoff_hz = 20000.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"World"), _muffle_filter)
	_chant_filter = AudioEffectLowPassFilter.new()
	_chant_filter.cutoff_hz = 300.0
	AudioServer.add_bus_effect(AudioServer.get_bus_index(&"Chant"), _chant_filter)


func _make_player(bus: StringName) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = bus
	add_child(p)
	return p


# --- Biblioteca --------------------------------------------------------------

func has_stream(stream_name: String) -> bool:
	return get_stream(stream_name, false) != null


func get_stream(stream_name: String, warn := true) -> AudioStream:
	if _cache.has(stream_name):
		return _cache[stream_name]
	var stream := _load_exact(stream_name)
	if stream == null:
		var variants: Array[AudioStream] = []
		for i in range(1, 10):
			var v := _load_exact("%s_%d" % [stream_name, i])
			if v == null:
				break
			variants.append(v)
		if variants.size() == 1:
			stream = variants[0]
		elif variants.size() > 1:
			var rnd := AudioStreamRandomizer.new()
			for v in variants:
				rnd.add_stream(-1, v)
			rnd.random_pitch = 1.06
			rnd.random_volume_offset_db = 1.5
			stream = rnd
	if stream == null:
		if warn and not _warned.has(stream_name):
			_warned[stream_name] = true
			push_warning("Som não encontrado: %s" % stream_name)
		return null
	_cache[stream_name] = stream
	return stream


func _load_exact(stream_name: String) -> AudioStream:
	for path in [FINAL_DIR + stream_name + ".ogg", FINAL_DIR + stream_name + ".wav", DRAFT_DIR + stream_name + ".wav"]:
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


# --- Efeitos -----------------------------------------------------------------

## Toca um som sem posição. Devolve o player (ou null se o som não existe).
func play_sfx(stream_name: String, volume_db := 0.0, bus: StringName = &"SFX", pitch := 1.0) -> AudioStreamPlayer:
	var stream := get_stream(stream_name)
	if stream == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()
	return p


## Toca um som posicionado no mundo 3D do nível atual.
func play_sfx_3d(stream_name: String, position: Vector3, volume_db := 0.0, max_distance := 30.0) -> AudioStreamPlayer3D:
	var stream := get_stream(stream_name)
	var parent: Node = Game.level if is_instance_valid(Game.level) else null
	if stream == null or parent == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.bus = &"SFX"
	p.volume_db = volume_db
	p.max_distance = max_distance
	p.unit_size = 4.0
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.global_position = position
	p.play()
	return p


## "Som atrasado": coisas gigantes soam um instante depois de vistas, como trovão.
func play_sfx_delayed(stream_name: String, delay: float, volume_db := 0.0, bus: StringName = &"SFX") -> void:
	await get_tree().create_timer(delay, true, false, true).timeout
	if not _silenced:
		play_sfx(stream_name, volume_db, bus)


func play_ui(stream_name: String, volume_db := -6.0) -> void:
	play_sfx(stream_name, volume_db, &"UI")


# --- Ambiência e música ------------------------------------------------------

func play_ambience(layer: String, stream_name: String, volume_db := 0.0, fade := 2.0) -> void:
	var current: AudioStreamPlayer = _ambience.get(layer)
	var stream := get_stream(stream_name)
	if current and current.stream == stream and current.playing:
		_fade_player(current, volume_db, fade)
		return
	stop_ambience(layer, fade)
	if stream == null:
		return
	var p := _make_player(&"Ambience")
	p.stream = stream
	p.volume_db = -60.0
	p.play()
	_ambience[layer] = p
	_fade_player(p, volume_db, fade)


func stop_ambience(layer: String, fade := 2.0) -> void:
	var p: AudioStreamPlayer = _ambience.get(layer)
	if p == null:
		return
	_ambience.erase(layer)
	_fade_player(p, -60.0, fade, true)


func stop_all_ambience(fade := 2.0) -> void:
	for layer in _ambience.keys():
		stop_ambience(layer, fade)


func play_music(stream_name: String, volume_db := -6.0, fade := 3.0) -> void:
	var stream := get_stream(stream_name)
	if stream == null:
		return
	if _music.stream != stream or not _music.playing:
		_music.stream = stream
		_music.volume_db = -60.0
		_music.play()
	_fade_player(_music, volume_db, fade)


func stop_music(fade := 3.0) -> void:
	if _music.playing:
		var tw := create_tween()
		tw.tween_property(_music, "volume_db", -60.0, maxf(fade, 0.01))
		tw.tween_callback(_music.stop)


func _fade_player(p: AudioStreamPlayer, target_db: float, fade: float, free_after := false) -> void:
	var tw := create_tween()
	tw.tween_property(p, "volume_db", target_db, maxf(fade, 0.01))
	if free_after:
		tw.tween_callback(p.queue_free)


# --- Canto do culto ----------------------------------------------------------

## Volume (dB) e corte do filtro do canto para um valor de Conhecimento.
static func chant_params(knowledge: float) -> Vector2:
	for i in range(1, CHANT_CURVE.size()):
		var a: Array = CHANT_CURVE[i - 1]
		var b: Array = CHANT_CURVE[i]
		if knowledge <= b[0]:
			var t := inverse_lerp(a[0], b[0], knowledge)
			return Vector2(lerpf(a[1], b[1], t), lerpf(a[2], b[2], t))
	var last: Array = CHANT_CURVE[-1]
	return Vector2(last[1], last[2])


func start_chant() -> void:
	var stream := get_stream(CHANT_STREAM)
	if stream == null:
		return
	if _chant.stream != stream:
		_chant.stream = stream
	if not _chant.playing:
		_chant.play()
	_apply_chant(GameState.knowledge, 0.5)


func stop_chant() -> void:
	_chant.stop()


func _on_knowledge_changed(value: float, _tier: int) -> void:
	_apply_chant(value, 3.0)


func _apply_chant(knowledge: float, fade: float) -> void:
	var params := chant_params(knowledge)
	if _chant_tween:
		_chant_tween.kill()
	_chant_tween = create_tween().set_parallel()
	_chant_tween.tween_property(_chant, "volume_db", params.x, fade)
	_chant_tween.tween_property(_chant_filter, "cutoff_hz", params.y, fade)


# --- Coração -----------------------------------------------------------------

## Batimento audível nos picos de medo. bpm <= 0 para o coração.
func set_heartbeat(bpm: float, volume_db := -4.0) -> void:
	_heart_volume_db = volume_db
	if bpm <= 0.0:
		_heart_bpm = 0.0
		_heart_timer.stop()
		return
	var was_stopped := _heart_bpm <= 0.0
	_heart_bpm = bpm
	_heart_timer.wait_time = 60.0 / bpm
	if was_stopped:
		_heart_timer.start()
		_on_heart_timer()


func get_heartbeat_bpm() -> float:
	return _heart_bpm


func _on_heart_timer() -> void:
	if _heart_bpm > 0.0:
		_heart_timer.wait_time = 60.0 / _heart_bpm
		play_sfx("sfx_heartbeat", _heart_volume_db, &"Body")


# --- Gotas d'água (a partir do capítulo III) ---------------------------------

func set_drips(enabled: bool) -> void:
	if enabled:
		if _drip_timer.is_stopped():
			_drip_timer.start(randf_range(2.0, 6.0))
	else:
		_drip_timer.stop()


func _on_drip_timer() -> void:
	var cam := Game.get_camera()
	if cam:
		var offset := Vector3(randf_range(-3.0, 3.0), randf_range(0.5, 1.5), randf_range(-3.0, 3.0))
		play_sfx_3d("sfx_drip", cam.global_position + offset, -6.0, 12.0)
	_drip_timer.start(randf_range(2.5, 7.0))


# --- Olhos fechados, silêncio ------------------------------------------------

func _on_eyes_changed(closed: bool) -> void:
	set_muffled(closed)


## Som abafado (olhos fechados, menus).
func set_muffled(muffled: bool, time := 0.35) -> void:
	if _muffle_tween:
		_muffle_tween.kill()
	_muffle_tween = create_tween().set_parallel()
	_muffle_tween.tween_property(_muffle_filter, "cutoff_hz", 450.0 if muffled else 20000.0, time)
	var world := AudioServer.get_bus_index(&"World")
	var from_db := AudioServer.get_bus_volume_db(world)
	_muffle_tween.tween_method(func(db: float) -> void: AudioServer.set_bus_volume_db(world, db), from_db, -7.0 if muffled else 0.0, time)


## Corta todo o som de uma vez por alguns segundos (antes de cada momento-chave).
func cut_to_silence(duration := 2.5) -> void:
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_mute(master, true)
	await get_tree().create_timer(duration, true, false, true).timeout
	if not _silenced:
		AudioServer.set_bus_mute(master, false)


## Silêncio total (fim do Julgamento). Desfeito por restore().
func silence_all() -> void:
	_silenced = true
	stop_all_ambience(0.0)
	_music.stop()
	_chant.stop()
	set_heartbeat(0.0)
	set_drips(false)
	for child in get_children():
		if child is AudioStreamPlayer and child != _music and child != _chant:
			child.queue_free()
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), true)


func restore() -> void:
	_silenced = false
	AudioServer.set_bus_mute(AudioServer.get_bus_index(&"Master"), false)
	set_muffled(false, 0.01)


# --- Voz ---------------------------------------------------------------------

## Toca a gravação da fala, se existir. Devolve a duração (0 sem gravação).
func play_voice(line_id: String) -> float:
	for ext in [".ogg", ".wav"]:
		var path: String = VOICE_DIR + line_id + ext
		if ResourceLoader.exists(path):
			var stream := load(path) as AudioStream
			var p := play_sfx_stream(stream, 0.0, &"Voice")
			return stream.get_length() if p else 0.0
	return 0.0


func play_sfx_stream(stream: AudioStream, volume_db := 0.0, bus: StringName = &"SFX") -> AudioStreamPlayer:
	if stream == null:
		return null
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.bus = bus
	p.volume_db = volume_db
	p.finished.connect(p.queue_free)
	add_child(p)
	p.play()
	return p
