## Mapa id -> ItemData, montado varrendo res://resources/items uma vez (carregamento preguiçoso).
class_name ItemRegistry
extends RefCounted

const ROOT: String = "res://resources/items"

static var _items: Dictionary = {}
static var _loaded: bool = false


## ItemData pelo id (null se não existe).
static func get_item(id: String) -> ItemData:
	_ensure()
	return _items.get(id)


## Nome traduzido do item (ou o id formatado, se não houver tradução).
static func display_name(id: String) -> String:
	var it := get_item(id)
	if it != null and it.name_key != "":
		var t := TranslationServer.translate(it.name_key)
		if t != it.name_key:
			return t
	return id.replace("_", " ").capitalize()


static func all_items() -> Array:
	_ensure()
	return _items.values()


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_scan(ROOT)
	print("[itens] %d definições carregadas" % _items.size())


static func _scan(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry: String = dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full: String = path.path_join(entry)
			if dir.current_is_dir():
				_scan(full)
			else:
				var f: String = entry
				if f.ends_with(".remap"):
					f = f.trim_suffix(".remap")
					full = full.trim_suffix(".remap")
				if f.ends_with(".tres") or f.ends_with(".res"):
					var res := load(full)
					if res is ItemData and res.id != "":
						_items[res.id] = res
		entry = dir.get_next()
	dir.list_dir_end()
