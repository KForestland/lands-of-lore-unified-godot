extends SceneTree
## Monastery library attack on the real Jungle host, then the Hive: in MLIB with Dawn installed, the Use Weapon key (F,
## room message7) runs the native MLIB 0x98F/0xF09 effects and plays the original reaction 0377307E. Flags191/190/185,
## GV_DAWN_ATTACKED_IN_MONASTERY, soul −1 and the relationship net 0 match the native replay. The test also checks a
## disk save/load mid-reaction, that Dawn is absent on return (flag191) and that a repeat attack does nothing. The
## carried monastery bank then reaches the Hive, where the RUNES entry (with copied runes) brings Dawn20, who translates.
## Supplied: library admission prerequisites (GV_MET_BACATTA, first visit done) and the Hive rune copy.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const Quest=preload("res://scripts/lol2/monastery_quest_state.gd")
const Speech=preload("res://scripts/lol2/monastery_conversation.gd")
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed=true;push_error(message);quit(1)
	return ok
## Saved banks reload integers as floats: compare numerically.
func same(a: Dictionary, b: Dictionary) -> bool:
	if a.size()!=b.size(): return false
	for k in a:
		if not b.has(k) or float(a[k])!=float(b[k]): return false
	return true
func key(node: Node, code: int) -> void:
	var e:=InputEventKey.new();e.keycode=code;e.physical_keycode=code;e.pressed=true
	node._unhandled_input(e)

func run() -> void:
	var path:="user://tests/monastery_library_attack.json"
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	var scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in 5: await process_frame
	var rooms=scene.monastery
	var m:=Quest.initial()
	m.globals.GV_MET_BACATTA=1;m.globals.GV_LUTHERS_SOUL=3;m.globals.GV_DAWN_RELATIONSHIP=5;m.flags["184"]=1
	scene.quest_state.monastery=m
	if not check(rooms.enter_room("MENT") and rooms.enter_room("MLIB") and Quest.dawn_present(rooms.state()),"Library with Dawn not entered"):return
	key(rooms,KEY_F)
	var s: Dictionary=rooms.state()
	if not check(s.conversation.sequence=="MLIB_ATTACK" and Speech.active(s.conversation),"Use Weapon did not start the reaction"):return
	if not check(int(s.globals.GV_DAWN_ATTACKED_IN_MONASTERY)==1 and int(s.globals.GV_LUTHERS_SOUL)==2 and int(s.globals.GV_DAWN_RELATIONSHIP)==5 and int(s.flags["191"])==1 and int(s.flags["190"])==1 and int(s.flags["185"])==1,"Attack effects differ: %s"%[s.globals]):return
	for i in 20: rooms.advance(0.05);await process_frame
	if not check(rooms.view.clip.get("frames",0)==97 and rooms.view.voice.playing,"Original reaction 0377307E not presented"):return
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://captures")
	root.get_texture().get_image().save_png("user://captures/monastery_library_attack.png")
	# Disk save mid-reaction and reload.
	var saved: Dictionary=rooms.state().duplicate(true)
	var se: String=scene.quicksave(path);var le: String=scene.quickload(path) if se.is_empty() else "skipped"
	if not check(se.is_empty() and le.is_empty() and rooms.state().conversation.sequence=="MLIB_ATTACK" and same(rooms.state().globals,saved.globals) and same(rooms.state().flags,saved.flags),"Mid-reaction save/load differs: save=%s load=%s seq=%s"%[se,le,rooms.state().conversation.sequence]):return
	for i in 200:
		rooms.advance(0.05)
		if not Speech.active(rooms.state().conversation): break
	if not check(not Speech.active(rooms.state().conversation) and not Quest.dawn_present(rooms.state()),"Reaction did not finish with Dawn gone"):return
	key(rooms,KEY_F)
	if not check(rooms.state().conversation.sequence=="MLIB_ATTACK" and not Speech.active(rooms.state().conversation) and int(rooms.state().globals.GV_LUTHERS_SOUL)==2,"Repeat attack changed state"):return
	# Return: leave and re-enter the library — she stays away.
	rooms.leave_room()
	if not check(rooms.state().room=="MENT" and not Quest.enter_library(rooms.state()),"Dawn returned to the library"):return
	rooms.leave_room()
	if not check(Quest.validate(rooms.state()).is_empty(),"Monastery state invalid after attack"):return
	# Carry to the Hive: copied runes (supplied) + RUNES entry → Dawn20 translates.
	var handoff: Dictionary=scene.area_handoff()
	scene.queue_free();for i in 3: await process_frame
	var hive=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive);current_scene=hive
	await process_frame;await physics_frame
	hive.set_development_mode(false);hive.set_physics_process(false);hive.get_node("Warriors").set_process(false)
	if not check(hive.apply_area_handoff(handoff).is_empty() and int(hive.monastery_checkpoint.globals.GV_DAWN_ATTACKED_IN_MONASTERY)==1,"Hive did not carry the monastery attack"):return
	hive.set_physics_process(false) # the handoff re-enables host physics; the fixture aim needs a still player
	hive.monastery_checkpoint.globals.GV_HAS_RUNES=1
	hive.dawn20.set_physics_process(false)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	hive.player.position=Vector3(-3156,-1620,-6138)
	var direction: Vector3=Vector3(-3156,-1657,-6178)-hive.camera.global_position
	hive.player.rotation.y=atan2(-direction.x,-direction.z);hive.camera.rotation.x=atan2(direction.y,Vector2(direction.x,direction.z).length())
	await physics_frame
	var conv=hive.get_node("ConversationReview")
	if not check(hive.runes.interact(),"RUNES entry failed: active=%s flying=%s paused=%s mouse=%s cursor=%s warriors=%s conv=%s/%s"%[hive.runes.active(),hive.flying,paused,Input.mouse_mode,hive.interface_hud.cursor_active,hive.get_node("Warriors").health,conv.started,conv.completed]):return
	hive.runes.leave()
	if not check(hive.dawn20.state.present and hive.dawn20.talking() and int(hive.monastery_checkpoint.globals.GV_RUNES_TRANSLATED)==1,"Dawn20 did not follow the earned monastery attack"):return
	hive.queue_free();for i in 3: await process_frame
	DirAccess.remove_absolute(path)
	if failed: return
	print("PASS monastery library attack live: F (msg7) in MLIB → native effects (attacked, soul−1, relationship net0, flags191/190/185), original 0377307E reaction, mid-reaction disk save/load, Dawn absent afterwards and on return, repeat inert, Jungle→Hive carry → RUNES entry → Dawn20 translates. Supplied: library prerequisites and rune copy.")
	quit()
