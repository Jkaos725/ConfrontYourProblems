extends Control

const DEFAULT_STATUS := "Choose the right answer to unlock the next room."
const OPENAI_URL := "https://api.openai.com/v1/chat/completions"
const OPENAI_MODEL := "gpt-4.1-mini"
const START_LIVES := 3
const ROOMS_DATA_PATH := "res://Data/rooms.json"
const SUBJECTS_DATA_PATH := "res://Data/subjects.json"
const QUESTIONS_DATA_PATH := "res://Data/questions.json"
const ANSWERS_DATA_PATH := "res://Data/answers.json"
const CLICK_SOUND_PATH := "res://Audio/click.wav"
const CORRECT_SOUND_PATH := "res://Audio/correct.wav"
const WRONG_SOUND_PATH := "res://Audio/wrong.wav"
const UNLOCK_SOUND_PATH := "res://Audio/unlock.wav"
const WIN_SOUND_PATH := "res://Audio/win.wav"
const LOSE_SOUND_PATH := "res://Audio/lose.wav"

var rooms: Array[Dictionary] = []
var subjects_db: Array[Dictionary] = []
var questions_db: Array[Dictionary] = []
var answers_db: Array[Dictionary] = []
var active_catalog_name := "Custom Upload"
var active_subject := "Custom"
var active_subject_id := ""
var active_request_kind := "room_generation"
var pending_upload_path := ""
var pending_upload_text := ""
var openai_api_key := ""

var current_room_index := 0
var room_cleared := false
var score := 0
var lives_remaining := START_LIVES
var hints_used := 0
var current_game_state := "start_intro"

@onready var background: ColorRect = $Background
@onready var background_texture: TextureRect = $BackgroundTexture
@onready var margin_container: MarginContainer = $MarginContainer
@onready var title_banner: Label = $MarginContainer/PanelContainer/VBoxContainer/TitleBanner
@onready var meta_label: Label = $MarginContainer/PanelContainer/VBoxContainer/MetaLabel
@onready var catalog_box: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/CatalogBox
@onready var subject_option: OptionButton = $MarginContainer/PanelContainer/VBoxContainer/CatalogBox/SubjectOption
@onready var catalog_description: Label = $MarginContainer/PanelContainer/VBoxContainer/CatalogBox/CatalogDescription
@onready var upload_box: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/UploadBox
@onready var upload_name_input: LineEdit = $MarginContainer/PanelContainer/VBoxContainer/UploadBox/UploadNameInput
@onready var upload_help: Label = $MarginContainer/PanelContainer/VBoxContainer/UploadBox/UploadHelp
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
@onready var question_file_dialog: FileDialog = $QuestionFileDialog
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
	_load_subject_database()
	openai_api_key = OS.get_environment("OPENAI_API_KEY")
	primary_button.pressed.connect(_on_primary_pressed)
	secondary_button.pressed.connect(_on_secondary_pressed)
	tertiary_button.pressed.connect(_on_tertiary_pressed)
	subject_option.item_selected.connect(_on_subject_selected)
	question_file_dialog.file_selected.connect(_on_question_file_selected)
	http_request.request_completed.connect(_on_openai_request_completed)
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
	current_game_state = "start_intro"
	room_cleared = false
	background.color = Color("202432")
	background_texture.visible = false
	title_banner.text = "Confront Your Problems"
	meta_label.text = "Escape room quiz game with customizable question catalogs."
	catalog_box.visible = false
	upload_box.visible = false
	room_title.text = "Start Your Escape"
	room_description.text = "Work through rooms by answering questions, switching subjects, or loading your own question files."
	question_label.text = "Press start when you're ready."
	theme_badge.text = "Phase 1: Start"
	hint_label.text = ""
	status_label.text = "Current source: %s (%d rooms)." % [active_catalog_name, rooms.size()]
	_set_answer_buttons_visible(false)
	primary_button.text = "Start Game"
	primary_button.visible = true
	primary_button.disabled = false
	secondary_button.visible = false
	tertiary_button.visible = false


