extends SceneTree
## Füstteszt képernyőképekkel (nem headless, xvfb alatt):
## xvfb-run godot --path . --resolution 720x1280 -s tests/smoke.gd
## Végigjátssza a beépített pályákat a megoldóval vezérelve, és kipróbálja a szerkesztőt.

var shots := "user://shots/"
var main: Node


func _initialize() -> void:
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _shot(name: String) -> void:
	await process_frame
	var img := root.get_texture().get_image()
	img.save_png(shots + name + ".png")
	print("shot ", ProjectSettings.globalize_path(shots + name + ".png"))


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(shots)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(10)
	await _shot("01_title")
	main.show_level_list(false)
	await _frames(5)
	await _shot("02_list")
	var fails := 0
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
		print("pálya %d: nyert=%s halál=%d" % [idx + 1, g.state.won, g.deaths])
		if not g.state.won or g.deaths > 0:
			fails += 1
		await _frames(50)
		if idx == 0:
			await _shot("03_win")
	# halál-üzenet
	main.play_level(0)
	await _frames(3)
	main.game.restart()
	main.game.input_dir("U")
	main.game.restart()
	await _frames(10)
	await _shot("08_death")
	# szerkesztő
	main.open_editor(2)
	await _frames(5)
	main.editor._check()
	await _frames(3)
	await _shot("05_editor_check")
	main.open_editor(-1)
	await _frames(3)
	var ed: LabEditor = main.editor
	var P := ed.painter
	# fal húzása: (1,0) pöttytől lefelé 3 szakasz
	ed.tool = "wall"
	ed._press(P.dot_pos(Vector2i(1, 0)))
	for y in range(1, 4):
		ed._drag(P.dot_pos(Vector2i(1, y)))
	ed._release(P.dot_pos(Vector2i(1, 3)))
	# tégla koppintással
	ed.tool = "brk"
	ed._press((P.dot_pos(Vector2i(3, 4)) + P.dot_pos(Vector2i(4, 4))) / 2)
	ed._release((P.dot_pos(Vector2i(3, 4)) + P.dot_pos(Vector2i(4, 4))) / 2)
	for t in [["H", Vector2i(2, 2)], ["F", Vector2i(5, 3)], ["W", Vector2i(0, 0)], ["A", Vector2i(3, 6)], ["A", Vector2i(6, 6)], ["C", Vector2i(4, 5)], ["T", Vector2i(2, 7)]]:
		ed.tool = t[0]
		var p := P.center(Vector2(t[1]))
		ed._press(p)
		ed._release(p)
	var walls := 0
	for k in ed.level.breakable:
		walls += 1
	print("szerkesztő: fal-élek=%d tégla=%d objektumok=%d" % [ed.level.cols * (ed.level.rows - 1) + ed.level.rows * (ed.level.cols - 1) - ed.level.open.size() - ed.level.breakable.size(), walls, ed.level.objects.size()])
	ed._check()
	await _frames(3)
	await _shot("06_editor_new")
	ed._test()
	await _frames(5)
	await _shot("07_test_play")
	print("FAILS=%d" % fails)
	quit(1 if fails > 0 else 0)
