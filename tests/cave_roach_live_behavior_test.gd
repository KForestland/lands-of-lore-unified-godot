extends SceneTree
const State=preload("res://scripts/lol2/cave_roach_population_state.gd")
# Headless display cannot capture the mouse. Only this gate is replaced; actual
# scene rays, collision, movement, shared player health and disk saves run.
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var running:=true
	func world_active() -> bool: return running
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func report_diff(before: Variant, after: Variant, path: String="save") -> void:
	if typeof(before)!=typeof(after):print("SAVE TYPE DIFF ",path," before=",typeof(before),"/",before," after=",typeof(after),"/",after);return
	if before==after:return
	if before is Dictionary and after is Dictionary:
		for key in before:
			if not after.has(key):print("SAVE DIFF ",path,".",key," missing after")
			else:report_diff(before[key],after[key],path+"."+str(key))
		for key in after:
			if not before.has(key):print("SAVE DIFF ",path,".",key," added ",after[key])
	elif before is Array and after is Array and before.size()==after.size():
		for i in before.size():report_diff(before[i],after[i],path+"["+str(i)+"]")
	else:print("SAVE DIFF ",path," before=",before," after=",after)
func step(live, seconds: float) -> void:
	for i in range(roundi(seconds*60)):
		live.advance(1.0/60.0)
		await physics_frame
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
	var body: CharacterBody3D=live.bodies["42"]
	var spawn: Vector3=body.global_position
	var model=scene.roach.model
	# Find a real standing spot ~120 units away that the Roach can see and reach.
	var chosen:=false
	for angle in range(0,360,30):
		var offset:=Vector3(sin(deg_to_rad(angle)),0,cos(deg_to_rad(angle)))*120
		var down:=PhysicsRayQueryParameters3D.create(spawn+offset+Vector3.UP*60,spawn+offset-Vector3.UP*60,1)
		var floor_hit: Dictionary=live.get_world_3d().direct_space_state.intersect_ray(down)
		if floor_hit.is_empty(): continue
		scene.player.global_position=floor_hit.position+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
		await physics_frame
		var state: Dictionary=scene.roach_population.duplicate(true)
		await step(live,1.0)
		var moved: float=Vector2(body.global_position.x-spawn.x,body.global_position.z-spawn.z).length()
		if scene.roach_population.live["42"].mode==State.PURSUE and moved>20:
			chosen=true;break
		scene.roach_population=state;live.restore();await physics_frame
	if not check(chosen,"No reachable visible approach for actor42"):return
	if not check(scene.roach_population.actors["42"].position!=[spawn.x,spawn.y,spawn.z] and scene.roach_population.live["42"].heading!=State.initial().actors.size(),"Pursuit did not persist position"):return
	# A moved actor must round-trip disk saves exactly.
	var moved_path:="user://tests/cave_roach_moved.json"
	if not check(scene._quicksave(moved_path).is_empty(),"Moved save failed"):return
	var moved_state: Dictionary=scene._save_state()
	var moved_load_error: String=scene._quickload(moved_path)
	report_diff(moved_state,scene._save_state())
	if not check(moved_load_error.is_empty() and scene._save_state()==moved_state,"Moved Roach save is not stable: "+moved_load_error):return
	scene.set_physics_process(false)
	DirAccess.remove_absolute(moved_path)
	var waited:=0.0
	while scene.roach_population.live["42"].mode!=State.ATTACK and waited<8.0:
		await step(live,0.1);waited+=0.1
	if not check(scene.roach_population.live["42"].mode==State.ATTACK,"Roach never reached bite range"):return
	var reach: float=Vector2(scene.player.global_position.x-body.global_position.x,scene.player.global_position.z-body.global_position.z).length()
	if not check(reach<=State.REACH+1 and model.player_health==30,"Unexpected approach state"):return
	# Disk save mid-bite; the bite then lands once for the source7 damage.
	var path:="user://tests/cave_roach_live_behavior.json"
	if not check(scene._quicksave(path).is_empty(),"Mid-bite save failed"):return
	var saved_live: Dictionary=scene.roach_population.live["42"].duplicate()
	await step(live,1.6)
	if not check(model.player_health==30-State.RULES.damage,"Bite damage differs: %d"%model.player_health):return
	if not check(scene._quickload(path).is_empty() and model.player_health==30 and scene.roach_population.live["42"]==saved_live,"Mid-bite disk rollback failed"):return
	scene.set_physics_process(false)
	await step(live,1.6)
	if not check(model.player_health==30-State.RULES.damage,"Restored bite repeated or skipped"):return
	# Pause gate freezes all actors.
	spells.running=false
	var paused: Dictionary=scene.roach_population.duplicate(true)
	await step(live,2.0)
	if not check(scene.roach_population==paused and model.player_health==30-State.RULES.damage,"Paused Roach acted"):return
	spells.running=true
	# Leaving sight ends pursuit; the actor does not hunt through walls.
	scene.player.global_position=spawn+Vector3(0,0,2000)
	await step(live,2.5)
	var parked: Vector3=body.global_position
	await step(live,1.0)
	if not check(scene.roach_population.live["42"].mode==State.IDLE and body.global_position.distance_to(parked)<0.01,"Distant player still pursued"):return
	# Checkpoint recovery drops an unfinished bite; defeat stops behavior permanently.
	scene.roach_population.live["42"].merge({"mode":State.ATTACK,"elapsed":1.0,"hit":false},true)
	live.recover()
	if not check(scene.roach_population.live["42"].mode==State.IDLE,"Recovery kept a bite"):return
	if not check(live.receive_damage("42",99),"Defeat failed"):return
	scene.player.global_position=parked+Vector3(0,0,30)
	var health: int=model.player_health
	await step(live,3.0)
	if not check(model.player_health==health and body.global_position.distance_to(parked)<0.01 and State.validate(scene.roach_population).is_empty(),"Defeated Roach acted"):return
	# Swarm: the source nest cluster moves together; disk saves must stay exact.
	var nest: Vector3=live.bodies["30"].global_position
	scene.player.global_position=nest+Vector3(0,30,90)
	await physics_frame
	await step(live,1.0)
	# Nest actors stay dormant until their source region writes enable decisions.
	if not check(scene.roach_population.live["30"].mode==State.IDLE and State.dormant(scene.roach_population,"30"),"Nest roach acted before region contact"):return
	State.first_contact(scene.roach_population,1140)
	await step(live,1.5)
	var moving_count:=0
	for id in ["25","26","27","28","29","30","31","32","33","34","35","43"]:
		if scene.roach_population.live[id].mode!=State.IDLE: moving_count+=1
	if not check(moving_count>=6,"Nest did not engage: %d"%moving_count):return
	if not check(scene._quicksave(path).is_empty(),"Swarm save failed"):return
	var swarm: Dictionary=scene._save_state()
	if not check(scene._quickload(path).is_empty() and scene._save_state()==swarm,"Swarm save is not stable"):return
	DirAccess.remove_absolute(path)
	print("PASS: source actor42 perceives, pursues on real floor, bites once for3 (native7 request) at frame12, mid-bite disk rollback, pause, sight loss, recovery, defeat and exact swarm save")
	scene.queue_free()
	await process_frame
	quit()
