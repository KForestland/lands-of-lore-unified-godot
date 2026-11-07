extends SceneTree
## PT3-UI-FALL-TEXT-OVERLAP (owner F10 2026-11-03 17:57:47; rendered, real area hosts). Every creature population used
## to draw its own label at (16,48): when Luther fell, each wrote "You fell · R: recover here · F9: load save", and a
## population whose processing its owner had switched off (Dawn or Kelsrick while talking, a friendly Bacatta) still
## showed its last aim text underneath: unreadable. target_status.gd now draws one line per host.
## - Jungle: aim at Kelsrick (his population writes "Kelsrick h/m" and the single line shows it); his owner switches the
##   population off as it does while he talks (set_process(false)): the stale text is no longer drawn. Luther falls:
##   exactly one visible label carries the fall prompt and no two visible labels overlap.
## - Museum, Dark Halls and Hive (developer overlay off, as the area routes leave it): one readable fall line, no
##   overlapping labels; in the Hive the shared line gives way to the guardians' own "Defeated" line at the same spot.
## - Not the Cave: its fall prompt is the HUD hint (classic_hud_live_test, cave_defeat_recovery_anchor_test) and its
##   population line sits under the indexed world layer 20, as the population labels did before.
## - Recovery (R through the populations' own handler) clears the prompt.
const FELL:="You fell · R: recover here · F9: load save"
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, msg: String) -> bool:
	if not ok and not failed: failed=true;push_error("FAIL: "+msg);quit(1)
	return ok
func visible_labels() -> Array:
	var out:=[]
	for n in root.find_children("*","Label",true,false):
		var l:=n as Label
		if l.is_visible_in_tree() and not l.text.strip_edges().is_empty(): out.append(l)
	return out
func overlaps() -> Array:
	var ls:=visible_labels();var bad:=[]
	for i in ls.size():
		for j in range(i+1,ls.size()):
			var a: Rect2=ls[i].get_global_rect();var b: Rect2=ls[j].get_global_rect()
			var x: Rect2=a.intersection(b)
			if x.get_area()>1.0: bad.append("%s '%s' x %s '%s'"%[ls[i].get_path(),ls[i].text.left(40),ls[j].get_path(),ls[j].text.left(40)])
	return bad
func fall_labels() -> Array: return visible_labels().filter(func(l): return "You fell" in l.text or l.text.begins_with("Defeated"))
func boot(path: String) -> Node:
	set_meta("lol2_jungle_handoff",{"collected":[],"equipped_item":"","equipped_armor":""})
	var scene: Node=load(path).instantiate();root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review") or scene.get("walkthrough_ready")==true or (i>60 and scene.get("walkthrough_ready")==null and scene.get("starting_magic")!=null): break
	# Players arrive through the area routes, which switch the developer overlay off (hive_route, dark_halls_route).
	if scene.has_method("set_development_mode"): scene.set_development_mode(false)
	for i in 5: await process_frame
	return scene
func fall_check(scene: Node, area: String) -> bool:
	if not check(scene.get("starting_magic")!=null,area+": no starting_magic"): return false
	scene.starting_magic.set_health(0)
	for i in 6: await process_frame
	# One prompt line at the top left: the shared line, or in the Hive the guardians' own "Defeated" line it yields to.
	var top:=fall_labels().filter(func(l): return l.get_global_rect().position.y<100)
	if not check(top.size()==1,"%s: %d visible top-left fall prompts: %s"%[area,top.size(),top.map(func(l): return str(l.get_path())+" '"+l.text+"'")]): return false
	var bad:=overlaps()
	if not check(bad.is_empty(),"%s: overlapping visible labels while fallen: %s"%[area,bad]): return false
	var r:=InputEventKey.new();r.keycode=KEY_R;r.physical_keycode=KEY_R;r.pressed=true;Input.parse_input_event(r);await process_frame
	r=r.duplicate();r.pressed=false;Input.parse_input_event(r)
	for i in 6: await process_frame
	if not check(scene.starting_magic.health()>0 and fall_labels().filter(func(l): return l.get_global_rect().position.y<100).is_empty(),"%s: R did not recover/clear the prompt (health %d)"%[area,scene.starting_magic.health()]): return false
	print("%s: one fall prompt, no overlap, R clears it"%area)
	return true
func unload(scene: Node) -> void:
	scene.queue_free();await process_frame;await process_frame

func run() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	var jungle: Node=await boot("res://scenes/lol2/jungle_walkthrough.tscn")
	jungle.set_physics_process(false)
	var status=jungle.get_meta("lol2_target_status") if jungle.has_meta("lol2_target_status") else null
	if not check(status!=null and is_instance_valid(status) and status.is_inside_tree(),"Jungle has no shared target status line"): return
	if not check(status.sources.size()>=3,"Jungle populations not attached: %d"%status.sources.size()): return
	# Stale aim text: Kelsrick's owner turns his population off while he talks.
	var k=jungle.kelsrick
	if not check(k!=null and is_instance_valid(k),"Kelsrick owner missing"): return
	var pop=k.population
	k.set_physics_process(false);k.set_process(false) # the test drives his population's processing switch itself
	var body: Vector3=pop.bodies["64"].global_position
	var aimed:=false
	for i in 16:
		var angle:=TAU*float(i%8)/8.0;var distance:=60.0 if i<8 else 35.0
		jungle.player.global_position=body+Vector3(sin(angle)*distance,42,cos(angle)*distance)
		await physics_frame
		jungle.camera.look_at(body+Vector3.UP*30)
		await physics_frame
		if pop.aimed()=="64": aimed=true;break
	if not check(aimed,"Could not aim at Kelsrick"): return
	pop.set_process(true)
	for i in 4: await process_frame
	if not check(pop.label.text.begins_with("Kelsrick") and status.label.text==pop.label.text and not pop.label.visible,"Aim text not on the single line: pop '%s' line '%s'"%[pop.label.text,status.label.text]): return
	pop.set_process(false) # what jungle_kelsrick.gd does while a clip/hold runs
	jungle.camera.look_at(body+Vector3(400,30,0))
	for i in 4: await process_frame
	if not check(pop.label.text.begins_with("Kelsrick") and status.label.text=="","Stale aim text still drawn: '%s'"%status.label.text): return
	if not await fall_check(jungle,"Jungle"): return
	await unload(jungle)
	for area in [["Museum","res://scenes/lol2/museum_walkthrough.tscn"],["Dark Halls","res://scenes/lol2/dark_halls.tscn"],["Hive","res://scenes/lol2/hive_review.tscn"]]:
		var scene: Node=await boot(area[1])
		if scene.has_method("set_physics_process"): scene.set_physics_process(false)
		if not await fall_check(scene,area[0]): return
		await unload(scene)
	print("PASS target_status_overlap_test: one top-left aim/fall line per host (Jungle stale Kelsrick text hidden; Jungle, Museum, Dark Halls, Hive fall prompt readable, R clears)")
	quit()
