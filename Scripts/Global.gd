extends Node

var globalTime = 180

var timer = Timer.new()  

var rooms: Array[Dictionary] = []
var index = 0
  
func _ready():  
	add_child(timer)
	timer.add_to_group("GlobalTimer")
	timer.start(1)  
	#timer.connect("timeout", self, "on_global_timer_timeout")  
