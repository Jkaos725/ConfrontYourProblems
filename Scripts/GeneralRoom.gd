# GeneralRoom.gd
# Controls the Questionhints scene — an essay-answer escape room.
# The player reads a clue note, types a free-text answer into a terminal,
# and the answer is graded by the AI via answer_http_request.gd.
# On a correct answer the room reveals a 4-digit keypad code; the player
# must enter the code to open the door and advance to the next room.
#
# Room phases (RoomPhase enum):
#   LOCKED           — initial state before the clue note is inspected.
#   CLUE_DISCOVERED  — clue visible, terminal active, keypad locked.
#   ACCESS_GRANTED   — correct answer submitted, keypad code revealed.
#   TRANSITIONING    — door opening animation playing, inputs disabled.
#
# Professor system:
#   One of three professors (Vex, Hale, Mira) is selected via Global.selected_professor.
#   Each professor has dialogue lines for: intro, hint, success, wrong, defeat.
#   All professor speech goes through _speak() which runs the typewriter effect and TTS.
extends Node2D

# TTS_RATE: controls how fast the professor speaks.
# 1.0 = normal speed | 1.5 = 50% faster | 2.0 = double speed
# To change speed: adjust the number below (range: 0.1 – 10.0)
const TTS_RATE := 1.5

# Audio asset paths loaded at startup by _configure_audio().
const CORRECT_SOUND_PATH := "res://Audio/New Sounds/New Correct sound/mixkit-correct-answer-fast-notification-953.wav"
const WRONG_SOUND_PATH := "res://Audio/New Sounds/Wrong sounds/tunetank.com_abort-operation.wav"
const LEVEL_TRANSITION_SOUND_PATH := "res://Audio/New Sounds/New Correct sound/mixkit-correct-answer-notification-947.wav"
const BACKGROUND_MUSIC_PATH := "res://Audio/New Sounds/Background music/Background.mp3"

# Tracks which interactive phase the room is currently in.
enum RoomPhase {
	LOCKED,
	CLUE_DISCOVERED,
	ACCESS_GRANTED,
	TRANSITIONING
}

# The question text displayed in the clue note. Set by _load_room_data() from Global.rooms.
@export var currentQuestion: String = "What does this chamber require?"
# The correct answer string used for AI grading. Set by _load_room_data() from Global.rooms.
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
@onready var keypad_display: Label = $Control2/KeypadPanel/KeypadVBox/KeypadDisplay
@onready var code_display: Label = $Control2/KeypadPanel/KeypadVBox/CodeDisplay
@onready var digit_1: Button = $Control2/KeypadPanel/KeypadVBox/NumpadGrid/Digit1
@onready var digit_2: Button = $Control2/KeypadPanel/KeypadVBox/NumpadGrid/Digit2
@onready var digit_3: Button = $Control2/KeypadPanel/KeypadVBox/NumpadGrid/Digit3
@onready var digit_4: Button = $Control2/KeypadPanel/KeypadVBox/NumpadGrid/Digit4
@onready var digit_5: Button = $Control2/KeypadPanel/KeypadVBox/NumpadGrid/Digit5
@onready var digit_6: Button = $Control2/KeypadPanel/KeypadVBox/NumpadGrid/Digit6
@onready var digit_7: Button = $Control2/KeypadPanel/KeypadVBox/NumpadGrid/Digit7
@onready var digit_8: Button = $Control2/KeypadPanel/KeypadVBox/NumpadGrid/Digit8
@onready var digit_9: Button = $Control2/KeypadPanel/KeypadVBox/NumpadGrid/Digit9
@onready var digit_0: Button = $Control2/KeypadPanel/KeypadVBox/NumpadGrid/Digit0
@onready var clear_button: Button = $Control2/KeypadPanel/KeypadVBox/NumpadGrid/ClearButton
@onready var enter_button: Button = $Control2/KeypadPanel/KeypadVBox/NumpadGrid/EnterButton
@onready var door: ColorRect = $Control2/Door
@onready var doorway: ColorRect = $Control2/Door/Doorway
@onready var door_panel: ColorRect = $Control2/Door/DoorPanel
@onready var door_label: Label = $Control2/Door/DoorLabel
@onready var door_lock_light: ColorRect = $Control2/Door/DoorLockLight
@onready var player_marker: ColorRect = $Control2/PlayerMarker
@onready var timer_label: Label = $Control2/TimerLabel
@onready var countdown_timer: Timer = $Control2/CountdownTimer
@onready var exit_button: Button = $Control2/ExitButton

