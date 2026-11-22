extends "res://tests/l13_pink_ledge_input_test.gd"
## Owner road, save 04-56-17 (Grok STOP 2026-11-15 14:31Z, frame l13_web_ruloi22.png): the web stayed shut on
## "Something still lives here." while Ruloi 22 stood on its ledge 139 above the lift, never moving; Spark 3 did
## not reach it. Lead ruling 14:3xZ: the web line says where, and at the lift it comes down to the player's height
## and can be killed with plain sword hits. His save by real F9 from the Citadel F2 start. Disclosed: the vent is
## marked broken (Grok broke it with Spark in his session; that chain is proven by the L13 vent tests) and two
## placements, at the web and at the lift-call spot where Grok stood (-4779, H -4, 3256). Real mouse aim and left
## clicks with his own weapon; ordinary 1/60.
const OWNER := "res://tmp/l13_hint_inputs/owner_045617.json"
const OWNER_SHA := "68b003e00c7b4e6fa8459e3d4ecd8f126075adc1a72310bcd5851b90d1bc66c4"
const WEB := Vector3(-5577.3, 42.0, -157.0)
const LIFT_CALL := Vector3(-4779.0, 28.0, 3256.0)
func actor() -> Dictionary: return scene.act2_creatures.state.actors["22"]
func body() -> CharacterBody3D: return scene.act2_creatures.bodies["22"]
func main():
	use_guard = false
	if not require(DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Rendered ordinary-clock Ruloi 22 proof"): return
	if not require(FileAccess.get_sha256(OWNER) == OWNER_SHA, "Untouched owner save 04-56-17"): return
	if not await start_from_f2(): return
	if not require(DirAccess.copy_absolute(ProjectSettings.globalize_path(OWNER), Slots.slot_path(1)) == OK, "Install the owner's save as slot 1"): return
	await tap(KEY_F9); await adopt()
	for i in 30: await physics_frame
	if not captured(): await lclick(); await frames(4)
	if not require(float(actor().health) > 0 and body().global_position.y > 120.0, "Ruloi 22 lives on its ledge above the lift in his save (at %s)" % body().global_position): return
	var eggs: Dictionary = scene.quest_state.get("l13_eggs", {}).duplicate(true); eggs["vent_broken"] = true; scene.quest_state["l13_eggs"] = eggs
	# 1. At the web the line says where the last one waits.
	scene.player.position = WEB; scene.player.velocity = Vector3.ZERO
	for i in 60: await physics_frame
	await look(scene.get_node("L13Belial").WEB + Vector3.UP * 32.0)
	for i in 20: await physics_frame
	var hints: Node = scene.find_child("ChainActionHints", true, false)
	# The web follows native control:103 (no Ruloi predicate, lead 2026-11-16); the all-Ruloi count is the maidens'.
	if not require(hints != null and str(hints.label.text) == "E - pass the web", "The web is not held by the living Ruloi (got '%s')" % (hints.label.text if hints else "?")): return
	var Targets = preload("res://scripts/lol2/l13_action_hint_targets.gd")
	if not require("above the lift" in Targets.maidens_line(scene), "The maidens' line names 22 above the lift (got '%s')" % Targets.maidens_line(scene)): return
	await picture("ruloi22_web_line")
	# 2. At the lift-call spot it leaves its ledge and comes down to his height.
	scene.player.position = LIFT_CALL; scene.player.velocity = Vector3.ZERO
	var came := false
	for tick in 900:
		await physics_frame
		var d: Vector3 = scene.player.global_position - body().global_position
		if absf(d.y) < 20.0 and Vector2(d.x, d.z).length() < 80.0: came = true; break
	if not require(came, "Ruloi 22 comes down to Luther's height at the lift (at %s, Luther %s)" % [body().global_position, pos()]): return
	await picture("ruloi22_down")
	# 3. Plain sword hits: real aim, real left clicks.
	var health_before := float(actor().health)
	for tick in 3600:
		if float(actor().health) <= 0: break
		if tick % 6 == 0: await look(body().global_position + Vector3(0, 20, 0))
		if tick % 30 == 0: await lclick()
		else: await physics_frame
		if hp() <= 0: break
	if not require(hp() > 0, "Luther lives through the fight"): return
	if not require(float(actor().health) <= 0, "Plain sword hits kill Ruloi 22 (health %s of %s)" % [actor().health, health_before]): return
	# 4. With 22 dead the maidens' line no longer points at the lift.
	if not require(not "above the lift" in Targets.maidens_line(scene) and "still live" in Targets.maidens_line(scene), "With 22 dead the maidens' line drops the lift (got '%s')" % Targets.maidens_line(scene)): return
	print("PASS l13_ruloi22_owner_input: owner save, the web is open, the maidens' line names the lift, 22 comes down at the lift and dies to plain sword hits")
	quit()
