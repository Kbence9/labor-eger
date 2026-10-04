extends Node
## Képernyők: főmenü, pályalista (játék / szerkesztés), játék, szerkesztő.

var library := LevelLibrary.new()
var game: LabGame
var editor: LabEditor
var menu_layer: CanvasLayer
var menu_root: Control
var _levels: Array = []
var _current_index := -1
var _testing_from_editor := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(BoardPainter.BG)
	game = LabGame.new()
	add_child(game)
	game.back_requested.connect(_on_game_back)
	game.next_requested.connect(_on_game_next)
	editor = LabEditor.new()
	editor.library = library
	add_child(editor)
	editor.test_requested.connect(_on_editor_test)
	editor.back_requested.connect(func(): show_level_list(true))
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)
	show_title()


func _hide_all() -> void:
	game.set_active(false)
	editor.set_active(false)
	if menu_root:
		menu_root.queue_free()
		menu_root = null


func _new_menu_root() -> VBoxContainer:
	menu_root = UiKit.full_rect(Control.new())
	menu_root.theme = UiKit.theme()
	menu_layer.add_child(menu_root)
	var center := UiKit.full_rect(CenterContainer.new())
	menu_root.add_child(center)
	var card := UiKit.card()
	card.custom_minimum_size = Vector2(620, 0)
	center.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	card.add_child(v)
	return v


func show_title() -> void:
	_hide_all()
	var v := _new_menu_root()
	v.add_child(UiKit.label("KÍSÉRLETI NAPLÓ · LABOR 7", 22, BoardPainter.INK_SOFT))
	v.add_child(UiKit.label("LABOR\nEGÉR", 96))
	var p := UiKit.label("Egy egér. Egy labirintus. Semmi magyarázat.\nJusson ki az alany a lila nyílnál.", 28)
	p.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(p)
	v.add_child(UiKit.button("Kísérlet indítása", func(): show_level_list(false), true))
	v.add_child(UiKit.button("Pályaszerkesztő", func(): show_level_list(true)))


func show_level_list(edit_mode: bool) -> void:
	_hide_all()
	_levels = library.list()
	var v := _new_menu_root()
	v.add_child(UiKit.label("Pályaszerkesztő" if edit_mode else "Kísérletek", 48))
	if edit_mode:
		var hint := UiKit.label("Válassz pályát, vagy kezdj egy újat.", 24, BoardPainter.INK_SOFT)
		v.add_child(hint)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 640)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 10)
	scroll.add_child(list)
	for i in _levels.size():
		var e: Dictionary = _levels[i]
		var tag := ""
		if e["source"] == "user":
			tag = "  · saját"
		elif e["source"] == "modified":
			tag = "  · módosított"
		var b := UiKit.button("%02d  %s%s" % [i + 1, e["name"], tag])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var idx := i
		if edit_mode:
			b.pressed.connect(func(): open_editor(idx))
		else:
			b.pressed.connect(func(): play_level(idx))
		list.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	if edit_mode:
		row.add_child(UiKit.button("Új pálya", func(): open_editor(-1), true))
	row.add_child(UiKit.button("Vissza", show_title))
	v.add_child(row)


func play_level(idx: int) -> void:
	var L := library.load_level(_levels[idx]["path"])
	if L == null:
		return
	_hide_all()
	_current_index = idx
	_testing_from_editor = false
	game.set_active(true)
	game.start(L, false, idx + 1 < _levels.size())


func open_editor(idx: int) -> void:
	_hide_all()
	editor.set_active(true)
	if idx < 0:
		editor.open_level(LevelData.new_empty(7, 9), "")
	else:
		var L := library.load_level(_levels[idx]["path"])
		editor.open_level(L, _levels[idx]["file"])


func _on_editor_test(L: LevelData) -> void:
	_hide_all()
	_testing_from_editor = true
	game.set_active(true)
	game.start(L, true, false)


func _on_game_back() -> void:
	if _testing_from_editor:
		_testing_from_editor = false
		game.set_active(false)
		editor.set_active(true)
	else:
		show_level_list(false)


func _on_game_next() -> void:
	if _current_index + 1 < _levels.size():
		play_level(_current_index + 1)
