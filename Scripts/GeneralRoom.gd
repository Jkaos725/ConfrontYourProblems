extends Node2D

const CLICK_SOUND_PATH := "res://Audio/New Sounds/Random Sound/skyscraper_seven-click-buttons-ui-menu-sounds-effects-button-13-205396.mp3"
const CORRECT_SOUND_PATH := "res://Audio/New Sounds/New Correct sound/mixkit-correct-answer-fast-notification-953.wav"
const WRONG_SOUND_PATH := "res://Audio/New Sounds/Wrong sounds/tunetank.com_abort-operation.wav"
const UNLOCK_SOUND_PATH := "res://Audio/New Sounds/New Correct sound/mixkit-correct-answer-notification-947.wav"
const WIN_SOUND_PATH := "res://Audio/New Sounds/New Correct sound/mixkit-correct-answer-notification-947.wav"
const LOSE_SOUND_PATH := "res://Audio/New Sounds/Wrong sounds/tunetank.com_abort-operation.wav"

const BACKGROUND_MUSIC_PATH := "res://Audio/New Sounds/Background music/Background.mp3"

@export var currentQuestion = "What is the derivative of sin(x)x^2"
@export var expectedAnswer = ""
@onready var professor_line: Label = $Control2/MarginContainer/PanelContainer/VBoxContainer/TopRow/ProfessorPanel/ProfessorBox/ProfessorLine
@onready var professor_portrait: TextureRect = $Control2/MarginContainer/PanelContainer/VBoxContainer/TopRow/ProfessorPanel/ProfessorBox/ProfessorPortrait
@onready var professor_panel: PanelContainer = $Control2/MarginContainer/PanelContainer/VBoxContainer/TopRow/ProfessorPanel
@onready var question_card: PanelContainer = $Control2/MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/QuestionCard

@onready var click_player: AudioStreamPlayer = $ClickPlayer
@onready var correct_player: AudioStreamPlayer = $CorrectPlayer
@onready var wrong_player: AudioStreamPlayer = $WrongPlayer
@onready var unlock_player: AudioStreamPlayer = $UnlockPlayer
@onready var win_player: AudioStreamPlayer = $WinPlayer
@onready var lose_player: AudioStreamPlayer = $LosePlayer

var end_state_triggered := false
var _typewriter_label: Label
var _idle_tween: Tween = null
var _speak_tween: Tween = null
var _pending_scene: String = ""
var background_music_player: AudioStreamPlayer

