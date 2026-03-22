# timer_label.gd
# A Label that reads the global countdown timer from the Global autoload and
# displays it as a plain integer (seconds remaining).
# On ready it sets itself from Global.globalTime, falling back to "hello" if time is zero.
# Every frame it checks if Global.globalTime has decreased and updates the display.
# The actual countdown decrement happens in the room scripts (GeneralRoom.gd, server_vault_room.gd).
extends Label


# Initializes the label text from the current global time.
# Shows "hello" as a fallback if the timer has not been set yet (globalTime <= 0).
func _ready() -> void:
	if Global.globalTime > 0:
		text = str(Global.globalTime)
	else:
		text = "hello"


# Checks each frame whether the global timer has ticked down and refreshes the display.
# Only updates when the new value is less than the currently displayed value,
# avoiding unnecessary text assignments on every frame.
func _process(delta: float) -> void:
	if Global.globalTime < int(text):
		text = str(Global.globalTime)
