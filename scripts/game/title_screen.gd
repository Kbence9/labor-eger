class_name TitleScreen
extends Node2D
## Nyitó animáció + főmenü egy füzetoldalon (Labornapló stílus).
##
## Intró (~6 mp, koppintásra átugorható):
##   füzetlap és margó -> írógépes fejléc -> golyóstoll megrajzolja a labirintust -> start/kijárat nyíl, sajt
##   -> az egér végigfut és kijut ... -> a LABOR EGÉR pecsét rácsap -> „Alany #0: kijutott. Majdnem.”
##   -> előtűnik a menü, és egy új egér szaglászik a labirintusban.
## Menü közben a háttérben egy egér bolyong; néha megkóstolja a sajtot (piros X marad utána).

signal continue_requested
signal levels_requested
signal editor_requested

const MAZE_COLS := 7
const MAZE_ROWS := 7
const EXIT_COL := 5
const STEP := 0.06            # intró: ennyi mp egy cella futás közben
const IDLE_STEP := 0.17       # menü: lassabb bolyongás
const T_MAZE := 0.6
const T_MAZE_LEN := 1.5
const T_RUN := 2.7
const NOTES := [
	"ne add neki a sajtot!!",
	"a tűz forró. Megint.",
	"#97 szerint a fal nem ehető.",
	"a repedés nem vár.",
	"aki ezt rajzolta, szóljon!",
	"a lila nyíl a kijárat. Elvileg.",
]

var painter := BoardPainter.new()
var maze: LevelData
var cheese := Vector2i(-1, -1)
var run_cells: Array[Vector2] = []    # az intró futása cellakoordinátában (a kijárat után a pecsétig)
var strokes: Array = []               # [{pts: PackedVector2Array, len: float}]
var total_len := 0.0
var specks: Array = []                # [{p: Vector2, r: float}]
var markers: Array[Vector2] = []      # piros X-ek (pixel)

var t := 0.0
var t_impact := 0.0
var t_end := 0.0
var playing_intro := false
var shake := 0.0
var note := ""
var note_is_death := false

var subject_no := 1
var next_level_no := 1
var has_progress := false
var total_deaths := 0

# geometria
var col_x := 0.0
var stamp_c := Vector2.ZERO
var stamp_size := 96
var stamp_rot := -0.085
var stamp_box := Vector2(450, 230)
var menu_top := 0.0
var footer_y := 0.0
var impact_pos := Vector2.ZERO

# bolyongó egér a menüben
var idle := {}

var _layer: CanvasLayer
var _ui: Control
var _menu: VBoxContainer
var _btn_main: Button
var _buttons: Array[Button] = []


func _ready() -> void:
	_build_maze()
	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()


# ---------- adatok ----------
func _build_maze() -> void:
	# az első olyan seed, ahol az út se nem túl rövid, se nem túl hosszú, és van zsákutca a sajtnak
	for seed in range(1, 400):
		var L := LevelData.new_empty(MAZE_COLS, MAZE_ROWS)
		L.objects.clear()
		L.objects[Vector2i(0, MAZE_ROWS - 1)] = "S"
		L.objects[Vector2i(EXIT_COL, 0)] = "E"
		MazeGen.carve(L, seed, 0.06)
		var path := Solver.solve(L)
		if path.size() < 13 or path.size() > 19:
			continue
		var cells := Solver.path_cells(L, path)
		var best := Vector2i(-1, -1)
		for d in MazeGen.dead_ends(L):
			if cells.has(d):
				continue
			for dir in LevelData.DIR_ORDER:
				var n: Vector2i = d + LevelData.DIRS[dir]
				if cells.has(n) and L.edge_kind(d, n) == "open" and n.y > 0 and n.y < MAZE_ROWS - 1:
					best = d
		if best.x < 0:
			continue
		maze = L
		cheese = best
		maze.objects[cheese] = "T"
		maze.rebuild()
		run_cells.clear()
		run_cells.append(Vector2(0, MAZE_ROWS) + Vector2(0, 0.35))
		for c in cells:
			run_cells.append(Vector2(c))
		return
	push_error("TitleScreen: nem találtam megfelelő labirintust")


