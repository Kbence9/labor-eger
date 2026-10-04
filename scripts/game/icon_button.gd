class_name IconButton
extends Button
## Gomb kódból rajzolt ikonnal (nincs képfájl). Ha van felirat, az ikon fölötte, a felirat alatta.
## Ikonok: back, undo, redo, menu, minus, plus, up, down, copy, trash, check
## Eszközök: wall, brk, carve, erase és a pályaelem-kódok (S, E, H, W, F, C, T, A, B)

var icon_id := ""
var caption := ""
var painter := BoardPainter.new()


static func make(id: String, cap: String = "", cb: Callable = Callable(), min_size: Vector2 = Vector2(72, 72)) -> IconButton:
	var b := IconButton.new()
	b.icon_id = id
	b.caption = cap
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = min_size
	b.tooltip_text = cap
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


func _draw() -> void:
	var P := BoardPainter
	var col := P.PEN if not disabled else Color(P.INK_SOFT, 0.4)
	var c := size / 2.0
	var s := minf(size.x, size.y)
	if caption != "":
		c.y = size.y * 0.40
		s = minf(size.x, size.y * 0.78)
		var f := UiKit.F_HAND
		var fs := 21
		var tw := f.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2((size.x - tw) / 2.0, size.y - 9), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, P.INK if button_pressed else P.INK_SOFT)
	_icon(icon_id, c, s * 0.5, col)


func _icon(id: String, c: Vector2, r: float, col: Color) -> void:
	var P := BoardPainter
	var w := maxf(3.0, r * 0.11)
	painter.cell = r * 1.7
	match id:
		"back":
			draw_polyline(PackedVector2Array([c + Vector2(r * .25, -r * .5), c + Vector2(-r * .25, 0), c + Vector2(r * .25, r * .5)]), col, w, true)
		"up":
			draw_polyline(PackedVector2Array([c + Vector2(-r * .45, r * .2), c + Vector2(0, -r * .25), c + Vector2(r * .45, r * .2)]), col, w, true)
		"down":
			draw_polyline(PackedVector2Array([c + Vector2(-r * .45, -r * .2), c + Vector2(0, r * .25), c + Vector2(r * .45, -r * .2)]), col, w, true)
		"undo", "redo":
			var sg := 1.0 if id == "redo" else -1.0
			var pts := PackedVector2Array()
			for i in 13:
				var a := lerpf(PI * 1.05, PI * 2.1, i / 12.0)
				pts.append(c + Vector2(cos(a) * r * .42 * sg, sin(a) * r * .42 + r * .12))
			draw_polyline(pts, col, w, true)
			var tip := pts[pts.size() - 1]
			draw_polyline(PackedVector2Array([tip + Vector2(-r * .26 * sg, -r * .05), tip, tip + Vector2(-r * .02 * sg, -r * .28)]), col, w, true)
		"menu":
			for i in 3:
				draw_circle(c + Vector2((i - 1) * r * .38, 0), r * .09, col)
		"minus":
			draw_line(c + Vector2(-r * .4, 0), c + Vector2(r * .4, 0), col, w, true)
		"plus":
			draw_line(c + Vector2(-r * .4, 0), c + Vector2(r * .4, 0), col, w, true)
			draw_line(c + Vector2(0, -r * .4), c + Vector2(0, r * .4), col, w, true)
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-r * .4, 0), c + Vector2(-r * .1, r * .32), c + Vector2(r * .45, -r * .38)]), col, w, true)
		"copy":
			draw_rect(Rect2(c + Vector2(-r * .4, -r * .25), Vector2(r * .6, r * .68)), col, false, w * .8)
			draw_rect(Rect2(c + Vector2(-r * .2, -r * .45), Vector2(r * .6, r * .68)), col, false, w * .8)
		"trash":
			draw_line(c + Vector2(-r * .45, -r * .3), c + Vector2(r * .45, -r * .3), col, w, true)
			draw_polyline(PackedVector2Array([c + Vector2(-r * .32, -r * .3), c + Vector2(-r * .25, r * .45), c + Vector2(r * .25, r * .45), c + Vector2(r * .32, -r * .3)]), col, w * .8, true)
		# ---- szerkesztő-eszközök ----
		"wall":
			var a := c + Vector2(-r * .5, r * .35)
			var b := c + Vector2(r * .5, -r * .35)
			for d in [a, b, c + Vector2(-r * .5, -r * .35), c + Vector2(r * .5, r * .35)]:
				draw_circle(d, r * .06, P.RULE.darkened(0.2))
			painter.ink_line(self, a, Vector2(a.x, b.y), w * 1.1, P.INK)
			painter.ink_line(self, Vector2(a.x, b.y), b, w * 1.1, P.INK)
		"brk":
			painter.draw_bricks(self, c + Vector2(-r * .55, 0), c + Vector2(r * .55, 0))
		"carve":
			var pts2 := PackedVector2Array([c + Vector2(-r * .5, r * .3), c + Vector2(-r * .1, r * .3), c + Vector2(-r * .1, -r * .25), c + Vector2(r * .5, -r * .25)])
			draw_polyline(pts2, Color(P.OK, 0.75), w * 1.6, true)
			for p in pts2:
				draw_circle(p, r * .07, P.OK)
		"erase":
			draw_set_transform(c, -0.5, Vector2.ONE)
			draw_rect(Rect2(Vector2(-r * .5, -r * .22), Vector2(r * 1.0, r * .44)), Color("f0a6b4"))
			draw_rect(Rect2(Vector2(-r * .5, -r * .22), Vector2(r * .35, r * .44)), Color("7d8cc9"))
			draw_rect(Rect2(Vector2(-r * .5, -r * .22), Vector2(r * 1.0, r * .44)), P.INK, false, w * .6)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"S":
			BoardPainter.arrow_shape(self, c, -PI / 2, r * .5, P.OK, w)
		"E":
			BoardPainter.arrow_shape(self, c, -PI / 2, r * .5, P.EXIT, w)
		"H":
			painter.draw_hammer(self, c + Vector2(0, r * .05), r * .58, -0.6)
		"W":
			painter.draw_flask(self, c, r * .55)
		"F":
			painter.draw_fire(self, c + Vector2(0, r * .1), r * .62, 0.3)
		"C":
			painter.cell = r * 1.2
			painter.draw_crack(self, c, false)
		"T":
			painter.draw_cheese(self, c, r * .6)
		"A", "B":
			painter.draw_portal(self, c, r * .62, P.PORTAL[id], 0.4)
			var f := UiKit.F_BOLD
			var fs := int(r * .55)
			var tw := f.get_string_size(id, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(f, c + Vector2(-tw / 2.0, fs * .35), id, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, P.PORTAL[id].darkened(0.3))
