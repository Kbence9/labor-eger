class_name UiKit
extends RefCounted
## Közös UI-építőkockák (téma, gombok, kártyák, ablakok) kódból, „Labornapló” stílusban:
## kézírás (Kalam), írógépes laborűrlap (Special Elite), pecsét (Rubik Dirt), golyóstoll-kék gombok.

const F_HAND := preload("res://assets/fonts/Kalam-Regular.ttf")
const F_BOLD := preload("res://assets/fonts/Kalam-Bold.ttf")
const F_TYPE := preload("res://assets/fonts/SpecialElite-Regular.ttf")
const F_STAMP := preload("res://assets/fonts/RubikDirt-Regular.ttf")

static var _theme: Theme


static func font(kind: String) -> Font:
	match kind:
		"bold":
			return F_BOLD
		"type":
			return F_TYPE
		"stamp":
			return F_STAMP
	return F_HAND


static func theme() -> Theme:
	if _theme:
		return _theme
	var P := BoardPainter
	var th := Theme.new()
	th.default_font = F_HAND
	th.default_font_size = 30

	# gomb: tollal húzott keret a lapon
	var btn := InkBox.make(InkBox.Mode.BOX, P.PEN, Color(P.PAPER, 0.92), 3.0, 10.0)
	var btn_hover := InkBox.make(InkBox.Mode.BOX, P.PEN, Color(P.PAPER, 0.92).blend(Color(P.PEN, 0.08)), 3.0, 10.0)
	var btn_pressed := InkBox.make(InkBox.Mode.BOX, P.INK, P.HIGHLIGHT, 3.0, 10.0)
	var btn_disabled := InkBox.make(InkBox.Mode.BOX, Color(P.INK_SOFT, 0.35), Color(P.PAPER, 0.6), 2.0, 10.0)
	th.set_stylebox("normal", "Button", btn)
	th.set_stylebox("hover", "Button", btn_hover)
	th.set_stylebox("pressed", "Button", btn_pressed)
	th.set_stylebox("hover_pressed", "Button", btn_pressed)
	th.set_stylebox("disabled", "Button", btn_disabled)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_font("font", "Button", F_BOLD)
	th.set_color("font_color", "Button", P.PEN)
	th.set_color("font_hover_color", "Button", P.PEN)
	th.set_color("font_pressed_color", "Button", P.INK)
	th.set_color("font_hover_pressed_color", "Button", P.INK)
	th.set_color("font_focus_color", "Button", P.PEN)
	th.set_color("font_disabled_color", "Button", Color(P.INK_SOFT, 0.45))

	th.set_color("font_color", "Label", P.INK)

	# szövegmező: kitöltendő sor egy laborűrlapon
	var le := InkBox.make(InkBox.Mode.UNDERLINE, P.INK_SOFT, Color(0, 0, 0, 0), 2.0, 6.0)
	le.content_margin_left = 4
	var le_focus := InkBox.make(InkBox.Mode.UNDERLINE, P.PEN, Color(0, 0, 0, 0), 3.0, 6.0)
	le_focus.content_margin_left = 4
	th.set_stylebox("normal", "LineEdit", le)
	th.set_stylebox("focus", "LineEdit", le_focus)
	th.set_font("font", "LineEdit", F_BOLD)
	th.set_font_size("font_size", "LineEdit", 36)
	th.set_color("font_color", "LineEdit", P.PEN)
	th.set_color("font_placeholder_color", "LineEdit", Color(P.INK_SOFT, 0.6))
	th.set_color("caret_color", "LineEdit", P.PEN)
	th.set_color("selection_color", "LineEdit", P.HIGHLIGHT)

	# görgetősáv: vékony ceruzavonal
	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(P.INK_SOFT, 0.45)
	grab.set_corner_radius_all(4)
	grab.content_margin_left = 3
	grab.content_margin_right = 3
	var track := StyleBoxEmpty.new()
	track.content_margin_left = 3
	track.content_margin_right = 3
	th.set_stylebox("scroll", "VScrollBar", track)
	th.set_stylebox("grabber", "VScrollBar", grab)
	th.set_stylebox("grabber_highlight", "VScrollBar", grab)
	th.set_stylebox("grabber_pressed", "VScrollBar", grab)
	_theme = th
	return th


