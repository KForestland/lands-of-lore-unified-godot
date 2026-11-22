extends SceneTree
## Structural snapshots use quiescent initial scenes, not earned gameplay.
const AREAS := ["L8_SJ", "L9_DR", "L10_DC", "L12_CM", "L13_RC", "L14_HT", "L16_CA", "L17_HC", "L19_BC", "L20_BB"]
const FIXTURES := "res://tests/fixtures/area_owners_d5da60a/"
var failures := 0
func kind() -> String: return "order"
func verify_scene(_scene: Node, _area: String) -> void: pass
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: ", message)
func _initialize() -> void: run.call_deferred()
func write_json(path: String, value: Variant) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, path)
	file.store_string(JSON.stringify(value, "\t", true, true) + "\n")
func snapshot(scene: Node) -> Dictionary:
	var children := []
	for child in scene.get_children():
		if child.name == "AreaOwners" or child.get_script() == null: continue
		var label := str(child.name)
		if label.begins_with("@"): label = "<automatic>"
		children.append({"name": label, "script": child.get_script().resource_path})
	var faces: Array = JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file)).faces
	var mesh := []
	var collision := []
	for i in faces.size():
		if scene.excluded_faces.has(i): mesh.append(i)
		if not scene.include_collision_face(faces[i]): collision.append(i)
	return {"children": children, "mesh_excluded": mesh, "collision_excluded": collision, "face_count": faces.size()}
func run() -> void:
	var generate := OS.get_environment("LOL2_WRITE_AREA_GOLDENS") == "1"
	Engine.set_meta("lol2_enhanced", false)
	for area in AREAS:
		if OS.has_environment("LOL2_AREA_CASE") and OS.get_environment("LOL2_AREA_CASE") != area: continue
		var path := "res://scenes/lol2/maps/%s.tscn" % area
		if area == "L8_SJ": path = "res://scenes/lol2/darker_jungle.tscn"
		if area == "L9_DR": path = "res://scenes/lol2/dragon_level.tscn"
		var scene = load(path).instantiate()
		# Freeze simulation during structural capture; _ready still constructs the real host.
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		root.add_child(scene)
		current_scene = scene
		for i in 3: await process_frame
		var actual := snapshot(scene)
		var target: String = FIXTURES + area + ".json"
		if generate:
			write_json(target, actual)
			var save := "user://area_owner_baseline.json"
			check(scene._quicksave_unrecorded(save).is_empty(), area + " baseline save")
			if FileAccess.file_exists(save):
				write_json(FIXTURES + area + "_save.json", JSON.parse_string(FileAccess.get_file_as_string(save)))
		var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(target))
		if kind() == "order":
			check(actual.children == expected.children, area + " ordered scripted host children")
		elif kind() == "faces":
			check(actual.face_count == expected.face_count, area + " face count")
			check(PackedInt32Array(actual.mesh_excluded) == PackedInt32Array(expected.mesh_excluded), area + " static face exclusions")
			check(PackedInt32Array(actual.collision_excluded) == PackedInt32Array(expected.collision_excluded), area + " collision face exclusions")
		verify_scene(scene, area)
		print("AREA ", area, " ", kind(), " children=", actual.children.size(), " mesh=", actual.mesh_excluded.size(), " collision=", actual.collision_excluded.size())
		scene.free()
		current_scene = null
		for i in 3: await process_frame
	if failures == 0: print("PASS area owner ", kind(), " ten-level unchanged-host golden contract")
	quit(0 if failures == 0 else 1)
