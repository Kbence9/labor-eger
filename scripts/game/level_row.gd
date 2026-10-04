class_name LevelRow
extends Button
## Egy sor a pályalistában, mint egy füzet tartalomjegyzéke:
## sorszám (írógép) · név (kézírás) · pontozott vezetővonal · állapot (pipa + legjobb idő / halálok / címke).

var number := 1
var title := ""
var done := false
var is_next := false
var best := -1.0
var deaths := 0
var tag := ""


static func make(n: int, t: String) -> LevelRow:
	var r := LevelRow.new()
	r.number = n
	r.title = t
	r.focus_mode = Control.FOCUS_NONE
	r.custom_minimum_size = Vector2(0, 78)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var empty := StyleBoxEmpty.new()
	var hover := InkBox.make(InkBox.Mode.FILL, BoardPainter.PEN, Color(BoardPainter.PEN, 0.06), 0.0, 0.0)
	r.add_theme_stylebox_override("normal", empty)
	r.add_theme_stylebox_override("hover", hover)
	r.add_theme_stylebox_override("pressed", hover)
	r.add_theme_stylebox_override("hover_pressed", hover)
	return r


static func fmt_time(sec: float) -> String:
	var m := int(sec / 60.0)
	return "%d:%04.1f" % [m, sec - m * 60]


func _draw() -> void:
	var P := BoardPainter
	var y := size.y * 0.5 + 12
	Notebook.text(self, Vector2(4, y), "%02d" % number, 26, P.INK_SOFT, "type")
	var nx := 62.0
	var f := UiKit.F_BOLD
	var fs := 36
	var shown := title
	var right_w := _status_width()
	var max_w := size.x - nx - right_w - 40
	while shown.length() > 3 and f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		shown = shown.substr(0, shown.length() - 2).strip_edges() + "…"
	var tw := f.get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	if is_next:
		var hl := PackedVector2Array([Vector2(nx - 6, y - 22), Vector2(nx + tw + 10, y - 25), Vector2(nx + tw + 6, y + 6), Vector2(nx - 10, y + 8)])
		draw_colored_polygon(hl, P.HIGHLIGHT)
	draw_string(f, Vector2(nx, y), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, P.INK)
	# pontozott vezetővonal
	var x := nx + tw + 16
	var x_end := size.x - right_w - 14
	while x < x_end:
		draw_circle(Vector2(x, y - 2), 1.7, Color(P.INK_SOFT, 0.6))
		x += 11
	_draw_status(Vector2(size.x - right_w, y))


func _status_width() -> float:
	if tag != "":
		return UiKit.F_HAND.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 4
	if done:
		return 150.0
	if deaths > 0:
		return 110.0
	return 10.0


func _draw_status(p: Vector2) -> void:
	var P := BoardPainter
	if tag != "":
		Notebook.text(self, p, tag, 24, P.INK_SOFT)
		return
	if done:
		draw_polyline(PackedVector2Array([p + Vector2(0, -12), p + Vector2(9, -2), p + Vector2(27, -26)]), P.OK, 4.0, true)
		Notebook.text(self, p + Vector2(38, 0), fmt_time(best), 24, P.INK, "type")
		return
	if deaths > 0:
		Notebook.text(self, p, "%d halál" % deaths, 24, P.MARK)
