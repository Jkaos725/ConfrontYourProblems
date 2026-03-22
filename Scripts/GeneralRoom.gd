extends Node2D

const CORRECT_SOUND_PATH := "res://Audio/New Sounds/New Correct sound/mixkit-correct-answer-fast-notification-953.wav"
const WRONG_SOUND_PATH := "res://Audio/New Sounds/Wrong sounds/tunetank.com_abort-operation.wav"
const LEVEL_TRANSITION_SOUND_PATH := "res://Audio/New Sounds/New Correct sound/mixkit-correct-answer-notification-947.wav"
const BACKGROUND_MUSIC_PATH := "res://Audio/New Sounds/Background music/Background.mp3"

enum RoomPhase {
	LOCKED,
	CLUE_DISCOVERED,
	ACCESS_GRANTED,
	TRANSITIONING
}

@export var currentQuestion: String = "What does this chamber require?"
@export var expectedAnswer: String = ""

@onready var meta_label: Label = $Control2/MetaLabel
@onready var professor_line: Label = $Control2/ProfessorPanel/ProfessorBox/ProfessorLine
@onready var professor_portrait: TextureRect = $Control2/ProfessorPanel/ProfessorBox/ProfessorPortrait
@onready var question_desk: ColorRect = $Control2/Desk
@onready var clue_note: PanelContainer = $Control2/ClueNote
@onready var clue_text: Label = $Control2/ClueNote/ClueText
@onready var clue_note_button: Button = $Control2/ClueNoteButton
@onready var terminal_base: ColorRect = $Control2/TerminalBase
@onready var terminal_panel: PanelContainer = $Control2/TerminalPanel
@onready var terminal_status: Label = $Control2/TerminalPanel/TerminalVBox/TerminalStatus
@onready var terminal_button: Button = $Control2/TerminalPanel/TerminalVBox/TerminalButton
@onready var terminal_input: TextEdit = $Control2/TerminalPanel/TerminalVBox/TerminalInput
@onready var submit_button: Button = $Control2/TerminalPanel/TerminalVBox/AnswerButton1
@onready var status_label: Label = $Control2/StatusLabel
@onready var room_prompt: Label = $Control2/RoomPrompt
@onready var hint_label: Label = $Control2/HintLabel
@onready var door: ColorRect = $Control2/Door
@onready var doorway: ColorRect = $Control2/Door/Doorway
@onready var door_panel: ColorRect = $Control2/Door/DoorPanel
@onready var door_label: Label = $Control2/Door/DoorLabel
@onready var door_lock_light: ColorRect = $Control2/Door/DoorLockLight
@onready var player_marker: ColorRect = $Control2/PlayerMarker
@onready var timer_label: Label = $Control2/TimerLabel
@onready var countdown_timer: Timer = $Control2/CountdownTimer
@onready var exit_button: Button = $Control2/ExitButton

var background_music_player: AudioStreamPlayer
var correct_player: AudioStreamPlayer
var wrong_player: AudioStreamPlayer
var transition_player: AudioStreamPlayer

var room_phase := RoomPhase.LOCKED
var end_state_triggered := false
var current_professor: Dictionary = {}
var player_start_position := Vector2.ZERO
var player_exit_position := Vector2.ZERO
var active_room_tween: Tween
var door_closed_top := 14.0
var door_closed_bottom := -14.0
var _portrait_bounce_tween: Tween = null
var _portrait_rest_y: float = 0.0

