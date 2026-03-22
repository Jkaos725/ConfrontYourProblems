extends Button

@export var timePercentage = 10
var waitTime

func _ready() -> void:
	waitTime = int(Global.globalTime * 0.01 * timePercentage)
	text = _display_name() + " - " + str(waitTime)
	pressed.connect(_on_pressed)
	if not $Timer.timeout.is_connected(_on_timer_timeout):
		$Timer.timeout.connect(_on_timer_timeout)
	$Timer.wait_time = 1.0
	if $Timer.is_stopped():
		$Timer.start()


func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	waitTime -= 1
	text = _display_name() + " - " + str(waitTime)
	if (waitTime < 0):
		$Timer.stop()
		disabled = false
		text = "Clue Ready"
		_start_pulse_animation()

func _start_pulse_animation() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(self, "modulate", Color(1.2, 1.0, 0.7, 1.0), 0.4)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)

func _on_pressed():
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	disabled = true


func _display_name() -> String:
	return name.replace("Hint", "Clue ")
