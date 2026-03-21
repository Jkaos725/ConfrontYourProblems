extends Sprite2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


#Hover the answer over the A
func _on_a_mouse_entered() -> void:
	$"../CanvasLayer/LabelA".visible = true
	pass # Replace with function body.


func _on_a_mouse_exited() -> void:
	$"../CanvasLayer/LabelA".visible = false
	pass # Replace with function body.
	

#Choose A
func _on_a_pressed() -> void:
	#If A is correct then correct
	#Else then not
	pass # Replace with function body.

#Hover to show answer B
func _on_b_mouse_entered() -> void:
	$"../CanvasLayer/LabelB".visible = true
	pass # Replace with function body.


func _on_b_mouse_exited() -> void:
	$"../CanvasLayer/LabelB".visible = false
	pass # Replace with function body.



func _on_b_pressed() -> void:
	#CHoose answer B
	pass # Replace with function body.
	
	

#Show answer C
func _on_c_mouse_entered() -> void:
	$"../CanvasLayer/LabelC".visible = true
	pass # Replace with function body.

func _on_c_mouse_exited() -> void:
	$"../CanvasLayer/LabelC".visible = false
	pass # Replace with function body.

#Choose C
func _on_c_pressed() -> void:
	#Code to choose C
	pass # Replace with function body.