func _layout() -> void:
	var vs := get_viewport_rect().size
	col_x = maxf(0.0, (vs.x - 720.0) / 2.0)
	stamp_c = Vector2(col_x + 340, 236)
	menu_top = vs.y - 392
	footer_y = vs.y - 58
	var area_top := 410.0
	var area_bot := menu_top - 34
	var cell := floorf(minf(58.0, minf((area_bot - area_top) / (MAZE_ROWS + 0.5), 520.0 / MAZE_COLS)))
	painter.level = maze
	painter.cell = cell
	painter.seed = 11
	var w := MAZE_COLS * cell
	painter.origin = Vector2(col_x + 392 - w / 2.0, area_top + (area_bot - area_top - MAZE_ROWS * cell) / 2.0).floor()
	# a futás vége: a kijárat fölött, a pecsét alsó széle alá bújva
	var ex := painter.center(Vector2(EXIT_COL, 0)).x
	stamp_box = Notebook.stamp_size(PackedStringArray(["LABOR", "EGÉR"]), stamp_size)
	var stamp_bottom := stamp_c.y + stamp_box.y / 2.0 + stamp_size * 0.11 + (ex - stamp_c.x) * sin(stamp_rot)
	impact_pos = Vector2(ex, stamp_bottom + painter.cell * 0.12)
	_rebuild_run_tail()
	_build_strokes()
	if _menu:
		_menu.position = Vector2(col_x + 104, menu_top)
		_menu.size = Vector2(minf(vs.x, 720.0) - 140, 0)


func _rebuild_run_tail() -> void:
	# a kijárattól felfelé, ki a lapra a pecsét alá
	while run_cells.size() > 0 and run_cells[run_cells.size() - 1].y < 0:
		run_cells.pop_back()
	var target_cy := (impact_pos.y - painter.origin.y) / painter.cell - 0.5
	run_cells.append(Vector2(EXIT_COL, target_cy))
	var steps := run_cells.size() - 3
	t_impact = T_RUN + steps * STEP + 0.26
	t_end = t_impact + 1.9


## Falak tollvonásokká fűzve: előbb a keret, aztán soronként a belső vonalak.
func _build_strokes() -> void:
	strokes.clear()
	total_len = 0.0
	var L := maze
	var gaps := {LevelData.ck(L.start) + "D": true, LevelData.ck(L.exit_cell) + "U": true}
	var segs := {}  # "x,y|x,y" pötty-élek
	for y in L.rows:
		for x in L.cols:
			var c := Vector2i(x, y)
			if x + 1 < L.cols and L.edge_kind(c, c + Vector2i(1, 0)) != "open":
				segs["v%d,%d" % [x + 1, y]] = true
			if y + 1 < L.rows and L.edge_kind(c, c + Vector2i(0, 1)) != "open":
				segs["h%d,%d" % [x, y + 1]] = true
	for x in L.cols:
		if not gaps.has(LevelData.ck(Vector2i(x, 0)) + "U"):
			segs["h%d,%d" % [x, 0]] = true
		if not gaps.has(LevelData.ck(Vector2i(x, L.rows - 1)) + "D"):
			segs["h%d,%d" % [x, L.rows]] = true
	for y in L.rows:
		segs["v%d,%d" % [0, y]] = true
		segs["v%d,%d" % [L.cols, y]] = true
	var border: Array = []
	var inner: Array = []
	# vízszintes futamok
	for y in L.rows + 1:
		var x := 0
		while x < L.cols:
			if segs.has("h%d,%d" % [x, y]):
				var x0 := x
				while x < L.cols and segs.has("h%d,%d" % [x, y]):
					x += 1
				var run := []
				for i in range(x0, x + 1):
					run.append(Vector2i(i, y))
				(border if (y == 0 or y == L.rows) else inner).append(run)
			else:
				x += 1
	# függőleges futamok
	for x in L.cols + 1:
		var y := 0
		while y < L.rows:
			if segs.has("v%d,%d" % [x, y]):
				var y0 := y
				while y < L.rows and segs.has("v%d,%d" % [x, y]):
					y += 1
				var run := []
				for i in range(y0, y + 1):
					run.append(Vector2i(x, i))
				(border if (x == 0 or x == L.cols) else inner).append(run)
			else:
				y += 1
	inner.sort_custom(func(a, b): return a[0].y * 100 + a[0].x < b[0].y * 100 + b[0].x)
	for run in border + inner:
		var pts := PackedVector2Array()
		for d in run:
			pts.append(painter.wob_dot(d.x, d.y))
		var ln := 0.0
		for i in range(1, pts.size()):
			ln += pts[i].distance_to(pts[i - 1])
		strokes.append({"pts": pts, "len": ln})
		total_len += ln


