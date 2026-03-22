extends CanvasLayer

@onready var overlay: ColorRect = $Overlay
@onready var music_toggle: CheckButton = $Overlay/Center/Panel/Margin/VBox/MusicRow/MusicToggle
@onready var music_slider: HSlider = $Overlay/Center/Panel/Margin/VBox/MusicRow/MusicSlider
@onready var sfx_toggle: CheckButton = $Overlay/Center/Panel/Margin/VBox/SFXRow/SFXToggle
@onready var sfx_slider: HSlider = $Overlay/Center/Panel/Margin/VBox/SFXRow/SFXSlider


func _ready() -> void:
	music_toggle.set_block_signals(true)
	music_slider.set_block_signals(true)
	sfx_toggle.set_block_signals(true)
	sfx_slider.set_block_signals(true)
	hide()
	music_toggle.set_block_signals(false)
	music_slider.set_block_signals(false)
	sfx_toggle.set_block_signals(false)
	sfx_slider.set_block_signals(false)
	overlay.gui_input.connect(_on_overlay_gui_input)


func open() -> void:
	_sync_from_audio_manager()
	show()


func close() -> void:
	hide()


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
		var panel: Control = $Overlay/Center/Panel
		if not panel.get_global_rect().has_point(event.global_position):
			close()
