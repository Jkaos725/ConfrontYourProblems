# server_vault_room.gd
# Controls the ServerVaultRoom scene — a multiple-choice escape room.
# The player inspects a clue note then picks one of three labeled buttons (A, B, C).
# A correct choice reveals a 4-digit keypad code; the player enters it to open the door.
# Wrong choices consume lives — at zero lives the defeat sequence plays.
#
# Room phases (RoomPhase enum):
#   LOCKED           — initial state, choices disabled until the clue is inspected.
#   CLUE_DISCOVERED  — clue visible, choices enabled.
#   ACCESS_GRANTED   — correct choice made, keypad code revealed.
#   TRANSITIONING    — door-open animation playing, all inputs disabled.
#
# Visual theming: each room index cycles through three color palettes (room_palettes array),
# changing backgrounds, panel colors, and button styles procedurally.
#
# Professor system: same three professors as GeneralRoom (Vex, Hale, Mira).
# All dialogue goes through _speak() which triggers the typewriter effect and TTS.
extends Control

# TTS_RATE: controls how fast the professor speaks.
# 1.0 = normal speed | 1.5 = 50% faster | 2.0 = double speed
# To change speed: adjust the number below (range: 0.1 – 10.0)
const TTS_RATE := 1.5

# Default number of lives a session starts with (overridden by Global.selected_lives).
const START_LIVES := 3
# Audio asset paths loaded at startup by _configure_audio().
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

@onready var title_label: Label = $TitleLabel
@onready var meta_label: Label = $MetaLabel
@onready var professor_line: Label = $ProfessorPanel/ProfessorBox/ProfessorLine
@onready var professor_portrait: TextureRect = $ProfessorPanel/ProfessorBox/ProfessorPortrait
@onready var background: ColorRect = $Background
@onready var top_glow: ColorRect = $TopGlow
@onready var back_wall_band: ColorRect = $BackWallBand
@onready var floor: ColorRect = $Floor
@onready var center_path: ColorRect = $CenterPath
@onready var door_shadow: ColorRect = $DoorShadow
@onready var clue_note: PanelContainer = $ClueNote
@onready var clue_text: Label = $ClueNote/ClueText
@onready var clue_note_button: Button = $ClueNoteButton
@onready var status_label: Label = $StatusLabel
@onready var terminal_base: ColorRect = $TerminalBase
@onready var terminal_panel: PanelContainer = $TerminalPanel
@onready var terminal_header: Label = $TerminalPanel/TerminalVBox/TerminalHeader
@onready var terminal_status: Label = $TerminalPanel/TerminalVBox/TerminalStatus
@onready var terminal_button: Button = $TerminalPanel/TerminalVBox/TerminalButton
@onready var choice_a: Button = $TerminalPanel/TerminalVBox/Choices/ChoiceA
@onready var choice_b: Button = $TerminalPanel/TerminalVBox/Choices/ChoiceB
@onready var choice_c: Button = $TerminalPanel/TerminalVBox/Choices/ChoiceC
@onready var exit_button: Button = $ExitButton
@onready var door: ColorRect = $Door
@onready var doorway: ColorRect = $Door/Doorway
@onready var door_panel: ColorRect = $Door/DoorPanel
@onready var door_label: Label = $Door/DoorLabel
@onready var door_lock_light: ColorRect = $Door/DoorLockLight
@onready var door_click_area: Button = $Door/DoorClickArea
@onready var professor_panel: PanelContainer = $ProfessorPanel
@onready var keypad_panel: PanelContainer = $KeypadPanel
@onready var keypad_title: Label = $KeypadPanel/KeypadVBox/KeypadTitle
@onready var keypad_display: Label = $KeypadPanel/KeypadVBox/KeypadDisplay
@onready var code_display: Label = $KeypadPanel/KeypadVBox/CodeDisplay
@onready var digit_1: Button = $KeypadPanel/KeypadVBox/NumpadGrid/Digit1
@onready var digit_2: Button = $KeypadPanel/KeypadVBox/NumpadGrid/Digit2
@onready var digit_3: Button = $KeypadPanel/KeypadVBox/NumpadGrid/Digit3
@onready var digit_4: Button = $KeypadPanel/KeypadVBox/NumpadGrid/Digit4
@onready var digit_5: Button = $KeypadPanel/KeypadVBox/NumpadGrid/Digit5
@onready var digit_6: Button = $KeypadPanel/KeypadVBox/NumpadGrid/Digit6
@onready var digit_7: Button = $KeypadPanel/KeypadVBox/NumpadGrid/Digit7
@onready var digit_8: Button = $KeypadPanel/KeypadVBox/NumpadGrid/Digit8
@onready var digit_9: Button = $KeypadPanel/KeypadVBox/NumpadGrid/Digit9
@onready var digit_0: Button = $KeypadPanel/KeypadVBox/NumpadGrid/Digit0
@onready var clear_button: Button = $KeypadPanel/KeypadVBox/NumpadGrid/ClearButton
@onready var enter_button: Button = $KeypadPanel/KeypadVBox/NumpadGrid/EnterButton
@onready var room_prompt: Label = $RoomPrompt
@onready var hint_label: Label = $HintLabel
@onready var player_marker: ColorRect = $PlayerMarker

