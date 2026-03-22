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

# Tracks whether the first hint has been filled in yet.
var hintOne = false

# Tracks whether the second hint has been filled in yet.
var hintTwo = false

# The three hint buttons in the scene — exported so they can be assigned in the editor.
@export var Hint1 : Button
@export var Hint2 : Button
@export var Hint3 : Button


# Connects all three hint buttons to the shared _on_button_pressed handler
# and loads the Groq API key from the config file.
func _ready() -> void:
	Hint1.pressed.connect(_on_button_pressed)
	Hint2.pressed.connect(_on_button_pressed)
	Hint3.pressed.connect(_on_button_pressed)

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
# and fills the next available hint button in order (Hint1 → Hint2 → Hint3).
func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())

		if parse_result == OK:
			var response = json.get_data()
			if response is Dictionary and response.has("choices"):
				var content: String = _sanitize_hint_text(str(response["choices"][0]["message"]["content"]))
				print("Response: ", content)
				if hintTwo:
					# Both earlier hints are filled — this response goes to Hint3.
					Hint3.text = content
				elif hintOne:
					# First hint exists — fill Hint2 and mark hintTwo as used.
					Hint2.text = content
					hintTwo = true
				else:
					# No hints yet — fill Hint1 and mark hintOne as used.
					Hint1.text = content
					hintOne = true
		else:
			print("JSON parse error")
	else:
		print("HTTP Error: ", response_code, " - ", body.get_string_from_utf8())


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
# Builds a context-aware prompt for the AI based on which hints have already been given,
# then sends the request to the Groq API.
func _on_button_pressed() -> void:
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

	# Add context about prior hints so each new hint is meaningfully different.
	if hintTwo:
		prompt_text += "\nPrior hints already given:\n- %s\n- %s\n" % [Hint1.text, Hint2.text]
		prompt_text += "Give the third hint (closest, still no answer).\n"
	elif hintOne:
		prompt_text += "\nPrior hint already given:\n- %s\n" % Hint1.text
		prompt_text += "Give the second hint (narrower than the first).\n"
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
