class_name LabGame
extends Node2D
## A játékjelenet: rajzolás, swipe/billentyű, futás kanyar-pufferrel, halál, győzelem, HUD.

signal back_requested
signal next_requested

const STEP_TIME := 0.085
const CRACK_TIME := 0.45
const DEATH_TIME := 1.15
const SWIPE_PX := 40.0
const HUD_TOP := 150.0
const HUD_BOTTOM := 120.0

const DEATH_TEXT := {
	"burn": [["megégett.", "kicsit túlsült.", "grillezve."], "Jegyzet: a tűz forró."],
	"fall": [["lezuhant.", "átesett a padlón.", "eltűnt egy lyukban."], "Jegyzet: a repedt padló nem vár."],
	"trap": [["egérfogóba lépett.", "megkóstolta a sajtot."], "Jegyzet: ingyen sajt csak az egérfogóban van."],
	"quit": [["feladta."], "Jegyzet: néha az újrakezdés is tudomány."],
}

var level: LevelData
var state: GameState
var painter := BoardPainter.new()
var test_mode := false
var has_next := false

var disp := Vector2.ZERO
var anim: Dictionary = {}
var moving := false
var cur_dir := ""
var queue_dir := ""
var face_dir := "U"
var crack_at := -1.0
var bump: Dictionary = {}
var deaths := 0
var t_start := -1.0
var t_end := -1.0
var markers: Array = []
var death_info: Dictionary = {}
var particles: Array = []
var shake := 0.0
var flash := 0.0
var now := 0.0
var touch_start := Vector2.INF

var _ui: Control
var _lbl_title: Label
var _lbl_subject: Label
var _lbl_time: Label
var _lbl_deaths: Label
var _toast: PanelContainer
var _toast_head: Label
var _toast_note: Label
var _win: Control
var _win_title: Label
var _win_stats: Label
var _win_note: Label
var _btn_next: Button


func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_layout)


func start(L: LevelData, is_test: bool = false, next_available: bool = false) -> void:
	level = L
	test_mode = is_test
	has_next = next_available
	painter.seed = L.id + 1
	deaths = 0
	t_start = -1.0
	t_end = -1.0
	markers.clear()
	particles.clear()
	_reset_run()
	_lbl_title.text = ("Teszt: " if test_mode else "") + L.title
	_win.visible = false
	_toast.visible = false
	_layout()


func _reset_run() -> void:
	state = GameState.from_level(level)
	disp = Vector2(state.pos)
	anim = {}
	moving = false
	cur_dir = ""
	queue_dir = ""
	crack_at = -1.0
	death_info = {}
	face_dir = "U"
	_update_hud()


func _layout() -> void:
	if level == null:
		return
	var vs := get_viewport_rect().size
	painter.fit(level, Rect2(Vector2(0, HUD_TOP), Vector2(vs.x, vs.y - HUD_TOP - HUD_BOTTOM)))


# ---------- input ----------
func _unhandled_input(e: InputEvent) -> void:
	if not visible or level == null:
		return
	if e is InputEventKey and e.pressed and not e.echo:
		var d := _key_dir(e.keycode)
		if d != "":
			input_dir(d)
			get_viewport().set_input_as_handled()
		elif e.keycode == KEY_R:
			restart()
	elif e is InputEventScreenTouch:
		if e.pressed:
			touch_start = e.position
			if not death_info.is_empty() and now - death_info["t0"] > 0.35:
				_finish_death()
		else:
			touch_start = Vector2.INF
	elif e is InputEventScreenDrag and touch_start != Vector2.INF:
		var dv: Vector2 = e.position - touch_start
		if dv.length() >= SWIPE_PX:
			if absf(dv.x) > absf(dv.y):
				input_dir("R" if dv.x > 0 else "L")
			else:
				input_dir("D" if dv.y > 0 else "U")
			touch_start = e.position


func _key_dir(k: int) -> String:
	match k:
		KEY_UP, KEY_W:
			return "U"
		KEY_DOWN, KEY_S:
			return "D"
		KEY_LEFT, KEY_A:
			return "L"
		KEY_RIGHT, KEY_D:
			return "R"
	return ""


func input_dir(d: String) -> void:
	if _win.visible:
		return
	if not death_info.is_empty():
		if now - death_info["t0"] > 0.35:
			_finish_death()
		return
	if state.won or state.dead != "":
		return
	if t_start < 0:
		t_start = now
	if moving:
		queue_dir = d
		return
	_try_move(d)


func is_busy() -> bool:
	return moving or not anim.is_empty() or not death_info.is_empty()