# Dynamically created AudioStreamPlayer nodes for each sound category.
var background_music_player: AudioStreamPlayer
var correct_player: AudioStreamPlayer
var wrong_player: AudioStreamPlayer
var transition_player: AudioStreamPlayer

# Current phase of the room — controls which inputs are active.
var room_phase := RoomPhase.LOCKED
# Prevents the defeat/timeout sequence from triggering more than once.
var end_state_triggered := false
# The professor dictionary selected for this session (name, portrait, dialogue lines).
var current_professor: Dictionary = {}
# World position of the player marker at room start, used to reset between rooms.
var player_start_position := Vector2.ZERO
# World position the player marker animates to when passing through the door.
var player_exit_position := Vector2.ZERO
# The currently running room animation tween. Killed before starting a new one.
var active_room_tween: Tween
# Offset values defining the closed door panel position.
var door_closed_top := 14.0
var door_closed_bottom := -14.0
# Tween that makes the professor portrait bounce while speaking.
var _portrait_bounce_tween: Tween = null
# Resting Y position of the professor portrait, restored when bouncing stops.
var _portrait_rest_y: float = 0.0
# The randomly generated 4-digit code revealed on a correct answer.
var keypad_code := ""
# The digits the player has entered on the keypad so far.
var keypad_input := ""
# All digit buttons collected into an array for bulk enable/disable.
var keypad_buttons: Array[Button] = []

# Local professor dialogue data for this scene.
# Each professor has five dialogue categories: intro, hint, success, wrong, defeat.
# A random line from the matching category is chosen each time _professor_line() is called.
# The active professor is selected by _select_professor() using Global.selected_professor.
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