# ---------- vezérlés ----------
## intro: lejátssza a nyitó animációt; különben azonnal a kész menü látszik.
func show_menu(intro: bool, progress: Progress, next_idx: int) -> void:
	subject_no = progress.subject_no()
	total_deaths = progress.total_deaths
	has_progress = progress.has_any()
	next_level_no = next_idx + 1
	_btn_main.text = "Kísérlet folytatása" if has_progress else "Kísérlet indítása"
	playing_intro = intro
	if intro:
		t = 0.0
		markers.clear()
		specks.clear()
		note = "Alany #0: kijutott. Majdnem."
		note_is_death = true
	else:
		if specks.is_empty():
			_make_specks()
		t = t_end + 10.0
		note = NOTES[randi() % NOTES.size()]
		note_is_death = false
		_spawn_idle()
	_update_buttons()
	set_active(true)


func skip_intro() -> void:
	if not playing_intro:
		return
	playing_intro = false
	if specks.is_empty():
		_make_specks()
	t = t_end + 10.0
	_spawn_idle()
	_update_buttons()


func is_intro_done() -> bool:
	return not playing_intro


func set_active(on: bool) -> void:
	visible = on
	_layer.visible = on
	set_process(on)
	set_process_unhandled_input(on)


func _unhandled_input(e: InputEvent) -> void:
	if not visible or not playing_intro:
		return
	if (e is InputEventScreenTouch and e.pressed) or (e is InputEventKey and e.pressed):
		skip_intro()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	t += delta
	if playing_intro:
		if t >= t_impact and specks.is_empty():
			_make_specks()
			shake = 16.0
		if t >= t_impact + 1.5 and idle.is_empty():
			_spawn_idle()
		if t >= t_end:
			playing_intro = false
	_update_idle()
	_update_buttons()
	if shake > 0.3:
		position = Vector2(randf() - 0.5, randf() - 0.5) * shake
		shake *= 0.82
	else:
		shake = 0.0
		position = Vector2.ZERO
	queue_redraw()


func _phase(a: float, len: float) -> float:
	return clampf((t - a) / len, 0.0, 1.0)


func _update_buttons() -> void:
	var t_menu := t_impact + 1.2
	_menu.visible = t >= t_menu
	for i in _buttons.size():
		_buttons[i].modulate.a = _phase(t_menu + i * 0.09, 0.28)


func _make_specks() -> void:
	specks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 30:
		var side := rng.randi() % 4
		var hw := stamp_box.x / 2.0 + 12
		var hh := stamp_box.y / 2.0 + 12
		var p := Vector2(rng.randf_range(-hw, hw), rng.randf_range(-hh, hh))
		match side:
			0:
				p.y = -hh - rng.randf_range(2, 30)
			1:
				p.y = hh + rng.randf_range(2, 14)
			2:
				p.x = -hw - rng.randf_range(2, 36)
			3:
				p.x = hw + rng.randf_range(2, 36)
		specks.append({"p": stamp_c + p.rotated(stamp_rot), "r": rng.randf_range(1.4, 4.8) * (1.0 if rng.randf() < 0.8 else 1.8)})


# ---------- bolyongó egér ----------
func _spawn_idle() -> void:
	idle = {"from": Vector2(0, MAZE_ROWS) + Vector2(0, 0.35), "to": Vector2(maze.start), "cell": maze.start, "dir": "U", "t0": t, "dur": 0.35, "pause": 0.0, "dead": -1.0}


