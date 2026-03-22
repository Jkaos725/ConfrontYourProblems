# question_label.gd
# Stub script for a Label node intended to display the current quiz question.
# The currentQuestion variable is meant to be set by a parent room script
# so this label can display the active question text.
# No display logic is implemented yet — the parent room sets text directly on the node.
extends Label

# Holds the question string for the current room.
# Expected to be written to by the parent scene's room controller.
var currentQuestion


# Called once when the node enters the scene tree. No setup needed yet.
func _ready() -> void:
	pass


# Called every frame. No per-frame logic needed yet.
func _process(delta: float) -> void:
	pass
