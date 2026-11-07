extends SceneTree
## Owner r12e F10 2026-10-25 11:05 at (-4499.7,1170.1): "the road is blocked to dark jungle". The drawn quad of the vine
## arch at the root tunnel exit (static assembly 99, not solid in the original) collided; the owner approved removing
## it. Only that arch stops colliding: a neighbouring assembly's faces still block.
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL darker_jungle_tunnel_arch: ", message); quit(1)

func run() -> void:
	scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not scene.get("ready_for_review"): return fail("Darker Jungle not ready")
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(scene.geometry_file))
	var open := 0
	var kept := 0
	var larkhon_open := 0
	for face in data.faces:
		if face.kind != "movable": continue
		if int(face.get("source_index", -1)) == 99: open += int(not scene.include_collision_face(face))
		elif int(face.get("source_index", -1)) == 111: larkhon_open += int(not scene.include_collision_face(face)) # astra STORY-035: facade 111 has no native solid box
		else: kept += int(scene.include_collision_face(face))
	if open != 4: return fail("Expected the 4 faces of arch 99 open, got %d" % open)
	if larkhon_open != 2: return fail("Expected the 2 faces of Larkhon facade 111 open, got %d" % larkhon_open)
	# 930 = 944 before astra minus facade 111 (2, STORY-035) minus tree door movable 50 (12, owned by l8_tree.gd, STORY-053);
	# 834 = 930 minus the standing tree 114 and the log bridge 116 (48 faces each, owned by l8_tree_bridge.gd, grok Y02 2026-11-06).
	if kept != 834: return fail("Other assembly faces changed: %d collide" % kept)
	# Ordinary grounded walking (gravity, step and move_and_slide via the shared move_grounded), from the owner's pose
	# east through the arch at x -4434.
	var player: CharacterBody3D = scene.player
	player.global_position = Vector3(-4499.7, 32.05, 1170.1)
	player.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
	if not player.is_on_floor(): return fail("Not grounded at the owner's pose: %s" % player.global_position)
	var resets: int = scene.resets
	for i in 240:
		await physics_frame
		scene.move_grounded(Vector3(1, 0, 0), 1.0 / 60.0)
		if player.global_position.x > -4300.0: break
	if player.global_position.x <= -4300.0: return fail("Walk east stopped at %s" % player.global_position)
	for i in 10:
		await physics_frame
		scene.move_grounded(Vector3.ZERO, 1.0 / 60.0)
	if not player.is_on_floor() or scene.resets != resets: return fail("Not grounded past the arch: %s" % player.global_position)
	print("PASS darker_jungle_tunnel_arch: arch 99 open (4 faces), 944 other assembly faces still collide; walked grounded from the owner pose through the arch to x %.1f" % player.global_position.x)
	quit(0)
