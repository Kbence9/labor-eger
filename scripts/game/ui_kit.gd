class_name UiKit
extends RefCounted
## Közös UI-építőkockák (téma, gombok, panelek) kódból, hogy ne kelljen kézzel .tscn-t írni.

static var _theme: Theme


static func theme() -> Theme:
	if _theme:
		return _theme
	var th := Theme.new()
	th.default_font_size = 30
	var btn := StyleBoxFlat.new()
	btn.bg_color = Color(0, 0, 0, 0)
	btn.border_color = Color("2c3e91")
	btn.set_border_width_all(3)
	btn.set_corner_radius_all(40)
	btn.set_content_margin_all(14)
	btn.content_margin_left = 12
	btn.content_margin_right = 12
	var btn_hover := btn.duplicate()
	btn_hover.bg_color = Color("2c3e91", 0.08)
	var btn_pressed := btn.duplicate()
	btn_pressed.bg_color = Color("2c3e91")
	th.set_stylebox("normal", "Button", btn)
	th.set_stylebox("hover", "Button", btn_hover)
	th.set_stylebox("pressed", "Button", btn_pressed)
	th.set_stylebox("hover_pressed", "Button", btn_pressed)
	th.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	th.set_color("font_color", "Button", Color("2c3e91"))
	th.set_color("font_hover_color", "Button", Color("2c3e91"))
	th.set_color("font_pressed_color", "Button", Color("f6f7f2"))
	th.set_color("font_hover_pressed_color", "Button", Color("f6f7f2"))
	th.set_color("font_focus_color", "Button", Color("2c3e91"))
	th.set_color("font_color", "Label", BoardPainter.INK)
	var le := StyleBoxFlat.new()
	le.bg_color = BoardPainter.PAPER
	le.border_color = BoardPainter.INK_SOFT
	le.set_border_width_all(2)
	le.set_corner_radius_all(10)
	le.set_content_margin_all(10)
	th.set_stylebox("normal", "LineEdit", le)
	th.set_stylebox("focus", "LineEdit", le)
	th.set_color("font_color", "LineEdit", BoardPainter.INK)
	_theme = th
	return th


static func button(text: String, cb: Callable = Callable(), solid: bool = false) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 72)
	if solid:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("2c3e91")
		sb.set_corner_radius_all(40)
		sb.set_content_margin_all(14)
		sb.content_margin_left = 22
		sb.content_margin_right = 22
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_color_override("font_color", Color("f6f7f2"))
		b.add_theme_color_override("font_hover_color", Color("f6f7f2"))
	if cb.is_valid():
		b.pressed.connect(cb)
	return b


static func label(text: String, size: int = 30, color: Color = BoardPainter.INK) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func card(border: Color = BoardPainter.INK) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = BoardPainter.PAPER
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 22
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 18
	sb.shadow_color = border
	sb.shadow_size = 0
	sb.shadow_offset = Vector2(6, 7)
	sb.set_content_margin_all(28)
	p.add_theme_stylebox_override("panel", sb)
	return p


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
