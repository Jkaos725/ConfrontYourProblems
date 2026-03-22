# MQ.gd
# Earliest prototype multiple-choice answer handler, attached to a Sprite2D background.
# Hover interactions show/hide CanvasLayer tooltip labels for answers A, B, C.
# This version scales buttons up to 1.5x on hover but does not scale them back down
# (the mouse-exited handlers only hide the label — no tween to restore scale).
# Answer selection logic is stubbed with pass throughout.
# This script is superseded by MQ (2).gd and ultimately server_vault_room.gd.
extends Sprite2D


# Called once when the node enters the scene tree. No setup needed.
func _ready() -> void:
	pass


# Called every frame. No per-frame logic needed.
func _process(delta: float) -> void:
	pass


# Shows the tooltip label for answer A and scales button A up when hovered.
func _on_a_mouse_entered() -> void:
	$"../CanvasLayer/LabelA".visible = true
	var tween = create_tween()
	tween.tween_property($A, "scale", Vector2(1.5, 1.5), 0.1)
	pass


# Hides the tooltip label for answer A when hover ends.
# Note: does not restore the button scale — scale reset is missing in this version.
func _on_a_mouse_exited() -> void:
	$"../CanvasLayer/LabelA".visible = false
	pass


# Fires when the player clicks answer A. Correct/wrong branching not yet implemented.
func _on_a_pressed() -> void:
	# TODO: check if A is the correct answer and respond accordingly
	pass


# Shows the tooltip label for answer B when hovered.
# Note: no scale tween in this version.
func _on_b_mouse_entered() -> void:
	$"../CanvasLayer/LabelB".visible = true
	pass


# Hides the tooltip label for answer B when hover ends.
func _on_b_mouse_exited() -> void:
	$"../CanvasLayer/LabelB".visible = false
	pass


# Fires when the player clicks answer B. Correct/wrong branching not yet implemented.
func _on_b_pressed() -> void:
	# TODO: check if B is the correct answer and respond accordingly
	pass


# Shows the tooltip label for answer C when hovered.
func _on_c_mouse_entered() -> void:
	$"../CanvasLayer/LabelC".visible = true
	pass


# Hides the tooltip label for answer C when hover ends.
func _on_c_mouse_exited() -> void:
	$"../CanvasLayer/LabelC".visible = false
	pass


# Fires when the player clicks answer C. Correct/wrong branching not yet implemented.
func _on_c_pressed() -> void:
	# TODO: check if C is the correct answer and respond accordingly
	pass