func _show_source_selection() -> void:
	current_game_state = "source_select"
	background.color = Color("202432")
	background_texture.visible = false
	catalog_box.visible = false
	upload_box.visible = false
	room_title.text = "Choose Your Question Source"
	room_description.text = "You can use prerecorded questions or upload your own JSON, TXT, or Markdown module."
	question_label.text = "Do you want prerecorded questions or do you want to upload questions or a study module?"
	theme_badge.text = "Phase 2: Source"
	hint_label.text = ""
	status_label.text = "Built-in subjects available: %d." % subjects_db.size()
	_set_answer_buttons_visible(false)
	primary_button.text = "Use Prerecorded"
	primary_button.visible = true
	primary_button.disabled = false
	secondary_button.text = "Upload Questions"
	secondary_button.visible = true
	secondary_button.disabled = false
	tertiary_button.text = "Back"
	tertiary_button.visible = true
	tertiary_button.disabled = false


func _show_subject_selection() -> void:
	current_game_state = "subject_select"
	background.color = Color("202432")
	background_texture.visible = false
	catalog_box.visible = true
	upload_box.visible = false
	room_title.text = "Choose A Subject"
	room_description.text = "Pick the subject you want from the dropdown."
	question_label.text = "What subject do you want to play?"
	theme_badge.text = "Phase 3: Subject"
	hint_label.text = ""
	status_label.text = "Selected source: %s." % active_catalog_name
	_set_answer_buttons_visible(false)
	primary_button.text = "Start Subject"
	primary_button.visible = true
	primary_button.disabled = subjects_db.is_empty()
	secondary_button.text = "Preview Catalog"
	secondary_button.visible = true
	secondary_button.disabled = subjects_db.is_empty()
	tertiary_button.text = "Back"
	tertiary_button.visible = true
	tertiary_button.disabled = false


func _show_room() -> void:
	current_game_state = "playing"
	var room: Dictionary = rooms[current_room_index]
	room_cleared = false
	catalog_box.visible = false
	upload_box.visible = false
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

	primary_button.text = "Generate With OpenAI"
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
	catalog_box.visible = false
	upload_box.visible = false
	if did_win:
		_play_if_ready(win_player)
	else:
		_play_if_ready(lose_player)
	title_banner.text = "Escape Complete" if did_win else "Try Again"
	meta_label.text = "Final Score %d   Rooms Cleared %d/%d   Hints Used %d   Subject %s" % [
		score,
		current_room_index + int(did_win),
		rooms.size(),
		hints_used,
		active_subject
	]
	room_title.text = "You made it out." if did_win else "The doors sealed shut."
	room_description.text = "Every lock opened and the story can grow from here." if did_win else "You ran out of lives, but the rooms are ready whenever you want another attempt."
	question_label.text = "What do you want to do next?"
	theme_badge.text = "Replay or generate new content"
	hint_label.text = "Next upgrade idea: add story branches, sound, and per-room art."
	status_label.text = "You can restart or generate a fresh room set whenever you want."
	_set_answer_buttons_visible(false)
	primary_button.text = "Start Game"
	primary_button.visible = true
	primary_button.disabled = false
	secondary_button.visible = false
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
		"start_intro", "end":
			_show_source_selection()
		"source_select":
			_show_subject_selection()
		"module_ready":
			_generate_module_catalog()
		"upload_ready":
			_start_game()
		"subject_select":
			_load_selected_catalog()
			_start_game()
		"playing":
			_on_generate_pressed()


func _on_secondary_pressed() -> void:
	_play_if_ready(click_player)
	match current_game_state:
		"source_select":
			question_file_dialog.popup_centered_ratio(0.75)
		"module_ready":
			question_file_dialog.popup_centered_ratio(0.75)
		"upload_ready":
			question_file_dialog.popup_centered_ratio(0.75)
		"subject_select":
			_generate_preview_room()
		"playing":
			_on_hint_pressed()


