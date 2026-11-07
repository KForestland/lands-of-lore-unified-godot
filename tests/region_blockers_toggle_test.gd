extends SceneTree
## Live opcode-197 blocker toggle (lead 2026-10-31): region_blockers.gd keeps the op197 regions of a pack as dynamic edges a
## native script host binder enables and toggles from the host's 0x22d0c:N bit_0x1c_0x01 writes (arms 0-5).
## L8_SJ (darker_jungle.gd now attaches the binder, source movers enabled): region 3277, the Claw Mountains exit, starts blocked (data
## bit 0); an opcode-197 arm 0 on it opens the edge, the player walks in and its entry event (group 1908: movie + level change
## to level 12 arrival 1) fires; arm 2 seals it again. L10_DC: the ten dynamic regions start open; arm 4 on 1864 closes it.
const Host := preload("res://scripts/lol2/native_script_host.gd")
var failures := 0
func check(c: bool, m: String) -> void:
	if not c: failures += 1; print("FAIL: " + m)
func _initialize() -> void: run.call_deferred()
func cmd(arm: int, word: int) -> Dictionary:
	var b := PackedByteArray([197, 0x90, word & 0xFF, (word >> 8) & 0xFF, arm, 0])
	return {"opcode": 197, "kind": 0x90, "target": word, "file_offset": -1, "bytes": b, "raw_hex": b.hex_encode()}
func blocked_by_wall(player: CharacterBody3D, motion: Vector3) -> String:
	var hit := KinematicCollision3D.new()
	if not player.test_move(player.global_transform, motion, hit): return ""
	return str(hit.get_collider().name) if hit.get_collider() != null else "?"
func settle() -> void:
	for i in 3: await physics_frame
