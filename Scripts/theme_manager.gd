extends Node

signal theme_changed(is_dark: bool)

const SAVE_PATH := "user://display_settings.cfg"

var is_dark_mode: bool = true

const DARK := {
	"background":    Color(0.101961, 0.0588235, 0.0313726, 1.0),
	"panel_bg":      Color(0.137255, 0.0941176, 0.0588235, 0.95),
	"panel_border":  Color(0.698039, 0.521569,  0.278431,  1.0),
	"text_primary":  Color(0.988235, 0.933333,  0.784314,  1.0),
	"text_secondary":Color(0.850980, 0.713726,  0.501961,  1.0),
	"text_hint":     Color(0.878431, 0.894118,  0.925490,  1.0),
	"text_accent":   Color(0.658824, 0.788235,  0.972549,  1.0),
	"text_content":  Color(0.960784, 0.941176,  0.858824,  1.0),
	"text_body":     Color(0.937255, 0.870588,  0.756863,  1.0),
	"text_card":     Color(0.88,     0.88,      0.88,      1.0),
	"text_question": Color(1.0,      0.968627,  0.913725,  1.0),
	"question_bg":   Color(0.439216, 0.337255,  0.223529,  0.92),
	"side_card_bg":  Color(0.203922, 0.141176,  0.0862745, 0.96),
	"button_bg":     Color(0.152941, 0.105882,  0.0627451, 1.0),
	"button_border": Color(0.474510, 0.333333,  0.176471,  1.0),
	"button_hover":  Color(0.250980, 0.176471,  0.101961,  1.0),
}

const LIGHT := {
	"background":    Color(0.93,  0.91,  0.87,  1.0),
	"panel_bg":      Color(0.99,  0.97,  0.94,  0.97),
	"panel_border":  Color(0.55,  0.40,  0.18,  1.0),
	"text_primary":  Color(0.13,  0.08,  0.03,  1.0),
	"text_secondary":Color(0.32,  0.20,  0.07,  1.0),
	"text_hint":     Color(0.28,  0.28,  0.32,  1.0),
	"text_accent":   Color(0.06,  0.28,  0.68,  1.0),
	"text_content":  Color(0.13,  0.10,  0.05,  1.0),
	"text_body":     Color(0.20,  0.15,  0.07,  1.0),
	"text_card":     Color(0.15,  0.15,  0.15,  1.0),
	"text_question": Color(0.10,  0.06,  0.02,  1.0),
	"question_bg":   Color(0.88,  0.85,  0.78,  0.95),
	"side_card_bg":  Color(0.94,  0.92,  0.87,  0.97),
	"button_bg":     Color(0.96,  0.93,  0.87,  1.0),
	"button_border": Color(0.50,  0.36,  0.14,  1.0),
	"button_hover":  Color(0.88,  0.83,  0.72,  1.0),
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
