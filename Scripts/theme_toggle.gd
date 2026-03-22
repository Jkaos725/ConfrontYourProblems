# theme_toggle.gd
# Attached to the light/dark mode toggle Button in the main UI.
# Calls ThemeManager.toggle_theme() when pressed and updates its icon
# to reflect the new theme state immediately.
#
# Two icon textures are assigned in the editor:
#   light_on_icon  — shown while dark mode is active (the "turn on light" icon).
#   light_off_icon — shown while light mode is active (the "turn off light" icon).
extends Button

# Icon displayed when dark mode is active. Assign in the Godot editor inspector.
@export var light_on_icon: Texture2D

# Icon displayed when light mode is active. Assign in the Godot editor inspector.
@export var light_off_icon: Texture2D


# Connects to the button's own pressed signal and to ThemeManager's theme_changed signal,
# then sets the initial icon based on the saved theme preference.
func _ready() -> void:
	pressed.connect(_on_pressed)
	ThemeManager.theme_changed.connect(_on_theme_changed)
	_update(ThemeManager.is_dark_mode)


# Toggles the global theme when the button is clicked.
func _on_pressed() -> void:
	ThemeManager.toggle_theme()


# Receives the theme_changed signal from ThemeManager and updates the icon accordingly.
func _on_theme_changed(is_dark: bool) -> void:
	_update(is_dark)


# Sets the button icon based on the current theme.
# is_dark = true  → show the "turn on light" icon (we are in dark mode).
# is_dark = false → show the "turn off light" icon (we are in light mode).
func _update(is_dark: bool) -> void:
	icon = light_on_icon if is_dark else light_off_icon
