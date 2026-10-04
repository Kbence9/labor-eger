class_name BoardPainter
extends RefCounted
## A pálya kirajzolása bármely CanvasItem-re (játék és szerkesztő közös).
## Pöttyös papír, kézzel húzott falak, tárgyak, egér.

const PAPER := Color("f6f7f2")      # a pálya lapja
const BG := Color("e6ebdf")         # a füzetoldal (halvány mérnöki zöld)
const PAGE_DOT := Color("b9c3b4")   # pöttyök a füzetoldalon
const PEN := Color("2b3f9e")        # golyóstoll: gombok, kézírásos értékek
const HIGHLIGHT := Color("f5e54b", 0.85)  # szövegkiemelő: fő gomb, kijelölt eszköz
const MARGIN := Color("d98a82")     # margóvonal
const HOLE := Color("2a2d33")       # lyukasztás a lap szélén
const INK := Color("1e2233")
const INK_SOFT := Color("5d6577")
const RULE := Color("c9d0cf")
const MARK := Color("c8352e")
const OK := Color("2f8a4a")
const EXIT := Color("7a3fa0")
const BRICK := Color("b4573f")
const PORTAL := {"A": Color("e0679b"), "B": Color("18a3a0")}

var origin := Vector2.ZERO
var cell := 40.0
var sheet := Rect2()
var level: LevelData
var seed := 1


func fit(L: LevelData, rect: Rect2, pad_cells: float = 1.3) -> void:
	level = L
	cell = floorf(minf(rect.size.x / (L.cols + pad_cells), rect.size.y / (L.rows + pad_cells)))
	cell = maxf(cell, 12.0)
	var board := Vector2(L.cols, L.rows) * cell
	origin = (rect.position + (rect.size - board) / 2.0).floor()
	sheet = Rect2(origin - Vector2.ONE * cell * pad_cells / 2.0, board + Vector2.ONE * cell * pad_cells)


# ---------- geometria ----------
func center(c: Vector2) -> Vector2:
	return origin + (c + Vector2(0.5, 0.5)) * cell


func cell_at(p: Vector2) -> Vector2i:
	var q := (p - origin) / cell
	return Vector2i(floori(q.x), floori(q.y))


func nearest_dot(p: Vector2) -> Vector2i:
	var q := (p - origin) / cell
	return Vector2i(roundi(q.x), roundi(q.y))


func dot_pos(d: Vector2i) -> Vector2:
	return origin + Vector2(d) * cell


func _h(a: int, b: int, c: int) -> float:
	var h := (a * 374761393 + b * 668265263 + c * 2147483647 + seed * 97) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0


func wob_dot(x: int, y: int) -> Vector2:
	return dot_pos(Vector2i(x, y)) + Vector2(_h(x, y, 1) - 0.5, _h(y, x, 7) - 0.5) * cell * 0.07


