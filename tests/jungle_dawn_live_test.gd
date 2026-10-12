extends SceneTree
## Live Dawn63 on the real Jungle host (fixture, not an earned route): rune possession is written into the host's
## named globals and carried inventory; region entries are the real player position; sighting is the production
## camera frustum + world ray; E is a real key event through a real camera ray at her generic body; the offered
## item is held through the production inventory; the strike is the generic population's own melee path.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const FOOT:=32.0
const RUNES:="hive:Wax_runes:0"
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var on:=true
	func world_active() -> bool: return on
var scene
var ctrl
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func globals() -> Dictionary: return scene.quest_state.monastery.globals
func logged(type: String, key: String="", value: Variant=null) -> int:
	return ctrl.effect_log.filter(func(e):return e.type==type and (key=="" or e.get(key)==value)).size()
func step_until(cond: Callable, seconds: float) -> bool:
	for i in range(roundi(seconds*30)):
		ctrl.advance(1.0/30.0)
		if i%60==0: await physics_frame
		if cond.call(): return true
	return false
func region_point(region: int) -> Vector3:
	for r in ctrl.src.regions:
		if int(r.region)!=region: continue
		var c:=Vector2.ZERO
		for v in r.polygon: c+=Vector2(v[0],v[1])
		c/=r.polygon.size()
		return Vector3(c.x,float(r.floor_min)+FOOT,c.y)+ctrl.origin()
	return Vector3.ZERO
func enter(region: int) -> void:
	scene.player.global_position=ctrl.origin()+Vector3(9000,0,9000);ctrl.advance(1.0/30.0)
	scene.player.global_position=region_point(region);ctrl.advance(1.0/30.0)
## First open approach within reach, looking at her.
func face_dawn(distance: float=60.0) -> bool:
	var p: Vector3=ctrl.population.bodies["63"].global_position
	for i in range(16):
		var angle:=TAU*float(i%8)/8.0;var d:=distance if i<8 else distance*0.6
		scene.player.global_position=p+Vector3(sin(angle)*d,FOOT+10,cos(angle)*d)
		await physics_frame
		scene.camera.look_at(p+Vector3.UP*30)
		await physics_frame
		if ctrl.population.aimed()=="63": return true
	return false
## Any open line of sight (production frustum + world ray), at a distance.
func view_dawn() -> bool:
	var p: Vector3=ctrl.population.bodies["63"].global_position
	for i in range(8):
		var angle:=TAU*float(i)/8.0
		scene.player.global_position=p+Vector3(sin(angle)*300,FOOT+10,cos(angle)*300)
		await physics_frame
		scene.camera.look_at(p+Vector3.UP*40)
		await physics_frame
		if ctrl.visible_to_camera(): return true
	return false
func press_e() -> void:
	var key:=InputEventKey.new();key.keycode=KEY_E;key.pressed=true
	ctrl._unhandled_input(key)
func save_roundtrip(label: String) -> bool:
	scene._sync_exit_checkpoint()
	var before: Dictionary=scene.quest_state.jungle_dawn.duplicate(true)
	var parsed=JSON.parse_string(JSON.stringify(scene.quest_state,"  ",true,true))
	if not check(Save.Quests.validate(parsed).is_empty(),label+": saved quests rejected: "+Save.Quests.validate(parsed)): return false
	if not check(ctrl.restore(parsed.jungle_dawn).is_empty(),label+": restore failed"): return false
	return check(ctrl.checkpoint()==before,label+": packet differs after reload")
## Fresh host scene with runes known and carried.
func load_scene() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD,RUNES],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	for node in [scene.exit_encounter,scene.bacatta,scene.kelsrick,scene.villager_population,scene.dino_population]:
		if node!=null and is_instance_valid(node): node.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var spells:=TestMagic.new();spells.host=scene;scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	ctrl=scene.dawn
	ctrl.set_physics_process(false)
	if not scene.quest_state.has("monastery"): scene.quest_state.monastery=preload("res://scripts/lol2/monastery_quest_state.gd").initial()
	var g:=globals();g.GV_HAS_RUNES=1;g.GV_LUTHERS_SOUL=5;g.GV_DAWN_RELATIONSHIP=1
