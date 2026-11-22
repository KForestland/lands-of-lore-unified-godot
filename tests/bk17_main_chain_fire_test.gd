extends SceneTree
## BK17. Boot L16, L17, L19, and L20, then fire the STORY-067..093 events in order.
## A stop is a target group whose host status is unhosted or rejected.
## Caller mismatches on other records of the same object are not stops.
const SCENES := {
	"L16_CA": "res://scenes/lol2/maps/L16_CA.tscn",
	"L17_HC": "res://scenes/lol2/maps/L17_HC.tscn",
	"L19_BC": "res://scenes/lol2/maps/L19_BC.tscn",
	"L20_BB": "res://scenes/lol2/maps/L20_BB.tscn",
}
const CHAIN: Array[Dictionary] = [
	{"story": "067", "area": "L16_CA", "ref": "control:78", "kind": 5, "value": 4},
	{"story": "067", "area": "L16_CA", "ref": "control:78", "kind": 5, "value": 5},
	{"story": "067", "area": "L16_CA", "ref": "region:233", "kind": 12, "value": 0},
	{"story": "068", "area": "L16_CA", "ref": "prop:626", "kind": 9, "value": 32},
	{"story": "069", "area": "L16_CA", "ref": "prop:489", "kind": 4, "value": 0},
	{"story": "069", "area": "L16_CA", "ref": "prop:490", "kind": 4, "value": 0},
	{"story": "069", "area": "L16_CA", "ref": "prop:491", "kind": 4, "value": 0},
	{"story": "069", "area": "L16_CA", "ref": "prop:492", "kind": 4, "value": 0},
	{"story": "069", "area": "L16_CA", "ref": "control:109", "kind": 6, "value": 20},
	{"story": "069", "area": "L16_CA", "ref": "control:110", "kind": 6, "value": 20},
	{"story": "069", "area": "L16_CA", "ref": "control:111", "kind": 6, "value": 20},
	{"story": "069", "area": "L16_CA", "ref": "control:112", "kind": 6, "value": 20},
	{"story": "070", "area": "L16_CA", "ref": "control:75", "kind": 4, "value": 3},
	{"story": "070", "area": "L16_CA", "ref": "prop:627", "kind": 4, "value": 0},
	{"story": "070", "area": "L16_CA", "ref": "prop:602", "kind": 6, "value": 20},
	{"story": "070", "area": "L16_CA", "ref": "prop:602", "kind": 10, "value": 0},
	{"story": "071", "area": "L16_CA", "ref": "prop:392", "kind": 9, "value": 17},
	{"story": "072", "area": "L16_CA", "ref": "prop:88", "kind": 9, "value": 14},
	{"story": "072", "area": "L16_CA", "ref": "prop:89", "kind": 9, "value": 32},
	{"story": "072", "area": "L16_CA", "ref": "prop:90", "kind": 9, "value": 16},
	{"story": "074", "area": "L16_CA", "ref": "movable:79", "kind": 6, "value": 9},
	{"story": "074", "area": "L16_CA", "ref": "movable:79", "kind": 6, "value": 15},
	{"story": "077", "area": "L16_CA", "ref": "control:80", "kind": 5, "value": 4},
	{"story": "077", "area": "L16_CA", "ref": "control:79", "kind": 5, "value": 4},
	{"story": "078", "area": "L16_CA", "ref": "prop:241", "kind": 9, "value": 2},
	{"story": "078", "area": "L16_CA", "ref": "control:74", "kind": 5, "value": 4},
	{"story": "079", "area": "L17_HC", "ref": "region:1312", "kind": 12, "value": 0},
	{"story": "080", "area": "L17_HC", "ref": "region:1293", "kind": 12, "value": 0},
	{"story": "081", "area": "L19_BC", "ref": "prop:222", "kind": 6, "value": 9},
	{"story": "082", "area": "L19_BC", "ref": "movable:77", "kind": 6, "value": 15},
	{"story": "082", "area": "L19_BC", "ref": "movable:74", "kind": 6, "value": 15},
	{"story": "082", "area": "L19_BC", "ref": "movable:75", "kind": 6, "value": 15},
	{"story": "082", "area": "L19_BC", "ref": "movable:76", "kind": 6, "value": 15},
	{"story": "083", "area": "L19_BC", "ref": "movable:50", "kind": 4, "value": 0},
	{"story": "083", "area": "L19_BC", "ref": "movable:71", "kind": 4, "value": 0},
	{"story": "083", "area": "L19_BC", "ref": "movable:72", "kind": 4, "value": 0},
	{"story": "084", "area": "L19_BC", "ref": "movable:73", "kind": 4, "value": 0},
	{"story": "084", "area": "L19_BC", "ref": "movable:51", "kind": 4, "value": 0},
	{"story": "085", "area": "L19_BC", "ref": "prop:67", "kind": 6, "value": 21},
	{"story": "085", "area": "L19_BC", "ref": "prop:68", "kind": 6, "value": 21},
	{"story": "085", "area": "L19_BC", "ref": "prop:69", "kind": 6, "value": 21},
	{"story": "085", "area": "L19_BC", "ref": "prop:70", "kind": 6, "value": 21},
	{"story": "085", "area": "L19_BC", "ref": "prop:65", "kind": 6, "value": 20},
	{"story": "085", "area": "L19_BC", "ref": "control:57", "kind": 6, "value": 9},
	{"story": "086", "area": "L19_BC", "ref": "prop:78", "kind": 6, "value": 0},
	{"story": "086", "area": "L19_BC", "ref": "actor:39", "kind": 6, "value": 0},
	{"story": "087", "area": "L19_BC", "ref": "prop:98", "kind": 6, "value": 20},
	{"story": "087", "area": "L19_BC", "ref": "region:2369", "kind": 12, "value": 0},
	{"story": "087", "area": "L20_BB", "ref": "prop:242", "kind": 6, "value": 21},
	{"story": "087", "area": "L20_BB", "ref": "prop:87", "kind": 6, "value": 20},
	{"story": "087", "area": "L20_BB", "ref": "actor:47", "kind": 6, "value": 11},
	{"story": "087", "area": "L20_BB", "ref": "actor:48", "kind": 6, "value": 11},
	{"story": "088", "area": "L20_BB", "ref": "movable:57", "kind": 6, "value": 15},
	{"story": "088", "area": "L20_BB", "ref": "movable:58", "kind": 6, "value": 15},
	{"story": "088", "area": "L20_BB", "ref": "movable:59", "kind": 6, "value": 15},
	{"story": "088", "area": "L20_BB", "ref": "movable:60", "kind": 6, "value": 15},
	{"story": "088", "area": "L20_BB", "ref": "movable:61", "kind": 6, "value": 15},
	{"story": "089", "area": "L20_BB", "ref": "region:1475", "kind": 12, "value": 0},
	{"story": "089", "area": "L20_BB", "ref": "region:1476", "kind": 12, "value": 0},
	{"story": "089", "area": "L20_BB", "ref": "region:1477", "kind": 12, "value": 0},
	{"story": "089", "area": "L20_BB", "ref": "region:1478", "kind": 12, "value": 0},
	{"story": "089", "area": "L20_BB", "ref": "region:1479", "kind": 12, "value": 0},
	{"story": "089", "area": "L20_BB", "ref": "region:1484", "kind": 12, "value": 0},
	{"story": "089", "area": "L20_BB", "ref": "region:1485", "kind": 12, "value": 0},
	{"story": "089", "area": "L20_BB", "ref": "region:1486", "kind": 12, "value": 0},
	{"story": "089", "area": "L20_BB", "ref": "region:1487", "kind": 12, "value": 0},
	{"story": "089", "area": "L20_BB", "ref": "region:1488", "kind": 12, "value": 0},
	{"story": "090", "area": "L20_BB", "ref": "control:62", "kind": 5, "value": 1},
	{"story": "090", "area": "L20_BB", "ref": "control:63", "kind": 5, "value": 1},
	{"story": "090", "area": "L20_BB", "ref": "control:64", "kind": 5, "value": 1},
	{"story": "090", "area": "L20_BB", "ref": "control:65", "kind": 5, "value": 1},
	{"story": "090", "area": "L20_BB", "ref": "control:66", "kind": 5, "value": 1},
	{"story": "090", "area": "L20_BB", "ref": "control:67", "kind": 5, "value": 1},
	{"story": "091", "area": "L20_BB", "ref": "actor:46", "kind": 6, "value": 11},
	{"story": "091", "area": "L20_BB", "ref": "actor:46", "kind": 6, "value": 20},
	{"story": "091", "area": "L20_BB", "ref": "movable:52", "kind": 6, "value": 15},
	{"story": "092", "area": "L20_BB", "ref": "actor:75", "kind": 5, "value": 0},
	{"story": "092", "area": "L20_BB", "ref": "actor:75", "kind": 6, "value": 0},
	{"story": "092", "area": "L20_BB", "ref": "control:0", "kind": 4, "value": 3},
	{"story": "092", "area": "L20_BB", "ref": "control:1", "kind": 4, "value": 3},
	{"story": "092", "area": "L20_BB", "ref": "control:2", "kind": 4, "value": 3},
	{"story": "093", "area": "L20_BB", "ref": "actor:46", "kind": 6, "value": 0},
]
var stops := 0
var ran := 0

