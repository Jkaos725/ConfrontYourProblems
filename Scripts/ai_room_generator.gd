class_name AIRoomGenerator
extends RefCounted


func build_module_prompt(catalog_name: String, notes_text: String) -> String:
	return "Return only valid JSON. Prefer either an array of room objects or an object with a rooms array. " \
		+ "Each room object must include title, description, question, answers, correct_index, hint, success. " \
		+ "Use exactly 3 answer choices. correct_index must be 0, 1, or 2. " \
		+ "Keep the quiz at university level and tie it closely to the uploaded notes. " \
		+ "Make every question about the actual subject matter, concepts, methods, definitions, or problem-solving steps in the notes. " \
		+ "Do not ask about the author, the book title, chapter names, publisher, edition, intro, preface, acknowledgements, or any other source metadata. " \
		+ "Do not phrase hints as 'read the book' or 'check the notes'; give a conceptual clue instead. " \
		+ "Hints must guide the learner without revealing the answer or repeating an answer choice. " \
		+ "Quiz set name: %s. Uploaded notes:\n%s" % [catalog_name, notes_text]


func build_payload(model: String, prompt: String) -> Dictionary:
	return {
		"model": model,
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


func extract_json_content(content: String) -> String:
	var cleaned := content.strip_edges()
	if cleaned.begins_with("```"):
		var first_newline := cleaned.find("\n")
		if first_newline != -1:
			cleaned = cleaned.substr(first_newline + 1)
		if cleaned.ends_with("```"):
			cleaned = cleaned.substr(0, cleaned.length() - 3)

	return cleaned.strip_edges()


func extract_generated_rooms(parsed_content: Variant) -> Array:
	if parsed_content is Array:
		return parsed_content

	if parsed_content is Dictionary:
		var parsed_dict: Dictionary = parsed_content
		var possible_rooms: Variant = parsed_dict.get("rooms", [])
		if possible_rooms is Array:
			return possible_rooms

	return []
