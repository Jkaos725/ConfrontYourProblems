extends Label


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if Global.globalTime > 0:
		text = str(Global.globalTime)
	else:
		text = ""


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.globalTime < int(text):
		text = str(Global.globalTime)
