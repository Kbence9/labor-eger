extends Node2D
## M0 placeholder: betölti az első pályát és kiírja, hogy a projekt él.
## M1-ben ezt váltja a valódi játékjelenet (lásd docs/ROADMAP.md).

func _ready() -> void:
	var f := FileAccess.open("res://levels/level_01.json", FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text()) if f else {}
	var label := Label.new()
	label.text = "Labor Egér · M0\n%s betöltve: %s" % [data.get("name", "?"), str(data.get("size", []))]
	label.position = Vector2(40, 80)
	label.add_theme_font_size_override("font_size", 36)
	add_child(label)
	print("[labor] ", label.text)
