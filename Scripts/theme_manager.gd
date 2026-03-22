extends Node

signal theme_changed(is_dark: bool)

const SAVE_PATH := "user://display_settings.cfg"

var is_dark_mode: bool = true

# Flat UI Colors palette — https://flatuicolors.com/palette/defo
# Dark:  Midnight Blue base, Turquoise accents, Clouds text
# Light: Clouds base, Peter River accents, Midnight Blue text
const DARK := {
	"background":    Color(0.173, 0.243, 0.314, 1.0),   # Midnight Blue #2c3e50
	"panel_bg":      Color(0.122, 0.176, 0.239, 0.97),  # darker than bg  #1f2d3d
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
	"side_card_bg":  Color(0.141, 0.200, 0.259, 0.96),  # mid-dark blue   #243341
	"button_bg":     Color(0.204, 0.286, 0.369, 1.0),   # Wet Asphalt     #34495e
	"button_border": Color(0.204, 0.596, 0.859, 1.0),   # Peter River     #3498db
	"button_hover":  Color(0.161, 0.502, 0.725, 1.0),   # Belize Hole     #2980b9
}

const LIGHT := {
	"background":    Color(0.925, 0.941, 0.945, 1.0),   # Clouds          #ecf0f1
	"panel_bg":      Color(0.969, 0.976, 0.980, 0.97),  # near-white      #f7f9fa
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


func _ready() -> void:
	_load()


func palette() -> Dictionary:
	return DARK if is_dark_mode else LIGHT


func toggle_theme() -> void:
	is_dark_mode = not is_dark_mode
	theme_changed.emit(is_dark_mode)
	_save()


func _save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "is_dark_mode", is_dark_mode)
	cfg.save(SAVE_PATH)


func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		is_dark_mode = cfg.get_value("display", "is_dark_mode", true)
