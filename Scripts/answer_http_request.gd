# answer_http_request.gd
# Extends HTTPRequest to handle AI grading of the player's essay answers
# and to provide a single contextual hint when the answer is wrong.
# Communicates with the Groq API (llama-3.3-70b-versatile).
# The API key is loaded from res://config.cfg so it is never hard-coded.
#
# Two-step flow:
#   1. Player submits an answer → _submit_answer() builds a grading prompt and sends it.
#      The AI replies with exactly "1" (correct) or "0" (wrong).
#   2. If "0" is returned → _send_hint_request() fires a separate hint prompt.
#      The AI's hint is passed to the parent room's handle_answer_wrong() method.
#      The expected answer is NOT included in the hint prompt to prevent leaking it.
#
# The parent room node must expose:
#   handle_answer_correct() — called when the grade is "1".
#   handle_answer_wrong(hint: String) — called when the grade is "0", receives the hint text.
extends HTTPRequest

# Groq API endpoint for chat completions.
var groq_url = "https://api.groq.com/openai/v1/chat/completions"

# API key loaded from config.cfg at startup.
var groq_api_key = ""

# The scene to load if the player wins and there is no parent room controller to handle it.
# Set in the editor via the export property.
@export var pathToNextScene = "res://Scenes/EssayQuestion.tscn"

# The submit/answer button in the room scene. Connected to _on_answer_button() in _ready().
@export var AnswerButton: Button

# Reference to the feedback overlay node (feed_back_prompt.gd).
# Used as a fallback when no parent room controller is found.
@export var feedBackPrompt: Node

# The full question text for the current room, set by the parent room script.
var currentQuestion := ""

# The expected correct answer for the current room, used to build the grading prompt.
# Never sent in the hint prompt to avoid leaking the answer.
var expectedAnswer := ""

# True while waiting for the grading response ("1" or "0").
# False while waiting for the hint response.
var _waiting_for_grade: bool = false

# The student's last submitted answer, stored so it can be included in logs/fallback messages.
var _last_student_answer: String = ""


# Connects the answer button signal and loads the Groq API key from config.cfg.
func _ready() -> void:
	AnswerButton.pressed.connect(_on_answer_button)

	var config: ConfigFile = ConfigFile.new()
	var err: int = config.load("res://config.cfg")
	if err == OK:
		groq_api_key = str(config.get_value("application", "groq_api_key", ""))
		print("API key loaded: ", groq_api_key.length(), " chars")
	else:
		print("Failed to load config: ", err)


# Called every frame. No per-frame logic needed.
func _process(_delta: float) -> void:
	pass


# Handles the completed HTTP response from the Groq API.
# Dispatches to the correct handler based on whether we were waiting for a grade or a hint.
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
			# Grade is correct — notify the parent room controller.
			var room_controller: Node = get_parent()
			if room_controller != null and room_controller.has_method("handle_answer_correct"):
				room_controller.handle_answer_correct()
			elif Global.index >= Global.rooms.size() - 1:
				_show_end_overlay("Victory!\nYou escaped every room.", "res://Scenes/main.tscn", false)
			else:
				_show_end_overlay("Victory!\nThe next room opens.", pathToNextScene, true)
		else:
			# Grade is wrong — fire a separate hint request (without the expected answer).
			_send_hint_request()
	else:
		# This response is the hint (not a grade).
		var hint: String = content if not content.is_empty() else "Think about the core concept."
		var room_controller: Node = get_parent()
		if room_controller != null and room_controller.has_method("handle_answer_wrong"):
			room_controller.handle_answer_wrong(hint)
		else:
			# Fallback: show hint in the feedback overlay if no room controller is present.
			feedBackPrompt.visible = true
			feedBackPrompt.textBox.text = "Wrong. Try again.\nHint: %s" % hint


# Builds the grading prompt sent to the AI.
# The AI is instructed to reply with exactly "1" (correct) or "0" (wrong).
# Synonyms, paraphrases, and conceptually correct shortened answers are accepted as correct.
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


# Builds the hint prompt sent after a wrong answer.
# The expected answer is NOT included — only a banned-word list derived from it —
# so the AI cannot simply rephrase the answer as the hint.
func _build_hint_prompt() -> String:
	# Extract meaningful words (length > 2) from the expected answer to form the banned list.
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


# Sends a request to the Groq API with the given prompt and token limit.
# Uses temperature 0.2 for consistent, factual responses.
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


# Fires the hint request after a wrong answer. Uses max_tokens=50 for concise hints.
func _send_hint_request() -> void:
	_send_request(_build_hint_prompt(), 50)


# Reads the player's answer from the terminal input, marks that we are waiting for a grade,
# and sends the grading request to the API. Uses max_tokens=5 since the response is just "1" or "0".
func _submit_answer() -> void:
	var student_answer: String = $"../Control2/TerminalPanel/TerminalVBox/TerminalInput".text.strip_edges()
	_last_student_answer = student_answer
	_waiting_for_grade = true
	_send_request(_build_grade_prompt(student_answer), 5)


# Shows the legacy end-of-game overlay with a message and transitions to the next scene.
# Used as a fallback when no parent room controller is present.
# advance_index: if true increments Global.index (next room); if false resets the session.
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


# Waits 1.4 seconds then changes to the specified scene.
func _transition_after_delay(next_scene: String) -> void:
	await get_tree().create_timer(1.4).timeout
	get_tree().change_scene_to_file(next_scene)


# Legacy signal handler — kept for compatibility with older scene connections.
func _on_button_pressed() -> void:
	_submit_answer()


# Connected to AnswerButton.pressed in _ready(). Triggers answer grading.
func _on_answer_button() -> void:
	_submit_answer()
