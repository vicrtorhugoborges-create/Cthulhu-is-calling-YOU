class_name JudgmentSequence
extends Node
## O Julgamento: 56 segundos a partir da abertura da porta.
## O jogador perde o controle aos poucos até restar apenas olhar Cthulhu por
## 12 segundos; não há ataque nem ação, e a tela escurece com um som maléfico.
##
## Linha do tempo (documento de design, seção "O Julgamento"):
##   0–12  a porta se abre (cede pelo topo e recua na diagonal); passos pesam aos 6 s
##   12–22 a escuridão escoa como fumaça e escurece o céu; o som ambiente se esvai
##   20    o jogador para, sem aviso
##   22–30 tremor, som úmido e arrastado; garras agarram o batente; ele sobe
##   26–30 a câmera é puxada para cima sozinha: Thurston ergue a cabeça
##   30–42 o olhar: só gira a cabeça num cone pequeno; fechar os olhos não responde
##   40    o coração para
##   42–46 a imagem escurece em 4 s enquanto o som maléfico toca (42–50)
##   50    silêncio total
##   56    créditos (ou a linha "Encontrado entre os papéis...")

signal finished

const DOOR_OPEN := Vector2(0.0, 12.0)
const STEPS_SLOW := Vector2(6.0, 20.0)
const DARKNESS := Vector2(12.0, 22.0)
const PLAYER_STOPS := 20.0
const EMERGE := Vector2(22.0, 30.0)
const CLAWS_GRAB := Vector2(22.0, 25.5)
const HEAD_RAISE := Vector2(26.0, 30.0)
const GAZE := Vector2(30.0, 42.0)
const GESTURE := Vector2(32.0, 39.0)
const HEART_STOPS := 40.0
const FADE := Vector2(42.0, 46.0)
const EVIL_SOUND := Vector2(42.0, 50.0)
const SILENCE_FROM := 50.0
const END := 56.0
## Silêncio de 2–3 s antes do momento-chave.
const SILENCE_BEFORE := 2.5
## Movimento das coisas gigantes: 12 quadros por segundo.
const GIANT_FPS := 12.0
## Atraso do som em relação à imagem, como um trovão distante.
const SOUND_DELAY := 0.8
const HEART_START_BPM := 118.0
const HEART_END_BPM := 34.0
## Folga para o cone de visão: a silhueta sempre transborda as bordas da tela.
const CONE_MARGIN_DEG := 4.0
const CONE_MIN_YAW_DEG := 3.0
const CONE_PITCH_DEG := 6.0

@export var door: Node3D
@export var claw_left: Node3D
@export var claw_right: Node3D
@export var cthulhu: MeshInstance3D
@export var sky: MeshInstance3D
@export var darkness: CPUParticles3D
## Quanto a criatura sobe (em metros) do fundo até a posição final.
@export var rise_height := 440.0
## Altura da porta (o giro é em torno da base).
@export var door_height := 70.0

var running := false
var _started := false
var t := 0.0

var _door_start: Transform3D
var _claw_l_end: Transform3D
var _claw_r_end: Transform3D
var _cthulhu_end: Vector3
var _fired := {}
var _player: Player


func _ready() -> void:
	if cthulhu and cthulhu.mesh == null:
		cthulhu.mesh = CthulhuBuilder.build_body()
	for claw in [claw_left, claw_right]:
		if claw is MeshInstance3D and claw.mesh == null:
			claw.mesh = CthulhuBuilder.build_claw()
	if door:
		_door_start = door.transform
	if claw_left:
		_claw_l_end = claw_left.transform
	if claw_right:
		_claw_r_end = claw_right.transform
	if cthulhu:
		_cthulhu_end = cthulhu.position
	_apply(0.0)


func start() -> void:
	if _started:
		return
	_started = true
	_player = Game.player
	GameState.set_eyes_close_allowed(false)
	await Audio.cut_to_silence(SILENCE_BEFORE)
	t = 0.0
	_fired.clear()
	running = true


