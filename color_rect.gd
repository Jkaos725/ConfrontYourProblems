extends ColorRect

func _ready() -> void:
	color = "Red"
	
	return


func _on_button_pressed() -> void:
	if color.is_equal_approx("Red"):
		color = "Blue"
	elif color.is_equal_approx("Blue"):
		color = "Red"
