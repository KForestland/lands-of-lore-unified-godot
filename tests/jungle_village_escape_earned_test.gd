extends SceneTree
## Focused component check of the village betrayal escape (rendered). NOT the continuous ordinary-input route proof
## (that is jungle_village_escape_route_test) and NOT a process restart (jungle_village_escape_reload_test). It uses
## supplied approach positions, direct shop/room owner calls and an in-process scene recreation. Requires
## --earned-save=PATH: a real campaign save in
## the Jungle after the village admission and before the weapon-shop intro (the same kind of pre-shop continuation
## jungle_kityara_live_test accepts). No story flag is written by the test; approach positions are supplied.
## 0. The earned input stands at health 5 of 30: heal to full with the Healing spell by keys (a dead Luther's save is
##    correctly refused: jungle_save.gd 'Invalid player health.').
## 1. Production weapon-shop entry and intro earn GV_LUTHER_KNOWS_ABOUT_DANIEL.
## 2. Barrel prop1465 comes into the camera's view: control123 idles (native idle window, before region3408). A basic
##    Spark (Q) from region3409 kills it through group 25802: Killed_Confidante=1 (no respawn).
## 3. Tavern betrayal: the earned input has already had the first visit, the farewell and the departure through the
##    gate passage, so the return (sealing entry) gives CAN_MAID:
##    GV_HULINE_ALERT; the live alarm owner fires on its own timer and closes leaves 78/79.
## 4. Owner-approved modern "Force gate" (2026-10-25): aim at closed leaf78, real E; the leaf breaks (sound452).
## 5. Ordinary grounded walking through the gap and on to the monastery entrance (MENT via the blocker-avoiding
##    tavern_to_monastery route points outside the gate); save, restart (fresh scene) and load keep every result.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const PASSAGE:=Vector2(-1412,-5249)
const OUTSIDE:=Vector2(-1300,-5240)
const INSIDE:=Vector2(-1479.5,-5169)
const TAVERN:=Vector3(-1630,32,-3900)
var scene
var rooms
var a
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error(msg);quit(1)
	return ok
func bank() -> Dictionary: return rooms.state()
## The only walkable spot in reach and sight of control123 without entering region3408 (which starts the meeting and
## holds Luther) is region3409 (village_escape_route.json inside_to_confidante end, 163 units away): beyond melee
## reach (140), so the idle-window kill is a basic Spark (Q, range 384; population_actor ray -> receive_damage 8).
func boot() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate();root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	scene.set_physics_process(false)
	rooms=scene.monastery;a=scene.village_alarm
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
func place(at: Vector2) -> void:
	var top:=Vector3(at.x,200,at.y)
	var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(top,top-Vector3.UP*600,1,[scene.player.get_rid()]))
	scene.player.global_position=Vector3(at.x,(hit.position.y if not hit.is_empty() else 0.0)+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,at.y)
	scene.player.velocity=Vector3.ZERO
	await physics_frame
## One clock: the live owners (alarm, village gate, Confidante, gate leaves) run on their own physics; the test only
## waits physics frames (the host's own physics stays off, movement is the grounded mover below).
func live(seconds: float) -> void:
	for i in int(ceil(seconds*60.0)): await physics_frame
func walk(to: Vector2, frames: int) -> bool:
	for i in frames:
		var off:=to-Vector2(scene.player.global_position.x,scene.player.global_position.z)
		if off.length()<4: return true
		scene.move_grounded(Vector3(off.x,0,off.y).normalized(),1.0/60.0)
		await physics_frame
		if scene.starting_magic.health()<=0: return check(false,"Luther died walking to %s"%to)
		if rooms.active(): return true
	return false
func key(code: int) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await process_frame
func click() -> void:
	var e:=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=true;Input.parse_input_event(e);await process_frame
	e=e.duplicate();e.pressed=false;Input.parse_input_event(e);await process_frame
## Healing spell by keys (2, Q per cast, then 1): the earned input stands at health 5 of 30.
func heal_up() -> void:
	await key(KEY_2)
	for i in 12:
		if scene.starting_magic.health()>=30 or int(scene.starting_magic.magic_state().player.mana)<2: break
		await key(KEY_Q)
		for f in 36: await physics_frame
	await key(KEY_1)
