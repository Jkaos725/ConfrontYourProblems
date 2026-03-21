extends ColorRect

func _ready() -> void:
	color = "Red"
	
	return


func _on_button_pressed() -> void:
	if color.is_equal_approx("Red"):
		color = "Blue"
	elif color.is_equal_approx("Blue"):
		color = "Red"

func query_model():
	var http_request = $HTTPRequest  # Reference to your HTTPRequest node
	
	var test = "Hello, what is the first 2 digits of pi?"
	
	var body = JSON.stringify({
		"model": "llama2",
		"prompt": test,
		"stream": false
	})
	
	var url = "http://localhost:11434/api/chat"
	
	http_request.request(url, [], HTTPClient.METHOD_POST, body)
	return

func _on_http_request_request_completed(result, response_code, headers, body):
	var json = JSON.new()
	json.parse(body.get_string_from_utf8())
	var response = json.get_data()
	print(response["response"])
