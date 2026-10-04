extends Node
## Képernyők: nyitó animáció + főmenü (TitleScreen), pályalista (játék / szerkesztés), játék, szerkesztő.
## A haladás (teljesített pályák, halálok) az eszközön: Progress (user://progress.json).

var library := LevelLibrary.new()
var progress: Progress
var title: TitleScreen
var game: LabGame
var editor: LabEditor
var menu_layer: CanvasLayer
var menu_root: Control
var _levels: Array = []
var _current_index := -1
var _testing_from_editor := false
var _back_to_title := false
var _list_edit_mode := false
var _list_scroll := 0


func _ready() -> void:
	RenderingServer.set_default_clear_color(BoardPainter.BG)
	progress = Progress.load_from()
	game = LabGame.new()
	add_child(game)
	game.back_requested.connect(_on_game_back)
	game.next_requested.connect(_on_game_next)
	game.died.connect(_on_game_died)
	game.won.connect(_on_game_won)
	editor = LabEditor.new()
	editor.library = library
	add_child(editor)
	editor.test_requested.connect(_on_editor_test)
	editor.back_requested.connect(func(): show_level_list(true))
	title = TitleScreen.new()
	add_child(title)
	title.continue_requested.connect(continue_game)
	title.levels_requested.connect(func(): show_level_list(false))
	title.editor_requested.connect(func(): show_level_list(true))
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)
	show_title(true)


func _hide_all() -> void:
	game.set_active(false)
	editor.set_active(false)
	title.set_active(false)
	if menu_root:
		menu_root.queue_free()
		menu_root = null


func show_title(intro: bool = false) -> void:
	_hide_all()
	_levels = library.list()
	title.show_menu(intro, progress, maxi(0, progress.next_index(library.files())))


func continue_game() -> void:
	_levels = library.list()
	var idx := progress.next_index(library.files())
	if idx < 0:
		return
	play_level(idx, true)


# ---------- pályalista ----------
func show_level_list(edit_mode: bool) -> void:
	_hide_all()
	_list_edit_mode = edit_mode
	_levels = library.list()
	menu_root = UiKit.full_rect(Control.new())
	menu_root.theme = UiKit.theme()
	menu_layer.add_child(menu_root)
	menu_root.add_child(NotebookPage.new())
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	menu_root.add_child(UiKit.full_rect(UiKit.margin(v, 104, 34, 28, 30)))

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	head.add_child(IconButton.make("back", "", func(): show_title(false)))
	var h := UiKit.label("Pályaszerkesztő" if edit_mode else "Pályák", 58, BoardPainter.INK, "bold")
	head.add_child(h)
	v.add_child(head)
	var sub := "Koppints egy pályára a szerkesztéshez. A nyilakkal a sorrendet állítod." if edit_mode else "Tartalomjegyzék. A kiemelt a következő kísérlet."
	var sl := UiKit.label(sub, 24, BoardPainter.INK_SOFT, "type")
	sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(sl)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 4)
	scroll.add_child(list)
	var files := library.files()
	var next_i := progress.next_index(files)
	for i in _levels.size():
		var e: Dictionary = _levels[i]
		var f: String = e["file"]
		var row := LevelRow.make(i + 1, e["name"])
		var idx := i
		if edit_mode:
			row.tag = {"user": "saját", "modified": "módosított"}.get(e["source"], "")
			row.pressed.connect(func(): open_editor(idx))
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 4)
			line.add_child(row)
			var up := IconButton.make("up", "", func(): _move_level(f, -1), Vector2(62, 62))
			var down := IconButton.make("down", "", func(): _move_level(f, 1), Vector2(62, 62))
			up.disabled = i == 0
			down.disabled = i == _levels.size() - 1
			line.add_child(up)
			line.add_child(down)
			list.add_child(line)
		else:
			row.done = progress.is_done(f)
			row.best = progress.best(f)
			row.deaths = progress.deaths(f)
			row.is_next = i == next_i and not row.done
			row.pressed.connect(func(): play_level(idx, false))
			list.add_child(row)
	if _levels.is_empty():
		list.add_child(UiKit.label("Még nincs pálya. Rajzolj egyet!", 30, BoardPainter.INK_SOFT))
	if edit_mode:
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override("separation", 12)
		var nb := UiKit.button("Új pálya", func(): open_editor(-1), "primary")
		nb.add_theme_font_size_override("font_size", 36)
		row2.add_child(nb)
		var pb := UiKit.button("Beillesztés", _paste_new, "ink")
		row2.add_child(pb)
		v.add_child(row2)
		var hint := UiKit.label("Beillesztés: a vágólapon lévő pálya-JSON-t nyitja meg új pályaként.", 22, BoardPainter.INK_SOFT)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(hint)
	var target := _list_scroll
	var restore := func() -> void:
		scroll.scroll_vertical = target
		scroll.get_v_scroll_bar().value_changed.connect(func(val): _list_scroll = int(val))
	restore.call_deferred()


func _move_level(file: String, delta: int) -> void:
	library.move(file, delta)
	show_level_list(true)


func _paste_new() -> void:
	var L := LevelLibrary.parse(DisplayServer.clipboard_get())
	if L == null:
		UiKit.modal(menu_root, "Nincs mit beilleszteni", "A vágólapon nem pálya-JSON van. A szerkesztő „Pálya JSON másolása” menüpontja ad ilyet.", [["Rendben", Callable(), "ink"]])
		return
	_hide_all()
	editor.set_active(true)
	editor.open_level(L, "")
	editor.dirty = true


# ---------- játék ----------
func play_level(idx: int, from_title: bool = false) -> void:
	if idx < 0 or idx >= _levels.size():
		return
	var L := library.load_level(_levels[idx]["path"])
	if L == null:
		return
	_hide_all()
	_current_index = idx
	_testing_from_editor = false
	_back_to_title = from_title
	game.subject_base = progress.total_deaths
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
	game.subject_base = 0
	game.set_active(true)
	game.start(L, true, false)


func _current_file() -> String:
	if _testing_from_editor or _current_index < 0 or _current_index >= _levels.size():
		return ""
	return _levels[_current_index]["file"]


func _on_game_died(_why: String) -> void:
	var f := _current_file()
	if f != "":
		progress.record_death(f)


func _on_game_won(seconds: float, _deaths: int) -> void:
	var f := _current_file()
	if f != "":
		progress.record_win(f, seconds)


func _on_game_back() -> void:
	if _testing_from_editor:
		_testing_from_editor = false
		game.set_active(false)
		editor.set_active(true)
	elif _back_to_title:
		show_title(false)
	else:
		show_level_list(false)


func _on_game_next() -> void:
	if _current_index + 1 < _levels.size():
		play_level(_current_index + 1, _back_to_title)


# ---------- vissza gomb (Esc / Android vissza) ----------
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		go_back()


func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo and e.keycode == KEY_ESCAPE:
		go_back()
		get_viewport().set_input_as_handled()


func go_back() -> void:
	if game.visible:
		_on_game_back()
	elif editor.visible:
		editor.request_back()
	elif menu_root != null:
		show_title(false)
	elif title.visible and not title.is_intro_done():
		title.skip_intro()
