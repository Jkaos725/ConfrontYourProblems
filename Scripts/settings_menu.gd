# settings_menu.gd
# Modal settings panel (CanvasLayer) that lets the player adjust audio levels.
# Opened by the settings button in the main lobby (escape_room.gd).
# Syncs its controls from AudioManager when opened and pushes changes back to
# AudioManager immediately as sliders/toggles are adjusted.
#
# Controls:
#   Music row  — CheckButton mutes/unmutes the Music bus; HSlider sets volume.
#   SFX row    — CheckButton mutes/unmutes the SFX bus; HSlider sets volume.
#   Voice row  — CheckButton enables/disables TTS; HSlider sets TTS volume.
#
# Theming is applied via ThemeManager so it respects light/dark mode.
# Clicking outside the panel closes it.
extends CanvasLayer

# Darkened full-screen overlay that closes the panel when clicked outside.
@onready var overlay:      ColorRect    = $Overlay

# The main settings panel container.
@onready var panel:        PanelContainer = $Overlay/Center/Panel

# "Settings" title label.
@onready var title_lbl:    Label        = $Overlay/Center/Panel/Margin/VBox/TitleRow/Title

# X button that closes the panel.
@onready var close_btn:    Button       = $Overlay/Center/Panel/Margin/VBox/TitleRow/CloseButton

# Horizontal rule separator below the title.
@onready var sep:          HSeparator   = $Overlay/Center/Panel/Margin/VBox/Sep

# "Music" label in the music row.
@onready var music_label:  Label        = $Overlay/Center/Panel/Margin/VBox/MusicRow/MusicLabel

# "Sound FX" label in the SFX row.
@onready var sfx_label:    Label        = $Overlay/Center/Panel/Margin/VBox/SFXRow/SFXLabel

# Toggle button that mutes/unmutes the Music bus. Pressed = unmuted (sound on).
@onready var music_toggle: CheckButton  = $Overlay/Center/Panel/Margin/VBox/MusicRow/MusicToggle

# Volume slider for the Music bus (0.0–1.0).
@onready var music_slider: HSlider      = $Overlay/Center/Panel/Margin/VBox/MusicRow/MusicSlider

# Toggle button that mutes/unmutes the SFX bus. Pressed = unmuted (sound on).
@onready var sfx_toggle:   CheckButton  = $Overlay/Center/Panel/Margin/VBox/SFXRow/SFXToggle

# Volume slider for the SFX bus (0.0–1.0).
@onready var sfx_slider:   HSlider      = $Overlay/Center/Panel/Margin/VBox/SFXRow/SFXSlider

# "Voice" label in the TTS row.
@onready var voice_label:  Label        = $Overlay/Center/Panel/Margin/VBox/VoiceRow/VoiceLabel

# Toggle button that enables/disables the professor TTS voice. Pressed = voice on.
@onready var voice_toggle: CheckButton  = $Overlay/Center/Panel/Margin/VBox/VoiceRow/VoiceToggle

# Volume slider for the TTS voice (0.0–1.0).
@onready var voice_slider: HSlider      = $Overlay/Center/Panel/Margin/VBox/VoiceRow/VoiceSlider


# Hides the panel, blocks signals while syncing initial values to avoid feedback loops,
# then wires up theme and overlay-click signals.
func _ready() -> void:
	music_toggle.set_block_signals(true)
	music_slider.set_block_signals(true)
	sfx_toggle.set_block_signals(true)
	sfx_slider.set_block_signals(true)
	voice_toggle.set_block_signals(true)
	voice_slider.set_block_signals(true)
	hide()
	_sync_from_audio_manager()
	music_toggle.set_block_signals(false)
	music_slider.set_block_signals(false)
	sfx_toggle.set_block_signals(false)
	sfx_slider.set_block_signals(false)
	voice_toggle.set_block_signals(false)
	voice_slider.set_block_signals(false)
	overlay.gui_input.connect(_on_overlay_gui_input)
	ThemeManager.theme_changed.connect(_apply_theme)
	_apply_theme(ThemeManager.is_dark_mode)


# Syncs all controls from AudioManager and shows the panel.
# Called by escape_room.gd when the settings button is pressed.
func open() -> void:
	_sync_from_audio_manager()
	show()


# Hides the panel without saving — changes are applied immediately as they are made.
func close() -> void:
	hide()


# Applies the current ThemeManager palette colors to the panel, labels, and separator.
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
	voice_label.add_theme_color_override("font_color", p["text_content"])
	sep.modulate = Color(p["panel_border"].r, p["panel_border"].g, p["panel_border"].b, 0.6)


# Reads the current AudioManager state and sets all controls to match.
# Signals are blocked during sync to prevent the value-changed handlers from
# firing and writing back to AudioManager while reading from it.
func _sync_from_audio_manager() -> void:
	music_toggle.set_block_signals(true)
	music_slider.set_block_signals(true)
	sfx_toggle.set_block_signals(true)
	sfx_slider.set_block_signals(true)
	voice_toggle.set_block_signals(true)
	voice_slider.set_block_signals(true)

	# Invert muted: toggle pressed = sound ON (not muted).
	music_toggle.button_pressed = not AudioManager.music_muted
	music_slider.value = AudioManager.music_volume
	sfx_toggle.button_pressed = not AudioManager.sfx_muted
	sfx_slider.value = AudioManager.sfx_volume
	voice_toggle.button_pressed = AudioManager.tts_enabled
	voice_slider.value = AudioManager.tts_volume

	music_toggle.set_block_signals(false)
	music_slider.set_block_signals(false)
	sfx_toggle.set_block_signals(false)
	sfx_slider.set_block_signals(false)
	voice_toggle.set_block_signals(false)
	voice_slider.set_block_signals(false)


# Closes the panel when the X button is pressed.
func _on_close_button_pressed() -> void:
	close()


# Updates the Music bus mute state. pressed = true means sound is ON (not muted).
func _on_music_toggle_toggled(pressed: bool) -> void:
	AudioManager.set_music_muted(not pressed)


# Updates the Music bus volume immediately as the slider moves.
func _on_music_slider_value_changed(value: float) -> void:
	AudioManager.set_music_volume(value)


# Updates the SFX bus mute state. pressed = true means sound is ON (not muted).
func _on_sfx_toggle_toggled(pressed: bool) -> void:
	AudioManager.set_sfx_muted(not pressed)


# Updates the SFX bus volume immediately as the slider moves.
func _on_sfx_slider_value_changed(value: float) -> void:
	AudioManager.set_sfx_volume(value)


# Enables or disables the professor TTS voice. pressed = true means voice is ON.
func _on_voice_toggle_toggled(pressed: bool) -> void:
	AudioManager.set_tts_enabled(pressed)


# Updates the TTS voice volume immediately as the slider moves.
func _on_voice_slider_value_changed(value: float) -> void:
	AudioManager.set_tts_volume(value)


# Closes the panel when the player clicks on the darkened overlay outside the panel.
func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not panel.get_global_rect().has_point(event.global_position):
			close()
