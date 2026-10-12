extends SceneTree
## Live Kelsrick64 on the real Jungle host (fixture, not an earned route): the village speech completion (control99
## local15) is written into the host's village state; region entries are the real player position; E is a real key event
## through a real camera ray at his generic body; the strike is the generic population's own melee path.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const Packet=preload("res://scripts/lol2/jungle_kelsrick_packet.gd")
const FOOT:=32.0
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var on:=true
	func world_active() -> bool: return on
var scene
var ctrl
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func globals() -> Dictionary:
	if not scene.quest_state.has("monastery"): scene.quest_state.monastery={}
	if not scene.quest_state.monastery.has("globals"): scene.quest_state.monastery.globals={}
	return scene.quest_state.monastery.globals
func logged(type: String, key: String="", value: Variant=null) -> int:
	var n:=0
	for e in ctrl.effect_log:
		if e.type==type and (key=="" or e.get(key)==value): n+=1
	return n
func step_until(cond: Callable, seconds: float) -> bool:
	for i in range(roundi(seconds*30)):
		ctrl.advance(1.0/30.0)
		if i%30==0: await physics_frame
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
## Walk out and back into a source region (one entry edge).
func enter(region: int) -> void:
	scene.player.global_position=Vector3(0,0,0)+ctrl.origin()+Vector3(9000,0,9000);ctrl.advance(1.0/30.0)
	scene.player.global_position=region_point(region);ctrl.advance(1.0/30.0)
## Stand within reach of Kelsrick on the first open approach (he stands among village walls) and look at him.
func face_kelsrick() -> bool:
	var p: Vector3=ctrl.population.bodies["64"].global_position
	for i in range(16):
		var angle:=TAU*float(i%8)/8.0;var distance:=60.0 if i<8 else 35.0
		scene.player.global_position=p+Vector3(sin(angle)*distance,FOOT+10,cos(angle)*distance)
		await physics_frame
		scene.camera.look_at(p+Vector3.UP*30)
		await physics_frame
		if ctrl.population.aimed()=="64": return true
	return false
func press_e() -> void:
	var key:=InputEventKey.new();key.keycode=KEY_E;key.pressed=true
	ctrl._unhandled_input(key)
