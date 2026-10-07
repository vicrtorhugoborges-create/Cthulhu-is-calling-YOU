class_name Player
extends CharacterBody3D
## Francis Wayland Thurston: um homem comum, sem treino de detetive nem de luta.
## Corpo frágil: anda devagar, corre por poucos segundos antes de ficar ofegante
## e não pula. Pode agachar, interagir, examinar objetos e fechar os olhos.

enum State { NORMAL, EXAMINE, READING, LOCKED }
## Controle do jogador nas cenas roteirizadas (o Julgamento tira o controle aos poucos).
enum ControlMode { FULL, LOOK_ONLY, NONE }

signal state_changed(state: State)
signal focus_changed(target: Interactable)

const WALK_SPEED := 1.8
const SPRINT_SPEED := 3.4
const CROUCH_SPEED := 0.9
const EXHAUSTED_SPEED := 1.2
const EYES_CLOSED_SPEED := 0.8
const ACCEL := 8.0
const DECEL := 10.0
## Segundos de corrida até ficar ofegante.
const STAMINA_MAX := 3.0
const STAMINA_RECOVERY := 0.55
## Fração da estamina para voltar a correr depois de ofegar.
const STAMINA_RESUME := 0.6
const EYE_HEIGHT := 1.6
const CROUCH_EYE_HEIGHT := 1.05
const STAND_CAPSULE := 1.75
const CROUCH_CAPSULE := 1.1
const PITCH_LIMIT := deg_to_rad(82.0)
const BOB_AMPLITUDE := 0.035
const EXAMINE_ROTATE_SPEED := 0.012

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interact_ray: RayCast3D = $Head/Camera3D/InteractRay
@onready var examine_anchor: Node3D = $Head/Camera3D/ExamineAnchor
@onready var examine_light: OmniLight3D = $Head/Camera3D/ExamineAnchor/ExamineLight
@onready var lantern: OmniLight3D = $Head/Lantern
@onready var collision: CollisionShape3D = $CollisionShape3D
@onready var ceiling_ray: RayCast3D = $CeilingRay

var state := State.NORMAL
var control := ControlMode.FULL
## Multiplicador de velocidade usado pelos roteiros (passos que pesam no Julgamento).
var move_speed_scale := 1.0
var stamina := STAMINA_MAX
var exhausted := false
var crouching := false
var focus: Interactable
## Quadro da última troca de estado: ações nesse quadro são ignoradas
## (o mesmo clique não fecha um documento e reabre outro).
var last_state_change_frame := -1

var _yaw := 0.0
var _pitch := 0.0
var _look_input := Vector2.ZERO
var _bob_time := 0.0
var _last_step_phase := 0.0
var _eye_height := EYE_HEIGHT
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

# Cone de visão limitado (Julgamento): centro e meia-abertura, em radianos.
var _cone_enabled := false
var _cone_center := Vector2.ZERO
var _cone_extent := Vector2.ZERO
var _forced_look_tween: Tween

# Tremor de câmera e inclinação do horizonte.
var _shake := 0.0
var _shake_decay := 1.5
var roll_wobble_deg := 0.0
var pitch_offset_deg := 0.0
var _extra_roll_deg := 0.0

# Exame de objetos.
var _examined: ExaminableItem
var _examined_visual: Node3D
var _examine_restore := {}


func _ready() -> void:
	_yaw = rotation.y
	rotation = Vector3.ZERO
	interact_ray.add_exception(self)
	ceiling_ray.add_exception(self)
	examine_light.visible = false
	camera.fov = Settings.fov
	Settings.changed.connect(func() -> void: camera.fov = Settings.fov)
	camera.make_current()


# --- Entrada -----------------------------------------------------------------

## Chamado pela cena principal com o movimento do mouse (em pixels).
func add_look_input(relative: Vector2) -> void:
	if state == State.EXAMINE:
		_rotate_examined(relative)
		return
	_look_input += relative


func _process(delta: float) -> void:
	_update_look(delta)
	_update_focus()
	_update_eyes()
	_update_camera_effects(delta)
	if state == State.EXAMINE:
		_update_examine(delta)
	_handle_actions()


func _handle_actions() -> void:
	if Engine.get_process_frames() <= last_state_change_frame + 1:
		return
	if Input.is_action_just_pressed(&"interact"):
		match state:
			State.NORMAL:
				if focus and control == ControlMode.FULL:
					focus.interact(self)
			State.EXAMINE:
				end_examine()
	elif Input.is_action_just_pressed(&"back") and state == State.EXAMINE:
		end_examine()


