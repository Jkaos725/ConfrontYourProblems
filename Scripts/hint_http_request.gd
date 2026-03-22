# hint_http_request.gd
# Extends HTTPRequest to provide AI-generated progressive hints for essay questions.
# Sends the current question to the Groq API (llama-3.3-70b-versatile) and populates
# up to three hint buttons with increasingly specific conceptual clues.
# The API key is loaded at startup from res://config.cfg so it is never hard-coded.
#
# Hint progression:
#   First press  → broad conceptual nudge    → written to Hint1 button
#   Second press → narrower guidance         → written to Hint2 button
#   Third press  → very close (no answer)    → written to Hint3 button
#
# Safety: _sanitize_hint_text() strips any response that mentions books, authors,
# or accidentally contains words from the expected answer.
extends HTTPRequest

# Groq API endpoint for chat completions.
var groq_url = "https://api.groq.com/openai/v1/chat/completions"

# API key loaded from config.cfg at startup. Never hard-coded.
var groq_api_key = ""

# Unused legacy reference — kept to avoid breaking any existing connections.
var client

# Whether the HTTP node is currently connected and ready. Unused at runtime.
var connected = false

# The question text passed in from the parent room scene.
var currentQuestion

# The correct answer text used to build the banned-word list for the AI prompt.
# This is never sent to the AI directly — only the banned word list is derived from it.
var expectedAnswer := ""

# The three hint buttons in the scene — exported so they can be assigned in the editor.
@export var Hint1 : Button
@export var Hint2 : Button
@export var Hint3 : Button

# Tracks which hint button started the current request so the response can be
# written back to the exact clue the player selected.
var pending_hint_button: Button = null
var pending_hint_level: int = 1


# Connects all three hint buttons to the shared _on_button_pressed handler
# and loads the Groq API key from the config file.
func _ready() -> void:
	Hint1.pressed.connect(_on_button_pressed.bind(Hint1, 1))
	Hint2.pressed.connect(_on_button_pressed.bind(Hint2, 2))
	Hint3.pressed.connect(_on_button_pressed.bind(Hint3, 3))

	var config = ConfigFile.new()
	var err = config.load("res://config.cfg")
	if err == OK:
		groq_api_key = config.get_value("application", "groq_api_key", "")
		print("API key loaded: ", groq_api_key.length(), " chars")
	else:
		print("Failed to load config: ", err)


# Called every frame. No per-frame logic needed.
func _process(delta: float) -> void:
	pass


# Handles the completed HTTP response from the Groq API.
# Parses the JSON, extracts the hint text, sanitizes it,
# and writes it back to the exact clue button the player clicked.
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())

		if parse_result == OK:
			var response = json.get_data()
			if response is Dictionary and response.has("choices"):
				var content: String = _sanitize_hint_text(str(response["choices"][0]["message"]["content"]))
				print("Response: ", content)
				if pending_hint_button != null:
					pending_hint_button.text = content
					pending_hint_button.disabled = true
				pending_hint_button = null
				pending_hint_level = 1
		else:
			print("JSON parse error")
	else:
		print("HTTP Error: ", response_code, " - ", body.get_string_from_utf8())
		if pending_hint_button != null:
			pending_hint_button.disabled = false
		pending_hint_button = null
		pending_hint_level = 1


# Builds a banned-word list from the expected answer so the AI cannot
# reveal it directly or through synonyms. Words shorter than 3 characters are skipped.
# Returns a comma-separated string of meaningful answer words.
func _build_banned_words() -> String:
	var words: PackedStringArray = expectedAnswer.to_lower().split(" ", false)
	var banned: Array[String] = []
	for word in words:
		var clean: String = word.strip_edges()
		if clean.length() > 2:
			banned.append(clean)
	return ", ".join(banned) if banned.size() > 0 else expectedAnswer.to_lower()


