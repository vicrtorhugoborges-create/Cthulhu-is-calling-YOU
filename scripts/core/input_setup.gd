class_name InputSetup
extends RefCounted
## Mapa de controles padrão (teclado, mouse e controle).
## Ações já configuradas em Project Settings > Input Map não são sobrescritas,
## então dá para remapear pelo editor sem mexer aqui.

const KEYS := {
	&"move_forward": [KEY_W, KEY_UP],
	&"move_back": [KEY_S, KEY_DOWN],
	&"move_left": [KEY_A, KEY_LEFT],
	&"move_right": [KEY_D, KEY_RIGHT],
	&"sprint": [KEY_SHIFT],
	&"crouch": [KEY_CTRL, KEY_C],
	&"interact": [KEY_E, KEY_F],
	&"close_eyes": [KEY_SPACE, KEY_Q],
	&"diary": [KEY_TAB, KEY_J],
	&"pause": [KEY_ESCAPE],
	&"back": [KEY_ESCAPE, KEY_BACKSPACE],
	&"page_next": [KEY_D, KEY_RIGHT],
	&"page_prev": [KEY_A, KEY_LEFT],
}

const MOUSE := {
	&"interact": [MOUSE_BUTTON_LEFT],
	&"back": [MOUSE_BUTTON_RIGHT],
}

const PAD_BUTTONS := {
	&"interact": [JOY_BUTTON_A],
	&"back": [JOY_BUTTON_B],
	&"sprint": [JOY_BUTTON_LEFT_STICK],
	&"crouch": [JOY_BUTTON_RIGHT_STICK],
	&"diary": [JOY_BUTTON_BACK],
	&"pause": [JOY_BUTTON_START],
	&"page_next": [JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT],
	&"page_prev": [JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT],
}

## [ação, eixo, sentido]
const PAD_AXES := [
	[&"move_forward", JOY_AXIS_LEFT_Y, -1.0],
	[&"move_back", JOY_AXIS_LEFT_Y, 1.0],
	[&"move_left", JOY_AXIS_LEFT_X, -1.0],
	[&"move_right", JOY_AXIS_LEFT_X, 1.0],
	[&"look_up", JOY_AXIS_RIGHT_Y, -1.0],
	[&"look_down", JOY_AXIS_RIGHT_Y, 1.0],
	[&"look_left", JOY_AXIS_RIGHT_X, -1.0],
	[&"look_right", JOY_AXIS_RIGHT_X, 1.0],
	[&"close_eyes", JOY_AXIS_TRIGGER_LEFT, 1.0],
]


static func register_defaults() -> void:
	var events := {}
	for action in KEYS:
		for key in KEYS[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			_append(events, action, ev)
	for action in MOUSE:
		for button in MOUSE[action]:
			var ev := InputEventMouseButton.new()
			ev.button_index = button
			_append(events, action, ev)
	for action in PAD_BUTTONS:
		for button in PAD_BUTTONS[action]:
			var ev := InputEventJoypadButton.new()
			ev.button_index = button
			_append(events, action, ev)
	for spec in PAD_AXES:
		var ev := InputEventJoypadMotion.new()
		ev.axis = spec[1]
		ev.axis_value = spec[2]
		_append(events, spec[0], ev)

	for action in events:
		if InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty():
			continue
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.25)
		for ev in events[action]:
			InputMap.action_add_event(action, ev)


static func _append(events: Dictionary, action: StringName, ev: InputEvent) -> void:
	if not events.has(action):
		events[action] = []
	events[action].append(ev)
