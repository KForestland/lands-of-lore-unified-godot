extends "res://tests/generic_l13_chain_input_test.gd"
## Grok 2026-11-16 20:59Z/21:50Z (owner road, r19o8): on L19's main road gate mover 69 (hinge 717, -125, -367) and Golden
## Door 51 (hinge 2550, -100, -854) opened on E when aimed but the screen named nothing. From Grok's game-written L19 save
## (local only), real F9; at each of Grok's stands (pose aid) facing the hinge: the screen says 'E — Open the gate' /
## 'E — Open the door', real E opens it, the line goes.
const SAVE := "res://tmp/l19_bow_inputs/grok_cb34052f.json"
const SAVE_SHA := "cb34052f0bc56c41b29a95b6f3c8d84d9e9ef676cc1a8aaef1867bd621a128ad"
const CASES := [
	[69, Vector3(737, -98, -343), Vector3(717, -125, -367), "E — Open the gate"],
	[51, Vector3(2530, -68, -839), Vector3(2550, -100, -854), "E — Open the door"],
]
func main():
	use_guard = false
	if not require(DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Rendered ordinary-clock proof"): return
	if not require(FileAccess.get_sha256(SAVE) == SAVE_SHA, "Untouched Grok save"): return
	if not await start_from_f2(): return
	DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
	if not require(DirAccess.copy_absolute(ProjectSettings.globalize_path(SAVE), Slots.slot_path(1)) == OK, "Install his save as slot 1"): return
	await tap(KEY_F9); await adopt()
	for i in 30: await physics_frame
	if not captured(): await lclick(); await frames(4)
	if not require(scene.area_id == "L19_BC", "L19 (got %s)" % scene.area_id): return
	var prog: Node = scene.progression
	for row in CASES:
		var id: int = row[0]
		if not require(int(prog.travel.get(id, 0)) == 0, "Movable %d starts closed" % id): return
		scene.player.position = row[1]; scene.player.velocity = Vector3.ZERO
		for i in 20: await physics_frame
		await look(row[2])
		for i in 4: await physics_frame
		print("AT %d aimed %d line '%s'" % [id, prog.aimed(), prog.interaction_hint.text])
		if not require(prog.interaction_hint.text == row[3], "Facing movable %d the screen says '%s' (got '%s', aimed %d)" % [id, row[3], prog.interaction_hint.text, prog.aimed()]): return
		await tap(KEY_E)
		for i in 90: await physics_frame
		if not require(int(prog.travel.get(id, 0)) != 0, "Real E opens movable %d" % id): return
		if not require(prog.interaction_hint.text == "", "The open one no longer asks (got '%s')" % prog.interaction_hint.text): return
	print("PASS l19_road_doors_prompt_input: gate 69 and Golden Door 51 name their E and open on it")
	quit()
