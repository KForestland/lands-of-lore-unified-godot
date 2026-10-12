extends SceneTree
## Hive Dawn20 on the real Hive host through the existing RUNES room entry (control0 E, supplied nearby aim as in
## hive_rune_entry_test). Supplied precondition: monastery globals GV_HAS_RUNES=1 and GV_DAWN_ATTACKED_IN_MONASTERY=1
## (their live producers are the wax copy and the unimplemented MLIB attack). Proves: link queued on entry and saved
## inside the room, Dawn appears on leaving, holds and faces the player with original E075E frames/voice, translates
## the runes (GV_RUNES_TRANSLATED), input refused while she talks, disk save/load mid-talk, wait, E offer with a held
## item (segment4), armed hit (soul/relationship −1, segment8, hostile body), removal on the next room entry, and no
## Dawn without the precondition.
const Dawn=preload("res://scripts/lol2/hive_dawn20.gd")
var scene
var d
var failed:=false
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok and not failed: failed=true;push_error(message);quit(1)
	return ok
func key(code: int) -> void:
	var event:=InputEventKey.new();event.keycode=code;event.physical_keycode=code;event.pressed=true
	Input.parse_input_event(event);Input.flush_buffered_events()
	var up:=InputEventKey.new();up.keycode=code;up.physical_keycode=code;up.pressed=false
	Input.parse_input_event(up);Input.flush_buffered_events()

func open_hive(attacked: bool) -> void:
	scene=load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	await process_frame;await physics_frame
	scene.set_development_mode(false)
	scene.set_physics_process(false)
	scene.get_node("Warriors").set_process(false)
	root.grab_focus()
	await process_frame
	d=scene.dawn20
	if d!=null: d.set_physics_process(false)
	scene.monastery_checkpoint=preload("res://scripts/lol2/monastery_quest_state.gd").initial()
	scene.monastery_checkpoint.globals.merge({"GV_HAS_RUNES":1,"GV_DAWN_ATTACKED_IN_MONASTERY":1 if attacked else 0,"GV_LUTHERS_SOUL":3,"GV_DAWN_RELATIONSHIP":5},true)
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED

func aim(point: Vector3) -> void:
	var direction: Vector3=point-scene.camera.global_position
	scene.player.rotation.y=atan2(-direction.x,-direction.z)
	scene.camera.rotation.x=atan2(direction.y,Vector2(direction.x,direction.z).length())
	await physics_frame

func enter_room() -> bool:
	scene.player.position=Vector3(-3156,-1620,-6138)
	await aim(Vector3(-3156,-1657,-6178))
	key(KEY_E)
	await process_frame
	return scene.runes.active()

func step(seconds: float) -> void:
	for i in int(ceil(seconds*30.0)):
		d.advance(1.0/30.0)
		if i%15==0: await process_frame

func capture(name: String) -> void:
	for i in 3: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute("user://captures")
	root.get_texture().get_image().save_png("user://captures/%s.png"%name)

func globals() -> Dictionary: return scene.monastery_checkpoint.globals