# ---------- mozgás ----------
func _try_move(d: String) -> void:
	cur_dir = d
	face_dir = d
	var from := state.pos
	var ev := state.step(level, d)
	var first: String = ev[0]["t"] if ev.size() > 0 else ""
	if first == "blocked" or first == "bonk":
		bump = {"dir": d, "t0": now}
		moving = false
		if first == "bonk":
			_burst(Vector2(from), d, Color("9a4b3a"), 4, false)
		_check_crack_hold()
		return
	if first == "break":
		_burst(Vector2(from), d, Color("a8553f"), 16, true)
		shake = 8.0
		moving = false
		return
	crack_at = -1.0
	for e in ev:
		if e["t"] == "crumble":
			_dust(Vector2(e["cell"]))
	var target := state.pos
	for e in ev:
		if e["t"] == "teleport":
			target = e["from"]
	moving = true
	anim = {"from": Vector2(from), "to": Vector2(target), "t0": now, "ev": ev}


func _arrive() -> void:
	var ev: Array = anim["ev"]
	anim = {}
	if not death_info.is_empty():
		return
	disp = Vector2(state.pos)
	var stop := false
	for e in ev:
		match e["t"]:
			"teleport":
				flash = 1.0
				_ring(Vector2(state.pos))
				stop = true
			"pick", "swap":
				_sparkle(Vector2(state.pos))
				stop = true
			"douse":
				_steam(Vector2(state.pos))
				stop = true
			"die":
				_die(e["why"])
				return
			"win":
				_on_win()
				return
	if queue_dir != "" and state.edge(level, state.pos, queue_dir) != "wall":
		var q := queue_dir
		queue_dir = ""
		_try_move(q)
		return
	if not stop:
		var fwd := state.edge(level, state.pos, cur_dir)
		var sides := ["L", "R"] if (cur_dir == "U" or cur_dir == "D") else ["U", "D"]
		var junction := false
		for sd in sides:
			if state.edge(level, state.pos, sd) != "wall":
				junction = true
		if fwd == "open" and not junction:
			_try_move(cur_dir)
			return
		if fwd == "brk" and state.held == "H":
			_try_move(cur_dir)
			return
		if fwd == "brk":
			bump = {"dir": cur_dir, "t0": now}
	moving = false
	queue_dir = ""
	_check_crack_hold()


func _check_crack_hold() -> void:
	if state.cracks.get(state.pos, "") == "ok" and crack_at < 0:
		crack_at = now


# ---------- halál / győzelem ----------
func _die(why: String) -> void:
	state.dead = why
	moving = false
	queue_dir = ""
	crack_at = -1.0
	anim = {}
	disp = Vector2(state.pos)
	deaths += 1
	markers.append(state.pos)
	if why != "quit":
		_fur(Vector2(state.pos))
		shake = 10.0
	var txt: Array = DEATH_TEXT[why]
	var heads: Array = txt[0]
	_toast_head.text = "Alany #%d %s" % [deaths, heads[randi() % heads.size()]]
	_toast_note.text = txt[1]
	_toast.visible = true
	death_info = {"why": why, "t0": now}
	_update_hud()


func _finish_death() -> void:
	if death_info.is_empty():
		return
	_toast.visible = false
	_reset_run()


func restart() -> void:
	if not death_info.is_empty() or state.won:
		return
	if t_start < 0:
		_reset_run()
		return
	_die("quit")


func _on_win() -> void:
	moving = false
	t_end = now
	_confetti(Vector2(state.pos))
	await get_tree().create_timer(0.6).timeout
	_win_title.text = level.title + " lezárva"
	_win_stats.text = "Idő: %s     Elhunyt alanyok: %d" % [_fmt(t_end - t_start), deaths]
	if deaths == 0:
		_win_note.text = "Elsőre? Gyanús. Az alanyt további vizsgálatra javasoljuk."
	elif deaths < 5:
		_win_note.text = "Az alany tanul. Lassan, de tanul."
	else:
		_win_note.text = "Szép munka. A labor hálás a(z) %d önkéntesért." % deaths
	_btn_next.visible = has_next and not test_mode
	_win.visible = true


static func _fmt(sec: float) -> String:
	sec = maxf(sec, 0.0)
	var m := int(sec / 60.0)
	var s := sec - m * 60
	return "%d:%04.1f" % [m, s]


func _update_hud() -> void:
	if _lbl_deaths:
		_lbl_deaths.text = "Halál: %d" % deaths
		_lbl_subject.text = "Alany #%d" % (deaths + 1)


