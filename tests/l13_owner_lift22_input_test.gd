extends "res://tests/l13_pink_ledge_input_test.gd"
## Owner's own Citadel test on r19o4 (F10 01-12-02 .. 01-22-38, 2026-11-16; lead TOP): stopped at the web on "Something
## still lives here. One waits above the lift." His saves never broke the light fixture over the egg basin
## (l13_eggs.vent_broken false), and in r19o4 every Ruloi flight, Ruloi 22's ledge glide included, waited for it; 22 and
## the four on the 140-high ledges (23-26) never came down. Lead rule: 22 engages wherever the player meets the lift,
## either end; the web line names the real blocker. His own save 01-18-19 (health 30, fixture intact, lift at the
## bottom) by real F9 from the Citadel F2 start; nothing written. Disclosed placements: the web, the lift-call spot at the
## top, the lift deck at the bottom. Real mouse aim; ordinary 1/60.
const OWNER := "res://tmp/l13_hint_inputs/owner_011819.json"
const OWNER_SHA := "8979cb0fff85426c64d102930b7c622e475d0546416dac53ec1dad02957f2881"
const WEB := Vector3(-5577.3, 42.0, -157.0)
const LIFT_CALL := Vector3(-4779.0, 28.0, 3256.0)
const LIFT_BOTTOM := Vector3(-4716.0, -940.0, 3021.0)
func body() -> CharacterBody3D: return scene.act2_creatures.bodies["22"]
## The glide keeps the Ruloi flight speed (about 48 a second): from the ledge to the lift bottom is about 24 s.
func comes_down(label: String) -> bool:
	for tick in 2400:
		await physics_frame
		var d: Vector3 = scene.player.global_position - body().global_position
		if absf(d.y) < 40.0 and Vector2(d.x, d.z).length() < 120.0: return true
	return require(false, "Ruloi 22 comes down to Luther at %s (22 at %s, Luther %s)" % [label, body().global_position, pos()])
func load_his() -> bool:
	DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
	if not require(DirAccess.copy_absolute(ProjectSettings.globalize_path(OWNER), Slots.slot_path(1)) == OK, "Install the owner's save as slot 1"): return false
	await tap(KEY_F9); await adopt()
	for i in 30: await physics_frame
	if not captured(): await lclick(); await frames(4)
	return true
func main():
	use_guard = false
	if not require(DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Rendered ordinary-clock proof"): return
	if not require(FileAccess.get_sha256(OWNER) == OWNER_SHA, "Untouched owner save 01-18-19"): return
	if not await start_from_f2(): return
	if not await load_his(): return
	if not require(not scene.quest_state.get("l13_eggs", {}).get("vent_broken", true), "His save: the light fixture is intact"): return
	if not require(float(scene.act2_creatures.state.actors["22"].health) > 0 and body().global_position.y > 120.0, "His save: 22 on its ledge above the lift"): return
	# 1. At the web: the original control:103 has no Ruloi predicate, so with ten alive the web offers its entry. The count,
	# the fixture and the lift go in the maidens' line (their all-Ruloi condition, prop:253 / local 18).
	scene.player.position = WEB; scene.player.velocity = Vector3.ZERO
	for i in 60: await physics_frame
	await look(scene.get_node("L13Belial").WEB + Vector3.UP * 32.0)
	for i in 20: await physics_frame
	var hints: Node = scene.find_child("ChainActionHints", true, false)
	if not require(hints != null and str(hints.label.text) == "E - pass the web", "His state: the web is open (got '%s')" % (hints.label.text if hints else "?")): return
	await picture("owner_web_open")
	var line: String = preload("res://scripts/lol2/l13_action_hint_targets.gd").maidens_line(scene)
	if not require(line.begins_with("The maidens stay until every Ruloi is dead: 10 still live.") and "light fixture above the eggs" in line and "above the lift" in line, "The maidens' line counts ten (his 01-18-19 save), names the fixture and the lift (got '%s')" % line): return
	# 2. At the lift top, fixture intact, 22 comes down.
	scene.player.position = LIFT_CALL; scene.player.velocity = Vector3.ZERO
	if not await comes_down("the lift top"): return
	# 3. His save again; on the lift deck at the bottom, 22 comes down the shaft too.
	if not await load_his(): return
	scene.player.position = LIFT_BOTTOM; scene.player.velocity = Vector3.ZERO
	if not await comes_down("the lift bottom"): return
	await picture("owner_lift_bottom_22")
	print("PASS l13_owner_lift22_input: his save, fixture intact: the web is open, the maidens' line counts ten and names the fixture and the lift; 22 comes down at the lift top and at the bottom")
	quit()