func _initialize() -> void:
	run.call_deferred()

func run() -> void:
	print("GAP story=068 ref=prop:210 no native event (dry-fountain ball)")
	print("GAP story=073 ivory chips are placed rows with event 0; no chain fire")
	print("GAP story=075 pedestals are event 0")
	print("GAP story=076 no placed box, disk, or yellow figure")
	print("GAP story=080 hw01.vqa is not a movie-MIX entry")
	var order := ["L16_CA", "L17_HC", "L19_BC", "L20_BB"]
	for area in order:
		await boot_and_fire(area)
	print("BK17_DONE stops=%d ran=%d" % [stops, ran])
	quit(0)

func boot_and_fire(area: String) -> void:
	print("BOOT %s" % area)
	var selector := 1
	set_meta("lol2_map_start_selector", selector)
	var scene: Node = load(SCENES[area]).instantiate()
	scene.adapter_exit_seeds = true
	root.add_child(scene)
	var ready := false
	for _i in 3000:
		await process_frame
		if scene.ready_for_review and scene.progression != null:
			ready = true
			break
	if not ready:
		print("BOOT_FAIL %s" % area)
		scene.queue_free()
		await process_frame
		return
	print("BOOT_OK %s seeds=%s" % [area, scene.progression.seeds_applied])
	scene.progression.change_scene_enabled = false
	if scene.player != null:
		scene.player.set_physics_process(false)
	var native: Object = scene.progression.native
	for step in CHAIN:
		if str(step.area) != area:
			continue
		await one(scene, native, step)
		if paused:
			paused = false
	scene.queue_free()
	await process_frame
	print("BOOT_FREE %s" % area)

