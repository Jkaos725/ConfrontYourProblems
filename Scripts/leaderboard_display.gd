extends CanvasLayer

@onready var overlay:      ColorRect     = $Overlay
@onready var panel:        PanelContainer = $Overlay/Center/Panel
@onready var title_lbl:    Label          = $Overlay/Center/Panel/Margin/VBox/TitleRow/Title
@onready var close_btn:    Button         = $Overlay/Center/Panel/Margin/VBox/TitleRow/CloseButton
@onready var sep:          HSeparator     = $Overlay/Center/Panel/Margin/VBox/Sep
@onready var search_label: Label          = $Overlay/Center/Panel/Margin/VBox/SearchRow/SearchLabel
@onready var tabs:         TabContainer   = $Overlay/Center/Panel/Margin/VBox/Tabs
@onready var score_list:   VBoxContainer  = $Overlay/Center/Panel/Margin/VBox/Tabs/HighScores/ScoreList
@onready var time_list:    VBoxContainer  = $Overlay/Center/Panel/Margin/VBox/Tabs/FastestTimes/TimeList
@onready var search_edit:  LineEdit       = $Overlay/Center/Panel/Margin/VBox/SearchRow/SearchEdit
@onready var filter_row:   HBoxContainer  = $Overlay/Center/Panel/Margin/VBox/FilterScroll/FilterRow

var _active_filter: String = ""  # "" = All subjects


func _ready() -> void:
	hide()
	tabs.set_tab_title(0, "High Scores")
	tabs.set_tab_title(1, "Fastest Times")
	overlay.gui_input.connect(_on_overlay_gui_input)
	search_edit.text_changed.connect(_on_search_changed)
	ThemeManager.theme_changed.connect(_apply_theme)
	_apply_theme(ThemeManager.is_dark_mode)


func open() -> void:
	_active_filter = ""
	search_edit.text = ""
	_build_filter_buttons()
	_populate()
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
	search_label.add_theme_color_override("font_color", p["text_content"])
	sep.modulate = Color(p["panel_border"].r, p["panel_border"].g, p["panel_border"].b, 0.6)


# ── Filter buttons ─────────────────────────────────────────────────────────────

func _build_filter_buttons() -> void:
	for child in filter_row.get_children():
		filter_row.remove_child(child)
		child.free()

	# Collect unique subjects across both boards
	var subjects: Array[String] = []
	var all_entries: Array = []
	all_entries.append_array(LeaderboardManager.get_high_scores())
	all_entries.append_array(LeaderboardManager.get_fastest_times())
	for entry in all_entries:
		var subject: String = str(entry.get("subject", "")).strip_edges()
		if not subject.is_empty() and not subjects.has(subject):
			subjects.append(subject)
	subjects.sort()

	var group := ButtonGroup.new()
	_add_filter_btn("All", "", group)
	for subject in subjects:
		_add_filter_btn(subject, subject, group)


func _add_filter_btn(label: String, filter_value: String, group: ButtonGroup) -> void:
	var btn := Button.new()
	btn.text = label
	btn.toggle_mode = true
	btn.button_group = group
	btn.button_pressed = (_active_filter == filter_value)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(func() -> void: _set_filter(filter_value))
	filter_row.add_child(btn)


func _set_filter(subject: String) -> void:
	_active_filter = subject
	_populate()


func _on_search_changed(_text: String) -> void:
	_populate()


# ── Populate ──────────────────────────────────────────────────────────────────

func _populate() -> void:
	_clear_list(score_list)
	_clear_list(time_list)

	var scores := _get_filtered(LeaderboardManager.get_high_scores())
	if scores.is_empty():
		score_list.add_child(_make_empty_label("No matching scores."))
	else:
		for i in scores.size():
			score_list.add_child(_make_row(i + 1, scores[i], false))

	var times := _get_filtered(LeaderboardManager.get_fastest_times())
	if times.is_empty():
		time_list.add_child(_make_empty_label("No matching times."))
	else:
		for i in times.size():
			time_list.add_child(_make_row(i + 1, times[i], true))


func _get_filtered(entries: Array) -> Array:
	var search := search_edit.text.strip_edges().to_lower()
	var result: Array = []
	for entry in entries:
		if not _active_filter.is_empty():
			if str(entry.get("subject", "")) != _active_filter:
				continue
		if not search.is_empty():
			var name_match  := str(entry.get("name",      "")).to_lower().contains(search)
			var quiz_match  := str(entry.get("quiz_name", "")).to_lower().contains(search)
			if not name_match and not quiz_match:
				continue
		result.append(entry)
	return result


func _clear_list(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


# ── Row builder ───────────────────────────────────────────────────────────────

func _make_row(rank: int, entry: Dictionary, time_primary: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)

	var rank_lbl  := _col("#%d" % rank,                              56,  Color(0.698, 0.521, 0.278, 1))
	var name_lbl  := _col(str(entry.get("name", "?")),               160, Color(0.988, 0.933, 0.784, 1))
	var score_lbl := _col("%d/%d" % [entry.get("score", 0), entry.get("total", 0)], 72, Color(0.878, 0.894, 0.925, 1))
	var time_lbl  := _col(_fmt_time(entry.get("time_seconds", 0)),   80,
		Color(0.658, 0.788, 0.972, 1) if time_primary else Color(0.878, 0.894, 0.925, 1))
	var hint_lbl  := _col("%d hint%s" % [entry.get("hints_used", 0),
		"s" if entry.get("hints_used", 0) != 1 else ""],             84,  Color(0.85, 0.71, 0.50, 1))
	var quiz_lbl  := _col(_truncate(str(entry.get("quiz_name", "")), 22), 180, Color(0.878, 0.894, 0.925, 1))
	var date_lbl  := _col(str(entry.get("date", "")),                100, Color(0.55,  0.55,  0.55,  1))

	for lbl in [rank_lbl, name_lbl, score_lbl, time_lbl, hint_lbl, quiz_lbl, date_lbl]:
		row.add_child(lbl)
	return row


func _col(text: String, min_width: int, color: Color) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(min_width, 0)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl


func _make_empty_label(msg: String) -> Label:
	var lbl := Label.new()
	lbl.text = msg
	lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6, 1))
	lbl.add_theme_font_size_override("font_size", 15)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return lbl


func _fmt_time(seconds: int) -> String:
	return "%d:%02d" % [seconds / 60, seconds % 60]


func _truncate(text: String, max_len: int) -> String:
	if text.length() <= max_len:
		return text
	return text.substr(0, max_len - 1) + "…"


func _on_close_button_pressed() -> void:
	close()


func _on_overlay_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel: Control = $Overlay/Center/Panel
		if not panel.get_global_rect().has_point(event.global_position):
			close()