## Host save → JSON → portable quest validation → atomic restore must reproduce the packet exactly.
func save_roundtrip(label: String) -> bool:
	scene._sync_exit_checkpoint()
	var before: Dictionary=scene.quest_state.jungle_kelsrick.duplicate(true)
	var parsed=JSON.parse_string(JSON.stringify(scene.quest_state,"  ",true,true))
	if not check(Save.Quests.validate(parsed).is_empty(),label+": saved quests rejected: "+Save.Quests.validate(parsed)): return false
	if not check(ctrl.restore(parsed.jungle_kelsrick).is_empty(),label+": restore failed"): return false
	var after: Dictionary=ctrl.checkpoint()
	if after!=before:
		for k in before:
			if before[k]!=after[k]: print("DIFF ",k," ",JSON.stringify(before[k])," VS ",JSON.stringify(after[k]))
	return check(ctrl.checkpoint()==before,label+": packet differs after reload")
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
	ctrl=scene.kelsrick
	if not check(ctrl!=null and is_instance_valid(ctrl),"Production Kelsrick setup failed"):return
	ctrl.set_physics_process(false)
	var g:=globals();g.GV_LUTHERS_SOUL=5
	if not check(ctrl.state.present and ctrl.population.meshes["64"].visible and not ctrl.mesh.visible and ctrl.targets().has("junglekelsrick64"),"Kelsrick not standing at load"):return
	# Talk1 needs the village speech completion: entering 3567 before it does nothing.
	scene.village_dialogue.state().local15=0
	enter(3567)
	if not check(ctrl.state.clip.is_empty() and not ctrl.input_locked(),"Talk1 ran before the village speech"):return
	# Completed control99 speech, as its own completion group21174 leaves it.
	scene.village_gate.state().local24=1
	var d: Dictionary=scene.village_dialogue.state();d.started=true;d.elapsed=preload("res://scripts/lol2/jungle_village_state.gd").SPEECH_DURATION;d.local15=1
	var before: Vector3=scene.player.global_position
	enter(3567)
	if not check(not ctrl.state.clip.is_empty() and int(ctrl.state.clip.selector)==9 and int(ctrl.state.clip.segment)==1,"Talk1 clip differs"):return
	if not check(ctrl.input_locked() and scene.actor_input_locked() and not scene.open_inventory() and not scene.request_jump(),"Hold 0x26 did not lock host input"):return
	if not check(ctrl.mesh.visible and not ctrl.population.meshes["64"].visible and ctrl.clip_frame()>=0,"Clip not presented in world"):return
	if not check(logged("reposition")==1 and scene.player.global_position.distance_to(before)>1.0,"Talk1 reposition not applied"):return
	# Rendered evidence of the in-world clip (inspected by eye; not a pixel assertion).
	if DisplayServer.get_name()!="headless":
		var p: Vector3=ctrl.mesh.global_position
		scene.camera.look_at(p+Vector3.UP*ctrl.mesh.mesh.size.y*0.5)
		for i in range(3): await process_frame
		scene.get_viewport().get_texture().get_image().save_png("res://tmp/kelsrick_talk1_live.png")
	# Mid-clip host save/restore; malformed packets change nothing.
	await step_until(func():return float(ctrl.state.clip.elapsed)>1.0,3.0)
	if not save_roundtrip("Mid-talk1"):return
	var good: Dictionary=ctrl.checkpoint()
	var bad: Array=[]
	var b1:=good.duplicate(true);b1.hold="yes";bad.append(b1)
	var b2:=good.duplicate(true);b2.inside=[3567,3567];bad.append(b2)
	var b3:=good.duplicate(true);b3.receipts=["zz"];bad.append(b3)
	var b4:=good.duplicate(true);b4.state.owner_state=255;bad.append(b4)
	var b5:=good.duplicate(true);b5.body.actors["64"].present=false;bad.append(b5)
	for packet in bad:
		if not check(not ctrl.restore(packet).is_empty() and ctrl.checkpoint()==good,"Malformed packet %d accepted or mutated"%bad.find(packet)):return
	var quests: Dictionary=scene.quest_state.duplicate(true);quests.jungle_kelsrick=b4
	if not check(not Save.Quests.validate(quests).is_empty(),"Quest validator accepted an unreachable Kelsrick packet"):return
	# Clip end → event0 → 30684 releases the hold; its external control98 request is kept as a receipt.
	if not check(await step_until(func():return ctrl.state.clip.is_empty(),40.0),"Talk1 never ended"):return
	if not check(not ctrl.input_locked() and not scene.actor_input_locked() and logged("player_property","property",0x27)==1 and not ctrl.receipts.is_empty(),"Talk1 release differs"):return
	enter(3567)
	if not check(ctrl.state.clip.is_empty(),"Talk1 repeated"):return
	# Held-item E-use (kind4 mode1, owner state0): empty hand does nothing, a held item plays the refusal segment2.
	if not check(await face_kelsrick(),"No open approach to Kelsrick"):return
	scene.hand_item=""
	if not check(ctrl.can_use(),"Kelsrick not aimed/reachable"):return
	press_e()
	if not check(ctrl.state.clip.is_empty(),"Empty hand admitted"):return
	# Held through the production inventory's hold action (Jungle wording), then closed.
	if not check(scene.open_inventory() and scene.inventory.hold_label=="Hold in hand" and scene.inventory.hold_item.call(Save.Museum.SWORD) and scene.hand_item==Save.Museum.SWORD,"Inventory hold differs"):return
	scene.inventory.close()
	await process_frame
	press_e()
	if not check(not ctrl.state.clip.is_empty() and int(ctrl.state.clip.segment)==2 and int(ctrl.state.clip.selector)==9,"Held-item refusal differs"):return
	if not check(await step_until(func():return ctrl.state.clip.is_empty(),30.0),"Refusal never ended"):return
	scene.hand_item=""
	# Region2750 then 3567 → talk2 (E081E).
	enter(2750);enter(3567)
	if not check(not ctrl.state.clip.is_empty() and int(ctrl.state.clip.selector)==11,"Talk2 differs"):return
	if not check(await step_until(func():return ctrl.state.clip.is_empty(),60.0) and not ctrl.input_locked(),"Talk2 never released"):return
	if not save_roundtrip("After talk2"):return
	# Owner state1 (after region2750): record30710's predicate no longer admits the refusal.
	if not check(await face_kelsrick(),"No open approach to Kelsrick"):return
	scene.hand_item=Save.Museum.SWORD
	press_e()
	if not check(ctrl.state.clip.is_empty(),"Held item answered outside owner state0"):return
	scene.hand_item=""
	# Real generic melee strike (sword) → source kind9 30456 → hostile state40 + HULINE_ALERT + segment3 → fight.
	await face_kelsrick()
	ctrl.advance(1.0/30.0)
	if not check(ctrl.population.aimed()=="64" and ctrl.population.strike(),"Generic strike on Kelsrick failed"):return
	ctrl.advance(1.0/30.0)
	if not check(int(ctrl.state.owner_state)==40 and int(ctrl.state.locals["52"])==1 and int(scene.village_gate.state().shared29)>=1 and int(ctrl.state.clip.segment)==3,"Melee hit admission differs: state %d"%int(ctrl.state.owner_state)):return
	if not check(await step_until(func():return ctrl.state.clip.is_empty(),30.0) and ctrl.fighting() and ctrl.population.state.actors["64"].woken,"Hostile wake differs"):return
	if not check(ctrl.targets().has("junglekelsrick64") and scene.starting_magic.get_script()!=null,"Hostile Kelsrick not a spell target"):return
	if not save_roundtrip("Hostile"):return
	# Spark (context 1/1) is mirrored as a non-melee hit; the latch keeps 30456 one-shot.
	var groups_before:=logged("group")
	ctrl.population.last_melee=false
	ctrl.population.state.actors["64"].health=int(ctrl.population.state.actors["64"].health)-3
	ctrl.advance(1.0/30.0)
	if not check(logged("group")==groups_before and int(ctrl.state.health)==int(ctrl.population.state.actors["64"].health),"Spark hit re-ran a latched record or desynced health"):return
	print("PASS: live Kelsrick64 on the Jungle host: village-gated talk1 E079E with 0x26 hold locking host input and reposition, mid-clip host save/JSON/quest validation/atomic restore, malformed rejected unchanged, release 0x27 + control98 receipt, no repeat; region2750→talk2 E081E; real E-use at owner0: empty hand none, inventory-held item refusal seg2 (none after state1); real generic sword strike → state40/HULINE_ALERT/seg3 → hostile fight + spell target, saved; Spark mirrored without re-running latched records")
	quit()
