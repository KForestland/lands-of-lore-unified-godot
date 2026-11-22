extends "res://tests/helpers/owner_gaps_input.gd"
## Owner F10 2026-11-16T16-30-04 on r19o8 (lead: FREEZE): at the Claw Mountains lake switch (3394, -6626, H -218) real E
## raised the lake platforms ("The lake platforms rise.") and the game stood still for 7 s: his E release, a W tap and F10
## arrive in the bundle at one instant (137.066), the 3 s frame recorder has no frame after 128.06. Cause: the switch
## starts ten floor regions in one call, and every region's deck claim re-read and re-parsed the 5.2 MB L12 geometry
## pack (act2_progression _claim_region_floor), ten times on one frame. Fix: one parse per frame, shared by every claim
## made in it. Proof: the pinned owner input before the pull (l12_platform), real W/E at the switch, the longest frame
## while the claims run stays under 400 ms and the platform rises; then his own bundle save (local only, taken after
## the pull) enters by real F9 and the rise continues to its top. Local stand disclosed as in owner_l12_tiger_input.
const BUNDLE := "res://tmp/l12_lever_inputs/owner_163004.json"
const BUNDLE_SHA := "f4f23faa6670c5776b665c4abe4772ab139ad50ba1ef2850fd95ca1250b80241"
const LIMIT_MS := 400
var longest_ms := 0
var last_us := 0
func watch() -> void:
	var now := Time.get_ticks_usec()
	if last_us > 0: longest_ms = maxi(longest_ms, int((now - last_us) / 1000))
	last_us = now
func run():
	if not check(FileAccess.get_sha256(BUNDLE) == BUNDLE_SHA, "Untouched owner bundle save 16-30-04"): return
	if not await boot_owner("L12_CM", "l12_platform"): return
	if not check(not scene.quest_state.get("l12_tiger_platform", {}).get("activated", false), "Owner input is before the pull"): return
	scene.player.position = Vector3(3430, -218, -6500); scene.player.velocity = Vector3.ZERO
	scene.set_physics_process(true); await ticks(6); await look(Vector3(3430, -218, -6580)); await hold_key(KEY_W, 6)
	process_frame.connect(watch); longest_ms = 0; last_us = Time.get_ticks_usec()
	await key(KEY_E); await ticks(30)
	process_frame.disconnect(watch)
	print("LEVER longest frame %d ms" % longest_ms)
	if not check(scene.quest_state.get("l12_tiger_platform", {}).get("activated", false), "Real E at the lake switch pulls it"): return
	if not check(longest_ms < LIMIT_MS, "Pulling the switch does not stall the game (longest frame %d ms, limit %d)" % [longest_ms, LIMIT_MS]): return
	if not check(scene.progression.floor_motion.has(1899), "The platform rises"): return
	# His own save, written after the pull: real F9 into it, the platforms reach their top.
	var file := FileAccess.open(Saves.slot_path(1), FileAccess.WRITE); file.store_buffer(FileAccess.get_file_as_bytes(BUNDLE)); file.close()
	if not await reload(): return
	await ticks(600)
	print("BUNDLE platform 1899 at %d" % int(scene.progression.regions[1899][1]))
	if not check(int(scene.progression.regions[1899][1]) == -150, "His save: platform 1899 at its top (-150)"): return
	# Owner F10 16-32-02 (the smear at the raised lake): each raised platform stands on a solid ice column.
	var columns := 0
	for region in [1901, 1828, 1897, 1905, 1907, 1902, 1898, 1900, 1906, 1899]:
		var deck: Node3D = scene.progression.floor_decks.get(region)
		if deck != null and deck.has_node("IceColumn"): columns += 1
	if not check(columns == 10, "All ten raised platforms stand on ice columns (got %d)" % columns): return
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	var ray := PhysicsRayQueryParameters3D.create(Vector3(3979.3, -240.0, -9023.4), Vector3(3870.0, -240.0, -8900.0))
	ray.exclude = [scene.player.get_rid()]
	var hit: Dictionary = space.intersect_ray(ray)
	if not check(not hit.is_empty() and str(hit.collider.name) == "IceColumn", "From his 16-32-02 spot the 1899 column is solid (hit %s)" % (hit.get("collider").name if not hit.is_empty() else "nothing")): return
	scene.player.position = Vector3(3979.3, -243.0, -9023.4); scene.player.velocity = Vector3.ZERO; scene.player.rotation.y = 2.484; scene.camera.rotation.x = 0.0098
	for i in 10: await process_frame
	await frame("lake_raised_columns")
	print("PASS l12_lake_lever_freeze_input: real E at the lake switch, longest frame %d ms; his 16-30-04 save loads with the platforms up on ice columns" % longest_ms)
	quit()