func _update_idle() -> void:
	if idle.is_empty():
		return
	if idle["dead"] >= 0.0:
		if t - idle["dead"] > 1.4:
			_spawn_idle()
		return
	if t - idle["t0"] < idle["dur"] or t < idle["pause"]:
		return
	var c: Vector2i = idle["cell"]
	if c == cheese:
		idle["dead"] = t
		markers.append(painter.center(Vector2(c)) + Vector2(painter.cell * 0.22, painter.cell * 0.18))
		if markers.size() > 5:
			markers.remove_at(0)
		return
	var back := {"U": "D", "D": "U", "L": "R", "R": "L"}
	var opts: Array[String] = []
	for d in LevelData.DIR_ORDER:
		var n: Vector2i = c + LevelData.DIRS[d]
		if maze.edge_kind(c, n) == "open" and d != back[idle["dir"]]:
			if n == cheese and randf() < 0.8:
				continue
			opts.append(d)
	if opts.is_empty():
		opts.append(back[idle["dir"]])
	if randf() < 0.18:
		idle["pause"] = t + randf_range(0.5, 1.4)
	var d2: String = opts[randi() % opts.size()]
	var n2: Vector2i = c + LevelData.DIRS[d2]
	idle["from"] = Vector2(c)
	idle["to"] = Vector2(n2)
	idle["cell"] = n2
	idle["dir"] = d2
	idle["t0"] = maxf(t, idle["pause"])
	idle["dur"] = IDLE_STEP


# ---------- rajzolás ----------
func _draw() -> void:
	var P := BoardPainter
	var vs := get_viewport_rect().size
	Notebook.page(self, Rect2(Vector2.ZERO, vs), _phase(0.0, 0.35), _phase(0.1, 0.45), true)
	_draw_header()
	_draw_maze()
	for m in markers:
		painter.draw_x(self, m, painter.cell * 0.17, Color(P.MARK, 0.8))
	_draw_intro_mouse()
	_draw_idle_mouse()
	_draw_stamp()
	_draw_note()
	_draw_footer()


