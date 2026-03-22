extends Node

var globalTime = 180

var timer = Timer.new()  

var rooms: Array[Dictionary] = []
var index = 0
var score = 0
var lives = 3
var selected_lives = 3
var selected_question_count = 4
var selected_hint_time = 180
var hints_used = 0
var active_subject = ""
var active_quiz_name = ""
var selected_professor = "Professor Vex"
var last_quiz_score = 0
var last_quiz_total = 0
var last_quiz_name = ""
var last_result = ""
var last_quiz_time_seconds: int = 0
var session_start_time: float = 0.0


func reset_quiz_session() -> void:
	index = 0
	score = 0
	lives = selected_lives
	hints_used = 0
	globalTime = selected_hint_time
	session_start_time = Time.get_ticks_msec()


func clear_quiz_session() -> void:
	rooms.clear()
	active_subject = ""
	active_quiz_name = ""
	reset_quiz_session()


func store_quiz_result(result: String) -> void:
	last_quiz_score = score
	last_quiz_total = max(rooms.size(), 0)
	last_quiz_name = active_quiz_name
	last_result = result
	last_quiz_time_seconds = int((Time.get_ticks_msec() - session_start_time) / 1000.0)
  
func _ready():  
	add_child(timer)
	timer.add_to_group("GlobalTimer")
	timer.start(1)  
	#timer.connect("timeout", self, "on_global_timer_timeout")  
