extends Control

const DEFAULT_STATUS := "Choose the right answer to unlock the next room."
const GROQ_URL := "https://api.groq.com/openai/v1/chat/completions"
const GROQ_MODEL := "llama-3.3-70b-versatile"
const GROQ_KEY_FILE_PATH := "res://Data/groq_api_key.txt"
const GROQ_LEGACY_KEY_FILE_PATH := "res://Data/grog_api_key.txt"
const GROQ_USER_KEY_FILE_PATH := "user://groq_api_key.txt"
const START_LIVES := 3
const SUBJECT_RUN_ROOM_COUNT := 4
const ROOMS_DATA_PATH := "res://Data/rooms.json"
const SUBJECTS_DATA_PATH := "res://Data/subjects.json"
const QUESTIONS_DATA_PATH := "res://Data/questions.json"
const ANSWERS_DATA_PATH := "res://Data/answers.json"
const CLICK_SOUND_PATH := "res://Audio/New Sounds/Random Sound/skyscraper_seven-click-buttons-ui-menu-sounds-effects-button-13-205396.mp3"
const CORRECT_SOUND_PATH := "res://Audio/New Sounds/New Correct sound/mixkit-correct-answer-fast-notification-953.wav"
const WRONG_SOUND_PATH := "res://Audio/New Sounds/Wrong sounds/tunetank.com_abort-operation.wav"
const UNLOCK_SOUND_PATH := "res://Audio/New Sounds/New Correct sound/mixkit-correct-answer-notification-947.wav"
const WIN_SOUND_PATH := "res://Audio/New Sounds/New Correct sound/mixkit-correct-answer-notification-947.wav"
const LOSE_SOUND_PATH := "res://Audio/New Sounds/Wrong sounds/tunetank.com_abort-operation.wav"
const LIVES_OPTIONS := [1, 2, 3, 5]
const QUESTION_COUNT_OPTIONS := [3, 4, 5, 6, 8]
const HINT_TIMER_OPTIONS := [60, 120, 180, 300, 600]
const PROFESSOR_OPTIONS := [
	{"name": "Professor Vex", "description": "Harsh, intense, and quick to challenge you."},
	{"name": "Professor Hale", "description": "Calm, neutral, and focused on precision."},
	{"name": "Professor Mira", "description": "Kind, encouraging, and patient with mistakes."}
]
const PROFESSOR_PORTRAITS := {
	"Professor Vex": "res://Images/angryBot.png",
	"Professor Hale": "res://Images/neutralface.png",
	"Professor Mira": "res://Images/happyface.png"
}

var rooms: Array[Dictionary] = []
var subjects_db: Array[Dictionary] = []
var questions_db: Array[Dictionary] = []
var answers_db: Array[Dictionary] = []
var quiz_sets_by_subject := {}
var active_catalog_name := "Custom Upload"
var active_subject := "Custom"
var active_subject_id := ""
var active_quiz_name := ""
var active_quiz_id := ""
var active_request_kind := ""
var groq_api_key := ""
var pending_upload_mode := "notes"
var pending_upload_path := ""
var pending_upload_text := ""
var current_professor_name := "Professor Vex"

var current_room_index := 0
var room_cleared := false
var score := 0
var lives_remaining := START_LIVES
var hints_used := 0
var current_game_state := "start_intro"
var current_launch_target := "quiz"
var mascot_home_position := Vector2.ZERO
var mascot_tween: Tween
var selected_lives := START_LIVES
var selected_question_count := SUBJECT_RUN_ROOM_COUNT
var selected_hint_time := 180

@onready var background: ColorRect = $Background
@onready var background_texture: TextureRect = $BackgroundTexture
@onready var margin_container: MarginContainer = $MarginContainer
@onready var main_panel: PanelContainer = $MarginContainer/PanelContainer
@onready var main_vbox: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer
@onready var body_row: HBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/BodyRow
@onready var left_column: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn
@onready var title_banner: Label = $MarginContainer/PanelContainer/VBoxContainer/TopRow/TopInfo/TitleBanner
@onready var meta_label: Label = $MarginContainer/PanelContainer/VBoxContainer/TopRow/TopInfo/MetaLabel
@onready var catalog_box: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/CatalogBox
@onready var catalog_title: Label = $MarginContainer/PanelContainer/VBoxContainer/CatalogBox/CatalogTitle
@onready var catalog_help: Label = $MarginContainer/PanelContainer/VBoxContainer/CatalogBox/CatalogHelp
@onready var subject_option: OptionButton = $MarginContainer/PanelContainer/VBoxContainer/CatalogBox/SubjectOption
@onready var quiz_label: Label = $MarginContainer/PanelContainer/VBoxContainer/CatalogBox/QuizLabel
@onready var quiz_option: OptionButton = $MarginContainer/PanelContainer/VBoxContainer/CatalogBox/QuizOption
@onready var catalog_description: Label = $MarginContainer/PanelContainer/VBoxContainer/CatalogBox/CatalogDescription
@onready var upload_box: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/UploadBox
@onready var upload_name_label: Label = $MarginContainer/PanelContainer/VBoxContainer/UploadBox/UploadNameLabel
@onready var upload_name_input: LineEdit = $MarginContainer/PanelContainer/VBoxContainer/UploadBox/UploadNameInput
@onready var upload_help: Label = $MarginContainer/PanelContainer/VBoxContainer/UploadBox/UploadHelp
@onready var session_setup_box: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/SessionSetupBox
@onready var session_setup_title: Label = $MarginContainer/PanelContainer/VBoxContainer/SessionSetupBox/SessionSetupTitle
@onready var session_setup_help: Label = $MarginContainer/PanelContainer/VBoxContainer/SessionSetupBox/SessionSetupHelp
@onready var lives_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SessionSetupBox/LivesLabel
@onready var hint_timer_label: Label = $MarginContainer/PanelContainer/VBoxContainer/SessionSetupBox/HintTimerLabel
@onready var lives_option: OptionButton = $MarginContainer/PanelContainer/VBoxContainer/SessionSetupBox/LivesOption
@onready var question_count_option: OptionButton = $MarginContainer/PanelContainer/VBoxContainer/SessionSetupBox/QuestionCountOption
@onready var hint_timer_option: OptionButton = $MarginContainer/PanelContainer/VBoxContainer/SessionSetupBox/HintTimerOption
@onready var room_title: Label = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/RoomTitle
@onready var room_description: Label = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/RoomDescription
@onready var question_card: PanelContainer = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/QuestionCard
@onready var question_label: Label = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/QuestionCard/QuestionLabel
@onready var right_column: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/RightColumn
@onready var theme_card: PanelContainer = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/RightColumn/ThemeCard
@onready var theme_badge: Label = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/RightColumn/ThemeCard/ThemeBadge
@onready var answers_container: HBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/AnswersContainer
@onready var hint_card: PanelContainer = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/RightColumn/HintCard
@onready var status_card: PanelContainer = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/RightColumn/StatusCard
@onready var hint_label: Label = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/RightColumn/HintCard/HintLabel
@onready var status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/StatusLabel
@onready var primary_button: Button = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/ActionRow/PrimaryButton
@onready var secondary_button: Button = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/ActionRow/SecondaryButton
@onready var tertiary_button: Button = $MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/ActionRow/TertiaryButton
@onready var quaternary_button: Button = get_node_or_null("MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/ActionRow/QuaternaryButton") as Button
@onready var http_request: HTTPRequest = $HTTPRequest
@onready var question_file_dialog: FileDialog = $QuestionFileDialog
@onready var click_player: AudioStreamPlayer = $ClickPlayer
@onready var correct_player: AudioStreamPlayer = $CorrectPlayer
@onready var wrong_player: AudioStreamPlayer = $WrongPlayer
@onready var unlock_player: AudioStreamPlayer = $UnlockPlayer
@onready var win_player: AudioStreamPlayer = $WinPlayer
@onready var lose_player: AudioStreamPlayer = $LosePlayer
@onready var timer_label: Label = $MarginContainer/PanelContainer/VBoxContainer/HBoxContainer/TimerLabel
@onready var mascot: TextureRect = $MarginContainer/PanelContainer/VBoxContainer/TopRow/MascotBox/Mascot
@onready var mascot_box: CenterContainer = $MarginContainer/PanelContainer/VBoxContainer/TopRow/MascotBox

