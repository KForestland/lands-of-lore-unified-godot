extends "res://tests/generic_l13_chain_input_test.gd"
## Grok r19o3 04:02Z STOP on the owner's life (lead 2026-11-16): in the Chamber of Voices the screen says "Remember
## Dawn's warning: fight in Beast form" and "G - Change form"; G did nothing and said nothing. His save holds the
## Dreamstone in the pack; at his stand (42, 9.4, 11263.2) on a step edge of the stepped arena floor the Beast body has
## no room and the curse waited silently. Now the wait says why, and a missing stone says so. Second, the owner's rule:
## the Dreamstone cannot be left behind; once a slot has done its work, walking away returns it to the pack with a line.
## Grok's own F5 at the chamber landing by real F9 from the Citadel F2 start; nothing written. Disclosed placements:
## Grok's stand, the spiral approach. Disclosed state setups: the stone put back in the spiral slot (a player who left
## it there), the stone taken out of the pack, the spiral reset to unvisited. Real keys and mouse; ordinary 1/60.
const SAVE := "res://tmp/l14_dream_inputs/grok_chamber_landing.json"
const SAVE_SHA := "e613c55ac07436f556ae8a010f4a1cf92a51812a93f7dbfb60fa6fcfcb8fde34"
const STONE := "act2:L13_RC:dreamstone"
const GROK_STAND := Vector3(42.0, 9.4, 11263.2)
const SPIRAL_APPROACH := Vector3(700.0, 40.0, -3453.0)
const Belial = preload("res://scripts/lol2/l14_belial.gd")
const WalkAway = preload("res://scripts/lol2/dreamstone_walk_away.gd")
func load_it() -> bool:
	DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
	if not require(DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE), Slots.slot_path(1)) == OK, "Install Grok's chamber-landing save as slot 1"): return false
	await tap(KEY_F9); await adopt()
	for i in 30: await physics_frame
	if not captured(): await lclick(); await frames(4)
	return require(scene.has_node("L14Belial") and pos().distance_to(Vector3(42, 22, 11041)) < 4.0, "His F5: the chamber landing (at %s)" % pos())
func belial() -> Node: return scene.get_node("L14Belial")
func spiral() -> Node: return scene.get_node("L14Spiral")
func at(p: Vector3) -> void:
	scene.player.position = p; scene.player.velocity = Vector3.ZERO
	for i in 40: await physics_frame
func main():
	use_guard = false
	if not require(DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Rendered ordinary-clock proof"): return
	if not require(FileAccess.get_sha256(SAVE) == SAVE_SHA, "Untouched Grok save"): return
	if not await start_from_f2(): return
	if not await load_it(): return
	if not require(STONE in scene.carried_collected and spiral().state().slots["temple:dreamstone_slot72"].occupied == "", "His save: the stone is in the pack, the spiral slot is empty"): return
	# 1. Grok's stand on the step edge: G starts the change, there is no room, and the screen says so.
	await at(GROK_STAND)
	await look(scene.act2_creatures.bodies["90"].global_position + Vector3.UP * 40.0)
	if not require(belial().near_boss() and belial().hint.text.begins_with("G — Change form"), "At his stand the screen offers G (got '%s')" % belial().hint.text): return
	await tap(KEY_G)
	for i in 300: await physics_frame
	if not require(scene.player_form == 0 and belial().hint.text == Belial.NO_ROOM, "No room for the Beast on the step edge, and the screen says so (form %d, got '%s')" % [scene.player_form, belial().hint.text]): return
	await picture("no_room_step_edge")
	# Walking on onto open floor, the waiting change comes.
	key_event(KEY_W, true)
	var changed := false
	for i in 120:
		await physics_frame
		if scene.player_form == 1: changed = true; break
	key_event(KEY_W, false)
	if not require(changed, "Walking on, the Beast comes (at %s)" % pos()): return
	await picture("beast_after_step")
	# 2. No stone in the pack (disclosed: taken out): G says what is missing.
	if not await load_it(): return
	scene.carried_collected.erase(STONE)
	await at(GROK_STAND)
	await tap(KEY_G)
	for i in 10: await physics_frame
	if not require(scene.player_form == 0 and hud() == Belial.NO_STONE, "Without the stone G says why (got '%s')" % hud()): return
	# 3. The stone left in the spiral slot (disclosed: put back): far from the slot it returns to the pack with a line.
	if not await load_it(): return
	var s: Dictionary = spiral().state().duplicate(true)
	s.slots["temple:dreamstone_slot72"].occupied = STONE
	scene.carried_collected.erase(STONE)
	scene.quest_state["l14_spiral"] = s
	for i in 5: await physics_frame
	if not require(STONE in scene.carried_collected and spiral().state().slots["temple:dreamstone_slot72"].occupied == "" and hud() == WalkAway.LINE, "Left in the slot, the stone comes back at the chamber (got '%s')" % hud()): return
	await at(GROK_STAND)
	await tap(KEY_G)
	for i in 300: await physics_frame
	if not require(int(scene.curse.state.phase) in [1, 2] or scene.player_form == 1, "With the stone back, G starts the change"): return
	# 4. A fresh spiral visit (disclosed: slot reset to unvisited): real E places the stone and the stair rises; walking
	# back down the approach without E, the stone returns with the line and the stair stays up.
	if not await load_it(): return
	scene.quest_state["l14_spiral"] = spiral().initial()
	spiral().restore()
	await at(SPIRAL_APPROACH)
	await look(spiral().POINT)
	for i in 10: await physics_frame
	if not require(spiral().hint.text == "E — Place Dreamstone", "At the slot the screen offers E (got '%s')" % spiral().hint.text): return
	await tap(KEY_E)
	for i in 10: await physics_frame
	if not require(spiral().committed(spiral().state()) and STONE not in scene.carried_collected, "Real E: the stone is in the slot and the stair rises"): return
	key_event(KEY_S, true)
	var back := false
	for i in 900:
		await physics_frame
		if STONE in scene.carried_collected: back = true; break
	key_event(KEY_S, false)
	var away: float = pos().distance_to(spiral().POINT)
	if not require(back and hud() == WalkAway.LINE and away > WalkAway.LEAVE - 10.0, "Walking away the stone returns with the line (%.0f from the slot, got '%s')" % [away, hud()]): return
	for i in 300: await physics_frame
	if not require(spiral().state().raised == 4.0 and spiral().committed(spiral().state()), "The stair stays up"): return
	await picture("stone_back_walking_away")
	print("PASS l14_dreamstone_beast_input: Grok's save: no room on the step edge is said and walking on brings the Beast; no stone is said; a stone left in the slot or walked away from returns with a line")
	quit()
