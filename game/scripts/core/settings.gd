class_name Settings
extends RefCounted

# Configurações do jogador (user://settings.cfg). Aplicadas ao iniciar e a cada mudança.

const PATH := "user://settings.cfg"
const DEFAULTS := {
	"fullscreen": true,
	"vsync": true,
	"fps_cap": 0,        # 0 = ilimitado
	"scale3d": 1.0,
	"vol_master": 0.8,
	"vol_music": 0.7,
	"vol_sfx": 0.8,
	"sens": 1.0,
	"show_fps": false,
}

static var force_windowed := false   # --windowed ignora o modo tela cheia (não grava)
static var _v: Dictionary = {}
static var _loaded := false


static func load_all() -> void:
	_v = DEFAULTS.duplicate()
	var cf := ConfigFile.new()
	if cf.load(PATH) == OK:
		for k in DEFAULTS:
			if cf.has_section_key("game", k) and typeof(cf.get_value("game", k)) == typeof(DEFAULTS[k]):
				_v[k] = cf.get_value("game", k)
	_loaded = true


static func get_value(key: String) -> Variant:
	if not _loaded:
		load_all()
	return _v.get(key, DEFAULTS.get(key))


static func set_value(key: String, value: Variant) -> void:
	if not _loaded:
		load_all()
	_v[key] = value
	apply()
	save()


static func save() -> void:
	var cf := ConfigFile.new()
	for k in _v:
		cf.set_value("game", k, _v[k])
	cf.save(PATH)


static func reset() -> void:
	_v = DEFAULTS.duplicate()
	_loaded = true
	apply()
	save()


static func apply() -> void:
	if not _loaded:
		load_all()
	if DisplayServer.get_name() != "headless":
		if not OS.has_feature("editor"):
			var full: bool = _v["fullscreen"] and not force_windowed
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if full else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if _v["vsync"] else DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = int(_v["fps_cap"])
	var root := Engine.get_main_loop() as SceneTree
	if root != null:
		root.root.scaling_3d_scale = float(_v["scale3d"])
	_ensure_buses()
	_set_bus("Master", float(_v["vol_master"]))
	_set_bus("Música", float(_v["vol_music"]))
	_set_bus("Efeitos", float(_v["vol_sfx"]))


static func _ensure_buses() -> void:
	for n in ["Música", "Efeitos"]:
		if AudioServer.get_bus_index(n) < 0:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, n)
			AudioServer.set_bus_send(i, "Master")


static func _set_bus(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
		AudioServer.set_bus_mute(i, linear <= 0.001)
