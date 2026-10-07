class_name CorruptionDirector
extends Node
## Aplica no mundo os efeitos do Conhecimento (tabela do documento de design):
##   0–25   mundo normal
##   26–50  canto no limite da audição (Audio); objetos mudam fora da vista (ShiftyObject)
##   51–75  texturas trocam por um instante; sombras de tentáculo (TentacleShadowSpot)
##   76–100 geometria errada em cômodos comuns; narração perde o tom cético (Narration)
## Com os olhos fechados, as distorções somem.

const FLASH_MIN_INTERVAL := 6.0
const FLASH_MAX_INTERVAL := 15.0
const FLASH_MIN_DURATION := 0.12
const FLASH_MAX_DURATION := 0.22

var _distortion := 0.0
var _flash_timer := 0.0
var _flash_left := 0.0


func _ready() -> void:
	_flash_timer = randf_range(FLASH_MIN_INTERVAL, FLASH_MAX_INTERVAL)
	_set_flash(false)
	RenderingServer.global_shader_parameter_set(&"world_distortion", 0.0)


## Distorção-alvo para um valor de Conhecimento (sem contar olhos e nível).
static func distortion_for(knowledge: float) -> float:
	if knowledge < GameState.TIER_THRESHOLDS[2]:
		return 0.0
	return lerpf(0.55, 1.0, inverse_lerp(GameState.TIER_THRESHOLDS[2], GameState.KNOWLEDGE_MAX, knowledge))


func _process(delta: float) -> void:
	var playing := is_instance_valid(Game.player)
	var target := 0.0
	if playing and not GameState.eyes_closed:
		target = distortion_for(GameState.knowledge)
		if Game.level is Level:
			target = clampf(target + (Game.level as Level).extra_distortion, 0.0, 1.0)
	var rate := 3.0 if target < _distortion else 0.6
	_distortion = move_toward(_distortion, target, rate * delta)
	RenderingServer.global_shader_parameter_set(&"world_distortion", _distortion)

	if _flash_left > 0.0:
		_flash_left -= delta
		if _flash_left <= 0.0 or GameState.eyes_closed:
			_flash_left = 0.0
			_set_flash(false)
		return
	if not playing or GameState.get_tier() < 2 or GameState.eyes_closed:
		return
	_flash_timer -= delta
	if _flash_timer <= 0.0:
		_flash_timer = randf_range(FLASH_MIN_INTERVAL, FLASH_MAX_INTERVAL)
		_flash_left = randf_range(FLASH_MIN_DURATION, FLASH_MAX_DURATION)
		_set_flash(true)


func _set_flash(on: bool) -> void:
	RenderingServer.global_shader_parameter_set(&"corruption_flash", 1.0 if on else 0.0)