## kind: "ink" (keretes), "primary" (szövegkiemelős fő gomb), "text" (csak tollal írt szöveg)
static func button(text: String, cb: Callable = Callable(), kind: String = "ink") -> Button:
	var P := BoardPainter
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 72)
	match kind:
		"primary":
			var hl := InkBox.make(InkBox.Mode.HIGHLIGHT, P.INK, P.HIGHLIGHT, 3.0, 12.0)
			hl.seed = text.length() + 3
			var hl_pressed := InkBox.make(InkBox.Mode.HIGHLIGHT, P.INK, Color(P.HIGHLIGHT, 1.0).darkened(0.12), 3.0, 12.0)
			hl_pressed.seed = hl.seed
			b.add_theme_stylebox_override("normal", hl)
			b.add_theme_stylebox_override("hover", hl)
			b.add_theme_stylebox_override("pressed", hl_pressed)
			b.add_theme_stylebox_override("hover_pressed", hl_pressed)
			for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
				b.add_theme_color_override(k, P.INK)
		"text":
			var empty := StyleBoxEmpty.new()
			empty.content_margin_left = 6
			empty.content_margin_right = 6
			var under := InkBox.make(InkBox.Mode.UNDERLINE, Color(P.PEN, 0.5), Color(0, 0, 0, 0), 2.0, 0.0)
			under.content_margin_left = 6
			under.content_margin_right = 6
			var press := InkBox.make(InkBox.Mode.HIGHLIGHT, P.INK, Color(P.HIGHLIGHT, 0.5), 2.0, 0.0)
			press.content_margin_left = 6
			press.content_margin_right = 6
			b.add_theme_stylebox_override("normal", empty)
			b.add_theme_stylebox_override("hover", under)
			b.add_theme_stylebox_override("pressed", press)
			b.add_theme_stylebox_override("hover_pressed", press)
			b.add_theme_font_override("font", F_HAND)
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func label(text: String, size: int = 30, color: Color = BoardPainter.INK, kind: String = "hand") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Papírcetli a füzetoldalon: tollal húzott keret, enyhe árnyék.
static func card(border: Color = BoardPainter.INK) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := InkBox.make(InkBox.Mode.BOX, border, BoardPainter.PAPER, 3.0, 26.0)
	sb.shadow = Color(BoardPainter.INK, 0.12)
	sb.seed = 7
	p.add_theme_stylebox_override("panel", sb)
	return p


## Pecsét-felirat (pl. SIKERES): Rubik Dirt, enyhén elforgatva.
static func stamp(text: String, color: Color, size: int = 48, rot_deg: float = -4.0) -> Label:
	var l := label(text, size, Color(color, 0.9), "stamp")
	l.rotation_degrees = rot_deg
	return l


static func full_rect(c: Control) -> Control:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return c


static func margin(child: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(child)
	return m


## Modális ablak (cetli a lap közepén). options: [[felirat, Callable, kind], ...]
## Bármelyik gomb bezárja az ablakot, utána hívja a callable-t.
static func modal(host: Control, title: String, text: String, options: Array) -> Control:
	var root := full_rect(Control.new())
	root.theme = theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := full_rect(ColorRect.new())
	dim.color = Color(BoardPainter.BG, 0.78)
	root.add_child(dim)
	var center := full_rect(CenterContainer.new())
	root.add_child(center)
	var c := card(BoardPainter.INK)
	c.custom_minimum_size = Vector2(600, 0)
	center.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	c.add_child(v)
	var h := label(title, 40, BoardPainter.INK, "bold")
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(h)
	if text != "":
		var p := label(text, 28, BoardPainter.INK_SOFT)
		p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(p)
	for o in options:
		var cb: Callable = o[1]
		var kind: String = o[2] if o.size() > 2 else "ink"
		var b := button(o[0], Callable(), kind)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT if kind == "text" else HORIZONTAL_ALIGNMENT_CENTER
		var close := func() -> void:
			root.queue_free()
			if cb.is_valid():
				cb.call()
		b.pressed.connect(close)
		v.add_child(b)
	host.add_child(root)
	return root
