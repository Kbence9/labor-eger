extends SceneTree
## Füstteszt képernyőképekkel (nem headless, xvfb alatt):
## xvfb-run godot --path . --resolution 720x1280 -s tests/smoke.gd
## Nyitó animáció kockái, főmenü, pályalisták; végigjátssza a beépített pályákat a megoldóval;
## kipróbálja a szerkesztő új funkcióit (generálás, folyosóvágás, visszavonás, menü, mentetlen-változás ablak).
## Nem ment a repóba (a szerkesztő Mentés gombját nem nyomja meg).

var shots := "user://shots/"
var main: Node
var fails := 0
var guard: Logger = preload("res://tests/error_guard.gd").new()
var t_total := 0.0
const TIME_LIMIT := 600.0


func _initialize() -> void:
	OS.add_logger(guard)
	_run.call_deferred()


## Őr: script-hibánál vagy időtúllépésnél azonnal 1-es kóddal kilép (különben a megszakadt
## korutin miatt a quit() sosem futna le, és a folyamat a CI időkorlátjáig lógna).
func _process(delta: float) -> bool:
	t_total += delta
	if guard.count > 0:
		print("HIBA  script-hiba a füstteszt közben: %s" % guard.first)
		print("FAILS=%d" % (fails + 1))
		quit(1)
	elif t_total > TIME_LIMIT:
		print("HIBA  a füstteszt nem ért véget %d mp alatt" % int(TIME_LIMIT))
		print("FAILS=%d" % (fails + 1))
		quit(1)
	return false


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


## A host alatti első gomb megnyomása, amelynek felirata így kezdődik.
func _press_in(host: Node, prefix: String) -> void:
	for b in host.find_children("*", "Button", true, false):
		if (b as Button).text.begins_with(prefix):
			(b as Button).pressed.emit()
			return
	_ok(false, "nincs „%s” gomb" % prefix)


## A futó pályát végigjátssza a megoldóval (ahol épp az egér áll).
func _solve_current() -> void:
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
			return
		g.input_dir(path[0])
		await process_frame


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
	# rekord: az 1. pálya újra, a legjobb idő a HUD-on és a győzelmi lapon
	var g1: LabGame = main.game
	main.play_level(0)
	await _frames(3)
	_ok(g1._lbl_best.text.begins_with("Rekord: "), "a HUD mutatja a rekordot: %s" % g1._lbl_best.text)
	# versenyhelyzet: győzelem után azonnal másik pálya -> a régi győzelmi lap nem nyílhat rá
	await _solve_current()
	while g1.t_end < 0.0:   # a győzelem (a lépés-animáció végén) megtörtént, a lap még késleltetve
		await process_frame
	main.play_level(1)
	await create_timer(LabGame.WIN_CARD_DELAY + 0.3).timeout
	await _frames(2)
	_ok(not g1._win.visible and not g1.state.won, "győzelem után azonnal indított pályára nem nyílik rá a régi győzelmi lap")

	# véletlen labirintus: menü, mindhárom szint végigjátszva, rekord mentve
	main.show_title(false)
	await _frames(5)
	main.show_random_menu()
	await _frames(5)
	await _shot("13_veletlen_menu")
	# seed kézi megadása: hibás bevitelnél a menü nyitva marad és hibát ír, jó seednél ugyanaz a pálya
	var menu: Control = main.random_menu
	main.seed_edit.text = "abc"
	_press_in(menu, "Nehéz")
	await _frames(3)
	_ok(is_instance_valid(menu) and not menu.is_queued_for_deletion() and main.seed_error.visible and main.seed_error.text.begins_with("A seed csak"), "hibás seed: hibaüzenet, a menü nyitva (%s)" % main.seed_error.text)
	await _shot("13b_veletlen_hibas_seed")
	main.seed_edit.text = "4242"
	main.seed_edit.text_changed.emit("4242")
	_ok(not main.seed_error.visible, "gépeléskor a hibaüzenet eltűnik")
	_press_in(menu, "Nehéz")
	await _frames(5)
	_ok(not is_instance_valid(menu) or menu.is_queued_for_deletion(), "jó seed: a menü bezárul")
	_ok(main.game.visible and main._random.get("seed", 0) == 4242 and JSON.stringify(main.game.level.to_dict()) == JSON.stringify(RandomMaze.build("nehez", 4242).to_dict()), "beírt seed 4242: ugyanaz a Nehéz pálya (%s)" % main.game.level.title)
	main.show_title(false)
	await _frames(3)
	main.show_random_menu()
	await _frames(3)
	main.seed_edit.text = ""
	_press_in(main.random_menu, "Könnyű")
	await _frames(3)
	_ok(main.game.visible and main._random["diff"] == "konnyu" and main._random["seed"] >= 1, "üres seed-mező: véletlen seed (%d)" % main._random["seed"])
	main.show_title(false)
	await _frames(3)
	for diff in RandomMaze.ORDER:
		main.play_random(diff, 4242)
		await _frames(5)
		var gr: LabGame = main.game
		_ok(gr.level.cols == RandomMaze.LEVELS[diff]["size"].x and gr._btn_next.text == "Új labirintus", "véletlen %s: %dx%d" % [diff, gr.level.cols, gr.level.rows])
		if diff == "nehez":
			await _shot("14_veletlen_nehez")
		await _solve_current()
		await _frames(50)
		_ok(gr.state.won and gr._win.visible and gr._win_record.text.begins_with("Első"), "véletlen %s megoldva, első idő: %s" % [diff, gr._win_record.text])
		_ok(main.progress.best(RandomMaze.progress_key(diff)) > 0.0, "véletlen %s: a rekord mentve" % diff)
	await _shot("15_veletlen_gyozelem")
	var seed_before: int = main._random["seed"]
	main._on_game_next()
	await _frames(3)
	_ok(main._random["seed"] != seed_before and main.game.best_before > 0.0, "Új labirintus: más seed, a szint rekordja a HUD-on")
	main.play_random(RandomMaze.DAILY, RandomMaze.daily_seed(Time.get_date_dict_from_system()), true)
	await _frames(3)
	_ok(main.game.level.title == "A nap labirintusa" and main._current_file().begins_with("napi:"), "a nap labirintusa: %s" % main._current_file())
	await _shot("16_nap_labirintusa")

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
