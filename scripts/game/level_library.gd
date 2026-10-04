class_name LevelLibrary
extends RefCounted
## Pályák listázása, betöltése, mentése, sorrendje, másolása, törlése.
## - res://levels  : beépített pályák (a repóban). Szerkesztőből futtatva (F5) ide ment.
## - user://levels : a telefonon/böngészőben szerkesztett pályák (felülírják az azonos nevű beépítettet).
## - order.json    : a pályák sorrendje (fájlnevek listája). Ami nincs benne, a végére kerül név szerint.

const BUILTIN_DIR := "res://levels"
const USER_DIR := "user://levels"
const ORDER_FILE := "order.json"


static func can_write_builtin() -> bool:
	return OS.has_feature("editor")


static func write_dir() -> String:
	return BUILTIN_DIR if can_write_builtin() else USER_DIR


static func _json_files(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".json") and f != ORDER_FILE:
			out.append(f)
	return out


static func _read_order(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	var txt := FileAccess.get_file_as_string(dir + "/" + ORDER_FILE)
	if txt == "":
		return out
	var data: Variant = JSON.parse_string(txt)
	if typeof(data) == TYPE_DICTIONARY:
		for f in data.get("order", []):
			out.append(str(f))
	return out


## Az érvényes sorrend: az eszközön mentett (ha van), különben a repóbeli.
func order() -> PackedStringArray:
	var o := _read_order(USER_DIR) if not can_write_builtin() else PackedStringArray()
	if o.is_empty():
		o = _read_order(BUILTIN_DIR)
	return o


## [{file, path, name, source}] a sorrend szerint. source: "builtin" | "user" | "modified"
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
	var files: Array = []
	for f in order():
		if by_file.has(f) and not files.has(f):
			files.append(f)
	var rest: Array = []
	for f in by_file.keys():
		if not files.has(f):
			rest.append(f)
	rest.sort()
	files.append_array(rest)
	var out: Array = []
	for f in files:
		var e: Dictionary = by_file[f]
		var L := load_level(e["path"])
		e["name"] = L.title if L else f
		out.append(e)
	return out


func files() -> PackedStringArray:
	var out := PackedStringArray()
	for e in list():
		out.append(e["file"])
	return out


func load_level(path: String) -> LevelData:
	var txt := FileAccess.get_file_as_string(path)
	if txt == "":
		return null
	return parse(txt)


## JSON szövegből pálya (vagy null, ha nem pálya).
static func parse(txt: String) -> LevelData:
	var j := JSON.new()
	if j.parse(txt.strip_edges()) != OK:
		return null
	var data: Variant = j.data
	if typeof(data) != TYPE_DICTIONARY or not data.has("size"):
		return null
	return LevelData.from_dict(data)


## Visszaadja a mentett fájl útvonalát (vagy "" hiba esetén).
func save_level(L: LevelData, file: String) -> String:
	var dir := write_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir + "/" + file
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(to_json(L))
	f.close()
	return path


func save_order(file_list: PackedStringArray) -> bool:
	var dir := write_dir()
	DirAccess.make_dir_recursive_absolute(dir)
	var f := FileAccess.open(dir + "/" + ORDER_FILE, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify({"order": Array(file_list)}, "  ", false) + "\n")
	f.close()
	return true


## Egy pálya mozgatása a sorrendben (delta: -1 fel, +1 le).
func move(file: String, delta: int) -> bool:
	var fl := files()
	var i := fl.find(file)
	var j := i + delta
	if i < 0 or j < 0 or j >= fl.size():
		return false
	fl[i] = fl[j]
	fl[j] = file
	return save_order(fl)


## Másolat a pályáról közvetlenül az eredeti után. Visszaadja az új fájlnevet ("" hiba).
func duplicate_level(file: String, L: LevelData) -> String:
	var copy := L.copy()
	copy.title = L.title + " (másolat)"
	var nf := next_file_name()
	if save_level(copy, nf) == "":
		return ""
	var fl := files()
	fl.remove_at(fl.find(nf))
	var i := fl.find(file)
	fl.insert(i + 1 if i >= 0 else fl.size(), nf)
	save_order(fl)
	return nf


## Törlés. Telefonon csak a saját/módosított pálya törölhető (a módosításnál a beépített tér vissza).
## Visszaad: "" siker, különben a hiba szövege.
func delete_level(file: String) -> String:
	var dir := write_dir()
	var path := dir + "/" + file
	if not FileAccess.file_exists(path):
		return "Ez beépített pálya, telefonon nem törölhető."
	var err := DirAccess.remove_absolute(path)
	if err != OK:
		return "A törlés nem sikerült (%d)." % err
	var fl := files()
	save_order(fl)
	return ""


static func to_json(L: LevelData) -> String:
	return JSON.stringify(L.to_dict(), "  ", false) + "\n"


func next_file_name() -> String:
	var used := {}
	for f in _json_files(BUILTIN_DIR):
		used[f] = true
	for f in _json_files(USER_DIR):
		used[f] = true
	var prefix := "level_" if can_write_builtin() else "sajat_"
	for i in range(1, 1000):
		var f := "%s%02d.json" % [prefix, i]
		if not used.has(f):
			return f
	return "%s%d.json" % [prefix, Time.get_unix_time_from_system()]