## Tempo arredondado a 12 quadros por segundo (para as coisas gigantes).
static func giant_time(time: float) -> float:
	return floor(time * GIANT_FPS) / GIANT_FPS


static func phase(time: float, window: Vector2) -> float:
	return clampf(inverse_lerp(window.x, window.y, time), 0.0, 1.0)


## Batimentos por minuto do coração no instante `time` (0 = parado).
static func heart_bpm_at(time: float) -> float:
	if time < EMERGE.x or time >= HEART_STOPS:
		return 0.0
	if time < GAZE.x:
		return HEART_START_BPM
	return lerpf(HEART_START_BPM, HEART_END_BPM, phase(time, Vector2(GAZE.x, HEART_STOPS)))


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	_apply(t)
	_beats()
	if t >= END:
		running = false
		finished.emit()


func _once(key: String) -> bool:
	if _fired.has(key):
		return false
	_fired[key] = true
	return true


## Estado visual contínuo para o instante `time`.
func _apply(time: float) -> void:
	var gt := giant_time(time)
	if door:
		var p := ease(phase(gt, DOOR_OPEN), 2.2)
		# Cede pelo topo e recua na diagonal: não dá para dizer se é vertical ou horizontal.
		var xf := _door_start
		var pivot := xf.origin - xf.basis.y.normalized() * door_height * 0.5
		var rot := Basis(xf.basis.x.normalized(), deg_to_rad(-38.0 * p)) * Basis(xf.basis.z.normalized(), deg_to_rad(9.0 * p))
		var new_basis := rot * xf.basis
		var new_origin := pivot + rot * (xf.origin - pivot) + Vector3(10.0, -6.0, -34.0) * p
		door.transform = Transform3D(new_basis, new_origin)
	if sky and sky.material_override is ShaderMaterial:
		var sky_mat := sky.material_override as ShaderMaterial
		sky_mat.set_shader_parameter(&"dim", 0.6 * phase(time, DARKNESS))
		# Contraluz: acende enquanto ele sobe e apaga com a cena.
		sky_mat.set_shader_parameter(&"glow_intensity", 1.3 * phase(time, EMERGE) * (1.0 - phase(time, FADE)))
	var claw_p := ease(phase(gt, CLAWS_GRAB), 0.5)
	for pair in [[claw_left, _claw_l_end], [claw_right, _claw_r_end]]:
		var claw: Node3D = pair[0]
		if claw:
			var end_xf: Transform3D = pair[1]
			claw.visible = claw_p > 0.0
			claw.transform = Transform3D(end_xf.basis, end_xf.origin + Vector3(0, -40, -25) * (1.0 - claw_p))
	if cthulhu:
		var rise := ease(phase(gt, Vector2(EMERGE.x + 1.0, EMERGE.y)), 0.4)
		cthulhu.visible = rise > 0.0
		cthulhu.position = _cthulhu_end + Vector3(0, -rise_height * (1.0 - rise), 0)
		var mat := cthulhu.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter(&"gesture", smoothstep(0.0, 1.0, phase(gt, GESTURE)) * (1.0 - phase(gt, Vector2(GESTURE.y, GESTURE.y + 3.0))))
			mat.set_shader_parameter(&"darkness", phase(time, FADE))
		for claw in [claw_left, claw_right]:
			if claw is MeshInstance3D and claw.material_override is ShaderMaterial:
				(claw.material_override as ShaderMaterial).set_shader_parameter(&"darkness", phase(time, FADE))
	if is_instance_valid(_player):
		_player.move_speed_scale = lerpf(1.0, 0.12, smoothstep(0.0, 1.0, phase(time, STEPS_SLOW))) if time < PLAYER_STOPS else 0.0


