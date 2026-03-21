extends Control

const DEFAULT_STATUS := "Choose the right answer to unlock the next room."
const OLLAMA_URL := "http://localhost:11434/api/chat"
const OLLAMA_MODEL := "gemma3:4b"
const START_LIVES := 3
const ROOMS_DATA_PATH := "res://Data/rooms.json"
const CLICK_SOUND_PATH := "res://Audio/click.wav"
const CORRECT_SOUND_PATH := "res://Audio/correct.wav"
const WRONG_SOUND_PATH := "res://Audio/wrong.wav"
const UNLOCK_SOUND_PATH := "res://Audio/unlock.wav"
const WIN_SOUND_PATH := "res://Audio/win.wav"
const LOSE_SOUND_PATH := "res://Audio/lose.wav"

var rooms: Array[Dictionary] = []

var current_room_index := 0
var room_cleared := false
var score := 0
var lives_remaining := START_LIVES
var hints_used := 0
var current_game_state := "start"

@onready var background: ColorRect = $Background
@onready var background_texture: TextureRect = $BackgroundTexture
@onready var margin_container: MarginContainer = $MarginContainer
@onready var title_banner: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleBanner
@onready var meta_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MetaLabel
@onready var room_title: Label = $MarginContainer/PanelContainer/VBoxContainer/RoomTitle
@onready var room_description: Label = $MarginContainer/PanelContainer/VBoxContainer/RoomDescription
@onready var question_label: Label = $MarginContainer/PanelContainer/VBoxContainer/QuestionLabel
@onready var theme_badge: Label = $MarginContainer/PanelContainer/VBoxContainer/ThemeBadge
@onready var answers_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/AnswersContainer
@onready var hint_label: Label = $MarginContainer/PanelContainer/VBoxContainer/HintLabel
@onready var status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var primary_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ActionRow/PrimaryButton
@onready var secondary_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ActionRow/SecondaryButton
@onready var tertiary_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ActionRow/TertiaryButton
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var click_player: AudioStreamPlayer = $ClickPlayer
@onready var correct_player: AudioStreamPlayer = $CorrectPlayer
@onready var wrong_player: AudioStreamPlayer = $WrongPlayer
@onready var unlock_player: AudioStreamPlayer = $UnlockPlayer
@onready var win_player: AudioStreamPlayer = $WinPlayer
@onready var lose_player: AudioStreamPlayer = $LosePlayer


func _ready() -> void:
	for index in range(answers_container.get_child_count()):
		var button := answers_container.get_child(index) as Button
		button.pressed.connect(_on_answer_selected.bind(index))

	_configure_audio_players()
	_load_rooms()
	primary_button.pressed.connect(_on_primary_pressed)
	secondary_button.pressed.connect(_on_secondary_pressed)
	tertiary_button.pressed.connect(_on_tertiary_pressed)
	http_request.request_completed.connect(_on_ollama_request_completed)
	_show_start_screen()


func _start_game() -> void:
	if rooms.is_empty():
		status_label.text = "No rooms were loaded. Check Data/rooms.json."
		return

	current_room_index = 0
	score = 0
	lives_remaining = START_LIVES
	hints_used = 0
	room_cleared = false
	current_game_state = "playing"
	margin_container.visible = true
	_show_room()


func _show_start_screen() -> void:
	current_game_state = "start"
	room_cleared = false
	background.color = Color("202432")
	background_texture.visible = false
	title_banner.text = "Confront Your Problems"
	meta_label.text = "Escape through %d rooms before you run out of lives." % rooms.size()
	room_title.text = "Start Your Escape"
	room_description.text = "Use hints carefully, survive wrong answers, and let Ollama generate fresh puzzles whenever you want a new challenge."
	question_label.text = "Ready to test the game loop we built?"
	theme_badge.text = "Dynamic quiz escape room"
	hint_label.text = "Tip: keep Ollama running in PowerShell if you want dynamic rooms."
	status_label.text = "You start with %d lives." % START_LIVES
	_set_answer_buttons_visible(false)
	primary_button.text = "Start Game"
	primary_button.visible = true
	primary_button.disabled = false
	secondary_button.text = "Generate Preview"
	secondary_button.visible = true
	secondary_button.disabled = false
	tertiary_button.text = "Show Hint"
	tertiary_button.visible = false


