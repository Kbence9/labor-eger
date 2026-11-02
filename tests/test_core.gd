extends SceneTree
## Headless teszt: godot --headless --path . -s tests/test_core.gd
## Minden pálya érvényes és megoldható; JSON oda-vissza alakítás veszteségmentes;
## labirintus-generátor, visszavonás, haladás-mentés, hibás bemenetek, véletlen kísérlet (szint + seed).

var fails := 0
var finished := false
var guard: Logger = preload("res://tests/error_guard.gd").new()


func _ok(cond: bool, msg: String) -> void:
	print(("OK    " if cond else "HIBA  ") + msg)
	if not cond:
		fails += 1


func _init() -> void:
	OS.add_logger(guard)
	_run_tests()
	finished = true
	_finish()


## Ha egy script-hiba megszakította a tesztet, az _init() nem jut el a quit()-ig: az első
## képkockán itt lépünk ki 1-es kóddal (nem a timeout állítja le).
func _process(_delta: float) -> bool:
	if not finished:
		print("HIBA  a teszt script-hibával megszakadt: %s" % guard.first)
		fails += 1
		finished = true
		_finish()
	return true


func _finish() -> void:
	if guard.count > 0:
		print("HIBA  %d script-hiba futás közben, az első: %s" % [guard.count, guard.first])
		fails += 1
	print("FAILS=%d" % fails)
	OS.remove_logger(guard)
	quit(1 if fails > 0 else 0)


