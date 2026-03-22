# feed_back_prompt.gd
# Controls a feedback overlay panel (ColorRect) that displays result messages
# to the player (e.g. "Wrong. Try again." or a victory message).
# The panel contains a child Label node referenced as textBox.
# It is made visible by answer_http_request.gd when a grade comes back,
# and hidden again when the player dismisses it via the close button.
extends ColorRect

# Reference to the child Label that displays the feedback message text.
@onready var textBox = $Label


# Called once when the node enters the scene tree. No setup needed.
func _ready() -> void:
	pass


# Called every frame. No per-frame logic needed.
func _process(delta: float) -> void:
	pass


# Hides the feedback panel when the player clicks the dismiss/close button.
func _on_button_pressed() -> void:
	visible = false
