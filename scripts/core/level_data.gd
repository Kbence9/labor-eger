class_name LevelData
extends RefCounted
## Egy pálya adatai: rács, nyitott élek (minden más él fal), törhető falak, objektumok.
## Node-független, headless tesztelhető. JSON formátum: docs/GDD.md

const DIRS := {"U": Vector2i(0, -1), "D": Vector2i(0, 1), "L": Vector2i(-1, 0), "R": Vector2i(1, 0)}
const DIR_ORDER: Array[String] = ["U", "D", "L", "R"]
const MIN_COLS := 4
const MAX_COLS := 12
const MIN_ROWS := 4
const MAX_ROWS := 16

var id: int = 0
var title: String = "Új pálya"
var cols: int = 7
var rows: int = 9
var open: Dictionary = {}       # él-kulcs -> true
var breakable: Dictionary = {}  # él-kulcs -> true
var objects: Dictionary = {}    # Vector2i -> String (nagybetűs kód)
var start: Vector2i = Vector2i(-1, -1)
var exit_cell: Vector2i = Vector2i(-1, -1)
var portal_pair: Dictionary = {}  # Vector2i -> Vector2i
var errors: Array[String] = []


static func ck(c: Vector2i) -> String:
	return "%d,%d" % [c.x, c.y]


static func parse_cell(s: String) -> Vector2i:
	var p := s.strip_edges().split(",")
	return Vector2i(int(p[0]), int(p[1]))


static func ek(a: Vector2i, b: Vector2i) -> String:
	if a.x < b.x or (a.x == b.x and a.y < b.y):
		return ck(a) + "|" + ck(b)
	return ck(b) + "|" + ck(a)


static func parse_edge(s: String) -> Array[Vector2i]:
	var p := s.split("|")
	var out: Array[Vector2i] = [parse_cell(p[0]), parse_cell(p[1])]
	return out


static func from_dict(d: Dictionary) -> LevelData:
	var L := LevelData.new()
	L.id = int(d.get("id", 0))
	L.title = str(d.get("name", "Névtelen"))
	var size: Array = d.get("size", [7, 9])
	L.cols = int(size[0])
	L.rows = int(size[1])
	for p in d.get("paths", []):
		var pts := str(p).strip_edges().split(" ", false)
		for i in range(1, pts.size()):
			var a := parse_cell(pts[i - 1])
			var b := parse_cell(pts[i])
			if absi(a.x - b.x) + absi(a.y - b.y) != 1:
				L.errors.append("Nem szomszédos cellák: %s -> %s" % [pts[i - 1], pts[i]])
				continue
			L.open[ek(a, b)] = true
	for e in d.get("edges", []):
		var ab := parse_edge(str(e))
		L.open[ek(ab[0], ab[1])] = true
	for e in d.get("breakable", []):
		var ab := parse_edge(str(e))
		var k := ek(ab[0], ab[1])
		L.open.erase(k)
		L.breakable[k] = true
	var objs: Dictionary = d.get("objects", {})
	for k in objs:
		L.objects[parse_cell(str(k))] = str(objs[k]).to_upper()
	L.rebuild()
	return L


static func new_empty(c: int = 7, r: int = 9) -> LevelData:
	var L := LevelData.new()
	L.cols = c
	L.rows = r
	for y in r:
		for x in c:
			var cell := Vector2i(x, y)
			if x + 1 < c:
				L.open[ek(cell, cell + Vector2i(1, 0))] = true
			if y + 1 < r:
				L.open[ek(cell, cell + Vector2i(0, 1))] = true
	L.objects[Vector2i(0, r - 1)] = "S"
	L.objects[Vector2i(c - 1, 0)] = "E"
	L.rebuild()
	return L


func to_dict() -> Dictionary:
	var edges: Array = open.keys()
	edges.sort()
	var brk: Array = breakable.keys()
	brk.sort()
	var objs := {}
	var keys: Array = objects.keys()
	keys.sort()
	for c in keys:
		objs[ck(c)] = objects[c]
	return {"id": id, "name": title, "size": [cols, rows], "edges": edges, "breakable": brk, "objects": objs}


func copy() -> LevelData:
	var L := LevelData.from_dict(to_dict())
	return L


func rebuild() -> void:
	start = Vector2i(-1, -1)
	exit_cell = Vector2i(-1, -1)
	portal_pair.clear()
	var portals := {}
	for c in objects:
		var v: String = objects[c]
		if v == "S":
			start = c
		elif v == "E":
			exit_cell = c
		elif v == "A" or v == "B":
			if not portals.has(v):
				portals[v] = []
			portals[v].append(c)
	for pid in portals:
		var lst: Array = portals[pid]
		if lst.size() == 2:
			portal_pair[lst[0]] = lst[1]
			portal_pair[lst[1]] = lst[0]


## Hibalista; üres = a pálya játszható.
func validate() -> Array[String]:
	var out: Array[String] = errors.duplicate()
	if start.x < 0:
		out.append("Nincs start.")
	if exit_cell.x < 0:
		out.append("Nincs kijárat.")
	var counts := {}
	for c in objects:
		if not in_bounds(c):
			out.append("Objektum a pályán kívül: %s" % ck(c))
		var v: String = objects[c]
		counts[v] = counts.get(v, 0) + 1
	for pid in ["A", "B"]:
		var n: int = counts.get(pid, 0)
		if n != 0 and n != 2:
			out.append("A(z) %s portálnak pontosan 2 vége kell (most %d)." % [pid, n])
	return out


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


## "open" | "wall" | "brk" két szomszédos cella között (pályán kívül: "wall")
func edge_kind(a: Vector2i, b: Vector2i) -> String:
	if not in_bounds(a) or not in_bounds(b):
		return "wall"
	var k := ek(a, b)
	if open.has(k):
		return "open"
	if breakable.has(k):
		return "brk"
	return "wall"


func set_edge(a: Vector2i, b: Vector2i, kind: String) -> void:
	if not in_bounds(a) or not in_bounds(b):
		return
	var k := ek(a, b)
	open.erase(k)
	breakable.erase(k)
	if kind == "open":
		open[k] = true
	elif kind == "brk":
		breakable[k] = true


func resize(nc: int, nr: int) -> void:
	nc = clampi(nc, MIN_COLS, MAX_COLS)
	nr = clampi(nr, MIN_ROWS, MAX_ROWS)
	var old_open := open
	var old_brk := breakable
	var oc := cols
	var orr := rows
	cols = nc
	rows = nr
	open = {}
	breakable = {}
	for y in rows:
		for x in cols:
			var c := Vector2i(x, y)
			for n: Vector2i in [c + Vector2i(1, 0), c + Vector2i(0, 1)]:
				if not in_bounds(n):
					continue
				var k := ek(c, n)
				var inside_old := c.x < oc and c.y < orr and n.x < oc and n.y < orr
				if not inside_old or old_open.has(k):
					open[k] = true
				elif old_brk.has(k):
					breakable[k] = true
	for c in objects.keys():
		if not in_bounds(c):
			objects.erase(c)
	rebuild()