# The loaded room dictionary from Global.rooms[Global.index], or a fallback demo room.
var current_room: Dictionary = {}
# Index of the correct answer in the answers array (0=A, 1=B, 2=C).
var correct_choice := 1
# True once the player has selected the correct choice and received the keypad code.
var solved := false
# Current phase of the room's state machine.
var room_phase := RoomPhase.LOCKED
# Pixel offset for the top edge of door_panel in the closed/locked position.
var door_closed_top := 14.0
# Pixel offset for the bottom edge of door_panel in the closed/locked position.
var door_closed_bottom := -14.0
# Where player_marker rests at the start of the room (recorded in _ready).
var player_start_position := Vector2.ZERO
# Target position player_marker moves to when walking through the open door.
var player_exit_position := Vector2.ZERO
# Shared Tween used for room transitions and door animation. Killed on room reload.
var active_room_tween: Tween
# The selected professor dictionary for the current room (name, portrait, dialogue lines).
var current_professor: Dictionary = {}
# Active portrait-bounce tween; null when the portrait is at rest.
var _portrait_bounce_tween: Tween = null
# Resting Y position of professor_portrait, recorded before each bounce starts.
var _portrait_rest_y: float = 0.0
# AudioStreamPlayer for the correct-answer sound effect (SFX bus).
var correct_player: AudioStreamPlayer
# AudioStreamPlayer for the wrong-answer sound effect (SFX bus).
var wrong_player: AudioStreamPlayer
# AudioStreamPlayer for the level-transition fanfare (SFX bus).
var transition_player: AudioStreamPlayer
# AudioStreamPlayer for background music (Music bus).
var background_music_player: AudioStreamPlayer
# The 4-digit code the player must enter after selecting the correct answer.
var keypad_code := ""
# Digits the player has typed so far (up to 4 characters).
var keypad_input := ""
# All digit buttons collected into an array so they can be enabled/disabled together.
var keypad_buttons: Array[Button] = []
# Professor dialogue data. Each entry has a name, portrait path, and five
# dialogue categories (intro, wrong, hint, success, defeat), each an Array of String lines.
# The active professor is chosen by _select_professor() and stored in current_professor.
var professors := [
	{
		"name": "Professor Vex",
		"portrait": "res://Images/angryBot.png",
		"intro": [
			"Release the right lock and I may let you pass.",
			"One lock. One clue. Do not embarrass yourself.",
			"The door listens only to sharp minds.",
			"Solve it quickly, or remain in my hall."
		],
		"wrong": [
			"Wrong. Look closer.",
			"No. Think before you touch the lock.",
			"Careless. The seal still holds.",
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
			"Access granted. Move before I change my mind."
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
		"portrait": "res://Images/neutralface.png",
		"intro": [
			"Take your time and study the clue carefully.",
			"This room rewards steady thinking.",
			"The right signal is here if you follow the pattern.",
			"Stay calm. The door will open for the prepared."
		],
		"wrong": [
			"Not quite. Try another angle.",
			"Close reading will help here.",
			"That signal does not fit. Try again.",
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
		"portrait": "res://Images/happyface.png",
		"intro": [
			"You can do this. Start with the clue in front of you.",
			"Take a breath. One careful choice opens the way.",
			"The exit is closer than it looks.",
			"Trust what you know and move step by step."
		],
		"wrong": [
			"Not this one. The seal still holds.",
			"That was a good attempt. Look once more.",
			"Keep going. The right signal is near.",
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
# Three color palettes cycled by room index. Each palette is a Dictionary of named
# Color values applied to all visual elements by _apply_palette(). Palette index =
# Global.index % room_palettes.size(), so every third room uses the same color scheme.
var room_palettes := [
	{
		# Midnight Blue / Turquoise
		"background":   Color(0.173, 0.243, 0.314, 1.0),
		"glow":         Color(0.102, 0.737, 0.612, 0.10),
		"wall":         Color(0.204, 0.286, 0.369, 0.9),
		"floor":        Color(0.118, 0.173, 0.224, 1.0),
		"path":         Color(0.204, 0.286, 0.369, 0.78),
		"desk":         Color(0.141, 0.200, 0.259, 0.92),
		"door":         Color(0.122, 0.176, 0.239, 1.0),
		"panel_bg":     Color(0.122, 0.176, 0.239, 0.96),
		"panel_border": Color(0.102, 0.737, 0.612, 1.0),
		"text_primary": Color(0.925, 0.941, 0.945, 1.0),
		"text_secondary":Color(0.741, 0.765, 0.780, 1.0),
		"text_hint":    Color(0.584, 0.647, 0.651, 1.0),
		"text_accent":  Color(0.102, 0.737, 0.612, 1.0),
		"button_bg":    Color(0.204, 0.286, 0.369, 1.0),
		"button_border":Color(0.204, 0.596, 0.859, 1.0),
		"button_hover": Color(0.161, 0.502, 0.725, 1.0),
	},
	{
		# Peter River / Belize Hole
		"background":   Color(0.075, 0.114, 0.157, 1.0),
		"glow":         Color(0.204, 0.596, 0.859, 0.12),
		"wall":         Color(0.122, 0.176, 0.239, 0.9),
		"floor":        Color(0.075, 0.114, 0.157, 1.0),
		"path":         Color(0.141, 0.200, 0.259, 0.78),
		"desk":         Color(0.102, 0.149, 0.196, 0.92),
		"door":         Color(0.161, 0.502, 0.725, 1.0),
		"panel_bg":     Color(0.086, 0.137, 0.188, 0.96),
		"panel_border": Color(0.204, 0.596, 0.859, 1.0),
		"text_primary": Color(0.925, 0.941, 0.945, 1.0),
		"text_secondary":Color(0.741, 0.765, 0.780, 1.0),
		"text_hint":    Color(0.584, 0.647, 0.651, 1.0),
		"text_accent":  Color(0.204, 0.596, 0.859, 1.0),
		"button_bg":    Color(0.122, 0.176, 0.239, 1.0),
		"button_border":Color(0.204, 0.596, 0.859, 1.0),
		"button_hover": Color(0.161, 0.502, 0.725, 1.0),
	},
	{
		# Amethyst / Wisteria
		"background":   Color(0.102, 0.071, 0.122, 1.0),
		"glow":         Color(0.608, 0.349, 0.714, 0.12),
		"wall":         Color(0.180, 0.106, 0.204, 0.9),
		"floor":        Color(0.122, 0.075, 0.141, 1.0),
		"path":         Color(0.263, 0.157, 0.302, 0.78),
		"desk":         Color(0.196, 0.118, 0.224, 0.92),
		"door":         Color(0.220, 0.141, 0.259, 1.0),
		"panel_bg":     Color(0.141, 0.098, 0.161, 0.96),
		"panel_border": Color(0.608, 0.349, 0.714, 1.0),
		"text_primary": Color(0.925, 0.941, 0.945, 1.0),
		"text_secondary":Color(0.741, 0.765, 0.780, 1.0),
		"text_hint":    Color(0.584, 0.647, 0.651, 1.0),
		"text_accent":  Color(0.608, 0.349, 0.714, 1.0),
		"button_bg":    Color(0.196, 0.118, 0.224, 1.0),
		"button_border":Color(0.608, 0.349, 0.714, 1.0),
		"button_hover": Color(0.557, 0.267, 0.678, 1.0),
	}
]


# Sets up audio, stores player marker positions, connects all button signals,
# loads the current room from Global.rooms, and plays the entrance animation.
func _ready() -> void:
	_configure_audio()
	player_start_position = player_marker.position
	player_exit_position = Vector2(door.position.x + (door.size.x * 0.5) - (player_marker.size.x * 0.35), door.position.y + 110.0)
	choice_a.pressed.connect(_on_choice_pressed.bind(0))
	choice_b.pressed.connect(_on_choice_pressed.bind(1))
	choice_c.pressed.connect(_on_choice_pressed.bind(2))
	exit_button.pressed.connect(_on_exit_pressed)
	clue_note_button.pressed.connect(_on_clue_note_pressed)
	keypad_buttons = [digit_1, digit_2, digit_3, digit_4, digit_5, digit_6, digit_7, digit_8, digit_9, digit_0]
	for button in keypad_buttons:
		button.pressed.connect(_on_keypad_digit_pressed.bind(button.text))
	clear_button.pressed.connect(_on_keypad_clear_pressed)
	enter_button.pressed.connect(_on_keypad_enter_pressed)
	_load_current_room()
	_play_entrance_animation()


# Resets the room to its initial state and loads data from Global.rooms[Global.index].
# Falls back to a built-in demo room if Global.rooms is empty.
# Applies the per-room color palette, populates answer button labels,
# fires TTS for the intro line, and resets lives/phase/UI.
func _load_current_room() -> void:
	if active_room_tween != null:
		active_room_tween.kill()
		active_room_tween = null

	if Global.rooms.is_empty():
		current_room = {
			"title": "The Vault Chamber",
			"description": "A locked chamber hums in the dark.",
			"question": "Which clue signal unlocks retrieval by key?",
			"answers": ["Array", "Hash Map", "Stack"],
			"correct_index": 1,
			"hint": "Focus on key-value retrieval.",
			"success": "The lock releases and the path opens."
		}
	else:
		Global.index = clamp(Global.index, 0, max(Global.rooms.size() - 1, 0))
		current_room = Global.rooms[Global.index]

	current_professor = _select_professor(Global.index)
	_apply_professor_portrait()
	title_label.text = ""
	title_label.visible = false
	_refresh_meta_label()
	clue_text.text = "CLUE NOTE\nInspect to reveal."
	var answers: Array = current_room.get("answers", ["Array", "Hash Map", "Stack"])
	choice_a.text = _format_choice_text(str(answers[0])) if answers.size() > 0 else "Module A"
	choice_b.text = _format_choice_text(str(answers[1])) if answers.size() > 1 else "Module B"
	choice_c.text = _format_choice_text(str(answers[2])) if answers.size() > 2 else "Module C"
	status_label.text = "Inspect the note."
	professor_line.text = _professor_line("intro")
	_tts_speak(professor_line.text)
	hint_label.text = ""
	correct_choice = int(current_room.get("correct_index", 1))
	solved = false
	keypad_code = _generate_keypad_code()
	keypad_input = ""
	room_phase = RoomPhase.LOCKED
	_apply_palette(Global.index)
	doorway.color = Color(0.055, 0.090, 0.122, 1.0)
	door_panel.offset_top = door_closed_top
	door_panel.offset_bottom = door_closed_bottom
	door_label.modulate = Color(1, 1, 1, 1)
	door_lock_light.color = Color("c53a2f")
	door_click_area.disabled = true
	terminal_panel.modulate = Color(1, 1, 1, 0.45)
	terminal_header.text = "CHOICES"
	terminal_status.text = "CLUE REQUIRED"
	terminal_button.visible = false
	terminal_button.disabled = true
	keypad_display.text = "LOCKED"
	code_display.text = "_ _ _ _"
	_set_keypad_enabled(true)
	room_prompt.text = "Inspect the note."
	player_marker.position = player_start_position
	player_marker.scale = Vector2.ONE
	player_marker.modulate = Color(1, 1, 1, 1)
	choice_a.visible = true
	choice_b.visible = true
	choice_c.visible = true
	exit_button.visible = true
	choice_a.disabled = true
	choice_b.disabled = true
	choice_c.disabled = true
	exit_button.disabled = false
	choice_a.modulate = Color(1, 1, 1, 0.45)
	choice_b.modulate = Color(1, 1, 1, 0.45)
	choice_c.modulate = Color(1, 1, 1, 0.45)
	exit_button.modulate = Color(1, 1, 1, 1)


# Called when the player clicks the clue note button.
# Advances the phase from LOCKED → CLUE_DISCOVERED, reveals the question text,
# enables the three choice buttons, and has the professor deliver a hint line.
func _on_clue_note_pressed() -> void:
	if room_phase != RoomPhase.LOCKED:
		return

	room_phase = RoomPhase.CLUE_DISCOVERED
	clue_text.text = _format_clue_text(str(current_room.get("question", "Which clue signal unlocks retrieval by key?")))
	clue_note.modulate = Color(1, 1, 1, 1)
	terminal_panel.modulate = Color(1, 1, 1, 0.95)
	terminal_status.text = "CHOICES READY"
	choice_a.disabled = false
	choice_b.disabled = false
	choice_c.disabled = false
	choice_a.modulate = Color(1, 1, 1, 1)
	choice_b.modulate = Color(1, 1, 1, 1)
	choice_c.modulate = Color(1, 1, 1, 1)
	room_prompt.text = "Choose a choice."
	status_label.text = "Clue found."
	_speak(_professor_line("hint"))


# Appends one digit to keypad_input (max 4) and refreshes the display.
# Blocked while transitioning so the player cannot type during the exit animation.
func _on_keypad_digit_pressed(digit: String) -> void:
	if room_phase == RoomPhase.TRANSITIONING:
		return
	if keypad_input.length() >= 4:
		return
	keypad_input += digit
	_refresh_code_display()


# Clears keypad_input and resets the display to "_ _ _ _".
# Blocked while transitioning.
func _on_keypad_clear_pressed() -> void:
	if room_phase == RoomPhase.TRANSITIONING:
		return
	keypad_input = ""
	status_label.text = "Enter the code."
	_refresh_code_display()


# Validates the 4-digit keypad entry against keypad_code.
# Correct: advances phase to TRANSITIONING, plays the door-open animation,
#          and calls _advance_after_delay() to move to the next room.
# Wrong:   flashes the lock light red, plays the wrong sound, and clears the input.
# Blocked while transitioning.
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
		var deny_tween := create_tween()
		var reset_light := Color("6fdc74") if room_phase == RoomPhase.ACCESS_GRANTED else Color("c53a2f")
		var reset_display := "READY" if room_phase == RoomPhase.ACCESS_GRANTED else "LOCKED"
		deny_tween.tween_property(door_lock_light, "color", reset_light, 0.25)
		deny_tween.finished.connect(func() -> void:
			if room_phase != RoomPhase.TRANSITIONING:
				keypad_display.text = reset_display
		)
		return

	room_phase = RoomPhase.TRANSITIONING
	keypad_display.text = "OPEN"
	status_label.text = "Path opened."
	room_prompt.text = "Entering next chamber..."
	_play_transition_sound()
	_open_vault()
	_advance_after_delay()
	door_click_area.disabled = true


# Handles the exit button press. Clears the quiz session and returns to the main menu.
func _on_exit_pressed() -> void:
	_return_to_main()


# Called when the player presses choice A (0), B (1), or C (2).
# Correct choice: marks the room solved, issues the keypad code, plays the success line,
#                 and increments Global.score.
# Wrong choice:   decrements Global.lives; if lives reach zero the defeat sequence fires
#                 (reveals the answer, plays defeat line, waits 4 s, returns to main).
#                 Otherwise plays the wrong line and lets the player try again.
# Ignored if already solved or not in the CLUE_DISCOVERED phase.
func _on_choice_pressed(choice_index: int) -> void:
	if solved or room_phase != RoomPhase.CLUE_DISCOVERED:
		return

	if choice_index == correct_choice:
		solved = true
		Global.score += 1
		_refresh_meta_label()
		room_phase = RoomPhase.ACCESS_GRANTED
		keypad_input = ""
		_refresh_code_display()
		status_label.text = "Door code: %s" % keypad_code
		_speak(_professor_line("success"))
		room_prompt.text = "Enter the 4-digit code."
		terminal_status.text = "CODE ISSUED %s" % keypad_code
		keypad_display.text = "READY"
		door_lock_light.color = Color("6fdc74")
		choice_a.disabled = true
		choice_b.disabled = true
		choice_c.disabled = true
		choice_a.modulate = Color(1, 1, 1, 1)
		choice_b.modulate = Color(1, 1, 1, 1)
		choice_c.modulate = Color(1, 1, 1, 1)
		_play_sound(correct_player)
	else:
		Global.lives -= 1
		_refresh_meta_label()
		_play_sound(wrong_player)
		door_lock_light.color = Color("d14a3a")
		if Global.lives <= 0:
			var correct_answers: Array = current_room.get("answers", [])
			var revealed_answer := ""
			if correct_choice >= 0 and correct_choice < correct_answers.size():
				revealed_answer = str(correct_answers[correct_choice])
			if revealed_answer.is_empty():
				revealed_answer = "The right choice remains hidden."
			status_label.text = "Out of attempts. Answer: %s" % revealed_answer
			hint_label.text = "The chamber seals shut."
			_speak(_professor_line("defeat"))
			_disable_choices()
			await get_tree().create_timer(4.0).timeout
			_return_to_main()
			return
		status_label.text = "Access denied."
		room_prompt.text = "Choose a choice."
		_speak(_professor_line("wrong"))


# Disables and dims all three choice buttons.
# Called after a defeat to prevent further input while the defeat dialogue plays.
func _disable_choices() -> void:
	choice_a.disabled = true
	choice_b.disabled = true
	choice_c.disabled = true
	choice_a.modulate = Color(1, 1, 1, 0.45)
	choice_b.modulate = Color(1, 1, 1, 0.45)
	choice_c.modulate = Color(1, 1, 1, 0.45)


# Plays the door-open tween sequence.
# The door panel slides up (offset_top/bottom animate), the doorway color shifts to
# the success color, and the player marker walks forward and shrinks into the doorway.
func _open_vault() -> void:
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


# Called when the player presses the hint button.
# Increments Global.hints_used, shows the room's hint text in hint_label,
# and has the professor speak a randomized hint line.
func _on_hint_pressed() -> void:
	Global.hints_used += 1
	hint_label.text = "Clue: %s" % str(current_room.get("hint", "Inspect the machinery more closely."))
	_speak(_professor_line("hint"))
	if room_phase == RoomPhase.LOCKED:
		room_prompt.text = "Inspect the note."
	elif room_phase == RoomPhase.CLUE_DISCOVERED:
		room_prompt.text = "Test a signal."


# Waits 1.9 seconds (door animation plays during this time), then either loads the
# next room by incrementing Global.index and calling _load_current_room(), or shows
# the victory screen if this was the last room in the session.
func _advance_after_delay() -> void:
	await get_tree().create_timer(1.9).timeout
	if Global.rooms.is_empty() or Global.index >= Global.rooms.size() - 1:
		_show_victory_screen()
		return

	Global.index += 1
	_load_current_room()


# Clears the quiz session state in Global and navigates back to the main menu scene.
func _return_to_main() -> void:
	Global.clear_quiz_session()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


# Stores the quiz result as a victory in Global, then transitions to the main menu.
# The main menu reads the stored result to decide whether to show the leaderboard form.
func _show_victory_screen() -> void:
	Global.store_quiz_result("victory")
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


# Creates and adds all AudioStreamPlayer nodes to the scene tree.
# Loads sound files from the const paths at the top of the file.
# Background music is assigned to the "Music" bus and started immediately;
# correct, wrong, and transition sounds are assigned to the "SFX" bus.
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
	var stream: Variant = load(LEVEL_TRANSITION_SOUND_PATH)
	if stream is AudioStream:
		transition_player.stream = stream


# Plays the level-transition fanfare through transition_player.
# Called when the correct keypad code is confirmed.
func _play_transition_sound() -> void:
	_play_sound(transition_player)


# Plays the given AudioStreamPlayer with a slight random pitch variation (±5%).
# Stops any currently playing sound on the player first to avoid overlap.
# Silently skips if the player node or its stream is null.
func _play_sound(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()


# Applies the color palette for the given room_index to every visual element.
# room_index is wrapped with % room_palettes.size() so the cycle repeats indefinitely.
# Palette colors cover background/wall/floor geometry, panels, labels, and choice buttons.
func _apply_palette(room_index: int) -> void:
	var palette: Dictionary = room_palettes[room_index % room_palettes.size()]
	# Background elements
	background.color = palette["background"]
	top_glow.color = palette["glow"]
	back_wall_band.color = palette["wall"]
	floor.color = palette["floor"]
	center_path.color = palette["path"]
	terminal_base.color = palette["floor"]
	$Desk.color = palette["desk"]
	door.color = palette["door"]
	# Panels — all share the same StyleBoxFlat sub-resource
	var panel_style := terminal_panel.get_theme_stylebox("panel") as StyleBoxFlat
	if panel_style:
		panel_style.bg_color = palette["panel_bg"]
		panel_style.border_color = palette["panel_border"]
	# Labels
	terminal_header.add_theme_color_override("font_color", palette["text_accent"])
	terminal_status.add_theme_color_override("font_color", palette["text_secondary"])
	professor_line.add_theme_color_override("font_color", palette["text_primary"])
	clue_text.add_theme_color_override("font_color", palette["text_primary"])
	door_label.add_theme_color_override("font_color", palette["text_primary"])
	keypad_title.add_theme_color_override("font_color", palette["text_primary"])
	keypad_display.add_theme_color_override("font_color", palette["text_primary"])
	status_label.add_theme_color_override("font_color", palette["text_secondary"])
	room_prompt.add_theme_color_override("font_color", palette["text_hint"])
	hint_label.add_theme_color_override("font_color", palette["text_hint"])
	meta_label.add_theme_color_override("font_color", palette["text_hint"])
	# Choice button fonts
	choice_a.add_theme_color_override("font_color", palette["text_primary"])
	choice_b.add_theme_color_override("font_color", palette["text_primary"])
	choice_c.add_theme_color_override("font_color", palette["text_primary"])
	# Choice button styles (shared sub-resource)
	var btn_normal := choice_a.get_theme_stylebox("normal") as StyleBoxFlat
	if btn_normal:
		btn_normal.bg_color = palette["button_bg"]
		btn_normal.border_color = palette["button_border"]
	var btn_hover := choice_a.get_theme_stylebox("hover") as StyleBoxFlat
	if btn_hover:
		btn_hover.bg_color = palette["button_hover"]
		btn_hover.border_color = palette["button_border"]


# Word-wraps choice text to a maximum of 24 characters per line.
# Returns the original string unchanged if it is already 24 characters or fewer.
# Splits on word boundaries to avoid breaking words across lines.
func _format_choice_text(choice_text: String) -> String:
	if choice_text.length() <= 24:
		return choice_text

	var words: PackedStringArray = choice_text.split(" ")
	var lines: Array[String] = []
	var current_line := ""

	for word in words:
		var proposed := word if current_line.is_empty() else "%s %s" % [current_line, word]
		if proposed.length() > 24 and not current_line.is_empty():
			lines.append(current_line)
			current_line = word
		else:
			current_line = proposed

	if not current_line.is_empty():
		lines.append(current_line)

	return "\n".join(lines)


# Strips boilerplate prefixes ("Which topic matches this clue?", etc.) that the AI
# sometimes prepends to the question, leaving only the meaningful clue content.
func _format_clue_text(question_text: String) -> String:
	var cleaned := question_text.strip_edges()
	var module_prefix := "Which topic matches this clue?"
	if cleaned.begins_with(module_prefix):
		cleaned = cleaned.trim_prefix(module_prefix).strip_edges()
	if cleaned.begins_with("Which concept is described here?"):
		cleaned = cleaned.trim_prefix("Which concept is described here?").strip_edges()
	if cleaned.begins_with("Which answer is correct?"):
		cleaned = cleaned.trim_prefix("Which answer is correct?").strip_edges()
	return cleaned


# Enables or disables all digit, clear, and enter buttons on the keypad.
# Disabled buttons are also dimmed to 45% opacity for a clear visual cue.
func _set_keypad_enabled(enabled: bool) -> void:
	for button in keypad_buttons:
		button.disabled = not enabled
		button.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.45)
	clear_button.disabled = not enabled
	clear_button.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.45)
	enter_button.disabled = not enabled
	enter_button.modulate = Color(1, 1, 1, 1) if enabled else Color(1, 1, 1, 0.45)


# Updates code_display to show entered digits separated by spaces, with underscores
# for the remaining empty slots (e.g. "3 _ _ _" after one digit is entered).
func _refresh_code_display() -> void:
	var display_parts: Array[String] = []
	for index in range(4):
		if index < keypad_input.length():
			display_parts.append(keypad_input.substr(index, 1))
		else:
			display_parts.append("_")
	code_display.text = " ".join(display_parts)


# Generates a random 4-digit string (e.g. "0731") used as the keypad unlock code.
# A new code is generated each time _load_current_room() is called.
func _generate_keypad_code() -> String:
	var code := ""
	for _i in range(4):
		code += str(randi_range(0, 9))
	return code


# Refreshes the HUD status strip showing chamber number, total rooms, remaining
# lives, and vault progress (correct answers). Called after score/lives change.
func _refresh_meta_label() -> void:
	meta_label.text = "Chamber %d/%d   Attempts %d   Vault Progress %d" % [
		Global.index + 1,
		max(Global.rooms.size(), 1),
		Global.lives,
		Global.score
	]

# Plays the room-entry animation when the scene first loads.
# The professor panel slides in from the left (TRANS_BACK ease-out), then the typewriter
# starts on the intro line. The clue note, terminal panel, and door fade in concurrently.
# Waits one process frame before starting so Control layout is fully computed.
func _play_entrance_animation() -> void:
	# Wait one frame so Control layout is fully computed before reading positions/sizes
	await get_tree().process_frame

	var prof_panel := $ProfessorPanel
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


# Animates visible_characters on a Label from 0 to its full length at ~22 chars/sec
# (each character takes 0.045 s). Starts the portrait bounce while typing and stops
# it when the tween finishes. No-ops if the label text is empty.
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


# Sets professor_line text, plays the typewriter animation, and fires TTS.
# Use this for all mid-game professor dialogue (wrong, hint, success, defeat).
# Do NOT use for the intro line set in _load_current_room() — that line uses a
# direct text assignment + separate _tts_speak() call to avoid double-typewriter
# conflict with _play_entrance_animation().
func _speak(text: String) -> void:
	professor_line.text = text
	_play_typewriter(professor_line)
	_tts_speak(text)


# Sends text to the OS text-to-speech engine via DisplayServer.tts_speak().
# Strips any "Professor Name: " prefix so the voice only reads the dialogue.
# Selects a voice based on the current professor (see _get_professor_voice_index()).
# Volume is sourced from AudioManager.tts_volume (0.0–1.0 → 0–100 int range).
# Speed is controlled by the TTS_RATE constant at the top of this file.
# Does nothing if AudioManager.tts_enabled is false or no English voices are available.
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


# Returns 0, 1, or 2 to index into the available English voice list.
# Vex → 0, Hale → 1, Mira → 2. The index is wrapped with % voices.size()
# in _tts_speak() so it is safe on systems with fewer than 3 installed voices.
func _get_professor_voice_index() -> int:
	match str(current_professor.get("name", "")):
		"Professor Vex":  return 0  # First available English voice
		"Professor Hale": return 1  # Second available English voice
		"Professor Mira": return 2  # Third available English voice (wraps if fewer voices exist)
	return 0


# Starts a looping vertical bounce tween on professor_portrait (±5 px, 0.28 s per half).
# Records the rest Y position before starting so _stop_portrait_bounce() can restore it.
# Kills any existing bounce tween before starting a new one.
func _start_portrait_bounce() -> void:
	if _portrait_bounce_tween != null:
		_portrait_bounce_tween.kill()
	_portrait_rest_y = professor_portrait.position.y
	_portrait_bounce_tween = create_tween().set_loops()
	_portrait_bounce_tween.tween_property(professor_portrait, "position:y", _portrait_rest_y - 5.0, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_portrait_bounce_tween.tween_property(professor_portrait, "position:y", _portrait_rest_y, 0.28).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


# Kills the portrait bounce tween and snaps the portrait back to its rest Y position.
# Called by _play_typewriter() when the typewriter animation finishes.
func _stop_portrait_bounce() -> void:
	if _portrait_bounce_tween != null:
		_portrait_bounce_tween.kill()
		_portrait_bounce_tween = null
	professor_portrait.position.y = _portrait_rest_y


# Returns the professor Dictionary whose "name" matches Global.selected_professor.
# Falls back to a round-robin choice (room_index % professors.size()) if no match is found.
func _select_professor(room_index: int) -> Dictionary:
	var selected_name := str(Global.selected_professor)
	for professor in professors:
		var professor_dict: Dictionary = professor
		if str(professor_dict.get("name", "")) == selected_name:
			return professor_dict
	return professors[room_index % professors.size()]


# Builds a formatted dialogue string: "Professor Name: <random line from kind category>".
# kind must be one of "intro", "wrong", "hint", "success", or "defeat".
# Falls back to just the professor name if the category array is empty.
func _professor_line(kind: String) -> String:
	var professor_name := str(current_professor.get("name", "Professor"))
	var lines_variant: Variant = current_professor.get(kind, [])
	var lines: Array = lines_variant if lines_variant is Array else []
	if lines.is_empty():
		return professor_name
	return "%s: %s" % [professor_name, _random_line(lines)]


# Loads the current professor's portrait texture from its res:// path and assigns it
# to professor_portrait. Silently skips if the path is empty or the resource is not a Texture2D.
func _apply_professor_portrait() -> void:
	var portrait_path := str(current_professor.get("portrait", ""))
	if portrait_path.is_empty():
		return
	var texture: Variant = load(portrait_path)
	if texture is Texture2D:
		professor_portrait.texture = texture


# Returns a uniformly random element from lines as a String.
# Returns an empty string if lines is empty.
func _random_line(lines: Array) -> String:
	if lines.is_empty():
		return ""
	return str(lines[randi() % lines.size()])