func _ready() -> void:
	if not String(Global.selected_professor).is_empty():
		current_professor_name = String(Global.selected_professor)
	for index in range(answers_container.get_child_count()):
		var button := answers_container.get_child(index) as Button
		button.pressed.connect(_on_answer_selected.bind(index))

	mascot_home_position = mascot.position
	_configure_audio_players()
	_load_subject_database()
	primary_button.pressed.connect(_on_primary_pressed)
	secondary_button.pressed.connect(_on_secondary_pressed)
	tertiary_button.pressed.connect(_on_tertiary_pressed)
	subject_option.item_selected.connect(_on_subject_selected)
	quiz_option.item_selected.connect(_on_quiz_selected)
	lives_option.item_selected.connect(_on_lives_selected)
	question_count_option.item_selected.connect(_on_question_count_selected)
	hint_timer_option.item_selected.connect(_on_hint_timer_selected)
	question_file_dialog.file_selected.connect(_on_question_file_selected)
	http_request.request_completed.connect(_on_http_request_completed)
	groq_api_key = _load_groq_api_key()
	_populate_session_setup_options()
	_apply_selected_professor_visual()
	_start_mascot_motion()
	if Global.last_result == "victory":
		_show_quiz_victory_screen()
	else:
		_show_start_screen()


func _start_game() -> void:
	if rooms.is_empty():
		status_label.text = "No rooms were loaded. Check Data/rooms.json."
		return

	rooms = _build_session_room_subset(rooms)
	if rooms.is_empty():
		status_label.text = "No rooms are available for the selected setup."
		return

	current_room_index = 0
	score = 0
	lives_remaining = selected_lives
	hints_used = 0
	room_cleared = false
	current_game_state = "playing"
	margin_container.visible = true
	Global.rooms = rooms.duplicate(true)
	Global.active_subject = active_subject
	Global.active_quiz_name = active_quiz_name if not active_quiz_name.is_empty() else active_catalog_name
	Global.selected_lives = selected_lives
	Global.selected_question_count = selected_question_count
	Global.selected_hint_time = selected_hint_time
	Global.reset_quiz_session()
	get_tree().change_scene_to_file("res://Scenes/ServerVaultRoom.tscn")


func _show_start_screen() -> void:
	current_game_state = "start_intro"
	room_cleared = false
	if not String(Global.selected_professor).is_empty():
		current_professor_name = String(Global.selected_professor)
	background.color = Color("0e1423")
	background_texture.visible = true
	_apply_full_panel_layout()
	_apply_intro_emphasis()
	_apply_selected_professor_visual()
	room_title.visible = true
	room_description.visible = true
	question_card.visible = true
	right_column.visible = false
	theme_card.visible = false
	status_card.visible = false
	hint_card.visible = true
	title_banner.text = "Confront Your Problems"
	meta_label.text = ""
	catalog_box.visible = false
	catalog_title.visible = true
	catalog_help.visible = true
	quiz_label.visible = true
	upload_box.visible = false
	session_setup_box.visible = false
	upload_name_label.visible = false
	upload_name_input.visible = false
	room_title.text = "Start Your Escape"
	room_description.text = "Upload lecture notes to build a quiz set, or choose a prerecorded subject for instant practice."
	question_label.text = "Press start when you're ready to study."
	theme_badge.text = ""
	hint_label.text = "The proctor is awake.\nPick a realm.\nSurvive the exam hall."
	status_label.text = ""
	_set_answer_buttons_visible(false)
	primary_button.text = "Start Quiz Game"
	primary_button.visible = true
	primary_button.disabled = false
	secondary_button.text = "Start Question Hints Game"
	secondary_button.visible = true
	secondary_button.disabled = false
	tertiary_button.visible = false


func _show_professor_selection() -> void:
	current_game_state = "professor_select"
	background.color = Color("202432")
	background_texture.visible = false
	_apply_compact_panel_layout()
	_clear_intro_emphasis()
	room_title.visible = false
	room_description.visible = false
	question_card.visible = false
	right_column.visible = false
	theme_card.visible = false
	status_card.visible = false
	hint_card.visible = true
	catalog_box.visible = true
	catalog_title.visible = true
	catalog_title.text = "Choose A Professor"
	catalog_help.visible = true
	catalog_help.text = "Pick the professor who will guide your escape."
	quiz_label.visible = false
	quiz_option.visible = false
	catalog_description.visible = true
	upload_box.visible = false
	session_setup_box.visible = false
	upload_name_label.visible = false
	upload_name_input.visible = false
	meta_label.text = ""
	question_label.text = ""
	theme_badge.text = ""
	hint_label.text = ""
	status_label.text = ""
	_set_answer_buttons_visible(false)
	_populate_professor_options()
	primary_button.text = "Continue"
	primary_button.visible = true
	primary_button.disabled = false
	secondary_button.visible = false
	secondary_button.disabled = true
	tertiary_button.text = "Back"
	tertiary_button.visible = true
	tertiary_button.disabled = false
	_set_quaternary_button(false, true)


func _show_source_selection() -> void:
	current_game_state = "source_select"
	background.color = Color("202432")
	background_texture.visible = false
	_apply_full_panel_layout()
	_clear_intro_emphasis()
	room_title.visible = true
	room_description.visible = true
	question_card.visible = true
	right_column.visible = false
	theme_card.visible = false
	status_card.visible = false
	hint_card.visible = true
	catalog_box.visible = false
	catalog_title.visible = true
	catalog_help.visible = true
	quiz_label.visible = true
	quiz_option.visible = true
	catalog_description.visible = true
	upload_box.visible = false
	session_setup_box.visible = false
	upload_name_label.visible = false
	upload_name_input.visible = false
	room_title.text = "How do you want to start this study session?"
	room_description.text = "Choose a prerecorded set or upload your own text file."
	question_label.text = "Pick the path you want to take for the %s." % ("question hints game" if current_launch_target == "question_hints" else "quiz game")
	theme_badge.text = ""
	hint_label.text = ""
	status_label.text = ""
	_set_answer_buttons_visible(false)
	primary_button.text = "Use Prerecorded"
	primary_button.visible = true
	primary_button.disabled = false
	secondary_button.text = "Upload My Own Text File"
	secondary_button.visible = true
	secondary_button.disabled = false
	tertiary_button.text = "Back"
	tertiary_button.visible = true
	tertiary_button.disabled = false