func _run_tests() -> void:
	var dir := "res://levels"
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".json") or f == LevelLibrary.ORDER_FILE:
			continue
		var L := LevelLibrary.parse(FileAccess.get_file_as_string(dir + "/" + f))
		if L == null:
			_ok(false, "%s nem olvasható" % f)
			continue
		var errs := L.validate()
		var sol := Solver.solve(L)
		var L2 := LevelData.from_dict(L.to_dict())
		var same := L2.open.size() == L.open.size() and L2.objects.size() == L.objects.size() and L2.breakable.size() == L.breakable.size()
		_ok(errs.is_empty() and sol.size() > 0 and same, "%s  hibák=%s  megoldás=%d lépés  roundtrip=%s" % [f, str(errs), sol.size(), same])

	# szerkesztő-műveletek
	var E := LevelData.new_empty(5, 5)
	E.set_edge(Vector2i(0, 4), Vector2i(1, 4), "wall")
	E.set_edge(Vector2i(0, 4), Vector2i(0, 3), "brk")
	_ok(Solver.solve(E).is_empty(), "elzárt start: nem megoldható")
	E.objects[Vector2i(0, 0)] = "H"
	E.rebuild()
	_ok(Solver.solve(E).is_empty(), "kalapács elérhetetlen helyen: nem megoldható")
	E.resize(4, 6)
	_ok(E.validate() == ["Nincs kijárat."], "átméretezés levágja a kijáratot")

	# labirintus-generátor
	for sz: Vector2i in [Vector2i(4, 4), Vector2i(7, 9), Vector2i(12, 16)]:
		for seed in [1, 2, 3, 42]:
			var M := LevelData.new_empty(sz.x, sz.y)
			MazeGen.carve(M, seed, 0.0)
			var perfect: bool = M.open.size() == sz.x * sz.y - 1
			var solvable := not Solver.solve(M).is_empty()
			_ok(perfect and solvable and M.validate().is_empty(), "generált %dx%d seed=%d: tökéletes=%s megoldható=%s" % [sz.x, sz.y, seed, perfect, solvable])
	var M2 := LevelData.new_empty(7, 9)
	M2.objects.clear()
	MazeGen.carve(M2, 5, 0.1)
	_ok(M2.start.x >= 0 and M2.exit_cell.x >= 0, "generálás lerakja a startot és a kijáratot")
	MazeGen.fill(M2, true)
	_ok(M2.open.is_empty() and Solver.solve(M2).is_empty(), "minden él fal")
	MazeGen.fill(M2, false)
	_ok(M2.open.size() == 7 * 8 + 9 * 6, "minden él nyitott")

	# visszavonás / újra
	var H := EditHistory.new()
	var U := LevelData.new_empty(6, 6)
	var before := JSON.stringify(U.to_dict())
	H.record(U)
	U.set_edge(Vector2i(0, 0), Vector2i(1, 0), "wall")
	U.objects[Vector2i(3, 3)] = "F"
	var after := JSON.stringify(U.to_dict())
	var U2 := H.undo(U)
	_ok(JSON.stringify(U2.to_dict()) == before and H.can_redo(), "visszavonás visszaállítja az előző állapotot")
	var U3 := H.redo(U2)
	_ok(JSON.stringify(U3.to_dict()) == after and not H.can_redo(), "újra visszahozza a módosítást")
	_ok(H.redo(U3) == null, "nincs több újra")

	# haladás
	var path := "user://teszt_progress.json"
	DirAccess.remove_absolute(path)
	var P := Progress.load_from(path)
	P.record_death("level_01.json")
	P.record_death("level_01.json")
	P.record_win("level_01.json", 41.5)
	P.record_win("level_01.json", 50.0)
	var P2 := Progress.load_from(path)
	_ok(P2.total_deaths == 2 and P2.subject_no() == 3 and P2.is_done("level_01.json") and absf(P2.best("level_01.json") - 41.5) < 0.01, "haladás mentése és betöltése")
	_ok(P2.next_index(PackedStringArray(["level_01.json", "level_02.json"])) == 1, "folytatás a következő nem teljesített pályán")
	DirAccess.remove_absolute(path)
	_ok(LevelLibrary.parse("nem json") == null and LevelLibrary.parse("{\"a\":1}") == null, "beillesztés: a nem-pálya szöveget elutasítja")

	# hibás / kézzel elrontott pálya-JSON: nem állhat le script-hibával
	for bad in ['{"size": 5}', '{"size": ["a", 3]}', '{"size": [0, 0]}', '{"size": [99, 9]}', '[1, 2]']:
		_ok(LevelLibrary.parse(bad) == null, "beillesztés: elutasítva %s" % bad)
	var B := LevelLibrary.parse('{"size": [5, 5], "edges": ["x", "0,0|1,0", "0,0|3,3", 7], "breakable": "nem lista", "paths": ["0,1 1"], "objects": {"q": "S", "0,4": "s", "4,0": "E"}}')
	_ok(B != null and B.open.size() == 1 and B.start == Vector2i(0, 4) and B.exit_cell == Vector2i(4, 0), "hibás bejegyzések kihagyva, a jók betöltve")
	_ok(B != null and B.validate().size() == 5, "a kihagyott bejegyzések hibaként jelennek meg (%s)" % (str(B.validate()) if B else "-"))
	_ok(LevelData.new_empty(3, 9).validate().size() == 1, "a túl kicsi pálya méret-hibát kap")

	# sérült haladás-fájl: nem dőlhet el tőle a játék
	var bad_path := "user://teszt_progress_hibas.json"
	for txt in ['nem json', '[1,2]', '{"levels": [1, 2], "total_deaths": "x"}', '{"levels": {"a.json": 3, "b.json": {"done": "igen", "best": "gyors", "deaths": -4}}, "total_deaths": 2}']:
		var f := FileAccess.open(bad_path, FileAccess.WRITE)
		f.store_string(txt)
		f.close()
		var BP := Progress.load_from(bad_path)
		_ok(BP != null and BP.next_index(PackedStringArray(["a.json"])) == 0, "sérült haladás betölthető: %s" % txt)
	var BP2 := Progress.load_from(bad_path)
	_ok(BP2.total_deaths == 2 and not BP2.is_done("b.json") and BP2.best("b.json") < 0.0 and BP2.deaths("b.json") == 0 and not BP2.levels.has("a.json"), "sérült haladás: az értelmezhető rész megmarad")
	DirAccess.remove_absolute(bad_path)

	# véletlen kísérlet: nehézségi szint + seed
	for diff in RandomMaze.ORDER:
		var cfg: Dictionary = RandomMaze.LEVELS[diff]
		for seed in [1, 7, 123456, 20261102]:
			var R := RandomMaze.build(diff, seed)
			var R2 := RandomMaze.build(diff, seed)
			var same_seed := JSON.stringify(R.to_dict()) == JSON.stringify(R2.to_dict())
			var size_ok: bool = Vector2i(R.cols, R.rows) == cfg["size"]
			var traps := 0
			for c in R.objects:
				traps += 1 if R.objects[c] == "T" else 0
			var sol := Solver.solve(R)
			_ok(same_seed and size_ok and R.validate().is_empty() and not sol.is_empty() and traps == cfg["traps"] and R.start != R.exit_cell,
				"véletlen %s seed=%d: ugyanaz=%s méret=%dx%d csapda=%d megoldás=%d lépés" % [diff, seed, same_seed, R.cols, R.rows, traps, sol.size()])
	_ok(JSON.stringify(RandomMaze.build("kozepes", 1).to_dict()) != JSON.stringify(RandomMaze.build("kozepes", 2).to_dict()), "más seed: más labirintus")
	var Rk := RandomMaze.build("konnyu", 5)
	_ok(Solver.solve(Rk).size() >= Rk.cols + Rk.rows - 2 - 4, "a kijárat messze van a starttól (%d lépés)" % Solver.solve(Rk).size())
	_ok(RandomMaze.daily_seed({"year": 2026, "month": 11, "day": 2}) == 20261102, "a nap seedje: ÉÉÉÉHHNN")
	_ok(RandomMaze.progress_key("nehez") == "veletlen:nehez" and RandomMaze.progress_key("kozepes", true, 20261102) == "napi:20261102", "haladás-kulcsok")
	var s1 := RandomMaze.new_seed()
	_ok(s1 >= 1 and s1 <= RandomMaze.MAX_SEED, "új seed a tartományban")

	# rekord-szöveg a győzelmi lapon
	_ok(LabGame.is_record(10.0, -1.0) and LabGame.is_record(9.0, 10.0) and not LabGame.is_record(10.0, 10.0), "rekord: első idő és javítás számít, döntetlen nem")
	_ok(LabGame.record_text(9.0, 10.5).begins_with("Új rekord! Az előző: 0:10.5 (-1.5 mp)"), "rekord-szöveg: %s" % LabGame.record_text(9.0, 10.5))
	_ok(LabGame.record_text(12.0, 10.0) == "Rekord: 0:10.0 (+2.0 mp)", "lassabb futás: %s" % LabGame.record_text(12.0, 10.0))

	# kézzel beírt seed
	var ps := RandomMaze.parse_seed("4242")
	_ok(ps["ok"] and ps["seed"] == 4242 and not ps["empty"], "seed: 4242 elfogadva")
	ps = RandomMaze.parse_seed("  #20 261 102 ")
	_ok(ps["ok"] and ps["seed"] == 20261102, "seed: szóköz, # és a nap seedje (8 számjegy) elfogadva")
	ps = RandomMaze.parse_seed("   ")
	_ok(ps["ok"] and ps["empty"], "seed: üres mező = véletlen")
	for bad in ["abc", "12a", "-5", "4.2", "0", "000", "123456789", "１２"]:
		ps = RandomMaze.parse_seed(bad)
		_ok(not ps["ok"] and str(ps["error"]) != "", "seed: elutasítva „%s”: %s" % [bad, ps["error"]])
	var typed := RandomMaze.build("nehez", RandomMaze.parse_seed("#4242")["seed"])
	_ok(JSON.stringify(typed.to_dict()) == JSON.stringify(RandomMaze.build("nehez", 4242).to_dict()), "beírt seed = ugyanaz a pálya")
	var daily_typed := RandomMaze.build(RandomMaze.DAILY, RandomMaze.parse_seed("20261102")["seed"])
	_ok(JSON.stringify(daily_typed.to_dict()) == JSON.stringify(RandomMaze.build(RandomMaze.DAILY, RandomMaze.daily_seed({"year": 2026, "month": 11, "day": 2})).to_dict()), "a nap seedje beírva a nap labirintusát adja")