## Spawn, sight and talk through segments 1..3 into the waiting idle loop.
func reach_waiting(look: bool=true) -> bool:
	if not look:
		# Look straight up and away from her spot for the whole approach.
		scene.camera.look_at(scene.camera.global_position+Vector3(0,1,0.001))
		await physics_frame
	enter(2812)
	# Shown either as her body sprite or, once sighted in the same step, as her idle clip.
	if not check(ctrl.state.present and (ctrl.population.meshes["63"].visible or ctrl.mesh.visible),"Dawn did not spawn"): return false
	if look:
		if not check(ctrl.state.sighted or await view_dawn(),"No open view of Dawn"): return false
		ctrl.advance(1.0/30.0)
		if not check(ctrl.state.sighted and int(ctrl.state.clip.segment)==0 and bool(ctrl.state.clip.repeat) and ctrl.mesh.visible,"Sighting idle differs"): return false
	else:
		# Never looked at: the 2842 entry itself must count as noticing her (no soft-lock).
		if not check(not ctrl.state.sighted and not ctrl.visible_to_camera(),"Unseen-approach fixture saw Dawn"): return false
	enter(2842)
	if not check(int(ctrl.state.clip.segment)==1 and ctrl.input_locked() and scene.actor_input_locked() and not scene.open_inventory() and not scene.request_jump(),"Talk start/hold differs"): return false
	return check(await step_until(func():return int(ctrl.state.owner_state)==3 and bool(ctrl.state.clip.repeat),70.0),"Talk never reached waiting")
