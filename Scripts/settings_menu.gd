extends CanvasLayer

@onready var overlay:      ColorRect    = $Overlay
@onready var panel: PanelContainer = $Overlay/Center/Panel
@onready var panel:        PanelContainer = $Overlay/Center/Panel
@onready var title_lbl:    Label        = $Overlay/Center/Panel/Margin/VBox/TitleRow/Title
@onready var close_btn:    Button       = $Overlay/Center/Panel/Margin/VBox/TitleRow/CloseButton
@onready var sep:          HSeparator   = $Overlay/Center/Panel/Margin/VBox/Sep
@onready var music_label:  Label        = $Overlay/Center/Panel/Margin/VBox/MusicRow/MusicLabel
@onready var sfx_label:    Label        = $Overlay/Center/Panel/Margin/VBox/SFXRow/SFXLabel
@onready var music_toggle: CheckButton  = $Overlay/Center/Panel/Margin/VBox/MusicRow/MusicToggle
@onready var music_slider: HSlider      = $Overlay/Center/Panel/Margin/VBox/MusicRow/MusicSlider
@onready var sfx_toggle:   CheckButton  = $Overlay/Center/Panel/Margin/VBox/SFXRow/SFXToggle
@onready var sfx_slider:   HSlider      = $Overlay/Center/Panel/Margin/VBox/SFXRow/SFXSlider


func _ready() -> void:
	music_toggle.set_block_signals(true)
	music_slider.set_block_signals(true)
	sfx_toggle.set_block_signals(true)
	sfx_slider.set_block_signals(true)
	hide()
	_sync_from_audio_manager()
	music_toggle.set_block_signals(false)
	music_slider.set_block_signals(false)
	sfx_toggle.set_block_signals(false)
	sfx_slider.set_block_signals(false)
	overlay.gui_input.connect(_on_overlay_gui_input)
	ThemeManager.theme_changed.connect(_apply_theme)
	_apply_theme(ThemeManager.is_dark_mode)


func open() -> void:
	_sync_from_audio_manager()
	show()


func close() -> void:
	hide()


func _apply_theme(is_dark: bool) -> void:
	var p := ThemeManager.palette()

	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	if style:
		style.bg_color     = p["panel_bg"]
		style.border_color = p["panel_border"]

	title_lbl.add_theme_color_override("font_color", p["text_primary"])
	close_btn.add_theme_color_override("font_color", p["text_primary"])
	music_label.add_theme_color_override("font_color", p["text_content"])
	sfx_label.add_theme_color_override("font_color", p["text_content"])
	sep.modulate = Color(p["panel_border"].r, p["panel_border"].g, p["panel_border"].b, 0.6)


func _sync_from_audio_manager() -> void:
	music_toggle.set_block_signals(true)
	music_slider.set_block_signals(true)
	sfx_toggle.set_block_signals(true)
	sfx_slider.set_block_signals(true)

	music_toggle.button_pressed = not AudioManager.music_muted
	music_slider.value = AudioManager.music_volume
	sfx_toggle.button_pressed = not AudioManager.sfx_muted
	sfx_slider.value = AudioManager.sfx_volume

	music_toggle.set_block_signals(false)
	music_slider.set_block_signals(false)
	sfx_toggle.set_block_signals(false)
	sfx_slider.set_block_signals(false)


func _on_close_button_pressed() -> void:
	close()


func _on_music_toggle_toggled(pressed: bool) -> void:
	AudioManager.set_music_muted(not pressed)


func _on_music_slider_value_changed(value: float) -> void:
	AudioManager.set_music_volume(value)


func _on_sfx_toggle_toggled(pressed: bool) -> void:
	AudioManager.set_sfx_muted(not pressed)


func _on_sfx_slider_value_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not panel.get_global_rect().has_point(event.global_position):
			close()
