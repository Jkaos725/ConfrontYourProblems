extends Node2D

@export var currentQuestion = "What is the derivative of sin(x)x^2"
@export var expectedAnswer = ""
@onready var professor_line: Label = $Control2/MarginContainer/PanelContainer/VBoxContainer/TopRow/ProfessorPanel/ProfessorBox/ProfessorLine
@onready var professor_portrait: TextureRect = $Control2/MarginContainer/PanelContainer/VBoxContainer/TopRow/ProfessorPanel/ProfessorBox/ProfessorPortrait
@onready var professor_panel: PanelContainer = $Control2/MarginContainer/PanelContainer/VBoxContainer/TopRow/ProfessorPanel
@onready var question_card: PanelContainer = $Control2/MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/QuestionCard

var end_state_triggered := false
var _typewriter_label: Label

var current_professor: Dictionary = {}
var professors := [
	{
		"name": "Professor Vex",
		"portrait": "res://Images/angryBot.png",
		"intro": [
			"Answer correctly and I may let you pass.",
			"One lock. One clue. Do not embarrass yourself.",
			"The door listens only to sharp minds.",
			"Solve it quickly, or remain in my hall."
		],
		"wrong": [
			"Wrong. Look closer.",
			"No. Think before you touch the lock.",
			"Careless. Try again.",
			"That is not the mechanism I asked for."
		],
		"hint": [
			"I will offer one clue. Do not waste it.",
			"Very well. Here is your hint.",
			"A small clue, nothing more.",
			"Even now I am being generous."
		],
		"success": [
			"Hm. Acceptable.",
			"You may proceed.",
			"Better. The next chamber awaits.",
			"Correct. Move before I change my mind."
		],
		"defeat": [
			"Then remain here with your mistakes.",
			"The hall closes on the unprepared.",
			"You were not ready for this trial.",
			"The chamber keeps what it defeats."
		]
	},
	{
		"name": "Professor Hale",
		"portrait": "res://Images/enutralface.png",
		"intro": [
			"Take your time and read the clue carefully.",
			"This room rewards steady thinking.",
			"The right answer is here if you follow the pattern.",
			"Stay calm. The door will open for the prepared."
		],
		"wrong": [
			"Not quite. Try another angle.",
			"Close reading will help here.",
			"That choice does not fit. Try again.",
			"Almost. Focus on the key idea."
		],
		"hint": [
			"Here is a nudge in the right direction.",
			"Use the clue, not your first guess.",
			"Look for the strongest match.",
			"Think about what the room is really asking."
		],
		"success": [
			"Good. Keep going.",
			"Nicely reasoned.",
			"That opened it. Onward.",
			"Well done. The next chamber is ready."
		],
		"defeat": [
			"You ran out of time, but the lesson is still there.",
			"This round is over. Return when you are ready.",
			"The room wins for now.",
			"You will get another chance."
		]
	},
	{
		"name": "Professor Mira",
		"portrait": "res://Images/first.png",
		"intro": [
			"You can do this. Start with the clue in front of you.",
			"Take a breath. One careful answer opens the way.",
			"The exit is closer than it looks.",
			"Trust what you know and move step by step."
		],
		"wrong": [
			"Not this one. Try again.",
			"That was a good attempt. Look once more.",
			"Keep going. The right answer is near.",
			"Almost there. Read the clue again."
		],
		"hint": [
			"Here is a clue to help you forward.",
			"Look for the concept that fits best.",
			"Use the strongest keyword in the clue.",
			"You already have what you need."
		],
		"success": [
			"Nice work. The door is opening.",
			"Yes, that was it.",
			"Great job. Keep moving.",
			"You solved it beautifully."
		],
		"defeat": [
			"It is okay. Try again from the start.",
			"This room can be beaten next time.",
			"You made progress. Come back stronger.",
			"The trial ends here, but not your journey."
		]
	}
]

func _ready() -> void:
	var timer = get_tree().get_first_node_in_group("GlobalTimer")
	if timer != null:
		timer.timeout.connect(on_timer_timeout)

	if not Global.rooms.is_empty() and Global.index >= 0 and Global.index < Global.rooms.size():
		var room: Dictionary = Global.rooms[Global.index]
		currentQuestion = str(room.get("question", currentQuestion))
		var answers: Array = room.get("answers", [])
		var correct_index: int = int(room.get("correct_index", -1))
		if correct_index >= 0 and correct_index < answers.size():
			expectedAnswer = str(answers[correct_index])

	for child in get_children():
		if "currentQuestion" in child:
			child.currentQuestion = currentQuestion
		if "expectedAnswer" in child:
			child.expectedAnswer = expectedAnswer
		if child.name == "QuestionLabel" and "text" in child:
			child.text = currentQuestion
	$Control2/MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/QuestionCard/QuestionLabel.text = currentQuestion
	
	current_professor = _select_professor(Global.index)
	

	professor_line.text = ""
	_apply_professor_portrait()
	_play_entrance_animation()