func run() -> void:
	await load_scene()
	if not check(ctrl!=null and is_instance_valid(ctrl),"Production Dawn setup failed"):return
	if not check(not ctrl.state.present and ctrl.targets().is_empty(),"Dawn present at load"):return
	# Without runes she never appears.
	globals().GV_HAS_RUNES=0
	enter(2812)
	if not check(not ctrl.state.present,"Spawned without runes"):return
	globals().GV_HAS_RUNES=1
	if not await reach_waiting(): return
	if not check(not scene.curse.requests_enabled(),"Dawn command25 did not disable shared transformation requests"):return
	var curse_before: Dictionary=scene.curse.snapshot()
	if not check(not scene.curse.request_timed_form(2,120) and scene.curse.snapshot()==curse_before,"Dawn waiting admitted a curse or consumed RNG"):return
	var gate_save: String="user://tests/dawn_admission.json"
	if not check(scene.quicksave(gate_save).is_empty(),"Waiting admission disk save failed"):return
	scene.curse.set_requests_enabled(true)
	if not check(scene.quickload(gate_save).is_empty() and not scene.curse.requests_enabled(),"Waiting admission was lost on disk reload"):return
	DirAccess.remove_absolute(gate_save)
	# Rendered evidence of the in-world clip (inspected by eye; not a pixel assertion).
	if DisplayServer.get_name()!="headless":
		var p: Vector3=ctrl.mesh.global_position
		scene.camera.look_at(p+Vector3.UP*ctrl.mesh.mesh.size.y*0.5)
		for i in range(3): await process_frame
		scene.get_viewport().get_texture().get_image().save_png("res://tmp/dawn_waiting_live.png")
	# Waiting: still held in place, but the inventory and E are live.
	if not check(ctrl.movement_locked() and not scene.actor_input_locked() and not scene.request_jump(),"Waiting lock differs"):return
	if not save_roundtrip("Waiting"):return
	var good: Dictionary=ctrl.checkpoint()
	var bad: Array=[]
	var b1:=good.duplicate(true);b1.state.owner_state=2;bad.append(b1)
	var b2:=good.duplicate(true);b2.body.actors["63"].present=false;bad.append(b2)
	var b3:=good.duplicate(true);b3.inside=[2812,2812];bad.append(b3)
	var b4:=good.duplicate(true);b4.state.items=["deadbeef"];bad.append(b4)
	for packet in bad:
		if not check(not ctrl.restore(packet).is_empty() and ctrl.checkpoint()==good,"Malformed packet %d accepted or mutated"%bad.find(packet)):return
	# Wax runes held through the production inventory, offered with a real E: rewards, consumption, farewell.
	if not check(await face_dawn(),"No open approach to Dawn"):return
	press_e()
	if not check(ctrl.state.clip.segment==0,"Empty hand admitted"):return
	var fighting_before=scene.quest_state.get("player_reward_state",{}).duplicate(true)
	var magic_before: Dictionary=scene.starting_magic.magic_state().duplicate(true)
	if not check(scene.open_inventory() and scene.inventory.hold_item.call(RUNES),"Inventory hold failed"):return
	scene.inventory.close();await process_frame
	press_e()
	var g:=globals()
	if not check(int(ctrl.state.clip.segment)==6 and int(g.GV_LUTHERS_SOUL)==7 and int(g.GV_DAWN_RELATIONSHIP)==2 and int(g.get("GV_GAVE_DAWN_RUNES",0))==1,"Wax offer globals differ: "+str(g)):return
	if not check(RUNES not in scene.carried_collected and scene.hand_item=="","Runes not taken"):return
	if not check(scene.quest_state.get("player_reward_state",{})!=fighting_before and scene.starting_magic.magic_state()!=magic_before,"0x0B/0x0C experience not awarded"):return
	if not check(await step_until(func():return not ctrl.state.present,60.0),"Farewell never completed"):return
	if not check(not ctrl.movement_locked() and not scene.actor_input_locked() and int(g.GV_DAWN_RELATIONSHIP)==2 and ctrl.targets().is_empty(),"Farewell release/cap differs"):return
	if not check(scene.curse.requests_enabled(),"Farewell command24 did not restore transformation requests"):return
	if not save_roundtrip("Departed"):return
	# Second scene: strike her while she waits → one-shot hit, seg12, hostile with her own item, then killable.
	scene.queue_free();await process_frame
	await load_scene()
	if not await reach_waiting(false): return
	if not check(await face_dawn(),"No open approach to Dawn (hit)"):return
	ctrl.advance(1.0/30.0)
	if not check(ctrl.population.strike(),"Generic strike on Dawn failed"):return
	ctrl.advance(1.0/30.0)
	g=globals()
	if not check(int(ctrl.state.owner_state)==40 and int(ctrl.state.clip.segment)==12 and int(g.GV_LUTHERS_SOUL)==4 and int(g.GV_DAWN_RELATIONSHIP)==0,"Hit admission differs: "+str(g)):return
	if not check(await step_until(func():return int(ctrl.state.owner_state)==50,20.0) and ctrl.hostile() and ctrl.state.items==["43f8bc0d"] and not ctrl.movement_locked(),"Hostile turn differs"):return
	if not check(ctrl.targets().has("jungledawn63") and RUNES in scene.carried_collected,"Hostile Dawn not a target or runes lost"):return
	if not save_roundtrip("Hostile"):return
	ctrl.population.receive_damage("63",500)
	ctrl.advance(1.0/30.0)
	if not check(int(ctrl.state.health)==0 and ctrl.targets().is_empty() and ctrl.state.hit_latches==[30266],"Hostile Dawn not killable"):return
	if not save_roundtrip("Dead"):return
	print("PASS: live Dawn63 on the Jungle host: rune-gated spawn at 2812, frustum/ray first sighting idle loop, 2842 talk seg1..3 with full input hold, waiting held in place with inventory/E live, host save/JSON/quest validation/atomic restore, malformed rejected unchanged; empty E none; inventory-held wax runes: Soul+2 (5→7), Dawn+1 capped 2, GAVE_DAWN_RUNES, +500 fighting/+500 magic XP, runes taken → farewell release; second run (never looked at her before 2842: region entry counts as noticing, talk plays, no soft-lock): real sword strike → one-shot hit Soul-1 Dawn-1 seg12 → hostile state50 with her own item (no loot), spell/strike target, killable, saved")
	quit()