func _draw_header() -> void:
	var P := BoardPainter
	var y := 66.0
	var k := _phase(0.3, 0.7)
	var l1 := "Kísérlet"
	var l2 := "Alany"
	var n1 := int(k * (l1.length() + l2.length()) * 1.0)
	var x1 := col_x + 112
	var w1 := Notebook.text(self, Vector2(x1, y), l1, 26, P.INK_SOFT, "type", n1)
	var vx := x1 + w1 + 12
	var right := col_x + 680
	var v2 := "#%d" % subject_no
	var vw2 := UiKit.F_BOLD.get_string_size(v2, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
	var lw2 := UiKit.F_TYPE.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
	var x2 := right - vw2 - 24 - lw2
	Notebook.text(self, Vector2(x2, y), l2, 26, P.INK_SOFT, "type", n1 - l1.length())
	var va := _phase(1.0, 0.2)
	if va > 0.0:
		var v1 := "%02d" % next_level_no
		var vw1 := UiKit.F_BOLD.get_string_size(v1, HORIZONTAL_ALIGNMENT_LEFT, -1, 34).x
		draw_line(Vector2(vx - 4, y + 8), Vector2(vx + vw1 + 18, y + 8), Color(P.INK_SOFT, 0.7 * va), 2.0)
		draw_line(Vector2(right - vw2 - 18, y + 8), Vector2(right + 4, y + 8), Color(P.INK_SOFT, 0.7 * va), 2.0)
		Notebook.text(self, Vector2(vx + 6, y + 2), v1, 34, Color(P.PEN, va), "bold")
		Notebook.text(self, Vector2(right - vw2 - 6, y + 2), v2, 34, Color(P.PEN, va), "bold")


func _draw_maze() -> void:
	var P := BoardPainter
	var w := maxf(2.5, painter.cell * 0.085)
	var drawn := total_len * _phase(T_MAZE, T_MAZE_LEN)
	var tip := Vector2.INF
	for s in strokes:
		var pts: PackedVector2Array = s["pts"]
		var ln: float = s["len"]
		if drawn <= 0.0:
			break
		if drawn >= ln:
			draw_polyline(pts, P.INK, w, true)
			drawn -= ln
			continue
		var part := PackedVector2Array([pts[0]])
		var left := drawn
		for i in range(1, pts.size()):
			var sl := pts[i].distance_to(pts[i - 1])
			if left >= sl:
				part.append(pts[i])
				left -= sl
			else:
				part.append(pts[i - 1].lerp(pts[i], left / sl))
				break
		draw_polyline(part, P.INK, w, true)
		tip = part[part.size() - 1]
		drawn = 0.0
		break
	var ka := _phase(T_MAZE + T_MAZE_LEN, 0.25)
	if ka > 0.0:
		painter.draw_arrow(self, maze.start, "D", Color(P.OK, ka), true)
		painter.draw_arrow(self, maze.exit_cell, "U", Color(P.EXIT, ka), false)
		var kc := _phase(T_MAZE + T_MAZE_LEN + 0.1, 0.25)
		if kc > 0.0:
			painter.draw_cheese(self, painter.center(Vector2(cheese)), painter.cell * 0.32 * _back_out(kc))
	if tip != Vector2.INF:
		Notebook.pen(self, tip)


static func _back_out(k: float) -> float:
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(k - 1.0, 3) + c1 * pow(k - 1.0, 2)


func _draw_intro_mouse() -> void:
	if not playing_intro and t > t_end:
		return
	if t < T_RUN - 0.35:
		return
	if t >= t_impact:
		return
	var pos: Vector2
	var dir := "U"
	if t < T_RUN:
		var a := clampf((t - (T_RUN - 0.35)) / 0.35, 0.0, 1.0)
		pos = run_cells[0].lerp(run_cells[1], a)
	else:
		var s := (t - T_RUN) / STEP
		var i := int(s) + 1
		if i >= run_cells.size() - 2:
			# utolsó szakasz: ki a kijáraton, a pecsét alá
			var a2 := clampf((t - (T_RUN + (run_cells.size() - 3) * STEP)) / 0.26, 0.0, 1.0)
			pos = run_cells[run_cells.size() - 2].lerp(run_cells[run_cells.size() - 1], a2)
			dir = "U"
		else:
			var a3 := s - floorf(s)
			pos = run_cells[i].lerp(run_cells[i + 1], a3)
			dir = _dir_of(run_cells[i + 1] - run_cells[i])
	painter.draw_mouse(self, painter.center(pos), dir, t, "", false)


static func _dir_of(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "R" if v.x > 0 else "L"
	return "D" if v.y > 0 else "U"


func _draw_idle_mouse() -> void:
	if idle.is_empty():
		return
	if idle["dead"] >= 0.0:
		var a := 1.0 - clampf((t - idle["dead"]) / 0.6, 0.0, 1.0)
		if a > 0.0:
			painter.draw_mouse(self, painter.center(Vector2(idle["cell"])), idle["dir"], t, "", true)
		return
	var k := clampf((t - idle["t0"]) / idle["dur"], 0.0, 1.0)
	var p: Vector2 = (idle["from"] as Vector2).lerp(idle["to"], k)
	var sniff := 0.0
	if t < idle["pause"]:
		sniff = sin(t * 22.0) * 0.04
	painter.draw_mouse(self, painter.center(p + Vector2(sniff, 0)), idle["dir"], t, "", false)


func _draw_stamp() -> void:
	var P := BoardPainter
	var lines := PackedStringArray(["LABOR", "EGÉR"])
	var fall := 0.24
	if t < t_impact - fall:
		return
	if t < t_impact:
		var k := (t - (t_impact - fall)) / fall
		var sc := lerpf(2.3, 1.0, k * k)
		# árnyék a leérkezés helyén
		draw_set_transform(stamp_c, stamp_rot, Vector2.ONE)
		draw_rect(Rect2(-stamp_box / 2.0, stamp_box), Color(P.INK, 0.12 * k))
		draw_set_transform(Vector2.ZERO)
		Notebook.stamp(self, stamp_c, lines, P.MARK, stamp_size, stamp_rot, sc, 0.25 + 0.6 * k)
		return
	var grow := _phase(t_impact, 0.08)
	for s in specks:
		draw_circle(s["p"], s["r"] * grow, Color(P.MARK, 0.8))
	Notebook.stamp(self, stamp_c, lines, P.MARK, stamp_size, stamp_rot, 1.0, 0.92)
	_draw_printed_mouse(impact_pos + Vector2(0, -painter.cell * 0.08), grow)


## Az egér, ami a pecsét alá került: piros tintás lenyomat a pecsét alsó szélén (a logó része marad).
func _draw_printed_mouse(p: Vector2, k: float) -> void:
	var col := Color(BoardPainter.MARK, 0.95)
	var r := painter.cell * 0.5
	var w := maxf(3.0, r * 0.14)
	draw_set_transform(p, stamp_rot - 0.15, Vector2(1.25, 0.7) * lerpf(1.3, 1.0, k))
	var body := BoardPainter.ellipse(Vector2(-r * .1, 0), r * .95, r * .68)
	draw_colored_polygon(body, Color(col, 0.3))
	draw_polyline(BoardPainter.closed(body), col, w, true)
	var head := BoardPainter.quad(Vector2(r * .45, -r * .5), Vector2(r * 1.4, -r * .2), Vector2(r * 1.3, 0), 6)
	head.append_array(BoardPainter.quad(Vector2(r * 1.3, 0), Vector2(r * 1.4, r * .2), Vector2(r * .45, r * .5), 6).slice(1))
	draw_polyline(BoardPainter.closed(head), col, w, true)
	for sg in [-1.0, 1.0]:
		var ear := BoardPainter.ellipse(Vector2(r * .45, sg * r * .62), r * .32, r * .28, 16)
		draw_polyline(BoardPainter.closed(ear), col, w, true)
		var e := Vector2(r * .9, sg * r * .2)
		var q := r * 0.1
		draw_line(e + Vector2(-q, -q), e + Vector2(q, q), col, w * 0.8, true)
		draw_line(e + Vector2(q, -q), e + Vector2(-q, q), col, w * 0.8, true)
	var tail := PackedVector2Array()
	for i in 9:
		var kk := i / 8.0
		tail.append(Vector2(-r * (0.95 + 1.6 * kk), sin(kk * 5.0) * r * 0.25))
	draw_polyline(tail, col, w, true)
	draw_set_transform(Vector2.ZERO)


func _draw_note() -> void:
	var P := BoardPainter
	if note == "":
		return
	var start := t_impact + 0.35 if note_is_death else t_impact + 1.2
	var n := int((t - start) / 0.035)
	if n <= 0:
		return
	var pos := Vector2(col_x + 112, impact_pos.y + 44)
	Notebook.text(self, pos, note, 28, P.PEN, "hand", n, -0.03)


func _draw_footer() -> void:
	var P := BoardPainter
	var a := _phase(t_impact + 1.3, 0.3)
	if a <= 0.0:
		return
	var x := col_x + 112
	var w := Notebook.text(self, Vector2(x, footer_y), "Elhunyt alanyok:", 28, Color(P.INK_SOFT, a))
	x += w + 18
	if total_deaths <= 0:
		Notebook.text(self, Vector2(x, footer_y), "még egy sem.", 28, Color(P.MARK, a))
		return
	var tw := 0.0
	if total_deaths >= 5:
		tw = Notebook.tally(self, Vector2(x, footer_y - 26), total_deaths, Color(P.MARK, a), 30.0, 3) + 6
	Notebook.text(self, Vector2(x + tw, footer_y + 2), str(total_deaths), 36, Color(P.MARK, a), "bold")


# ---------- UI ----------
func _build_ui() -> void:
	_layer = CanvasLayer.new()
	add_child(_layer)
	_ui = UiKit.full_rect(Control.new())
	_ui.theme = UiKit.theme()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_ui)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 6)
	_ui.add_child(_menu)
	_btn_main = UiKit.button("Kísérlet indítása", func(): continue_requested.emit(), "primary")
	_btn_main.add_theme_font_size_override("font_size", 50)
	_btn_main.custom_minimum_size = Vector2(0, 96)
	_btn_main.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_menu.add_child(_btn_main)
	_buttons.append(_btn_main)
	for b in [["Pályák", func(): levels_requested.emit()], ["Pályaszerkesztő", func(): editor_requested.emit()]]:
		var btn := UiKit.button(b[0], b[1], "text")
		btn.add_theme_font_size_override("font_size", 42)
		btn.add_theme_color_override("font_color", BoardPainter.PEN)
		btn.add_theme_color_override("font_hover_color", BoardPainter.PEN)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		btn.custom_minimum_size = Vector2(0, 78)
		_menu.add_child(btn)
		_buttons.append(btn)
