# room_loader.gd
# Pure data/logic class (RefCounted — no scene node) that handles validation,
# normalization, and assembly of room dictionaries before a quiz session starts.
#
# Three main responsibilities:
#   1. Validate AI-generated rooms (is_valid_generated_room) — rejects rooms that
#      are malformed, missing required fields, or contain banned meta-material.
#   2. Normalize rooms (normalize_generated_room) — ensures every room dictionary
#      has all expected keys with the correct types before being stored in Global.rooms.
#   3. Build room arrays for a session (build_session_room_subset,
#      build_rooms_for_subject) — slices the full room list down to the selected
#      question count and shuffles when appropriate.
class_name RoomLoader
extends RefCounted


# Returns true if a generated room dictionary passes all quality checks:
#   - Has all required keys: title, description, question, answers, correct_index, hint, success
#   - Does not contain banned meta-material (book/author/chapter references) in any text field
#   - Has exactly 3 answer choices
#   - correct_index is 0, 1, or 2
func is_valid_generated_room(room: Dictionary) -> bool:
	if not room.has("title") or not room.has("description") or not room.has("question"):
		return false
	if not room.has("answers") or not room.has("correct_index") or not room.has("hint") or not room.has("success"):
		return false

	var generated_question: String = str(room.get("question", ""))
	var generated_hint: String = str(room.get("hint", ""))
	var generated_description: String = str(room.get("description", ""))
	# Reject if any text field references book metadata rather than subject matter.
	if _contains_meta_material(generated_question) or _contains_meta_material(generated_hint) or _contains_meta_material(generated_description):
		return false

	var answers: Array = room["answers"]
	if answers.size() != 3:
		return false

	var correct_index: int = int(room["correct_index"])
	return correct_index >= 0 and correct_index < 3


# Converts a raw room dictionary (from AI output or the database) into a
# fully typed, consistently structured dictionary ready for Global.rooms.
# Handles the edge case where the AI returns a boolean true for the "success" field.
func normalize_generated_room(room: Dictionary) -> Dictionary:
	var normalized_success: Variant = room["success"]
	# Some AI responses return `true` instead of a success message string.
	if normalized_success is bool:
		normalized_success = "The lock opens and the path forward is clear."

	return {
		"title":            str(room["title"]),
		"description":      str(room["description"]),
		"question":         str(room["question"]),
		"answers":          room["answers"],
		"correct_index":    int(room["correct_index"]),
		"hint":             str(room["hint"]),
		"success":          str(normalized_success),
		"theme_color":      str(room.get("theme_color", "")),
		"accent_color":     str(room.get("accent_color", "")),
		"background_image": str(room.get("background_image", ""))
	}


# Trims and optionally shuffles a full room array down to the selected question count.
# If active_subject_id is non-empty the array is shuffled first so players get
# different question orders each run. Without a subject filter the first N rooms are taken.
func build_session_room_subset(source_rooms: Array[Dictionary], selected_question_count: int, active_subject_id: String) -> Array[Dictionary]:
	var trimmed_rooms: Array[Dictionary] = source_rooms.duplicate(true)
	if trimmed_rooms.is_empty():
		return trimmed_rooms

	var limit := mini(selected_question_count, trimmed_rooms.size())
	if active_subject_id.is_empty():
		return trimmed_rooms.slice(0, limit)

	# Shuffle so each session presents a different subset of questions.
	trimmed_rooms.shuffle()
	return trimmed_rooms.slice(0, limit)


# Builds a shuffled room array from the questions/answers database for a specific
# subject and quiz. Matches questions by subject_id and quiz_id, pairs each question
# with its three answers, normalizes the result, and shuffles before returning.
func build_rooms_for_subject(subject_id: String, quiz_id: String, questions_db: Array, answers_db: Array) -> Array[Dictionary]:
	var subject_rooms: Array[Dictionary] = []

	for question in questions_db:
		var question_dict: Dictionary = question
		# Skip questions that belong to a different subject.
		if str(question_dict.get("subject_id", "")) != subject_id:
			continue

		# Skip questions that belong to a different quiz set within this subject.
		var quiz_info: Dictionary = _get_quiz_info_for_question(question_dict)
		if str(quiz_info.get("id", "quiz_1")) != quiz_id:
			continue

		# Collect the three answer choices for this question from the answers database.
		var room_answers: Array = []
		var correct_index := -1
		for answer in answers_db:
			var answer_dict: Dictionary = answer
			if str(answer_dict.get("question_id", "")) != str(question_dict.get("id", "")):
				continue
			room_answers.append(str(answer_dict.get("text", "")))
			if bool(answer_dict.get("is_correct", false)):
				correct_index = room_answers.size() - 1

		# Only add the room if it has exactly 3 answers and a valid correct answer.
		if room_answers.size() == 3 and correct_index >= 0:
			var room := {
				"title":            str(question_dict.get("title", "")),
				"description":      str(question_dict.get("description", "")),
				"question":         str(question_dict.get("question", "")),
				"answers":          room_answers,
				"correct_index":    correct_index,
				"hint":             str(question_dict.get("hint", "")),
				"success":          str(question_dict.get("success", "")),
				"theme_color":      str(question_dict.get("theme_color", "")),
				"accent_color":     str(question_dict.get("accent_color", "")),
				"background_image": str(question_dict.get("background_image", ""))
			}
			subject_rooms.append(normalize_generated_room(room))

	# Shuffle so the question order varies between sessions.
	subject_rooms.shuffle()
	return subject_rooms


# Returns true if the given text string contains any banned meta-material terms
# (references to the book, author, chapter, publisher, etc.) that should never
# appear in a question, hint, or description shown to the player.
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


# Derives the quiz ID and name for a question dictionary.
# First checks for an explicit quiz_id field on the question.
# Falls back to inferring the quiz number from the question's ID suffix
# (e.g. question IDs ending in _1, _2, _3 → quiz_1; _4+ → quiz_2).
func _get_quiz_info_for_question(question: Dictionary) -> Dictionary:
	var explicit_quiz_id := str(question.get("quiz_id", ""))
	var explicit_quiz_name := str(question.get("quiz_name", ""))
	if not explicit_quiz_id.is_empty():
		return {
			"id":   explicit_quiz_id,
			"name": explicit_quiz_name if not explicit_quiz_name.is_empty() else "Quiz Set"
		}

	# Infer quiz number from the numeric suffix of the question ID.
	var question_id := str(question.get("id", ""))
	var suffix_text := question_id.get_slice("_", 1)
	var suffix_number := int(suffix_text)
	var quiz_number := 1 if suffix_number <= 3 else 2
	var subject_id := str(question.get("subject_id", ""))
	var quiz_name := _default_quiz_name(subject_id, quiz_number)
	return {
		"id":   "quiz_%d" % quiz_number,
		"name": quiz_name
	}


# Returns a human-readable default quiz name for a given subject and quiz number.
# Used when the question database does not include explicit quiz name metadata.
func _default_quiz_name(subject_id: String, quiz_number: int) -> String:
	match subject_id:
		"math":               return "Math Homework %d" % quiz_number
		"english":            return "English Homework %d" % quiz_number
		"programming":        return "Programming Quiz %d" % quiz_number
		"godot":              return "Godot Practice %d" % quiz_number
		"cs":                 return "CS Quiz %d" % quiz_number
		"technical_interview":return "Interview Prep %d" % quiz_number
		"science":            return "Science Homework %d" % quiz_number
		"history":            return "History Homework %d" % quiz_number
		_:                    return "Quiz Set %d" % quiz_number
