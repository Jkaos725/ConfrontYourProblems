# professor_manager.gd
# Pure data class (RefCounted — no scene node) that centralizes all professor
# metadata: names, personality descriptions, and portrait image paths.
# Used by escape_room.gd to populate the professor-selection UI and by any
# room scene that needs to resolve a professor name to a portrait path.
#
# Adding a new professor: add an entry to PROFESSOR_OPTIONS and PROFESSOR_PORTRAITS.
class_name ProfessorManager
extends RefCounted


# The three available professors with their display names and personality descriptions.
# These are shown in the professor-selection screen before a quiz begins.
const PROFESSOR_OPTIONS := [
	{"name": "Professor Vex",  "description": "Harsh, intense, and quick to challenge you."},
	{"name": "Professor Hale", "description": "Calm, neutral, and focused on precision."},
	{"name": "Professor Mira", "description": "Kind, encouraging, and patient with mistakes."}
]

# Maps each professor name to their portrait image path in the res:// filesystem.
const PROFESSOR_PORTRAITS := {
	"Professor Vex":  "res://Images/angryBot.png",
	"Professor Hale": "res://Images/neutralface.png",
	"Professor Mira": "res://Images/happyface.png"
}


# Returns the full list of professor option dictionaries.
# Each entry has "name" and "description" keys.
func get_options() -> Array:
	return PROFESSOR_OPTIONS


# Returns the professor dictionary at the given index.
# Falls back to the first professor (Vex) if the index is out of range.
func get_professor(index: int) -> Dictionary:
	if index < 0 or index >= PROFESSOR_OPTIONS.size():
		return PROFESSOR_OPTIONS[0]
	return PROFESSOR_OPTIONS[index]


# Returns the index of the professor with the given name, or 0 if not found.
# Used to pre-select the correct option in a dropdown when the player returns to the menu.
func get_selected_index(selected_name: String) -> int:
	for index in range(PROFESSOR_OPTIONS.size()):
		if str(PROFESSOR_OPTIONS[index].get("name", "")) == selected_name:
			return index
	return 0


# Returns the personality description string for the named professor.
# Returns an empty string if the name is not found.
func get_description(name: String) -> String:
	for professor in PROFESSOR_OPTIONS:
		var professor_dict: Dictionary = professor
		if str(professor_dict.get("name", "")) == name:
			return str(professor_dict.get("description", ""))
	return ""


# Returns the res:// path to the portrait image for the named professor.
# Falls back to the angry bot (Vex) portrait if the name is not found.
func get_portrait_path(name: String) -> String:
	return str(PROFESSOR_PORTRAITS.get(name, "res://Images/angryBot.png"))