var current_professor: Dictionary = {}
var professors := [
	{
		"name": "Professor Vex",
		"portrait": "res://Images/angryBot.png",
		"intro": [
			"Answer correctly and I may let you pass.",
			"One lock. One clue. Do not embarrass yourself.",
			"The door listens only to sharp minds.",
			"Solve it quickly, or remain in my hall.",
			"I have no patience for dawdling. Answer.",
			"The mechanism is simple. Observe before you act.",
			"Every second you hesitate disappoints me further."
		],
		"wrong": [
			"Wrong. Look closer.",
			"No. Think before you touch the lock.",
			"Careless. Try again.",
			"That is not the mechanism I asked for.",
			"Predictable. Try harder.",
			"That answer was an insult to the lock.",
			"I expected better. I should not have."
		],
		"hint": [
			"I will offer one clue. Do not waste it.",
			"Very well. Here is your hint.",
			"A small clue, nothing more.",
			"Even now I am being generous.",
			"I will not repeat myself.",
			"Use it wisely. I have nothing more to give.",
			"One clue. That is all your incompetence has earned."
		],
		"success": [
			"Hm. Acceptable.",
			"You may proceed.",
			"Better. The next chamber awaits.",
			"Correct. Move before I change my mind.",
			"Finally.",
			"I was beginning to lose hope.",
			"Do not let it go to your head."
		],
		"defeat": [
			"Then remain here with your mistakes.",
			"The hall closes on the unprepared.",
			"You were not ready for this trial.",
			"The chamber keeps what it defeats.",
			"Time rewards the prepared. You were not.",
			"This is what complacency earns.",
			"The door has made its judgment."
		]
	},
	{
		"name": "Professor Hale",
		"portrait": "res://Images/enutralface.png",
		"intro": [
			"Take your time and read the clue carefully.",
			"This room rewards steady thinking.",
			"The right answer is here if you follow the pattern.",
			"Stay calm. The door will open for the prepared.",
			"Check the details before committing to an answer.",
			"Approach this systematically and you will find the way.",
			"Every clue in this room has a purpose. Use them."
		],
		"wrong": [
			"Not quite. Try another angle.",
			"Close reading will help here.",
			"That choice does not fit. Try again.",
			"Almost. Focus on the key idea.",
			"Reread the clue before trying again.",
			"The answer is here. Keep narrowing it down.",
			"A step in the wrong direction. Adjust and try again."
		],
		"hint": [
			"Here is a nudge in the right direction.",
			"Use the clue, not your first guess.",
			"Look for the strongest match.",
			"Think about what the room is really asking.",
			"Consider the relationship between the key terms.",
			"The pattern becomes clear when you slow down.",
			"A small detail in the question points the way."
		],
		"success": [
			"Good. Keep going.",
			"Nicely reasoned.",
			"That opened it. Onward.",
			"Well done. The next chamber is ready.",
			"Confirmed. Move to the next stage.",
			"Logical. Well executed.",
			"That is how it is done."
		],
		"defeat": [
			"You ran out of time, but the lesson is still there.",
			"This round is over. Return when you are ready.",
			"The room wins for now.",
			"You will get another chance.",
			"Time expired. Review the material and return.",
			"Note what slowed you down and address it.",
			"A neutral outcome. There is always another attempt."
		]
	},
	{
		"name": "Professor Mira",
		"portrait": "res://Images/first.png",
		"intro": [
			"You can do this. Start with the clue in front of you.",
			"Take a breath. One careful answer opens the way.",
			"The exit is closer than it looks.",
			"Trust what you know and move step by step.",
			"You have everything you need. Trust yourself.",
			"Start with what you know and build from there.",
			"This room is solvable. I believe in you."
		],
		"wrong": [
			"Not this one. Try again.",
			"That was a good attempt. Look once more.",
			"Keep going. The right answer is near.",
			"Almost there. Read the clue again.",
			"That is okay. Take another look.",
			"You are closer than you think. Try once more.",
			"Do not worry. The right answer is within reach."
		],
		"hint": [
			"Here is a clue to help you forward.",
			"Look for the concept that fits best.",
			"Use the strongest keyword in the clue.",
			"You already have what you need.",
			"This should point you in the right direction.",
			"Take your time with this one.",
			"A gentle nudge — you are almost there."
		],
		"success": [
			"Nice work. The door is opening.",
			"Yes, that was it.",
			"Great job. Keep moving.",
			"You solved it beautifully.",
			"I knew you could do it.",
			"That is the one. Well done.",
			"Wonderful. The next room is waiting for you."
		],
		"defeat": [
			"It is okay. Try again from the start.",
			"This room can be beaten next time.",
			"You made progress. Come back stronger.",
			"The trial ends here, but not your journey.",
			"That is alright. Every attempt teaches something.",
			"You gave it your best. Come back ready.",
			"The room stopped you today. Not forever."
		]
	}
]

func _ready() -> void:
	_configure_audio_players()

	_configure_background_music()
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

	$AnswerHTTPRequest.answer_graded_correct.connect(_on_answer_graded_correct)
	$AnswerHTTPRequest.answer_graded_wrong.connect(_on_answer_graded_wrong)
	$AnswerHTTPRequest.ready_to_advance.connect(_on_ready_to_advance)
	$Control2/FeedBackPrompt/ContinueButton.pressed.connect(_on_continue_pressed)

	var hint1 = $Control2/MarginContainer/PanelContainer/VBoxContainer/BodyRow/RightColumn/ThemeCard/Hint1
	var hint2 = $Control2/MarginContainer/PanelContainer/VBoxContainer/BodyRow/RightColumn/HintCard/Hint2
	var hint3 = $Control2/MarginContainer/PanelContainer/VBoxContainer/BodyRow/RightColumn/StatusCard/Hint3
	var answer_btn = $Control2/MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/AnswerButton1
	hint1.pressed.connect(func(): _play_with_random_pitch(click_player))
	hint2.pressed.connect(func(): _play_with_random_pitch(click_player))
	hint3.pressed.connect(func(): _play_with_random_pitch(click_player))
	answer_btn.pressed.connect(func(): _play_with_random_pitch(click_player))

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
		_play_with_random_pitch(lose_player)
		var timer = get_tree().get_first_node_in_group("GlobalTimer")
		if timer != null:
			timer.stop()
		var feedback_prompt = get_node_or_null("Control2/FeedBackPrompt")
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
	if _idle_tween:
		_idle_tween.kill()
	_idle_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_idle_tween.tween_property(professor_portrait, "rotation_degrees", 1.5, 1.2)
	_idle_tween.tween_property(professor_portrait, "rotation_degrees", -1.5, 1.2)


