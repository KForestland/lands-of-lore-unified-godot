extends SceneTree
const State=preload("res://scripts/lol2/jungle_dino_population_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const Save=preload("res://scripts/lol2/jungle_save.gd")
# Headless display cannot capture the mouse; only the world gate is replaced.
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var running:=true
	func world_active() -> bool: return running
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func step(dinos, seconds: float) -> void:
	for i in range(roundi(seconds*60)):
		dinos.advance(1.0/60.0)
		await physics_frame
func run() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	var scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	var dinos=scene.dino_population
	if not check(dinos!=null and dinos.bodies.size()==15 and dinos.targets().size()==15,"DINO population missing"):return
	dinos.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var spells:=TestMagic.new();scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	for row in State.source().actors:
		var p: Array=row.position
		if not check(dinos.bodies[str(int(row.actor))].position==Vector3(p[0],p[1],p[2]),"Source spawn differs"):return
	if not check(not scene.quest_state.has("jungle_dino_population"),"Restore mutated fresh quests"):return
	dinos.state()
	var body: CharacterBody3D=dinos.bodies["24"]
	var spawn: Vector3=body.global_position
	# Find a visible, reachable standing spot ~180 units away.
	var chosen:=false
	for angle in range(0,360,30):
		var offset:=Vector3(sin(deg_to_rad(angle)),0,cos(deg_to_rad(angle)))*180
		var down:=PhysicsRayQueryParameters3D.create(spawn+offset+Vector3.UP*120,spawn+offset-Vector3.UP*120,1)
		var floor_hit: Dictionary=dinos.get_world_3d().direct_space_state.intersect_ray(down)
		if floor_hit.is_empty(): continue
		scene.player.global_position=floor_hit.position+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
		await physics_frame
		var saved: Dictionary=scene.quest_state.jungle_dino_population.duplicate(true)
		await step(dinos,1.0)
		if scene.quest_state.jungle_dino_population.live["24"].mode==Live.PURSUE and Vector2(body.global_position.x-spawn.x,body.global_position.z-spawn.z).length()>20:
			chosen=true;break
		scene.quest_state.jungle_dino_population=saved;dinos.restore();await physics_frame
	if not check(chosen,"No reachable visible approach for DINO24"):return
	var waited:=0.0
	while scene.quest_state.jungle_dino_population.live["24"].mode!=Live.ATTACK and waited<10.0:
		await step(dinos,0.1);waited+=0.1
	if not check(scene.quest_state.jungle_dino_population.live["24"].mode==Live.ATTACK and scene.health==30,"DINO never reached bite range"):return
	var path:="user://tests/jungle_dino_live.json"
	if not check(scene.quicksave(path).is_empty(),"Mid-bite Jungle save failed"):return
	var saved_state: Dictionary=scene.quest_state.jungle_dino_population.duplicate(true)
	# Herd mates may join; count bites by actual health change in whole24 units.
	await step(dinos,1.3)
	if not check(scene.health<30 and (scene.health==0 or (30-scene.health)%10==0),"Bite damage differs: %d"%scene.health):return
	if not check(scene.quickload(path).is_empty() and scene.health==30 and scene.quest_state.jungle_dino_population==saved_state,"Mid-bite disk rollback failed"):return
	scene.set_physics_process(false)
	# Melee: aim at the actor with the equipped sword through the production strike.
	scene.player.global_position=body.global_position+(scene.player.global_position-body.global_position).normalized()*50+Vector3.UP*20
	scene.camera.look_at(body.global_position+Vector3(0,24,0))
	await physics_frame
	var before_xp=scene.quest_state.get("player_reward_state",{})
	var hp: int=scene.quest_state.jungle_dino_population.actors["24"].health
	if not check(dinos.aimed()=="24" and dinos.strike() and scene.quest_state.jungle_dino_population.actors["24"].health<hp,"Melee strike failed"):return
	if not check(scene.quest_state.has("player_reward_state") and scene.quest_state.player_reward_state!=before_xp,"Melee XP not awarded"):return
	if not check(not dinos.strike(),"Cooldown ignored"):return
	# Cooldown survives disk rollback and remains frozen behind the world gate.
	if not check(scene.quicksave(path).is_empty(),"Strike cooldown save failed"):return
	var saved_strike: float=dinos.strike_remaining
	await step(dinos,0.5)
	if not check(dinos.strike_remaining==0.0,"Strike cooldown never expired"):return
	if not check(scene.quickload(path).is_empty() and dinos.strike_remaining==saved_strike and not dinos.strike(),"Strike cooldown rollback failed"):return
	scene.set_physics_process(false)
	spells.running=false
	dinos.advance(1.0)
	if not check(dinos.strike_remaining==saved_strike,"Paused strike cooldown advanced"):return
	spells.running=true
	await physics_frame # Restored bodies must reach the physics query server.
	# Loading normalizes the camera; aim again before the independent spell check.
	scene.camera.look_at(body.global_position+Vector3(0,24,0))
	# Spark through the shared starting-magic collider dispatch.
	spells.select_spell("spark")
	hp=scene.quest_state.jungle_dino_population.actors["24"].health
	if not check(spells.cast() and scene.quest_state.jungle_dino_population.actors["24"].health==hp-8,"Spark did not hit DINO"):return
	# Kill, corpse and no further behavior.
	if not check(dinos.receive_damage("24",999),"Defeat failed"):return
	# Leave the herd so its other members stop biting during the corpse clip.
	scene.player.global_position=Vector3(353,72,-4909)
	scene.health=30
	await step(dinos,2.0)
	if not check(scene.quest_state.jungle_dino_population.actors["24"].death==State.DEATH_SECONDS and body.collision_layer==0 and not dinos.targets().has("jungledino24"),"Defeat clip/corpse differs"):return
	# Area transport: quests carry the population to the Hive and back.
	var transfer: Dictionary=scene.area_handoff()
	if not check(Save.Quests.validate(transfer.quests).is_empty() and transfer.quests.jungle_dino_population.actors["24"].health==0,"Quest transport lost DINO state"):return
	var expected_dino: Dictionary=State.canonical(transfer.quests.jungle_dino_population)
	var handoff_error: String=scene.apply_area_handoff(JSON.parse_string(JSON.stringify(transfer)))
	if not check(handoff_error.is_empty() and scene.quest_state.jungle_dino_population==State.canonical(transfer.quests.jungle_dino_population),"JSON area handoff differs"):return
	# Player death retry.
	scene.health=0
	var event:=InputEventKey.new();event.keycode=KEY_R;event.pressed=true
	dinos._unhandled_input(event)
	if not check(scene.health==30,"Retry did not recover"):return
	DirAccess.remove_absolute(path)
	print("PASS: 15 source DINOs; actor24 perceives, pursues on real floor, bites for10 (native24 request), mid-bite disk rollback, melee XP/cooldown, Spark, defeat corpse, quest transport and retry")
	scene.queue_free()
	await process_frame
	quit()
