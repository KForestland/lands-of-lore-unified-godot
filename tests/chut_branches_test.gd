extends SceneTree
## Headless, actual Jungle host: the chief's-hut branches that were unhosted (CHUT_BRANCHES_DECODE_20261027).
## - Branch B: on a later visit (first visit done) a weapon strike kills Anyar: Anyar_Attacked (Kelsrick local 33),
##   the Huline alert, Soul -1, flag 150, her death clip then cue 100:17, the two stone piles; six pile clicks give six
##   Ancients' Stones (cue 2:30 on the first), a seventh gives nothing; a full pack refuses before the flag; a later
##   visit shows the piles and ignores strikes; disk save/load mid-clip resumes.
## - Branch A: entering after Kelsrick was struck: line 365 at once, then Luther is thrown out at (-1749, -5457)
##   facing 286 with the alert and Anyar_Attacked; a strike or an offer has no window before that.
## - Empty hut: after the Kelsrick-dead speech (flag 153) the hut shows nobody and strikes do nothing.
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
const Save = preload("res://scripts/lol2/jungle_save.gd")
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
var jungle
var rooms
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> bool:
	if not ok:
		failures += 1
		push_error("FAIL: "+label)
	return ok
func bank() -> Dictionary: return rooms.state()
func speech() -> Dictionary: return bank().get("conversation",Speech.initial())
func settle() -> void:
	for i in range(64):
		rooms.advance(1000.0)
		if not Speech.active(speech()): break
func shared29() -> int: return int(jungle.village_gate.state().shared29) if is_instance_valid(jungle.get("village_gate")) else -1
func soul() -> int: return int(bank().globals.get("GV_LUTHERS_SOUL",5))
func local33() -> int: return int(jungle.kelsrick.state.locals.get("33",0))
func stones() -> int: return jungle.carried_collected.filter(func(id): return str(id).begins_with("jungle:chut:Ancients_Stone_")).size()
func click_stone(index: int) -> bool:
	for hit in rooms.hotspots:
		if hit.get_meta("chut_stone",-1) == index and hit.visible:
			var event := InputEventMouseButton.new(); event.button_index = MOUSE_BUTTON_LEFT; event.pressed = true
			hit.gui_input.emit(event)
			return true
	return false
func fresh() -> void:
	jungle.quest_state.monastery = preload("res://scripts/lol2/monastery_quest_state.gd").initial()
	jungle.carried_collected.assign([Save.Museum.SWORD])
	if is_instance_valid(jungle.get("village_gate")): jungle.village_gate.state().shared29 = 0
	jungle.kelsrick.state.locals["52"] = 0; jungle.kelsrick.state.locals["33"] = 0
	rooms.restore()
func enter_hut() -> bool:
	if not rooms.enter_room("CHUT"): return false
	settle() # the hut-apr intro, then callback 9
	return rooms.active() and bank().room == "CHUT"
