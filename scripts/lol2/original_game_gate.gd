extends Control

const Check = preload("res://scripts/lol2/original_game_check.gd")
const MuseumSave = preload("res://scripts/lol2/museum_save.gd")
const HiveSave = preload("res://scripts/lol2/hive_save.gd")
const JungleSave = preload("res://scripts/lol2/jungle_save.gd")
const Darker = preload("res://scripts/lol2/darker_jungle.gd")
const Act2Map = preload("res://scripts/lol2/act2_map.gd")
const Dragon = preload("res://scripts/lol2/dragon_level.gd")
const DarkHalls = preload("res://scripts/lol2/dark_halls.gd")
const Starts = preload("res://scripts/lol2/playtest_starts.gd")
const UiScale = preload("res://scripts/lol2/ui_scale.gd")
const STARTS_KEY := KEY_F2
const SETTINGS := "user://original_game.cfg"
var settings_path := SETTINGS
var museum_save_path := MuseumSave.DEFAULT_PATH
var jungle_save_path := JungleSave.DEFAULT_PATH
var hive_save_path := HiveSave.DEFAULT_PATH
var darker_save_path := Darker.DEFAULT_PATH
var dark_halls_save_path := DarkHalls.DEFAULT_PATH
var path_field: LineEdit
var status: Label
var picker: FileDialog
## Playtest starts list (docs/playtest-starts.md): built on first open; null until then.
var starts_panel: Control
var starts_status: Label

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().set_meta("original_game_verified", false)
	var background := ColorRect.new()
	background.color = Color("17202b")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 620
	column.add_theme_constant_override("separation", 18)
	center.add_child(column)
	var title := Label.new()
	title.text = "Lands of Lore II — Original game required"
	title.add_theme_font_size_override("font_size", 26)
	column.add_child(title)
	var description := Label.new()
	description.text = "Select LOLG.EXE from your installed copy of Lands of Lore II.\nCurrently supported: the verified GOG executable.\nThe file is checked locally each time you launch; it is never uploaded or run."
	column.add_child(description)
	path_field = LineEdit.new()
	path_field.placeholder_text = "Path to LOLG.EXE"
	path_field.text_submitted.connect(func(_text: String): _verify_and_start())
	column.add_child(path_field)
	# Own row above the start/resume row (that row already runs past a 1280-wide window with the map previews).
	if not Starts.manifest().entries.is_empty():
		var starts := Button.new()
		starts.name = "PlaytestStarts"
		starts.text = "Playtest starts (F2)"
		starts.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		# Out of the Tab order: keyboard users and the packaged smoke keep the original path -> Browse -> Verify -> Resume order;
		# mouse and F2 still open the list.
		starts.focus_mode = Control.FOCUS_NONE
		starts.pressed.connect(show_playtest_starts)
		column.add_child(starts)
	var buttons := HBoxContainer.new()
	column.add_child(buttons)
	var browse := Button.new()
	browse.text = "Browse…"
	browse.pressed.connect(func(): picker.popup_centered_ratio(0.8))
	buttons.add_child(browse)
	var start := Button.new()
	start.text = "Verify and start cavern"
	start.pressed.connect(_verify_and_start)
	buttons.add_child(start)
	if FileAccess.file_exists(museum_save_path):
		var resume := Button.new()
		resume.text = "Resume museum"
		resume.pressed.connect(_verify_and_start.bind(true))
		buttons.add_child(resume)
	if FileAccess.file_exists(jungle_save_path):
		var resume := Button.new()
		resume.text = "Resume jungle"
		resume.pressed.connect(_verify_and_start.bind(false, true))
		buttons.add_child(resume)
	if FileAccess.file_exists(hive_save_path):
		var resume := Button.new()
		resume.text = "Resume Hive"
		resume.pressed.connect(_verify_and_start.bind(false, false, true))
		buttons.add_child(resume)
	if FileAccess.file_exists(darker_save_path):
		var resume := Button.new()
		resume.text = "Resume darker jungle"
		resume.pressed.connect(_verify_and_start.bind(false,false,false,true))
		buttons.add_child(resume)
	if FileAccess.file_exists(dark_halls_save_path):
		var resume := Button.new()
		resume.text = "Resume Dark Halls"
		resume.pressed.connect(_verify_and_start.bind(false,false,false,false,true))
		buttons.add_child(resume)
	if Darker.arrival_assets_ready():
		var preview := Button.new()
		preview.name = "L8Preview"
		preview.text = "Preview: Act 2 start"
		preview.pressed.connect(_verify_and_start.bind(false,false,false,false,false,true))
		buttons.add_child(preview)
	if Dragon.arrival_assets_ready():
		var dragon_preview := Button.new()
		dragon_preview.name = "L9Preview"
		dragon_preview.text = "Preview: dragon level (L9_DR)"
		dragon_preview.pressed.connect(_verify_and_start.bind(false,false,false,false,false,false,"",true))
		buttons.add_child(dragon_preview)
	# Act 2/3 map packs (scripts/lol2/act2_maps.json, act2_map.gd): one test-start button per staged map, both editions.
	for entry in Act2Map.registry():
		var map_button := Button.new()
		map_button.name = "MapPreview_" + str(entry.area)
		map_button.text = str(entry.label)
		map_button.pressed.connect(_verify_and_start.bind(false,false,false,false,false,false,str(entry.scene)))
		buttons.add_child(map_button)
	var quit := Button.new()
	quit.text = "Quit"
	quit.pressed.connect(func(): get_tree().quit())
	buttons.add_child(quit)
	status = Label.new()
	status.custom_minimum_size = Vector2(620, 70)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(status)
	picker = FileDialog.new()
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.title = "Select original Lands of Lore II executable"
	picker.add_filter("*.exe, *.EXE", "Game executable")
	picker.file_selected.connect(func(path: String):
		path_field.text = path
		_verify_and_start())
	add_child(picker)
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		path_field.text = str(config.get_value("original_game", "exe_path", ""))
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--original-game-exe="):
			path_field.text = argument.trim_prefix("--original-game-exe=")
	if "--l8-preview" in OS.get_cmdline_user_args() and not path_field.text.is_empty():
		_verify_and_start.bind(false, false, false, false, false, true).call_deferred()
		return
	if "--l9-preview" in OS.get_cmdline_user_args() and not path_field.text.is_empty():
		_verify_and_start.bind(false, false, false, false, false, false, "", true).call_deferred()
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--playtest-start=") and not path_field.text.is_empty():
			start_playtest.bind(argument.trim_prefix("--playtest-start=")).call_deferred()
			return
	if "--playtest-starts" in OS.get_cmdline_user_args():
		show_playtest_starts.call_deferred()  # opens the list instead of the automatic new-game start below
		return
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--map-preview=") and not path_field.text.is_empty():
			for entry in Act2Map.registry():
				if str(entry.area) == argument.trim_prefix("--map-preview="):
					_verify_and_start.bind(false, false, false, false, false, false, str(entry.scene)).call_deferred()
					return
	if not path_field.text.is_empty() and not FileAccess.file_exists(museum_save_path) and not FileAccess.file_exists(jungle_save_path) and not FileAccess.file_exists(hive_save_path) and not FileAccess.file_exists(darker_save_path) and not FileAccess.file_exists(dark_halls_save_path):
		_verify_and_start.call_deferred()

