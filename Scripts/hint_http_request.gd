extends HTTPRequest

var groq_url = "https://api.groq.com/openai/v1/chat/completions"
var groq_api_key = ""
var client
var connected = false

var currentQuestion
var expectedAnswer := ""

var hintOne = false
var hintTwo = false

@export var Hint1 : Button
@export var Hint2 : Button
@export var Hint3 : Button

# Called when the node enters the scene tree for the first time.
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


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


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
					Hint3.text = content
				elif hintOne:
					Hint2.text = content
					hintTwo = true
				else:
					Hint1.text = content
					hintOne = true
		else:
			print("JSON parse error")
	else:
		print("HTTP Error: ", response_code, " - ", body.get_string_from_utf8())



func _build_banned_words() -> String:
	# Extract meaningful words from the expected answer to use as a banned list.
	# This way the LLM knows what NOT to say without the full answer being visible.
	var words: PackedStringArray = expectedAnswer.to_lower().split(" ", false)
	var banned: Array[String] = []
	for word in words:
		var clean: String = word.strip_edges()
		if clean.length() > 2:
			banned.append(clean)
	return ", ".join(banned) if banned.size() > 0 else expectedAnswer.to_lower()


func _on_button_pressed() -> void:
	var banned_words: String = _build_banned_words()

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

func _on_answer_button():
	pass


func _sanitize_hint_text(raw_text: String) -> String:
	var cleaned: String = raw_text.strip_edges().replace("\"", "")
	if cleaned.contains("\n"):
		cleaned = cleaned.split("\n")[0].strip_edges()

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

	# Word-level check: reject if any meaningful answer word appears in the hint.
	var answer_words: PackedStringArray = expectedAnswer.to_lower().split(" ", false)
	for word in answer_words:
		var clean_word: String = word.strip_edges()
		if clean_word.length() > 2 and lowered.contains(clean_word):
			return "Think about how this concept behaves."

	if cleaned.length() > 60:
		cleaned = cleaned.substr(0, 60).strip_edges()

	if cleaned.is_empty():
		return "Focus on the key concept."

	return cleaned
