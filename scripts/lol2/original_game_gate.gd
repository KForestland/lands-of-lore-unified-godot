extends Control

const Check = preload("res://scripts/lol2/original_game_check.gd")
const MuseumSave = preload("res://scripts/lol2/museum_save.gd")
const HiveSave = preload("res://scripts/lol2/hive_save.gd")
const JungleSave = preload("res://scripts/lol2/jungle_save.gd")
const Darker = preload("res://scripts/lol2/darker_jungle.gd")
const SETTINGS := "user://original_game.cfg"
var settings_path := SETTINGS
var museum_save_path := MuseumSave.DEFAULT_PATH
var jungle_save_path := JungleSave.DEFAULT_PATH
var hive_save_path := HiveSave.DEFAULT_PATH
var darker_save_path := Darker.DEFAULT_PATH
var path_field: LineEdit
var status: Label
var picker: FileDialog

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
	if not path_field.text.is_empty() and not FileAccess.file_exists(museum_save_path) and not FileAccess.file_exists(jungle_save_path) and not FileAccess.file_exists(hive_save_path) and not FileAccess.file_exists(darker_save_path):
		_verify_and_start.call_deferred()

func _verify_and_start(resume_museum: bool = false, resume_jungle: bool = false, resume_hive: bool = false, resume_darker: bool = false) -> void:
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
	var result := get_tree().change_scene_to_file(scene_path)
	if result != OK:
		get_tree().set_meta("original_game_verified", false)
		if resume_museum: get_tree().remove_meta("lol2_museum_resume")
		if resume_jungle: get_tree().remove_meta("lol2_jungle_resume")
		if resume_hive: get_tree().remove_meta("lol2_hive_resume")
		if resume_darker: get_tree().remove_meta("lol2_darker_resume")
		status.text = "Could not load the game. Extract the complete demo ZIP and try again."
