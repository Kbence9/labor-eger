class_name MazeGen
extends RefCounted
## Véletlen labirintus a szerkesztőhöz és a nyitó animációhoz.
## Mélységi bejárás (tökéletes labirintus: bármely két cella között pontosan egy út),
## utána néhány extra nyitás, hogy legyenek hurkok is. Node-független.


## A pálya falait újragenerálja. Az objektumok maradnak; ha nincs Start/Kijárat, lerakja őket.
## loops: a cellák hányad részénél nyisson pluszban egy falat (0 = tökéletes labirintus).
static func carve(L: LevelData, seed: int, loops: float = 0.08) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	L.open.clear()
	L.breakable.clear()
	var visited := {}
	var first := Vector2i(rng.randi_range(0, L.cols - 1), rng.randi_range(0, L.rows - 1))
	var stack: Array[Vector2i] = [first]
	visited[first] = true
	while not stack.is_empty():
		var c: Vector2i = stack[stack.size() - 1]
		var nbs: Array[Vector2i] = []
		for d in LevelData.DIR_ORDER:
			var n: Vector2i = c + LevelData.DIRS[d]
			if L.in_bounds(n) and not visited.has(n):
				nbs.append(n)
		if nbs.is_empty():
			stack.pop_back()
			continue
		var nxt: Vector2i = nbs[rng.randi() % nbs.size()]
		L.open[LevelData.ek(c, nxt)] = true
		visited[nxt] = true
		stack.append(nxt)
	var extra := int(round(L.cols * L.rows * loops))
	for i in extra:
		var c2 := Vector2i(rng.randi_range(0, L.cols - 1), rng.randi_range(0, L.rows - 1))
		var d2: String = LevelData.DIR_ORDER[rng.randi() % 4]
		var n2: Vector2i = c2 + LevelData.DIRS[d2]
		if L.in_bounds(n2):
			L.open[LevelData.ek(c2, n2)] = true
	var has_s := false
	var has_e := false
	for k in L.objects:
		has_s = has_s or L.objects[k] == "S"
		has_e = has_e or L.objects[k] == "E"
	if not has_s:
		L.objects[Vector2i(0, L.rows - 1)] = "S"
	if not has_e:
		L.objects[Vector2i(L.cols - 1, 0)] = "E"
	L.rebuild()


## Minden él fal (true) vagy minden él nyitott (false). Az objektumok maradnak.
static func fill(L: LevelData, walls: bool) -> void:
	L.open.clear()
	L.breakable.clear()
	if not walls:
		for y in L.rows:
			for x in L.cols:
				var c := Vector2i(x, y)
				if x + 1 < L.cols:
					L.open[LevelData.ek(c, c + Vector2i(1, 0))] = true
				if y + 1 < L.rows:
					L.open[LevelData.ek(c, c + Vector2i(0, 1))] = true
	L.rebuild()


## Zsákutcák (pontosan egy nyitott szomszéd), a Start és a Kijárat kivételével.
static func dead_ends(L: LevelData) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in L.rows:
		for x in L.cols:
			var c := Vector2i(x, y)
			if c == L.start or c == L.exit_cell:
				continue
			var n := 0
			for d in LevelData.DIR_ORDER:
				if L.edge_kind(c, c + LevelData.DIRS[d]) == "open":
					n += 1
			if n == 1:
				out.append(c)
	return out