func run() -> void:
	var path:="user://tests/hive_dawn20_live.json"
	await open_hive(true)
	if not check(d!=null and d.set_up() and not d.state.present,"Hive Dawn20 not installed absent"):return
	# Entry queues prop71 kind6/20 (pred184 true now); it is saved inside the room.
	if not check(await enter_room() and d.state.pending==[84] and not d.state.present,"RUNES entry did not queue the link"):return
	var se: String=scene.quicksave(path);var le: String=scene.quickload(path)
	if not check(se.is_empty() and le.is_empty() and scene.runes.active() and d.state.pending==[84],"In-room save lost the link queue: save=%s load=%s active=%s pending=%s"%[se,le,scene.runes.active(),d.state.pending]):return
	# Leaving the room runs the link: Dawn appears beside the source return point and talks.
	key(KEY_ESCAPE)
	await process_frame
	if not check(not scene.runes.active() and d.state.present and d.hold and d.talking() and int(d.state.clip.segment)==1,"Leaving the room did not start Dawn's talk"):return
	if not check(int(globals().get("GV_RUNES_TRANSLATED",0))==1 and int(d.state.locals["31"])==1 and d.state.items==["43f8bc0d"],"Link group84 effects differ"):return
	var body: Vector3=d.population.bodies["20"].global_position
	if not check(Vector2(body.x,body.z).distance_to(Vector2(-3063,-6333))<1.0 and Vector2(scene.player.position.x,scene.player.position.z).distance_to(Vector2(body.x,body.z))<120.0,"Dawn placement/return pose differs"):return
	await step(0.5)
	if not check(d.voice.playing and d.mesh.visible and d.clip_frame()>=int(d.media.clip.segments[1].first),"Original talk frames/voice not presented"):return
	await capture("hive_dawn20_talk")
	# Held: input is refused while she talks.
	if not check(scene.actor_input_locked() and not scene.request_jump(),"Talk does not hold input"):return
	var yaw: float=scene.player.rotation.y
	var m:=InputEventMouseMotion.new();m.relative=Vector2(400,0);Input.parse_input_event(m);Input.flush_buffered_events()
	await process_frame
	if not check(is_equal_approx(scene.player.rotation.y,yaw),"Held player turned"):return
	# Disk save/load mid-talk restores segment and clock.
	await step(3.0)
	var saved: Dictionary=d.state.duplicate(true)
	if not check(scene.quicksave(path).is_empty(),"Mid-talk save failed"):return
	await step(4.0)
	if not check(scene.quickload(path).is_empty() and d.state==saved and d.hold and d.talking(),"Mid-talk load differs"):return
	# Talk runs to the wait: hold released, idle loop.
	for i in 60:
		await step(1.0)
		if int(d.state.owner_state)==5: break
	if not check(int(d.state.owner_state)==5 and not d.hold and not scene.actor_input_locked() and bool(d.state.clip.repeat),"Talk did not reach the wait"):return
	# E offer with a held item while aimed at her (mode1 → segment4).
	var sword: String=preload("res://scripts/lol2/jungle_save.gd").Museum.SWORD
	scene.carried_inventory.collected.append(sword);scene.carried_inventory.equipped_item=sword
	scene.player.position=Vector3(body.x-70,scene.player.position.y,body.z+40)
	await aim(body+Vector3.UP*30)
	if not check(d.can_use(),"Dawn not usable when aimed"):return
	key(KEY_E)
	await process_frame
	if not check(int(d.state.clip.segment)==4 and int(d.state.locals["32"])==1,"E offer did not play segment4"):return
	await step(6.0)
	# Armed hit through the generic damage owner.
	if not check(d.population.receive_damage("20",3,true),"Damage not received"):return
	await step(0.1)
	if not check(int(d.state.owner_state)==15 and int(d.state.clip.segment)==8 and int(globals().GV_LUTHERS_SOUL)==2 and int(globals().GV_DAWN_RELATIONSHIP)==4,"Hit branch differs"):return
	await step(5.0)
	if not check(int(d.state.owner_state)==20 and d.hostile() and d.state.present,"Post-hit goals differ"):return
	# Next RUNES entry removes her (pred192).
	if not check(await enter_room() and d.state.pending==[126],"Second entry did not queue removal"):return
	key(KEY_ESCAPE);await process_frame
	if not check(not d.state.present and not d.population.state.actors["20"].present,"Second entry did not remove Dawn"):return
	var ps: String=scene.quicksave(path);var pl: String=scene.quickload(path) if ps.is_empty() else "skipped"
	if not check(ps.is_empty() and pl.is_empty() and not d.state.present and int(globals().GV_RUNES_TRANSLATED)==1,"Post-removal save differs: save=%s load=%s"%[ps,pl]):return
	# Atomic rejection of a malformed packet.
	var good: Dictionary=d.checkpoint();var bad: Dictionary=good.duplicate(true);bad.state.pending=[999]
	if not check(not d.restore(bad).is_empty() and d.checkpoint()==good and not preload("res://scripts/lol2/act_one_quest_state.gd").validate({"hive_dawn20":bad}).is_empty(),"Malformed packet applied"):return
	scene.queue_free();for i in 3: await process_frame
	# Without the monastery attack no Dawn appears.
	await open_hive(false)
	if not check(await enter_room() and d.state.pending.is_empty(),"Unattacked entry queued Dawn"):return
	key(KEY_ESCAPE);await process_frame
	if not check(not d.state.present and int(globals().get("GV_RUNES_TRANSLATED",0))==0,"Dawn appeared without the precondition"):return
	scene.queue_free();for i in 3: await process_frame
	DirAccess.remove_absolute(path)
	if failed: return
	print("PASS hive dawn20 live: RUNES entry queues prop71 link (saved in room), leaving runs it → Dawn20 at source placement, hold/facing, original E075E frames+voice, GV_RUNES_TRANSLATED, input refused, mid-talk disk save/load, wait, E offer segment4, armed hit (soul/relationship −1, segment8, hostile), removal on next entry, atomic packet, none without precondition. Supplied precondition and aim.")
	quit()
