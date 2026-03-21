extends Control

const DEFAULT_STATUS := "Choose the right answer to unlock the next room."

var rooms := [
	{
		"title": "Room 1: The Locked Study",
		"description": "A wall safe hums behind a framed quote. The keypad accepts a single answer.",
		"question": "What keyword in programming usually means 'if this is true, do the next thing'?",
		"answers": ["loop", "branch", "compile"],
		"correct_index": 1,
		"hint": "Think about decision-making in code.",
		"success": "The safe clicks open and a brass key slides out."
	},
	{
		"title": "Room 2: The Server Hall",
		"description": "Rows of monitors flicker. One terminal asks what kind of app runs in a browser.",
		"question": "Which option best describes the front end of a web app?",
		"answers": ["The part users see and interact with", "The database backup", "The code compiler only"],
		"correct_index": 0,
		"hint": "It is the layer that shapes the user's experience.",
		"success": "The monitors turn green and a hidden door unlocks."
	},
	{
		"title": "Room 3: The Reflection Chamber",
		"description": "A final door asks for the mindset that keeps hard projects moving.",
		"question": "What helps most when building something challenging step by step?",
		"answers": ["Testing ideas and improving them", "Waiting for perfection first", "Ignoring feedback"],
		"correct_index": 0,
		"hint": "Progress usually beats perfection.",
		"success": "The final lock opens. You escaped."
	}
]

var current_room_index := 0
var room_cleared := false

@onready var room_title: Label = $MarginContainer/PanelContainer/VBoxContainer/RoomTitle
@onready var room_description: Label = $MarginContainer/PanelContainer/VBoxContainer/RoomDescription
@onready var question_label: Label = $MarginContainer/PanelContainer/VBoxContainer/QuestionLabel
@onready var answers_container: VBoxContainer = $MarginContainer/PanelContainer/VBoxContainer/AnswersContainer
@onready var hint_label: Label = $MarginContainer/PanelContainer/VBoxContainer/HintLabel
@onready var status_label: Label = $MarginContainer/PanelContainer/VBoxContainer/StatusLabel
@onready var next_button: Button = $MarginContainer/PanelContainer/VBoxContainer/ActionRow/NextButton


func _ready() -> void:
	for index in range(answers_container.get_child_count()):
		var button := answers_container.get_child(index) as Button
		button.pressed.connect(_on_answer_selected.bind(index))

	$MarginContainer/PanelContainer/VBoxContainer/ActionRow/HintButton.pressed.connect(_on_hint_pressed)
	next_button.pressed.connect(_on_next_pressed)
	_show_room()


func _show_room() -> void:
	var room: Dictionary = rooms[current_room_index]
	room_cleared = false
	room_title.text = room["title"]
	room_description.text = room["description"]
	question_label.text = room["question"]
	hint_label.text = ""
	status_label.text = DEFAULT_STATUS
	next_button.visible = false

	var answers: Array = room["answers"]
	for index in range(answers_container.get_child_count()):
		var button := answers_container.get_child(index) as Button
		button.text = answers[index]
		button.disabled = false


func _on_answer_selected(answer_index: int) -> void:
	if room_cleared:
		return

	var room: Dictionary = rooms[current_room_index]
	if answer_index == room["correct_index"]:
		room_cleared = true
		status_label.text = room["success"]
		next_button.visible = true
		for child in answers_container.get_children():
			var button := child as Button
			button.disabled = true
	else:
		status_label.text = "That answer keeps the door locked. Try again."


func _on_hint_pressed() -> void:
	var room: Dictionary = rooms[current_room_index]
	hint_label.text = "Hint: %s" % room["hint"]


func _on_next_pressed() -> void:
	if not room_cleared:
		return

	if current_room_index >= rooms.size() - 1:
		status_label.text = "You cleared every room. Next we can add story branches, scoring, or Ollama-generated questions."
		next_button.visible = false
		return

	current_room_index += 1
	_show_room()
