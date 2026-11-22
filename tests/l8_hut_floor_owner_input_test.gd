extends "res://tests/helpers/g15_spell_input.gd"
## Owner F10 2026-11-15 04-41-43, Darker Jungle: on the floor of the raised tree hut (feet 220) "cannot get to the mixer in
## the small hut because of an invisible wall". The blocker of ground strip 2419 (floor 0, ceiling 200 + headroom 1024) rose
## through the hut floor. scripts/lol2/region_blockers.gd ends it at the hut floor (220, headroom 0), as 2417 already was.
## Untouched local owner save (tests/fixtures/l8_hut_inputs_manifest.json); real mouse look and real W.
##  - real W from his own pose crosses the hut floor to its table (Solid67, where he had taken the War Club);
##  - the strip under the hut is still walled at ground height, and the wall ends at the hut floor.
## Red (787c707 without the cut): the body stops at the 2418/2419 edge.
const TABLE := Vector3(-1647, 270, -2681)
const EDGE_A := Vector2(-1665, -2612)
const EDGE_B := Vector2(-1496, -2750)
func _initialize(): main.call_deferred()
func blocker_hit(y: float) -> bool:
	var mid := (EDGE_A + EDGE_B) / 2.0
	var n := (EDGE_B - EDGE_A).orthogonal().normalized()
	var from := Vector3(mid.x + n.x * 40, y, mid.y + n.y * 40)
	var to := Vector3(mid.x - n.x * 40, y, mid.y - n.y * 40)
	var q := PhysicsRayQueryParameters3D.create(from, to, preload("res://scripts/lol2/region_blockers.gd").LAYER)
	q.hit_from_inside = true
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and str(hit.collider.name) == "RegionBlockers"
func main():
	var inputs: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/l8_hut_inputs_manifest.json"))
	var input: String = "res://" + str(inputs.files[0].path)
	if not require(FileAccess.get_sha256(input) == str(inputs.files[0].sha256), "Untouched local owner full save"): return
	if not require(DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Rendered ordinary 1/60"): return
	if not require(preload("res://scripts/lol2/game_save.gd").load_file(self, input).is_empty(), "Actual whole-game owner loader"): return
	await scene_changed
	for tick in 3000:
		await process_frame
		if is_instance_valid(current_scene) and bool(current_scene.get("ready_for_review")): break
	if not require(is_instance_valid(current_scene) and bool(current_scene.get("ready_for_review")), "Owner area ready before sending keys"): return
	use_guard = false; await adopt()
	if not captured(): await lclick(); await frames(3)
	if not require(pos().distance_to(Vector3(-1540, 252, -2694)) < 4.0, "Owner stands on the hut floor at his F10 pose"): return
	if not require(blocker_hit(100.0), "Strip 2419 under the hut is still walled at ground height"): return
	if not require(not blocker_hit(240.0), "The 2419 wall ends at the hut floor"): return
	var reached := false
	for step in 60:
		if Vector2(pos().x - TABLE.x, pos().z - TABLE.z).length() < 45.0: reached = true; break
		if not await look(TABLE): break
		key_event(KEY_W, true); await ticks(6); key_event(KEY_W, false); await frames(2)
	if not require(reached, "Real W crosses the hut floor to the table (at %s)" % pos().snapped(Vector3.ONE)): return
	if not require(pos().y > 240.0, "The body stays on the hut floor"): return
	if not require(hp() > 0 and scene.resets == 0, "Alive, zero recovery"): return
	print("PASS owner hut floor: real W from the owner's 04-41-43 pose crosses the hut floor to the table at ", pos().snapped(Vector3.ONE), "; strip 2419 still walled at ground; ordinary 1/60, untouched save")
	quit()
