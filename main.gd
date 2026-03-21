extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var tween = create_tween()
	
	tween.tween_property($Icon, "rotation",deg_to_rad(180),3)
