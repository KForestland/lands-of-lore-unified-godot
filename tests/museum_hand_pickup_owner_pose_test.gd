extends "res://tests/museum_ivory_live_test.gd"
## Owner r3 reports 2026-10-20 11:37 (Prism) and 11:42 (Long arm): the owner's save held Broken Thohan in the hand
## (hand_item museum:control181:Tho_Broken), so the empty-hand source pickups refused silently, and the Prism's
## centre cone missed while the view centre sat on its hilt. Exact owner poses; E now puts the held item away.
const THOHAN := "museum:control181:Tho_Broken"
const Arm = preload("res://scripts/lol2/museum_long_arm.gd")
const ArmState = preload("res://scripts/lol2/museum_long_arm_state.gd")
func pose(position: Vector3, yaw: float, pitch: float) -> void:
	scene.player.position = position; scene.player.rotation.y = yaw; scene.camera.rotation.x = pitch; scene.camera.fov = 75
	await physics_frame; await physics_frame
func hint() -> String:
	scene.pickup_notice_time=0.0;scene._physics_process(0.0)
	return scene.interaction_label.text if scene.interaction_label.visible else ""
func run() -> void:
	scene=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate();scene.introduction_state="complete";root.add_child(scene);current_scene=scene
	await process_frame;freeze(scene);scene.flying=false;Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	scene.carried_collected.append(THOHAN);scene.hand_item=THOHAN
	# Prism, report 11:37 owner pose.
	var prism=scene.prism
	await pose(Vector3(2325.3564453125,-37.9601364135742,-3340.35766601562),-0.0300162527710199,-0.0250029284507036)
	if not check(not scene.can_reach_item(prism.display.global_position),"Old centre-cone rule unexpectedly reached the Prism"):return
	if not check(scene.can_reach_sprite(prism.display,prism.display.global_position),"View centre on the Prism hilt is not reachable"):return
	var prism_hint := hint()
	if not check(prism_hint=="E — Take Prism (puts away Broken Thohan)" or prism_hint.begins_with("E — Take Prism (puts away"),"Prism hint with Thohan in hand: "+prism_hint):return
	await press_e()
	if not check(prism.taken and scene.carried_collected.count(prism.ITEM)==1 and scene.hand_item=="" and THOHAN in scene.carried_collected,"Prism pickup with Thohan in hand"):return
	await press_e()
	if not check(scene.carried_collected.count(prism.ITEM)==1,"Duplicate Prism"):return
	# Long arm, report 11:42 owner position, level view onto the altar.
	var arm=scene.long_arm
	scene.hand_item=THOHAN
	await pose(Vector3(-728.289001464844,72.0011749267578,-1088.07250976562),-0.0210162065923214,0.0)
	arm.state.walkway=true # region first contact is exercised by museum_long_arm_escape_test with physics.
	Engine.set_meta("lol2_enhanced",true) # the closed-passage78 refusal is the Enhanced guard since 2026-10-28 (owner)
	if not check(not arm.offered(),"Busy hand admitted directly"):return
	if not check(hint()==Arm.NEED_PASSAGE,"Closed passage78 refusal hidden by the held item: "+hint()):return
	if not check(scene.key_locks.restore_checkpoint({"version":1,"loaded":[78],"panel_state":0}).is_empty(),"Lock78 open"):return
	scene.curse.set_requests_enabled(true)
	var arm_hint := hint()
	if not check(arm_hint.begins_with("E — Take Long arm (puts away"),"Long arm hint with Thohan in hand: "+arm_hint):return
	await press_e()
	if not check(int(arm.state.stage)==1 and scene.hand_item==ArmState.ITEM and THOHAN in scene.carried_collected and scene.carried_collected.count(ArmState.ITEM)==1,"Long arm pickup with Thohan in hand"):return
	# A held item that an action uses keeps priority: nothing is stowed when no empty-hand action applies.
	scene.hand_item=THOHAN
	await pose(Vector3(0,500,0),0.0,0.0)
	await press_e()
	if not check(scene.hand_item==THOHAN,"Held item stowed with nothing to take"):return
	print("PASS owner-pose Prism and Long arm with Broken Thohan in hand; hilt aim; refusal hint; no stow without a pickup")
	await finish(scene);quit()
