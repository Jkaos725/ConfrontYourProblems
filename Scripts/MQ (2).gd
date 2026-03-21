extends ColorRect

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	$"../CanvasLayer/LabelA".visible = false
	$"../CanvasLayer/LabelB".visible = false
	$"../CanvasLayer/LabelC".visible = false
	var tween = create_tween()
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


#Hover the answer over the A
func _on_a_mouse_entered() -> void:
	$"../CanvasLayer/LabelA".visible = true
	var tween = create_tween()
	tween.tween_property($A, "scale", Vector2(1.15,1.15),0.1)
	pass # Replace with function body.


func _on_a_mouse_exited() -> void:
	$"../CanvasLayer/LabelA".visible = false
	
	var tween = create_tween()
	tween.tween_property($A, "scale", Vector2(1,1),0.1)
	pass # Replace with function body.
	

#Choose A
func _on_a_pressed() -> void:
	#If A is correct then correct
	#Else then not
	pass # Replace with function body.

#Hover to show answer B
func _on_b_mouse_entered() -> void:
	$"../CanvasLayer/LabelB".visible = true
	
	var tween = create_tween()
	tween.tween_property($B, "scale", Vector2(1.15,1.15),0.1)
	pass # Replace with function body.


func _on_b_mouse_exited() -> void:
	$"../CanvasLayer/LabelB".visible = false
	
	var tween = create_tween()
	tween.tween_property($B, "scale", Vector2(1,1),0.1)
	pass # Replace with function body.



func _on_b_pressed() -> void:
	#CHoose answer B
	pass # Replace with function body.
	
	

#Show answer C
func _on_c_mouse_entered() -> void:
	$"../CanvasLayer/LabelC".visible = true
	var tween = create_tween()
	tween.tween_property($C, "scale", Vector2(1.15,1.15),0.1)
	pass # Replace with function body.

func _on_c_mouse_exited() -> void:
	$"../CanvasLayer/LabelC".visible = false
	
	var tween = create_tween()
	tween.tween_property($C, "scale", Vector2(1,1),0.1)
	pass # Replace with function body.

#Choose C
func _on_c_pressed() -> void:
	#Code to choose C
	pass # Replace with function body.