static func ellipse(c: Vector2, rx: float, ry: float, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


static func quad(p0: Vector2, p1: Vector2, p2: Vector2, n: int = 8) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	return pts


static func closed(pts: PackedVector2Array) -> PackedVector2Array:
	var o := pts.duplicate()
	o.append(pts[0])
	return o


# ---------- teljes tábla ----------
## opts: markers (Array of Vector2i), shake_cell (Vector2i), path (Array[Vector2i]), show_hidden (bool)
func draw_board(ci: CanvasItem, s: GameState, t: float, opts: Dictionary = {}) -> void:
	var L := level
	ci.draw_rect(sheet, PAPER)
	# pöttyös papír
	var dr := maxf(1.2, cell * 0.035)
	for y in range(-1, L.rows + 2):
		for x in range(-1, L.cols + 2):
			var p := dot_pos(Vector2i(x, y))
			if sheet.has_point(p):
				ci.draw_circle(p, dr, RULE)
	# padló
	for c in s.cracks:
		if s.cracks[c] == "hole":
			draw_hole(ci, center(Vector2(c)))
		else:
			var shaking: bool = opts.get("shake_cell", Vector2i(-99, -99)) == c
			draw_crack(ci, center(Vector2(c)), shaking)
	for m in opts.get("markers", []):
		draw_x(ci, center(Vector2(m)), cell * 0.16, Color(MARK, 0.55))
	# portálok
	for c in L.objects:
		var v: String = L.objects[c]
		if v == "A" or v == "B":
			draw_portal(ci, center(Vector2(c)), cell * 0.4, PORTAL[v], t)
	# útvonal (szerkesztő)
	var path: Array = opts.get("path", [])
	if path.size() > 1:
		var pts := PackedVector2Array()
		for c in path + [Vector2i(-1, -1)]:
			if c == Vector2i(-1, -1):
				if pts.size() > 1:
					ci.draw_polyline(pts, Color(OK, 0.45), maxf(3.0, cell * 0.12), true)
				pts = PackedVector2Array()
			else:
				pts.append(center(Vector2(c)))
	_draw_walls(ci, s)
	_draw_arrows(ci)
	# tárgyak, csapdák, tűz
	for c in s.items:
		var bob := sin(t * 3.0 + c.x) * cell * 0.02
		if s.items[c] == "H":
			draw_hammer(ci, center(Vector2(c)) + Vector2(0, bob), cell * 0.32, -0.6)
		else:
			draw_flask(ci, center(Vector2(c)) + Vector2(0, bob), cell * 0.3)
	for c in s.traps:
		draw_cheese(ci, center(Vector2(c)), cell * 0.32)
	for c in s.fires:
		draw_fire(ci, center(Vector2(c)) + Vector2(0, cell * 0.05), cell * 0.36, t)
	if opts.get("tape", true):
		draw_tape(ci)


## Ragasztószalag a lap két felső sarkán (a pálya egy füzetbe ragasztott lap).
func draw_tape(ci: CanvasItem) -> void:
	var tw := clampf(cell * 1.5, 46.0, 96.0)
	var th := tw * 0.36
	for k in [[sheet.position, -0.75], [Vector2(sheet.end.x, sheet.position.y), 0.75]]:
		var p: Vector2 = k[0]
		ci.draw_set_transform(p, k[1], Vector2.ONE)
		var r := Rect2(Vector2(-tw / 2.0, -th / 2.0), Vector2(tw, th))
		ci.draw_rect(r, Color(0.89, 0.83, 0.64, 0.8))
		ci.draw_rect(r, Color(0.7, 0.62, 0.42, 0.35), false, 1.5)
		for i in 5:
			var x := r.position.x + r.size.x * (i + 0.5) / 5.0
			ci.draw_line(Vector2(x, r.position.y), Vector2(x + 2, r.end.y), Color(1, 1, 1, 0.18), 2.0)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_walls(ci: CanvasItem, s: GameState) -> void:
	var L := level
	var lw := maxf(2.0, cell * 0.085)
	var gaps := {}
	if L.exit_cell.x >= 0:
		gaps[LevelData.ck(L.exit_cell) + outer_side(L.exit_cell)] = true
	if L.start.x >= 0:
		gaps[LevelData.ck(L.start) + outer_side(L.start)] = true
	for y in L.rows:
		for x in L.cols:
			var c := Vector2i(x, y)
			var edges := [["R", Vector2i(x + 1, y), Vector2i(x + 1, y + 1)], ["D", Vector2i(x, y + 1), Vector2i(x + 1, y + 1)]]
			if y == 0:
				edges.append(["U", Vector2i(x, y), Vector2i(x + 1, y)])
			if x == 0:
				edges.append(["L", Vector2i(x, y), Vector2i(x, y + 1)])
			for e in edges:
				var d: String = e[0]
				var kind := s.edge(L, c, d)
				if kind == "open":
					continue
				var a: Vector2i = e[1]
				var b: Vector2i = e[2]
				if kind == "brk":
					draw_bricks(ci, dot_pos(a), dot_pos(b))
					continue
				if gaps.has(LevelData.ck(c) + d):
					continue
				ink_line(ci, wob_dot(a.x, a.y), wob_dot(b.x, b.y), lw, INK)


func outer_side(c: Vector2i) -> String:
	if c.y == 0:
		return "U"
	if c.y == level.rows - 1:
		return "D"
	if c.x == 0:
		return "L"
	if c.x == level.cols - 1:
		return "R"
	return ""


func _draw_arrows(ci: CanvasItem) -> void:
	var L := level
	if L.exit_cell.x >= 0:
		var side := outer_side(L.exit_cell)
		if side != "":
			draw_arrow(ci, L.exit_cell, side, EXIT, false)
		else:
			draw_ring_mark(ci, center(Vector2(L.exit_cell)), EXIT)
	if L.start.x >= 0:
		var side2 := outer_side(L.start)
		if side2 != "":
			draw_arrow(ci, L.start, side2, OK, true)
		else:
			draw_ring_mark(ci, center(Vector2(L.start)), OK)


# ---------- primitívek ----------
func ink_line(ci: CanvasItem, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	var mid := (a + b) / 2.0 + Vector2(_h(int(a.x), int(b.y), 3) - 0.5, _h(int(b.x), int(a.y), 5) - 0.5) * cell * 0.05
	ci.draw_polyline(quad(a, mid, b, 6), col, w, true)
	ci.draw_circle(a, w / 2.0, col)
	ci.draw_circle(b, w / 2.0, col)


func draw_x(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	var w := maxf(2.0, cell * 0.05)
	ci.draw_line(p + Vector2(-r, -r), p + Vector2(r, r), col, w, true)
	ci.draw_line(p + Vector2(r, -r), p + Vector2(-r, r), col, w, true)


func draw_ring_mark(ci: CanvasItem, p: Vector2, col: Color) -> void:
	ci.draw_arc(p, cell * 0.38, 0, TAU, 32, col, maxf(2.0, cell * 0.07), true)


func draw_arrow(ci: CanvasItem, c: Vector2i, side: String, col: Color, inward: bool) -> void:
	var dv := Vector2(LevelData.DIRS[side])
	var base := center(Vector2(c)) + dv * cell * 0.95
	var ang := dv.angle() + (PI if inward else 0.0)
	arrow_shape(ci, base, ang, cell * 0.32, col, maxf(2.0, cell * 0.07))


## Körvonalas nyíl (start/kijárat jele, ikonok)
static func arrow_shape(ci: CanvasItem, base: Vector2, ang: float, s1: float, col: Color, w: float) -> void:
	var local := PackedVector2Array([Vector2(-s1, -s1 * .35), Vector2(s1 * .1, -s1 * .35), Vector2(s1 * .1, -s1 * .8), Vector2(s1, 0), Vector2(s1 * .1, s1 * .8), Vector2(s1 * .1, s1 * .35), Vector2(-s1, s1 * .35), Vector2(-s1, -s1 * .35)])
	var pts := PackedVector2Array()
	for q in local:
		pts.append(base + q.rotated(ang))
	ci.draw_polyline(pts, col, w, true)


func draw_bricks(ci: CanvasItem, a: Vector2, b: Vector2) -> void:
	var horiz := absf(a.y - b.y) < absf(a.x - b.x)
	var th := cell * 0.2
	var r: Rect2
	if horiz:
		r = Rect2(Vector2(minf(a.x, b.x), a.y - th / 2), Vector2(absf(b.x - a.x), th))
	else:
		r = Rect2(Vector2(a.x - th / 2, minf(a.y, b.y)), Vector2(th, absf(b.y - a.y)))
	ci.draw_rect(r, BRICK)
	ci.draw_rect(r, INK, false, maxf(1.2, cell * 0.04))
	var mortar := Color("f0d9c8")
	var mw := maxf(1.0, cell * 0.025)
	if horiz:
		ci.draw_line(Vector2(r.position.x, a.y), Vector2(r.end.x, a.y), mortar, mw)
		for i in range(1, 4):
			var x := r.position.x + r.size.x * i / 4.0
			ci.draw_line(Vector2(x, r.position.y), Vector2(x, a.y), mortar, mw)
			var x2 := r.position.x + r.size.x * (i - 0.5) / 4.0
			ci.draw_line(Vector2(x2, a.y), Vector2(x2, r.end.y), mortar, mw)
	else:
		ci.draw_line(Vector2(a.x, r.position.y), Vector2(a.x, r.end.y), mortar, mw)
		for i in range(1, 4):
			var y := r.position.y + r.size.y * i / 4.0
			ci.draw_line(Vector2(r.position.x, y), Vector2(a.x, y), mortar, mw)
			var y2 := r.position.y + r.size.y * (i - 0.5) / 4.0
			ci.draw_line(Vector2(a.x, y2), Vector2(r.end.x, y2), mortar, mw)


func draw_hammer(ci: CanvasItem, p: Vector2, r: float, rot: float) -> void:
	ci.draw_set_transform(p, rot, Vector2.ONE)
	ci.draw_line(Vector2(0, r * 0.85), Vector2(0, -r * 0.35), Color("7a4a22"), r * 0.22, true)
	var head := Rect2(Vector2(-r * 0.62, -r * 0.78), Vector2(r * 1.24, r * 0.46))
	ci.draw_rect(head, Color("e07a2b"))
	ci.draw_rect(head, INK, false, maxf(1.2, r * 0.08))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_flask(ci: CanvasItem, p: Vector2, r: float) -> void:
	var outline := PackedVector2Array([Vector2(-.2, -.85), Vector2(-.2, -.25), Vector2(-.72, .7), Vector2(.72, .7), Vector2(.2, -.25), Vector2(.2, -.85)])
	var water := PackedVector2Array([Vector2(-.364, .05), Vector2(.364, .05), Vector2(.72, .7), Vector2(-.72, .7)])
	var o := PackedVector2Array()
	for q in outline:
		o.append(p + q * r)
	var w := PackedVector2Array()
	for q in water:
		w.append(p + q * r)
	ci.draw_colored_polygon(o, Color(1, 1, 1, 0.7))
	ci.draw_colored_polygon(w, Color("3d8be0"))
	ci.draw_polyline(closed(o), INK, maxf(1.2, r * 0.09), true)
	ci.draw_line(p + Vector2(-.32, -.85) * r, p + Vector2(.32, -.85) * r, INK, maxf(1.2, r * 0.09), true)


func draw_fire(ci: CanvasItem, p: Vector2, r: float, t: float) -> void:
	var flames := [[0.0, -0.28, Color("d8432b"), 0.85], [1.7, 0.3, Color("d8432b"), 0.75], [3.1, 0.0, Color("f08a24"), 1.05], [4.2, 0.0, Color("ffd54a"), 0.55]]
	for f in flames:
		var k: float = f[0]
		var sx: float = f[1]
		var hh: float = f[3]
		var wob := sin(t * 11.0 + k) * 0.12 + sin(t * 19.0 + k * 2.0) * 0.06
		var bx := p.x + sx * r
		var tip := Vector2(bx + wob * r, p.y - r * hh)
		var left := quad(Vector2(bx - r * .42, p.y + r * .6), Vector2(bx - r * .5, p.y - r * .1), tip, 6)
		var right := quad(tip, Vector2(bx + r * .5, p.y - r * .1), Vector2(bx + r * .42, p.y + r * .6), 6)
		var pts := left
		pts.append_array(right.slice(1))
		ci.draw_colored_polygon(pts, f[2])


func draw_cheese(ci: CanvasItem, p: Vector2, r: float) -> void:
	var front := PackedVector2Array([Vector2(-.75, .5), Vector2(.75, .5), Vector2(.75, -.05), Vector2(-.75, .1)])
	var top := PackedVector2Array([Vector2(-.75, .1), Vector2(.3, -.55), Vector2(.75, -.05)])
	var f := PackedVector2Array()
	for q in front:
		f.append(p + q * r)
	var tp := PackedVector2Array()
	for q in top:
		tp.append(p + q * r)
	var w := maxf(1.2, r * 0.08)
	ci.draw_colored_polygon(f, Color("f2c94c"))
	ci.draw_colored_polygon(tp, Color("f7dc7a"))
	ci.draw_polyline(closed(f), INK, w, true)
	ci.draw_polyline(closed(tp), INK, w, true)
	for h in [Vector3(-.35, .3, .12), Vector3(.2, .28, .09), Vector3(.5, .1, .07)]:
		ci.draw_circle(p + Vector2(h.x, h.y) * r, h.z * r, Color("d9a92e"))


func draw_portal(ci: CanvasItem, p: Vector2, r: float, col: Color, t: float) -> void:
	for i in 3:
		var rx := r * (0.85 - i * 0.25)
		var ry := r * (0.6 - i * 0.17)
		var c := Color(col, 1.0 - i * 0.28)
		var off := t * (1.5 if i % 2 == 0 else -1.5)
		for seg in 6:
			var a0 := off + TAU * seg / 6.0
			var pts := PackedVector2Array()
			for j in 7:
				var a := a0 + (TAU / 6.0) * 0.62 * j / 6.0
				pts.append(p + Vector2(cos(a) * rx, sin(a) * ry))
			ci.draw_polyline(pts, c, maxf(1.5, r * 0.12), true)


func draw_crack(ci: CanvasItem, p: Vector2, shaking: bool) -> void:
	var j := Vector2.ZERO
	if shaking:
		j = Vector2(randf() - 0.5, randf() - 0.5) * cell * 0.08
	var c := p + j
	var s := cell
	ci.draw_rect(Rect2(c - Vector2.ONE * (s / 2 - 2), Vector2.ONE * (s - 4)), Color(0.47, 0.44, 0.38, 0.14))
	var col := Color(0.27, 0.25, 0.22, 0.7)
	var w := maxf(1.0, s * 0.035)
	ci.draw_polyline(PackedVector2Array([c + Vector2(-.4, -.1) * s, c + Vector2(-.1, -.02) * s, c + Vector2(0, -.3) * s, c + Vector2(.15, .05) * s, c + Vector2(.4, .15) * s]), col, w, true)
	ci.draw_line(c + Vector2(-.1, -.02) * s, c + Vector2(-.2, .32) * s, col, w, true)
	ci.draw_line(c + Vector2(.15, .05) * s, c + Vector2(.08, .38) * s, col, w, true)


func draw_hole(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_colored_polygon(ellipse(p, cell * .42, cell * .36), Color("23262b"))
	ci.draw_colored_polygon(ellipse(p + Vector2(0, cell * .05), cell * .3, cell * .24), Color("0d0e10"))


func draw_mouse(ci: CanvasItem, p: Vector2, dir: String, t: float, held: String, dead: bool, scale: float = 1.0, stretch: Vector2 = Vector2.ONE) -> void:
	var ang := Vector2(LevelData.DIRS.get(dir, Vector2i(0, -1))).angle()
	var r := cell * 0.3
	var a := 0.55 if dead else 1.0
	var line := maxf(1.3, r * 0.09)
	ci.draw_set_transform(p, ang, Vector2.ONE * scale * stretch)
	# farok
	var tail := PackedVector2Array()
	for i in 9:
		var k := i / 8.0
		tail.append(Vector2(-r * (0.9 + 1.1 * k), sin(t * 8.0 + k * 4.0) * r * 0.35 * k))
	ci.draw_polyline(tail, Color(Color("e7a0ae"), a), maxf(1.5, r * 0.12), true)
	# test
	var body := ellipse(Vector2(-r * .1, 0), r * .95, r * .68)
	ci.draw_colored_polygon(body, Color(Color("a7adb3"), a))
	ci.draw_polyline(closed(body), Color(INK, a), line, true)
	var head := quad(Vector2(r * .45, -r * .5), Vector2(r * 1.4, -r * .2), Vector2(r * 1.3, 0), 6)
	head.append_array(quad(Vector2(r * 1.3, 0), Vector2(r * 1.4, r * .2), Vector2(r * .45, r * .5), 6).slice(1))
	ci.draw_colored_polygon(head, Color(Color("a7adb3"), a))
	ci.draw_polyline(closed(head), Color(INK, a), line, true)
	for sg in [-1.0, 1.0]:
		var ear := ellipse(Vector2(r * .45, sg * r * .55), r * .3, r * .26, 16)
		ci.draw_colored_polygon(ear, Color(Color("a7adb3"), a))
		ci.draw_polyline(closed(ear), Color(INK, a), line, true)
		ci.draw_colored_polygon(ellipse(Vector2(r * .45, sg * r * .55), r * .17, r * .14, 12), Color(Color("f2a7b5"), a))
		var e := Vector2(r * .88, sg * r * .2)
		if dead:
			var q := r * 0.08
			ci.draw_line(e + Vector2(-q, -q), e + Vector2(q, q), INK, line)
			ci.draw_line(e + Vector2(q, -q), e + Vector2(-q, q), INK, line)
		else:
			ci.draw_circle(e, r * 0.08, INK)
	ci.draw_circle(Vector2(r * 1.32, 0), r * 0.1, Color(Color("e46a85"), a))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if held != "" and not dead:
		var bob := sin(t * 6.0) * cell * 0.03
		var hp := p + Vector2(cell * 0.28, -cell * 0.3 + bob)
		if held == "H":
			draw_hammer(ci, hp, cell * 0.2, -0.4)
		else:
			draw_flask(ci, hp, cell * 0.19)