func run() -> void:
	Engine.set_meta("lol2_enhanced", false)
	var scene = load("res://scenes/lol2/darker_jungle.tscn").instantiate()
	root.add_child(scene)
	for i in 5: await process_frame
	var p = scene.progression
	print("TREE OWNERSHIP ", p.hinges.keys(), " gate=",scene.get_node_or_null("L8Tree/OriginalTreeDoor50/Collision"))
	check(p != null and p.native != null and p.area_id == "L8_SJ" and p.hinges_enabled and p.hinges.size() == 2 and p.hinges.has(53) and p.hinges.has(54) and not p.hinges.has(50) and scene.has_node("L8Tree/OriginalTreeDoor50/Collision"), "L8: native movers53/54 and sole tree-owned door50 collider")
	if p == null or p.native == null: quit(1); return
	p.change_scene_enabled = false
	var blockers = scene.get_node_or_null("RegionBlockers")
	check(blockers != null and scene.preview_blockers == 859 and p.dynamic_blockers == 5 and blockers.dynamic_enabled, "L8: 859 static edges unchanged, 5 dynamic regions enabled by the binder (%d)" % p.dynamic_blockers)
	check(blockers.is_region_blocked(3277) and blockers.is_region_blocked(3278) and not blockers.is_region_blocked(3455), "L8: data bit 0 — 3277/3278 start blocked, 3455 open (%s)" % [blockers.dynamic_state])
	var active_before: int = blockers.dynamic_active_edges
	check(active_before > 0 and active_before < 19, "L8: some of the 19 dynamic edges are active at start (%d)" % active_before)
	# Stand in the passable neighbour of 3277 (edge 7591,1982 -> 7436,1838) and try to cross into it.
	var player: CharacterBody3D = scene.player
	var stand := Vector3(7568, 32, 1855)
	var inside := Vector3(7404.25, 32, 2009.75)
	player.global_position = stand
	await settle()
	var motion := (inside - stand) * 1.2
	var wall := blocked_by_wall(player, motion)
	check(wall == "RegionBlockers", "L8: the sealed exit region 3277 stops the player (%s)" % wall)
	check(not blockers.inside_blocked(), "L8: standing outside, the blocker layer is on")
	# Opcode 197 arm 0 on 3277 (a synthetic group on the real host; natively group 21504 clears 3277/3278/3457 with arm 5).
	p.native.groups[p.native.group_key(1, 980000)] = [cmd(0, 3277)]
	var r: Dictionary = p.native.execute_group(1, 980000)
	check(str(r.status) == "ran" and r.adapters.is_empty(), "L8: arm 0 on 3277 runs PROVEN (%s)" % [r.get("reasons", [])])
	check(p.blocker_log == [{"region": 3277, "blocked": false, "applied": true}] and not blockers.is_region_blocked(3277), "L8: the host's bit-0 clear opened region 3277 (%s)" % [p.blocker_log])
	# The inbound edges of 3277 go inactive; its own edges into still-blocked neighbours (3278) come alive, so the count may hold.
	var inbound := {}
	for edge in blockers.dynamic_edges: if int(edge.to_dynamic) == 3277: inbound = edge
	check(not inbound.is_empty() and not blockers._edge_active(inbound), "L8: the edges into 3277 are inactive after the open (%d active of 19)" % blockers.dynamic_active_edges)
	await settle()
	wall = blocked_by_wall(player, motion)
	check(wall == "", "L8: nothing stops the player after the open (%s)" % wall)
	# Walk in: the entry event of 3277 (group 1908, movie index 0x1e + level change to level 12 arrival 1) fires.
	player.global_position = inside
	await settle()
	check(p.current_region == 3277, "L8: the player stands in region 3277 (%d)" % p.current_region)
	check(p.level_changes.size() == 1 and int(p.level_changes[0].level) == 12 and int(p.level_changes[0].selector) == 1, "L8: entering the opened exit runs its level change to level 12 arrival 1, the Claw Mountains (%s)" % [p.level_changes])
	check(not blockers.inside_blocked(), "L8: inside an open region the blocker layer stays on")
	# Seal it again (arm 2): the player inside keeps the way out (layer off while inside), the edge is a wall from outside.
	p.native.groups[p.native.group_key(1, 980001)] = [cmd(2, 3277)]
	r = p.native.execute_group(1, 980001)
	check(str(r.status) == "ran" and blockers.is_region_blocked(3277) and p.blocker_log.size() == 2 and bool(p.blocker_log[1].blocked), "L8: arm 2 seals 3277 again (%s)" % [p.blocker_log])
	await settle()
	check(blockers.inside_blocked(), "L8: sealed in, the layer is off so the player can leave")
	player.global_position = stand
	await settle()
	check(not blockers.inside_blocked() and blocked_by_wall(player, motion) == "RegionBlockers", "L8: back outside, the sealed edge stops the player again")
	# A static region's bit is not a blocker toggle (no dynamic region): logged, not applied.
	p.native.groups[p.native.group_key(1, 980002)] = [cmd(0, 41)]
	r = p.native.execute_group(1, 980002)
	check(str(r.status) == "ran" and p.blocker_log.size() == 3 and not bool(p.blocker_log[2].applied), "L8: bit 0 of a region the producer saw no opcode 197 touch is logged, not toggled (%s)" % [p.blocker_log[2] if p.blocker_log.size() > 2 else {}])
	scene.queue_free(); await process_frame
	# L10_DC: ten dynamic regions, all open in the data; arm 4 on 1864 (what group 11480 does) closes the 797 -> 1864 edge.
	scene = load("res://scenes/lol2/maps/L10_DC.tscn").instantiate()
	root.add_child(scene)
	for i in 5: await process_frame
	p = scene.progression
	p.change_scene_enabled = false
	blockers = scene.get_node_or_null("RegionBlockers")
	check(p.dynamic_blockers == 10 and scene.preview_blockers == 766 and not blockers.is_region_blocked(1864), "L10: 10 dynamic regions enabled, 766 static edges, 1864 open at start")
	# 1864 is a 4-unit gate slot (the row 1864-1881 at z -2318), too narrow for the player's capsule: a ray on the blocker
	# layer from region 797's centre into it tells whether the 797 -> 1864 edge is a wall.
	stand = Vector3(3339.13, 32, -2470.81)
	inside = Vector3(3320.25, 32, -2309.5)
	await settle()
	var query := PhysicsRayQueryParameters3D.create(stand, inside, blockers.LAYER)
	var space: PhysicsDirectSpaceState3D = scene.player.get_world_3d().direct_space_state
	var hit: Dictionary = space.intersect_ray(query)
	check(hit.is_empty(), "L10: no blocker wall on the way into the open region 1864 (%s)" % [hit.get("collider")])
	p.native.groups[p.native.group_key(1, 980003)] = [cmd(4, 1864)]
	r = p.native.execute_group(1, 980003)
	check(str(r.status) == "ran" and blockers.is_region_blocked(1864) and p.blocker_log.size() == 1, "L10: arm 4 on 1864 closes it (%s)" % [p.blocker_log])
	await settle()
	hit = space.intersect_ray(query)
	check(not hit.is_empty() and str(hit.collider.name) == "RegionBlockers", "L10: the closed gate slot 1864 is now a blocker wall (%s)" % [hit.get("collider")])
	scene.queue_free(); await process_frame
	print("region blockers toggle: %d failures" % failures)
	if failures == 0: print("PASS region blockers toggle: opcode 197 bit-0 writes open/seal dynamic regions live (L8 3277 exit walked into, level change to L12 fires; L10 1864 closed), static sets unchanged")
	quit(0 if failures == 0 else 1)
