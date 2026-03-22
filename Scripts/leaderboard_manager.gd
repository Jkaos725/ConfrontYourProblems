# leaderboard_manager.gd
# Autoload singleton — registered as "LeaderboardManager" in Project Settings.
# Stores, sorts, and persists two leaderboards:
#   high_scores   — all quiz runs, sorted by score DESC then time ASC.
#   fastest_times — only complete runs (score == total), sorted by time ASC.
#
# Per-name deduplication: each player name keeps only their best result on each board.
# A new submission replaces an existing entry only if it is strictly better.
#
# Data is persisted to user://leaderboard.json.
# On first launch, default scores are seeded from res://stats/default_scores.json
# if that file is present and configured to seed on first run.
extends Node

# Path where leaderboard data is saved between sessions.
const SAVE_PATH    := "user://leaderboard.json"

# Optional path for default/seed scores bundled with the game.
const DEFAULT_PATH := "res://stats/default_scores.json"

# Maximum number of entries shown on each board.
var max_entries: int = 10

# Array of high-score entry dictionaries, sorted by score DESC / time ASC.
var high_scores:    Array[Dictionary] = []

# Array of fastest-time entry dictionaries (complete runs only), sorted by time ASC.
var fastest_times:  Array[Dictionary] = []


# Loads saved leaderboard data (or seeds from defaults if no save exists) on startup.
func _ready() -> void:
	_load()


# ── Public queries ─────────────────────────────────────────────────────────────

# Returns true if this score would earn a place on the high-score board.
# Checks whether the board has room or whether the score beats the last entry.
func is_high_score(score: int, total: int, time_seconds: int) -> bool:
	if high_scores.size() < max_entries:
		return true
	var last: Dictionary = high_scores.back()
	if score > last["score"]:
		return true
	if score == last["score"] and time_seconds < last["time_seconds"]:
		return true
	return false


# Returns true if this is a perfect run (score == total) that would place on
# the fastest-times board. Only complete runs qualify.
func is_fastest_time(score: int, total: int, time_seconds: int) -> bool:
	if score != total:
		return false
	if fastest_times.size() < max_entries:
		return true
	return time_seconds < fastest_times.back()["time_seconds"]


# ── Submit ─────────────────────────────────────────────────────────────────────

# Records a completed quiz session on both boards.
# Per-name rule: if the player's name already appears on a board, the entry is only
# replaced if the new result is strictly better (higher score, or faster time at the same score).
# After updating, each board is re-sorted and trimmed to max_entries.
func submit(
	player_name:  String,  # Display name entered by the player.
	score:        int,     # Number of correct answers.
	total:        int,     # Total number of questions in the session.
	quiz_name:    String,  # Display name of the quiz set.
	subject:      String,  # Subject category (e.g. "cs", "math").
	time_seconds: int,     # Total elapsed time in seconds.
	hints_used:   int      # Number of AI hints the player used.
) -> void:
	var entry := {
		"name":         player_name,
		"score":        score,
		"total":        total,
		"quiz_name":    quiz_name,
		"subject":      subject,
		"time_seconds": time_seconds,
		"hints_used":   hints_used,
		"date":         Time.get_date_string_from_system()
	}

	# High scores – keep best entry per name (score DESC, time ASC tiebreaker).
	var hs_idx := _find_entry_index(high_scores, player_name)
	if hs_idx != -1:
		var existing: Dictionary = high_scores[hs_idx]
		var new_is_better: bool = entry["score"] > int(existing["score"]) or \
			(entry["score"] == int(existing["score"]) and entry["time_seconds"] < int(existing["time_seconds"]))
		if new_is_better:
			# Remove the old entry so the new one can be appended and re-sorted.
			high_scores.remove_at(hs_idx)
			high_scores.append(entry)
		# else: existing result is better — leave the board unchanged.
	else:
		high_scores.append(entry)
	high_scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["time_seconds"] < b["time_seconds"]
	)
	if high_scores.size() > max_entries:
		high_scores.resize(max_entries)

	# Fastest times – complete runs only, keep best time per name.
	if score == total:
		var ft_idx := _find_entry_index(fastest_times, player_name)
		if ft_idx != -1:
			if entry["time_seconds"] < int(fastest_times[ft_idx]["time_seconds"]):
				# New time is faster — replace the existing entry.
				fastest_times.remove_at(ft_idx)
				fastest_times.append(entry)
			# else: existing time is faster — leave the board unchanged.
		else:
			fastest_times.append(entry)
		fastest_times.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["time_seconds"] < b["time_seconds"]
		)
		if fastest_times.size() > max_entries:
			fastest_times.resize(max_entries)

	_save()