func _update_look(delta: float) -> void:
	var pad := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	var allow_look := control != ControlMode.NONE and state in [State.NORMAL, State.LOCKED] and _forced_look_tween == null
	if allow_look:
		var sens := deg_to_rad(Settings.mouse_sensitivity)
		var invert := -1.0 if Settings.invert_y else 1.0
		_yaw -= _look_input.x * sens
		_pitch -= _look_input.y * sens * invert
		_yaw -= pad.x * deg_to_rad(Settings.gamepad_look_speed) * delta
		_pitch -= pad.y * deg_to_rad(Settings.gamepad_look_speed) * delta * invert
	elif state == State.EXAMINE and pad.length() > 0.0:
		_rotate_examined(pad * 600.0 * delta)
	_look_input = Vector2.ZERO
	_pitch = clampf(_pitch, -PITCH_LIMIT, PITCH_LIMIT)
	if _cone_enabled:
		_yaw = _cone_center.x + clampf(wrapf(_yaw - _cone_center.x, -PI, PI), -_cone_extent.x, _cone_extent.x)
		_pitch = clampf(_pitch, _cone_center.y - _cone_extent.y, _cone_center.y + _cone_extent.y)
	rotation.y = _yaw
	head.rotation.x = _pitch + deg_to_rad(pitch_offset_deg)


# --- Movimento ---------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= _gravity * delta
	else:
		velocity.y = maxf(velocity.y, -0.1)

	var can_move := state == State.NORMAL and control == ControlMode.FULL
	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back") if can_move else Vector2.ZERO
	_update_crouch(delta, can_move and Input.is_action_pressed(&"crouch"))

	var wants_sprint := can_move and Input.is_action_pressed(&"sprint") and input.y < -0.1 and not crouching and not GameState.eyes_closed
	var speed := WALK_SPEED
	if crouching:
		speed = CROUCH_SPEED
	elif exhausted:
		speed = EXHAUSTED_SPEED
	elif wants_sprint and stamina > 0.0:
		speed = SPRINT_SPEED
	if GameState.eyes_closed:
		speed = minf(speed, EYES_CLOSED_SPEED)
	speed *= move_speed_scale

	_update_stamina(delta, speed > WALK_SPEED * move_speed_scale + 0.01 and input.length() > 0.1)

	var dir := (transform.basis * Vector3(input.x, 0.0, input.y))
	dir.y = 0.0
	dir = dir.normalized() * minf(input.length(), 1.0)
	var target := dir * speed
	var rate := ACCEL if target.length() > 0.01 else DECEL
	velocity.x = move_toward(velocity.x, target.x, rate * delta)
	velocity.z = move_toward(velocity.z, target.z, rate * delta)
	move_and_slide()
	_update_bob_and_steps(delta)


func _update_stamina(delta: float, sprinting: bool) -> void:
	if sprinting:
		stamina -= delta
		if stamina <= 0.0:
			stamina = 0.0
			exhausted = true
			Audio.play_sfx("sfx_breath_exhausted", -3.0, &"Body")
	else:
		stamina = minf(stamina + STAMINA_RECOVERY * delta, STAMINA_MAX)
		if exhausted and stamina >= STAMINA_MAX * STAMINA_RESUME:
			exhausted = false


func _update_crouch(delta: float, wants_crouch: bool) -> void:
	if not wants_crouch and crouching and ceiling_ray.is_colliding():
		wants_crouch = true
	crouching = wants_crouch
	var target_eye := CROUCH_EYE_HEIGHT if crouching else EYE_HEIGHT
	_eye_height = move_toward(_eye_height, target_eye, delta * 3.0)
	var capsule := collision.shape as CapsuleShape3D
	var target_h := CROUCH_CAPSULE if crouching else STAND_CAPSULE
	capsule.height = move_toward(capsule.height, target_h, delta * 3.0)
	collision.position.y = capsule.height * 0.5


func _update_bob_and_steps(delta: float) -> void:
	var horizontal := Vector2(velocity.x, velocity.z).length()
	var bob := 0.0
	if is_on_floor() and horizontal > 0.2:
		_bob_time += delta * horizontal * 2.2
		bob = sin(_bob_time * 2.0) * BOB_AMPLITUDE * Settings.head_bob * clampf(horizontal / WALK_SPEED, 0.5, 1.5)
		var phase := fposmod(_bob_time, PI)
		if phase < _last_step_phase:
			_play_step()
		_last_step_phase = phase
	head.position.y = _eye_height + bob


func _play_step() -> void:
	var surface := "wood"
	var floor_collider := get_last_slide_collision()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y > 0.7:
			floor_collider = c
			break
	if floor_collider and floor_collider.get_collider() and floor_collider.get_collider().has_meta(&"surface"):
		surface = floor_collider.get_collider().get_meta(&"surface")
	var volume := -14.0 if crouching else -8.0
	Audio.play_sfx("sfx_step_" + surface, volume)


# --- Foco e interação --------------------------------------------------------

func _update_focus() -> void:
	var target: Interactable = null
	if state == State.NORMAL and control == ControlMode.FULL and not GameState.eyes_closed and interact_ray.is_colliding():
		var hit := interact_ray.get_collider()
		if hit is Interactable and (hit as Interactable).enabled:
			target = hit
	if target != focus:
		focus = target
		focus_changed.emit(focus)
		if focus and focus.hint_id != "":
			Game.show_hint(focus.hint_id)


func set_state(new_state: State) -> void:
	if state == new_state:
		return
	state = new_state
	last_state_change_frame = Engine.get_process_frames()
	if state != State.NORMAL:
		GameState.set_eyes_closed(false)
	state_changed.emit(state)