func _process(_delta: float) -> void:
	pass


func on_timer_timeout() -> void:
	Global.globalTime -= 1
	if Global.globalTime <= 0 and not end_state_triggered:
		end_state_triggered = true
		var timer = get_tree().get_first_node_in_group("GlobalTimer")
		if timer != null:
			timer.stop()
		var feedback_prompt = get_node_or_null("FeedBackPrompt")
		if feedback_prompt != null:
			feedback_prompt.visible = true
			professor_line.text = _professor_line("defeat")
			feedback_prompt.textBox.text = "Defeat.\nTime ran out in the room."
		_return_to_main_after_delay()


func _return_to_main_after_delay() -> void:
	await get_tree().create_timer(1.6).timeout
	Global.index = 0
	Global.rooms.clear()
	Global.globalTime = Global.selected_hint_time
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_answer_button_mouse_entered() -> void:
	var tween = create_tween()
	tween.tween_property($AnswerHTTPRequest/AnswerButton, "scale", Vector2(1.1, 1.1), 0.01)


func _on_answer_button_mouse_exited() -> void:
	var tween = create_tween()
	tween.tween_property($AnswerHTTPRequest/AnswerButton, "scale", Vector2(1, 1), 0.01)

func _select_professor(room_index: int) -> Dictionary:
	var selected_name := str(Global.selected_professor)
	for professor in professors:
		var professor_dict: Dictionary = professor
		if str(professor_dict.get("name", "")) == selected_name:
			return professor_dict
	return professors[room_index % professors.size()]


func _professor_line(kind: String) -> String:
	var professor_name := str(current_professor.get("name", "Professor"))
	var lines_variant: Variant = current_professor.get(kind, [])
	var lines: Array = lines_variant if lines_variant is Array else []
	if lines.is_empty():
		return professor_name
	return "%s: %s" % [professor_name, _random_line(lines)]


func _random_line(lines: Array) -> String:
	if lines.is_empty():
		return ""
	return str(lines[randi() % lines.size()])


func _apply_professor_portrait() -> void:
	var portrait_path := str(current_professor.get("portrait", ""))
	if portrait_path.is_empty():
		return
	var texture: Variant = load(portrait_path)
	if texture is Texture2D:
		professor_portrait.texture = texture


func _play_entrance_animation() -> void:
	var question_label = question_card.get_node("QuestionLabel")
	var original_pos = question_card.position.y
	question_card.modulate.a = 0
	question_card.position.y -= 20
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(question_card, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(question_card, "position:y", original_pos, 0.5).set_trans(Tween.TRANS_CUBIC)
	
	if question_label:
		question_label.modulate.a = 0
		tween.tween_property(question_label, "modulate:a", 1.0, 0.4).set_delay(0.2)
	
	var portrait_original_pos = professor_portrait.position.x
	professor_portrait.modulate.a = 0
	professor_portrait.position.x -= 30
	tween.tween_property(professor_portrait, "modulate:a", 1.0, 0.4).set_delay(0.1)
	tween.tween_property(professor_portrait, "position:x", portrait_original_pos, 0.4).set_delay(0.1).set_trans(Tween.TRANS_BACK)
	
	await get_tree().create_timer(0.5).timeout
	_start_idle_bob()
	_typewriter_text(professor_line, _professor_line("intro"), 0.03)


func _start_idle_bob() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(professor_portrait, "position", Vector2(), 1.0)
	tween.tween_property(professor_portrait, "rotation_degrees", 0, 30.0)


func _typewriter_text(label: Label, text: String, speed: float) -> void:
	_typewriter_label = label
	_typewriter_label.text = text
	_typewriter_label.visible_characters = 1
	await label.get_tree().process_frame
	
	
	var timer = Timer.new()
	timer.wait_time = speed
	timer.one_shot = false
	add_child(timer)
	timer.timeout.connect(_on_typewriter_tick)
	timer.start()


func _on_typewriter_tick() -> void:
	if _typewriter_label.visible_characters < _typewriter_label.text.length():
		_typewriter_label.visible_characters += 1
	else:
		for child in get_children():
			if child is Timer:
				child.stop()
				child.queue_free()
				break
		_on_typewriter_complete()


func _on_typewriter_complete() -> void:
	pass
