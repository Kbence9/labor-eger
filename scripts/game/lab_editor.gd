class_name LabEditor
extends Node2D
## Pályaszerkesztő. Falat pöttytől pöttyig húzva rajzolsz (mint papíron), objektumot koppintással teszel le.
## Ellenőrzés: a megoldó megmondja, megoldható-e, és megrajzolja a legrövidebb utat.

signal test_requested(level: LevelData)
signal back_requested

const TOP_H := 200.0
const BOTTOM_H := 440.0
const TOOLS := [
	["wall", "Fal"], ["brk", "Tégla"], ["erase", "Radír"], ["S", "Start"],
	["E", "Kijárat"], ["H", "Kalapács"], ["W", "Víz"], ["F", "Tűz"],
	["C", "Repedés"], ["T", "Sajt"], ["A", "Portál A"], ["B", "Portál B"],
]

var library: LevelLibrary
var level: LevelData
var file_name := ""
var dirty := false
var tool := "wall"
var painter := BoardPainter.new()
var solution: Array[Vector2i] = []
var now := 0.0

var _anchor := Vector2i(-999, -999)
var _stroke_mode := ""
var _press_pos := Vector2.INF
var _dragged := false

var _ui: Control
var _name_edit: LineEdit
var _size_lbl: Label
var _status: Label


func _ready() -> void:
	_build_ui()
	get_viewport().size_changed.connect(_layout)


func open_level(L: LevelData, file: String) -> void:
	level = L
	file_name = file
	dirty = false
	solution.clear()
	painter.seed = L.id + 1
	_name_edit.text = L.title
	_refresh()
	_set_status("Falat húzással rajzolsz pöttytől pöttyig. Tárgyat koppintással teszel le.")


func _layout() -> void:
	if level == null:
		return
	var vs := get_viewport_rect().size
	painter.fit(level, Rect2(Vector2(0, TOP_H), Vector2(vs.x, vs.y - TOP_H - BOTTOM_H)), 1.4)


func _refresh() -> void:
	_size_lbl.text = "%d × %d" % [level.cols, level.rows]
	_layout()
	queue_redraw()


func _changed() -> void:
	dirty = true
	solution.clear()
	level.rebuild()
	queue_redraw()


func _set_status(t: String, col: Color = BoardPainter.INK_SOFT) -> void:
	_status.text = t
	_status.add_theme_color_override("font_color", col)


# ---------- rajzolás ----------
func _process(delta: float) -> void:
	if visible and level != null:
		now += delta
		queue_redraw()


func _draw() -> void:
	if level == null:
		return
	var s := GameState.from_level(level)
	painter.draw_board(self, s, now, {"path": solution})
	if _anchor.x > -999:
		draw_circle(painter.dot_pos(_anchor), painter.cell * 0.14, Color(BoardPainter.EXIT, 0.6))


# ---------- input ----------
func _unhandled_input(e: InputEvent) -> void:
	if not visible or level == null:
		return
	if e is InputEventScreenTouch:
		if e.pressed:
			_press(e.position)
		else:
			_release(e.position)
	elif e is InputEventScreenDrag:
		_drag(e.position)


func _is_line_tool() -> bool:
	return tool == "wall" or tool == "brk" or tool == "erase"


func _press(p: Vector2) -> void:
	_press_pos = p
	_dragged = false
	_stroke_mode = ""
	_anchor = Vector2i(-999, -999)
	if _is_line_tool():
		var d := painter.nearest_dot(p)
		if p.distance_to(painter.dot_pos(d)) < painter.cell * 0.45 and _dot_ok(d):
			_anchor = d


func _drag(p: Vector2) -> void:
	if _anchor.x <= -999:
		return
	var d := painter.nearest_dot(p)
	if d == _anchor or not _dot_ok(d):
		return
	if p.distance_to(painter.dot_pos(d)) > painter.cell * 0.38:
		return
	var diff := d - _anchor
	if absi(diff.x) + absi(diff.y) != 1:
		_anchor = d
		return
	_apply_segment(_anchor, d)
	_anchor = d
	_dragged = true


