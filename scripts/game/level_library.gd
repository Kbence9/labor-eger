class_name LevelLibrary
extends RefCounted
## Pályák listázása, betöltése, mentése.
## - res://levels  : beépített pályák (a repóban). Szerkesztőből futtatva ide ment.
## - user://levels : a telefonon/böngészőben szerkesztett pályák (felülírják az azonos nevű beépítettet).

const BUILTIN_DIR := "res://levels"
const USER_DIR := "user://levels"


static func can_write_builtin() -> bool:
	return OS.has_feature("editor")


static func _json_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json"):
			out.append(f)
	return out


## [{file, path, name, source}] fájlnév szerint rendezve. source: "builtin" | "user" | "modified"
func list() -> Array:
	var by_file := {}
	for f in _json_files(BUILTIN_DIR):
		by_file[f] = {"file": f, "path": BUILTIN_DIR + "/" + f, "source": "builtin"}
	for f in _json_files(USER_DIR):
		if by_file.has(f):
			by_file[f]["path"] = USER_DIR + "/" + f
			by_file[f]["source"] = "modified"
		else:
			by_file[f] = {"file": f, "path": USER_DIR + "/" + f, "source": "user"}
	var files: Array = by_file.keys()
	files.sort()
	var out: Array = []
	for f in files:
		var e: Dictionary = by_file[f]
		var L := load_level(e["path"])
		e["name"] = L.title if L else f
		out.append(e)
	return out


func load_level(path: String) -> LevelData:
	var txt := FileAccess.get_file_as_string(path)
	if txt == "":
		return null
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) != TYPE_DICTIONARY:
		return null
	return LevelData.from_dict(data)


## Visszaadja a mentett fájl útvonalát (vagy "" hiba esetén).
func save_level(L: LevelData, file: String) -> String:
	var dir := BUILTIN_DIR if can_write_builtin() else USER_DIR
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/" + file
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(to_json(L))
	f.close()
	return path


static func to_json(L: LevelData) -> String:
	return JSON.stringify(L.to_dict(), "  ", false) + "\n"


func next_file_name() -> String:
	var used := {}
	for e in list():
		used[e["file"]] = true
	var prefix := "level_" if can_write_builtin() else "sajat_"
	for i in range(1, 1000):
		var f := "%s%02d.json" % [prefix, i]
		if not used.has(f):
			return f
	return "%s%d.json" % [prefix, Time.get_unix_time_from_system()]
