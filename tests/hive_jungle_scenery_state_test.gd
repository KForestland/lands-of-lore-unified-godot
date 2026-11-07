extends SceneTree
## Hive + Jungle scenery contract and host (stub walkthrough, no rendering): 666 Hive and 16 Jungle ambient rows
## (G58/G71 build-ready rows minus descriptor 0, minus the 7 transparent 'Inviso Light' slots and the 4 unbound
## region-65535 records), first frame only (frame_seconds null, no _process), one MultiMesh per material/box/flip batch,
## native boxes and 0x40/0x80 flips, records drawn by other hosts excluded, sound-only owner groups decoded but not hosted.
const Scenery = preload("res://scripts/lol2/hive_jungle_scenery.gd")
const COUNTS := {"L5_HC": 666, "L4_HJ": 16}
const PLACED_ELSEWHERE := {"L5_HC": [188, 198, 215, 233, 316, 327, 363, 377, 401, 426, 676, 725],
	"L4_HJ": [64, 68, 427, 484, 492, 506, 552, 561, 572, 961, 1465, 4181]}
const NOT_HOSTED := {"L5_HC": [70, 77, 234, 237, 333, 334, 378, 615, 685, 767], "L4_HJ": [560]}
## jungle_props.gd rows (no owner, never named) must not be drawn twice: a few of its 5830 instances (5904 before the
## region-65535 rule of tools/lol2/map_props.py, 2026-10-30).
const JUNGLE_PROPS_ROWS := [0, 1, 2, 100, 3000, 6294]

class StubHost extends Node3D:
	pass

func _initialize() -> void: run.call_deferred()
func v(a: Array) -> Vector3: return Vector3(a[0], a[1], a[2])

func fail(message: String) -> void:
	push_error(message); quit(1)

