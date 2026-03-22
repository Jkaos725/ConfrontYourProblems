# MQ (2).gd
# Prototype multiple-choice answer handler attached to a ColorRect background.
# This is a newer iteration of MQ.gd — adds scale-down animations when the mouse
# leaves a button, making hover feel more polished.
# Answer buttons A, B, C each show a tooltip label on hover and scale up/down.
# Answer selection logic (correct/wrong branching) is stubbed out with pass.
# This script is superseded by server_vault_room.gd in the final room scenes.
extends ColorRect


# Called once when the node enters the scene tree.
# Hides all answer tooltip labels so they are invisible until hovered.
func _ready() -> void:
	$"../CanvasLayer/LabelA".visible = false
	$"../CanvasLayer/LabelB".visible = false
	$"../CanvasLayer/LabelC".visible = false
	var tween = create_tween()
	pass


# Called every frame. No per-frame logic needed.
func _process(delta: float) -> void:
	pass


# Shows the tooltip label for answer A and scales the A button up when hovered.
func _on_a_mouse_entered() -> void:
	$"../CanvasLayer/LabelA".visible = true
	var tween = create_tween()
	tween.tween_property($A, "scale", Vector2(1.15, 1.15), 0.1)
	pass


# Hides the tooltip label for answer A and scales the A button back to normal when hover ends.
func _on_a_mouse_exited() -> void:
	$"../CanvasLayer/LabelA".visible = false
	var tween = create_tween()
	tween.tween_property($A, "scale", Vector2(1, 1), 0.1)
	pass


# Fires when the player clicks answer A. Correct/wrong branching not yet implemented.
func _on_a_pressed() -> void:
	# TODO: check if A is the correct answer and respond accordingly
	pass


# Shows the tooltip label for answer B and scales the B button up when hovered.
func _on_b_mouse_entered() -> void:
	$"../CanvasLayer/LabelB".visible = true
	var tween = create_tween()
	tween.tween_property($B, "scale", Vector2(1.15, 1.15), 0.1)
	pass


# Hides the tooltip label for answer B and scales the B button back to normal when hover ends.
func _on_b_mouse_exited() -> void:
	$"../CanvasLayer/LabelB".visible = false
	var tween = create_tween()
	tween.tween_property($B, "scale", Vector2(1, 1), 0.1)
	pass


# Fires when the player clicks answer B. Correct/wrong branching not yet implemented.
func _on_b_pressed() -> void:
	# TODO: check if B is the correct answer and respond accordingly
	pass


# Shows the tooltip label for answer C and scales the C button up when hovered.
func _on_c_mouse_entered() -> void:
	$"../CanvasLayer/LabelC".visible = true
	var tween = create_tween()
	tween.tween_property($C, "scale", Vector2(1.15, 1.15), 0.1)
	pass


# Hides the tooltip label for answer C and scales the C button back to normal when hover ends.
func _on_c_mouse_exited() -> void:
	$"../CanvasLayer/LabelC".visible = false
	var tween = create_tween()
	tween.tween_property($C, "scale", Vector2(1, 1), 0.1)
	pass


# Fires when the player clicks answer C. Correct/wrong branching not yet implemented.
func _on_c_pressed() -> void:
	# TODO: check if C is the correct answer and respond accordingly
	pass