## Eventos pontuais da linha do tempo.
func _beats() -> void:
	if _once("door"):
		Audio.play_music("mus_drone_low_loop", -3.0, 0.5)
		Audio.play_sfx("sfx_door_grind", -1.0)
	if t >= DARKNESS.x and _once("darkness"):
		if darkness:
			darkness.emitting = true
		Audio.stop_all_ambience(DARKNESS.y - DARKNESS.x)
		Audio.stop_music(DARKNESS.y - DARKNESS.x)
		Audio.stop_chant()
		Audio.set_drips(false)
	if t >= DARKNESS.y and _once("darkness_end"):
		if darkness:
			darkness.emitting = false
	if t >= PLAYER_STOPS and _once("stop"):
		if is_instance_valid(_player):
			_player.set_control(Player.ControlMode.LOOK_ONLY)
	if t >= EMERGE.x and _once("emerge"):
		Audio.play_ambience("tremor", "sfx_tremor_loop", -3.0, 1.0)
		Audio.play_sfx_delayed("sfx_wet_drag", SOUND_DELAY, -2.0)
		for k in [1.5, 4.0, 6.5]:
			Audio.play_sfx_delayed("sfx_thump_far", k + SOUND_DELAY, 0.0)
		if is_instance_valid(_player):
			_player.add_shake(0.8, 0.09)
	if t >= EMERGE.x and t < GAZE.y and is_instance_valid(_player) and fmod(t, 2.0) < get_process_delta_time():
		_player.add_shake(0.55, 0.12)
	if t >= HEAD_RAISE.x and _once("raise"):
		if is_instance_valid(_player) and cthulhu:
			_player.force_look_at(_head_point(), HEAD_RAISE.y - HEAD_RAISE.x)
	if t >= GAZE.x and _once("gaze"):
		_enter_gaze()
	if t >= GESTURE.x and _once("gesture"):
		Audio.play_sfx_delayed("sfx_tentacle_move", SOUND_DELAY + 0.4, 0.0)
	var bpm := heart_bpm_at(t)
	if absf(bpm - Audio.get_heartbeat_bpm()) > 1.0 or (bpm == 0.0) != (Audio.get_heartbeat_bpm() == 0.0):
		Audio.set_heartbeat(bpm, -2.0)
	if t >= FADE.x and _once("fade"):
		if is_instance_valid(_player):
			_player.set_control(Player.ControlMode.NONE)
			_player.clear_look_cone()
		Audio.stop_ambience("tremor", 0.3)
		Audio.stop_music(0.2)
		Audio.play_sfx("sfx_evil", 0.0, &"Music")
		Game.fade_world(1.0, FADE.y - FADE.x)
		Narration.clear()
	if t >= SILENCE_FROM and _once("silence"):
		Audio.silence_all()


## Centro da cabeça na posição final (mesmo enquanto ele ainda está subindo).
func _head_point() -> Vector3:
	var parent_xf: Transform3D = (cthulhu.get_parent() as Node3D).global_transform
	return parent_xf * Transform3D(cthulhu.basis, _cthulhu_end) * CthulhuBuilder.HEAD_CENTER


func _enter_gaze() -> void:
	if not is_instance_valid(_player):
		return
	var angles := _player.look_angles_to(_head_point())
	var final_pos: Vector3 = (cthulhu.get_parent() as Node3D).global_transform * _cthulhu_end
	var yaw_extent := deg_to_rad(gaze_yaw_extent_deg(_player.camera, final_pos, CthulhuBuilder.WING_HALF_SPAN * cthulhu.scale.x))
	_player.set_look_cone(angles.x, angles.y, yaw_extent, deg_to_rad(CONE_PITCH_DEG))


## Meia-abertura horizontal do cone (graus) para que as asas nunca caibam na tela.
static func gaze_yaw_extent_deg(camera: Camera3D, creature_pos: Vector3, wing_half_span: float) -> float:
	var flat := Vector2(creature_pos.x - camera.global_position.x, creature_pos.z - camera.global_position.z)
	var wing_half_angle := rad_to_deg(atan2(wing_half_span, flat.length()))
	var aspect := 4.0 / 3.0
	var half_h := rad_to_deg(atan(tan(deg_to_rad(camera.fov * 0.5)) * aspect))
	return maxf(CONE_MIN_YAW_DEG, wing_half_angle - half_h - CONE_MARGIN_DEG)
