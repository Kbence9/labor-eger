class_name Progress
extends RefCounted
## A játékos haladása az eszközön (user://progress.json): teljesített pályák, legjobb idő,
## halálok pályánként és összesen. Az alany sorszáma = összes halál + 1.

const PATH := "user://progress.json"

var levels := {}        # fájlnév -> {"done": bool, "best": float (mp, -1 ha nincs), "deaths": int}
var total_deaths := 0
var save_path := PATH


## Betöltés. Sérült vagy kézzel elrontott fájlnál sem áll le: ami nem értelmezhető, azt kihagyja.
static func load_from(path: String = PATH) -> Progress:
	var p := Progress.new()
	p.save_path = path
	var txt := FileAccess.get_file_as_string(path)
	if txt == "":
		return p
	var j := JSON.new()
	if j.parse(txt) != OK:
		return p
	var d: Variant = j.data
	if typeof(d) != TYPE_DICTIONARY:
		return p
	p.total_deaths = maxi(0, _num(d.get("total_deaths", 0), 0))
	var lv: Variant = d.get("levels", {})
	if typeof(lv) != TYPE_DICTIONARY:
		return p
	for k in lv:
		var e: Variant = lv[k]
		if typeof(e) != TYPE_DICTIONARY:
			continue
		p.levels[str(k)] = {"done": typeof(e.get("done")) == TYPE_BOOL and e.get("done"), "best": float(_num(e.get("best", -1.0), -1.0, true)), "deaths": maxi(0, _num(e.get("deaths", 0), 0))}
	return p


static func _num(v: Variant, fallback: Variant, as_float: bool = false) -> Variant:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return fallback
	return float(v) if as_float else int(v)


func save() -> void:
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"total_deaths": total_deaths, "levels": levels}, "  ") + "\n")
	f.close()


func _entry(file: String) -> Dictionary:
	if not levels.has(file):
		levels[file] = {"done": false, "best": -1.0, "deaths": 0}
	return levels[file]


func record_death(file: String) -> void:
	total_deaths += 1
	_entry(file)["deaths"] += 1
	save()


func record_win(file: String, seconds: float) -> void:
	var e := _entry(file)
	e["done"] = true
	if e["best"] < 0.0 or seconds < e["best"]:
		e["best"] = seconds
	save()


func is_done(file: String) -> bool:
	return levels.has(file) and levels[file]["done"]


func best(file: String) -> float:
	return levels[file]["best"] if levels.has(file) else -1.0


func deaths(file: String) -> int:
	return levels[file]["deaths"] if levels.has(file) else 0


func subject_no() -> int:
	return total_deaths + 1


## Az első még nem teljesített pálya indexe a listában (ha mind kész: az utolsó; ha üres: -1).
func next_index(file_list: PackedStringArray) -> int:
	for i in file_list.size():
		if not is_done(file_list[i]):
			return i
	return file_list.size() - 1


func has_any() -> bool:
	return total_deaths > 0 or not levels.is_empty()
