extends SceneTree
## Actual Jungle host, tavern return / Huline alert (docs/tavern-return.md). The village gate is supplied open (its
## rescue admission is covered by jungle_village_gate_test).
## Rooms:
## - Region3501 entry (g7092) sets Left_Village 0->2 once. First visit, then the farewell sets flag34.
## - Later visits while still in the village: 662..666 (flag42, partial save of the audio-only line), 675 (flag43), the
##   flag44 farewell (Bacatta 676/677 only, from CAN_EXIT cursor2), then silence. Bacatta is present throughout.
## - Region3805 entry (g7950), through the real alarm owner: not while paused, 2->3 once, inert without the alert.
## - Return: CAN_MAID 700..709 with Bacatta absent. GV_HULINE_ALERT (village gate shared29) rises only after line707,
##   flag267 after 709. Back in VILLAGE, CAN is refused. Partial save/load mid-sequence; the state survives disk.
## Alarm and routes (production grounded movement, live alarm/gate/Kelsrick/archers):
## - Outward escape: from the tavern through the passage. The alarm fires and shuts the gate behind Luther, who walks
##   the reversed source village approach to the Hive entrance and enters the Hive alive.
## - Trapped inside: cross, turn back inside before the gate shuts. The tavern-to-monastery route (no gate) still
##   reaches the monastery hall.
## Legacy monastery saves without flags 42/43/44 validate.
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
const Room = preload("res://scripts/lol2/monastery_quest_state.gd")
const Save = preload("res://scripts/lol2/jungle_save.gd")
const VillageState = preload("res://scripts/lol2/jungle_village_state.gd")
const PASSAGE := Vector2(-1412,-5249)
const OUTSIDE := Vector2(-1300,-5240)
const INSIDE := Vector2(-1479.5,-5169)
const TAVERN := Vector3(-1630,32,-3900)
var scene
var rooms
var a
var routes: Dictionary
var failed := false
var last_hp := -1
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed = true; push_error(message); quit(1)
	return ok
func bank() -> Dictionary: return rooms.state()
func shared29() -> int: return int(scene.village_gate.state().shared29)

func open_jungle(isolated: bool = true) -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene = load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene); current_scene = scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	rooms = scene.monastery; a = scene.village_alarm
	rooms.set_process(false); a.set_physics_process(false); scene.village_gate.set_physics_process(false)
	# Scenario 1 teleports into the threshold repeatedly, so Bacatta57's sealing entry is kept out of it.
	if isolated and is_instance_valid(scene.get("bacatta57")): scene.bacatta57.set_physics_process(false); scene.bacatta57.set_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
## Live owners (Bacatta57 and the creature populations run on their own physics; the gate/alarm are stepped).
func live(seconds: float) -> void:
	for i in int(ceil(seconds*60.0)):
		a.advance(1.0/60.0); scene.village_gate.advance(1.0/60.0)
		await physics_frame
func open_gate() -> void:
	scene.village_gate.state().local24 = 1; scene.village_gate.state().elapsed = VillageState.DURATION; scene.village_gate.restore()
func place(at: Vector2) -> void:
	var o: Vector3 = a.origin()
	var top := Vector3(at.x,200,at.y)+o
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*600,1,[scene.player.get_rid()]))
	var y: float = hit.position.y if not hit.is_empty() else o.y
	scene.player.global_position = Vector3(at.x+o.x,y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,at.y+o.z)
	scene.player.velocity = Vector3.ZERO
	await physics_frame
func alarm_step(seconds: float) -> void:
	for i in int(ceil(seconds*30.0)):
		a.advance(1.0/30.0); scene.village_gate.advance(1.0/30.0)
		if i%10 == 0: await process_frame
func cycle(tag: String) -> bool:
	var path := "user://tests/tavern_return_%s.json" % tag
	var before: String = JSON.stringify(bank(),"",true)
	if not check(scene.quicksave(path).is_empty(),"Save "+tag): return false
	rooms.advance(1.0)
	var error: String = scene.quickload(path)
	rooms.set_process(false); a.set_physics_process(false); scene.village_gate.set_physics_process(false); scene.set_physics_process(false)
	var after: String = JSON.stringify(bank(),"",true)
	if after != before:
		var x: Dictionary = JSON.parse_string(before); var y: Dictionary = JSON.parse_string(after)
		for k in x:
			if JSON.stringify(x[k]) != JSON.stringify(y.get(k)): print("DIFF ",k,": ",JSON.stringify(x[k]).left(400)," -> ",JSON.stringify(y.get(k)).left(400))
		for k in y:
			if not x.has(k): print("NEW ",k)
	# Disk round-trips turn integers into floats; compare numeric meaning.
	return check(error.is_empty() and JSON.parse_string(after) == JSON.parse_string(before),"Reload %s: %s" % [tag,error])
