extends Button

@export var light_on_icon: Texture2D
@export var light_off_icon: Texture2D

func _ready() -> void:
	pressed.connect(_on_pressed)
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_update(ThemeManager.is_dark_mode)


func _on_pressed() -> void:
	ThemeManager.toggle_theme()


func _on_theme_changed(is_dark: bool) -> void:
	_update(is_dark)


func _update(is_dark: bool) -> void:
	icon = light_on_icon if is_dark else light_off_icon
