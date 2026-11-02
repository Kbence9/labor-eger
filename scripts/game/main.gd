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
var seed_edit: LineEdit       # a véletlen-menü seed-mezője (amíg a menü nyitva van)
var seed_error: Label
var random_menu: Control
var _random: Dictionary = {}   # véletlen kísérlet: {"diff", "seed", "daily"}; üres = beépített pálya


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
	title.random_requested.connect(show_random_menu)
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


# ---------- véletlen kísérlet ----------
func show_random_menu() -> void:
	# seed-mező: üresen véletlen seed, kitöltve az adott seed (ugyanaz a seed + szint = ugyanaz a pálya)
	var seed_lbl := UiKit.label("Seed (üresen hagyva: véletlen)", 24, BoardPainter.INK_SOFT, "type")
	seed_edit = LineEdit.new()
	seed_edit.placeholder_text = "pl. 4242"
	seed_edit.max_length = 12
	seed_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	seed_edit.custom_minimum_size = Vector2(0, 64)
	seed_error = UiKit.label("", 24, BoardPainter.MARK, "bold")
	seed_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	seed_error.visible = false
	seed_edit.text_changed.connect(func(_t): seed_error.visible = false)
	var opts: Array = []
	for diff in RandomMaze.ORDER:
		var cfg: Dictionary = RandomMaze.LEVELS[diff]
		var size: Vector2i = cfg["size"]
		var best := progress.best(RandomMaze.progress_key(diff))
		var label := "%s  (%d × %d)" % [cfg["name"], size.x, size.y]
		if best >= 0.0:
			label += "   rekord " + LabGame._fmt(best)
		var d: String = diff
		opts.append([label, func() -> bool: return start_random_from_input(d), "ink"])
	opts.append(["A nap labirintusa", func(): play_random(RandomMaze.DAILY, RandomMaze.daily_seed(Time.get_date_dict_from_system()), true), "primary"])
	opts.append(["Mégse", Callable(), "text"])
	random_menu = UiKit.modal(title.ui_root(), "Véletlen labirintus", "Válassz szintet. A nap labirintusa ma mindenkinek ugyanaz.", opts, [seed_lbl, seed_edit, seed_error])
	seed_edit.text_submitted.connect(func(_t):
		if start_random_from_input(RandomMaze.DAILY):
			random_menu.queue_free())


## A szint-gomb: a beírt seeddel (vagy üres mezőnél új véletlennel) indít.
## Hibás bevitelnél kiírja a hibát, és false-t ad (a menü nyitva marad).
func start_random_from_input(diff: String) -> bool:
	var r := RandomMaze.parse_seed(seed_edit.text if seed_edit else "")
	if not r["ok"]:
		seed_error.text = r["error"]
		seed_error.visible = true
		return false
	play_random(diff, RandomMaze.new_seed() if r["empty"] else int(r["seed"]))
	return true


func play_random(diff: String, seed: int, daily: bool = false) -> void:
	if not RandomMaze.is_valid(diff):
		return
	var L := RandomMaze.build(diff, seed)
	if daily:
		L.title = "A nap labirintusa"
	_hide_all()
	_random = {"diff": diff, "seed": seed, "daily": daily}
	_current_index = -1
	_testing_from_editor = false
	_back_to_title = true
	_start_game(L, false, true, "Új labirintus")


# ---------- játék ----------
func play_level(idx: int, from_title: bool = false) -> void:
	if idx < 0 or idx >= _levels.size():
		return
	var L := library.load_level(_levels[idx]["path"])
	if L == null:
		return
	_hide_all()
	_random = {}
	_current_index = idx
	_testing_from_editor = false
	_back_to_title = from_title
	_start_game(L, false, idx + 1 < _levels.size(), "Következő")


func _start_game(L: LevelData, is_test: bool, has_next: bool, next_text: String) -> void:
	game.subject_base = 0 if is_test else progress.total_deaths
	var key := _current_file()
	game.best_before = progress.best(key) if key != "" else -1.0
	game.next_text = next_text
	game.set_active(true)
	game.start(L, is_test, has_next)


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
	_start_game(L, true, false, "Következő")


## A haladás kulcsa a futó pályához: fájlnév, véletlen kísérletnél „veletlen:<szint>” / „napi:<seed>”,
## szerkesztőből tesztelve "" (az nem számít bele a haladásba).
func _current_file() -> String:
	if _testing_from_editor:
		return ""
	if not _random.is_empty():
		return RandomMaze.progress_key(_random["diff"], _random["daily"], _random["seed"])
	if _current_index < 0 or _current_index >= _levels.size():
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
	if not _random.is_empty():
		var diff: String = _random["diff"]
		play_random(diff, RandomMaze.new_seed())
	elif _current_index + 1 < _levels.size():
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
