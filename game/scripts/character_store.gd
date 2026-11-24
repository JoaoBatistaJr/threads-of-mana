class_name CharacterStore
extends RefCounted

# Slots de personagem salvos localmente (user://characters.json).
# Por enquanto só o nome; com contas online isso passa a ficar no servidor.

const PATH := "user://characters.json"


static func clean(raw: String) -> String:
	var n := raw.strip_edges()
	if n.length() < Const.NAME_MIN or n.length() > Const.NAME_MAX:
		return ""
	var re := RegEx.new()
	re.compile("^[\\p{L}0-9_-]+( [\\p{L}0-9_-]+)*$")
	return n if re.search(n) != null else ""


static func load_slots() -> Array:
	var slots: Array = []
	slots.resize(Const.SLOT_COUNT)
	slots.fill("")
	if FileAccess.file_exists(PATH):
		var data = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if typeof(data) == TYPE_DICTIONARY and data.get("slots") is Array:
			var saved: Array = data["slots"]
			for i in mini(Const.SLOT_COUNT, saved.size()):
				if typeof(saved[i]) == TYPE_STRING:
					slots[i] = clean(saved[i])
	return slots


static func save_slots(slots: Array) -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		push_warning("Não foi possível salvar personagens")
		return
	f.store_string(JSON.stringify({"slots": slots}))
	f.close()
