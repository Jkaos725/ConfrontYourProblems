# label.gd
# Makes a Label node follow the mouse cursor, used as a tooltip overlay.
# Attach this to a Label that should trail the cursor (e.g. to display hover text).
# The label moves every frame to stay at the cursor position plus an offset
# so the text does not sit directly under the mouse pointer.
extends Label

# How far (in pixels) to offset the label from the exact cursor position.
# Adjust x/y to reposition the tooltip relative to the cursor tip.
@export var offset: Vector2 = Vector2(10, 10)


# Called every frame — moves the label to the current mouse position plus the offset.
# delta is unused because mouse position is read directly, not integrated over time.
func _process(delta):
	global_position = get_global_mouse_position() + offset