## Playtest starts (docs/playtest-starts.md): F2 or the button opens a plain list of story checkpoints. Each is a real
## earned save from the automated campaign (scripts/lol2/playtest_starts.json), staged read-only under res://.
func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	var open := starts_panel != null and starts_panel.visible
	if event.keycode == STARTS_KEY or (open and event.keycode == KEY_ESCAPE):
		if open: starts_panel.hide()
		else: show_playtest_starts()
		get_viewport().set_input_as_handled()

func show_playtest_starts() -> void:
	if starts_panel == null: _build_playtest_starts()
	starts_panel.show()
	var first := starts_panel.find_child("Start_*", true, false) as Button
	if first != null: first.grab_focus()

func _build_playtest_starts() -> void:
	var listed := Starts.manifest()
	starts_panel = PanelContainer.new()
	starts_panel.name = "PlaytestStartsPanel"
	starts_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("17202b")
	style.content_margin_left = 40; style.content_margin_right = 40; style.content_margin_top = 24; style.content_margin_bottom = 24
	starts_panel.add_theme_stylebox_override("panel", style)
	# Plain list at the player's UI size (ui_scale.gd; 150% by default), relative to a 720-high window.
	var font := int(round(16 * UiScale.factor()))
	starts_panel.add_theme_font_size_override("font_size", font)
	add_child(starts_panel)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	starts_panel.add_child(column)
	var heading := Label.new()
	heading.text = "Playtest starts"
	heading.add_theme_font_size_override("font_size", font + 8)
	column.add_child(heading)
	var help := Label.new()
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.text = "Start at a story point. Each start is a real save earned by the automated playthrough tests and opens through the normal Resume. Your own saves are not changed until you save (F5). F2 or Esc closes this list."
	column.add_child(help)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for entry in listed.entries:
		var row := Button.new()
		row.name = "Start_" + str(entry.id)
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.text = str(entry.title)
		var missing := Starts.file_error(entry)
		if not missing.is_empty():
			row.disabled = true
			row.text += "  (not in this build)"
		row.pressed.connect(start_playtest.bind(str(entry.id)))
		rows.add_child(row)
	starts_status = Label.new()
	starts_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	starts_status.text = listed.error
	column.add_child(starts_status)
	var back := Button.new()
	back.name = "PlaytestStartsBack"
	back.text = "Back"
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(func(): starts_panel.hide())
	column.add_child(back)

