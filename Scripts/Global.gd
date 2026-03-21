extends Node

var globalTime = 180

var timer = Timer.new()  

var rooms: Array[Dictionary] = []
var index = 0
var score = 0
var lives = 3
var hints_used = 0
var active_subject = ""
var active_quiz_name = ""


func reset_quiz_session() -> void:
	index = 0
	score = 0
	lives = 3
	hints_used = 0
	globalTime = 180


func clear_quiz_session() -> void:
	rooms.clear()
	active_subject = ""
	active_quiz_name = ""
	reset_quiz_session()
  
func _ready():  
	add_child(timer)
	timer.add_to_group("GlobalTimer")
	timer.start(1)  
	#timer.connect("timeout", self, "on_global_timer_timeout")  
