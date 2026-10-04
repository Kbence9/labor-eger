class_name GameState
extends RefCounted
## Egy futás állapota és a lépés-szabályok (docs/GDD.md). Node-független.

var pos: Vector2i
var held: String = ""          # "" | "H" | "W"
var items: Dictionary = {}     # Vector2i -> "H" | "W"
var fires: Dictionary = {}     # Vector2i -> true
var cracks: Dictionary = {}    # Vector2i -> "ok" | "hole"
var traps: Dictionary = {}     # Vector2i -> true
var exit_cell: Vector2i
var broken: Dictionary = {}    # él-kulcs -> true
var dead: String = ""          # "" | "burn" | "fall" | "trap" | "quit"
var won: bool = false


static func from_level(L: LevelData) -> GameState:
	var s := GameState.new()
	s.pos = L.start
	s.exit_cell = L.exit_cell
	for c in L.objects:
		var v: String = L.objects[c]
		match v:
			"H", "W":
				s.items[c] = v
			"F":
				s.fires[c] = true
			"C":
				s.cracks[c] = "ok"
			"T":
				s.traps[c] = true
	return s


func copy() -> GameState:
	var s := GameState.new()
	s.pos = pos
	s.held = held
	s.items = items.duplicate()
	s.fires = fires.duplicate()
	s.cracks = cracks.duplicate()
	s.traps = traps
	s.exit_cell = exit_cell
	s.broken = broken.duplicate()
	s.dead = dead
	s.won = won
	return s


## "open" | "wall" | "brk" a c cellából dir irányba
func edge(L: LevelData, c: Vector2i, dir: String) -> String:
	var n: Vector2i = c + LevelData.DIRS[dir]
	if not L.in_bounds(c) or not L.in_bounds(n):
		return "wall"
	var k := LevelData.ek(c, n)
	if L.open.has(k) or broken.has(k):
		return "open"
	if L.breakable.has(k):
		return "brk"
	return "wall"


## Egy lépés-kísérlet. Módosítja az állapotot, eseménylistát ad vissza.
func step(L: LevelData, dir: String) -> Array:
	var ev: Array = []
	if dead != "" or won:
		return ev
	var t := edge(L, pos, dir)
	if t == "wall":
		ev.append({"t": "blocked"})
		return ev
	var n: Vector2i = pos + LevelData.DIRS[dir]
	if t == "brk":
		if held == "H":
			broken[LevelData.ek(pos, n)] = true
			ev.append({"t": "break", "cell": pos, "dir": dir})
		else:
			ev.append({"t": "bonk"})
		return ev
	if cracks.get(pos, "") == "ok":
		cracks[pos] = "hole"
		ev.append({"t": "crumble", "cell": pos})
	pos = n
	ev.append({"t": "move"})
	_enter(L, ev, false)
	return ev


func _enter(L: LevelData, ev: Array, via_portal: bool) -> void:
	if cracks.get(pos, "") == "hole":
		dead = "fall"
		ev.append({"t": "die", "why": "fall"})
		return
	if fires.has(pos):
		if held == "W":
			fires.erase(pos)
			held = ""
			ev.append({"t": "douse", "cell": pos})
		else:
			dead = "burn"
			ev.append({"t": "die", "why": "burn"})
			return
	if traps.has(pos):
		dead = "trap"
		ev.append({"t": "die", "why": "trap"})
		return
	if items.has(pos):
		var got: String = items[pos]
		var left := held
		if left != "":
			items[pos] = left
		else:
			items.erase(pos)
		held = got
		ev.append({"t": "swap" if left != "" else "pick", "got": got, "left": left})
	if pos == exit_cell:
		won = true
		ev.append({"t": "win"})
		return
	if cracks.get(pos, "") == "ok":
		ev.append({"t": "oncrack"})
	if not via_portal and L.portal_pair.has(pos):
		var from := pos
		pos = L.portal_pair[pos]
		ev.append({"t": "teleport", "from": from})
		_enter(L, ev, true)


func state_key() -> String:
	return "%s/%s/%s/%s/%s/%s" % [LevelData.ck(pos), held, _dk(items), _dk(fires), _dk(cracks), _dk(broken)]


static func _dk(d: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in d:
		parts.append(str(k) + "=" + str(d[k]))
	parts.sort()
	return ",".join(parts)
