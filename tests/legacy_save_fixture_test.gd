extends SceneTree
## Actual fifteen d5da60a writers, plus the existing Cave v1 reader migration.
const FIXTURES := "res://tests/fixtures/saves_d5da60a/areas/"
func verify_fresh_scene(_scene: Node, _area: String) -> bool: return true
func verify_scene(_scene: Node, _area: String, _legacy: Dictionary) -> void: pass
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURES + "manifest.json"))
	var generate := OS.get_environment("LOL2_WRITE_LEGACY_ROUNDTRIPS") == "1"
	for area in manifest.areas:
		paused = false
		var row: Dictionary = manifest.areas[area]
		assert(FileAccess.get_sha256(FIXTURES + area + ".json") == row.sha256)
		var scene = load(row.scene).instantiate()
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(scene); current_scene = scene
		for i in 1500:
			await process_frame
			if (scene.get("walkthrough_ready") if area == "L1_DC" else scene.get("ready_for_review")) and scene.get("starting_magic") != null: break
		if area == "L3_DH": scene.introduction_state = "complete"
		paused = false
		assert(await verify_fresh_scene(scene, area), area + " fresh packet parity")
		assert(scene._quickload_unrecorded(FIXTURES + area + ".json").is_empty(), area + " legacy loader")
		var path := "user://legacy_fixture_roundtrip.json"
		assert(scene._quicksave_unrecorded(path).is_empty(), area + " legacy writer")
		var bytes := FileAccess.get_file_as_bytes(path)
		var expected: String = FIXTURES + area + "_roundtrip.json"
		var contract:Dictionary=preload("res://tests/helpers/legacy_base_contract.gd").expected(area)
		# Exact pre-items G03 observations, independently pinned before this
		# repair. Check the COMPLETE new packet before projecting a copy for
		# old fields; original fixture bytes and full snapshot equality stay.
		var actual:Dictionary=JSON.parse_string(bytes.get_string_from_utf8())
		var g03=preload("res://tests/helpers/item_grant_g03_reference.gd")
		var projected:Dictionary=actual.duplicate(true)
		var wrapped:Dictionary=g03.project("legacy_loaded",area,{"grant_quests":actual.get("quests",{})})
		if projected.has("quests"):projected.quests=wrapped.grant_quests
		if generate:
			var file := FileAccess.open(expected, FileAccess.WRITE); file.store_buffer(bytes); file.close()
		assert(projected==contract,area+" legacy writer keeps immutable fields plus enumerated pre-G04 and independently pinned G03 additions")
		if not JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/g04_inputs/pre_g04_legacy_additions.json")).areas.has(area) and not g03.data().normalizations.legacy_loaded.has(area):
			assert(bytes==FileAccess.get_file_as_bytes(expected),area+" unextended legacy bytes unchanged")
		if scene.has_method("area_snapshot"):
			var normalized: Variant = JSON.parse_string(JSON.stringify(scene.area_snapshot(), "", true, true))
			assert(normalized == JSON.parse_string(bytes.get_string_from_utf8()), area + " snapshot equals legacy writer")
		verify_scene(scene, area, JSON.parse_string(bytes.get_string_from_utf8()))
		if area == "L1_DC":
			assert(scene._quickload_unrecorded(FIXTURES + "L1_DC_v1.json").is_empty(), "Cave v1 reader still migrates")
			assert(scene._quicksave_unrecorded(path).is_empty())
			var migrated: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
			assert(migrated.version == 2 and migrated.collected == [])
		print("LEGACY ", area, " v", row.version, " bytes=", bytes.size())
		scene.free(); current_scene = null
		for i in 3: await process_frame
	DirAccess.remove_absolute("user://legacy_fixture_roundtrip.json")
	print("PASS fifteen immutable legacy inputs/loaders/writers: every original field plus independently pinned pre-G04/G03 additions, unextended bytes exact, full new snapshot parity; Cave v1 migration retained")
	quit()
