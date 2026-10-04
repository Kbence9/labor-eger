class_name Notebook
extends RefCounted
## A „Labornapló” rajzelemei: füzetoldal, pecsét, strigulák, golyóstoll, írógépes és kézírásos szöveg.

const DOT_STEP := 32.0
const MARGIN_X := 88.0


## Füzetoldal: pöttyök, margóvonal, lyukasztás. margin_k: a margóvonal kirajzolt hányada (0..1)
static func page(ci: CanvasItem, rect: Rect2, dots_alpha: float = 1.0, margin_k: float = 1.0, holes: bool = true) -> void:
	var P := BoardPainter
	ci.draw_rect(rect, P.BG)
	if dots_alpha > 0.0:
		var col := Color(P.PAGE_DOT, dots_alpha)
		var y := rect.position.y + DOT_STEP / 2.0
		while y < rect.end.y:
			var x := rect.position.x + DOT_STEP / 2.0
			while x < rect.end.x:
				ci.draw_circle(Vector2(x, y), 1.6, col)
				x += DOT_STEP
			y += DOT_STEP
	if margin_k > 0.0:
		var mx := rect.position.x + MARGIN_X
		ci.draw_line(Vector2(mx, rect.position.y), Vector2(mx, rect.position.y + rect.size.y * margin_k), P.MARGIN, 3.0)
	if holes:
		for k in [0.2, 0.5, 0.8]:
			var c := Vector2(rect.position.x + 38, rect.position.y + rect.size.y * k)
			ci.draw_circle(c, 13.0, P.HOLE)
			ci.draw_arc(c, 13.0, PI * 0.15, PI * 0.85, 10, Color(0, 0, 0, 0.35), 3.0, true)


## A pecsét kerete (a dupla szegély nélkül).
static func stamp_size(lines: PackedStringArray, size: int) -> Vector2:
	var w := 0.0
	for s in lines:
		w = maxf(w, UiKit.F_STAMP.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
	return Vector2(w + size * 0.55, size * 0.98 * lines.size() + size * 0.42)


## Gumibélyegző-lenyomat: dupla keret, Rubik Dirt felirat, elforgatva.
## scale > 1: még a levegőben van (érkezés közben), alpha: átlátszóság.
static func stamp(ci: CanvasItem, center: Vector2, lines: PackedStringArray, col: Color, size: int, rot: float, scale: float = 1.0, alpha: float = 0.92) -> Rect2:
	var f := UiKit.F_STAMP
	var lh := size * 0.98
	var box := stamp_size(lines, size)
	var c := Color(col, alpha)
	ci.draw_set_transform(center, rot, Vector2.ONE * scale)
	var r := Rect2(-box / 2.0, box)
	ci.draw_rect(r, c, false, maxf(3.0, size * 0.075))
	ci.draw_rect(r.grow(size * 0.11), c, false, maxf(2.0, size * 0.03))
	var y := r.position.y + size * 0.2 + f.get_ascent(size) * 0.92
	for s in lines:
		var sw := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
		ci.draw_string(f, Vector2(-sw / 2.0, y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, c)
		y += lh
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	return Rect2(center - box / 2.0, box)


## Strigulák (ötösével áthúzva). Visszaadja a kirajzolt szélességet.
static func tally(ci: CanvasItem, pos: Vector2, n: int, col: Color, h: float = 30.0, max_groups: int = 4) -> float:
	var x := pos.x
	var groups := mini(ceili(n / 5.0), max_groups)
	var left := mini(n, max_groups * 5)
	var w := 3.0
	for g in groups:
		var k := mini(5, left)
		left -= k
		var x0 := x
		for i in mini(k, 4):
			var jx := sin(g * 7.0 + i * 3.1) * 1.5
			ci.draw_line(Vector2(x + i * 8 + jx, pos.y), Vector2(x + i * 8 + 1.5, pos.y + h), col, w, true)
		if k == 5:
			ci.draw_line(Vector2(x0 - 4, pos.y + h * 0.78), Vector2(x0 + 30, pos.y + h * 0.22), col, w, true)
		x += 48
	return x - pos.x


## Golyóstoll a hegyével `tip` pontban (rajzolás közben látszik).
static func pen(ci: CanvasItem, tip: Vector2, ang: float = -2.35) -> void:
	var P := BoardPainter
	ci.draw_set_transform(tip, ang, Vector2.ONE)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(0, 0), Vector2(16, -6), Vector2(16, 6)]), Color("d9d4c7"))
	ci.draw_circle(Vector2(1.5, 0), 2.2, P.INK)
	ci.draw_rect(Rect2(Vector2(16, -8), Vector2(120, 16)), P.PEN)
	ci.draw_rect(Rect2(Vector2(16, -8), Vector2(26, 16)), Color("1d2c70"))
	ci.draw_rect(Rect2(Vector2(120, -10), Vector2(18, 20)), Color("1d2c70"))
	ci.draw_line(Vector2(50, -9), Vector2(112, -9), Color(1, 1, 1, 0.35), 3.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Szöveg az első n karakteréig (írógép / kézírás „előtűnése”).
static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, kind: String = "hand", n: int = -1, rot: float = 0.0) -> float:
	var f := UiKit.font(kind)
	var shown := s if n < 0 else s.substr(0, clampi(n, 0, s.length()))
	if rot != 0.0:
		ci.draw_set_transform(pos, rot, Vector2.ONE)
		ci.draw_string(f, Vector2.ZERO, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	else:
		ci.draw_string(f, pos, shown, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
	return f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