func leave_all() -> void:
	while rooms.active():
		rooms.leave_room();rooms.advance(1000.0)

func run() -> void:
	var earned_source:=""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--earned-save="): earned_source=arg.trim_prefix("--earned-save=")
	if earned_source.is_empty(): earned_source=OS.get_environment("LOL2_VILLAGE_ESCAPE_SAVE") # run_regressions passes no user args
	if not check(not earned_source.is_empty() and FileAccess.file_exists(earned_source),"Requires --earned-save=PATH or LOL2_VILLAGE_ESCAPE_SAVE (pre-shop Jungle campaign save)"): return
	DirAccess.make_dir_recursive_absolute("user://tests")
	var earned:="user://tests/village_escape_earned.json";var final:="user://tests/village_escape_focused_final.json"
	var f:=FileAccess.open(earned,FileAccess.WRITE);f.store_string(FileAccess.get_file_as_string(earned_source));f.close()
	await boot()
	if not check(scene.quickload(earned).is_empty(),"Earned save rejected"): return
	leave_all()
	await heal_up()
	if not check(scene.starting_magic.health()==30,"Healing by keys reached %d"%scene.starting_magic.health()): return
	var globals: Dictionary=scene.quest_state.monastery.globals
	if not check(int(globals.get("GV_LUTHER_KNOWS_ABOUT_DANIEL",0))==0 and int(scene.village_gate.state().shared29)==0 and not scene.confidante.killed(),"Input is not a pre-shop, pre-alert save"): return
	# 1. Weapon-shop intro (production entry contact).
	var shop=scene.weapon_shop
	var entrance: Array=shop.data.entrances[0];var c:=Vector2.ZERO
	for p in entrance: c+=Vector2(p[0],p[1])
	c/=float(entrance.size())
	scene.player.position=Vector3(c.x,32,c.y);shop.was_inside=false;shop._process(0.016)
	if not check(shop.active() and shop.interact("enter"),"Shop entry failed"): return
	for i in 4000:
		shop.advance(0.1)
		if not shop.State.active(shop.state()): break
	shop.leave_room();shop.leave_room()
	if not check(int(globals.get("GV_LUTHER_KNOWS_ABOUT_DANIEL",0))==1 and not shop.active(),"Shop intro did not earn Daniel knowledge"): return
	# 2. Confidante: barrel sight, idle window, real click kill.
	var k=scene.confidante
	var barrel: Array=k.src.props["1465"].position
	await place(Vector2(-1269.5,-4390.5));scene.camera.look_at(Vector3(-1269.5,40,-4690.5));await physics_frame
	await live(0.1) # sight is an edge: the first look after the load only records what is in view
	scene.camera.look_at(Vector3(barrel[0],barrel[1]+40,barrel[2]));await physics_frame
	await live(0.2)
	if not check(int(k.state.controls["123"].segment)==3 and k.speaking()=="","Confidante not idling after barrel sight"): return
	var at: Array=k.src.locations["123"].control.position
	scene.camera.look_at(Vector3(at[0],at[1]+18,at[2]));await physics_frame
	var soul0: int=preload("res://scripts/lol2/shared_global_defaults.gd").read(globals,"GV_LUTHERS_SOUL")
	await key(KEY_Q)
	if not check(k.killed() and preload("res://scripts/lol2/shared_global_defaults.gd").read(globals,"GV_LUTHERS_SOUL")==soul0-1,"Spark did not kill the Confidante"): return
	await live(3.0)
	# 3. Tavern betrayal with live owners. The earned input already has the first visit and farewell (flag34 1) and the
	#    departure through the gate passage (Left_Village 3), so the return entry (Bacatta57 sealing) leads to CAN_MAID.
	if not check(int(bank().flags["34"])==1 and int(bank().locals.Left_Village)==3,"Earned input lacks the farewell/departure"): return
	await place(Vector2(-1718,-3961));await live(0.3)
	await place(Vector2(TAVERN.x,TAVERN.z));rooms.was_inside=false;rooms._process(0.0);await live(0.3)
	if not check(bank().room=="VILLAGE","Village room not entered"): return
	if not check(rooms.enter_room("CAN") and bank().conversation.sequence=="CAN_MAID","Maid sequence"): return
	rooms.advance(1000.0);leave_all()
	if not check(int(scene.village_gate.state().shared29)==1,"Betrayal did not raise the alert"): return
	Engine.time_scale=4.0;Engine.physics_ticks_per_second=240
	scene.set_physics_process(true) # the alarm and gate already run on their own physics (single clock)
	scene.set_process_unhandled_input(false)
	for tick in range(240*40):
		await physics_frame
		if a.movable_target(78)==0 and int(scene.village_gate.pose)==0: break
	Engine.time_scale=1.0;Engine.physics_ticks_per_second=60
	scene.set_physics_process(false);scene.set_process_unhandled_input(true)
	if not check(a.movable_target(78)==0 and int(scene.village_gate.pose)==0,"Alarm did not close the gate"): return
	# 4. Force gate.
	await place(Vector2(-1440,-5300));scene.camera.look_at(Vector3(-1378,40,-5300));await physics_frame
	if not check(scene.gate_leaves.interaction_hint().begins_with("E — Force gate"),"Force gate not offered: '%s'"%scene.gate_leaves.interaction_hint()): return
	await key(KEY_E)
	if not check(scene.village_gate.leaf_removed(78),"Force gate did not break leaf78"): return
	# 5. Grounded walk out and to the monastery entrance.
	if not check(await walk(Vector2(-1300,-5300),900) and scene.player.global_position.x>-1330,"Could not walk through the gap"): return
	# Broken-leaf persistence before any source relink region (the MENT leg crosses region3896, which restores the gate).
	var gap:="user://tests/village_escape_focused_gap.json"
	if not check(scene.quicksave(gap).is_empty() and scene.quickload(gap).is_empty() and scene.village_gate.leaf_removed(78) and scene.gate_leaves.panels["81"].visible,"Gap save/reload lost the broken leaf"): return
	scene.set_physics_process(false)
	var route: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/hive_quest_walk_routes.json")).tavern_to_monastery
	# Continue from the route's first point outside the gate (admission region2443): the nearest point to OUTSIDE is
	# the passage point (-1376,-5249) between the leaves, where unbroken leaf79's edge stands.
	var start: int=route.regions.find(2443.0) if route.regions.has(2443.0) else route.regions.find(2443)
	if not check(start>=0,"Monastery route has no region2443 point"): return
	for i in range(start,route.points.size()):
		if not check(await walk(Vector2(route.points[i][0],route.points[i][1]),2400),"Walk stuck at monastery route point %d"%i): return
		if rooms.active(): break
	if not check(rooms.active() and bank().room=="MENT","Did not reach the monastery entrance: room '%s'"%bank().room): return
	var save_error: String=scene.quicksave(final)
	if not check(save_error.is_empty(),"Final save rejected: %s (health %d)"%[save_error,scene.starting_magic.health()]): return
	scene.queue_free();await process_frame;await process_frame
	await boot()
	# Region3896 on the monastery leg relinked both leaves before this save (source behaviour kept by Codex).
	if not check(scene.quickload(final).is_empty() and scene.confidante.killed() and not scene.village_gate.leaf_removed(78) and not scene.village_gate.leaf_removed(79) and not scene.gate_leaves.panels["81"].visible and int(scene.village_gate.state().shared29)==1 and int(scene.quest_state.monastery.globals.get("GV_LUTHER_KNOWS_ABOUT_DANIEL",0))==1,"Restart lost the escape state"): return
	DirAccess.remove_absolute(earned);DirAccess.remove_absolute(gap)
	print("PASS jungle_village_escape_earned_test (focused components): shop Daniel knowledge, Confidante idle-window Spark kill, tavern betrayal alert and timed alarm closure, Force gate (owner-approved modern binding), grounded walk through the gap (broken leaf kept over save/load), region3896 relink on the way to MENT, in-process scene recreation. Supplied approach positions and direct room calls; final save kept at ",final)
	quit()
