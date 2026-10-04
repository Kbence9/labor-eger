class_name EditHistory
extends RefCounted
## Visszavonás / újra a szerkesztőhöz: minden módosítás előtt pillanatkép a pályáról.

const MAX_STEPS := 200

var _undo: Array[Dictionary] = []
var _redo: Array[Dictionary] = []


## Módosítás ELŐTT hívd: elmenti a jelenlegi állapotot, és törli az „újra” listát.
func record(L: LevelData) -> void:
	_undo.append(L.to_dict())
	if _undo.size() > MAX_STEPS:
		_undo.pop_front()
	_redo.clear()


## Az előző állapot (vagy null, ha nincs mit visszavonni).
func undo(current: LevelData) -> LevelData:
	if _undo.is_empty():
		return null
	_redo.append(current.to_dict())
	return LevelData.from_dict(_undo.pop_back())


func redo(current: LevelData) -> LevelData:
	if _redo.is_empty():
		return null
	_undo.append(current.to_dict())
	return LevelData.from_dict(_redo.pop_back())


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	return not _redo.is_empty()


func clear() -> void:
	_undo.clear()
	_redo.clear()