func one(scene: Node, native: Object, step: Dictionary) -> void:
	var ref := str(step.ref)
	var kind := int(step.kind)
	var value := int(step.value)
	var wanted: Array[int] = target_groups(native, ref, kind, value)
	if wanted.is_empty():
		print("MISSING story=%s ref=%s kind=%d value=%d" % [step.story, ref, kind, value])
		return
	var input := chain_input(native, ref, kind, value)
	var before: int = scene.progression.level_changes.size()
	var results: Array = []
	if kind == 12:
		results = scene.progression.enter_region(int(ref.get_slice(":", 1)))
	else:
		results = scene.progression.fire(ref, kind, input)
	var seen: Dictionary = {}
	for raw in results:
		var row: Dictionary = raw
		var group := int(row.get("group", -1))
		if not wanted.has(group):
			continue
		seen[group] = true
		var status := str(row.get("status", ""))
		var reasons: Array = row.get("reasons", [])
		var reason := str(reasons[0]) if not reasons.is_empty() else ""
		var stream := int(row.get("stream", -1))
		if status == "ran":
			ran += 1
			print("RAN story=%s ref=%s kind=%d value=%d stream=%d group=%d" % [step.story, ref, kind, value, stream, group])
		elif status == "unhosted" or status == "rejected":
			stops += 1
			print("STOP story=%s ref=%s kind=%d value=%d stream=%d group=%d status=%s reason=%s" % [step.story, ref, kind, value, stream, group, status, reason])
		else:
			print("OTHER story=%s ref=%s stream=%d group=%d status=%s reason=%s" % [step.story, ref, stream, group, status, reason])
	for group in wanted:
		if not seen.has(group):
			print("UNSEEN story=%s ref=%s kind=%d value=%d group=%d level_changes=%d" % [step.story, ref, kind, value, group, scene.progression.level_changes.size() - before])

func target_groups(native: Object, ref: String, kind: int, value: int) -> Array[int]:
	var out: Array[int] = []
	for raw in native.call("object_records", ref):
		var record: Dictionary = raw
		if int(record.get("kind", -1)) != kind:
			continue
		var bytes: PackedByteArray = record.bytes
		if kind != 12 and (bytes.size() <= 4 or int(bytes[4]) != value):
			continue
		var group := int(record.get("group", -1))
		if group >= 0 and not out.has(group):
			out.append(group)
	return out

func chain_input(native: Object, ref: String, kind: int, value: int) -> Dictionary:
	var input := {"context": ref}
	for raw in native.call("object_records", ref):
		var record: Dictionary = raw
		if int(record.get("kind", -1)) != kind:
			continue
		var bytes: PackedByteArray = record.bytes
		if kind != 12 and (bytes.size() <= 4 or int(bytes[4]) != value):
			continue
		if kind == 5 or kind == 6:
			input["caller_byte"] = value
			if kind == 5 and bytes.size() > 5:
				input["caller_byte_2"] = int(bytes[5])
		elif kind == 4:
			var mode := int(bytes[4]) if bytes.size() > 4 else 0
			if mode == 1:
				input["arg_c"] = 1
			elif mode == 3 and bytes.size() >= 10:
				input["arg_object_identity"] = bytes.decode_u32(6)
			else:
				input["arg_c"] = 0
		elif kind == 8 and bytes.size() >= 6:
			input["arg"] = bytes.decode_u16(4)
		elif kind == 9 and bytes.size() >= 8:
			var mask0 := bytes.decode_u16(4)
			var mask2 := bytes.decode_u16(6)
			input["word0"] = mask0 if mask0 != 0 else 1
			input["word2"] = mask2 if mask2 != 0 else 0
			input["dword_26"] = 0
			input["dword_1e"] = 255
			input["global_23331"] = 0
		return input
	return input
