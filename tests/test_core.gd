extends SceneTree
## Headless teszt: godot --headless --path . -s tests/test_core.gd
## Minden pálya érvényes és megoldható; JSON oda-vissza alakítás veszteségmentes;
## labirintus-generátor, visszavonás, haladás-mentés.

var fails := 0


func _ok(cond: bool, msg: String) -> void:
	print(("OK    " if cond else "HIBA  ") + msg)
	if not cond:
		fails += 1


func _init() -> void:
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

	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
