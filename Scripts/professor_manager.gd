class_name ProfessorManager
extends RefCounted


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


func get_options() -> Array:
	return PROFESSOR_OPTIONS


func get_professor(index: int) -> Dictionary:
	if index < 0 or index >= PROFESSOR_OPTIONS.size():
		return PROFESSOR_OPTIONS[0]
	return PROFESSOR_OPTIONS[index]


func get_selected_index(selected_name: String) -> int:
	for index in range(PROFESSOR_OPTIONS.size()):
		if str(PROFESSOR_OPTIONS[index].get("name", "")) == selected_name:
			return index
	return 0


func get_description(name: String) -> String:
	for professor in PROFESSOR_OPTIONS:
		var professor_dict: Dictionary = professor
		if str(professor_dict.get("name", "")) == name:
			return str(professor_dict.get("description", ""))
	return ""


func get_portrait_path(name: String) -> String:
	return str(PROFESSOR_PORTRAITS.get(name, "res://Images/angryBot.png"))