# Sets up audio, connects the countdown timer and all interactive buttons,
# loads room data from Global.rooms, and plays the entrance animation.
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
	keypad_buttons = [digit_1, digit_2, digit_3, digit_4, digit_5, digit_6, digit_7, digit_8, digit_9, digit_0]
	for button in keypad_buttons:
		button.pressed.connect(_on_keypad_digit_pressed.bind(button.text))
	clear_button.pressed.connect(_on_keypad_clear_pressed)
	enter_button.pressed.connect(_on_keypad_enter_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_load_room_data()
	_load_current_room()
	_play_entrance_animation()


# Updates the meta label every frame with the current chamber index and formatted trial time.
func _process(_delta: float) -> void:
	meta_label.text = "Chamber %d/%d   Trial Timer %s" % [
		Global.index + 1,
		max(Global.rooms.size(), 1),
		_format_trial_time(Global.globalTime)
	]


# Reads the current room's question and expected answer from Global.rooms[Global.index]
# and writes them to currentQuestion and expectedAnswer.
# Also propagates these values to any child nodes that expose matching properties
# (e.g. answer_http_request.gd reads currentQuestion/expectedAnswer from its parent).
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


# Resets all room UI and state to the initial LOCKED condition.
# Selects and displays the professor, generates a new keypad code,
# fires TTS for the intro line, and sets phase to CLUE_DISCOVERED.
func _load_current_room() -> void:
	end_state_triggered = false
	room_phase = RoomPhase.LOCKED
	current_professor = _select_professor(Global.index)
	_apply_professor_portrait()
	professor_line.text = _professor_line("intro")
	_tts_speak(professor_line.text)
	professor_line.visible_characters = 0
	$Control2/ProfessorPanel.modulate.a = 0.0
	clue_text.text = "CLUE NOTE\nInspect to reveal."
	status_label.text = ""
	room_prompt.text = "Inspect the note or answer below."
	hint_label.text = ""
	terminal_status.text = "Type your answer below."
	terminal_button.visible = false
	terminal_button.disabled = true
	terminal_input.text = ""
	terminal_input.editable = true
	terminal_input.modulate = Color(1, 1, 1, 1)
	submit_button.disabled = false
	submit_button.modulate = Color(1, 1, 1, 1)
	keypad_code = _generate_keypad_code()
	keypad_input = ""
	code_display.text = "_ _ _ _"
	keypad_display.text = "LOCKED"
	_set_keypad_enabled(true)
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


# Reveals the full clue text when the player clicks the clue note button.
# Updates the professor line with a hint and focuses the terminal input.
# Does nothing if the room is already transitioning or completed.
func _on_clue_note_pressed() -> void:
	if room_phase == RoomPhase.TRANSITIONING or room_phase == RoomPhase.ACCESS_GRANTED:
		return
	clue_text.text = _format_clue_text(currentQuestion)
	status_label.text = "Clue found."
	room_prompt.text = "Answer below."
	_speak(_professor_line("hint"))
	terminal_input.grab_focus()


# Called by answer_http_request.gd when the AI grades the student's answer as correct.
# Reveals the 4-digit keypad code, plays the correct sound, and begins the door-open animation.
# Called externally — must be public (no underscore prefix).
func handle_answer_correct() -> void:
	if room_phase == RoomPhase.TRANSITIONING or room_phase == RoomPhase.ACCESS_GRANTED:
		return
	room_phase = RoomPhase.ACCESS_GRANTED
	keypad_input = ""
	_refresh_code_display()
	status_label.text = "Code revealed: %s" % keypad_code
	room_prompt.text = "Enter the code."
	hint_label.text = ""
	_speak(_professor_line("success"))
	terminal_status.text = "Code revealed."
	door_lock_light.color = Color("6fdc74")
	_play_sound(correct_player)
	keypad_display.text = "READY"


# Called by answer_http_request.gd when the AI grades the answer as wrong.
# Displays the AI-generated hint, flashes the door lock light red, and plays the wrong sound.
# hint: the hint string returned by the AI in the second API call.
# Called externally — must be public.
func handle_answer_wrong(hint: String) -> void:
	if room_phase == RoomPhase.TRANSITIONING or room_phase == RoomPhase.ACCESS_GRANTED:
		return
	status_label.text = "Try again."
	room_prompt.text = "Try again."
	hint_label.text = "Room clue: %s" % hint
	_speak(_professor_line("wrong"))
	door_lock_light.color = Color("d14a3a")
	_play_sound(wrong_player)
	var flash_tween := create_tween()
	flash_tween.tween_property(door_lock_light, "color", Color("c53a2f"), 0.25)


# Appends a digit to keypad_input when a numpad button is pressed.
# Ignores input if the room is transitioning or all 4 digits are already entered.
func _on_keypad_digit_pressed(digit: String) -> void:
	if room_phase == RoomPhase.TRANSITIONING:
		return
	if keypad_input.length() >= 4:
		return
	keypad_input += digit
	_refresh_code_display()


# Clears the current keypad input and resets the code display to "_ _ _ _".
func _on_keypad_clear_pressed() -> void:
	if room_phase == RoomPhase.TRANSITIONING:
		return
	keypad_input = ""
	status_label.text = "Enter the code."
	_refresh_code_display()


# Validates the entered 4-digit code against keypad_code.
# On match: transitions the room to TRANSITIONING and opens the vault door.
# On mismatch: flashes DENIED briefly then resets to the previous display state.
func _on_keypad_enter_pressed() -> void:
	if room_phase == RoomPhase.TRANSITIONING:
		return
	if keypad_input.length() < 4:
		status_label.text = "Enter all 4 digits."
		return
	if keypad_input != keypad_code:
		keypad_input = ""
		_refresh_code_display()
		status_label.text = "Wrong code."
		keypad_display.text = "DENIED"
		door_lock_light.color = Color("d14a3a")
		_play_sound(wrong_player)
		var flash_tween := create_tween()
		var reset_light := Color("6fdc74") if room_phase == RoomPhase.ACCESS_GRANTED else Color("c53a2f")
		var reset_display := "READY" if room_phase == RoomPhase.ACCESS_GRANTED else "LOCKED"
		flash_tween.tween_property(door_lock_light, "color", reset_light, 0.25)
		flash_tween.finished.connect(func() -> void:
			if room_phase != RoomPhase.TRANSITIONING:
				keypad_display.text = reset_display
		)
		return

	room_phase = RoomPhase.TRANSITIONING
	keypad_display.text = "OPEN"
	status_label.text = "Path opened."
	room_prompt.text = "Entering..."
	_play_transition_sound()
	_open_vault()
	_advance_after_delay()


# Called every second by the countdown timer. Decrements Global.globalTime.
# When time reaches zero: triggers the defeat sequence, shows the correct answer,
# waits 4 seconds, then returns to the main menu.
# Named without underscore because it is connected via signal, not called directly.
func on_timer_timeout() -> void:
	Global.globalTime -= 1
	if Global.globalTime <= 0 and not end_state_triggered:
		countdown_timer.stop()
		end_state_triggered = true
		_speak(_professor_line("defeat"))
		if expectedAnswer.strip_edges().is_empty():
			status_label.text = "Time up. Answer unavailable."
		else:
			status_label.text = "Time up. Answer: %s" % expectedAnswer
		room_prompt.text = "The chamber seals shut."
		hint_label.text = ""
		terminal_input.editable = false
		submit_button.disabled = true
		await get_tree().create_timer(4.0).timeout
		_return_to_main_after_delay()


# Stops the timer, resets Global session state, and navigates back to the main menu scene.
func _return_to_main_after_delay() -> void:
	countdown_timer.stop()
	Global.index = 0
	Global.rooms.clear()
	Global.globalTime = Global.selected_hint_time
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


# Handles the Exit button. Stops the timer, clears the session, and returns to the main menu.
func _on_exit_pressed() -> void:
	countdown_timer.stop()
	Global.index = 0
	Global.rooms.clear()
	Global.globalTime = Global.selected_hint_time
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


# Plays the door-opening tween sequence: door color changes to blue/green, panels slide up,
# and the player marker animates forward and shrinks as it passes through the doorway.
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


# Waits 1.9 seconds for the door animation, then either shows the victory screen
# (if this was the last room) or increments Global.index and reloads the Questionhints scene.
func _advance_after_delay() -> void:
	await get_tree().create_timer(1.9).timeout
	if Global.rooms.is_empty() or Global.index >= Global.rooms.size() - 1:
		_show_victory_and_return()
		return
	Global.index += 1
	get_tree().change_scene_to_file("res://Scenes/Questionhints.tscn")


# Displays the "Trial complete" message, stops the timer, and returns to the main menu.
# Called when the player clears the final room in the session.
func _show_victory_and_return() -> void:
	status_label.text = "Trial complete."
	room_prompt.text = "Every chamber cleared."
	await get_tree().create_timer(1.2).timeout
	countdown_timer.stop()
	Global.index = 0
	Global.rooms.clear()
	Global.globalTime = Global.selected_hint_time
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


# Creates and configures all AudioStreamPlayer nodes at runtime.
# Loads each audio file from its resource path and assigns it to the correct bus.
# Music goes to the "Music" bus; all sound effects go to the "SFX" bus.
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


# Plays the room intro animation: the professor panel slides in from the left,
# then the typewriter effect and TTS play on the intro line.
# The clue note, terminal panel, and door fade in simultaneously.
# Waits one frame first so the Control layout is fully computed before reading positions.
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


# Animates the professor_line label's visible_characters from 0 to the full length,
# creating a typewriter reveal effect. Also triggers the portrait bounce animation.
# The speed scales with text length at ~0.045 seconds per character.
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


# Sets the professor line text, plays the typewriter animation, and speaks via TTS.
# Central entry point for all professor dialogue — call this instead of setting text directly.
func _speak(text: String) -> void:
	professor_line.text = text
	_play_typewriter(professor_line)
	_tts_speak(text)


# Speaks text aloud using Godot's built-in DisplayServer TTS API.
# Strips the "Professor Name: " prefix so only the dialogue content is spoken.
# Selects the system voice based on which professor is active (_get_professor_voice_index).
# Respects AudioManager.tts_enabled and AudioManager.tts_volume.
# Speed is controlled by the TTS_RATE constant at the top of this file.
func _tts_speak(text: String) -> void:
	if not AudioManager.tts_enabled:
		return
	# Strip "Professor Name: " prefix so only the dialogue is spoken
	var speech_text := text
	var colon_pos := text.find(": ")
	if colon_pos != -1:
		speech_text = text.substr(colon_pos + 2)
	if speech_text.strip_edges().is_empty():
		return
	DisplayServer.tts_stop()
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		return
	var voice_id := voices[_get_professor_voice_index() % voices.size()]
	DisplayServer.tts_speak(speech_text, voice_id, int(AudioManager.tts_volume * 100), 1.0, TTS_RATE)


# Returns a 0-based index into the available TTS voice list based on the current professor.
# Vex → 0, Hale → 1, Mira → 2. Callers use % voices.size() so it wraps safely
# on systems with fewer than three English voices installed.
func _get_professor_voice_index() -> int:
	match str(current_professor.get("name", "")):
		"Professor Vex":  return 0  # First available English voice
		"Professor Hale": return 1  # Second available English voice
		"Professor Mira": return 2  # Third available English voice (wraps if fewer voices exist)
	return 0


# Starts an infinite looping tween that bobs the professor portrait up and down by 5px
# while the professor is speaking. Kills any previously running bounce tween first.
func _start_portrait_bounce() -> void:
	if _portrait_bounce_tween != null:
		_portrait_bounce_tween.kill()
	_portrait_rest_y = professor_portrait.position.y
	_portrait_bounce_tween = create_tween().set_loops()
	_portrait_bounce_tween.tween_property(professor_portrait, "position:y", _portrait_rest_y - 5.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_portrait_bounce_tween.tween_property(professor_portrait, "position:y", _portrait_rest_y, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Stops the portrait bounce tween and snaps the portrait back to its rest Y position.
func _stop_portrait_bounce() -> void:
	if _portrait_bounce_tween != null:
		_portrait_bounce_tween.kill()
		_portrait_bounce_tween = null
	professor_portrait.position.y = _portrait_rest_y


# Returns the professor dictionary matching Global.selected_professor.
# Falls back to cycling through professors by room_index if no name match is found.
func _select_professor(room_index: int) -> Dictionary:
	var selected_name := str(Global.selected_professor)
	for professor in professors:
		var professor_dict: Dictionary = professor
		if str(professor_dict.get("name", "")) == selected_name:
			return professor_dict
	return professors[room_index % professors.size()]


# Builds a formatted dialogue string: "Professor Name: [random line from kind category]".
# kind: one of "intro", "hint", "success", "wrong", "defeat".
# Returns just the professor name if the category has no lines.
func _professor_line(kind: String) -> String:
	var professor_name := str(current_professor.get("name", "Professor"))
	var lines_variant: Variant = current_professor.get(kind, [])
	var lines: Array = lines_variant if lines_variant is Array else []
	if lines.is_empty():
		return professor_name
	return "%s: %s" % [professor_name, _random_line(lines)]


# Returns a random string from the given array. Returns empty string if the array is empty.
func _random_line(lines: Array) -> String:
	if lines.is_empty():
		return ""
	return str(lines[randi() % lines.size()])


# Loads the professor's portrait texture from its res:// path and sets it on the portrait node.
# Does nothing if the portrait path is empty or the texture fails to load.
func _apply_professor_portrait() -> void:
	var portrait_path := str(current_professor.get("portrait", ""))
	if portrait_path.is_empty():
		return
	var texture: Variant = load(portrait_path)
	if texture is Texture2D:
		professor_portrait.texture = texture


# Plays the level transition sound effect (used when the vault door opens).
func _play_transition_sound() -> void:
	_play_sound(transition_player)


# Stops any currently playing audio on the given player, applies a small random pitch
# variation (±5%) for variety, then plays the sound.
# Does nothing if the player or its stream is null.
func _play_sound(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()


# Trims whitespace from the question text for display in the clue note.
# Returns a fallback string if the question is empty.
func _format_clue_text(question_text: String) -> String:
	var cleaned := question_text.strip_edges()
	if cleaned.is_empty():
		return "The clue has faded."
	return cleaned


# Enables or disables all keypad digit buttons, the clear button, and the enter button.
# Also adjusts modulate alpha so disabled buttons appear faded.
func _set_keypad_enabled(enabled: bool) -> void:
	for button in keypad_buttons:
		button.disabled = not enabled
		button.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.45)
	clear_button.disabled = not enabled
	clear_button.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.45)
	enter_button.disabled = not enabled
	enter_button.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.45)


# Updates the code display label to show entered digits and underscores for empty slots.
# e.g. if keypad_input is "42" it shows "4 2 _ _".
func _refresh_code_display() -> void:
	var display_parts: Array[String] = []
	for index in range(4):
		if index < keypad_input.length():
			display_parts.append(keypad_input.substr(index, 1))
		else:
			display_parts.append("_")
	code_display.text = " ".join(display_parts)


# Generates a random 4-digit code string (e.g. "3071") revealed when the answer is correct.
# Each digit is independently random 0–9.
func _generate_keypad_code() -> String:
	var code := ""
	for _i in range(4):
		code += str(randi_range(0, 9))
	return code


# Converts a raw seconds value to "MM:SS" format for the meta label timer display.
# Clamps to zero so the display never shows negative time.
func _format_trial_time(total_seconds: int) -> String:
	var clamped_seconds: int = maxi(total_seconds, 0)
	var minutes: int = int(clamped_seconds / 60)
	var seconds: int = int(clamped_seconds % 60)
	return "%02d:%02d" % [minutes, seconds]
