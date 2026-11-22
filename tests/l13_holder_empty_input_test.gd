extends "res://tests/generic_l13_chain_input_test.gd"
## Owner F10 2026-11-16T16-25-00 (r19o8): "the empty holder is not empty when I take the stone but I have it". The
## Dreamstone holder is prop record 326 (prop_84), whose five frames all draw the stone. Presentation adapter (lead
## 2026-11-16, DEVIATIONS): once the stone is taken the holder draws a derived frame with the stone cut out
## (tools/prepare_l13_holder_empty.py); a save with the stone untaken draws it with the stone. Proof by real F9 into two
## owner saves (local only): owner_011552 (stone untaken) shows the stone; his 16-25-00 save (taken) shows the empty
## holder. Ordinary 1/60.
const UNTAKEN := "res://tmp/l13_native_use_inputs/owner_011552.json"
const UNTAKEN_SHA := "9a5c770e59d312c0828783ddd8c49d713b12f44068e506b4a4051fb5a3c8316c"
const TAKEN := "res://tmp/l13_holder_inputs/owner_162500.json"
const TAKEN_SHA := "14f6e7f27bb762210404d678e90869a81d9fce1c366be21669ccbcf83a154f04"
func load_slot(path: String) -> bool:
	DirAccess.make_dir_recursive_absolute(Slots.slot_path(1).get_base_dir())
	if not require(DirAccess.copy_absolute(ProjectSettings.globalize_path(path), Slots.slot_path(1)) == OK, "Install %s as slot 1" % path): return false
	await tap(KEY_F9); await adopt()
	for i in 30: await physics_frame
	return require(scene.area_id == "L13_RC", "In the Citadel (got %s)" % scene.area_id)
func holder_scale() -> float:
	var p: Array = scene.prop_placements[326]
	return (p[0] as MultiMesh).get_instance_transform(p[1]).basis.get_scale().x
func empty_shown() -> bool:
	var altar: Node = scene.get_node("L13Altar")
	return is_instance_valid(altar.holder_empty) and altar.holder_empty.visible
func main():
	use_guard = false
	if not require(DisplayServer.get_name() != "headless" and Engine.time_scale == 1.0 and Engine.physics_ticks_per_second == 60, "Rendered ordinary-clock proof"): return
	if not require(FileAccess.get_sha256(UNTAKEN) == UNTAKEN_SHA and FileAccess.get_sha256(TAKEN) == TAKEN_SHA, "Untouched owner saves"): return
	if not require(FileAccess.file_exists("res://assets/lol2/generated/l13_altar/holder_empty.png"), "Empty holder frame prepared"): return
	if not await start_from_f2(): return
	if not await load_slot(UNTAKEN): return
	if not require(not scene.quest_state.get("l13_altar", {}).get("stone_taken", false), "owner_011552: stone untaken"): return
	if not require(holder_scale() > 0.5 and not empty_shown(), "Untaken: the holder draws the stone (scale %.2f, empty %s)" % [holder_scale(), empty_shown()]): return
	if not await load_slot(TAKEN): return
	if not require(scene.quest_state.l13_altar.stone_taken, "His 16-25-00 save: stone taken"): return
	if not require(holder_scale() < 0.01 and empty_shown(), "Taken: the holder is empty (scale %.2f, empty %s)" % [holder_scale(), empty_shown()]): return
	var altar: Node = scene.get_node("L13Altar")
	var p: Array = scene.prop_placements[326]
	if not require(altar.holder_empty.global_position.distance_to(p[2]) < 0.5, "The empty holder stands where the holder stands"): return
	scene.player.position = Vector3(-2674.5, -986.0, -4229.4); scene.player.rotation.y = 2.47; scene.camera.rotation.x = 0.0
	for i in 20: await physics_frame
	await picture("l13_holder_empty")
	print("PASS l13_holder_empty_input: untaken save draws the stone; his taken save draws the empty holder in its place")
	quit()
