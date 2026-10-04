extends SceneTree
## Füstteszt képernyőképekkel (nem headless, xvfb alatt):
## xvfb-run godot --path . --resolution 720x1280 -s tests/smoke.gd
## Nyitó animáció kockái, főmenü, pályalisták; végigjátssza a beépített pályákat a megoldóval;
## kipróbálja a szerkesztő új funkcióit (generálás, folyosóvágás, visszavonás, menü, mentetlen-változás ablak).
## Nem ment a repóba (a szerkesztő Mentés gombját nem nyomja meg).

var shots := "user://shots/"
var main: Node
var fails := 0


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(shots + name + ".png")
	print("shot ", ProjectSettings.globalize_path(shots + name + ".png"))


func _ok(cond: bool, msg: String) -> void:
	print(("OK    " if cond else "HIBA  ") + msg)
	if not cond:
		fails += 1


func _intro_at(sec: float, name: String) -> void:
	var ts: TitleScreen = main.title
	ts.t = sec
	await _shot(name)


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(shots)
	DirAccess.remove_absolute(Progress.PATH)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	var ts: TitleScreen = main.title
	# nyitó animáció kockái
	await _intro_at(0.5, "00a_intro_lap")
	await _intro_at(1.45, "00b_intro_toll")
	await _intro_at(2.5, "00c_intro_labirintus")
	await _intro_at(ts.T_RUN + 0.5, "00d_intro_fut")
	await _intro_at(ts.t_impact - 0.08, "00e_intro_pecset_zuhan")
	await _intro_at(ts.t_impact + 0.05, "00f_intro_becsapodas")
	await _intro_at(ts.t_impact + 0.9, "00g_intro_jegyzet")
	await _intro_at(ts.t_end + 0.5, "01_title")
	_ok(not ts.playing_intro, "az intró lefutott")
	await _frames(60)
	await _shot("01b_title_bolyongo_eger")

	main.show_level_list(false)
	await _frames(5)
	await _shot("02_list")
	for idx in main._levels.size():
		main.play_level(idx)
		await _frames(5)
		var g: LabGame = main.game
		var n := 0
		while not g.state.won and n < 6000:
			n += 1
			if g.is_busy():
				await process_frame
				continue
			var path := Solver.solve(g.level, g.state)
			if path.is_empty():
				print("nincs út innen")
				break
			g.input_dir(path[0])
			await process_frame
			if idx == 2 and n == 60:
				await _shot("04_l3_mid")
		_ok(g.state.won and g.deaths == 0, "pálya %d: nyert=%s halál=%d" % [idx + 1, g.state.won, g.deaths])
		await _frames(50)
		if idx == 0:
			await _shot("03_win")
	# halál-üzenet (a haladásba is beszámít)
	main.play_level(0)
	await _frames(3)
	main.game.restart()
	main.game.input_dir("U")
	main.game.restart()
	await _frames(10)
	await _shot("08_death")
	_ok(main.progress.total_deaths == 1 and main.progress.is_done("level_01.json"), "haladás: 1 halál, 1. pálya kész")
	main.show_title(false)
	await _frames(10)
	await _shot("09_title_vissza")
	main.show_level_list(false)
	await _frames(5)
	await _shot("02b_list_haladas")
	main.show_level_list(true)
	await _frames(5)
	await _shot("02c_list_szerkeszto")

	# szerkesztő: meglévő pálya ellenőrzése
	main.open_editor(2)
	await _frames(5)
	main.editor._check()
	await _frames(3)
	await _shot("05_editor_check")

	# új pálya: generálás, kitöltés, folyosóvágás, visszavonás
	main.open_editor(-1)
	await _frames(3)
	var ed: LabEditor = main.editor
	var P := ed.painter
	ed._generate()
	await _frames(3)
	_ok(not ed.solution.is_empty(), "generált labirintus megoldható")
	await _shot("06_editor_generalt")
	ed._fill(true)
	_ok(ed.level.open.is_empty() and ed.tool == "carve", "minden él fal, folyosó eszköz kiválasztva")
	# folyosó a starttól (0,8) felfelé, majd jobbra a kijáratig (6,0)
	ed._press(P.center(Vector2(0, 8)))
	for y in range(7, -1, -1):
		ed._drag(P.center(Vector2(0, y)))
	for x in range(1, 7):
		ed._drag(P.center(Vector2(x, 0)))
	ed._release(P.center(Vector2(6, 0)))
	_ok(ed.level.open.size() == 14 and not Solver.solve(ed.level).is_empty(), "folyosóvágás: 14 nyitott él, megoldható")
	# egy fal és egy tárgy, aztán visszavonás
	ed.tool = "wall"
	ed._press(P.dot_pos(Vector2i(1, 1)))
	ed._drag(P.dot_pos(Vector2i(1, 0)))
	ed._release(P.dot_pos(Vector2i(1, 0)))
	_ok(Solver.solve(ed.level).is_empty(), "fal elzárja a folyosót")
	ed.tool = "F"
	ed._press(P.center(Vector2(0, 4)))
	ed._release(P.center(Vector2(0, 4)))
	_ok(ed.level.objects.get(Vector2i(0, 4), "") == "F", "tűz lerakva")
	ed.undo()
	ed.undo()
	_ok(not ed.level.objects.has(Vector2i(0, 4)) and not Solver.solve(ed.level).is_empty(), "két visszavonás: tűz és fal eltűnt")
	ed.redo()
	_ok(Solver.solve(ed.level).is_empty(), "újra: a fal visszajött")
	ed.undo()
	ed._check()
	await _frames(3)
	await _shot("06b_editor_folyoso")
	ed._open_menu()
	await _frames(3)
	await _shot("06c_editor_menu")
	for c in ed._ui.get_children():
		if c.get_class() == "Control":
			c.queue_free()
	await _frames(2)
	# beillesztés vágólapról
	DisplayServer.clipboard_set(FileAccess.get_file_as_string("res://levels/level_02.json"))
	ed.paste_json(DisplayServer.clipboard_get())
	_ok(ed.level.title == "Kísérlet 02" and ed.dirty, "JSON beillesztése")
	ed.request_back()
	await _frames(3)
	await _shot("06d_editor_mentetlen")
	_ok(ed.visible, "mentetlen változásnál nem lép ki kérdés nélkül")
	ed.dirty = false
	ed._ui.get_child(ed._ui.get_child_count() - 1).queue_free()
	ed._test()
	await _frames(5)
	await _shot("07_test_play")
	# magasabb telefon (19.5:9): a logikai nézet 720x1560 lesz
	DisplayServer.window_set_size(Vector2i(576, 1248))
	await _frames(5)
	main.show_title(false)
	await _frames(10)
	await _shot("10_magas_title")
	main.open_editor(0)
	await _frames(5)
	await _shot("11_magas_editor")
	main.play_level(1)
	await _frames(5)
	await _shot("12_magas_jatek")
	print("FAILS=%d" % fails)
	DirAccess.remove_absolute(Progress.PATH)
	quit(1 if fails > 0 else 0)