func _on_tertiary_pressed() -> void:
	if current_game_state == "source_select":
		_play_if_ready(click_player)
		_show_start_screen()
		return
	if current_game_state == "subject_select":
		_play_if_ready(click_player)
		_show_source_selection()
		return
	if current_game_state == "module_ready":
		_play_if_ready(click_player)
		_show_source_selection()
		return
	if current_game_state == "upload_ready":
		_play_if_ready(click_player)
		_show_source_selection()
		return
	if current_game_state != "playing":
		_play_if_ready(click_player)
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
	active_request_kind = "room_generation"
	primary_button.disabled = true
	status_label.text = "Asking OpenAI for a new question..."
	hint_label.text = ""

	if openai_api_key.is_empty():
		primary_button.disabled = false
		status_label.text = "OPENAI_API_KEY is not available. Restart Godot after setting it."
		return

	var prompt := _build_generation_prompt()
	var payload := {
		"model": OPENAI_MODEL,
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

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % openai_api_key
	]
	var error := http_request.request(OPENAI_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		primary_button.disabled = false
		status_label.text = "Could not start the OpenAI request."


func _generate_preview_room() -> void:
	if rooms.is_empty():
		status_label.text = "No room data is available to preview."
		return

	var preview_index: int = clamp(current_room_index, 0, rooms.size() - 1)
	var preview_room: Dictionary = rooms[preview_index]
	_apply_room_theme(preview_room, preview_index)
	title_banner.text = "Generated Preview Mode"
	meta_label.text = "Catalog %s   Subject %s   Preview room %d" % [active_catalog_name, active_subject, preview_index + 1]
	room_title.text = preview_room["title"]
	room_description.text = "This is the room template that OpenAI will replace when you generate new content."
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


func _on_openai_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	primary_button.disabled = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		status_label.text = "OpenAI request failed. Check your API key and internet connection."
		hint_label.text = body.get_string_from_utf8()
		return

	var response_text := body.get_string_from_utf8()
	var parsed_response: Variant = JSON.parse_string(response_text)
	if parsed_response == null:
		status_label.text = "Could not read OpenAI's response."
		return

	var parsed_dict: Dictionary = parsed_response
	var choices: Array = parsed_dict.get("choices", [])
	if choices.is_empty():
		status_label.text = "OpenAI returned no choices."
		hint_label.text = response_text
		return

	var first_choice: Dictionary = choices[0]
	var message: Dictionary = first_choice.get("message", {})
	var content: String = str(message.get("content", ""))
	var parsed_content: Variant = JSON.parse_string(_extract_json_content(content))
	if parsed_content == null:
		status_label.text = "OpenAI replied, but not in the JSON format the app expected."
		hint_label.text = content
		return

	if active_request_kind == "module_generation":
		var generated_rooms: Array = _extract_generated_rooms(parsed_content)
		if generated_rooms.is_empty():
			status_label.text = "OpenAI returned invalid module data."
			hint_label.text = content
			return

		rooms.clear()
		for entry in generated_rooms:
			if entry is Dictionary and _is_valid_generated_room(entry):
				rooms.append(_normalize_generated_room(entry))

		if rooms.is_empty():
			status_label.text = "OpenAI could not build a usable module from that upload."
			return

		current_game_state = "upload_ready"
		catalog_box.visible = false
		upload_box.visible = true
		status_label.text = "Generated %d questions for %s." % [rooms.size(), active_catalog_name]
		room_title.text = "Uploaded Module Ready"
		room_description.text = "Your study module was converted into a playable question set."
		question_label.text = "Press start to use the generated module questions."
		theme_badge.text = "Uploaded Module"
		hint_label.text = "You can rename it and regenerate by uploading a different module."
		primary_button.text = "Start Uploaded Questions"
		secondary_button.text = "Upload Different File"
		tertiary_button.text = "Back"
		return

	var generated_room: Dictionary = parsed_content
	if not _is_valid_generated_room(generated_room):
		status_label.text = "OpenAI returned incomplete puzzle data."
		return

	rooms[current_room_index] = _normalize_generated_room(generated_room)
	status_label.text = "New puzzle loaded from OpenAI."
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


func _load_subject_database() -> void:
	subjects_db.clear()
	questions_db.clear()
	answers_db.clear()
	subject_option.clear()

	var subjects_file: FileAccess = FileAccess.open(SUBJECTS_DATA_PATH, FileAccess.READ)
	var questions_file: FileAccess = FileAccess.open(QUESTIONS_DATA_PATH, FileAccess.READ)
	var answers_file: FileAccess = FileAccess.open(ANSWERS_DATA_PATH, FileAccess.READ)
	if subjects_file == null or questions_file == null or answers_file == null:
		push_error("Could not open subject/question/answer database files.")
		catalog_description.text = "Database files are missing."
		return

	var parsed_subjects: Variant = JSON.parse_string(subjects_file.get_as_text())
	var parsed_questions: Variant = JSON.parse_string(questions_file.get_as_text())
	var parsed_answers: Variant = JSON.parse_string(answers_file.get_as_text())
	if parsed_subjects == null or not (parsed_subjects is Array) or parsed_questions == null or not (parsed_questions is Array) or parsed_answers == null or not (parsed_answers is Array):
		push_error("Database files are not valid JSON arrays.")
		catalog_description.text = "Database files are invalid."
		return

	for entry in parsed_subjects:
		if entry is Dictionary and entry.has("id") and entry.has("name"):
			var subject: Dictionary = entry
			subjects_db.append(subject)
			subject_option.add_item(str(subject["name"]))

	for entry in parsed_questions:
		if entry is Dictionary:
			questions_db.append(entry)

	for entry in parsed_answers:
		if entry is Dictionary:
			answers_db.append(entry)

	if subjects_db.is_empty():
		catalog_description.text = "No prerecorded subjects found."
		return

	subject_option.select(0)
	_update_catalog_details(0)


func _on_subject_selected(index: int) -> void:
	_update_catalog_details(index)


func _update_catalog_details(index: int) -> void:
	if index < 0 or index >= subjects_db.size():
		return

	var subject: Dictionary = subjects_db[index]
	active_catalog_name = str(subject["name"])
	active_subject = str(subject["name"])
	active_subject_id = str(subject["id"])
	catalog_description.text = str(subject.get("description", "No description available."))
	theme_badge.text = "Subject: %s" % active_subject


func _load_selected_catalog() -> void:
	if subjects_db.is_empty():
		return

	var selected_index: int = subject_option.get_selected_id()
	if selected_index < 0 or selected_index >= subjects_db.size():
		selected_index = 0

	var subject: Dictionary = subjects_db[selected_index]
	active_catalog_name = str(subject["name"])
	active_subject = str(subject["name"])
	active_subject_id = str(subject["id"])
	_build_rooms_for_subject(active_subject_id)


func _on_question_file_selected(path: String) -> void:
	pending_upload_path = path
	active_catalog_name = path.get_file().get_basename()
	upload_name_input.text = active_catalog_name
	catalog_box.visible = false
	upload_box.visible = true

	var extension := path.get_extension().to_lower()
	if extension == "json":
		_load_rooms_from_path(path)
		active_subject = "Uploaded"
		current_game_state = "upload_ready"
		status_label.text = "Loaded uploaded questions from %s (%d rooms)." % [active_catalog_name, rooms.size()]
		theme_badge.text = "Phase 2: Uploaded"
		room_title.text = "Uploaded Questions Ready"
		room_description.text = "Your custom question file is loaded and ready to play."
		question_label.text = "Press start to use the uploaded questions."
		upload_help.text = "Rename this uploaded catalog if you want, then press Start Uploaded Questions."
		hint_label.text = ""
		primary_button.text = "Start Uploaded Questions"
		primary_button.visible = true
		primary_button.disabled = rooms.is_empty()
		secondary_button.text = "Upload Different File"
		secondary_button.visible = true
		secondary_button.disabled = false
		tertiary_button.text = "Back"
		tertiary_button.visible = true
		tertiary_button.disabled = false
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		status_label.text = "Could not open the uploaded module."
		return

	pending_upload_text = file.get_as_text()
	current_game_state = "module_ready"
	active_subject = "Uploaded Module"
	room_title.text = "Study Module Ready"
	room_description.text = "This file will be turned into a question set with OpenAI."
	question_label.text = "Give the uploaded module a name, then generate questions from it."
	theme_badge.text = "Phase 2: Module Upload"
	upload_help.text = "TXT and Markdown files are supported here. PDF parsing is not built yet."
	hint_label.text = ""
	status_label.text = "Uploaded module loaded. Press Generate Module Questions when ready."
	primary_button.text = "Generate Module Questions"
	primary_button.visible = true
	primary_button.disabled = pending_upload_text.strip_edges().is_empty()
	secondary_button.text = "Upload Different File"
	secondary_button.visible = true
	secondary_button.disabled = false
	tertiary_button.text = "Back"
	tertiary_button.visible = true
	tertiary_button.disabled = false


func _load_rooms_from_path(path: String) -> void:
	rooms.clear()

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open room data at %s" % path)
		return

	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed == null or not (parsed is Array):
		push_error("Room data is not a valid JSON array.")
		return

	for entry in parsed:
		if entry is Dictionary and _is_valid_generated_room(entry):
			rooms.append(_normalize_generated_room(entry))

	if rooms.is_empty():
		push_error("No valid rooms were loaded from %s" % path)


func _build_rooms_for_subject(subject_id: String) -> void:
	rooms.clear()

	for question in questions_db:
		if str(question.get("subject_id", "")) != subject_id:
			continue

		var room_answers: Array = []
		var correct_index := -1
		for answer in answers_db:
			if str(answer.get("question_id", "")) != str(question.get("id", "")):
				continue
			room_answers.append(str(answer.get("text", "")))
			if bool(answer.get("is_correct", false)):
				correct_index = room_answers.size() - 1

		if room_answers.size() == 3 and correct_index >= 0:
			var room := {
				"title": str(question.get("title", "")),
				"description": str(question.get("description", "")),
				"question": str(question.get("question", "")),
				"answers": room_answers,
				"correct_index": correct_index,
				"hint": str(question.get("hint", "")),
				"success": str(question.get("success", "")),
				"theme_color": str(question.get("theme_color", "")),
				"accent_color": str(question.get("accent_color", "")),
				"background_image": str(question.get("background_image", ""))
			}
			rooms.append(_normalize_generated_room(room))


func _generate_module_catalog() -> void:
	active_request_kind = "module_generation"
	active_catalog_name = upload_name_input.text.strip_edges()
	if active_catalog_name.is_empty():
		active_catalog_name = "Uploaded Module"
		upload_name_input.text = active_catalog_name

	primary_button.disabled = true
	status_label.text = "Asking OpenAI to turn the module into questions..."
	hint_label.text = ""

	if openai_api_key.is_empty():
		primary_button.disabled = false
		status_label.text = "OPENAI_API_KEY is not available. Restart Godot after setting it."
		return

	var trimmed_text := pending_upload_text.strip_edges()
	if trimmed_text.length() > 6000:
		trimmed_text = trimmed_text.substr(0, 6000)

	var prompt := "Return only valid JSON. Prefer either an array of 3 room objects or an object with a rooms array of 3 room objects. " \
		+ "Each room object must have keys title, description, question, answers, correct_index, hint, success. " \
		+ "Answers must contain exactly 3 choices and correct_index must be 0, 1, or 2. " \
		+ "theme_color and accent_color are optional. Keep each answer short. " \
		+ "Build the questions from this uploaded study material. " \
		+ "Use the catalog name '%s'. Study material:\n%s" % [active_catalog_name, trimmed_text]

	var payload := {
		"model": OPENAI_MODEL,
		"messages": [
			{
				"role": "system",
				"content": "You convert study materials into concise multiple-choice escape-room questions. Return JSON only with no markdown."
			},
			{
				"role": "user",
				"content": prompt
			}
		],
		"stream": false
	}

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % openai_api_key
	]
	var error := http_request.request(OPENAI_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		primary_button.disabled = false
		status_label.text = "Could not start module generation with OpenAI."


func _extract_generated_rooms(parsed_content: Variant) -> Array:
	if parsed_content is Array:
		return parsed_content

	if parsed_content is Dictionary:
		var parsed_dict: Dictionary = parsed_content
		var possible_rooms: Variant = parsed_dict.get("rooms", [])
		if possible_rooms is Array:
			return possible_rooms

	return []


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
