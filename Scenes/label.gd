extends Label

# Optional: Add an offset so the text isn't directly on the cursor
@export var offset: Vector2 = Vector2(10, 10)

func _process(delta):
	# Update the label's position to follow the mouse cursor
	global_position = get_global_mouse_position() + offset
# In the script of the object being hovered (e.g., a Button node)
