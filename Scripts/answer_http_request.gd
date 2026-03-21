extends HTTPRequest

var groq_url = "https://api.groq.com/openai/v1/chat/completions"
var groq_api_key = ""

@export var pathToNextScene = "res://Scenes/EssayQuestion.tscn"
@export var AnswerButton: Button
@export var feedBackPrompt: Node

var currentQuestion := ""
var expectedAnswer := ""


func _ready() -> void:
	for child in get_children():
		if child is Button:
			child.pressed.connect(_on_answer_button)

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

	if content == "1":
		if Global.index >= Global.rooms.size() - 1:
			_show_end_overlay("Victory!\nYou escaped every room.", "res://Scenes/main.tscn", false)
		else:
			_show_end_overlay("Victory!\nThe next room opens.", pathToNextScene, true)
		return

	feedBackPrompt.visible = true
	feedBackPrompt.textBox.text = "Wrong. Try again.\nHint: %s" % content


func _build_answer_check_prompt(student_answer: String) -> String:
	var prompt_text: String = "You are grading a university student's answer in an escape-room study game.\n"
	prompt_text += "Question: %s\n" % currentQuestion
	prompt_text += "Expected answer or key idea: %s\n" % expectedAnswer
	prompt_text += "Student answer: %s\n\n" % student_answer
	prompt_text += "Rules:\n"
	prompt_text += "- Respond with only 1 if the student's answer is correct or close enough.\n"
	prompt_text += "- Treat synonyms, paraphrases, near-equivalent wording, and conceptually correct shortened answers as correct.\n"
	prompt_text += "- Examples of close-enough answers include synonym swaps like fast/rapid, easy/simple, correct/accurate when the intended meaning matches.\n"
	prompt_text += "- If the student is partially right but missing a necessary idea, do not mark it correct.\n"
	prompt_text += "- If the answer is wrong, return one short hint only.\n"
	prompt_text += "- Never reveal the final answer or a full solution.\n"
	prompt_text += "- Keep the hint under 60 characters."
	return prompt_text


func _submit_answer() -> void:
	var student_answer: String = $"../Control/TextEdit".text.strip_edges()
	var prompt_text: String = _build_answer_check_prompt(student_answer)

	var body: String = JSON.stringify({
		"model": "llama-3.3-70b-versatile",
		"messages": [{"role": "user", "content": prompt_text}],
		"max_tokens": 40,
		"temperature": 0.2
	})

	var headers: PackedStringArray = ["Content-Type: application/json", "Authorization: Bearer " + groq_api_key]
	print(prompt_text)
	var request_result: int = request(groq_url, headers, HTTPClient.METHOD_POST, body)
	if request_result != OK:
		print("Error starting request")


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