# ── Getters ────────────────────────────────────────────────────────────────────

# Returns the sorted high-scores array. Used by leaderboard_display.gd to populate the UI.
func get_high_scores() -> Array:
	return high_scores


# Returns the sorted fastest-times array. Used by leaderboard_display.gd to populate the UI.
func get_fastest_times() -> Array:
	return fastest_times


# ── Reset ──────────────────────────────────────────────────────────────────────

# Clears both boards, re-seeds from the default scores file, and saves.
# Useful for resetting to the bundled example data during development.
func reset_to_defaults() -> void:
	high_scores.clear()
	fastest_times.clear()
	_seed_from_defaults()
	_save()


# ── Persistence ────────────────────────────────────────────────────────────────

# Writes both boards to user://leaderboard.json as formatted JSON.
func _save() -> void:
	var data := {
		"high_scores":   high_scores,
		"fastest_times": fastest_times
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


# Loads both boards from user://leaderboard.json.
# Falls back to seeding from the bundled default scores if no save file exists.
func _load() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			var text   := file.get_as_text()
			file.close()
			var result: Variant = JSON.parse_string(text)
			if result is Dictionary:
				high_scores   = _to_dict_array(result.get("high_scores",   []))
				fastest_times = _to_dict_array(result.get("fastest_times", []))
				return

	# No save file yet — check if defaults should be seeded.
	_load_defaults_config()


# Reads the config block from default_scores.json to determine max_entries
# and whether the data should be seeded on first run.
func _load_defaults_config() -> void:
	if not ResourceLoader.exists(DEFAULT_PATH):
		return
	var file := FileAccess.open(DEFAULT_PATH, FileAccess.READ)
	if not file:
		return
	var result: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not result is Dictionary:
		return

	var cfg: Dictionary = result.get("config", {})
	max_entries = int(cfg.get("max_entries", 10))

	if bool(cfg.get("seed_on_first_run", true)):
		_seed_from_defaults()


# Parses both boards from default_scores.json and saves them as the starting leaderboard.
# Called once on first launch if the config enables seeding.
func _seed_from_defaults() -> void:
	if not ResourceLoader.exists(DEFAULT_PATH):
		return
	var file := FileAccess.open(DEFAULT_PATH, FileAccess.READ)
	if not file:
		return
	var result: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not result is Dictionary:
		return

	var cfg: Dictionary = result.get("config", {})
	max_entries = int(cfg.get("max_entries", 10))

	high_scores   = _to_dict_array(result.get("high_scores",   []))
	fastest_times = _to_dict_array(result.get("fastest_times", []))

	if high_scores.size() > max_entries:
		high_scores.resize(max_entries)
	if fastest_times.size() > max_entries:
		fastest_times.resize(max_entries)

	_save()


# ── Helpers ────────────────────────────────────────────────────────────────────

# Searches an entry array for the first entry whose "name" matches player_name.
# Returns the index if found, or -1 if no match exists.
# Used by submit() to enforce the one-entry-per-name deduplication rule.
func _find_entry_index(arr: Array[Dictionary], player_name: String) -> int:
	for i in arr.size():
		if str(arr[i].get("name", "")) == player_name:
			return i
	return -1


# Converts a raw Variant array (from JSON) to a typed Array[Dictionary],
# silently skipping any elements that are not Dictionary instances.
func _to_dict_array(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				out.append(item)
	return out
