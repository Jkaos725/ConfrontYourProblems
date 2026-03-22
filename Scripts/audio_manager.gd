# audio_manager.gd
# Autoload singleton — registered as "AudioManager" in Project Settings.
# Manages three audio buses: Music, SFX, and the TTS (text-to-speech) volume/enabled flag.
# Volume levels are stored as 0.0–1.0 floats and converted to dB when applied to the bus.
# All settings are persisted to user://audio_settings.cfg so they survive between sessions.
#
# Music bus  — background music streams.
# SFX bus    — one-shot sound effects (correct/wrong/transition sounds).
# TTS        — professor voice using Godot's built-in DisplayServer TTS API.
extends Node

# Path where audio settings are saved between sessions.
const SAVE_PATH := "user://audio_settings.cfg"

# Name of the Music audio bus in the Godot Audio panel.
const MUSIC_BUS := "Music"

# Name of the SFX audio bus in the Godot Audio panel.
const SFX_BUS := "SFX"

# Music volume as a linear 0.0–1.0 value. Converted to dB internally.
var music_volume: float = 1.0

# SFX volume as a linear 0.0–1.0 value. Converted to dB internally.
var sfx_volume: float = 1.0

# Whether the Music bus is muted. Muting is separate from volume so the
# slider position is preserved when the player unmutes.
var music_muted: bool = false

# Whether the SFX bus is muted.
var sfx_muted: bool = false

# Whether the professor TTS voice is enabled. When false, _tts_speak() is a no-op.
var tts_enabled: bool = true

# TTS volume as a linear 0.0–1.0 value.
# Multiplied by 100 and passed as an int to DisplayServer.tts_speak().
var tts_volume: float = 1.0


# Ensures both audio buses exist, loads saved settings, and applies them.
func _ready() -> void:
	_ensure_buses()
	_load_settings()
	_apply_settings()


# Checks whether the Music and SFX buses exist in the Audio panel.
# If either is missing it creates it and sets its send target to "Master".
# This guards against the project being opened on a machine without the saved audio layout.
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


# Sets the Music bus volume (0.0–1.0), applies it to the bus, and saves.
func set_music_volume(value: float) -> void:
	music_volume = clampf(value, 0.0, 1.0)
	_apply_settings()
	_save_settings()


# Sets the SFX bus volume (0.0–1.0), applies it to the bus, and saves.
func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_settings()
	_save_settings()


# Mutes or unmutes the Music bus and saves.
func set_music_muted(muted: bool) -> void:
	music_muted = muted
	_apply_settings()
	_save_settings()


# Mutes or unmutes the SFX bus and saves.
func set_sfx_muted(muted: bool) -> void:
	sfx_muted = muted
	_apply_settings()
	_save_settings()


# Enables or disables the TTS professor voice and saves.
# When disabled, all _tts_speak() calls in room scripts are skipped.
func set_tts_enabled(enabled: bool) -> void:
	tts_enabled = enabled
	_save_settings()


# Sets the TTS volume (0.0–1.0) and saves.
# Room scripts multiply this by 100 when calling DisplayServer.tts_speak().
func set_tts_volume(value: float) -> void:
	tts_volume = clampf(value, 0.0, 1.0)
	_save_settings()


# Applies the current volume/mute values to the Music and SFX audio buses.
# Volume of 0.0 is mapped to -80 dB (effectively silent) to avoid log(0) errors.
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


# Writes all audio and TTS settings to user://audio_settings.cfg.
func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "music_volume", music_volume)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "music_muted", music_muted)
	config.set_value("audio", "sfx_muted", sfx_muted)
	config.set_value("audio", "tts_enabled", tts_enabled)
	config.set_value("audio", "tts_volume", tts_volume)
	config.save(SAVE_PATH)


# Reads saved settings from user://audio_settings.cfg.
# Falls back to sensible defaults if the file does not exist yet.
func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) == OK:
		music_volume = float(config.get_value("audio", "music_volume", 1.0))
		sfx_volume = float(config.get_value("audio", "sfx_volume", 1.0))
		music_muted = bool(config.get_value("audio", "music_muted", false))
		sfx_muted = bool(config.get_value("audio", "sfx_muted", false))
		tts_enabled = bool(config.get_value("audio", "tts_enabled", true))
		tts_volume = float(config.get_value("audio", "tts_volume", 1.0))
