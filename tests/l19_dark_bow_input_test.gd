extends "res://tests/generic_l13_chain_input_test.gd"
## Grok 2026-11-16 19:53Z on r19o8 (owner road, game-written Belial arrival autosave sha cb34052f): in Belial's Laboratory the
## screen said "The three slotted switches want the Human and a bow." He carried the City's Dark Bow, but the pack could not put
## it in the hand ('Hold in hand' left the Dark Sword): the catalog gave it the empty slot of every Act 2 world row, though it
## is the same definition 35 "36-Darkbow" as the Blue Bow. Proof from his save (local only), real F9, real pack clicks ('Hold
## in hand'), real left clicks at the three switches. Disclosed aids, as l19_sewer_forms_earned: the body is set in front of
## each switch and the camera aimed at it.
const SAVE := "res://tmp/l19_bow_inputs/grok_cb34052f.json"
const SAVE_SHA := "cb34052f0bc56c41b29a95b6f3c8d84d9e9ef676cc1a8aaef1867bd621a128ad"
const DARK_BOW := "act2:L16_CA:item24"
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
	if not require(scene.area_id == "L19_BC", "His save: Belial's Laboratory (got %s)" % scene.area_id): return
	if not require(DARK_BOW in scene.carried_collected, "He carries the Dark Bow"): return
	if not await pack_use(DARK_BOW, "Hold in hand", "dark bow"): return
	if not require(str(scene.hand_item) == DARK_BOW, "Hold in hand puts the Dark Bow in the hand (hand %s, weapon %s)" % [scene.hand_item, scene.equipped_item]): return
	var forms: Node = scene.get_node("L19SewerForms")
	for raw in [forms.AIM_74, forms.AIM_75, forms.AIM_76]:
		var point: Vector3 = raw
		scene.player.position = Vector3(point.x, 22.0, -2088.0); scene.player.velocity = Vector3.ZERO
		for i in 6: await physics_frame
		scene.camera.global_position = scene.player.global_position + Vector3(0, 8, 0)
		scene.camera.look_at(point, Vector3.UP)
		await frames(2)
		if not require(forms.hint.text == "Shoot the slotted switch.", "At the switch the screen says 'Shoot the slotted switch.' (got '%s')" % forms.hint.text): return
		await lclick(); await frames(10)
	var got: Array = forms.state().switches
	print("SWITCHES ", got)
	if not require(got.size() == 3, "The three slotted switches take the Dark Bow's shots (got %s)" % [got]): return
	print("PASS l19_dark_bow_input: his save; 'Hold in hand' puts the Dark Bow in the hand; the three slotted switches take it")
	quit()