func enter_village() -> bool:
	scene.player.position = TAVERN
	rooms.was_inside = false
	rooms._process(0.0)
	return bank().room == "VILLAGE"
func leave_all() -> void:
	while rooms.active():
		rooms.leave_room()
		rooms.advance(1000.0)

## Grounded production movement along a fixture point list; the live game owns everything else.
func walk(points: Array, label: String, until: Callable = Callable()) -> bool:
	for i in points.size():
		var target := Vector2(points[i][0],points[i][1])
		var reached := false
		for tick in range(2400):
			await physics_frame
			if until.is_valid() and until.call(): return true
			if not check(int(scene.starting_magic.health()) > 0,"%s: Luther died at %s" % [label,scene.player.position]): return false
			if int(scene.starting_magic.health()) != last_hp:
				last_hp = int(scene.starting_magic.health())
				var woken := []
				for key in ["villager_population","kelsrick","drunk","bacatta65","bacatta57"]:
					var node = scene.get(key)
					if node != null and is_instance_valid(node) and node.get("state") is Dictionary and node.state.get("actors") is Dictionary:
						for id in node.state.actors:
							if node.state.actors[id].get("woken",false): woken.append("%s:%s" % [key,id])
				if last_hp < 30: print("ALARM LOG ",JSON.stringify(a.effect_log.slice(0,12)).left(1500)," B57 ",JSON.stringify(scene.bacatta57.state).left(600) if is_instance_valid(scene.get("bacatta57")) else "-")
				print("HP %d at %s (%s) woken %s drunk %s arrows %d" % [last_hp,scene.player.position,label,woken,scene.drunk.state if is_instance_valid(scene.get("drunk")) else "-",a.fired_arrows])
			var offset := target-Vector2(scene.player.position.x,scene.player.position.z)
			if offset.length() < 3: reached = true; break
			var delta: float = scene.player.get_physics_process_delta_time()
			var direction := offset.normalized()*minf(1,offset.length()/(80*delta))
			scene.move_grounded(Vector3(direction.x,0,direction.y),delta)
			if not check(scene.resets == 0 and not scene.flying,"%s: reset/flight" % label): return false
		if not reached: return check(false,"%s blocked at waypoint %d target %s player %s room '%s' mouse %d hp %d vel %s" % [label,i,target,scene.player.position,rooms.state().room,Input.mouse_mode,int(scene.starting_magic.health()),scene.player.velocity])
	return true

