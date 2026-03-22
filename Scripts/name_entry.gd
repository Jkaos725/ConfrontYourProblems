extends CanvasLayer

signal submitted(player_name: String)

@onready var overlay:        ColorRect = $Overlay
@onready var subtitle_label: Label     = $Overlay/Center/Panel/Margin/VBox/SubtitleLabel
@onready var name_edit:      LineEdit  = $Overlay/Center/Panel/Margin/VBox/NameEdit
@onready var submit_button:  Button    = $Overlay/Center/Panel/Margin/VBox/SubmitButton
@onready var error_label:    Label     = $Overlay/Center/Panel/Margin/VBox/ErrorLabel


func _ready() -> void:
	hide()
	overlay.gui_input.connect(_on_overlay_gui_input)
	submit_button.pressed.connect(_on_submit_pressed)
	name_edit.text_submitted.connect(_on_text_submitted)


func open(score: int, total: int, time_seconds: int) -> void:
	var mins := time_seconds / 60
	var secs := time_seconds % 60
	subtitle_label.text = "Score: %d / %d   ·   Time: %d:%02d" % [score, total, mins, secs]
	name_edit.text = ""
	error_label.text = ""
	show()
	name_edit.grab_focus()


func close() -> void:
	hide()


func _on_submit_pressed() -> void:
	_try_submit()


func _on_text_submitted(_text: String) -> void:
	_try_submit()


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


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel: Control = $Overlay/Center/Panel
		if not panel.get_global_rect().has_point(event.global_position):
			close()
