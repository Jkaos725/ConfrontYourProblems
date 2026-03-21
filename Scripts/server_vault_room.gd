extends Control

const START_LIVES := 3

@onready var title_label: Label = $TitleLabel
@onready var meta_label: Label = $MetaLabel
@onready var professor_line: Label = $ProfessorPanel/ProfessorBox/ProfessorLine
@onready var professor_portrait: TextureRect = $ProfessorPanel/ProfessorBox/ProfessorPortrait
@onready var background: ColorRect = $Background
@onready var top_glow: ColorRect = $TopGlow
@onready var walkway: ColorRect = $Walkway
@onready var step_1: ColorRect = $Step1
@onready var step_2: ColorRect = $Step2
@onready var step_3: ColorRect = $Step3
@onready var clue_label: Label = $CluePanel/ClueLabel
@onready var status_label: Label = $StatusLabel
@onready var choice_a: Button = $Choices/ChoiceA
@onready var choice_b: Button = $Choices/ChoiceB
@onready var choice_c: Button = $Choices/ChoiceC
@onready var door: ColorRect = $Door
@onready var doorway: ColorRect = $Door/Doorway
@onready var door_panel: ColorRect = $Door/DoorPanel
@onready var door_label: Label = $Door/DoorLabel
@onready var hint_button: Button = $HintButton
@onready var back_button: Button = $BackButton
@onready var hint_label: Label = $HintLabel
@onready var player_marker: ColorRect = $PlayerMarker

var current_room: Dictionary = {}
var correct_choice := 1
var solved := false
var door_closed_top := 14.0
var door_closed_bottom := -14.0
var player_start_position := Vector2.ZERO
var player_exit_position := Vector2.ZERO
var active_room_tween: Tween
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
var room_palettes := [
	{
		"background": Color("140d07"),
		"glow": Color(0.827451, 0.560784, 0.258824, 0.12),
		"walkway": Color(0.223529, 0.152941, 0.0823529, 0.45),
		"step1": Color(0.290196, 0.192157, 0.105882, 0.98),
		"step2": Color(0.32549, 0.219608, 0.117647, 0.95),
		"step3": Color(0.364706, 0.247059, 0.133333, 0.95),
		"door": Color(0.227451, 0.145098, 0.0784314, 1)
	},
	{
		"background": Color("0d1420"),
		"glow": Color(0.25098, 0.509804, 0.827451, 0.12),
		"walkway": Color(0.101961, 0.180392, 0.266667, 0.48),
		"step1": Color(0.141176, 0.239216, 0.352941, 0.98),
		"step2": Color(0.156863, 0.270588, 0.392157, 0.95),
		"step3": Color(0.184314, 0.305882, 0.439216, 0.95),
		"door": Color(0.117647, 0.192157, 0.301961, 1)
	},
	{
		"background": Color("1a0f1d"),
		"glow": Color(0.65098, 0.313726, 0.768627, 0.12),
		"walkway": Color(0.25098, 0.129412, 0.282353, 0.48),
		"step1": Color(0.333333, 0.160784, 0.372549, 0.98),
		"step2": Color(0.380392, 0.184314, 0.423529, 0.95),
		"step3": Color(0.439216, 0.211765, 0.486275, 0.95),
		"door": Color(0.266667, 0.137255, 0.309804, 1)
	}
]


func _ready() -> void:
	player_start_position = player_marker.position
	player_exit_position = Vector2(door.position.x + (door.size.x * 0.5) - (player_marker.size.x * 0.35), door.position.y + 110.0)
	choice_a.pressed.connect(_on_choice_pressed.bind(0))
	choice_b.pressed.connect(_on_choice_pressed.bind(1))
	choice_c.pressed.connect(_on_choice_pressed.bind(2))
	#hint_button.pressed.connect(_on_hint_pressed)
	#back_button.pressed.connect(_return_to_main)
	_load_current_room()


