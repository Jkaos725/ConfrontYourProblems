extends Node

var globalTime = 180

var timer = Timer.new()  
  
func _ready():  
	add_child(timer)  
	timer.start(1)  
	#timer.connect("timeout", self, "on_global_timer_timeout")  

func on_global_timer_timeout():
	print("foo")