func run() -> void:
	var source: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Scenery.SOURCE))
	if source.frame_seconds != null: return fail("No Hive/Jungle frame rate is proven: frame_seconds must be null")
	for area in COUNTS:
		var pack: Dictionary = source.areas[area]
		if pack.rows.size() != COUNTS[area] or int(pack.summary.rows) != COUNTS[area]: return fail("%s row count differs: %d" % [area, pack.rows.size()])
		for r in PLACED_ELSEWHERE[area] + NOT_HOSTED[area]:
			if pack.rows.has(str(r)): return fail("%s record %d must not be hosted here" % [area, r])
		for n in pack.not_hosted:
			if not int(n.record) in NOT_HOSTED[area]: return fail("%s unexpected not_hosted record %s" % [area, n.record])
		if area == "L4_HJ":
			for r in JUNGLE_PROPS_ROWS:
				if pack.rows.has(str(r)): return fail("Jungle record %d belongs to jungle_props.gd" % r)
		var instances := 0
		for group in pack.groups:
			instances += group.instances.size()
			for row in group.instances:
				var hosted: Dictionary = pack.rows[str(int(row[3]))]
				if v(hosted.position) != Vector3(row[0], row[1], row[2]) or hosted.material != group.material or (int(hosted.frame_flags) & 0xC0) != int(group.flip):
					return fail("%s group instance %s does not match its row" % [area, row])
		if instances != COUNTS[area]: return fail("%s groups hold %d instances" % [area, instances])
		for id in pack.rows:
			var row: Dictionary = pack.rows[id]
			if row.frames.is_empty() or not pack.art.has(row.material) or pack.art[row.material] != row.frames: return fail("%s row %s art" % [area, id])
			if float(row.right) <= float(row.left) or float(row.top) <= float(row.bottom): return fail("%s row %s degenerate box" % [area, id])
			if row.sound_group != pack.sound_groups.has(id): return fail("%s row %s sound group flag" % [area, id])
		for id in pack.sound_groups:
			for g in pack.sound_groups[id]:
				if int(g.target_kind) != 3 or int(g.target) != int(id) or not g.names_owner: return fail("%s sound group of %s names another object" % [area, id])
	var hive: Dictionary = source.areas["L5_HC"]
	var pole: Dictionary = hive.rows["0"]
	if pole.name != "pole 2" or int(pole.template) != 1 or v(pole.position) != Vector3(-689, -235, -8341) or pole.material != "prop_59" \
		or pole.frames.size() != 3 or float(pole.left) != -32.0 or float(pole.right) != 32.0 or int(pole.bottom) != 0 or int(pole.top) != 80 or int(pole.region) != 387:
		return fail("Hive record 0 differs: %s" % pole)
	if hive.sound_groups.size() != 83 or int(hive.sound_groups["125"][0].sound) != 720 or int(hive.sound_groups["125"][0].volume) != 50: return fail("Hive sound groups differ")
	var jungle: Dictionary = source.areas["L4_HJ"]
	var idol: Dictionary = jungle.rows["510"]
	if idol.name != "Idol" or int(idol.template) != 90 or v(idol.position) != Vector3(-2024, 10, -4881) or idol.material != "prop_526" or int(idol.top) != 62:
		return fail("Jungle record 510 differs: %s" % idol)
	if int(jungle.rows["4960"].frame_flags) & 0x40 == 0 or int(jungle.rows["313"].frame_flags) != 16: return fail("Jungle frame flags differ")
	if jungle.sound_groups.size() != 6 or int(jungle.jungle_props_instances) != 5830: return fail("Jungle counts differ")

	for area in COUNTS:
		if not Scenery.assets_ready(area): return fail("Pack not staged for " + area)
		var host := StubHost.new()
		root.add_child(host)
		var scenery = Scenery.new()
		host.add_child(scenery)
		var error: String = scenery.setup(host, area)
		if not error.is_empty(): return fail(error)
		var pack: Dictionary = source.areas[area]
		if scenery.instance_count != COUNTS[area] or scenery.batches.size() != pack.groups.size() or scenery.placements.size() != COUNTS[area]:
			return fail("%s host: %d instances in %d batches" % [area, scenery.instance_count, scenery.batches.size()])
		if scenery.is_processing() or scenery.is_physics_processing(): return fail("Scenery must not animate (no proven rate)")
		for i in pack.groups.size():
			var group: Dictionary = pack.groups[i]
			var node: MultiMeshInstance3D = scenery.batches[i]
			var quad: QuadMesh = node.multimesh.mesh
			if quad.size != Vector2(float(group.right) - float(group.left), float(group.top) - float(group.bottom)): return fail("%s batch %d box" % [area, i])
			if quad.center_offset != Vector3((float(group.left) + float(group.right)) / 2.0, (float(group.bottom) + float(group.top)) / 2.0, 0.0): return fail("%s batch %d anchor" % [area, i])
			var material: StandardMaterial3D = quad.material
			if material.albedo_texture != scenery.textures[group.material][0]: return fail("%s batch %d not on the first frame" % [area, i])
			if material.billboard_mode != BaseMaterial3D.BILLBOARD_FIXED_Y or material.transparency != BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR: return fail("%s batch %d material" % [area, i])
			var flip := int(group.flip)
			if (material.uv1_scale.x < 0.0) != bool(flip & 0x40) or (material.uv1_scale.y < 0.0) != bool(flip & 0x80): return fail("%s batch %d flip" % [area, i])
			if node.multimesh.instance_count != group.instances.size(): return fail("%s batch %d count" % [area, i])
			# The headless dummy renderer does not read instance transforms back; the rendered live test does. Here the
			# host's own placement table must bind every instance to this batch at its native position.
			for j in group.instances.size():
				var row: Array = group.instances[j]
				var placed: Array = scenery.placements[int(row[3])]
				if placed[0] != node.multimesh or int(placed[1]) != j or placed[2] != Vector3(row[0], row[1], row[2]): return fail("%s batch %d instance %d misplaced" % [area, i, j])
		for id in pack.rows:
			if scenery.position_of(int(id)) != v(pack.rows[id].position): return fail("%s record %s position lookup" % [area, id])
		if scenery.position_of(999999) != Vector3.INF: return fail("Unknown record must report INF")
		host.queue_free()
	print("PASS hive_jungle_scenery_state: 666 Hive + 16 Jungle ambient rows in 45 + 13 batches, first frame only, native boxes/flips, 11 not hosted, 83 + 6 sound-only groups decoded (not hosted)")
	quit()
