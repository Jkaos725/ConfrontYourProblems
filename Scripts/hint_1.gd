extends Button

@export var timePercentage = 10
var waitTime

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	waitTime = int(Global.globalTime * 0.01 * timePercentage)
	text = name + " - " + str(waitTime)
	pressed.connect(_on_pressed)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_timer_timeout() -> void:
	waitTime -= 1
	text = name + " - " + str(waitTime)
	if (waitTime < 0):
		$Timer.stop()
		disabled = false
		text = "Hint Available!"

func _on_pressed():
	disabled = true