func _release(p: Vector2) -> void:
	var was_tap := not _dragged and _press_pos != Vector2.INF and p.distance_to(_press_pos) < painter.cell * 0.3
	_anchor = Vector2i(-999, -999)
	_press_pos = Vector2.INF
	if was_tap:
		_tap(p)
	queue_redraw()


func _dot_ok(d: Vector2i) -> bool:
	return d.x >= 0 and d.y >= 0 and d.x <= level.cols and d.y <= level.rows


func _tap(p: Vector2) -> void:
	var q := (p - painter.origin) / painter.cell
	if _is_line_tool():
		var seg := _nearest_segment(q)
		if seg.size() == 2:
			_stroke_mode = ""
			_apply_segment(seg[0], seg[1])
			return
		if tool != "erase":
			return
	var c := painter.cell_at(p)
	if not level.in_bounds(c):
		return
	if tool == "erase":
		if level.objects.has(c):
			level.objects.erase(c)
			_changed()
		return
	_place(c, tool)


func _nearest_segment(q: Vector2) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var best := 0.22
	# vízszintes él
	var ry := roundf(q.y)
	var fx := q.x - floorf(q.x)
	if absf(q.y - ry) < best and fx > 0.12 and fx < 0.88:
		best = absf(q.y - ry)
		out = [Vector2i(floori(q.x), int(ry)), Vector2i(floori(q.x) + 1, int(ry))]
	var rx := roundf(q.x)
	var fy := q.y - floorf(q.y)
	if absf(q.x - rx) < best and fy > 0.12 and fy < 0.88:
		out = [Vector2i(int(rx), floori(q.y)), Vector2i(int(rx), floori(q.y) + 1)]
	if out.size() == 2 and (not _dot_ok(out[0]) or not _dot_ok(out[1])):
		out.clear()
	return out


