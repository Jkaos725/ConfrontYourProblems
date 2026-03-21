extends Node2D

@export var currentQuestion = "What is the derivative of sin(x)x^2"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var timer = get_tree().get_first_node_in_group("GlobalTimer")
	timer.timeout.connect(on_timer_timeout)
	if !Global.rooms.is_empty():
		var room: Dictionary = Global.rooms[Global.index]
		currentQuestion = room["question"]
	for child in get_children():
		if ("currentQuestion" in child):
			child.currentQuestion = currentQuestion
			if ("text" in child):
				child.text = currentQuestion
	print(Global.rooms)
	

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func on_timer_timeout():
	Global.globalTime -= 1
