class_name InkBox
extends StyleBox
## Kézzel húzott keret / szövegkiemelő / aláhúzás gombokhoz, kártyákhoz, mezőkhöz.
## A remegés a méretből és a seed-ből jön, így képkockáról képkockára stabil.

enum Mode { BOX, HIGHLIGHT, UNDERLINE, FILL }

var mode: Mode = Mode.BOX
var ink := Color("1e2233")
var fill := Color(0, 0, 0, 0)
var width := 3.0
var wobble := 2.2
var seed := 1
var shadow := Color(0, 0, 0, 0)
var shadow_offset := Vector2(5, 6)


static func make(m: Mode, ink_col: Color, fill_col: Color = Color(0, 0, 0, 0), w: float = 3.0, margin: float = 14.0) -> InkBox:
	var b := InkBox.new()
	b.mode = m
	b.ink = ink_col
	b.fill = fill_col
	b.width = w
	b.content_margin_left = margin + 6
	b.content_margin_right = margin + 6
	b.content_margin_top = margin
	b.content_margin_bottom = margin
	return b


func _h(i: int, rect: Rect2) -> float:
	var h := (int(rect.size.x) * 374761393 + int(rect.size.y) * 668265263 + i * 2147483647 + seed * 97) & 0x7fffffff
	h = ((h ^ (h >> 13)) * 1274126177) & 0x7fffffff
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0 - 0.5


func _corners(rect: Rect2, inset: float) -> PackedVector2Array:
	var r := rect.grow(-inset)
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	for i in 4:
		pts[i] += Vector2(_h(i * 2, rect), _h(i * 2 + 1, rect)) * wobble * 2.0
	return pts


static func _curve(a: Vector2, b: Vector2, bend: float, n: int = 8) -> PackedVector2Array:
	var mid := (a + b) / 2.0 + (b - a).orthogonal().normalized() * bend
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / n
		pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
	return pts


func _draw(to_canvas_item: RID, rect: Rect2) -> void:
	var rs := RenderingServer
	match mode:
		Mode.HIGHLIGHT:
			# szövegkiemelő: ferde, lekerekített végű csík a szöveg alsó kétharmadán
			var top := rect.position.y + rect.size.y * 0.30
			var bot := rect.end.y - rect.size.y * 0.06
			var sk := (bot - top) * 0.25
			var l := rect.position.x - 4.0
			var r := rect.end.x + 4.0
			var poly := PackedVector2Array()
			poly.append_array(_curve(Vector2(l + sk, top + _h(1, rect) * 4), Vector2(r + sk, top + _h(2, rect) * 4), _h(3, rect) * 3, 10))
			poly.append_array(_curve(Vector2(r - sk, bot), Vector2(l - sk, bot), _h(4, rect) * 3, 10))
			rs.canvas_item_add_polygon(to_canvas_item, poly, PackedColorArray([fill]))
		Mode.UNDERLINE:
			var y := rect.end.y - width
			var line := _curve(Vector2(rect.position.x, y + _h(1, rect) * 2), Vector2(rect.end.x, y + _h(2, rect) * 2), _h(3, rect) * 2.5, 10)
			if fill.a > 0.0:
				rs.canvas_item_add_rect(to_canvas_item, rect, fill)
			rs.canvas_item_add_polyline(to_canvas_item, line, PackedColorArray([ink]), width, true)
		_:
			var c := _corners(rect, width)
			if shadow.a > 0.0:
				var sp := PackedVector2Array()
				for p in c:
					sp.append(p + shadow_offset)
				rs.canvas_item_add_polygon(to_canvas_item, sp, PackedColorArray([shadow]))
			if fill.a > 0.0:
				rs.canvas_item_add_polygon(to_canvas_item, c, PackedColorArray([fill]))
			if mode == Mode.BOX:
				for i in 4:
					var a := c[i]
					var b := c[(i + 1) % 4]
					var dir := (b - a).normalized()
					var over := 2.0 + (_h(10 + i, rect) + 0.5) * 3.0
					var seg := _curve(a - dir * over * 0.4, b + dir * over, _h(20 + i, rect) * wobble * 1.4, 8)
					rs.canvas_item_add_polyline(to_canvas_item, seg, PackedColorArray([ink]), width, true)
