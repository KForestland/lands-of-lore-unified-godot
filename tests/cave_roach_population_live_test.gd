extends SceneTree
const State=preload("res://scripts/lol2/cave_roach_population_state.gd")
const Reward=preload("res://scripts/lol2/hive_live_spell_reward.gd")
const Aura=preload("res://scripts/lol2/player_spark_aura_state.gd")
# Headless display cannot capture the mouse. Only this test replaces that gate;
# actual scene rays, health, reward, save and collision paths are used unchanged.
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var running:=true
	func world_active() -> bool: return running
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for frame in range(600):
		await process_frame
		if scene.walkthrough_ready:break
	if not check(scene.walkthrough_ready,"Cave not ready"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var spells:=TestMagic.new();scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	var live=scene.roach_population_live
	if not check(live.bodies.size()==23 and live.targets().size()==23 and live.reward_scale==1,"Source population/reward binding differs"):return
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(State.SOURCE))
	for row in source.actors:
		var id:=str(int(row.actor));var p: Array=row.position
		if not check(live.bodies[id].position==Vector3(p[0],p[1],p[2])+scene.native_translation and scene.roach_population.actors[id].health==10,"Source spawn differs"):return
	for id in live.animations:
		if not check(live.animations[id].action_key==-1 and live.animations[id].view_slot==0 and scene.roach_population.visuals[id].action==0,"Fresh source idle differs"):return
	# Existing saved action9 clips retain their independent clocks.
	scene.roach_population.visuals["25"]={"action":9,"elapsed":0.0}
	scene.roach_population.visuals["26"]={"action":9,"elapsed":0.0}
	live.advance(0.375)
	if not check(live.animations["25"].frame_index==3 and live.animations["26"].frame_index==3,"Per-actor startup clock differs"):return
	var pause: Dictionary=scene.roach_population.duplicate(true)
	spells.running=false;live.advance(3.0)
	if not check(scene.roach_population==pause,"Paused actors advanced"):return
	spells.running=true
	# Search a real unobstructed approach to source actor40, without moving it.
	var body: CharacterBody3D=live.bodies["40"]
	var target: Vector3=body.global_position+Vector3(0,6,0)
	var aimed:=false
	for offset in [Vector3(0,20,45),Vector3(0,20,-45),Vector3(45,20,0),Vector3(-45,20,0),Vector3(0,40,0.1)]:
		scene.player.position=target+offset-scene.camera.position
		scene.camera.look_at(target)
		for i in 2:await physics_frame
		var query:=PhysicsRayQueryParameters3D.create(scene.camera.global_position,target,3,[scene.player.get_rid()])
		var hit: Dictionary=scene.get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.collider==body:aimed=true;break
	if not check(aimed,"No clear source actor40 approach"):return
	var health_before: int=scene.roach.model.player_health
	var untouched: Dictionary=scene.roach_population.actors["41"].duplicate(true)
	var before: Dictionary=spells.magic_state().duplicate(true)
	var predicted: Dictionary=before.duplicate(true);predicted.player.mana-=1
	var reward:=Reward.apply(predicted,int(predicted.get("spark_reward_seed",324508639)),8,20,1)
	if not check(spells.cast() and scene.roach_population.actors["40"].health==2,"Actual Spark ray missed population target"):return
	if not check(spells.magic_state().player==reward.checkpoint.player and scene.roach_population.actors["41"]==untouched and scene.roach.model.player_health==health_before,"Population Spark reward/ownership differs"):return
	var path:="user://tests/cave_roach_population_live.json"
	if not check(scene._quicksave(path).is_empty(),"Live population save failed"):return
	var saved: Dictionary=scene.roach_population.duplicate(true)
	var saved_magic: Dictionary=spells.magic_state().duplicate(true)
	# Aura dispatch must award only the2 HP actually removed, with scale1.
	reward=Reward.apply(saved_magic,int(saved_magic.get("spark_reward_seed",324508639)),2,23,1)
	spells.aura.hit("caveroach40",23,live.targets()["caveroach40"])
	if not check(scene.roach_population.actors["40"].health==0 and body.collision_layer==0 and live.animations["40"].action_key==14 and spells.magic_state().player==reward.checkpoint.player,"Aura loss/reward/death dispatch differs"):return
	var after_magic: Dictionary=spells.magic_state().duplicate(true)
	if not check(not live.receive_damage("40",100,false,23) and spells.magic_state()==after_magic,"Corpse awarded duplicate XP"):return
	live.advance(0.625)
	if not check(live.animations["40"].frame_index==5 and live.animations["25"].action_key==-1,"Death clock contaminated living startup"):return
	if not check(scene._quicksave(path+".dead").is_empty(),"Partial death save failed"):return
	live.advance(4.0)
	if not check(not live.meshes["40"].visible,"Completed collapse remained visible"):return
	if not check(scene._quickload(path+".dead").is_empty() and live.animations["40"].frame_index==5 and body.collision_layer==0,"Partial death rollback differs"):return
	scene.set_physics_process(false)
	if not check(scene._quickload(path).is_empty() and scene.roach_population==saved and body.collision_layer==2 and spells.magic_state()==saved_magic,"Live rollback lost health/visual/XP"):return
	scene.set_physics_process(false)
	var bad: Dictionary=scene._save_state();bad.roach_population.visuals["40"].action=14
	var file:=FileAccess.open(path+".bad",FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
	if not check(not scene._quickload(path+".bad").is_empty() and scene.roach_population==saved,"Malformed visuals partially changed live state"):return
	for id in Aura.CAVE_ROACH_IDS:
		if not check(Aura.valid_target("caveroach"+str(id)),"Source aura identity rejected"):return
	for id in ["caveroach36","caveroach025","caveroach-1","caveroach51junk",null]:
		if not check(not Aura.valid_target(id),"Invalid cave aura identity admitted"):return
	var aura:=Aura.initial();aura.area=scene.scene_file_path
	aura.bolts=[{"target":"caveroach40","effect":20,"position":[target.x,target.y,target.z],"life":1.0}]
	if not check(Aura.validate(JSON.parse_string(JSON.stringify(aura))).is_empty(),"Population bolt JSON rejected"):return
	# Melee shares the entrance actor's single cooldown and obeys physical walls.
	scene.roach_population=State.initial();live.restore()
	scene.equipped_item="";scene.player_form=0
	if not check(not live.strike() and scene.roach_population.actors["40"].health==10,"Unequipped human struck population"):return
	var weapon=preload("res://scripts/lol2/cave_stalagmite.gd")
	scene.stalagmites.restore([weapon.item_id(641,1)])
	if not check(scene.set_equipped_item(weapon.item_id(641,1)),"Fixture weapon selection failed"):return
	scene.roach.model.strike_remaining=0.0
	var wall:=StaticBody3D.new();wall.collision_layer=1
	var collider:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(12,12,12);collider.shape=box
	wall.add_child(collider);scene.add_child(wall)
	wall.global_position=scene.camera.global_position.lerp(target,0.5)
	for i in 2:await physics_frame
	if not check(not live.strike() and scene.roach_population.actors["40"].health==10,"Melee passed through a wall"):return
	wall.queue_free();await physics_frame;await physics_frame
	var entrance_hp: int=scene.roach.model.enemy_health
	if not check(live.strike() and scene.roach_population.actors["40"].health==2 and scene.roach.model.enemy_health==entrance_hp,"Melee target routing failed"):return
	if not check(not live.strike() and scene.roach_population.actors["40"].health==2,"Melee bypassed shared cooldown"):return
	scene.roach.model.advance(0.5,1000,false)
	if not check(live.strike() and scene.roach_population.actors["40"].health==0,"Second earned cooldown strike failed"):return
	print("PASS:23 source bodies, independent animation/pause, Spark ray/scale1 rewards, aura/overkill, partial death/live disk rollback, malformed rejection and equipped melee/wall/shared-cooldown routing")
	scene.queue_free();await process_frame;quit()