func _show_subject_selection() -> void:
	current_game_state = "subject_select"
	background.color = Color("202432")
	background_texture.visible = false
	if current_launch_target == "question_hints":
		_apply_compact_panel_layout()
	else:
		_apply_full_panel_layout()
	_clear_intro_emphasis()
	room_title.visible = false
	room_description.visible = false
	question_card.visible = false
	right_column.visible = false
	theme_card.visible = false
	status_card.visible = false
	hint_card.visible = true
	catalog_box.visible = true
	catalog_title.visible = true
	catalog_title.text = "Choose A Subject"
	catalog_help.visible = false
	quiz_label.visible = true
	quiz_option.visible = true
	catalog_description.visible = false
	upload_box.visible = false
	session_setup_box.visible = true
	_configure_session_setup_box()
	upload_name_label.visible = false
	upload_name_input.visible = false
	meta_label.text = ""
	room_title.text = ""
	room_description.text = ""
	question_label.text = ""
	theme_badge.text = ""
	hint_label.text = ""
	status_label.text = ""
	_set_answer_buttons_visible(false)
	_repopulate_subject_options()
	primary_button.text = "Start Subject"
	primary_button.visible = true
	primary_button.disabled = subjects_db.is_empty()
	secondary_button.visible = false
	secondary_button.disabled = true
	tertiary_button.text = "Back"
	tertiary_button.visible = true
	tertiary_button.disabled = false
	_set_quaternary_button(false, true)


func _show_room() -> void:
	current_game_state = "playing"
	var room: Dictionary = rooms[current_room_index]
	room_cleared = false
	_apply_full_panel_layout()
	_clear_intro_emphasis()
	room_title.visible = true
	room_description.visible = true
	question_card.visible = true
	right_column.visible = false
	theme_card.visible = false
	hint_card.visible = false
	status_card.visible = false
	catalog_box.visible = false
	upload_box.visible = false
	session_setup_box.visible = false
	upload_name_label.visible = false
	upload_name_input.visible = false
	_apply_room_theme(room, current_room_index)
	title_banner.text = "Escape Room Challenge"
	meta_label.text = "Quiz %s   Room %d/%d   Score %d   Lives %d   Hints %d" % [
		active_quiz_name,
		current_room_index + 1,
		rooms.size(),
		score,
		lives_remaining,
		hints_used
	]
	room_title.text = room["title"]
	room_description.text = room["description"]
	question_label.text = room["question"]
	theme_badge.text = ""
	hint_label.text = ""
	status_label.text = DEFAULT_STATUS
	_set_answer_buttons_visible(true)

	var answers: Array = room["answers"]
	for index in range(answers_container.get_child_count()):
		var button := answers_container.get_child(index) as Button
		button.text = answers[index]
		button.disabled = false
	
	question_card.visible = true
	primary_button.text = "Restart Catalog"
	primary_button.visible = true
	primary_button.disabled = false
	secondary_button.text = "Show Hint"
	secondary_button.visible = true
	secondary_button.disabled = false
	tertiary_button.text = "Next Room"
	tertiary_button.visible = room_cleared
	tertiary_button.disabled = not room_cleared
	_set_quaternary_button(false, true)

func _show_escape_room():
	var session_rooms: Array[Dictionary] = _build_session_room_subset(rooms)
	if session_rooms.is_empty():
		status_label.text = "No rooms are available for the selected setup."
		return
	Global.rooms = session_rooms
	Global.index = 0
	Global.selected_lives = selected_lives
	Global.selected_question_count = selected_question_count
	Global.selected_hint_time = selected_hint_time
	Global.reset_quiz_session()
	get_tree().change_scene_to_file("res://Scenes/Questionhints.tscn")

func _show_end_screen(did_win: bool) -> void:
	current_game_state = "end"
	room_cleared = false
	_apply_full_panel_layout()
	_clear_intro_emphasis()
	room_title.visible = true
	room_description.visible = true
	question_card.visible = true
	right_column.visible = true
	theme_card.visible = false
	hint_card.visible = true
	status_card.visible = false
	background.color = Color("1f2430") if did_win else Color("342126")
	background_texture.visible = false
	catalog_box.visible = false
	upload_box.visible = false
	session_setup_box.visible = false
	upload_name_label.visible = false
	upload_name_input.visible = false
	if did_win:
		_play_if_ready(win_player)
	else:
		_play_if_ready(lose_player)
	title_banner.text = "Escape Complete" if did_win else "Try Again"
	meta_label.text = "Final Score %d   Rooms Cleared %d/%d   Hints Used %d   Subject %s   Quiz %s" % [
		score,
		current_room_index + int(did_win),
		rooms.size(),
		hints_used,
		active_subject,
		active_quiz_name
	]
	room_title.text = "You made it out." if did_win else "The doors sealed shut."
	room_description.text = "Every lock opened and the story can grow from here." if did_win else "You ran out of lives, but the rooms are ready whenever you want another attempt."
	question_label.text = "What do you want to do next?"
	theme_badge.text = ""
	hint_label.text = "Next upgrade idea: add story branches, sound, and per-room art."
	status_label.text = "You can restart or switch catalogs whenever you want."
	_set_answer_buttons_visible(false)
	primary_button.text = "Start Quiz Game"
	primary_button.visible = true
	primary_button.disabled = false
	secondary_button.text = "Start Question Hints Game"
	secondary_button.visible = true
	secondary_button.disabled = false
	tertiary_button.visible = false


func _show_quiz_victory_screen() -> void:
	current_game_state = "end"
	room_cleared = false
	if not String(Global.selected_professor).is_empty():
		current_professor_name = String(Global.selected_professor)
	background.color = Color("2a1d11")
	background_texture.visible = false
	_apply_full_panel_layout()
	_clear_intro_emphasis()
	_apply_selected_professor_visual()
	room_title.visible = true
	room_description.visible = true
	question_card.visible = true
	right_column.visible = false
	theme_card.visible = false
	status_card.visible = false
	hint_card.visible = true
	catalog_box.visible = false
	upload_box.visible = false
	session_setup_box.visible = false
	upload_name_label.visible = false
	upload_name_input.visible = false
	_set_answer_buttons_visible(false)

	title_banner.text = "Escape Complete"
	meta_label.text = "Quiz %s   Score %d/%d" % [
		Global.last_quiz_name if not Global.last_quiz_name.is_empty() else "Escape",
		Global.last_quiz_score,
		Global.last_quiz_total
	]
	room_title.text = "The final door opens."
	room_description.text = "You made it through every chamber and escaped %s's trial." % current_professor_name
	question_label.text = "What do you want to do next?"
	hint_label.text = "Every solved room becomes part of your archive."
	status_label.text = ""

	primary_button.text = "Start Quiz Game"
	primary_button.visible = true
	primary_button.disabled = false
	secondary_button.text = "Start Question Hints Game"
	secondary_button.visible = true
	secondary_button.disabled = false
	tertiary_button.visible = false
	_set_quaternary_button(false, true)

	Global.last_result = ""


