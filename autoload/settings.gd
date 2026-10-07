extends Node
## Opções de conforto e acessibilidade (salvas em user://settings.cfg).
## O documento de design pede: campo de visão, intensidade do tremor,
## balanço da câmera, filtro de TV opcional e legendas ligadas por padrão.

signal changed

const PATH := "user://settings.cfg"
const SECTION := "opcoes"
const KEYS := [
	"fov", "mouse_sensitivity", "gamepad_look_speed", "invert_y",
	"jitter", "affine", "head_bob", "crt_filter",
	"subtitles", "control_hints", "end_line", "master_volume",
]

var fov := 70.0
## Graus de rotação por pixel de mouse.
var mouse_sensitivity := 0.12
## Graus por segundo com o analógico no máximo.
var gamepad_look_speed := 140.0
var invert_y := false
## 0..1: tremor de vértices do PS1 (pode causar enjoo).
var jitter := 1.0
## 0..1: deformação afim das texturas.
var affine := 1.0
## 0..1: balanço da câmera ao andar.
var head_bob := 1.0
var crt_filter := false
var subtitles := true
var control_hints := true
## Mostra "Encontrado entre os papéis do falecido..." antes dos créditos.
var end_line := true
var master_volume := 1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	InputSetup.register_defaults()
	load_settings()
	apply()


func apply() -> void:
	RenderingServer.global_shader_parameter_set(&"ps1_jitter", jitter)
	RenderingServer.global_shader_parameter_set(&"ps1_affine", affine)
	var master := AudioServer.get_bus_index(&"Master")
	AudioServer.set_bus_volume_db(master, linear_to_db(maxf(master_volume, 0.0001)))
	changed.emit()


func set_value(key: String, value: Variant) -> void:
	if not KEYS.has(key):
		push_warning("Opção desconhecida: %s" % key)
		return
	set(key, value)
	apply()
	save_settings()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	for key in KEYS:
		cfg.set_value(SECTION, key, get(key))
	var err := cfg.save(PATH)
	if err != OK:
		push_warning("Não foi possível salvar as opções (%s)." % error_string(err))


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	for key in KEYS:
		if cfg.has_section_key(SECTION, key):
			var value: Variant = cfg.get_value(SECTION, key)
			if typeof(value) == typeof(get(key)):
				set(key, value)