func _show_room() -> void:
	current_game_state = "playing"
	var room: Dictionary = rooms[current_room_index]
	room_cleared = false
	_apply_room_theme(room, current_room_index)
	title_banner.text = "Escape Room Challenge"
	meta_label.text = "Room %d/%d   Score %d   Lives %d   Hints %d" % [
		current_room_index + 1,
		rooms.size(),
		score,
		lives_remaining,
		hints_used
	]
	room_title.text = room["title"]
	room_description.text = room["description"]
	question_label.text = room["question"]
	theme_badge.text = "Theme color %s" % room.get("theme_color", "default")
	hint_label.text = ""
	status_label.text = DEFAULT_STATUS
	_set_answer_buttons_visible(true)

	var answers: Array = room["answers"]
	for index in range(answers_container.get_child_count()):
		var button := answers_container.get_child(index) as Button
		button.text = answers[index]
		button.disabled = false

	primary_button.text = "Generate With Ollama"
	primary_button.visible = true
	primary_button.disabled = false
	secondary_button.text = "Show Hint"
	secondary_button.visible = true
	secondary_button.disabled = false
	tertiary_button.text = "Next Room"
	tertiary_button.visible = room_cleared
	tertiary_button.disabled = not room_cleared


func _show_end_screen(did_win: bool) -> void:
	current_game_state = "end"
	room_cleared = false
	background.color = Color("1f2430") if did_win else Color("342126")
	background_texture.visible = false
	if did_win:
		_play_if_ready(win_player)
	else:
		_play_if_ready(lose_player)
	title_banner.text = "Escape Complete" if did_win else "Try Again"
	meta_label.text = "Final Score %d   Rooms Cleared %d/%d   Hints Used %d" % [
		score,
		current_room_index + int(did_win),
		rooms.size(),
		hints_used
	]
	room_title.text = "You made it out." if did_win else "The doors sealed shut."
	room_description.text = "Every lock opened and the story can grow from here." if did_win else "You ran out of lives, but the rooms are ready whenever you want another attempt."
	question_label.text = "What do you want to do next?"
	theme_badge.text = "Replay or generate new content"
	hint_label.text = "Next upgrade idea: add story branches, sound, and per-room art."
	status_label.text = "Ollama can still generate a fresh room set whenever you restart."
	_set_answer_buttons_visible(false)
	primary_button.text = "Play Again"
	primary_button.visible = true
	primary_button.disabled = false
	secondary_button.text = "Generate Preview"
	secondary_button.visible = true
	secondary_button.disabled = false
	tertiary_button.visible = false


func _set_answer_buttons_visible(is_visible: bool) -> void:
	answers_container.visible = is_visible
	for child in answers_container.get_children():
		var button := child as Button
		button.visible = is_visible


func _on_answer_selected(answer_index: int) -> void:
	if current_game_state != "playing" or room_cleared:
		return

	var room: Dictionary = rooms[current_room_index]
	if answer_index == room["correct_index"]:
		room_cleared = true
		score += 1
		_play_if_ready(correct_player)
		status_label.text = room["success"]
		meta_label.text = "Room %d/%d   Score %d   Lives %d   Hints %d" % [
			current_room_index + 1,
			rooms.size(),
			score,
			lives_remaining,
			hints_used
		]
		for child in answers_container.get_children():
			var button := child as Button
			button.disabled = true
		_play_if_ready(unlock_player)
		tertiary_button.visible = true
		tertiary_button.disabled = false
		tertiary_button.text = "Finish Escape" if current_room_index >= rooms.size() - 1 else "Next Room"
	else:
		lives_remaining -= 1
		_play_if_ready(wrong_player)
		if lives_remaining <= 0:
			meta_label.text = "Room %d/%d   Score %d   Lives %d   Hints %d" % [
				current_room_index + 1,
				rooms.size(),
				score,
				lives_remaining,
				hints_used
			]
			_show_end_screen(false)
			return

		status_label.text = "That answer keeps the door locked. Lives remaining: %d." % lives_remaining
		meta_label.text = "Room %d/%d   Score %d   Lives %d   Hints %d" % [
			current_room_index + 1,
			rooms.size(),
			score,
			lives_remaining,
			hints_used
		]