var professors := [
	{
		"name": "Professor Vex",
		"portrait": "res://Images/angryBot.png",
		"intro": [
			"Release the right lock and the path will open.",
			"One clue. One console. Do not waste either.",
			"This chamber yields only to a sharp mind."
		],
		"wrong": [
			"Access denied. Think harder.",
			"That input does not fit the lock.",
			"The chamber rejects that response."
		],
		"hint": [
			"I will offer one clue. Use it well.",
			"Very well. Here is your room clue.",
			"A narrow clue. Nothing more."
		],
		"success": [
			"Hm. Acceptable.",
			"Access granted. Move on.",
			"The lock releases. Do not linger."
		],
		"defeat": [
			"The chamber closes on the unprepared.",
			"You were not ready for this trial.",
			"The hall keeps what it defeats."
		]
	},
	{
		"name": "Professor Hale",
		"portrait": "res://Images/neutralface.png",
		"intro": [
			"Study the clue. Then use the terminal.",
			"The right response is already in the room.",
			"Steady thinking will open this chamber."
		],
		"wrong": [
			"Not quite. Try another input.",
			"That response does not match the clue.",
			"Close. Refine the idea."
		],
		"hint": [
			"Use the strongest idea in the clue.",
			"Here is a nudge in the right direction.",
			"Focus on the concept, not the wording."
		],
		"success": [
			"Good. The path is opening.",
			"Well reasoned.",
			"That opened it. Continue."
		],
		"defeat": [
			"This round is over. Return when ready.",
			"The chamber wins for now.",
			"You will get another chance."
		]
	},
	{
		"name": "Professor Mira",
		"portrait": "res://Images/happyface.png",
		"intro": [
			"You can do this. Start with the note.",
			"One careful response opens the way.",
			"Take a breath. The clue will guide you."
		],
		"wrong": [
			"Not this one. Try again.",
			"That was close. Read the clue once more.",
			"Keep going. The right response is near."
		],
		"hint": [
			"Here is a clue to help you forward.",
			"Look for the concept that fits best.",
			"You already have what you need."
		],
		"success": [
			"Nice work. The door is opening.",
			"Yes, that was it.",
			"Great job. Keep moving."
		],
		"defeat": [
			"It is okay. Try again from the start.",
			"This room can be beaten next time.",
			"The trial ends here, but not your progress."
		]
	}
]