# ---------- frame ----------
func _process(delta: float) -> void:
	if level == null or not visible:
		return
	now += delta
	if not anim.is_empty() and now - anim["t0"] >= STEP_TIME:
		_arrive()
	if crack_at >= 0 and death_info.is_empty() and state.dead == "" and now - crack_at >= CRACK_TIME:
		if state.cracks.get(state.pos, "") == "ok" and not moving:
			state.cracks[state.pos] = "hole"
			_dust(Vector2(state.pos))
			_die("fall")
		crack_at = -1.0
	if not death_info.is_empty() and now - death_info["t0"] >= DEATH_TIME:
		_finish_death()
	for p in particles:
		var v: Vector2 = p["vel"]
		p["pos"] += v
		v.y += p["g"]
		p["vel"] = v
		p["life"] -= p["decay"]
	particles = particles.filter(func(p): return p["life"] > 0.0)
	var el := 0.0
	if t_start >= 0:
		el = (t_end if t_end >= 0 else now) - t_start
	_lbl_time.text = _fmt(el)
	queue_redraw()


func _draw() -> void:
	if level == null:
		return
	var off := Vector2.ZERO
	if shake > 0.2:
		off = Vector2(randf() - 0.5, randf() - 0.5) * shake
		shake *= 0.85
	else:
		shake = 0.0
	var shake_cell := state.pos if crack_at >= 0 else Vector2i(-99, -99)
	# a painter saját transzformot használ; az eltolást az origón keresztül adjuk át
	painter.origin += off
	painter.sheet.position += off
	painter.draw_board(self, state, now, {"markers": markers, "shake_cell": shake_cell})
	# egér
	var m := disp
	if not anim.is_empty():
		var k := clampf((now - anim["t0"]) / STEP_TIME, 0.0, 1.0)
		m = (anim["from"] as Vector2).lerp(anim["to"], k)
	if not bump.is_empty():
		var bk: float = (now - bump["t0"]) / 0.14
		if bk > 1.0:
			bump = {}
		else:
			m += Vector2(LevelData.DIRS[bump["dir"]]) * sin(bk * PI) * 0.12
	var sc := 1.0
	if not death_info.is_empty() and death_info["why"] == "fall":
		sc = maxf(0.0, 1.0 - (now - death_info["t0"]) / 0.5)
	if sc > 0.0:
		painter.draw_mouse(self, painter.center(m), face_dir, now, state.held, not death_info.is_empty(), sc)
	for p in particles:
		var col: Color = p["color"]
		col.a = clampf(p["life"], 0.0, 1.0)
		var pp := painter.center(p["pos"])
		var r: float = p["size"] * painter.cell
		if p["sq"]:
			draw_rect(Rect2(pp - Vector2.ONE * r / 2, Vector2.ONE * r), col)
		else:
			draw_circle(pp, r / 2, col)
	painter.origin -= off
	painter.sheet.position -= off
	# kézben lévő tárgy (jobb felső doboz)
	var vs := get_viewport_rect().size
	var slot := Rect2(Vector2(vs.x - 110, 34), Vector2(82, 82))
	draw_rect(slot, BoardPainter.PAPER)
	draw_rect(slot, BoardPainter.INK_SOFT, false, 3.0)
	var c := slot.get_center()
	var save_cell := painter.cell
	painter.cell = 60.0
	if state.held == "H":
		painter.draw_hammer(self, c + Vector2(0, 4), 28.0, -0.6)
	elif state.held == "W":
		painter.draw_flask(self, c + Vector2(0, 4), 28.0)
	else:
		draw_line(c + Vector2(-14, 0), c + Vector2(14, 0), BoardPainter.RULE, 4.0)
	painter.cell = save_cell
	if flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, vs), Color(0.77, 0.42, 0.84, flash * 0.25))
		flash = maxf(0.0, flash - 0.06)


# ---------- részecskék ----------
func _p(pos: Vector2, vel: Vector2, color: Color, size: float, decay: float, g: float = 0.0, sq: bool = false) -> void:
	particles.append({"pos": pos, "vel": vel, "color": color, "size": size, "decay": decay, "g": g, "life": 1.0, "sq": sq})


func _burst(c: Vector2, d: String, color: Color, n: int, big: bool) -> void:
	var dv := Vector2(LevelData.DIRS[d])
	for i in n:
		_p(c + dv * 0.5, Vector2(randf() - 0.5, randf() - 0.5) * 0.12 + dv * 0.02, color, (0.05 + randf() * 0.07) if big else 0.04, 0.025, 0.004, big)


func _dust(c: Vector2) -> void:
	for i in 10:
		_p(c, Vector2(randf() - 0.5, randf() - 0.5) * 0.05, Color("8c8f86"), 0.05, 0.03)


func _steam(c: Vector2) -> void:
	for i in 16:
		_p(c, Vector2((randf() - 0.5) * 0.04, -0.02 - randf() * 0.03), Color("b9c3cc"), 0.08 + randf() * 0.06, 0.018)