## Start one manifest entry through the gate's own resume branch for its area: the branch's save path is pointed at the
## staged res:// file for this one call (reader, validator, resume meta and scene unchanged), then restored.
func start_playtest(id: String) -> void:
	var entry := {}
	for candidate in Starts.manifest().entries:
		if str(candidate.id) == id: entry = candidate
	var report := func(text: String) -> void:
		status.text = text
		if starts_status != null: starts_status.text = text
		print("Playtest start blocked: ", text)
	if entry.is_empty():
		report.call("Unknown playtest start: " + id)
		return
	var error := Starts.file_error(entry)
	if not error.is_empty():
		report.call(error)
		return
	var path := Starts.save_path(entry)
	var kept := [museum_save_path, jungle_save_path, hive_save_path, darker_save_path, dark_halls_save_path]
	match str(entry.resume):
		"museum": museum_save_path = path
		"jungle": jungle_save_path = path
		"hive": hive_save_path = path
		"darker": darker_save_path = path
		"dark_halls": dark_halls_save_path = path
	print("Playtest start: ", entry.id, " (", entry.save, ")")
	_verify_and_start(entry.resume == "museum", entry.resume == "jungle", entry.resume == "hive", entry.resume == "darker", entry.resume == "dark_halls")
	museum_save_path = kept[0]; jungle_save_path = kept[1]; hive_save_path = kept[2]; darker_save_path = kept[3]; dark_halls_save_path = kept[4]
	if starts_status != null and not status.text.is_empty(): starts_status.text = status.text

## Act 2 test start (lane l8-preview, opened to Classic by the owner's 2026-10-30 request "jump to Act 2 without replaying Act 1"):
## the darker-jungle scene from its native arrival, without the Act 1 handoff. Offered in both editions whenever the pack is staged;
## --l8-preview still starts it at once. The Classic Act 1 chain itself reaches that scene only through act_one_departure.

