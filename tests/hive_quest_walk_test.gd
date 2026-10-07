extends SceneTree
## One continuous capsule walk. Only the initial source entrance is a spawn fixture.
var scene
var routes: Dictionary
var inner_gate_route := "--kelsrick-inner-gate" in OS.get_cmdline_user_args()
var population_route := "--return-population" in OS.get_cmdline_user_args()
var broken_route := "--broken-sword" in OS.get_cmdline_user_args()
var spell_route := "--starting-spells" in OS.get_cmdline_user_args()
var earned_cave_chain := "--earned-cave-chain" in OS.get_cmdline_user_args()
var save_path := "user://tests/hive_walk_%d.json" % Time.get_ticks_usec()

func _initialize() -> void:
	run.call_deferred()

func check(condition: bool, message: String) -> bool:
	if condition: return true
	push_error(message)
	DirAccess.remove_absolute(save_path)
	quit(1)
	return false

func capture(name: String) -> void:
	if "--capture-hive-walk" not in OS.get_cmdline_user_args(): return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("/home/bob/lol2_out/hive_geometry_20260914/walk_%s.png" % name)

func fight_executioner() -> bool:
	var enemy = scene.executioner_live
	var guards = scene.get_node("Warriors")
	if enemy.state.health<=0 or not enemy.active() or not enemy.clear_path() or scene.camera.global_position.distance_to(enemy.body.global_position)>150: return true
	for tick in range(24000):
		await physics_frame
		if not check(guards.health>0,"Executioner defeated route player"): return false
		if enemy.state.health<=0:
			print("Executioner defeated through aimed strikes and grounded windup retreats; player health ",guards.health)
			return true
		var target: Vector3=enemy.body.global_position
		scene.camera.look_at(target)
		var offset: Vector3=target-scene.camera.global_position
		var distance := offset.length()
		if distance<94: guards.strike()
		var desired := 105.0 if enemy.state.mode=="attack" else 82.0
		var direction:=Vector3(offset.x,0,offset.z).normalized()
		if distance<desired-2: direction=-direction
		elif distance<=desired+2: direction=Vector3.ZERO
		scene.move_grounded(direction,scene.player.get_physics_process_delta_time(),true)
		if not check(scene.resets==0 and not scene.flying,"Executioner fight left walkable route"): return false
	return check(false,"Executioner duel exceeded traversal budget")

func walk(name: String, allow_exit: bool = false, destination_room: String = "") -> bool:
	var route: Dictionary = routes[name]
	for i in route.points.size():
		var target := Vector2(route.points[i][0],route.points[i][1])
		var reached := false
		for step in range(1200):
			await physics_frame
			if allow_exit and current_scene != scene: return true
			if destination_room.is_empty() and scene.get("monastery") != null and scene.monastery.active():
				return check(false,"Unexpected room %s on %s at %s" % [scene.monastery.state().room,name,scene.player.position])
			if not destination_room.is_empty() and scene.monastery.active():
				return check(scene.monastery.state().room == destination_room,"Unexpected room on " + name)
			if scene.has_node("GateVillager") and scene.village_dialogue.active():
				for speech_tick in range(7200):
					await physics_frame
					if not scene.village_dialogue.active(): break
				if not check(scene.village_dialogue.state().local15 == 1,"Village speech did not complete naturally"): return false
			if scene.has_node("ExecutionerLive") and not await fight_executioner(): return false
			var offset := target-Vector2(scene.player.position.x,scene.player.position.z)
			if offset.length() < 3:
				reached = true
				break
			var delta: float = scene.player.get_physics_process_delta_time()
			var direction := offset.normalized()*minf(1,offset.length()/(80*delta))
			scene.move_grounded(Vector3(direction.x,0,direction.y),delta)
			if not check(scene.resets == 0 and not scene.flying,"Walk reset or entered flight"): return false
			if scene.has_node("Warriors"):
				var guards = scene.get_node("Warriors")
				if not check(guards.health > 0,"Player died on route"): return false
				for enemy in range(2):
					var aim: Vector3 = guards.POSITIONS[enemy]+Vector3(0,35,0)
					if guards.enemies[enemy] > 0 and scene.camera.global_position.distance_to(aim) < 90 and guards.clear_path(aim):
						scene.camera.look_at(aim)
						guards.strike()
		if not reached:
			return check(false,"%s blocked at waypoint%d region%s target%s player%s" % [name,i,route.regions[i],target,scene.player.position])
	print("Walk segment ",name," passed: ",route.regions.size()," source regions at ",scene.player.position)
	return true

