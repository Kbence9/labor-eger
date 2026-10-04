class_name Solver
extends RefCounted
## Szélességi keresés egylépéses mozgásokkal. Visszaad egy legrövidebb irány-listát,
## vagy üres tömböt, ha a pálya nem megoldható (vagy túl nagy az állapottér).

static func solve(L: LevelData, from: GameState = null, max_states: int = 300000) -> Array[String]:
	var none: Array[String] = []
	var s0: GameState = from.copy() if from != null else GameState.from_level(L)
	if s0.won or s0.dead != "":
		return none
	var queue: Array = [[s0, none]]
	var head := 0
	var seen := {s0.state_key(): true}
	while head < queue.size():
		var item: Array = queue[head]
		head += 1
		var s: GameState = item[0]
		var path: Array[String] = item[1]
		for d in LevelData.DIR_ORDER:
			var n := s.copy()
			var ev := n.step(L, d)
			if ev.size() == 1 and (ev[0]["t"] == "blocked" or ev[0]["t"] == "bonk"):
				continue
			if n.dead != "":
				continue
			var np: Array[String] = path.duplicate()
			np.append(d)
			if n.won:
				return np
			var k := n.state_key()
			if seen.has(k):
				continue
			seen[k] = true
			if seen.size() > max_states:
				return none
			queue.append([n, np])
	return none


## A megoldás során bejárt cellák (teleportot is követve) – a szerkesztő útvonal-rajzához.
## Vector2i(-1, -1) jelzi a teleport miatti szakadást.
static func path_cells(L: LevelData, path: Array[String]) -> Array[Vector2i]:
	var s := GameState.from_level(L)
	var out: Array[Vector2i] = [s.pos]
	for d in path:
		var ev := s.step(L, d)
		for e in ev:
			if e["t"] == "teleport":
				out.append(e["from"])
				out.append(Vector2i(-1, -1))  # szakadás: a vonal nem köti össze a két portált
		if out[out.size() - 1] != s.pos:
			out.append(s.pos)
	return out