# Fires when any of the three hint buttons is pressed.
# Builds the requested hint depth from the clicked clue button,
# then sends the request to the Groq API.
func _on_button_pressed(button: Button, hint_level: int) -> void:
	pending_hint_button = button
	pending_hint_level = hint_level
	var banned_words: String = _build_banned_words()

	# Build the base system prompt with rules and banned words.
	var prompt_text = "You are giving a hint to a student in an escape-room study game.\n"
	prompt_text += "Question: %s\n\n" % str(currentQuestion)
	prompt_text += "BANNED WORDS — never use these or any synonym: %s\n\n" % banned_words
	prompt_text += "Rules:\n"
	prompt_text += "- Return only one hint line.\n"
	prompt_text += "- Never state or imply the answer.\n"
	prompt_text += "- Never mention the book, author, chapter, intro, preface, or publisher.\n"
	prompt_text += "- Keep it under 55 characters.\n"
	prompt_text += "- Hints should mention properties, behaviors, or relationships.\n"
	prompt_text += "- First hint: broad conceptual nudge.\n"
	prompt_text += "- Second hint: narrower conceptual guidance.\n"
	prompt_text += "- Third hint: very close guidance without naming the answer.\n"

	var prior_hints: Array[String] = []
	if hint_level > 1 and _button_has_real_hint(Hint1):
		prior_hints.append(Hint1.text)
	if hint_level > 2 and _button_has_real_hint(Hint2):
		prior_hints.append(Hint2.text)
	if prior_hints.size() > 0:
		prompt_text += "\nEarlier hints already shown:\n- %s\n" % "\n- ".join(prior_hints)

	if hint_level == 3:
		prompt_text += "\nGive the third hint (closest, still no answer).\n"
	elif hint_level == 2:
		prompt_text += "\nGive the second hint (narrower than the first).\n"
	else:
		prompt_text += "\nGive the first hint (broad conceptual nudge).\n"

	var body = JSON.stringify({
		"model": "llama-3.3-70b-versatile",
		"messages": [{"role": "user", "content": prompt_text}],
		"max_tokens": 40,
		"temperature": 0.2
	})

	var headers = ["Content-Type: application/json", "Authorization: Bearer " + groq_api_key]
	print(prompt_text)
	var result = request(groq_url, headers, HTTPClient.METHOD_POST, body)

	if result != OK:
		print("Error starting request")


# Unused handler — kept as a stub in case answer button logic is added here later.
func _on_answer_button():
	pass


func _button_has_real_hint(button: Button) -> bool:
	if button == null:
		return false
	var text_value: String = button.text.strip_edges()
	return text_value != "" and not text_value.begins_with("Clue ") and text_value != "Clue Ready"


# Cleans up the raw AI response to ensure it is safe to show as a hint.
# Strips quotes, takes only the first line, rejects banned phrases and answer words,
# truncates to 60 characters, and returns a fallback string if anything is wrong.
func _sanitize_hint_text(raw_text: String) -> String:
	var cleaned: String = raw_text.strip_edges().replace("\"", "")
	# Take only the first line if the model returned multiple lines.
	if cleaned.contains("\n"):
		cleaned = cleaned.split("\n")[0].strip_edges()

	# Reject responses that reference source material meta-information.
	var banned_phrases: Array[String] = [
		"read the book",
		"read the notes",
		"check the book",
		"check the notes",
		"read the chapter",
		"check the chapter",
		"check the intro",
		"book intro",
		"author",
		"publisher",
		"preface"
	]
	var lowered: String = cleaned.to_lower()
	for phrase in banned_phrases:
		if lowered.contains(phrase):
			return "Focus on the core idea, not the source text."

	# Reject the hint if it contains any significant word from the expected answer.
	var answer_words: PackedStringArray = expectedAnswer.to_lower().split(" ", false)
	for word in answer_words:
		var clean_word: String = word.strip_edges()
		if clean_word.length() > 2 and lowered.contains(clean_word):
			return "Think about how this concept behaves."

	# Hard-truncate to 60 characters.
	if cleaned.length() > 60:
		cleaned = cleaned.substr(0, 60).strip_edges()

	if cleaned.is_empty():
		return "Focus on the key concept."

	return cleaned