func _load_current_room() -> void:
	if active_room_tween != null:
		active_room_tween.kill()
		active_room_tween = null

	if Global.rooms.is_empty():
		current_room = {
			"title": "The Server Vault",
			"description": "A brass vault hums in the dark.",
			"question": "Which structure stores values by key for fast retrieval?",
			"answers": ["Array", "Hash Map", "Stack"],
			"correct_index": 1,
			"hint": "Think about key-value lookups.",
			"success": "The vault unlocks and groans open."
		}
	else:
		Global.index = clamp(Global.index, 0, max(Global.rooms.size() - 1, 0))
		current_room = Global.rooms[Global.index]

	current_professor = _select_professor(Global.index)
	_apply_professor_portrait()
	title_label.text = ""
	title_label.visible = false
	_refresh_meta_label()
	clue_label.text = _format_clue_text(str(current_room.get("question", "Which structure stores values by key for fast retrieval?")))
	var answers: Array = current_room.get("answers", ["Array", "Hash Map", "Stack"])
	choice_a.text = _format_choice_text(str(answers[0])) if answers.size() > 0 else "Module A"
	choice_b.text = _format_choice_text(str(answers[1])) if answers.size() > 1 else "Module B"
	choice_c.text = _format_choice_text(str(answers[2])) if answers.size() > 2 else "Module C"
	status_label.text = ""
	professor_line.text = _professor_line("intro")
	hint_label.text = ""
	correct_choice = int(current_room.get("correct_index", 1))
	solved = false
	_apply_palette(Global.index)
	doorway.color = Color(0.0470588, 0.0313726, 0.0156863, 1)
	door_panel.offset_top = door_closed_top
	door_panel.offset_bottom = door_closed_bottom
	door_label.modulate = Color(1, 1, 1, 1)
	player_marker.position = player_start_position
	player_marker.scale = Vector2.ONE
	player_marker.modulate = Color(1, 1, 1, 1)
	choice_a.disabled = false
	choice_b.disabled = false
	choice_c.disabled = false


func _on_choice_pressed(choice_index: int) -> void:
	if solved:
		return

	if choice_index == correct_choice:
		solved = true
		Global.score += 1
		_refresh_meta_label()
		status_label.text = "The exit unlocks. Move through the door to reach the next room."
		professor_line.text = _professor_line("success")
		_disable_choices()
		_open_vault()
		_advance_after_delay()
	else:
		Global.lives -= 1
		_refresh_meta_label()
		if Global.lives <= 0:
			status_label.text = "The vault seals shut. You are out of time and chances."
			professor_line.text = _professor_line("defeat")
			_disable_choices()
			await get_tree().create_timer(1.2).timeout
			_return_to_main()
			return
		status_label.text = "Try again."
		professor_line.text = _professor_line("wrong")


func _disable_choices() -> void:
	choice_a.disabled = true
	choice_b.disabled = true
	choice_c.disabled = true


func _open_vault() -> void:
	active_room_tween = create_tween()
	active_room_tween.set_trans(Tween.TRANS_SINE)
	active_room_tween.set_ease(Tween.EASE_OUT)
	active_room_tween.parallel().tween_property(door, "color", Color(0.568627, 0.407843, 0.180392, 1), 0.25)
	active_room_tween.parallel().tween_property(doorway, "color", Color(0.729412, 0.65098, 0.34902, 0.9), 0.25)
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


func _apply_palette(room_index: int) -> void:
	var palette: Dictionary = room_palettes[room_index % room_palettes.size()]
	background.color = palette["background"]
	top_glow.color = palette["glow"]
	walkway.color = palette["walkway"]
	step_1.color = palette["step1"]
	step_2.color = palette["step2"]
	step_3.color = palette["step3"]
	door.color = palette["door"]


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
	meta_label.text = "Room %d/%d   Lives %d   Score %d" % [
		Global.index + 1,
		max(Global.rooms.size(), 1),
		Global.lives,
		Global.score
	]


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
