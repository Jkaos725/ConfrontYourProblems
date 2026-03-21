extends Node2D

@export var currentQuestion = "What is the derivative of sin(x)x^2"
@export var expectedAnswer = ""

var end_state_triggered := false


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

	var tween = create_tween()
	tween.set_loops(0)
	tween.tween_property($Sprite2D, "position:y", position.y + 100, 1)
	tween.tween_property($Sprite2D, "position:y", position.y + 150, 1)
	tween.set_trans(Tween.TRANS_SINE)
	tween.set_ease(Tween.EASE_IN_OUT)


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
			feedback_prompt.textBox.text = "Defeat.\nTime ran out in the room."
		_return_to_main_after_delay()


func _return_to_main_after_delay() -> void:
	await get_tree().create_timer(1.6).timeout
	Global.index = 0
	Global.rooms.clear()
	Global.globalTime = 180
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_answer_button_mouse_entered() -> void:
	var tween = create_tween()
	tween.tween_property($AnswerHTTPRequest/AnswerButton, "scale", Vector2(1.1, 1.1), 0.01)


func _on_answer_button_mouse_exited() -> void:
	var tween = create_tween()
	tween.tween_property($AnswerHTTPRequest/AnswerButton, "scale", Vector2(1, 1), 0.01)