## Két szomszédos pötty közötti szakasz -> a két cella, amit elválaszt (szélső fal: üres)
func _segment_cells(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if a.y == b.y:
		var x := mini(a.x, b.x)
		var y := a.y
		if y <= 0 or y >= level.rows:
			return out
		out = [Vector2i(x, y - 1), Vector2i(x, y)]
	else:
		var x2 := a.x
		var y2 := mini(a.y, b.y)
		if x2 <= 0 or x2 >= level.cols:
			return out
		out = [Vector2i(x2 - 1, y2), Vector2i(x2, y2)]
	return out


func _apply_segment(a: Vector2i, b: Vector2i) -> void:
	var cells := _segment_cells(a, b)
	if cells.size() != 2:
		return
	var cur := level.edge_kind(cells[0], cells[1])
	if _stroke_mode == "":
		match tool:
			"wall":
				_stroke_mode = "open" if cur == "wall" else "wall"
			"brk":
				_stroke_mode = "open" if cur == "brk" else "brk"
			_:
				_stroke_mode = "open"
	if cur != _stroke_mode:
		level.set_edge(cells[0], cells[1], _stroke_mode)
		_changed()


func _place(c: Vector2i, code: String) -> void:
	if level.objects.get(c, "") == code:
		level.objects.erase(c)
		_changed()
		return
	if code == "S" or code == "E":
		for k in level.objects.keys():
			if level.objects[k] == code:
				level.objects.erase(k)
	elif code == "A" or code == "B":
		var same: Array = []
		for k in level.objects.keys():
			if level.objects[k] == code and k != c:
				same.append(k)
		if same.size() >= 2:
			level.objects.erase(same[0])
	level.objects[c] = code
	_changed()


# ---------- műveletek ----------
func _resize(dc: int, dr: int) -> void:
	level.resize(level.cols + dc, level.rows + dr)
	_changed()
	_refresh()


func _check() -> void:
	level.title = _name_edit.text.strip_edges()
	var errs := level.validate()
	if not errs.is_empty():
		_set_status("Nem játszható: " + " ".join(errs), BoardPainter.MARK)
		return
	var path := Solver.solve(level)
	if path.is_empty():
		solution.clear()
		_set_status("Nem megoldható. (Vagy túl bonyolult a megoldónak.)", BoardPainter.MARK)
	else:
		solution = Solver.path_cells(level, path)
		_set_status("Megoldható. A legrövidebb út %d lépés (zölddel)." % path.size(), BoardPainter.OK)
	queue_redraw()


func _test() -> void:
	level.title = _name_edit.text.strip_edges()
	var errs := level.validate()
	if not errs.is_empty():
		_set_status("Teszt előtt: " + " ".join(errs), BoardPainter.MARK)
		return
	test_requested.emit(level.copy())


func _save() -> void:
	level.title = _name_edit.text.strip_edges()
	if file_name == "":
		file_name = library.next_file_name()
	var path := library.save_level(level, file_name)
	if path == "":
		_set_status("Mentés sikertelen.", BoardPainter.MARK)
		return
	dirty = false
	var where := "a repóba" if path.begins_with("res://") else "erre az eszközre"
	_set_status("Mentve %s: %s" % [where, path], BoardPainter.OK)


func _copy() -> void:
	level.title = _name_edit.text.strip_edges()
	DisplayServer.clipboard_set(LevelLibrary.to_json(level))
	_set_status("A pálya JSON-ja a vágólapon. Bemásolhatod egy chatbe vagy fájlba.", BoardPainter.OK)


func _new() -> void:
	open_level(LevelData.new_empty(7, 9), "")
	_set_status("Új üres pálya. Rajzold meg a falakat!")


# ---------- UI ----------
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	_ui = UiKit.full_rect(Control.new())
	_ui.theme = UiKit.theme()
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)

	var top := VBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 24
	top.offset_right = -24
	top.offset_top = 24
	top.add_theme_constant_override("separation", 12)
	_ui.add_child(top)
	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 12)
	_name_edit = LineEdit.new()
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.placeholder_text = "Pálya neve"
	_name_edit.custom_minimum_size = Vector2(0, 70)
	_name_edit.text_changed.connect(func(_t): dirty = true)
	row1.add_child(_name_edit)
	row1.add_child(UiKit.button("Új", _new))
	top.add_child(row1)
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 10)
	row2.add_child(UiKit.label("Méret", 26, BoardPainter.INK_SOFT))
	row2.add_child(UiKit.button("Szél −", func(): _resize(-1, 0)))
	row2.add_child(UiKit.button("Szél +", func(): _resize(1, 0)))
	_size_lbl = UiKit.label("7 × 9", 28)
	_size_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_size_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row2.add_child(_size_lbl)
	row2.add_child(UiKit.button("Mag −", func(): _resize(0, -1)))
	row2.add_child(UiKit.button("Mag +", func(): _resize(0, 1)))
	top.add_child(row2)

	var bottom := VBoxContainer.new()
	bottom.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 24
	bottom.offset_right = -24
	bottom.offset_top = -BOTTOM_H + 10
	bottom.offset_bottom = -20
	bottom.add_theme_constant_override("separation", 12)
	_ui.add_child(bottom)
	_status = UiKit.label("", 24, BoardPainter.INK_SOFT)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(0, 66)
	bottom.add_child(_status)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	var group := ButtonGroup.new()
	for t in TOOLS:
		var b := UiKit.button(t[1])
		b.toggle_mode = true
		b.button_group = group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 66)
		b.add_theme_font_size_override("font_size", 26)
		b.button_pressed = t[0] == tool
		var id: String = t[0]
		b.pressed.connect(func(): tool = id)
		grid.add_child(b)
	bottom.add_child(grid)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	for a in [["Teszt", _test, true], ["Ellenőriz", _check, false], ["Mentés", _save, false], ["Másol", _copy, false], ["Vissza", func(): back_requested.emit(), false]]:
		var b2 := UiKit.button(a[0], a[1], a[2])
		b2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b2.add_theme_font_size_override("font_size", 25)
		b2.add_theme_constant_override("h_separation", 0)
		actions.add_child(b2)
	bottom.add_child(actions)


func set_active(on: bool) -> void:
	visible = on
	_ui.visible = on
	set_process_unhandled_input(on)
