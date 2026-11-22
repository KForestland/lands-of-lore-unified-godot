extends SceneTree
const Save = preload("res://scripts/lol2/game_save.gd")
const Areas = preload("res://scripts/lol2/game_areas.gd")
const Session = preload("res://scripts/lol2/game_session.gd")
const FIXTURES := "res://tests/fixtures/saves_d5da60a/areas/"
func _initialize() -> void: run.call_deferred()
func run() -> void:
	assert(OS.get_environment("LOL2_PRIVATE_SAVE_CASE") == "1")
	var session: Node = Session.for_tree(self)
	for area in Areas.ROWS:
		var row: Dictionary = Areas.ROWS[area]
		var state: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + area + ".json"))
		var doc := {"format":Save.FORMAT,"version":Save.CURRENT,"written_unix":1,"play_seconds":123.5,
			"label":row.label,"area":area,"scene":row.scene,"area_save":state,"native_bank":{},"native_globals":Session.Globals.empty(),"session":{"options":{"adapter_exit_seeds":false},"last_slot":4}}
		if area in Areas.PROGRESSION_AREAS:
			var vm:=preload("res://scripts/lol2/native_script_host.gd").new()
			assert(vm.load_area("res://scripts/lol2/native_scripts/"+area+".json").is_empty())
			var bank:=vm.snapshot();bank.struck_durability={};doc.native_bank[area]=bank
		assert(Save.write_document(Save.slot_path(4),doc).is_empty(), area + " envelope fixture")
		set_meta("lol2_museum_checkpoint",{"stale":true})
		set_meta("lol2_act2_handoff",{"stale":true})
		assert(Save.load(self,4).is_empty(),area + " load admission")
		await scene_changed
		var scene: Node = current_scene
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		for i in 1500:
			await process_frame
			if session.pending_resume.is_empty() and scene.get("starting_magic") != null: break
		assert(session.pending_resume.is_empty(),area + " consumes pending resume")
		if area == "L5_HC":
			assert(not scene.development_mode, "Hive slot resume enters normal play, matching legacy resume")
			assert(not is_instance_valid(scene.development_overlay) or not scene.development_overlay.visible)
		assert(not session.changing_scene and not has_meta("lol2_slot_resume"))
		assert(not has_meta("lol2_act2_handoff") and not has_meta("lol2_museum_checkpoint"),area + " stale state cleared")
		assert(session.play_seconds == 123.5 and session.last_slot == 4)
		var actual: Variant = JSON.parse_string(JSON.stringify(scene.area_snapshot(),"",true,true))
		var expected: Dictionary = preload("res://tests/helpers/legacy_base_contract.gd").expected(area)
		assert(actual == expected,area + " new scene snapshot equals unchanged legacy load")
		print("SLOT LOAD ",area)
	# Cave inner version 1 goes through its own migration, independent of the envelope version.
	var doc: Dictionary = Save.read_document(Save.slot_path(4)).state
	doc.area="L1_DC";doc.scene=Areas.ROWS.L1_DC.scene;doc.area_save=JSON.parse_string(FileAccess.get_file_as_string(FIXTURES+"L1_DC_v1.json"))
	assert(Save.write_document(Save.slot_path(4),doc).is_empty())
	assert(Save.load(self,4).is_empty()); await scene_changed
	current_scene.process_mode=Node.PROCESS_MODE_DISABLED
	for i in 1500:
		await process_frame
		if session.pending_resume.is_empty() and current_scene.get("starting_magic") != null: break
	assert(session.pending_resume.is_empty())
	assert(current_scene.area_snapshot().version==2 and current_scene.area_snapshot().collected==[])
	# Reject damaged/future envelopes before touching live state or session.
	var before: Dictionary=session.runtime_checkpoint();var live:=current_scene
	var file:=FileAccess.open(Save.slot_path(5),FileAccess.WRITE);file.store_string("{bad");file.close()
	assert(not Save.load(self,5).is_empty());assert(current_scene==live and session.runtime_checkpoint()==before)
	current_scene.free();current_scene=null
	print("PASS fifteen fresh-scene slot resumes, stale arrivals/cache cleared, Cave inner v1 migration, invalid load atomic")
	quit()
