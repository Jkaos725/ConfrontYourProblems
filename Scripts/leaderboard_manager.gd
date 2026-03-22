extends Node

# ── Storage paths ──────────────────────────────────────────────────────────────
const SAVE_PATH    := "user://leaderboard.json"
const DEFAULT_PATH := "res://stats/default_scores.json"

# ── State ──────────────────────────────────────────────────────────────────────
var max_entries: int = 10
var high_scores:    Array[Dictionary] = []
var fastest_times:  Array[Dictionary] = []


func _ready() -> void:
	_load()


# ── Public queries ─────────────────────────────────────────────────────────────

## Returns true if this score/time would place on the high-score board.
func is_high_score(score: int, total: int, time_seconds: int) -> bool:
	if high_scores.size() < max_entries:
		return true
	var last: Dictionary = high_scores.back()
	if score > last["score"]:
		return true
	if score == last["score"] and time_seconds < last["time_seconds"]:
		return true
	return false


## Returns true if this is a complete run that would place on the fastest board.
func is_fastest_time(score: int, total: int, time_seconds: int) -> bool:
	if score != total:
		return false
	if fastest_times.size() < max_entries:
		return true
	return time_seconds < fastest_times.back()["time_seconds"]


# ── Submit ─────────────────────────────────────────────────────────────────────

func submit(
	player_name:  String,
	score:        int,
	total:        int,
	quiz_name:    String,
	subject:      String,
	time_seconds: int,
	hints_used:   int
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

	# High scores – sorted by score DESC, then time ASC as tiebreaker
	high_scores.append(entry)
	high_scores.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["time_seconds"] < b["time_seconds"]
	)
	if high_scores.size() > max_entries:
		high_scores.resize(max_entries)

	# Fastest times – complete runs only, sorted by time ASC
	if score == total:
		fastest_times.append(entry)
		fastest_times.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return a["time_seconds"] < b["time_seconds"]
		)
		if fastest_times.size() > max_entries:
			fastest_times.resize(max_entries)

	_save()


# ── Getters ────────────────────────────────────────────────────────────────────

func get_high_scores() -> Array:
	return high_scores

func get_fastest_times() -> Array:
	return fastest_times


# ── Reset ──────────────────────────────────────────────────────────────────────

## Wipes saved scores and re-seeds from default_scores.json.
func reset_to_defaults() -> void:
	high_scores.clear()
	fastest_times.clear()
	_seed_from_defaults()
	_save()


# ── Persistence ────────────────────────────────────────────────────────────────

func _save() -> void:
	var data := {
		"high_scores":   high_scores,
		"fastest_times": fastest_times
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


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

	# No save file yet – check if we should seed defaults
	_load_defaults_config()


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

	# Trim to configured limit
	if high_scores.size() > max_entries:
		high_scores.resize(max_entries)
	if fastest_times.size() > max_entries:
		fastest_times.resize(max_entries)

	_save()


func _to_dict_array(raw: Variant) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if raw is Array:
		for item in raw:
			if item is Dictionary:
				out.append(item)
	return out