func _set_answer_buttons_visible(is_visible: bool) -> void:
	answers_container.visible = is_visible
	for child in answers_container.get_children():
		var button := child as Button
		button.visible = is_visible


func _set_quaternary_button(is_visible: bool, is_disabled: bool) -> void:
	if quaternary_button == null:
		return
	quaternary_button.visible = is_visible
	quaternary_button.disabled = is_disabled


func _apply_compact_panel_layout() -> void:
	margin_container.offset_top = 112.0
	margin_container.offset_bottom = -52.0
	main_panel.size_flags_vertical = 0
	main_vbox.size_flags_vertical = 0
	body_row.size_flags_vertical = 0
	left_column.size_flags_vertical = 0


func _apply_question_hints_ready_layout() -> void:
	_apply_compact_panel_layout()
	mascot_box.custom_minimum_size = Vector2(190, 72)
	mascot.custom_minimum_size = Vector2(120, 56)
	title_banner.add_theme_font_size_override("font_size", 28)
	room_title.add_theme_font_size_override("font_size", 22)
	room_description.add_theme_font_size_override("font_size", 14)
	question_label.add_theme_font_size_override("font_size", 16)
	question_card.custom_minimum_size = Vector2(0, 72)
	primary_button.custom_minimum_size = Vector2(0, 44)
	secondary_button.custom_minimum_size = Vector2(0, 44)
	tertiary_button.custom_minimum_size = Vector2(0, 44)
	session_setup_box.add_theme_constant_override("separation", 4)
	main_vbox.add_theme_constant_override("separation", 6)


func _apply_ready_screen_layout() -> void:
	_apply_compact_panel_layout()
	mascot_box.custom_minimum_size = Vector2(190, 72)
	mascot.custom_minimum_size = Vector2(120, 56)
	title_banner.add_theme_font_size_override("font_size", 30)
	room_title.add_theme_font_size_override("font_size", 22)
	room_description.add_theme_font_size_override("font_size", 14)
	question_label.add_theme_font_size_override("font_size", 18)
	question_card.custom_minimum_size = Vector2(0, 76)
	primary_button.custom_minimum_size = Vector2(0, 46)
	secondary_button.custom_minimum_size = Vector2(0, 46)
	tertiary_button.custom_minimum_size = Vector2(0, 46)
	session_setup_box.add_theme_constant_override("separation", 4)
	main_vbox.add_theme_constant_override("separation", 6)


func _apply_full_panel_layout() -> void:
	margin_container.offset_top = -108.0
	margin_container.offset_bottom = 108.0
	main_panel.size_flags_vertical = 4
	main_vbox.size_flags_vertical = 4
	body_row.size_flags_vertical = 3
	left_column.size_flags_vertical = 3
	mascot_box.custom_minimum_size = Vector2(190, 128)
	mascot.custom_minimum_size = Vector2(150, 78)
	main_vbox.add_theme_constant_override("separation", 10)
	session_setup_box.add_theme_constant_override("separation", 8)


func _apply_intro_emphasis() -> void:
	room_title.add_theme_font_size_override("font_size", 42)
	question_label.add_theme_font_size_override("font_size", 26)
	question_card.custom_minimum_size = Vector2(0, 170)
	primary_button.add_theme_font_size_override("font_size", 24)
	primary_button.custom_minimum_size = Vector2(0, 78)
	title_banner.add_theme_font_size_override("font_size", 40)
	title_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	room_description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	question_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _clear_intro_emphasis() -> void:
	room_title.add_theme_font_size_override("font_size", 26)
	question_label.add_theme_font_size_override("font_size", 22)
	question_card.custom_minimum_size = Vector2(0, 136)
	primary_button.add_theme_font_size_override("font_size", 16)
	primary_button.custom_minimum_size = Vector2.ZERO
	secondary_button.custom_minimum_size = Vector2.ZERO
	tertiary_button.custom_minimum_size = Vector2.ZERO
	title_banner.add_theme_font_size_override("font_size", 34)


