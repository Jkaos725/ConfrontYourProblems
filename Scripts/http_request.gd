extends HTTPRequest

var websocket_url = "http://localhost:11434/api/generate"
var ollama_url = "http://localhost:11434/api/generate"
var err = 0
var client # Create the Client.
var connected = false

@onready var question1 = $"../ColorRect"

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for child in get_children():
		if child is Button:
			child.pressed.connect(_on_button_pressed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.new()
		var parse_result = json.parse(body.get_string_from_utf8())
		
		if parse_result == OK:
			var response = json.get_data()
			print("Response: ", response.get("response", ""))
			$Hint1.text = response.get("response", "")
		else:
			print("JSON parse error")
	else:
		print("HTTP Error: ", response_code)



func _on_button_pressed() -> void:
	var prompt_text = "You are a teacher helping a student.
	Do not give them the answer!!!
	Only give them hints!
	Make sure to give the answer in 60 characters or less.
	Make sure the hint is only included. Do not include anything else.
	They are having problems trying to solve this homework.
	Give them the first step in the right direction for this problem:
	What is the derivative of x^2?"
	
	var body = JSON.stringify({
		"model": "llama3",
		"prompt": prompt_text,
		"stream": false
	})
	
	var headers = ["Content-Type: application/json"]
	print("Requst Given")
	var result = request(ollama_url, headers, HTTPClient.METHOD_POST, body)
	
	if result != OK:
		print("Error starting request")
