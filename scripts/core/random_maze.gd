class_name RandomMaze
extends RefCounted
## Véletlen kísérlet: seedből generált, játszható labirintus nehézségi szinttel. Node-független.
## Ugyanaz a (szint, seed) pár mindig ugyanazt a pályát adja, így a seed megosztható,
## és a „nap labirintusa” (seed = ÉÉÉÉHHNN) mindenkinek ugyanaz.
##
## Építés: MazeGen.carve (mélységi bejárás + néhány hurok) → a Start a labirintus egyik
## „végén”, a Kijárat a tőle legtávolabbi cellában (két szélességi keresés) → a magasabb
## szinteken sajt-csapda a zsákutcák végén. Zsákutca sosem esik a legrövidebb útra, ezért a
## csapda nem teheti megoldhatatlanná; a megoldó ezt minden pályánál ellenőrzi is.

const ORDER: Array[String] = ["konnyu", "kozepes", "nehez"]
const LEVELS := {
	"konnyu": {"name": "Könnyű", "size": Vector2i(5, 6), "loops": 0.10, "traps": 0},
	"kozepes": {"name": "Közepes", "size": Vector2i(7, 9), "loops": 0.06, "traps": 2},
	"nehez": {"name": "Nehéz", "size": Vector2i(10, 13), "loops": 0.03, "traps": 5},
}
const DAILY := "kozepes"
const MAX_SEED := 999999


static func is_valid(diff: String) -> bool:
	return LEVELS.has(diff)


static func diff_name(diff: String) -> String:
	return LEVELS[diff]["name"] if LEVELS.has(diff) else diff


## Új véletlen seed (1..MAX_SEED), hogy rövid és begépelhető maradjon.
static func new_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	return rng.randi_range(1, MAX_SEED)


## A nap seedje: ÉÉÉÉHHNN (pl. 20261102). date: Time.get_date_dict_from_system() alakú.
static func daily_seed(date: Dictionary) -> int:
	return int(date["year"]) * 10000 + int(date["month"]) * 100 + int(date["day"])


## A haladásban (Progress) ezen a kulcson él a szint legjobb ideje és halálai.
static func progress_key(diff: String, daily: bool = false, seed: int = 0) -> String:
	return "napi:%d" % seed if daily else "veletlen:" + diff


static func build(diff: String, seed: int) -> LevelData:
	var cfg: Dictionary = LEVELS[diff] if LEVELS.has(diff) else LEVELS["kozepes"]
	var size: Vector2i = cfg["size"]
	var L := LevelData.new_empty(size.x, size.y)
	L.objects.clear()
	L.id = seed
	L.title = "%s #%d" % [cfg["name"], seed]
	MazeGen.carve(L, seed, cfg["loops"])
	L.objects.clear()
	# Start: a véletlen cellától legtávolabbi pont; Kijárat: a Starttól legtávolabbi.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed * 7919 + 13
	var any := Vector2i(rng.randi_range(0, L.cols - 1), rng.randi_range(0, L.rows - 1))
	var start := farthest(L, any)
	var exit := farthest(L, start)
	L.objects[start] = "S"
	L.objects[exit] = "E"
	L.rebuild()
	var ends := MazeGen.dead_ends(L)
	for i in mini(int(cfg["traps"]), ends.size()):
		var j := rng.randi_range(i, ends.size() - 1)
		var c := ends[j]
		ends[j] = ends[i]
		ends[i] = c
		L.objects[c] = "T"
	L.rebuild()
	return L


## A from cellától (nyitott éleken) legtávolabbi cella; holtversenyben az első a bejárási sorrendben.
static func farthest(L: LevelData, from: Vector2i) -> Vector2i:
	var dist := {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	var best := from
	while head < queue.size():
		var c := queue[head]
		head += 1
		if dist[c] > dist[best]:
			best = c
		for d in LevelData.DIR_ORDER:
			var n: Vector2i = c + LevelData.DIRS[d]
			if not dist.has(n) and L.edge_kind(c, n) == "open":
				dist[n] = dist[c] + 1
				queue.append(n)
	return best
