# hint_1.gd
# Attached to each hint Button in the Questionhints room scene.
# Each hint button starts locked (disabled) behind a countdown timer.
# The wait time is calculated as a percentage of the total session time,
# so on shorter timer settings the hint unlocks proportionally sooner.
# Once the countdown finishes the button enables, pulses with a warm glow,
# and disables itself again after the player clicks it to prevent reuse.
extends Button

# Percentage of the total session time to wait before this hint unlocks.
# e.g. 10 means the hint unlocks after 10% of globalTime has elapsed.
# Set per-button in the editor — different hints can have different delays.
@export var timePercentage = 10

# The calculated wait time in seconds, derived from timePercentage at startup.
var waitTime


# Calculates waitTime from the current globalTime, sets the button label,
# connects signals, and starts the per-second countdown timer.
func _ready() -> void:
	waitTime = int(Global.globalTime * 0.01 * timePercentage)
	text = _display_name() + " - " + str(waitTime)
	pressed.connect(_on_pressed)
	# Connect the child Timer's timeout if not already connected.
	if not $Timer.timeout.is_connected(_on_timer_timeout):
		$Timer.timeout.connect(_on_timer_timeout)
	$Timer.wait_time = 1.0
	if $Timer.is_stopped():
		$Timer.start()


# Called every frame. No per-frame logic needed — the countdown uses a Timer node.
func _process(delta: float) -> void:
	pass


# Fires every second, decrementing waitTime and updating the button label.
# When the countdown reaches zero the button unlocks and starts a pulse animation.
func _on_timer_timeout() -> void:
	waitTime -= 1
	text = _display_name() + " - " + str(waitTime)
	if (waitTime < 0):
		$Timer.stop()
		disabled = false
		text = "Clue Ready"
		_start_pulse_animation()


# Starts an infinite looping tween that makes the button glow warm yellow/white
# to draw the player's attention when the hint becomes available.
func _start_pulse_animation() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(self, "modulate", Color(1.2, 1.0, 0.7, 1.0), 0.4)
	tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.4)


# Fires when the player clicks the hint button.
# Resets the modulate color and disables the button so it cannot be clicked again.
func _on_pressed():
	modulate = Color(1.0, 1.0, 1.0, 1.0)
	disabled = true


# Converts the node name (e.g. "Hint1") to a player-facing label (e.g. "Clue 1").
func _display_name() -> String:
	return name.replace("Hint", "Clue ")
