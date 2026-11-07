extends SceneTree
## Owner F10 2026-10-24 18:12 (#22): "the chectan point and click do not start just back yard here". Kelsrick's
## gate-line group g5084 ends with op12 control100 -> room14 and op9 control100 property21: the chief's-hut room CHUT
## (docs/jungle-chut-room.md). The owner's own save (talk1 done, g5084 receipts, gate shut, Luther back north in
## region3791) is the reported state: the room never opened. Those two commands must open CHUT; the first visit plays
## 350..364 with flags 152/151 and Met_Kelsrick, survives a save inside the speech, then places Luther at (-1769, -5464)
## facing 150 degrees. A second g5084 finds only the idle room, left with Back.
const FIXTURE := "res://tests/fixtures/owner_r12c_jungle_20261024_2015.json"
const FIXTURE_SHA256 := "e474a40d8af2172363add9472e9e9a3cd774e0e5bf1980b50acb6d2df0ceed40"
const GATE_LINE := Vector2(-1826.0, -5563.0)
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL jungle_chut_room: ", message); quit(1)

func walk_to(target: Vector2, frames: int, until: Callable) -> bool:
	var p: CharacterBody3D = scene.player
	for i in frames:
		if until.call(): return true
		var d := target - Vector2(p.global_position.x, p.global_position.z)
		if d.length() < 4: d = Vector2.ZERO
		var v := Vector3(d.x, 0, d.y).normalized() * 80.0 if d != Vector2.ZERO else Vector3.ZERO
		p.velocity = Vector3(v.x, p.velocity.y - 9.8, v.z)
		p.move_and_slide()
		await physics_frame
	return until.call()

func run() -> void:
	if FileAccess.get_sha256(FIXTURE) != FIXTURE_SHA256: return fail("Owner save fixture changed")
	DirAccess.make_dir_recursive_absolute("user://tests")
	var copy := "user://tests/chut_owner_jungle.json"
	DirAccess.copy_absolute(ProjectSettings.globalize_path(FIXTURE), ProjectSettings.globalize_path(copy))
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate(); root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	if not scene.get("ready_for_review"): return fail("Jungle not ready")
	if not scene.monastery.view.manifest.rooms.has("CHUT"): return fail("CHUT media not staged (tools/prepare_chut_room_media.py)")
	var error: String = scene.quickload(copy)
	if not error.is_empty(): return fail("Owner save rejected: " + error)
	for i in 10: await physics_frame
	var k = scene.kelsrick
	if int(k.state.region) != 3791 or not "091064001500" in k.receipts: return fail("Owner save is not the reported lock-out")
	var rooms = scene.monastery
	var s: Dictionary = rooms.state()
	if not str(s.room).is_empty() or int(s.flags.get("152", 0)) != 0: return fail("Owner save already in CHUT")
	# With the gate shut the gate line (region2750, behind the leaves) is out of reach from region3791: in the original
	# too, CHUT returns Luther outside the shut gate. The owner's save therefore cannot replay the crossing; the room
	# opens from g5084's own last two commands, delivered to the host consumer exactly as Kelsrick's owner emits them.
	var p: CharacterBody3D = scene.player
	p.global_position = Vector3(-1769.0, p.global_position.y + 40.0, -5464.0); p.velocity = Vector3.ZERO
	for i in 40: await physics_frame
	await walk_to(GATE_LINE, 300, func(): return false)
	if int(k.state.region) == 2750: return fail("Gate line reachable through the shut gate")
	for raw in ["0c1064000e00", "091064001500"]: scene._kelsrick_effects({"type": "external", "raw": raw})
	if str(rooms.state().room) != "CHUT": return fail("g5084 op12 room14 + op9 property21 did not open CHUT")
	s = rooms.state()
	if s.conversation.sequence != "CHUT" or scene.is_physics_processing(): return fail("CHUT did not start with the hut-apr intro")
	# Intro, then callback9 admits the first visit.
	rooms.advance(8.0)
	s = rooms.state()
	if s.conversation.sequence != "CHUT_FIRST" or int(s.flags["152"]) != 1: return fail("First visit not admitted: %s" % s.conversation)
	# A save inside the speech restores it.
	rooms.advance(20.0)
	var mid: Dictionary = s.conversation.duplicate()
	if not scene.quicksave(copy).is_empty(): return fail("Save inside CHUT failed")
	error = scene.quickload(copy)
	if not error.is_empty(): return fail("Save inside CHUT rejected: " + error)
	s = rooms.state()
	if s.room != "CHUT" or s.conversation.sequence != "CHUT_FIRST" or int(s.conversation.cursor) != int(mid.cursor): return fail("CHUT speech not restored")
	var steps := 0
	while str(rooms.state().room) == "CHUT" and steps < 400:
		rooms.advance(0.25); steps += 1
		s = rooms.state()
		if s.conversation.get("sequence", "") == "CHUT_FIRST" and int(s.conversation.cursor) == 9 and int(s.flags.get("151", 0)) != 1: return fail("flag151 not set after line358")
	s = rooms.state()
	if not str(s.room).is_empty(): return fail("CHUT did not close after line364")
	if int(s.flags["151"]) != 1 or int(s.locals.get("Met_Kelsrick", 0)) != 1: return fail("First-visit writes missing: %s %s" % [s.flags["151"], s.locals])
	if Vector2(p.position.x, p.position.z).distance_to(Vector2(-1769, -5464)) > 0.5: return fail("Not placed at (-1769,-5464): %s" % p.position)
	if absf(wrapf(p.rotation.y - deg_to_rad(60.0), -PI, PI)) > 0.01: return fail("Not facing 150 degrees (yaw 60): %f" % p.rotation.y)
	var to_kelsrick := (Vector2(-1892, -5475) - Vector2(p.position.x, p.position.z)).normalized()
	if Vector2(-sin(p.rotation.y), -cos(p.rotation.y)).dot(to_kelsrick) < 0.8: return fail("Not facing Kelsrick after CHUT (longplay f_00756)")
	if not scene.is_physics_processing(): return fail("World not resumed after CHUT")
	for i in 30: await physics_frame
	# Second entry (g5084 again): the room opens on its idle only; Back (callback8) places Luther again.
	for raw in ["0c1064000e00", "091064001500"]: scene._kelsrick_effects({"type": "external", "raw": raw})
	if str(rooms.state().room) != "CHUT": return fail("Second g5084 did not open CHUT")
	rooms.advance(8.0)
	s = rooms.state()
	if Speech().active(s.conversation): return fail("Second visit replayed the first-visit lines")
	rooms.leave_room()
	if not str(rooms.state().room).is_empty() or Vector2(p.position.x, p.position.z).distance_to(Vector2(-1769, -5464)) > 0.5: return fail("Back did not leave CHUT to the placement")
	print("PASS jungle_chut_room: owner save state, g5084 room pair -> CHUT, first visit 350..364 (flags 152/151, Met_Kelsrick), placed (-1769,-5464) at 150 deg; revisit idle + Back")
	quit(0)

func Speech(): return preload("res://scripts/lol2/monastery_conversation.gd")
