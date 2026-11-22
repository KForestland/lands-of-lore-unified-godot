extends SceneTree
const Save = preload("res://scripts/lol2/game_save.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE") == "1", "private profile driver required")
	var scene = load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
	root.add_child(scene); current_scene = scene; Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	for i in 1500:
		await process_frame
		if scene.ready_for_review: break
	for i in 30: await physics_frame
	assert(scene.can_save().is_empty(), scene.can_save())
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	var legacy := "user://legacy_expected.json"
	assert(scene._quicksave_unrecorded(legacy).is_empty())
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(legacy))
	for id in [1,2,3,4,5,6,7,8,9,10,Save.AUTOSAVE]:
		assert(Save.save(scene, id).is_empty(), "independent slot " + str(id))
		var read := Save.read_document(Save.slot_path(id))
		assert(read.error.is_empty() and read.state.area_save == expected)
	var rows := Save.slots()
	assert(rows.size() == 11)
	var panel := preload("res://scripts/lol2/save_slots_panel.gd")
	var description: String = panel.describe(rows[0])
	assert(description.count("Dracoid Cemetery") == 1 and not description.contains("L10_DC"), "player-facing area name, once")
	var labelled: Dictionary = rows[0].duplicate(true); labelled.label = "Before the gate"
	description = panel.describe(labelled)
	assert(description.contains("Before the gate") and description.contains("Dracoid Cemetery") and not description.contains("L10_DC"))
	for id in [1,2]:
		var old := FileAccess.get_file_as_bytes(Save.slot_path(id))
		assert(Save.save(scene, id).is_empty())
		assert(FileAccess.get_file_as_bytes(Save.backup_path(id)) == old, "verified previous bytes in backup")
	var good := FileAccess.get_file_as_bytes(Save.slot_path(1))
	var broken := Save.make_document(scene, 1); broken.native_bank = {"UNKNOWN": {}}
	assert(not Save.write_document(Save.slot_path(1), broken).is_empty())
	assert(FileAccess.get_file_as_bytes(Save.slot_path(1)) == good, "invalid replacement leaves previous bytes")
	var file := FileAccess.open(Save.slot_path(2), FileAccess.WRITE); file.store_string("{damaged"); file.close()
	var row: Dictionary = Save.slots()[1]
	assert(row.exists and not row.valid and not row.error.is_empty() and row.backup.valid)
	var future := Save.make_document(scene, 1); future.version = 999
	assert(Save.validate(future).contains("newer"))
	assert(not Save.validate({}).is_empty())
	for field in ["area", "scene", "area_save", "native_bank", "native_globals", "session", "play_seconds"]:
		var invalid := Save.make_document(scene, 1); invalid.erase(field)
		assert(not Save.validate(invalid).is_empty(), field)
	assert(not Save.newest().is_empty())
	# Remembered executable plus slots/backups keeps Continue/Load on the opening screen.
	var config:=ConfigFile.new();config.set_value("original_game","exe_path",OS.get_environment("LOL2_ORIGINAL_GAME_EXE"));assert(config.save("user://original_game.cfg")==OK)
	scene.free();current_scene=null
	var gate=load("res://scenes/lol2/original_game_gate.tscn").instantiate();root.add_child(gate);current_scene=gate
	for i in 4:await process_frame
	assert(current_scene==gate and gate.find_child("Continue",true,false)!=null and not gate.find_child("Continue",true,false).disabled,"remembered path cannot auto-start over a slot")
	gate.free();current_scene=null
	# A lone backup is still a saved game, including when its primary is missing.
	for id in [0,1,2,3,4,5,6,7,8,9,10]:
		DirAccess.remove_absolute(Save.slot_path(id))
		if id!=2:DirAccess.remove_absolute(Save.backup_path(id))
	assert(Save.has_slot_files() and Save.newest().get("use_backup",false))
	gate=load("res://scenes/lol2/original_game_gate.tscn").instantiate();root.add_child(gate);current_scene=gate
	for i in 4:await process_frame
	assert(current_scene==gate and not gate.find_child("Continue",true,false).disabled,"backup-only Continue remains available")
	gate.free();current_scene=null
	print("PASS ten independent slots +autosave, exact inner packet, backup bytes, malformed/future refusal and damaged-row isolation")
	quit()
