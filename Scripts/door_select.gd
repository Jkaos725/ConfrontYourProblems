# door_select.gd
# Attached to a Sprite2D that acts as a scene-selection door on an older menu screen.
# Clicking the main button navigates to the Multiple Choice room.
# Clicking the left door navigates to the Questionhints (essay) room.
# This script predates the main escape_room.gd lobby and is largely superseded by it.
extends Sprite2D


# Called once when the node enters the scene tree. No setup needed.
func _ready() -> void:
	pass


# Called every frame. No per-frame logic needed.
func _process(delta: float) -> void:
	pass


# Navigates to the Multiple Choice scene when the main button is pressed.
func _on_button_button_down() -> void:
	get_tree().change_scene_to_file("res://Scenes/Multiple_Choice.tscn")


# Navigates to the Questionhints (essay question) scene when the left door is pressed.
func _on_door_left_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Questionhints.tscn")