func _on_primary_pressed() -> void:
	_play_if_ready(click_player)
	match current_game_state:
		"start", "end":
			_start_game()
		"playing":
			_on_generate_pressed()


func _on_secondary_pressed() -> void:
	_play_if_ready(click_player)
	match current_game_state:
		"start", "end":
			_generate_preview_room()
		"playing":
			_on_hint_pressed()


func _on_tertiary_pressed() -> void:
	if current_game_state != "playing":
		return
	_play_if_ready(click_player)
	_on_next_pressed()


func _on_hint_pressed() -> void:
	if current_game_state != "playing":
		return

	var room: Dictionary = rooms[current_room_index]
	hints_used += 1
	hint_label.text = "Hint: %s" % room["hint"]
	meta_label.text = "Room %d/%d   Score %d   Lives %d   Hints %d" % [
		current_room_index + 1,
		rooms.size(),
		score,
		lives_remaining,
		hints_used
	]


func _on_next_pressed() -> void:
	if current_game_state != "playing" or not room_cleared:
		return

	if current_room_index >= rooms.size() - 1:
		_show_end_screen(true)
		return

	current_room_index += 1
	_show_room()


func _on_generate_pressed() -> void:
	primary_button.disabled = true
	status_label.text = "Asking Ollama for a new question..."
	hint_label.text = ""

	var prompt := _build_generation_prompt()
	var payload := {
		"model": OLLAMA_MODEL,
		"messages": [
			{
				"role": "system",
				"content": "You create short escape-room quiz content for a Godot app. Return JSON only with no markdown."
			},
			{
				"role": "user",
				"content": prompt
			}
		],
		"stream": false
	}

	var headers := ["Content-Type: application/json"]
	var error := http_request.request(OLLAMA_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		primary_button.disabled = false
		status_label.text = "Could not start the Ollama request. Make sure Ollama is running."


func _generate_preview_room() -> void:
	if rooms.is_empty():
		status_label.text = "No room data is available to preview."
		return

	var preview_index: int = clamp(current_room_index, 0, rooms.size() - 1)
	var preview_room: Dictionary = rooms[preview_index]
	_apply_room_theme(preview_room, preview_index)
	title_banner.text = "Ollama Preview Mode"
	meta_label.text = "Model %s   Preview room %d" % [OLLAMA_MODEL, preview_index + 1]
	room_title.text = preview_room["title"]
	room_description.text = "This is the room template that Ollama will replace when you generate new content."
	question_label.text = preview_room["question"]
	theme_badge.text = "Preview theme %s" % preview_room.get("theme_color", "default")
	hint_label.text = "Hint preview: %s" % preview_room["hint"]
	status_label.text = "Press Start Game when you want to play the current set."
	_set_answer_buttons_visible(true)
	var answers: Array = preview_room["answers"]
	for index in range(answers_container.get_child_count()):
		var button := answers_container.get_child(index) as Button
		button.text = answers[index]
		button.disabled = true


func _on_ollama_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	primary_button.disabled = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_label.text = "Ollama request failed. Check that the local server is running on port 11434."
		return

	var response_text := body.get_string_from_utf8()
	var parsed_response = JSON.parse_string(response_text)
	if parsed_response == null:
		status_label.text = "Could not read Ollama's response."
		return

	var message: Dictionary = parsed_response.get("message", {})
	var content: String = message.get("content", "")
	var generated_room = JSON.parse_string(_extract_json_content(content))
	if generated_room == null:
		status_label.text = "Ollama replied, but not in the JSON format the app expected."
		hint_label.text = content
		return

	if not _is_valid_generated_room(generated_room):
		status_label.text = "Ollama returned incomplete puzzle data."
		return

	rooms[current_room_index] = _normalize_generated_room(generated_room)
	status_label.text = "New puzzle loaded from Ollama."
	if current_game_state == "playing":
		_show_room()
	else:
		_generate_preview_room()


func _build_generation_prompt() -> String:
	var room: Dictionary = rooms[current_room_index]
	return "Return only valid JSON with keys title, description, question, answers, correct_index, hint, success. " \
		+ "Create one escape-room challenge with exactly 3 answer choices and exactly one correct answer. " \
		+ "The correct_index must be 0, 1, or 2. " \
		+ "Make the room feel cinematic, beginner-friendly, and a little tense. " \
		+ "Use a short success sentence instead of true/false. " \
		+ "Current room theme: %s." % room["title"]


func _is_valid_generated_room(room: Dictionary) -> bool:
	if not room.has("title") or not room.has("description") or not room.has("question"):
		return false
	if not room.has("answers") or not room.has("correct_index") or not room.has("hint") or not room.has("success"):
		return false

	var answers: Array = room["answers"]
	if answers.size() != 3:
		return false

	var correct_index: int = int(room["correct_index"])
	return correct_index >= 0 and correct_index < 3


func _extract_json_content(content: String) -> String:
	var cleaned := content.strip_edges()
	if cleaned.begins_with("```"):
		var first_newline := cleaned.find("\n")
		if first_newline != -1:
			cleaned = cleaned.substr(first_newline + 1)
		if cleaned.ends_with("```"):
			cleaned = cleaned.substr(0, cleaned.length() - 3)

	return cleaned.strip_edges()


func _normalize_generated_room(room: Dictionary) -> Dictionary:
	var normalized_success: Variant = room["success"]
	if normalized_success is bool:
		normalized_success = "The lock opens and the path forward is clear."

	return {
		"title": str(room["title"]),
		"description": str(room["description"]),
		"question": str(room["question"]),
		"answers": room["answers"],
		"correct_index": int(room["correct_index"]),
		"hint": str(room["hint"]),
		"success": str(normalized_success),
		"theme_color": str(room.get("theme_color", "")),
		"accent_color": str(room.get("accent_color", "")),
		"background_image": str(room.get("background_image", ""))
	}

func _load_rooms() -> void:
	rooms.clear()

	var file: FileAccess = FileAccess.open(ROOMS_DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("Could not open room data at %s" % ROOMS_DATA_PATH)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Array):
		push_error("Room data is not a valid JSON array.")
		return

	for entry in parsed:
		if entry is Dictionary and _is_valid_generated_room(entry):
			rooms.append(_normalize_generated_room(entry))

	if rooms.is_empty():
		push_error("No valid rooms were loaded from %s" % ROOMS_DATA_PATH)


func _apply_room_theme(room: Dictionary, room_index: int) -> void:
	var fallback_palette := [
		Color("202432"),
		Color("1d2936"),
		Color("2a2337"),
		Color("1f2f2b"),
		Color("34233a")
	]
	var fallback_color: Color = fallback_palette[room_index % fallback_palette.size()]
	var theme_color_text := str(room.get("theme_color", ""))
	background.color = _color_from_string(theme_color_text, fallback_color)

	var accent_text := str(room.get("accent_color", ""))
	var accent_color := _color_from_string(accent_text, Color("8fe6ff"))
	question_label.add_theme_color_override("font_color", accent_color)
	theme_badge.add_theme_color_override("font_color", accent_color)

	var image_path := str(room.get("background_image", ""))
	if image_path.is_empty():
		background_texture.texture = null
		background_texture.visible = false
		return

	var texture := load(image_path)
	if texture == null:
		background_texture.texture = null
		background_texture.visible = false
		return

	background_texture.texture = texture
	background_texture.visible = true


func _color_from_string(value: String, fallback: Color) -> Color:
	if value.is_empty():
		return fallback

	if value.is_valid_html_color():
		return Color(value)

	return fallback


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

	var stream: Variant = load(path)
	if stream is AudioStream:
		return stream

	return null


func _play_if_ready(player: AudioStreamPlayer) -> void:
	if player.stream != null:
		player.play()