func _on_answer_selected(answer_index: int) -> void:
	if current_game_state != "playing" or room_cleared:
		return

	var room: Dictionary = rooms[current_room_index]
	if answer_index == room["correct_index"]:
		room_cleared = true
		score += 1
		_play_if_ready(correct_player)
		status_label.text = room["success"]
		meta_label.text = "Quiz %s   Room %d/%d   Score %d   Lives %d   Hints %d" % [
			active_quiz_name,
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
			meta_label.text = "Quiz %s   Room %d/%d   Score %d   Lives %d   Hints %d" % [
				active_quiz_name,
				current_room_index + 1,
				rooms.size(),
				score,
				lives_remaining,
				hints_used
			]
			_show_end_screen(false)
			return

		status_label.text = "That answer keeps the door locked. Lives remaining: %d." % lives_remaining
		meta_label.text = "Quiz %s   Room %d/%d   Score %d   Lives %d   Hints %d" % [
			active_quiz_name,
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
			current_launch_target = "quiz"
			_show_professor_selection()
		"professor_select":
			_show_source_selection()
		"source_select":
			_show_subject_selection()
		"module_ready":
			_generate_module_catalog()
		"upload_ready":
			if current_launch_target == "question_hints":
				_show_escape_room()
			else:
				_start_game()
		"subject_select":
			_load_selected_catalog()
			if current_launch_target == "question_hints":
				_show_escape_room()
			else:
				_start_game()
		"playing":
			_restart_loaded_catalog()


func _on_secondary_pressed() -> void:
	_play_if_ready(click_player)
	match current_game_state:
		"source_select":
			pending_upload_mode = "notes"
			question_file_dialog.clear_filters()
			question_file_dialog.add_filter("*.txt,*.md ; Notes or Study Guides")
			question_file_dialog.popup_centered_ratio(0.75)
		"module_ready":
			question_file_dialog.popup_centered_ratio(0.75)
		"upload_ready":
			question_file_dialog.popup_centered_ratio(0.75)
		"playing":
			_on_hint_pressed()
		"start_intro", "end":
			current_launch_target = "question_hints"
			_show_professor_selection()


func _load_other_game() -> void:
	get_tree().change_scene_to_file("res://Scenes/main.tscn")


func _on_tertiary_pressed() -> void:
	if current_game_state == "subject_select":
		_play_if_ready(click_player)
		_show_source_selection()
		return
	if current_game_state == "source_select":
		_play_if_ready(click_player)
		_show_professor_selection()
		return
	if current_game_state == "professor_select":
		_play_if_ready(click_player)
		_show_start_screen()
		return
	if current_game_state == "module_ready":
		_play_if_ready(click_player)
		_show_source_selection()
		return
	if current_game_state == "upload_ready":
		_play_if_ready(click_player)
		_load_other_game()
		return
	if current_game_state != "playing":
		_play_if_ready(click_player)
		return
	_play_if_ready(click_player)
	_on_next_pressed()

func _on_onquarternary_pressed() -> void:
	match current_game_state:
		"upload_ready":
			_show_escape_room()
		"subject_select":
			_load_selected_catalog()
			_show_escape_room()

func _on_hint_pressed() -> void:
	if current_game_state != "playing":
		return

	var room: Dictionary = rooms[current_room_index]
	hints_used += 1
	right_column.visible = true
	hint_card.visible = true
	hint_label.text = "Hint: %s" % room["hint"]
	meta_label.text = "Quiz %s   Room %d/%d   Score %d   Lives %d   Hints %d" % [
		active_quiz_name,
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


func _restart_loaded_catalog() -> void:
	_start_game()


func _generate_preview_room() -> void:
	if rooms.is_empty():
		status_label.text = ""
		return

	var preview_index: int = clamp(current_room_index, 0, rooms.size() - 1)
	var preview_room: Dictionary = rooms[preview_index]
	_apply_room_theme(preview_room, preview_index)
	title_banner.text = "Escape Room Challenge"
	meta_label.text = "Catalog %s   Subject %s   Preview room %d" % [active_catalog_name, active_subject, preview_index + 1]
	room_title.text = preview_room["title"]
	room_description.text = "This is the current room from the selected or uploaded catalog."
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


func _is_valid_generated_room(room: Dictionary) -> bool:
	if not room.has("title") or not room.has("description") or not room.has("question"):
		return false
	if not room.has("answers") or not room.has("correct_index") or not room.has("hint") or not room.has("success"):
		return false

	var generated_question: String = str(room.get("question", ""))
	var generated_hint: String = str(room.get("hint", ""))
	var generated_description: String = str(room.get("description", ""))
	if _contains_meta_material(generated_question) or _contains_meta_material(generated_hint) or _contains_meta_material(generated_description):
		return false

	var answers: Array = room["answers"]
	if answers.size() != 3:
		return false

	var correct_index: int = int(room["correct_index"])
	return correct_index >= 0 and correct_index < 3


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
	quiz_sets_by_subject.clear()
	subject_option.clear()
	quiz_option.clear()

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
			var question_entry: Dictionary = entry
			questions_db.append(question_entry)
			var subject_id := str(question_entry.get("subject_id", ""))
			if subject_id.is_empty():
				continue
			if not quiz_sets_by_subject.has(subject_id):
				quiz_sets_by_subject[subject_id] = []
			var quiz_info: Dictionary = _get_quiz_info_for_question(question_entry)
			var quiz_id := str(quiz_info.get("id", "quiz_1"))
			var quiz_name := str(quiz_info.get("name", "Quiz Set"))
			var quiz_list: Array = quiz_sets_by_subject[subject_id]
			var exists := false
			for quiz_entry in quiz_list:
				if quiz_entry is Dictionary and str(quiz_entry.get("id", "")) == quiz_id:
					exists = true
					break
			if not exists:
				quiz_list.append({
					"id": quiz_id,
					"name": quiz_name
				})
				quiz_sets_by_subject[subject_id] = quiz_list

	for entry in parsed_answers:
		if entry is Dictionary:
			answers_db.append(entry)

	if subjects_db.is_empty():
		catalog_description.text = "No prerecorded subjects found."
		return

	subject_option.select(0)
	_update_subject_selection(0)


func _on_subject_selected(index: int) -> void:
	if current_game_state == "professor_select":
		_update_professor_selection(index)
		return
	_update_subject_selection(index)


func _on_quiz_selected(index: int) -> void:
	_update_quiz_selection(index)


func _update_subject_selection(index: int) -> void:
	if index < 0 or index >= subjects_db.size():
		return

	var subject: Dictionary = subjects_db[index]
	active_catalog_name = str(subject["name"])
	active_subject = str(subject["name"])
	active_subject_id = str(subject["id"])
	_populate_quiz_options(active_subject_id)


func _populate_professor_options() -> void:
	subject_option.clear()
	for professor in PROFESSOR_OPTIONS:
		subject_option.add_item(str(professor.get("name", "Professor")))
	var selected_index := 0
	for index in range(PROFESSOR_OPTIONS.size()):
		if str(PROFESSOR_OPTIONS[index].get("name", "")) == current_professor_name:
			selected_index = index
			break
	subject_option.select(selected_index)
	_update_professor_selection(selected_index)


func _update_professor_selection(index: int) -> void:
	if index < 0 or index >= PROFESSOR_OPTIONS.size():
		return
	var professor: Dictionary = PROFESSOR_OPTIONS[index]
	current_professor_name = str(professor.get("name", "Professor Vex"))
	Global.selected_professor = current_professor_name
	catalog_description.text = str(professor.get("description", ""))
	_apply_selected_professor_visual()
	_start_mascot_motion()


func _repopulate_subject_options() -> void:
	subject_option.clear()
	for subject in subjects_db:
		var subject_dict: Dictionary = subject
		subject_option.add_item(str(subject_dict.get("name", "")))

	if subjects_db.is_empty():
		active_subject = ""
		active_subject_id = ""
		active_quiz_name = ""
		active_quiz_id = ""
		return

	subject_option.select(0)
	_update_subject_selection(0)


func _apply_selected_professor_visual() -> void:
	var portrait_path := str(PROFESSOR_PORTRAITS.get(current_professor_name, "res://Images/angryBot.png"))
	var texture: Variant = load(portrait_path)
	if texture is Texture2D:
		mascot.texture = texture


func _start_mascot_motion() -> void:
	if mascot_tween != null:
		mascot_tween.kill()
	mascot.position = mascot_home_position
	mascot.rotation = 0.0

	mascot_tween = create_tween()
	mascot_tween.set_loops()
	mascot_tween.set_ease(Tween.EASE_IN_OUT)
	mascot_tween.set_trans(Tween.TRANS_SINE)
	mascot_tween.tween_property(mascot, "position", mascot_home_position + Vector2(-16, -4), 0.55)
	mascot_tween.parallel().tween_property(mascot, "rotation_degrees", -4.0, 0.55)
	mascot_tween.tween_property(mascot, "position", mascot_home_position + Vector2(14, 10), 0.7)
	mascot_tween.parallel().tween_property(mascot, "rotation_degrees", 3.5, 0.7)
	mascot_tween.tween_property(mascot, "position", mascot_home_position + Vector2(18, -3), 0.45)
	mascot_tween.parallel().tween_property(mascot, "rotation_degrees", 0.0, 0.45)
	mascot_tween.tween_property(mascot, "position", mascot_home_position + Vector2(-10, 8), 0.55)
	mascot_tween.parallel().tween_property(mascot, "rotation_degrees", -2.0, 0.55)
	mascot_tween.tween_property(mascot, "position", mascot_home_position, 0.55)
	mascot_tween.parallel().tween_property(mascot, "rotation_degrees", 0.0, 0.55)


func _populate_quiz_options(subject_id: String) -> void:
	quiz_option.clear()
	var quiz_list: Array = quiz_sets_by_subject.get(subject_id, [])
	if quiz_list.is_empty():
		active_quiz_id = ""
		active_quiz_name = "General Set"
		catalog_description.text = "No named quiz sets found for this subject."
		theme_badge.text = "Subject: %s" % active_subject
		return

	for quiz_entry in quiz_list:
		var quiz_dict: Dictionary = quiz_entry
		quiz_option.add_item(str(quiz_dict.get("name", "Quiz Set")))

	quiz_option.select(0)
	_update_quiz_selection(0)


func _update_quiz_selection(index: int) -> void:
	var quiz_list: Array = quiz_sets_by_subject.get(active_subject_id, [])
	if index < 0 or index >= quiz_list.size():
		return

	var quiz_entry: Dictionary = quiz_list[index]
	active_quiz_id = str(quiz_entry.get("id", "default"))
	active_quiz_name = str(quiz_entry.get("name", "Quiz Set"))
	var subject_description := ""
	for subject in subjects_db:
		var subject_dict: Dictionary = subject
		if str(subject_dict.get("id", "")) == active_subject_id:
			subject_description = str(subject_dict.get("description", "No description available."))
			break
	catalog_description.text = subject_description
	theme_badge.text = "Subject: %s   Quiz: %s" % [active_subject, active_quiz_name]


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
	var selected_quiz_index: int = quiz_option.get_selected_id()
	if selected_quiz_index < 0:
		selected_quiz_index = 0
	_update_quiz_selection(selected_quiz_index)
	active_catalog_name = "%s - %s" % [active_subject, active_quiz_name]
	_build_rooms_for_subject(active_subject_id, active_quiz_id)


func _on_question_file_selected(path: String) -> void:
	pending_upload_path = path
	active_catalog_name = path.get_file().get_basename()
	upload_name_input.text = active_catalog_name
	catalog_box.visible = false
	upload_box.visible = true
	session_setup_box.visible = false

	var extension := path.get_extension().to_lower()
	if pending_upload_mode == "json" or extension == "json":
		_load_rooms_from_path(path)
		active_subject = "Uploaded"
		active_subject_id = ""
		active_quiz_name = active_catalog_name
		active_quiz_id = "uploaded_json"
		current_game_state = "upload_ready"
		if current_launch_target == "question_hints":
			_apply_question_hints_ready_layout()
		else:
			_apply_ready_screen_layout()
		_clear_intro_emphasis()
		theme_card.visible = false
		status_card.visible = false
		upload_name_label.visible = false
		upload_name_input.visible = false
		session_setup_box.visible = true
		_configure_session_setup_box()
		status_label.text = "Loaded uploaded questions from %s (%d rooms)." % [active_catalog_name, rooms.size()]
		theme_badge.text = ""
		room_title.text = "Uploaded Questions Ready"
		room_description.text = ""
		question_label.text = "Press Start when you're ready."
		upload_help.text = ""
		hint_label.text = ""
		primary_button.text = "Start"
		primary_button.visible = true
		primary_button.disabled = rooms.is_empty()
		secondary_button.text = "Upload Different File"
		secondary_button.visible = true
		secondary_button.disabled = false
		tertiary_button.text = "Back"
		tertiary_button.visible = true
		tertiary_button.disabled = false
		if quaternary_button != null:
			quaternary_button.text = "Start Uploaded Escape"
		_set_quaternary_button(true, false)
		return

	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		status_label.text = "Could not open the uploaded module."
		return

	pending_upload_text = file.get_as_text()
	current_game_state = "module_ready"
	if current_launch_target == "question_hints":
		_apply_question_hints_ready_layout()
	else:
		_apply_ready_screen_layout()
	_clear_intro_emphasis()
	theme_card.visible = false
	status_card.visible = false
	upload_name_label.visible = false
	upload_name_input.visible = false
	session_setup_box.visible = true
	_configure_session_setup_box()
	active_subject = "Uploaded Module"
	active_subject_id = ""
	active_quiz_name = active_catalog_name
	active_quiz_id = "uploaded_module"
	room_title.text = "Escape Room Is Ready"
	room_description.text = ""
	question_label.text = "Press Start when you're ready."
	theme_badge.text = ""
	upload_help.text = ""
	hint_label.text = ""
	status_label.text = ""
	primary_button.text = "Start"
	primary_button.visible = true
	primary_button.disabled = pending_upload_text.strip_edges().is_empty()
	secondary_button.text = "Choose Different Notes"
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


func _build_rooms_for_subject(subject_id: String, quiz_id: String) -> void:
	var subject_rooms: Array[Dictionary] = []

	for question in questions_db:
		if str(question.get("subject_id", "")) != subject_id:
			continue
		var quiz_info: Dictionary = _get_quiz_info_for_question(question)
		if str(quiz_info.get("id", "quiz_1")) != quiz_id:
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
			subject_rooms.append(_normalize_generated_room(room))

	subject_rooms.shuffle()
	rooms = subject_rooms


func _build_session_room_subset(source_rooms: Array[Dictionary]) -> Array[Dictionary]:
	var trimmed_rooms: Array[Dictionary] = source_rooms.duplicate(true)
	if trimmed_rooms.is_empty():
		return trimmed_rooms

	var limit := mini(selected_question_count, trimmed_rooms.size())
	if active_subject_id.is_empty():
		return trimmed_rooms.slice(0, limit)

	trimmed_rooms.shuffle()
	return trimmed_rooms.slice(0, limit)


func _populate_session_setup_options() -> void:
	lives_option.clear()
	for value in LIVES_OPTIONS:
		lives_option.add_item(str(value))

	question_count_option.clear()
	for value in QUESTION_COUNT_OPTIONS:
		question_count_option.add_item(str(value))

	hint_timer_option.clear()
	for seconds in HINT_TIMER_OPTIONS:
		hint_timer_option.add_item("%d minute%s" % [int(seconds / 60), "" if seconds == 60 else "s"])

	_select_option_by_value(lives_option, LIVES_OPTIONS, selected_lives)
	_select_option_by_value(question_count_option, QUESTION_COUNT_OPTIONS, selected_question_count)
	_select_option_by_value(hint_timer_option, HINT_TIMER_OPTIONS, selected_hint_time)


func _configure_session_setup_box() -> void:
	session_setup_title.text = "Session Setup"
	if current_launch_target == "question_hints":
		session_setup_help.text = "Choose question count and total time."
		lives_label.visible = false
		lives_option.visible = false
		hint_timer_label.text = "Time Limit"
		hint_timer_label.visible = true
		hint_timer_option.visible = true
		question_card.custom_minimum_size = Vector2(0, 120)
		room_title.add_theme_font_size_override("font_size", 24)
		room_description.add_theme_font_size_override("font_size", 16)
		question_label.add_theme_font_size_override("font_size", 18)
	else:
		session_setup_help.text = "Choose how many questions and lives you want for this quiz run."
		lives_label.visible = true
		lives_option.visible = true
		hint_timer_label.visible = false
		hint_timer_option.visible = false
		question_card.custom_minimum_size = Vector2(0, 136)
		room_title.add_theme_font_size_override("font_size", 26)
		room_description.add_theme_font_size_override("font_size", 16)
		question_label.add_theme_font_size_override("font_size", 22)


func _select_option_by_value(option_button: OptionButton, values: Array, target_value: int) -> void:
	for index in range(values.size()):
		if int(values[index]) == target_value:
			option_button.select(index)
			return
	if option_button.item_count > 0:
		option_button.select(0)


func _on_lives_selected(index: int) -> void:
	if index < 0 or index >= LIVES_OPTIONS.size():
		return
	selected_lives = int(LIVES_OPTIONS[index])


func _on_question_count_selected(index: int) -> void:
	if index < 0 or index >= QUESTION_COUNT_OPTIONS.size():
		return
	selected_question_count = int(QUESTION_COUNT_OPTIONS[index])


func _on_hint_timer_selected(index: int) -> void:
	if index < 0 or index >= HINT_TIMER_OPTIONS.size():
		return
	selected_hint_time = int(HINT_TIMER_OPTIONS[index])


func _get_quiz_info_for_question(question: Dictionary) -> Dictionary:
	var explicit_quiz_id := str(question.get("quiz_id", ""))
	var explicit_quiz_name := str(question.get("quiz_name", ""))
	if not explicit_quiz_id.is_empty():
		return {
			"id": explicit_quiz_id,
			"name": explicit_quiz_name if not explicit_quiz_name.is_empty() else "Quiz Set"
		}

	var question_id := str(question.get("id", ""))
	var suffix_text := question_id.get_slice("_", 1)
	var suffix_number := int(suffix_text)
	var quiz_number := 1 if suffix_number <= 3 else 2
	var subject_id := str(question.get("subject_id", ""))
	var quiz_name := _default_quiz_name(subject_id, quiz_number)
	return {
		"id": "quiz_%d" % quiz_number,
		"name": quiz_name
	}


func _default_quiz_name(subject_id: String, quiz_number: int) -> String:
	match subject_id:
		"math":
			return "Math Homework %d" % quiz_number
		"english":
			return "English Homework %d" % quiz_number
		"programming":
			return "Programming Quiz %d" % quiz_number
		"godot":
			return "Godot Practice %d" % quiz_number
		"cs":
			return "CS Quiz %d" % quiz_number
		"technical_interview":
			return "Interview Prep %d" % quiz_number
		"science":
			return "Science Homework %d" % quiz_number
		"history":
			return "History Homework %d" % quiz_number
		_:
			return "Quiz Set %d" % quiz_number


func _build_rooms_from_module_text(module_text: String, catalog_name: String) -> Array[Dictionary]:
	var sections: Array[Dictionary] = _extract_module_sections(module_text)
	var built_rooms: Array[Dictionary] = []
	if sections.size() < 3:
		return built_rooms

	var accent_palette := ["#8fe6ff", "#ffcf7d", "#b8f28f", "#f7a8ff", "#ffd39f"]
	for index in range(sections.size()):
		var section: Dictionary = sections[index]
		var clue_text := str(section.get("body", "")).strip_edges()
		if clue_text.is_empty():
			continue

		var answer_data: Dictionary = _build_module_answers(sections, index)
		var answers: Array = answer_data.get("answers", [])
		if answers.size() != 3:
			continue

		var room := {
			"title": "%s: %s" % [catalog_name, str(section.get("title", "Topic"))],
			"description": "",
			"question": clue_text,
			"answers": answers,
			"correct_index": int(answer_data.get("correct_index", 0)),
			"hint": "Match the clue text to the most relevant topic title.",
			"success": "The study note clicks into place and the next door opens.",
			"theme_color": "",
			"accent_color": accent_palette[index % accent_palette.size()],
			"background_image": ""
		}
		built_rooms.append(_normalize_generated_room(room))

	return built_rooms


func _extract_module_sections(module_text: String) -> Array[Dictionary]:
	var sections: Array[Dictionary] = []
	var lines: PackedStringArray = module_text.split("\n")
	var current_title := ""
	var current_body_lines: Array[String] = []

	for raw_line in lines:
		var line := raw_line.strip_edges()
		if line.is_empty():
			continue

		var is_topic_heading := line.begins_with("Topic ") and line.find(":") != -1
		var is_markdown_heading := line.begins_with("## ")
		if is_topic_heading or is_markdown_heading:
			if not current_title.is_empty() and not current_body_lines.is_empty():
				var section_body: String = _join_lines(current_body_lines)
				if not _is_meta_section(current_title, section_body):
					sections.append({
						"title": current_title,
						"body": section_body
					})
			if is_topic_heading:
				current_title = line.get_slice(":", 1).strip_edges()
			else:
				current_title = line.substr(3).strip_edges()
			current_body_lines.clear()
			continue

		if current_title.is_empty():
			continue

		current_body_lines.append(line)

	if not current_title.is_empty() and not current_body_lines.is_empty():
		var final_body: String = _join_lines(current_body_lines)
		if not _is_meta_section(current_title, final_body):
			sections.append({
				"title": current_title,
				"body": final_body
			})

	return sections


func _build_module_answers(sections: Array[Dictionary], correct_section_index: int) -> Dictionary:
	var answers: Array[String] = []
	var correct_title := str(sections[correct_section_index].get("title", "Topic"))
	answers.append(correct_title)

	for index in range(sections.size()):
		if index == correct_section_index:
			continue
		answers.append(str(sections[index].get("title", "Topic")))
		if answers.size() == 3:
			break

	if answers.size() < 3:
		return {
			"answers": [],
			"correct_index": 0
		}

	var correct_index := correct_section_index % 3
	if correct_index != 0:
		var correct_value := answers[0]
		answers.remove_at(0)
		answers.insert(correct_index, correct_value)

	return {
		"answers": answers,
		"correct_index": correct_index
	}


func _join_lines(lines: Array[String]) -> String:
	var combined := ""
	for line in lines:
		if combined.is_empty():
			combined = line
		else:
			combined += " " + line
	return combined


func _extract_json_content(content: String) -> String:
	var cleaned := content.strip_edges()
	if cleaned.begins_with("```"):
		var first_newline := cleaned.find("\n")
		if first_newline != -1:
			cleaned = cleaned.substr(first_newline + 1)
		if cleaned.ends_with("```"):
			cleaned = cleaned.substr(0, cleaned.length() - 3)

	return cleaned.strip_edges()


func _extract_generated_rooms(parsed_content: Variant) -> Array:
	if parsed_content is Array:
		return parsed_content

	if parsed_content is Dictionary:
		var parsed_dict: Dictionary = parsed_content
		var possible_rooms: Variant = parsed_dict.get("rooms", [])
		if possible_rooms is Array:
			return possible_rooms

	return []


func _generate_module_catalog() -> void:
	active_catalog_name = upload_name_input.text.strip_edges()
	if active_catalog_name.is_empty():
		active_catalog_name = "Uploaded Module"
		upload_name_input.text = active_catalog_name

	active_request_kind = "ai_notes_generation"
	primary_button.disabled = true
	status_label.text = "Generating quiz questions from notes with AI..."
	hint_label.text = ""

	var trimmed_text := pending_upload_text.strip_edges()
	if trimmed_text.length() > 5000:
		trimmed_text = trimmed_text.substr(0, 5000)

	if groq_api_key.is_empty():
		_use_local_module_fallback("No Groq API key was found, so the app used the local notes converter instead.")
		hint_label.text = "Set GROQ_API_KEY or create Data/groq_api_key.txt to enable hosted AI generation."
		return

	var prompt := "Return only valid JSON. Prefer either an array of room objects or an object with a rooms array. " \
		+ "Each room object must include title, description, question, answers, correct_index, hint, success. " \
		+ "Use exactly 3 answer choices. correct_index must be 0, 1, or 2. " \
		+ "Keep the quiz at university level and tie it closely to the uploaded notes. " \
		+ "Make every question about the actual subject matter, concepts, methods, definitions, or problem-solving steps in the notes. " \
		+ "Do not ask about the author, the book title, chapter names, publisher, edition, intro, preface, acknowledgements, or any other source metadata. " \
		+ "Do not phrase hints as 'read the book' or 'check the notes'; give a conceptual clue instead. " \
		+ "Hints must guide the learner without revealing the answer or repeating an answer choice. " \
		+ "Quiz set name: %s. Uploaded notes:\n%s" % [active_catalog_name, trimmed_text]

	var payload := {
		"model": GROQ_MODEL,
		"messages": [
			{
				"role": "system",
				"content": "You turn university study notes into concise multiple-choice quiz rooms for an escape-room study app. Return JSON only. Focus on subject-matter concepts, never book metadata, and never reveal answers inside hints."
			},
			{
				"role": "user",
				"content": prompt
			}
		],
		"stream": false,
		"response_format": {
			"type": "json_object"
		}
	}

	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer %s" % groq_api_key
	]
	var error := http_request.request(GROQ_URL, headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		_use_local_module_fallback("Could not start the AI request, so the app used the local notes converter instead.")


func _on_http_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	primary_button.disabled = false
	if active_request_kind != "ai_notes_generation":
		return

	var body_text := body.get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		_use_local_module_fallback("AI generation was unavailable, so the app used the local notes converter instead.")
		hint_label.text = body_text if not body_text.is_empty() else "Set GROQ_API_KEY or add Data/groq_api_key.txt to enable hosted AI generation."
		return

	var parsed_response: Variant = JSON.parse_string(body_text)
	if parsed_response == null:
		_use_local_module_fallback("AI returned unreadable data, so the app used the local notes converter instead.")
		return

	var response_dict: Dictionary = parsed_response
	var choices: Array = response_dict.get("choices", [])
	if choices.is_empty():
		_use_local_module_fallback("AI returned no usable choices, so the app used the local notes converter instead.")
		hint_label.text = body_text
		return

	var first_choice: Dictionary = choices[0]
	var message: Dictionary = first_choice.get("message", {})
	var content: String = str(message.get("content", ""))
	var parsed_content: Variant = JSON.parse_string(_extract_json_content(content))
	if parsed_content == null:
		_use_local_module_fallback("AI returned unstructured content, so the app used the local notes converter instead.")
		hint_label.text = content
		return

	var generated_rooms_variant: Array = _extract_generated_rooms(parsed_content)
	var generated_rooms: Array[Dictionary] = []
	for room_entry in generated_rooms_variant:
		if room_entry is Dictionary and _is_valid_generated_room(room_entry):
			generated_rooms.append(_normalize_generated_room(room_entry))

	if generated_rooms.is_empty():
		_use_local_module_fallback("AI could not build a usable quiz set from those notes, so the app used the local notes converter instead.")
		return

	_finalize_generated_module(generated_rooms, true)
	status_label.text = "AI generated %d questions for %s." % [rooms.size(), active_catalog_name]
	hint_label.text = "This quiz set was generated from your uploaded notes using Groq."
	active_request_kind = ""


func _use_local_module_fallback(reason: String) -> void:
	var generated_rooms := _build_rooms_from_module_text(pending_upload_text, active_catalog_name)
	if generated_rooms.is_empty():
		primary_button.disabled = false
		status_label.text = "The uploaded text needs at least 3 topic sections to build questions."
		hint_label.text = "Try headings like 'Topic 1: Algorithms', then add a few lines under each topic."
		active_request_kind = ""
		return

	_finalize_generated_module(generated_rooms, false)
	status_label.text = reason
	active_request_kind = ""


func _contains_meta_material(text: String) -> bool:
	var lowered: String = text.to_lower()
	var banned_terms: Array[String] = [
		"author",
		"book",
		"chapter",
		"preface",
		"publisher",
		"edition",
		"foreword",
		"acknowledg",
		"introduction to the book",
		"read the book",
		"read the notes",
		"check the book",
		"check the notes"
	]
	for term in banned_terms:
		if lowered.contains(term):
			return true
	return false


func _is_meta_section(title: String, body: String) -> bool:
	var combined: String = "%s\n%s" % [title.to_lower(), body.to_lower()]
	var banned_terms: Array[String] = [
		"about the author",
		"author biography",
		"preface",
		"foreword",
		"acknowledg",
		"copyright",
		"publisher",
		"edition",
		"table of contents",
		"book introduction",
		"about this book"
	]
	for term in banned_terms:
		if combined.contains(term):
			return true
	return false


func _finalize_generated_module(generated_rooms: Array[Dictionary], used_ai: bool) -> void:
	rooms.clear()
	for room in generated_rooms:
		rooms.append(room)

	current_game_state = "upload_ready"
	catalog_box.visible = false
	upload_box.visible = true
	session_setup_box.visible = true
	_configure_session_setup_box()
	if current_launch_target == "question_hints":
		_apply_question_hints_ready_layout()
	else:
		_apply_ready_screen_layout()
	upload_name_label.visible = false
	upload_name_input.visible = false
	active_subject = "Uploaded Module"
	active_subject_id = ""
	status_label.text = ""
	room_title.text = "Escape Room Is Ready"
	room_description.text = ""
	question_label.text = "Press Start when you're ready."
	theme_badge.text = ""
	hint_label.text = ""
	primary_button.text = "Start"
	secondary_button.text = "Choose Different Notes"
	tertiary_button.text = "Back"
	question_card.visible = true


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
		player.stop()
		player.play()


func _load_groq_api_key() -> String:
	var config = ConfigFile.new()
	var err = config.load("res://config.cfg")
	if err == OK:
		groq_api_key = config.get_value("application", "groq_api_key", "")
		print("API key loaded: ", groq_api_key.length(), " chars")
	else:
		print("Failed to load config: ", err)
	
	return groq_api_key


func _read_key_file(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""

	return file.get_as_text().strip_edges()


	