func run() -> void:
	DirAccess.make_dir_recursive_absolute("user://tests")
	last_hp = -1
	routes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_quest_walk_routes.json"))
	await open_jungle()
	if not check(is_instance_valid(rooms) and a != null and is_instance_valid(scene.village_gate),"Hosts missing"): return
	# Clip records match the conversation clocks.
	var named: Dictionary = rooms.view.manifest.rooms.CAN.get("sequences",{})
	for sequence in Speech.CAN_LATER:
		if not check(named.has(sequence) and named[sequence].size() == Speech.FRAMES[sequence].size(),"Missing clips "+sequence): return
		for i in named[sequence].size():
			if not check(int(named[sequence][i].frames) == Speech.FRAMES[sequence][i] and int(named[sequence][i].audio_samples) == Speech.SAMPLES[sequence][i],"Clip %s %d" % [sequence,i]): return
	# ---- g7092 and the first visit ----
	if not check(int(bank().locals.Left_Village) == 0 and enter_village() and int(bank().locals.Left_Village) == 2,"Region3501 Left_Village 0->2"): return
	rooms.advance(1000.0)
	if not check(rooms.enter_room("CAN") and bank().conversation.sequence == "CAN","First visit"): return
	rooms.advance(1000.0); rooms.leave_room(); rooms.advance(1000.0)
	if not check(bank().room == "VILLAGE" and bank().flags["34"] == 1 and bank().flags["37"] == 0,"First farewell"): return
	# ---- Later visits while still in the village ----
	if not check(rooms.enter_room("CAN") and bank().conversation.sequence == "CAN_REVISIT" and bank().flags["42"] == 1 and Room.bacatta_present(bank()),"Second visit"): return
	rooms.advance(Speech.duration("CAN_REVISIT",0)+Speech.duration("CAN_REVISIT",1)+0.4)
	if not check(int(bank().conversation.cursor) == 2 and rooms.view.clip.frames == 0 and rooms.view.voice.playing,"Audio-only Luther line"): return
	if not cycle("revisit"): return
	rooms.advance(1000.0)
	if not check(not Speech.active(bank().conversation) and rooms.view.clip.get("idle",false),"Bacatta idle after revisit"): return
	rooms.leave_room()
	if not check(bank().room == "VILLAGE" and not Speech.active(bank().conversation),"Revisit leave not silent"): return
	if not check(rooms.enter_room("CAN") and bank().conversation.sequence == "CAN_REVISIT_LATE" and bank().flags["43"] == 1,"Third visit 675"): return
	rooms.advance(1000.0); rooms.leave_room()
	bank().globals.GV_BACATTA_RELATIONSHIP = 3
	if not check(rooms.enter_room("CAN") and bank().conversation.sequence == "CAN_EXIT" and int(bank().conversation.cursor) == 2 and bank().flags["44"] == 1 and bank().flags["37"] == 0 and int(bank().globals.GV_BACATTA_RELATIONSHIP) == 0,"Flag44 farewell"): return
	rooms.advance(1000.0)
	if not check(bank().room == "VILLAGE","Farewell did not return to the village"): return
	if not check(rooms.enter_room("CAN") and not Speech.active(bank().conversation) and Room.bacatta_present(bank()),"Fifth visit not silent"): return
	rooms.leave_room()
	leave_all()
	if not check(not rooms.active() and int(bank().locals.Left_Village) == 2 and enter_village() and int(bank().locals.Left_Village) == 2,"Re-entry changed Left_Village"): return
	leave_all()
	# ---- g7950 through the alarm owner ----
	open_gate()
	await place(OUTSIDE); await alarm_step(0.1)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await place(PASSAGE); await alarm_step(0.2)
	if not check(int(bank().locals.Left_Village) == 2,"Paused passage wrote Left_Village"): return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await alarm_step(0.1)
	if not check(int(bank().locals.Left_Village) == 3,"Region3805 Left_Village 2->3"): return
	await place(OUTSIDE); await alarm_step(7.0)
	if not check(shared29() == 0 and scene.village_gate.pose == 100 and a.movable_target(78) == -1,"Alarm without the alert"): return
	await place(PASSAGE); await alarm_step(0.1)
	if not check(int(bank().locals.Left_Village) == 3,"Second crossing changed Left_Village"): return
	# Walking from the gate to the tavern outlasts timer1 (300 ticks): it expires inert before the betrayal.
	await place(OUTSIDE); await alarm_step(7.0)
	if not check(a.movable_target(78) == -1 and a.fired_arrows == 0,"Second crossing fired the alarm"): return
	# ---- Return to the tavern: the maid ----
	if not check(enter_village() and bank().flags["41"] == 1 and not Speech.active(bank().conversation),"Village re-entry"): return
	if not check(rooms.enter_room("CAN") and bank().conversation.sequence == "CAN_MAID" and not Room.bacatta_present(bank()),"Maid sequence"): return
	for i in 7: rooms.advance(Speech.duration("CAN_MAID",i))
	rooms.advance(0.3)
	if not check(int(bank().conversation.cursor) == 7 and shared29() == 0,"Alert before line707 ended"): return
	if not cycle("maid"): return
	rooms.advance(Speech.duration("CAN_MAID",7))
	if not check(int(bank().conversation.cursor) == 8 and shared29() == 1 and bank().flags["267"] == 0,"Alert after line707"): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/tavern_return_maid.png")
	rooms.advance(1000.0)
	if not check(bank().room == "VILLAGE" and bank().flags["267"] == 1 and shared29() == 1,"Maid end"): return
	if not check(not rooms.enter_room("CAN"),"Tavern reopened after the betrayal"): return
	var path := "user://tests/tavern_return_alert.json"
	if not check(scene.quicksave(path).is_empty() and scene.quickload(path).is_empty() and shared29() == 1 and rooms.state().flags["267"] == 1 and int(rooms.state().locals.Left_Village) == 3,"Alert/flag267 disk"): return
	rooms = scene.monastery; a = scene.village_alarm
	leave_all()
	var legacy: Dictionary = Room.initial()
	for key in Room.CAN_FLAGS: legacy.flags.erase(key)
	if not check(Room.validate(legacy).is_empty(),"Legacy monastery save rejected"): return
	var forged: Dictionary = Room.initial(); forged.flags["34"] = 1; forged.room = "CAN"; forged.conversation = {"sequence":"CAN_MAID","cursor":1,"elapsed":0.0}
	if not check(not Room.validate(forged).is_empty(),"Maid without leaving accepted"): return
	if not check(scene.quicksave(path).is_empty(),"Pre-route save"): return
	# ---- Scenario 2: the native betrayal with every live owner (Bacatta57 seal, alarm, gate, Kelsrick, archers) ----
	scene.queue_free(); await process_frame; await process_frame
	await open_jungle(false)
	open_gate()
	await place(Vector2(-1718,-3961)); await live(0.3)
	await place(Vector2(TAVERN.x,TAVERN.z)); await live(0.3)
	rooms._process(0.0)
	if not check(bank().room == "VILLAGE" and int(bank().locals.Left_Village) == 2 and not scene.bacatta57.sealed(),"Scenario2 first entry"): return
	rooms.advance(1000.0)
	if not check(rooms.enter_room("CAN"),"Scenario2 first CAN"): return
	rooms.advance(1000.0); rooms.leave_room(); rooms.advance(1000.0); leave_all()
	if not check(bank().flags["34"] == 1 and int(bank().globals.GV_BACATTA_RELATIONSHIP) == 0,"Scenario2 farewell"): return
	# Leave the village through the gate passage (alarm owner live): Left_Village 2 -> 3, timer1 armed, inert.
	await place(Vector2(-1718,-3961)); await live(0.3)
	await place(INSIDE); await alarm_step(0.1)
	await place(PASSAGE); await alarm_step(0.1)
	await place(OUTSIDE); await alarm_step(7.0)
	if not check(int(bank().locals.Left_Village) == 3 and a.movable_target(78) == -1,"Scenario2 departure"): return
	# Return: the sealing entry (relationship 0) and the room.
	await place(Vector2(-1718,-3961)); await live(0.3)
	await place(Vector2(TAVERN.x,TAVERN.z))
	rooms.was_inside = false; rooms._process(0.0)
	await live(0.3)
	if not check(bank().room == "VILLAGE" and scene.bacatta57.sealed(),"Sealing entry: room '%s' b57 %s inside %s rel %s pos %s" % [bank().room,JSON.stringify(scene.bacatta57.state).left(300),scene.bacatta57.inside,bank().globals.get("GV_BACATTA_RELATIONSHIP"),scene.player.position]): return
	if not check(rooms.enter_room("CAN") and bank().conversation.sequence == "CAN_MAID","Scenario2 maid"): return
	rooms.advance(1000.0)
	if not check(bank().room == "VILLAGE" and shared29() == 1 and bank().flags["267"] == 1,"Scenario2 alert"): return
	leave_all()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	await live(1.0)
	var rp := Vector2(scene.player.position.x,scene.player.position.z)
	if not check(rp.distance_to(Vector2(-1718,-3961)) < 30,"Return point not applied: %s" % [scene.player.position]): return
	# Production movement from here on: the alarm fires on its own timer and Luther walks the gate-free route.
	Engine.time_scale = 4.0; Engine.physics_ticks_per_second = 240
	scene.set_process_unhandled_input(false)
	for node in [scene, a, scene.village_gate]: node.set_physics_process(true)
	rooms.set_process(true); rooms.was_inside = true
	var to_hall: Array = routes.tavern_to_monastery.points.slice(1)
	var hall := func(): return rooms.active() and rooms.state().room == "MENT"
	var alarm_seen := false
	if not await walk(to_hall,"betrayal->monastery",func():
		if a.movable_target(78) == 0: alarm_seen = true
		return hall.call()): return
	if not check(rooms.state().room == "MENT" and (alarm_seen or a.movable_target(78) == 0) and int(a.state.locals.get("7",0)) == 2,"Monastery not reached after the alarm (alarm %s)" % alarm_seen): return
	print("Betrayal escape reached the monastery hall: health %d, arrows %d, gate %d" % [int(scene.starting_magic.health()),a.fired_arrows,a.movable_target(78)])
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("user://tests/tavern_return_hall.png")
	# On to the Hive by the source monastery->Hive route (no gate on it).
	leave_all()
	routes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_flute_return_routes.json")),true)
	var jungle = scene
	if not await walk(routes.monastery_to_hive.points,"monastery->Hive",func(): return current_scene != jungle or not is_instance_valid(jungle)): return
	for i in 480:
		if is_instance_valid(current_scene) and current_scene != jungle: break
		await physics_frame
	if not check(is_instance_valid(current_scene) and current_scene != jungle and current_scene.scene_file_path == "res://scenes/lol2/hive_review.tscn","Hive not reached after the betrayal"): return
	print("Betrayal route continued into the Hive")
	Engine.time_scale = 1.0; Engine.physics_ticks_per_second = 60
	for p in ["user://tests/tavern_return_revisit.json","user://tests/tavern_return_maid.json","user://tests/tavern_return_alert.json"]: DirAccess.remove_absolute(p)
	print("PASS tavern_return_live: [scenario1 rooms] g7092 0->2 once; first visit+farewell; revisit 662-666 (partial audio save), 675, flag44 farewell 676/677, then silent; g7950 2->3 via the alarm owner (not paused, once, inert without alert); maid 700-709 Bacatta absent, alert after 707 via shared29, flag267, tavern closed, disk; legacy/forged saves; [scenario2 live] farewell, gate departure, sealing return entry, maid alert, return point, the alarm fires on its own timer, grounded tavern->monastery escape reaches the hall alive, then monastery->Hive.")
	quit()