func _start_speak_shake() -> void:
	if _idle_tween:
		_idle_tween.kill()
		_idle_tween = null
	if _speak_tween:
		_speak_tween.kill()
	_speak_tween = create_tween().set_loops()
	_speak_tween.tween_property(professor_portrait, "rotation_degrees", 2.5, 0.07).set_trans(Tween.TRANS_SINE)
	_speak_tween.tween_property(professor_portrait, "rotation_degrees", -2.5, 0.12).set_trans(Tween.TRANS_SINE)
	_speak_tween.tween_property(professor_portrait, "rotation_degrees", 0.0, 0.07).set_trans(Tween.TRANS_SINE)


func _stop_speak_shake() -> void:
	if _speak_tween:
		_speak_tween.kill()
		_speak_tween = null
	var reset := create_tween()
	reset.tween_property(professor_portrait, "rotation_degrees", 0.0, 0.12).set_trans(Tween.TRANS_SINE)
	reset.tween_callback(_start_idle_bob)


func _typewriter_text(label: Label, text: String, speed: float) -> void:
	_typewriter_label = label
	_typewriter_label.text = text
	_typewriter_label.visible_characters = 1
	_start_speak_shake()
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
	_stop_speak_shake()


func _configure_audio_players() -> void:
	click_player.stream = _load_audio(CLICK_SOUND_PATH)
	correct_player.stream = _load_audio(CORRECT_SOUND_PATH)
	wrong_player.stream = _load_audio(WRONG_SOUND_PATH)
	unlock_player.stream = _load_audio(UNLOCK_SOUND_PATH)
	win_player.stream = _load_audio(WIN_SOUND_PATH)
	lose_player.stream = _load_audio(LOSE_SOUND_PATH)


func _load_audio(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	var stream: Variant = ResourceLoader.load(path)
	if stream is AudioStream:
		return stream
	return null


func _play_with_random_pitch(player: AudioStreamPlayer) -> void:
	if player.stream != null:
		player.pitch_scale = randf_range(0.95, 1.05)
		player.stop()
		player.play()


func _on_answer_graded_correct(is_final_room: bool) -> void:
	if is_final_room:
		_play_with_random_pitch(win_player)
	else:
		_play_with_random_pitch(correct_player)
		_play_with_random_pitch(unlock_player)
	_typewriter_text(professor_line, _professor_line("success"), 0.03)


func _on_answer_graded_wrong() -> void:
	_play_with_random_pitch(wrong_player)
	_typewriter_text(professor_line, _professor_line("wrong"), 0.03)


func _on_ready_to_advance(next_scene: String) -> void:
	_pending_scene = next_scene
	var global_timer = get_tree().get_first_node_in_group("GlobalTimer")
	if global_timer != null:
		global_timer.stop()
	$Control2/FeedBackPrompt/Button.visible = false
	$Control2/FeedBackPrompt/ContinueButton.visible = true


func _on_continue_pressed() -> void:
	var global_timer = get_tree().get_first_node_in_group("GlobalTimer")
	if global_timer != null:
		global_timer.start(1)
	get_tree().change_scene_to_file(_pending_scene)


func _configure_background_music() -> void:
	background_music_player = AudioStreamPlayer.new()
	add_child(background_music_player)
	var stream: Variant = load(BACKGROUND_MUSIC_PATH)
	if stream is AudioStream:
		background_music_player.stream = stream
		if background_music_player.stream is AudioStreamMP3:
			background_music_player.stream.loop = true
		background_music_player.volume_db = -14.0
		background_music_player.play()
