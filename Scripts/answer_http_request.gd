extends HTTPRequest

var groq_url = "https://api.groq.com/openai/v1/chat/completions"
var groq_api_key = ""
var client
var connected = false

@export var pathToNextScene = "res://Scenes/EssayQuestion.tscn"

var currentQuestion

var hintOne = false
var hintTwo = false

@export var AnswerButton:Button
@export var feedBackPrompt:Node

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in get_children():
		if child is Button:
			child.pressed.connect(_on_answer_button)
	
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
				var content = response["choices"][0]["message"]["content"]
				print("Response: ", content)
				if(content == "1"):
					Global.index += 1
					get_tree().change_scene_to_file(pathToNextScene)
				else:
					feedBackPrompt.visible = true
					feedBackPrompt.textBox.text = content
		else:
			print("JSON parse error")
	else:
		print("HTTP Error: ", response_code, " - ", body.get_string_from_utf8())



func _on_button_pressed() -> void:
	var prompt_text = "You are a teacher helping a student.
	Do not give them the answer!!!
	Only give them hints!
	If the answer to the question is correct or close enough to the correct, response with the number 1 only.
	Check if the answer is turned around or explained in a different way.
	If it still leads to the answer, respond with the number 1.
	If the answer is not correct, give them feedback in a form of a hint.
	Make sure the hint is only included. Do not include anything else.
	They are providing an answer to this question:\n"
	
	prompt_text += currentQuestion
	
	prompt_text += "\n This is the answer they gave:\n"
	prompt_text += $"../Control/TextEdit".text
	
	var body = JSON.stringify({
		"model": "llama-3.3-70b-versatile",
		"messages": [{"role": "user", "content": prompt_text}],
		"max_tokens": 40,
		"temperature": 0.5
	})
	
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + groq_api_key]
	print(prompt_text)
	var result = request(groq_url, headers, HTTPClient.METHOD_POST, body)
	
	if result != OK:
		print("Error starting request")

func _on_answer_button():
	var prompt_text = "You are a teacher helping a student.
	Do not give them the answer!!!
	Only give them hints!
	If the explaination to find the answer is correct or close to correct, response with the number 1 only.
	If the answer is not correct, give them feedback in a form of a hint.
	Make sure to give the answer in 60 characters or less.
	Make sure the hint is only included. Do not include anything else.
	They are providing an answer to this question:\n"
	
	prompt_text += currentQuestion
	
	prompt_text += "\n This is the answer they gave:\n"
	prompt_text += $"../Control/TextEdit".text
	
	var body = JSON.stringify({
		"model": "llama-3.3-70b-versatile",
		"messages": [{"role": "user", "content": prompt_text}],
		"max_tokens": 40,
		"temperature": 0.5
	})
	
	var headers = ["Content-Type: application/json", "Authorization: Bearer " + groq_api_key]
	print(prompt_text)
	var result = request(groq_url, headers, HTTPClient.METHOD_POST, body)
	
	if result != OK:
		print("Error starting request")
