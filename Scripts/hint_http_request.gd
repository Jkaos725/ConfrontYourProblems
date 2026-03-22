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



func _on_button_pressed() -> void:
	var prompt_text = "You are helping a student in an escape-room study game.\n"
	prompt_text += "Question: %s\n" % str(currentQuestion)
	prompt_text += "Expected answer or key idea: %s\n" % str(expectedAnswer)
	prompt_text += "Rules:\n"
	prompt_text += "- Return only one hint line.\n"
	prompt_text += "- Never reveal the final answer or any answer choice.\n"
	prompt_text += "- Never use the exact expected answer or a direct synonym of it.\n"
	prompt_text += "- Never mention the book, author, chapter, intro, preface, publisher, or tell the user to read the book or notes.\n"
	prompt_text += "- Keep it under 55 characters.\n"
	prompt_text += "- Base the hint on the core concept, not book metadata.\n"
	prompt_text += "- First hint: broad conceptual nudge.\n"
	prompt_text += "- Second hint: narrower conceptual guidance.\n"
	prompt_text += "- Third hint: very close guidance without naming the answer.\n"
	prompt_text += "- Good hints mention properties, behavior, or relationships.\n"
	
	if hintTwo:
		prompt_text += "Prior hints:\n- %s\n- %s\n" % [Hint1.text, Hint2.text]
		prompt_text += "Give the third hint.\n"
	elif hintOne:
		prompt_text += "Prior hint:\n- %s\n" % Hint1.text
		prompt_text += "Give the second hint.\n"
	else:
		prompt_text += "Give the first hint.\n"
	
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

	var expected_lower: String = expectedAnswer.to_lower().strip_edges()
	if not expected_lower.is_empty() and lowered.contains(expected_lower):
		return "Focus on what the concept does."

	if cleaned.length() > 60:
		cleaned = cleaned.substr(0, 60).strip_edges()

	if cleaned.is_empty():
		return "Focus on the key concept."

	return cleaned
