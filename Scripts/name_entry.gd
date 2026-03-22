# name_entry.gd
# Modal name-entry form shown after a quiz session ends when the player's result
# qualifies for the leaderboard. The player types their name and submits it;
# the submitted signal carries the name string back to escape_room.gd which
# then calls LeaderboardManager.submit() with the full session result.
#
# Validation rules:
#   - Name must not be empty.
#   - Name must be 24 characters or fewer.
# The form can also be dismissed by clicking outside the panel.
extends CanvasLayer

# Emitted when the player successfully submits a valid name.
# escape_room.gd connects to this signal to receive the name and record the score.
signal submitted(player_name: String)

# The darkened background overlay behind the panel.
@onready var overlay:        ColorRect = $Overlay

# Subtitle label that shows the player's score and time for context while entering their name.
@onready var subtitle_label: Label     = $Overlay/Center/Panel/Margin/VBox/SubtitleLabel

# The text field where the player types their name.
@onready var name_edit:      LineEdit  = $Overlay/Center/Panel/Margin/VBox/NameEdit

# The submit button that triggers name validation and submission.
@onready var submit_button:  Button    = $Overlay/Center/Panel/Margin/VBox/SubmitButton

# Label used to display validation error messages (e.g. "Name must be 24 characters or fewer.").
@onready var error_label:    Label     = $Overlay/Center/Panel/Margin/VBox/ErrorLabel


# Hides the panel on startup and connects all interactive signals.
func _ready() -> void:
	hide()
	overlay.gui_input.connect(_on_overlay_gui_input)
	submit_button.pressed.connect(_on_submit_pressed)
	# Also allow submission by pressing Enter inside the text field.
	name_edit.text_submitted.connect(_on_text_submitted)


# Opens the name entry panel, populates the subtitle with score/time, and focuses the text field.
# score:        number of questions answered correctly.
# total:        total number of questions in the session.
# time_seconds: total elapsed time for the session.
func open(score: int, total: int, time_seconds: int) -> void:
	var mins := time_seconds / 60
	var secs := time_seconds % 60
	subtitle_label.text = "Score: %d / %d   ·   Time: %d:%02d" % [score, total, mins, secs]
	name_edit.text = ""
	error_label.text = ""
	show()
	name_edit.grab_focus()


# Hides the panel without submitting.
func close() -> void:
	hide()


# Called when the submit button is pressed.
func _on_submit_pressed() -> void:
	_try_submit()


# Called when the player presses Enter inside the name field.
# _text is the submitted string but we re-read from name_edit to stay consistent.
func _on_text_submitted(_text: String) -> void:
	_try_submit()


# Validates the name and either shows an error or closes the panel and emits submitted.
func _try_submit() -> void:
	var player_name := name_edit.text.strip_edges()
	if player_name.is_empty():
		error_label.text = "Please enter a name."
		return
	if player_name.length() > 24:
		error_label.text = "Name must be 24 characters or fewer."
		return
	close()
	submitted.emit(player_name)


# Closes the panel if the player clicks outside the panel bounds.
func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel: Control = $Overlay/Center/Panel
		if not panel.get_global_rect().has_point(event.global_position):
			close()
