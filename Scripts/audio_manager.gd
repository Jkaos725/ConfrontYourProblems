extends Node

const SAVE_PATH := "user://audio_settings.cfg"
const MUSIC_BUS := "Music"
const SFX_BUS := "SFX"

var music_volume: float = 1.0
var sfx_volume: float = 1.0
var music_muted: bool = false
var sfx_muted: bool = false


func _ready() -> void:
	_ensure_buses()
	_load_settings()
	_apply_settings()


func _ensure_buses() -> void:
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		AudioServer.add_bus()
		var music_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_idx, MUSIC_BUS)
		AudioServer.set_bus_send(music_idx, "Master")
	if AudioServer.get_bus_index(SFX_BUS) == -1:
		AudioServer.add_bus()
		var sfx_idx := AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_idx, SFX_BUS)
		AudioServer.set_bus_send(sfx_idx, "Master")


func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_settings()
	_save_settings()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_settings()
	_save_settings()


func set_music_muted(muted: bool) -> void:
	music_muted = muted
	_apply_settings()
	_save_settings()


func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	_apply_settings()
	_save_settings()


func _apply_settings() -> void:
	var music_idx := AudioServer.get_bus_index(MUSIC_BUS)
	if music_idx != -1:
		AudioServer.set_bus_mute(music_idx, music_muted)
		var music_db := linear_to_db(music_volume) if music_volume > 0.0 else -80.0
		AudioServer.set_bus_volume_db(music_idx, music_db)

	var sfx_idx := AudioServer.get_bus_index(SFX_BUS)
	if sfx_idx != -1:
		AudioServer.set_bus_mute(sfx_idx, sfx_muted)
		var sfx_db := linear_to_db(sfx_volume) if sfx_volume > 0.0 else -80.0
		AudioServer.set_bus_volume_db(sfx_idx, sfx_db)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_muted", music_muted)
	config.set_value("audio", "sfx_muted", sfx_muted)
	config.save(SAVE_PATH)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		music_volume = float(config.get_value("audio", "music_volume", 1.0))
		sfx_volume = float(config.get_value("audio", "sfx_volume", 1.0))
		music_muted = bool(config.get_value("audio", "music_muted", false))
		sfx_muted = bool(config.get_value("audio", "sfx_muted", false))
