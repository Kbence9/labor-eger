extends SceneTree
## Headless teszt: godot --headless --path . -s tests/test_core.gd
## Minden pálya érvényes és megoldható; JSON oda-vissza alakítás veszteségmentes.

func _init() -> void:
	var fails := 0
	var dir := "res://levels"
	var files := DirAccess.get_files_at(dir)
	for f in files:
		if not f.ends_with(".json"):
			continue
		var txt := FileAccess.get_file_as_string(dir + "/" + f)
		var L := LevelData.from_dict(JSON.parse_string(txt))
		var errs := L.validate()
		var sol := Solver.solve(L)
		var L2 := LevelData.from_dict(L.to_dict())
		var same := L2.open.size() == L.open.size() and L2.objects.size() == L.objects.size() and L2.breakable.size() == L.breakable.size()
		var ok := errs.is_empty() and sol.size() > 0 and same
		if not ok:
			fails += 1
		print("%s %s  hibák=%s  megoldás=%d lépés  roundtrip=%s" % ["OK  " if ok else "HIBA", f, str(errs), sol.size(), same])
	# szerkesztő-műveletek
	var E := LevelData.new_empty(5, 5)
	E.set_edge(Vector2i(0, 4), Vector2i(1, 4), "wall")
	E.set_edge(Vector2i(0, 4), Vector2i(0, 3), "brk")
	var s1 := Solver.solve(E)
	E.objects[Vector2i(0, 0)] = "H"
	E.rebuild()
	var s2 := Solver.solve(E)
	E.resize(4, 6)
	print("üres pálya: elzárva=%d lépés, kalapáccsal sem elérhető=%d, átméretezés után hibák=%s" % [s1.size(), s2.size(), str(E.validate())])
	if s1.size() != 0:
		fails += 1
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
