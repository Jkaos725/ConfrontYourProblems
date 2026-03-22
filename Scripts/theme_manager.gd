# theme_manager.gd
# Autoload singleton — registered as "ThemeManager" in Project Settings.
# Manages the application-wide light/dark color theme and notifies all UI nodes
# when the theme changes via the theme_changed signal.
#
# Color palettes use the Flat UI Colors set (https://flatuicolors.com/palette/defo):
#   DARK  — Midnight Blue base (#2c3e50), Turquoise accents (#1abc9c), Clouds text (#ecf0f1)
#   LIGHT — Clouds base (#ecf0f1), Peter River accents (#3498db), Midnight Blue text (#2c3e50)
#
# Any node that needs to respond to theme changes should:
#   1. Call ThemeManager.palette() to get the current color dictionary.
#   2. Connect to ThemeManager.theme_changed to re-apply colors when the theme switches.
extends Node

# Emitted whenever the theme is toggled. is_dark is true for dark mode, false for light.
signal theme_changed(is_dark: bool)

# Path where the theme preference is saved between sessions.
const SAVE_PATH := "user://display_settings.cfg"

# Whether dark mode is currently active. Loaded from disk on startup.
var is_dark_mode: bool = true

# ── Dark palette ──────────────────────────────────────────────────────────────
# All colors use normalized 0–1 float components. Hex values are shown as comments.
const DARK := {
	"background":    Color(0.173, 0.243, 0.314, 1.0),   # Midnight Blue   #2c3e50
	"panel_bg":      Color(0.122, 0.176, 0.239, 0.97),  # Darker than bg  #1f2d3d
	"panel_border":  Color(0.102, 0.737, 0.612, 1.0),   # Turquoise       #1abc9c
	"text_primary":  Color(0.925, 0.941, 0.945, 1.0),   # Clouds          #ecf0f1
	"text_secondary":Color(0.741, 0.765, 0.780, 1.0),   # Silver          #bdc3c7
	"text_hint":     Color(0.584, 0.647, 0.651, 1.0),   # Concrete        #95a5a6
	"text_accent":   Color(0.102, 0.737, 0.612, 1.0),   # Turquoise       #1abc9c
	"text_content":  Color(0.925, 0.941, 0.945, 1.0),   # Clouds          #ecf0f1
	"text_body":     Color(0.741, 0.765, 0.780, 1.0),   # Silver          #bdc3c7
	"text_card":     Color(0.741, 0.765, 0.780, 1.0),   # Silver          #bdc3c7
	"text_question": Color(0.925, 0.941, 0.945, 1.0),   # Clouds          #ecf0f1
	"question_bg":   Color(0.204, 0.286, 0.369, 0.92),  # Wet Asphalt     #34495e
	"side_card_bg":  Color(0.141, 0.200, 0.259, 0.96),  # Mid-dark blue   #243341
	"button_bg":     Color(0.204, 0.286, 0.369, 1.0),   # Wet Asphalt     #34495e
	"button_border": Color(0.204, 0.596, 0.859, 1.0),   # Peter River     #3498db
	"button_hover":  Color(0.161, 0.502, 0.725, 1.0),   # Belize Hole     #2980b9
}

# ── Light palette ─────────────────────────────────────────────────────────────
const LIGHT := {
	"background":    Color(0.925, 0.941, 0.945, 1.0),   # Clouds          #ecf0f1
	"panel_bg":      Color(0.969, 0.976, 0.980, 0.97),  # Near-white      #f7f9fa
	"panel_border":  Color(0.204, 0.596, 0.859, 1.0),   # Peter River     #3498db
	"text_primary":  Color(0.173, 0.243, 0.314, 1.0),   # Midnight Blue   #2c3e50
	"text_secondary":Color(0.204, 0.286, 0.369, 1.0),   # Wet Asphalt     #34495e
	"text_hint":     Color(0.498, 0.549, 0.553, 1.0),   # Asbestos        #7f8c8d
	"text_accent":   Color(0.204, 0.596, 0.859, 1.0),   # Peter River     #3498db
	"text_content":  Color(0.173, 0.243, 0.314, 1.0),   # Midnight Blue   #2c3e50
	"text_body":     Color(0.204, 0.286, 0.369, 1.0),   # Wet Asphalt     #34495e
	"text_card":     Color(0.173, 0.243, 0.314, 1.0),   # Midnight Blue   #2c3e50
	"text_question": Color(0.173, 0.243, 0.314, 1.0),   # Midnight Blue   #2c3e50
	"question_bg":   Color(0.741, 0.765, 0.780, 0.50),  # Silver 50%      #bdc3c7
	"side_card_bg":  Color(0.925, 0.941, 0.945, 0.97),  # Clouds          #ecf0f1
	"button_bg":     Color(0.741, 0.765, 0.780, 1.0),   # Silver          #bdc3c7
	"button_border": Color(0.161, 0.502, 0.725, 1.0),   # Belize Hole     #2980b9
	"button_hover":  Color(0.204, 0.596, 0.859, 1.0),   # Peter River     #3498db
}


# Loads the saved theme preference from disk on startup.
func _ready() -> void:
	_load()


# Returns the active color palette dictionary (DARK or LIGHT).
# Call this from any node that needs a theme color, e.g.: ThemeManager.palette()["text_primary"]
func palette() -> Dictionary:
	return DARK if is_dark_mode else LIGHT


# Toggles between dark and light mode, emits theme_changed, and saves the new preference.
func toggle_theme() -> void:
	is_dark_mode = not is_dark_mode
	theme_changed.emit(is_dark_mode)
	_save()


# Persists the current is_dark_mode value to user://display_settings.cfg.
func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "is_dark_mode", is_dark_mode)
	cfg.save(SAVE_PATH)


# Loads is_dark_mode from user://display_settings.cfg.
# Defaults to true (dark mode) if no save file exists.
func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		is_dark_mode = cfg.get_value("display", "is_dark_mode", true)
