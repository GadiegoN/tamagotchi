extends RefCounted
const State = preload("res://scripts/pet_state.gd")
const PATH = "user://pet_v1.json"
var notice := ""

func load_state(now: float, offset: int, path: String = PATH) -> Dictionary:
	notice = ""
	for candidate in [path, path + ".bak"]:
		if not FileAccess.file_exists(candidate):
			continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(candidate)) != OK:
			continue
		var state := State.validate(parser.data, now, offset)
		if not state.is_empty():
			if candidate != path:
				notice = "Save principal inválido; cópia de segurança recuperada."
			return state
	if FileAccess.file_exists(path):
		notice = "Save inválido preservado. Uma nova rotina foi iniciada."
		DirAccess.copy_absolute(path, path + ".invalid")
	return State.fresh(now, offset)

func save_state(state: Dictionary, path: String = PATH) -> bool:
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(state))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	if FileAccess.file_exists(path):
		# A recovered session must not overwrite its good backup with a corrupt primary.
		var previous := JSON.new()
		if previous.parse(FileAccess.get_file_as_string(path)) == OK and not State.validate(previous.data, state.updated_at, int(state.timezone)).is_empty():
			if DirAccess.copy_absolute(path, path + ".bak") != OK:
				return false
	return DirAccess.rename_absolute(path + ".tmp", path) == OK
