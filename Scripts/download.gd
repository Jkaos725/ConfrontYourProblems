# download.gd
# Early prototype door-select script attached to a Sprite2D.
# Functionally identical to door_select.gd but uses a hardcoded absolute path
# for the Multiple Choice scene (D:/...), which will only work on one specific machine.
# The Questionhints path uses the correct res:// resource path.
# This script is superseded by the main escape_room.gd lobby.
extends Sprite2D


# Called once when the node enters the scene tree. No setup needed.
func _ready() -> void:
	pass


# Called every frame. No per-frame logic needed.
func _process(delta: float) -> void:
	pass


# Navigates to the Multiple Choice scene.
# WARNING: Uses a hardcoded absolute path — will break on any machine other than the original dev machine.
func _on_button_button_down() -> void:
	get_tree().change_scene_to_file("D:/ConfrontYourProblems/Scenes/Multiple_Choice.tscn")
	pass


# Navigates to the Questionhints (essay question) scene using the correct res:// path.
func _on_door_left_pressed() -> void:
	get_tree().change_scene_to_file("res://Scenes/Questionhints.tscn")
	pass
