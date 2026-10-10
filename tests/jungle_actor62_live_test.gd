extends SceneTree
## Live actor62 (Huline greeting) on the real Jungle host (fixture, not an earned route): region entry is the real
## player position; his four original lines run on their decoded clocks; save/restore through the host quests.
const Save=preload("res://scripts/lol2/jungle_save.gd")
const FOOT:=32.0
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	func world_active() -> bool: return true
var scene
var ctrl
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func groups() -> Array: return ctrl.effect_log.filter(func(e):return e.type=="group").map(func(e):return e.group)
func region_point(region: int) -> Vector3:
	for r in ctrl.src.regions:
		if int(r.region)!=region: continue
		var c:=Vector2.ZERO
		for v in r.polygon: c+=Vector2(v[0],v[1])
		c/=r.polygon.size()
		return Vector3(c.x,float(r.floor_min)+FOOT,c.y)+ctrl.origin()
	return Vector3.ZERO
func save_roundtrip(label: String) -> bool:
	scene._sync_exit_checkpoint()
	var before: Dictionary=scene.quest_state.jungle_actor62.duplicate(true)
	var parsed=JSON.parse_string(JSON.stringify(scene.quest_state,"  ",true,true))
	if not check(Save.Quests.validate(parsed).is_empty(),label+": saved quests rejected: "+Save.Quests.validate(parsed)): return false
	if not check(ctrl.restore(parsed.jungle_actor62).is_empty(),label+": restore failed"): return false
	return check(ctrl.checkpoint()==before,label+": packet differs after reload")
func run() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	for node in [scene.exit_encounter,scene.bacatta,scene.kelsrick,scene.dawn,scene.villager_population,scene.dino_population]:
		if node!=null and is_instance_valid(node): node.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var spells:=TestMagic.new();spells.host=scene;scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	ctrl=scene.actor62
	if not check(ctrl!=null and is_instance_valid(ctrl),"Production actor62 setup failed"):return
	ctrl.set_physics_process(false)
	if not check(not ctrl.state.present and not ctrl.population.bodies["62"].visible,"actor62 present at load"):return
	var start: Vector3=ctrl.population.bodies["62"].global_position
	scene.player.global_position=region_point(1703);ctrl.advance(1.0/30.0)
	if not check(ctrl.state.present and ctrl.population.bodies["62"].visible and ctrl.talking() and int(ctrl.state.sound.request)==333,"Greeting did not start"):return
	if not check(ctrl.population.bodies["62"].global_position.distance_to(start)>50 and ctrl.voice.stream!=null,"Actor reposition/voice differs"):return
	await physics_frame
	for i in range(15): ctrl.advance(1.0/30.0)
	if DisplayServer.get_name()!="headless":
		var p: Vector3=ctrl.population.bodies["62"].global_position
		scene.camera.look_at(p+Vector3.UP*35)
		for i in range(3): await process_frame
		scene.get_viewport().get_texture().get_image().save_png("res://tmp/actor62_greeting_live.png")
	if not save_roundtrip("Mid-line"):return
	var good: Dictionary=ctrl.checkpoint()
	var bad: Array=[]
	var b1:=good.duplicate(true);b1.state.sound.request=258;bad.append(b1)
	var b2:=good.duplicate(true);b2.inside=[1703,1703];bad.append(b2)
	var b3:=good.duplicate(true);b3.body.actors["62"].present=false;bad.append(b3)
	for packet in bad:
		if not check(not ctrl.restore(packet).is_empty() and ctrl.checkpoint()==good,"Malformed %d accepted or mutated"%bad.find(packet)):return
	for i in range(30*12): ctrl.advance(1.0/30.0)
	if not check(int(ctrl.state.owner_state)==11 and not ctrl.talking() and groups().slice(-5)==[29512,29534,29556,29578,29610],"Line chain differs: "+str(groups())):return
	# Walk out and into another greeting region: links again, no second greeting.
	scene.player.global_position=ctrl.origin()+Vector3(9000,0,9000);ctrl.advance(1.0/30.0)
	scene.player.global_position=region_point(1672);ctrl.advance(1.0/30.0)
	if not check(not ctrl.talking() and int(ctrl.state.owner_state)==11 and ctrl.state.present,"Greeting repeated"):return
	if not save_roundtrip("After greeting"):return
	print("PASS: live actor62 Huline greeting on the Jungle host: region1703 link + event20 → original lines 333/325/258/243 (Codex-bound LOCALLNG 0220404e/0220504e/0120604e/0120704e) on decoded clocks, actor/player reposition, mid-line host save/JSON/quest validation/atomic restore, malformed rejected unchanged, release at state10, action2 clip end → event3 → 29610 state11, re-entry links without repeating")
	quit()