func _ready() -> void:
	_configure_audio()
	if not countdown_timer.timeout.is_connected(on_timer_timeout):
		countdown_timer.timeout.connect(on_timer_timeout)
	countdown_timer.wait_time = 1.0
	countdown_timer.one_shot = false
	countdown_timer.start()
	player_start_position = player_marker.position
	player_exit_position = Vector2(door.position.x + (door.size.x * 0.5) - (player_marker.size.x * 0.35), door.position.y + 110.0)
	clue_note_button.pressed.connect(_on_clue_note_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_load_room_data()
	_load_current_room()
	_play_entrance_animation()


func _process(_delta: float) -> void:
	meta_label.text = "Chamber %d/%d   Trial Timer %s" % [
		Global.index + 1,
		max(Global.rooms.size(), 1),
		_format_trial_time(Global.globalTime)
	]


func _load_room_data() -> void:
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


func _load_current_room() -> void:
	end_state_triggered = false
	room_phase = RoomPhase.LOCKED
	current_professor = _select_professor(Global.index)
	_apply_professor_portrait()
	professor_line.text = _professor_line("intro")
	professor_line.visible_characters = 0
	$Control2/ProfessorPanel.modulate.a = 0.0
	clue_text.text = "CLUE NOTE\nInspect to reveal."
	status_label.text = ""
	room_prompt.text = "Inspect the note or enter your response."
	hint_label.text = ""
	terminal_status.text = "INPUT CHANNEL OPEN"
	terminal_button.visible = false
	terminal_button.disabled = true
	terminal_input.text = ""
	terminal_input.editable = true
	terminal_input.modulate = Color(1, 1, 1, 1)
	submit_button.disabled = false
	submit_button.modulate = Color(1, 1, 1, 1)
	terminal_panel.modulate = Color(1, 1, 1, 0.95)
	door_lock_light.color = Color("c53a2f")
	doorway.color = Color(0.055, 0.090, 0.122, 1.0)
	door_panel.offset_top = door_closed_top
	door_panel.offset_bottom = door_closed_bottom
	door_label.modulate = Color(1, 1, 1, 1)
	player_marker.position = player_start_position
	player_marker.scale = Vector2.ONE
	player_marker.modulate = Color(1, 1, 1, 1)
	room_phase = RoomPhase.CLUE_DISCOVERED


func _on_clue_note_pressed() -> void:
	if room_phase == RoomPhase.TRANSITIONING or room_phase == RoomPhase.ACCESS_GRANTED:
		return
	clue_text.text = _format_clue_text(currentQuestion)
	status_label.text = "Clue found."
	room_prompt.text = "Enter your response."
	_speak(_professor_line("hint"))
	terminal_input.grab_focus()


func handle_answer_correct() -> void:
	if room_phase == RoomPhase.TRANSITIONING or room_phase == RoomPhase.ACCESS_GRANTED:
		return
	room_phase = RoomPhase.ACCESS_GRANTED
	status_label.text = "Access granted."
	room_prompt.text = "Door unlocking..."
	hint_label.text = ""
	_speak(_professor_line("success"))
	terminal_status.text = "ACCESS GRANTED"
	terminal_input.editable = false
	submit_button.disabled = true
	door_lock_light.color = Color("6fdc74")
	_play_sound(correct_player)
	_play_transition_sound()
	_open_vault()
	_advance_after_delay()


func handle_answer_wrong(hint: String) -> void:
	if room_phase == RoomPhase.TRANSITIONING or room_phase == RoomPhase.ACCESS_GRANTED:
		return
	status_label.text = "Access denied."
	room_prompt.text = "Refine your response."
	hint_label.text = "Room clue: %s" % hint
	_speak(_professor_line("wrong"))
	door_lock_light.color = Color("d14a3a")
	_play_sound(wrong_player)
	var flash_tween := create_tween()
	flash_tween.tween_property(door_lock_light, "color", Color("c53a2f"), 0.25)


func on_timer_timeout() -> void:
	Global.globalTime -= 1
	if Global.globalTime <= 0 and not end_state_triggered:
		countdown_timer.stop()
		end_state_triggered = true
		_speak(_professor_line("defeat"))
		status_label.text = "Lockdown."
		room_prompt.text = "The chamber seals shut."
		terminal_input.editable = false
		submit_button.disabled = true
		await get_tree().create_timer(1.6).timeout
		_return_to_main_after_delay()


func _return_to_main_after_delay() -> void:
	countdown_timer.stop()
	Global.index = 0
	Global.rooms.clear()
	Global.globalTime = Global.selected_hint_time
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_exit_pressed() -> void:
	countdown_timer.stop()
	Global.index = 0
	Global.rooms.clear()
	Global.globalTime = Global.selected_hint_time
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _open_vault() -> void:
	if active_room_tween != null:
		active_room_tween.kill()
	active_room_tween = create_tween()
	active_room_tween.set_trans(Tween.TRANS_SINE)
	active_room_tween.set_ease(Tween.EASE_OUT)
	active_room_tween.parallel().tween_property(door, "color", Color(0.204, 0.596, 0.859, 1.0), 0.25)
	active_room_tween.parallel().tween_property(doorway, "color", Color(0.102, 0.737, 0.612, 0.9), 0.25)
	active_room_tween.parallel().tween_property(door_panel, "offset_top", -150.0, 0.8)
	active_room_tween.parallel().tween_property(door_panel, "offset_bottom", -178.0, 0.8)
	active_room_tween.parallel().tween_property(door_label, "modulate:a", 0.0, 0.4)
	active_room_tween.tween_property(player_marker, "position", Vector2(player_start_position.x, 236.0), 0.22)
	active_room_tween.tween_property(player_marker, "position", Vector2(player_start_position.x, 170.0), 0.22)
	active_room_tween.tween_property(player_marker, "position", Vector2(player_start_position.x, 104.0), 0.22)
	active_room_tween.tween_property(player_marker, "position", player_exit_position, 0.35)
	active_room_tween.parallel().tween_property(player_marker, "scale", Vector2(0.42, 0.42), 0.32)
	active_room_tween.parallel().tween_property(player_marker, "modulate:a", 0.25, 0.32)


func _advance_after_delay() -> void:
	await get_tree().create_timer(1.9).timeout
	if Global.rooms.is_empty() or Global.index >= Global.rooms.size() - 1:
		_show_victory_and_return()
		return
	Global.index += 1
	get_tree().change_scene_to_file("res://Scenes/Questionhints.tscn")


func _show_victory_and_return() -> void:
	status_label.text = "Trial complete."
	room_prompt.text = "Every chamber cleared."
	await get_tree().create_timer(1.2).timeout
	countdown_timer.stop()
	Global.index = 0
	Global.rooms.clear()
	Global.globalTime = Global.selected_hint_time
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _configure_audio() -> void:
	background_music_player = AudioStreamPlayer.new()
	background_music_player.bus = "Music"
	add_child(background_music_player)
	var background_stream: Variant = load(BACKGROUND_MUSIC_PATH)
	if background_stream is AudioStream:
		background_music_player.stream = background_stream
		if background_music_player.stream is AudioStreamMP3:
			background_music_player.stream.loop = true
		background_music_player.volume_db = -14.0
		background_music_player.play()

	correct_player = AudioStreamPlayer.new()
	correct_player.bus = "SFX"
	add_child(correct_player)
	var correct_stream: Variant = load(CORRECT_SOUND_PATH)
	if correct_stream is AudioStream:
		correct_player.stream = correct_stream

	wrong_player = AudioStreamPlayer.new()
	wrong_player.bus = "SFX"
	add_child(wrong_player)
	var wrong_stream: Variant = load(WRONG_SOUND_PATH)
	if wrong_stream is AudioStream:
		wrong_player.stream = wrong_stream

	transition_player = AudioStreamPlayer.new()
	transition_player.bus = "SFX"
	add_child(transition_player)
	var transition_stream: Variant = load(LEVEL_TRANSITION_SOUND_PATH)
	if transition_stream is AudioStream:
		transition_player.stream = transition_stream


func _play_entrance_animation() -> void:
	# Wait one frame so Control layout is fully computed before reading positions/sizes
	await get_tree().process_frame

	var prof_panel := $Control2/ProfessorPanel
	var rest_x: float = prof_panel.global_position.x
	# Place professor fully off the left edge, then make it visible
	prof_panel.global_position.x = -prof_panel.size.x - 20.0
	prof_panel.modulate.a = 1.0
	professor_line.visible_characters = 0

	clue_note.modulate.a = 0.0
	terminal_panel.modulate.a = 0.0
	door.modulate.a = 0.0

	# Professor slides in from the left, then typewriter plays
	var prof_tw := create_tween()
	prof_tw.tween_property(prof_panel, "global_position:x", rest_x, 0.55).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	prof_tw.tween_callback(func() -> void: _play_typewriter(professor_line))

	# Other elements fade in alongside the entrance
	var bg_tw := create_tween().set_parallel(true)
	bg_tw.tween_property(clue_note, "modulate:a", 1.0, 0.5).set_delay(0.2)
	bg_tw.tween_property(terminal_panel, "modulate:a", 0.45, 0.5).set_delay(0.25)
	bg_tw.tween_property(door, "modulate:a", 1.0, 0.45).set_delay(0.1)


func _play_typewriter(label: Label) -> void:
	label.visible_characters = 0
	var total: int = label.text.length()
	if total == 0:
		label.visible_characters = -1
		return
	_start_portrait_bounce()
	var tw := create_tween()
	tw.tween_property(label, "visible_characters", total, total * 0.045).set_trans(Tween.TRANS_LINEAR)
	tw.tween_callback(_stop_portrait_bounce)


func _speak(text: String) -> void:
	professor_line.text = text
	_play_typewriter(professor_line)


func _start_portrait_bounce() -> void:
	if _portrait_bounce_tween != null:
		_portrait_bounce_tween.kill()
	_portrait_rest_y = professor_portrait.position.y
	_portrait_bounce_tween = create_tween().set_loops()
	_portrait_bounce_tween.tween_property(professor_portrait, "position:y", _portrait_rest_y - 5.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_portrait_bounce_tween.tween_property(professor_portrait, "position:y", _portrait_rest_y, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _stop_portrait_bounce() -> void:
	if _portrait_bounce_tween != null:
		_portrait_bounce_tween.kill()
		_portrait_bounce_tween = null
	professor_portrait.position.y = _portrait_rest_y


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


func _play_transition_sound() -> void:
	_play_sound(transition_player)


func _play_sound(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()


func _format_clue_text(question_text: String) -> String:
	var cleaned := question_text.strip_edges()
	if cleaned.is_empty():
		return "The clue has faded."
	return cleaned


func _format_trial_time(total_seconds: int) -> String:
	var clamped_seconds: int = maxi(total_seconds, 0)
	var minutes: int = int(clamped_seconds / 60)
	var seconds: int = int(clamped_seconds % 60)
	return "%02d:%02d" % [minutes, seconds]
