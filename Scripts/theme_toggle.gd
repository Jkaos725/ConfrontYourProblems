extends Button


func _ready() -> void:
	pressed.connect(_on_pressed)
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_update(ThemeManager.is_dark_mode)


func _on_pressed() -> void:
	ThemeManager.toggle_theme()


func _on_theme_changed(is_dark: bool) -> void:
	_update(is_dark)


func _update(is_dark: bool) -> void:
	text = "Light Mode" if is_dark else "Dark Mode"
	var p := ThemeManager.palette()
	add_theme_color_override("font_color", p["text_primary"])