func run() -> void:
	if "--return-hive" in OS.get_cmdline_user_args() and "--continue-monastery" not in OS.get_cmdline_user_args():
		check(false,"--return-hive requires --continue-monastery")
		return
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 240
	if earned_cave_chain:
		var input_path := "user://tests/act1_broken_hive_entry.json" if broken_route else "user://tests/act1_magic_hive_entry.json" if spell_route else "user://tests/act1_cave_hive_entry.json"
		var proof = JSON.parse_string(FileAccess.get_file_as_string("res://docs/broken-earned-jungle-hive-walk-checks.json" if broken_route else "res://docs/magic-earned-jungle-hive-walk-checks.json" if spell_route else "res://docs/earned-jungle-hive-walk-checks.json"))
		if not check(FileAccess.get_sha256(input_path) == proof.output_sha256,"Earned cave/Hive entry save differs"): return
		var saved = preload("res://scripts/lol2/hive_save.gd").read_save(input_path)
		if not check(saved.error.is_empty(),"Earned Hive entry save is invalid"): return
		set_meta("lol2_hive_resume",saved.state)
	scene = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	scene.set_development_mode(false)
	# This fixture drives movement/aim itself; desktop mouse events must not alter it.
	scene.set_process_unhandled_input(false)
	scene.get_node("Warriors").set_process_unhandled_input(false)
	scene.interface_hud.set_process_input(false)
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not earned_cave_chain:
		var state: Dictionary = scene.area_handoff()
		state.inventory = {"collected":[scene.Save.Shared.Museum.SWORD],"equipped_item":scene.Save.Shared.Museum.SWORD,"equipped_armor":""}
		if not check(scene.apply_area_handoff(state).is_empty(),"Initial equipment handoff failed"): return
	else:
		if not check("cave:prop641:harvest1:Stalagmite" in scene.carried_inventory.collected and scene.carried_inventory.equipped_item == scene.Save.Shared.Museum.SWORD,"Earned entry lost its weapons"): return
	scene.set_physics_process(false)
	routes = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_quest_walk_routes.json"))
	var shape: Shape3D = scene.player.get_child(0).shape
	if not check(scene.player_form == 0 and shape is CapsuleShape3D and is_equal_approx(shape.radius,15.0) and is_equal_approx(shape.height,46.0),"Route must use the source human body"): return
	for name in routes:
		if not routes[name] is Dictionary: continue
		if not check(routes[name].minimum_portal_width >= 2*shape.radius+2 and routes[name].minimum_clearance >= shape.height+1,"Route fixture predates source human clearance: " + name): return
	for i in range(90):
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
	if not check(scene.player.is_on_floor(),"Source entrance did not ground"): return
	if not await walk("entrance_to_rock"): return
	var chasm = scene.get_node("Chasm")
	scene.camera.look_at(chasm.trigger.global_position+Vector3(0,36,0))
	await capture("chasm_before")
	if not check(scene.get_node("Warriors").strike() and chasm.activated,"Grounded bank melee strike did not activate rock233 (mouse=%s cooldown=%s hit=%s)" % [Input.mouse_mode,scene.get_node("Warriors").cooldown,scene.get_node("Warriors").aimed_hit()]): return
	for i in range(80): await physics_frame
	if not check(chasm.elapsed > 0 and not chasm.completed,"Chasm did not advance"): return
	if not check(scene.quicksave(save_path).is_empty(),"Mid-collapse save failed"): return
	var saved_elapsed: float = chasm.elapsed
	if not check(scene.quickload(save_path).is_empty() and is_equal_approx(chasm.elapsed,saved_elapsed),"Mid-collapse restore differs"): return
	scene.set_physics_process(false)
	while not chasm.completed:
		await physics_frame
		scene.move_grounded(Vector3.ZERO,scene.player.get_physics_process_delta_time())
	await capture("chasm_after")
	if not await walk("bridge_to_guardian"): return
	var guards = scene.get_node("Warriors")
	var aim: Vector3 = guards.POSITIONS[0]+Vector3(0,35,0)
	scene.camera.look_at(aim)
	for i in range(150):
		await physics_frame
		guards.strike()
		if guards.enemies[0] == 0: break
	if not check(guards.enemies[0] == 0,"Guardian not defeated from walked approach (mouse=%s health=%s cooldown=%s hit=%s)" % [Input.mouse_mode,guards.enemies[0],guards.cooldown,guards.aimed_hit()]): return
	while not scene.get_node("QuestPillar").opened: await physics_frame
	await capture("guardian")
	if not await walk("guardian_to_room"): return
	var actor = scene.get_node("ConversationReview")
	actor.check_room_contact()
	if not check(actor.room_entered,"Walk failed to admit room1001"): return
	if not await walk("room_to_conversation"): return
	scene.camera.look_at(actor.global_position+Vector3(0,64,0))
	if not check(actor.can_begin(),"Walked conversation approach not admitted"): return
	var speak := InputEventKey.new()
	speak.keycode = KEY_E
	speak.pressed = true
	Input.parse_input_event(speak)
	Input.flush_buffered_events()
	if not check(actor.started and actor.shared_flags[38] == 1,"E did not start source conversation"): return
	await capture("conversation")
	while not actor.completed: await process_frame
	scene.set_physics_process(false)
	if not await walk("conversation_to_room"): return
	if not await walk("room_to_exit",true): return
	for i in range(180):
		await physics_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/lol2/jungle_walkthrough.tscn": break
	if not check(is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/lol2/jungle_walkthrough.tscn","Walk did not return to jungle"): return
	for i in range(90): await physics_frame
	var jungle = current_scene
	if not check(jungle.player.is_on_floor() and jungle.quest_state.hive_chasm.activated and jungle.quest_state.conversation.completed,"Return lost grounded state or quests"): return
	if not check(jungle.equipped_item == "museum:item11:Fine_Longsword","Return lost sword"): return
	scene = jungle
	scene.set_physics_process(false)
	scene.set_process_unhandled_input(false)
	scene.interface_hud.set_process_input(false)
	if not await walk("jungle_to_village"): return
	var gate = jungle.village_gate
	if not check(gate.state().local24 == 1,"Continuous rescued approach did not trigger village gate"): return
	for i in range(1800):
		await physics_frame
		if gate.pose == 100 and not jungle.village_dialogue.active(): break
	if not check(gate.pose == 100,"Village gate did not finish opening"): return
	for i in range(110):
		await physics_frame
		scene.move_grounded(Vector3.LEFT,scene.player.get_physics_process_delta_time())
	if not check(scene.player.is_on_floor() and scene.player.position.x < -1420 and scene.resets == 0,"Continuous quest route did not cross village gate: %s" % scene.player.position): return
	if inner_gate_route:
		await kelsrick_inner_gate()
		return
	if not await walk("village_to_followup"): return
	if not check(scene.followup_gate.state().local18 == 1,"Village path did not arm follow-up"): return
	for i in range(150):
		await physics_frame
		scene.move_grounded(Vector3.FORWARD,scene.player.get_physics_process_delta_time())
		if scene.followup_dialogue.active(): break
	if not check(scene.followup_dialogue.active(),"Continuous village approach did not start follow-up"): return
	for i in range(9000):
		await physics_frame
		if not scene.followup_dialogue.active() and scene.followup_gate.pose == 0: break
	if not check(scene.followup_gate.state().speech == preload("res://scripts/lol2/jungle_followup_state.gd").DURATION and scene.followup_gate.pose == 0,"Follow-up did not finish and close gate naturally"): return
	if "--continue-monastery" in OS.get_cmdline_user_args():
		if not await walk("followup_to_tavern",false,"VILLAGE"): return
		if not await finish_room_speech(): return
		if not check(scene.monastery.enter_room("CAN"),"Village hotspot did not admit Bacatta"): return
		if not await finish_room_speech(): return
		scene.monastery.leave_room()
		if not await finish_room_speech(): return
		if not check(scene.monastery.state().room == "VILLAGE","Bacatta farewell did not return"): return
		scene.monastery.leave_room()
		scene.set_physics_process(false)
		if not await walk("tavern_to_monastery",false,"MENT"): return
		if not check(scene.monastery.enter_room("MLIB"),"Library entry failed"): return
		if not await finish_room_speech(): return
		scene.monastery.leave_room()
		if not check(scene.monastery.enter_room("MOFF"),"Earned Bacatta/Dawn prerequisite did not admit office"): return
		if not await finish_room_speech(): return
		if not check(preload("res://scripts/lol2/monastery_conversation.gd").FLUTE in scene.carried_collected,"Continuous quest failed to grant flute"): return
		print("Extended continuous Bacatta→Dawn→Julian/flute route PASSED; no position or quest-flag injection after initial Hive spawn")
		if "--return-hive" in OS.get_cmdline_user_args():
			if not check(scene.quicksave(earned_output("earned_flute")).is_empty(),"Earned flute checkpoint failed"): return
			scene.monastery.leave_room()
			if not await finish_room_speech(): return
			if not check(scene.monastery.state().room == "MENT","Julian farewell did not return to hall"): return
			scene.monastery.leave_room()
			if not check(not scene.monastery.active(),"Monastery exit remained active"): return
			if not await walk_flute_return(): return

	DirAccess.remove_absolute(save_path)
	print("Hive continuous quest walk PASSED: source entrance, melee rock233, partial save/load, bridge, guardian/pillar, room/E conversation and grounded jungle return→village gate entry and follow-up speech/gate closure; no repositioning after spawn")
	current_scene.queue_free()
	await process_frame
	quit()

## Earned branch: from the crossed village gate, walk to Kelsrick. His talk1 (after the gate villager's speech) runs
## at natural speed; its end (g30684, control98 selector1) opens the inner gate. Then walk south through the gate line
## (region2750, where his g5084 shuts it behind) into region2752. No position or quest state is injected.
func kelsrick_inner_gate() -> void:
	routes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/kelsrick_inner_gate_routes.json")),true)
	var GateState=preload("res://scripts/lol2/jungle_inner_gate_state.gd")
	var gate=scene.get("inner_gate");var kelsrick=scene.get("kelsrick")
	if not check(gate!=null and kelsrick!=null and not GateState.open(gate.state,"74") and gate.pose["74"]==0,"Inner gate not installed shut on the earned route"): return
	if not await walk("village_to_kelsrick"): return
	for i in range(1200):
		await physics_frame
		if kelsrick.hold: break
		var offset:=Vector2(-1804,-5508)-Vector2(scene.player.position.x,scene.player.position.z)
		scene.move_grounded(Vector3(offset.normalized().x,0,offset.normalized().y),scene.player.get_physics_process_delta_time())
	if not check(kelsrick.hold,"Kelsrick talk1 did not start on the earned approach"): return
	for i in range(40000):
		await physics_frame
		if not kelsrick.hold and GateState.open(gate.state,"74") and GateState.open(gate.state,"75"): break
	if not check(not kelsrick.hold and "051062000100" in kelsrick.receipts and GateState.open(gate.state,"75"),"Talk1 end did not open the inner gate"): return
	for i in range(2400):
		await physics_frame
		if gate.pose["74"]==100 and gate.pose["75"]==100: break
	if not check(gate.pose["74"]==100 and gate.pose["75"]==100,"Inner gate did not finish opening"): return
	if not await walk("kelsrick_through_inner_gate"): return
	var south: Dictionary=gate.src.regions[0]
	var polygon:=PackedVector2Array()
	for v in south.polygon: polygon.append(Vector2(v[0],v[1]))
	if not check(Geometry2D.is_point_in_polygon(Vector2(scene.player.position.x,scene.player.position.z),polygon) and scene.resets==0,"Did not cross south into region2752: %s"%scene.player.position): return
	if not check(gate.effect_log.any(func(e): return e.type=="group" and int(e.group)==21156) and gate.effect_log.any(func(e): return e.type=="group" and int(e.group)==21138),"Gate log lacks the talk1 open/g5084 shut"): return
	print("Earned Kelsrick talk1 -> inner gate crossing PASSED: natural talk1 opened 74/75 (g30684/g21156), walk crossed region2750 (g5084 shut behind via g21138) into region2752; no position or quest-flag injection after initial Hive spawn")
	current_scene.queue_free()
	await process_frame
	quit()

func finish_room_speech() -> bool:
	var speech = preload("res://scripts/lol2/monastery_conversation.gd")
	for tick in range(40000):
		await physics_frame
		if not speech.active(scene.monastery.state().conversation): return true
	return check(false,"Room speech did not finish naturally")

func walk_flute_return() -> bool:
	routes.merge(JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_flute_return_routes.json")),true)
	scene.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if not await walk("monastery_to_hive",true): return false
	for tick in range(180):
		await physics_frame
		if is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/lol2/hive_review.tscn": break
	if not check(is_instance_valid(current_scene) and current_scene.scene_file_path == "res://scenes/lol2/hive_review.tscn","Flute return failed to enter Hive"): return false
	scene = current_scene
	scene.set_physics_process(false)
	if not check(preload("res://scripts/lol2/monastery_conversation.gd").FLUTE in scene.carried_inventory.collected,"Hive return lost flute"): return false
	if not await walk("hive_return_to_gate"): return false
	if earned_cave_chain and not check("cave:prop641:harvest1:Stalagmite" in scene.carried_inventory.collected,"Cave weapon lost on earned flute return"): return false
	if population_route:
		if not check(scene.return_population.targets().size()==7,"Earned rescue/Bacatta return did not activate seven warriors"): return false
	if not check(scene.quicksave(earned_output("flute_hive_return")).is_empty(),"Returned flute checkpoint failed"): return false
	if broken_route:
		var handoff: Dictionary = scene.area_handoff()
		if not check("museum:control181:Tho_Broken" in handoff.inventory.collected and handoff.quests.museum_control181.owner_state == 1,"Broken sword/history lost after flute return"): return false
		var input_path = "user://tests/act1_broken_hive_entry.json"
		var output_path = earned_output("flute_hive_return")
		var report = {"passed":true,"input_sha256":FileAccess.get_sha256(input_path),"output_sha256":FileAccess.get_sha256(output_path),"output_save":output_path,"scope":"Earned broken-sword Hive arrival through Executioner/rescue, village, Bacatta/Dawn/Julian flute and actual Hive return. Normal movement with manually driven movement ticks, accelerated clocks. No supplied inventory/quest/position."}
		FileAccess.open("res://docs/population-earned-flute-return-walk-checks.json" if population_route else "res://docs/broken-earned-flute-return-walk-checks.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  ")+"\n")
	print("PASS: continuous monastery/flute return through Jungle and Hive transition to curse control region")
	return true

func earned_output(name: String) -> String:
	return "user://tests/act1_%s%s.json" % [("population_" if population_route else "")+("broken_" if broken_route else "magic_" if spell_route else ("cave_" if earned_cave_chain else "")),name]
