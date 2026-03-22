extends HTTPRequest

var groq_url = "https://api.groq.com/openai/v1/chat/completions"
var groq_api_key = ""

@export var pathToNextScene = "res://Scenes/EssayQuestion.tscn"
@export var AnswerButton: Button
@export var feedBackPrompt: Node

var currentQuestion := ""
var expectedAnswer := ""

# Tracks whether we're waiting for a grade (1/0) or a hint response.
var _waiting_for_grade: bool = false
var _last_student_answer: String = ""


func _ready() -> void:
	AnswerButton.pressed.connect(_on_answer_button)

	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load("res://config.cfg")
	if err == OK:
		groq_api_key = str(config.get_value("application", "groq_api_key", ""))
		print("API key loaded: ", groq_api_key.length(), " chars")
	else:
		print("Failed to load config: ", err)


func _process(_delta: float) -> void:
	pass


func _on_request_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		print("HTTP Error: ", response_code, " - ", body.get_string_from_utf8())
		return

	var json: JSON = JSON.new()
	var parse_result: int = json.parse(body.get_string_from_utf8())
	if parse_result != OK:
		print("JSON parse error")
		return

	var response: Variant = json.get_data()
	if not (response is Dictionary) or not response.has("choices"):
		return

	var content: String = str(response["choices"][0]["message"]["content"]).strip_edges()
	print("Response: ", content)

	if _waiting_for_grade:
		_waiting_for_grade = false
		if content == "1":
			if Global.index >= Global.rooms.size() - 1:
				_show_end_overlay("Victory!\nYou escaped every room.", "res://Scenes/main.tscn", false)
			else:
				_show_end_overlay("Victory!\nThe next room opens.", pathToNextScene, true)
		else:
			# Grade came back wrong — ask for a hint in a separate call that
			# does NOT include the expected answer, so it can't be leaked.
			_send_hint_request()
	else:
		# This is the hint response.
		var hint: String = content if not content.is_empty() else "Think about the core concept."
		feedBackPrompt.visible = true
		feedBackPrompt.textBox.text = "Wrong. Try again.\nHint: %s" % hint


func _build_grade_prompt(student_answer: String) -> String:
	var prompt_text: String = "You are grading a student's answer in an escape-room study game.\n"
	prompt_text += "Question: %s\n" % currentQuestion
	prompt_text += "Expected answer or key idea: %s\n" % expectedAnswer
	prompt_text += "Student answer: %s\n\n" % student_answer
	prompt_text += "Rules:\n"
	prompt_text += "- Reply with exactly '1' if the student's answer is correct or close enough.\n"
	prompt_text += "- Treat synonyms, paraphrases, near-equivalent wording, and conceptually correct shortened answers as correct.\n"
	prompt_text += "- Reply with exactly '0' if the answer is wrong or incomplete.\n"
	prompt_text += "- Reply with exactly '0' if the answer is empty.\n"
	prompt_text += "- Do not output anything other than '1' or '0'.\n"
	return prompt_text


func _build_hint_prompt() -> String:
	# Build a banned-word list from the expected answer so the LLM
	# cannot simply rephrase it. The expected answer itself is NOT
	# included in this prompt — only the question and the banned words.
	var answer_words: PackedStringArray = expectedAnswer.to_lower().split(" ", false)
	var banned: Array[String] = []
	for word in answer_words:
		var clean: String = word.strip_edges()
		if clean.length() > 2:
			banned.append(clean)

	var banned_str: String = ", ".join(banned) if banned.size() > 0 else expectedAnswer.to_lower()

	var prompt_text: String = "You are giving a hint to a student in an escape-room study game.\n"
	prompt_text += "Question: %s\n\n" % currentQuestion
	prompt_text += "BANNED WORDS — never use these words or any synonym of them: %s\n\n" % banned_str
	prompt_text += "Rules:\n"
	prompt_text += "- Write exactly one hint line.\n"
	prompt_text += "- Describe a property, behavior, or relationship that leads the student to the concept.\n"
	prompt_text += "- Do not mention books, notes, chapters, authors, or publishers.\n"
	prompt_text += "- Keep it under 60 characters.\n"
	prompt_text += "- Do not state or imply the answer directly.\n"
	return prompt_text


func _send_request(prompt_text: String, max_tokens: int) -> void:
	var body: String = JSON.stringify({
		"model": "llama-3.3-70b-versatile",
		"messages": [{"role": "user", "content": prompt_text}],
		"max_tokens": max_tokens,
		"temperature": 0.2
	})
	var headers: PackedStringArray = ["Content-Type: application/json", "Authorization: Bearer " + groq_api_key]
	print(prompt_text)
	var request_result: int = request(groq_url, headers, HTTPClient.METHOD_POST, body)
	if request_result != OK:
		print("Error starting request")


func _send_hint_request() -> void:
	_send_request(_build_hint_prompt(), 50)


func _submit_answer() -> void:
	var student_answer: String = $"../Control2/MarginContainer/PanelContainer/VBoxContainer/BodyRow/LeftColumn/Control/TextEdit".text.strip_edges()
	_last_student_answer = student_answer
	_waiting_for_grade = true
	_send_request(_build_grade_prompt(student_answer), 5)


func _show_end_overlay(message: String, next_scene: String, advance_index: bool) -> void:
	feedBackPrompt.visible = true
	feedBackPrompt.textBox.text = message
	if advance_index:
		Global.index += 1
	else:
		Global.index = 0
		Global.rooms.clear()
		Global.globalTime = 180
	_transition_after_delay(next_scene)


func _transition_after_delay(next_scene: String) -> void:
	await get_tree().create_timer(1.4).timeout
	get_tree().change_scene_to_file(next_scene)


func _on_button_pressed() -> void:
	_submit_answer()


func _on_answer_button() -> void:
	_submit_answer()
