class_name NotebookPage
extends Control
## Teljes képernyős füzetoldal háttér a menükhöz (a gombok fölötte vannak).

var holes := true


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(queue_redraw)


func _draw() -> void:
	Notebook.page(self, Rect2(Vector2.ZERO, size), 1.0, 1.0, holes)