func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	jungle = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(jungle); current_scene = jungle
	for i in range(6): await process_frame
	jungle.set_physics_process(false)
	rooms = jungle.monastery
	if not check(rooms != null and rooms.available and rooms.view.manifest.rooms.has("CHUT") and rooms.view.manifest.rooms.CHUT.get("sequences",{}).has("CHUT_KILL"),"CHUT media and the branch media must be staged (tools/prepare_chut_room_media.py, tools/prepare_chut_branch_media.py)"): return finish()
	if not check(is_instance_valid(jungle.get("kelsrick")) and is_instance_valid(jungle.get("village_gate")),"Kelsrick and the village gate must be present"): return finish()
	rooms.set_process(false)
	for key in ["magic_shop","weapon_shop","thieves_den"]:
		var other = jungle.get(key)
		if is_instance_valid(other): other.set_process(false)
	for key in ["kelsrick","bacatta57","dino_population","villager_population","village_alarm","village_gate"]:
		var owner = jungle.get(key)
		if owner != null and is_instance_valid(owner): owner.set_physics_process(false); owner.set_process(false)
	# Branch B on the second visit.
	fresh()
	check(rooms.enter_room("CHUT"),"enter the hut")
	settle_until_sequence("CHUT_FIRST")
	check(speech().sequence == "CHUT_FIRST","first visit plays 350..364")
	settle()
	check(not rooms.active() and int(bank().flags["152"]) == 1,"the first visit ends outside the hut")
	check(enter_hut() and not Speech.active(speech()) and rooms.view.clip.get("idle",false),"second visit: Anyar's idle, nothing said")
	check(rooms.chut_stones[0] != null and not rooms.chut_stones[0].visible,"no stone piles yet")
	var soul_before := soul()
	check(rooms.attack(7) and speech().sequence == "CHUT_KILL","F in the hut: branch B")
	check(int(bank().flags["150"]) == 1 and local33() == 1 and shared29() == 1 and soul() == soul_before-1,"Anyar_Attacked, the alert, Soul -1, flag 150")
	check(rooms.chut_stones[0].visible and rooms.chut_stones[1].visible,"the stone piles appear")
	rooms.advance(1.0)
	var path := "user://tests/chut_branches.json"
	var before: Dictionary = JSON.parse_string(JSON.stringify(bank()))
	check(jungle.quicksave(path).is_empty(),"save during 998")
	rooms.advance(3.0)
	check(jungle.quickload(path).is_empty() and JSON.parse_string(JSON.stringify(rooms.state())) == before,"reload resumes the death clip")
	rooms = jungle.monastery; rooms.set_process(false)
	settle()
	check(not Speech.active(speech()) and rooms.view.patch.texture == null and not rooms.view.clip.get("idle",false),"after the kill: no idle, no leftover frame")
	check(not rooms.attack(7),"a second strike does nothing (flag 150)")
	# Six stones, the first with its cue; a full pack refuses and retries.
	check(click_stone(0) and speech().sequence == "CHUT_STONE" and stones() == 1 and int(bank().flags["154"]) == 1,"first stone with cue 2:30")
	settle()
	var keep: Array = jungle.carried_collected.duplicate()
	var filler: Array = Catalog.ids("jungle").filter(func(id): return not id in keep and not str(id).begins_with("jungle:chut:"))
	while jungle.carried_collected.size() < Catalog.MAX_CARRIED: jungle.carried_collected.append(filler.pop_back())
	check(click_stone(1) and stones() == 1 and int(bank().flags["155"]) == 0,"full pack: refused, flag untouched")
	jungle.carried_collected.assign(keep)
	for i in range(5):
		check(click_stone(i%2) and stones() == 2+i and not Speech.active(speech()),"stone %d silently" % (2+i))
	check(click_stone(0) and stones() == 6,"a seventh click gives nothing")
	for i in range(6): check(int(bank().flags[str(154+i)]) == 1,"flag %d set" % (154+i))
	check(Catalog.use_kind("jungle:chut:Ancients_Stone_1") == "ancient" and Catalog.definition_name("jungle:chut:Ancients_Stone_6") == "66-Ancients stn","the stones are Ancients' Stones")
	check(jungle.quicksave(path).is_empty() and jungle.quickload(path).is_empty() and stones() == 6,"six stones survive the disk")
	rooms = jungle.monastery; rooms.set_process(false)
	rooms.leave_room()
	check(not rooms.active() and is_equal_approx(jungle.player.position.x,-1769) and is_equal_approx(jungle.player.position.z,-5464),"Back places Luther at the gate")
	check(enter_hut() and rooms.chut_stones[0].visible and not rooms.view.clip.get("idle",false) and not rooms.attack(7),"later visit: piles shown, no Anyar, strikes ignored")
	rooms.leave_room()
	# Branch A: entering after Kelsrick was struck.
	fresh()
	jungle.kelsrick.state.locals["52"] = 1
	check(rooms.enter_room("CHUT"),"enter with Kelsrick attacked")
	settle_until_sequence("CHUT_ATTACK")
	check(speech().sequence == "CHUT_ATTACK" and bank().chut_attacked and local33() == 1 and shared29() == 1,"branch A at the first update: 365, Anyar_Attacked, the alert")
	check("kelsrick_attacked_then_hut" in preload("res://scripts/lol2/my_journal.gd").notes(jungle),"branch A records the barred-hut My Journal note")
	check(not rooms.attack(7) and not rooms.offer_item(Save.Museum.SWORD),"no strike or offer while 365 plays")
	rooms.advance(1.0)
	check(jungle.quicksave(path).is_empty() and jungle.quickload(path).is_empty() and jungle.monastery.state().chut_attacked,"the attacked mode survives the disk")
	rooms = jungle.monastery; rooms.set_process(false)
	settle()
	check(not rooms.active() and is_equal_approx(jungle.player.position.x,-1749) and is_equal_approx(jungle.player.position.z,-5457) and is_equal_approx(jungle.player.rotation.y,deg_to_rad(196.0)),"thrown out at (-1749, -5457) facing 286: %s" % [jungle.player.position])
	check(int(bank().flags["152"]) == 0 and int(bank().flags["150"]) == 0,"no first visit, no stones")
	# Empty hut after the Kelsrick-dead speech.
	fresh()
	bank().globals["GV_KELSRICK_DEAD"] = 1
	check(enter_hut() and speech().sequence == "CHUT_DEAD","Kelsrick dead: the dead speech")
	settle()
	check(rooms.active() and int(bank().flags["153"]) == 1 and not rooms.attack(7),"after the speech: strikes do nothing")
	check(rooms.view.clip.get("idle",false) and bank().anyar_present,"Anyar stays in her idle for the rest of this visit ([0xD78] is cleared only by setup)")
	rooms.leave_room()
	check(enter_hut() and not bank().anyar_present and not rooms.view.clip.get("idle",false) and rooms.view.patch.texture == null and not rooms.attack(7),"the empty hut")
	rooms.leave_room()
	DirAccess.remove_absolute(path)
	jungle.queue_free()
	await process_frame
	await process_frame
	finish()
func settle_until_sequence(name: String) -> void:
	for i in range(100000):
		if speech().sequence == name: return
		rooms.advance(0.25)
		if not rooms.active(): return
func finish() -> void:
	if failures:
		push_error("FAIL: %d chief's-hut branch checks" % failures)
		quit(1)
		return
	print("PASS chut branches: branch B (Anyar killed: Anyar_Attacked, alert, Soul -1, flag 150, 998 + cue, stone piles, six stones with cue 2:30, full-pack refusal, disk resume, later visit inert); branch A (entered after striking Kelsrick: 365, thrown out at (-1749,-5457) facing 286, alert, attacked mode saved); the empty hut after the dead speech")
	quit()
