extends SceneTree
## Enter skips the spoken line (DialogueSkip autoload, owner request 2026-10-22). Real Enter key events through the
## viewport: Kelsrick's talk1 (actor clip family; the jungle input lock passes Enter), Morgan's MGAR room conversation
## line by line to its flag-writing end (room movie family), the village gate speech (single clip) and the Hive
## warrior conversation (sections). Each skip must still apply the line's own completion; Enter with nobody speaking
## is left alone.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const Speech=preload("res://scripts/lol2/monastery_conversation.gd")
const FOOT:=32.0
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	func world_active() -> bool: return true
var scene
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL dialogue_skip: ",message); quit(1); return false
func enter() -> bool:
	var key:=InputEventKey.new();key.keycode=KEY_ENTER;key.pressed=true
	Input.parse_input_event(key);Input.flush_buffered_events()
	var up:=InputEventKey.new();up.keycode=KEY_ENTER;up.pressed=false
	Input.parse_input_event(up);Input.flush_buffered_events()
	await process_frame
	return true
func region_point(ctrl, region: int) -> Vector3:
	for r in ctrl.src.regions:
		if int(r.region)!=region: continue
		var c:=Vector2.ZERO
		for v in r.polygon: c+=Vector2(v[0],v[1])
		c/=r.polygon.size()
		return Vector3(c.x,float(r.floor_min)+FOOT,c.y)+ctrl.origin()
	return Vector3.ZERO
func run() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	for node in [scene.exit_encounter,scene.bacatta,scene.villager_population,scene.dino_population]:
		if node!=null and is_instance_valid(node): node.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var spells:=TestMagic.new();spells.host=scene;scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	for room in [scene.monastery,scene.weapon_shop,scene.magic_shop,scene.departure]: room.set_process(false)
	scene.village_dialogue.set_process(false)
	var skip=root.get_node("DialogueSkip")
	if skip.skip(): return fail("Enter skipped with nobody speaking")
	# 1. Kelsrick talk1 (selector 9 segment 1) after the village speech: one Enter ends it and releases the hold.
	var ctrl=scene.kelsrick
	ctrl.set_physics_process(false)
	scene.quest_state.monastery={"globals":{"GV_LUTHERS_SOUL":5}} if not scene.quest_state.has("monastery") else scene.quest_state.monastery
	scene.village_gate.state().local24=1
	var d: Dictionary=scene.village_dialogue.state();d.started=true;d.elapsed=preload("res://scripts/lol2/jungle_village_state.gd").SPEECH_DURATION;d.local15=1
	scene.player.global_position=ctrl.origin()+Vector3(9000,0,9000);ctrl.advance(1.0/30.0)
	scene.player.global_position=region_point(ctrl,3567);ctrl.advance(1.0/30.0)
	if ctrl.state.clip.is_empty() or int(ctrl.state.clip.selector)!=9 or not scene.actor_input_locked(): return fail("Kelsrick talk1 did not start")
	ctrl.advance(0.5)
	await enter()
	ctrl.advance(1.0/30.0)
	if not ctrl.state.clip.is_empty() or ctrl.input_locked(): return fail("Enter did not end Kelsrick's line: %s" % ctrl.state.clip)
	# 2. Morgan's MGAR conversation: each Enter moves one line; the end still writes flags 176-178.
	var rooms=scene.monastery
	if not (rooms.enter_room("MENT") and rooms.enter_room("MGAR")): return fail("Could not enter MGAR")
	var speech: Dictionary=rooms.state().conversation
	if speech.sequence!="MGAR" or not Speech.active(speech): return fail("Morgan did not start speaking: %s" % speech)
	var lines:=0
	while Speech.active(rooms.state().conversation) and lines<40:
		var cursor:=int(rooms.state().conversation.cursor)
		await enter()
		lines+=1
		if Speech.active(rooms.state().conversation) and int(rooms.state().conversation.cursor)!=cursor+1: return fail("Enter did not move exactly one line")
	if lines!=Speech.FRAMES["MGAR"].size(): return fail("MGAR took %d skips" % lines)
	for flag in ["176","177","178"]:
		if int(rooms.state().flags.get(flag,0))!=1: return fail("Skipped MGAR end lost flag %s" % flag)
	rooms.leave_room();rooms.leave_room()
	# 3. Village gate speech: one Enter completes it (local15, source group21174).
	d.started=false;d.elapsed=0.0;d.local15=0
	if not scene.village_dialogue.begin(): return fail("Village speech did not begin")
	await enter()
	if int(d.local15)!=1 or scene.village_dialogue.active(): return fail("Enter did not complete the village speech")
	if skip.skip(): return fail("Enter skipped with nobody speaking (after)")
	scene.queue_free()
	await process_frame
	# 4. Hive warrior conversation: each Enter ends a section; the last one finishes the conversation.
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive);current_scene=hive
	for i in range(5): await process_frame
	var conv=hive.get_node("ConversationReview")
	conv.room_entered=true
	if not conv.begin(): return fail("Hive conversation did not begin")
	var sections:=0
	while not conv.completed and sections<20:
		await enter();sections+=1
	if not conv.completed or sections!=conv.data.order.size(): return fail("Hive conversation took %d skips" % sections)
	if not hive.is_physics_processing(): return fail("Hive movement still locked after the skipped conversation")
	hive.queue_free()
	await process_frame
	print("PASS dialogue_skip: Enter ends Kelsrick's talk1 and releases the hold; MGAR %d lines one per Enter with flags 176-178; village speech local15; Hive conversation %d sections; no skip with nobody speaking" % [lines,sections])
	quit(0)