func _sparkle(c: Vector2) -> void:
	for i in 10:
		var a := TAU * i / 10.0
		_p(c, Vector2(cos(a), sin(a)) * 0.05, Color("e3b23c"), 0.035, 0.04)


func _ring(c: Vector2) -> void:
	for i in 18:
		var a := TAU * i / 18.0
		_p(c, Vector2(cos(a), sin(a)) * 0.06, Color("c56bd6"), 0.04, 0.035)


func _fur(c: Vector2) -> void:
	for i in 18:
		_p(c, Vector2((randf() - 0.5) * 0.12, (randf() - 0.5) * 0.12 - 0.02), Color("9aa0a6") if i % 3 else Color("f2a7b5"), 0.04 + randf() * 0.04, 0.02, 0.002)


func _confetti(c: Vector2) -> void:
	var cols := [Color("e0679b"), Color("18a3a0"), Color("e3b23c"), Color("2f8a4a"), Color("7a3fa0")]
	for i in 40:
		_p(c, Vector2((randf() - 0.5) * 0.2, -randf() * 0.18), cols[i % 5], 0.05, 0.012, 0.006, true)


# ---------- UI ----------
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = UiKit.full_rect(Control.new())
	_ui.theme = UiKit.theme()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)

	var top := VBoxContainer.new()
	top.position = Vector2(32, 30)
	_ui.add_child(top)
	_lbl_title = UiKit.label("", 40)
	_lbl_subject = UiKit.label("Alany #1", 24, BoardPainter.INK_SOFT)
	top.add_child(_lbl_title)
	top.add_child(_lbl_subject)

	var stats := VBoxContainer.new()
	stats.anchor_left = 1.0
	stats.anchor_right = 1.0
	stats.offset_left = -340
	stats.offset_right = -130
	stats.offset_top = 30
	stats.offset_bottom = 120
	stats.alignment = BoxContainer.ALIGNMENT_BEGIN
	_ui.add_child(stats)
	_lbl_time = UiKit.label("0:00.0", 34)
	_lbl_time.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_deaths = UiKit.label("Halál: 0", 26, BoardPainter.MARK)
	_lbl_deaths.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stats.add_child(_lbl_time)
	stats.add_child(_lbl_deaths)

	var bottom := HBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -100
	bottom.offset_bottom = -20
	bottom.offset_left = 32
	bottom.offset_right = -32
	bottom.add_theme_constant_override("separation", 16)
	_ui.add_child(bottom)
	var hint := UiKit.label("Húzd az ujjad", 24, BoardPainter.INK_SOFT)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bottom.add_child(hint)
	bottom.add_child(UiKit.button("Újra", restart))
	bottom.add_child(UiKit.button("Vissza", func(): back_requested.emit()))

	_toast = UiKit.card(BoardPainter.MARK)
	_toast.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_toast.offset_left = -300
	_toast.offset_right = 300
	_toast.offset_top = -300
	_toast.offset_bottom = -130
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tv := VBoxContainer.new()
	_toast_head = UiKit.label("", 32, BoardPainter.MARK)
	_toast_head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_toast_note = UiKit.label("", 24, BoardPainter.INK_SOFT)
	_toast_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tv.add_child(_toast_head)
	tv.add_child(_toast_note)
	_toast.add_child(tv)
	_toast.visible = false
	_ui.add_child(_toast)

	_win = UiKit.full_rect(CenterContainer.new())
	_ui.add_child(_win)
	var card := UiKit.card(BoardPainter.INK)
	card.custom_minimum_size = Vector2(600, 0)
	_win.add_child(card)
	var wv := VBoxContainer.new()
	wv.add_theme_constant_override("separation", 18)
	card.add_child(wv)
	wv.add_child(UiKit.label("SIKERES", 26, BoardPainter.OK))
	_win_title = UiKit.label("", 40)
	_win_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_win_stats = UiKit.label("", 28)
	_win_note = UiKit.label("", 26, BoardPainter.INK_SOFT)
	_win_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wv.add_child(_win_title)
	wv.add_child(_win_stats)
	wv.add_child(_win_note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	_btn_next = UiKit.button("Következő", func(): next_requested.emit(), true)
	row.add_child(_btn_next)
	row.add_child(UiKit.button("Újra", func(): start(level, test_mode, has_next)))
	row.add_child(UiKit.button("Vissza", func(): back_requested.emit()))
	wv.add_child(row)
	_win.visible = false


func set_active(on: bool) -> void:
	visible = on
	_ui.visible = on
	set_process_unhandled_input(on)
