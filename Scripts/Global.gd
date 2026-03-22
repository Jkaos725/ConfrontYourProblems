# Global.gd
# Autoload singleton — registered as "Global" in Project Settings.
# Holds all cross-scene state for a quiz session so that data survives
# scene transitions (e.g. from the lobby to a room and back).
#
# Two categories of data live here:
#   Session state  — values that change during an active quiz (index, score, lives, time).
#   Config state   — values set by the player before the quiz starts (professor, question count, etc.).
#
# Helper methods reset/clear session state at the appropriate moments.
extends Node

# Remaining seconds in the current quiz session timer.
# Decremented each second by the active room script.
var globalTime = 180

# Legacy timer node — kept for group membership but the countdown is driven
# by the room scripts' CountdownTimer nodes, not this timer.
var timer = Timer.new()

# The ordered list of room dictionaries for the active quiz session.
# Populated by escape_room.gd before launching into the room scenes.
var rooms: Array[Dictionary] = []

# Index of the room currently being played within the rooms array.
var index = 0

# Number of questions answered correctly in the current session.
var score = 0

# Remaining lives (wrong-answer attempts) for the current session.
var lives = 3

# Lives setting chosen by the player on the setup screen (default 3).
var selected_lives = 3

# Number of questions the player chose to include in this session (default 4).
var selected_question_count = 4

# Time (in seconds) the player chose for the hint/countdown timer (default 180).
var selected_hint_time = 180

# Total number of AI hint buttons used across all rooms in the current session.
var hints_used = 0

# The subject ID of the active quiz (e.g. "cs", "math"). Empty for uploaded quizzes.
var active_subject = ""

# The display name of the active quiz set (e.g. "CS Quiz 1" or the uploaded file name).
var active_quiz_name = ""

# The name of the professor selected by the player before the quiz (e.g. "Professor Vex").
var selected_professor = "Professor Vex"

# Score from the most recently completed quiz — used to display results on the main screen.
var last_quiz_score = 0

# Total questions from the most recently completed quiz.
var last_quiz_total = 0

# Quiz name from the most recently completed quiz.
var last_quiz_name = ""

# Result string from the most recently completed quiz (e.g. "victory" or "defeat").
var last_result = ""

# Time in seconds taken to complete the most recently finished quiz.
var last_quiz_time_seconds: int = 0

# Timestamp (in milliseconds) when the current quiz session started.
# Used to calculate last_quiz_time_seconds at session end.
var session_start_time: float = 0.0


# Resets only the mid-session counters (index, score, lives, hints, timer).
# Called at the start of a new quiz run while keeping the player's configuration choices.
func reset_quiz_session() -> void:
	index = 0
	score = 0
	lives = selected_lives
	hints_used = 0
	globalTime = selected_hint_time
	session_start_time = Time.get_ticks_msec()


# Clears the room list and subject info, then calls reset_quiz_session().
# Called when fully exiting a quiz (e.g. pressing Exit or returning to the main menu).
func clear_quiz_session() -> void:
	rooms.clear()
	active_subject = ""
	active_quiz_name = ""
	reset_quiz_session()


# Captures the final score, total, name, result, and elapsed time from the just-finished session.
# Called by server_vault_room.gd when all rooms have been cleared.
# result: "victory" or another result string used by the main screen to show the outcome.
func store_quiz_result(result: String) -> void:
	last_quiz_score = score
	last_quiz_total = max(rooms.size(), 0)
	last_quiz_name = active_quiz_name
	last_result = result
	last_quiz_time_seconds = int((Time.get_ticks_msec() - session_start_time) / 1000.0)


# Initializes the legacy global timer node and adds it to the GlobalTimer group.
# The timer is started but its timeout signal is not connected here — the countdown
# is handled per-room instead.
func _ready():
	add_child(timer)
	timer.add_to_group("GlobalTimer")
	timer.start(1)
	# timer.connect("timeout", self, "on_global_timer_timeout")  # legacy — not used