func _verify_and_start(resume_museum: bool = false, resume_jungle: bool = false, resume_hive: bool = false, resume_darker: bool = false, resume_dark_halls: bool = false, preview_darker: bool = false, preview_map_scene: String = "", preview_dragon: bool = false) -> void:
	get_tree().set_meta("original_game_verified", false)
	var error := Check.verify(path_field.text)
	if not error.is_empty():
		status.text = error
		print("Original game verification blocked: ", error)
		return
	var config := ConfigFile.new()
	config.set_value("original_game", "exe_path", path_field.text)
	config.save(settings_path) # Only the path is remembered; never cache approval.
	get_tree().set_meta("original_game_verified", true)
	print("Original game executable verified (SHA-256).")
	var scene_path := "res://scenes/lol2/cave_walkthrough.tscn"
	if resume_museum:
		var saved := MuseumSave.read_save(museum_save_path)
		if not saved.error.is_empty():
			status.text = saved.error
			return
		if not preload("res://scripts/lol2/museum_walkthrough.gd").assets_ready():
			status.text = "Museum assets are missing from this build."
			return
		get_tree().set_meta("lol2_museum_resume",saved.state)
		scene_path = "res://scenes/lol2/museum_walkthrough.tscn"
	elif resume_jungle:
		var saved := JungleSave.read_save(jungle_save_path)
		if not saved.error.is_empty():
			status.text = saved.error
			return
		if not preload("res://scripts/lol2/jungle_walkthrough.gd").assets_ready():
			status.text = "Jungle assets are missing from this build."
			return
		get_tree().set_meta("lol2_jungle_resume",saved.state)
		scene_path = "res://scenes/lol2/jungle_walkthrough.tscn"
	elif resume_hive:
		var saved := HiveSave.read_save(hive_save_path)
		if not saved.error.is_empty():
			status.text = saved.error
			return
		if not preload("res://scripts/lol2/hive_review.gd").assets_ready():
			status.text = "Hive assets are missing from this build."
			return
		get_tree().set_meta("lol2_hive_resume",saved.state)
		scene_path = "res://scenes/lol2/hive_review.tscn"
	elif resume_darker:
		var saved := JungleSave.read_save(darker_save_path,Darker.FORMAT)
		if not saved.error.is_empty():
			status.text = saved.error
			return
		if not Darker.arrival_assets_ready():
			status.text = "Darker jungle assets are missing from this build."
			return
		get_tree().set_meta("lol2_darker_resume",saved.state)
		scene_path = "res://scenes/lol2/darker_jungle.tscn"
	elif preview_darker:
		if not Darker.arrival_assets_ready():
			status.text = "Darker jungle assets are missing from this build."
			return
		get_tree().set_meta("lol2_darker_preview", true)
		scene_path = "res://scenes/lol2/darker_jungle.tscn"
	elif not preview_map_scene.is_empty():
		var registered := false
		for entry in Act2Map.registry():
			if str(entry.scene) == preview_map_scene: registered = true
		if not registered or not ResourceLoader.exists(preview_map_scene):  # exported builds store scenes remapped; FileAccess sees no .tscn there
			status.text = "That map's scene is missing from this build."
			return
		get_tree().set_meta("lol2_map_preview", true)
		scene_path = preview_map_scene
	elif preview_dragon:
		if not Dragon.arrival_assets_ready():
			status.text = "Dragon level assets are missing from this build."
			return
		scene_path = "res://scenes/lol2/dragon_level.tscn"
	elif resume_dark_halls:
		var saved := JungleSave.read_save(dark_halls_save_path,DarkHalls.FORMAT)
		if not saved.error.is_empty():
			status.text = saved.error
			return
		if not DarkHalls.arrival_assets_ready():
			status.text = "Dark Halls assets are missing from this build."
			return
		get_tree().set_meta("lol2_dark_halls_resume",saved.state)
		scene_path = "res://scenes/lol2/dark_halls.tscn"
	var result := get_tree().change_scene_to_file(scene_path)
	if result != OK:
		get_tree().set_meta("original_game_verified", false)
		if resume_museum: get_tree().remove_meta("lol2_museum_resume")
		if resume_jungle: get_tree().remove_meta("lol2_jungle_resume")
		if resume_hive: get_tree().remove_meta("lol2_hive_resume")
		if resume_darker: get_tree().remove_meta("lol2_darker_resume")
		if resume_dark_halls: get_tree().remove_meta("lol2_dark_halls_resume")
		status.text = "Could not load the game. Extract the complete demo ZIP and try again."