func _update_eyes() -> void:
	var wants := state == State.NORMAL and control != ControlMode.NONE and Input.is_action_pressed(&"close_eyes")
	GameState.set_eyes_closed(wants)


# --- Exame de objetos --------------------------------------------------------

func begin_examine(item: ExaminableItem) -> void:
	if state != State.NORMAL:
		return
	var visual := item.get_visual()
	if visual == null:
		return
	_examined = item
	_examined_visual = visual
	_examine_restore = {
		"parent": visual.get_parent(),
		"index": visual.get_index(),
		"transform": visual.transform,
	}
	set_state(State.EXAMINE)
	visual.reparent(examine_anchor, true)
	examine_light.visible = true
	var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(visual, "position", item.examine_offset, 0.35)
	tw.tween_property(visual, "quaternion", Quaternion.from_euler(item.examine_rotation), 0.35)
	tw.tween_property(visual, "scale", Vector3.ONE * item.examine_scale, 0.35)
	Audio.play_sfx("sfx_paper", -12.0)
	item.on_examine_started(self)
	Game.show_hint("rotate")


func end_examine() -> void:
	if _examined == null:
		return
	var item := _examined
	var visual := _examined_visual
	_examined = null
	_examined_visual = null
	examine_light.visible = false
	if item.pickup:
		visual.queue_free()
	else:
		var parent: Node = _examine_restore["parent"]
		visual.reparent(parent, true)
		parent.move_child(visual, mini(_examine_restore["index"], parent.get_child_count() - 1))
		var home: Transform3D = item.rest_transform_for(_examine_restore["transform"])
		var tw := create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(visual, "position", home.origin, 0.3)
		tw.tween_property(visual, "quaternion", home.basis.get_rotation_quaternion(), 0.3)
		tw.tween_property(visual, "scale", home.basis.get_scale(), 0.3)
	set_state(State.NORMAL)
	item.on_examine_finished(self)


func _rotate_examined(relative: Vector2) -> void:
	if _examined_visual == null:
		return
	var cam_basis := camera.global_basis
	_examined_visual.global_rotate(cam_basis.y.normalized(), relative.x * EXAMINE_ROTATE_SPEED)
	_examined_visual.global_rotate(cam_basis.x.normalized(), relative.y * EXAMINE_ROTATE_SPEED)


func _update_examine(_delta: float) -> void:
	if _examined and _examined_visual:
		_examined.check_detail(_examined_visual, camera)


# --- Efeitos de câmera e controle roteirizado --------------------------------

func add_shake(amount: float, decay := 1.5) -> void:
	_shake = maxf(_shake, amount)
	_shake_decay = decay


func _update_camera_effects(delta: float) -> void:
	_shake = maxf(_shake - _shake_decay * delta, 0.0)
	var s := _shake * _shake
	camera.h_offset = randf_range(-1.0, 1.0) * 0.06 * s
	camera.v_offset = randf_range(-1.0, 1.0) * 0.06 * s
	var t := Time.get_ticks_msec() / 1000.0
	var roll := sin(t * 0.37) * roll_wobble_deg + _extra_roll_deg + randf_range(-1.0, 1.0) * 1.5 * s
	camera.rotation.z = deg_to_rad(roll)


func set_control(mode: ControlMode) -> void:
	control = mode
	if mode != ControlMode.FULL:
		focus = null
		focus_changed.emit(null)


## Limita a cabeça a um cone (yaw/pitch em radianos, centro e meia-abertura).
func set_look_cone(center_yaw: float, center_pitch: float, yaw_extent: float, pitch_extent: float) -> void:
	_cone_enabled = true
	_cone_center = Vector2(center_yaw, center_pitch)
	_cone_extent = Vector2(yaw_extent, pitch_extent)


func clear_look_cone() -> void:
	_cone_enabled = false


## Yaw e pitch que apontam a câmera para um ponto do mundo.
func look_angles_to(point: Vector3) -> Vector2:
	var from := head.global_position
	var d := point - from
	var yaw := atan2(-d.x, -d.z)
	var pitch := atan2(d.y, Vector2(d.x, d.z).length())
	return Vector2(yaw, pitch)


## Puxa a cabeça sozinha até olhar para um ponto (Thurston ergue a cabeça).
func force_look_at(point: Vector3, duration: float) -> void:
	var target := look_angles_to(point)
	var start_yaw := _yaw
	var delta_yaw := wrapf(target.x - _yaw, -PI, PI)
	if _forced_look_tween:
		_forced_look_tween.kill()
	_forced_look_tween = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_forced_look_tween.tween_method(func(v: float) -> void: _yaw = start_yaw + delta_yaw * v, 0.0, 1.0, duration)
	_forced_look_tween.tween_property(self, "_pitch", target.y, duration)
	await _forced_look_tween.finished
	_forced_look_tween = null


func get_yaw() -> float:
	return _yaw


func get_pitch() -> float:
	return _pitch


func set_view(yaw: float, pitch: float) -> void:
	_yaw = yaw
	_pitch = pitch
	rotation.y = _yaw
	head.rotation.x = _pitch


func set_lantern(enabled: bool) -> void:
	lantern.visible = enabled
