extends Logger
## Script-hiba figyelő a tesztekhez. Godotban egy futásidejű script-hiba (pl. tömb túlindexelés)
## csak kiír egy SCRIPT ERROR-t, és megszakítja az adott függvényt: a teszt nem bukik el, sőt a
## quit() elmaradása miatt a folyamat örökké fut. Ez a Logger megszámolja a script-hibákat,
## így a teszt nem nullás kóddal léphet ki.
##   var guard := preload("res://tests/error_guard.gd").new()
##   OS.add_logger(guard)   # ... a végén: guard.count > 0 -> hiba

var count := 0
var first := ""
var _mutex := Mutex.new()


func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	if error_type != ERROR_TYPE_SCRIPT:
		return
	_mutex.lock()
	count += 1
	if first == "":
		first = "%s (%s:%d %s) %s" % [code, file, line, function, rationale]
	_mutex.unlock()


func _log_message(_message: String, _error: bool) -> void:
	pass
