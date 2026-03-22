extends Control

const START_LIVES := 3
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
@onready var keypad_button: Button = $KeypadPanel/KeypadVBox/KeypadButton
@onready var room_prompt: Label = $RoomPrompt
@onready var hint_label: Label = $HintLabel
@onready var player_marker: ColorRect = $PlayerMarker

var current_room: Dictionary = {}
var correct_choice := 1
var solved := false
var room_phase := RoomPhase.LOCKED
var door_closed_top := 14.0
var door_closed_bottom := -14.0
var player_start_position := Vector2.ZERO
var player_exit_position := Vector2.ZERO
var active_room_tween: Tween
var current_professor: Dictionary = {}
var _portrait_bounce_tween: Tween = null
var _portrait_rest_y: float = 0.0
var correct_player: AudioStreamPlayer
var wrong_player: AudioStreamPlayer
var transition_player: AudioStreamPlayer
var background_music_player: AudioStreamPlayer
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


func _ready() -> void:
	_configure_audio()
	player_start_position = player_marker.position
	player_exit_position = Vector2(door.position.x + (door.size.x * 0.5) - (player_marker.size.x * 0.35), door.position.y + 110.0)
	choice_a.pressed.connect(_on_choice_pressed.bind(0))
	choice_b.pressed.connect(_on_choice_pressed.bind(1))
	choice_c.pressed.connect(_on_choice_pressed.bind(2))
	clue_note_button.pressed.connect(_on_clue_note_pressed)
	keypad_button.pressed.connect(_on_keypad_pressed)
	_load_current_room()
	_play_entrance_animation()


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
	hint_label.text = ""
	correct_choice = int(current_room.get("correct_index", 1))
	solved = false
	room_phase = RoomPhase.LOCKED
	_apply_palette(Global.index)
	doorway.color = Color(0.055, 0.090, 0.122, 1.0)
	door_panel.offset_top = door_closed_top
	door_panel.offset_bottom = door_closed_bottom
	door_label.modulate = Color(1, 1, 1, 1)
	door_lock_light.color = Color("c53a2f")
	door_click_area.disabled = true
	terminal_panel.modulate = Color(1, 1, 1, 0.45)
	terminal_header.text = "ACCESS TERMINAL"
	terminal_status.text = "CLUE REQUIRED"
	terminal_button.visible = false
	terminal_button.disabled = true
	keypad_button.disabled = true
	keypad_display.text = "LOCKED"
	room_prompt.text = "Inspect the note."
	player_marker.position = player_start_position
	player_marker.scale = Vector2.ONE
	player_marker.modulate = Color(1, 1, 1, 1)
	choice_a.visible = true
	choice_b.visible = true
	choice_c.visible = true
	choice_a.disabled = true
	choice_b.disabled = true
	choice_c.disabled = true
	choice_a.modulate = Color(1, 1, 1, 0.45)
	choice_b.modulate = Color(1, 1, 1, 0.45)
	choice_c.modulate = Color(1, 1, 1, 0.45)


func _on_clue_note_pressed() -> void:
	if room_phase != RoomPhase.LOCKED:
		return

	room_phase = RoomPhase.CLUE_DISCOVERED
	clue_text.text = _format_clue_text(str(current_room.get("question", "Which clue signal unlocks retrieval by key?")))
	clue_note.modulate = Color(1, 1, 1, 1)
	terminal_panel.modulate = Color(1, 1, 1, 0.95)
	terminal_status.text = "SIGNAL TEST READY"
	choice_a.disabled = false
	choice_b.disabled = false
	choice_c.disabled = false
	choice_a.modulate = Color(1, 1, 1, 1)
	choice_b.modulate = Color(1, 1, 1, 1)
	choice_c.modulate = Color(1, 1, 1, 1)
	room_prompt.text = "Test a signal."
	status_label.text = "Clue found."
	professor_line.text = _professor_line("hint")


func _on_keypad_pressed() -> void:
	if room_phase != RoomPhase.ACCESS_GRANTED:
		return

	room_phase = RoomPhase.TRANSITIONING
	keypad_display.text = "OPEN"
	status_label.text = "Path opened."
	room_prompt.text = "Entering next chamber..."
	_play_transition_sound()
	_open_vault()
	_advance_after_delay()
	door_click_area.disabled = true


func _on_choice_pressed(choice_index: int) -> void:
	if solved or room_phase != RoomPhase.CLUE_DISCOVERED:
		return

	if choice_index == correct_choice:
		solved = true
		Global.score += 1
		_refresh_meta_label()
		room_phase = RoomPhase.ACCESS_GRANTED
		status_label.text = "Lock released."
		professor_line.text = _professor_line("success")
		room_prompt.text = "Engage the keypad."
		terminal_status.text = "ACCESS GRANTED"
		keypad_button.disabled = false
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
			status_label.text = "The chamber seals shut. Your attempts are spent."
			professor_line.text = _professor_line("defeat")
			_disable_choices()
			await get_tree().create_timer(1.2).timeout
			_return_to_main()
			return
		status_label.text = "Access denied."
		room_prompt.text = "Test a signal."
		professor_line.text = _professor_line("wrong")


func _disable_choices() -> void:
	choice_a.disabled = true
	choice_b.disabled = true
	choice_c.disabled = true
	choice_a.modulate = Color(1, 1, 1, 0.45)
	choice_b.modulate = Color(1, 1, 1, 0.45)
	choice_c.modulate = Color(1, 1, 1, 0.45)


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


func _on_hint_pressed() -> void:
	Global.hints_used += 1
	hint_label.text = "Clue: %s" % str(current_room.get("hint", "Inspect the machinery more closely."))
	professor_line.text = _professor_line("hint")
	if room_phase == RoomPhase.LOCKED:
		room_prompt.text = "Inspect the note."
	elif room_phase == RoomPhase.CLUE_DISCOVERED:
		room_prompt.text = "Test a signal."


func _advance_after_delay() -> void:
	await get_tree().create_timer(1.9).timeout
	if Global.rooms.is_empty() or Global.index >= Global.rooms.size() - 1:
		_show_victory_screen()
		return

	Global.index += 1
	_load_current_room()


func _return_to_main() -> void:
	Global.clear_quiz_session()
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _show_victory_screen() -> void:
	Global.store_quiz_result("victory")
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
	var stream: Variant = load(LEVEL_TRANSITION_SOUND_PATH)
	if stream is AudioStream:
		transition_player.stream = stream


func _play_transition_sound() -> void:
	_play_sound(transition_player)


func _play_sound(player: AudioStreamPlayer) -> void:
	if player == null or player.stream == null:
		return
	player.stop()
	player.pitch_scale = randf_range(0.95, 1.05)
	player.play()


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


func _refresh_meta_label() -> void:
	meta_label.text = "Chamber %d/%d   Attempts %d   Vault Progress %d" % [
		Global.index + 1,
		max(Global.rooms.size(), 1),
		Global.lives,
		Global.score
	]

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


func _apply_professor_portrait() -> void:
	var portrait_path := str(current_professor.get("portrait", ""))
	if portrait_path.is_empty():
		return
	var texture: Variant = load(portrait_path)
	if texture is Texture2D:
		professor_portrait.texture = texture


func _random_line(lines: Array) -> String:
	if lines.is_empty():
		return ""
	return str(lines[randi() % lines.size()])
