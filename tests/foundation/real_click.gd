extends SceneTree
## Local full-scene combat regression, not a campaign/earned-route claim.
## Declared setup: inventory, one initial standing pose from a floor ray and
## health top-ups. There are no target/pose/AI edits after combat begins.
const SWORD="museum:item11:Fine_Longsword"
var scene
var pop
var id := ""
var topups := 0
var clicks := 0
var observed_blow := 0
func scenario()->String:return "cave"
func _initialize():run.call_deferred()
func frames(n:int):
	for i in n:await physics_frame
func click():
	await process_frame
	for down in [true,false]:
		var e=InputEventMouseButton.new();e.button_index=MOUSE_BUTTON_LEFT;e.pressed=down;e.position=Vector2(640,360)
		Input.parse_input_event(e);Input.flush_buffered_events();await process_frame
	clicks+=1
func tap(key:Key):
	await process_frame
	for down in [true,false]:
		var e=InputEventKey.new();e.keycode=key;e.physical_keycode=key;e.pressed=down
		Input.parse_input_event(e);Input.flush_buffered_events();await process_frame
func hp()->int:
	match scenario():
		"cave":return scene.roach.model.enemy_health
		"hive":return pop.enemies[0]
		"jungle":return int(pop.view().actors[id].health)
		_:return int(pop.state.actors[id].health)
func target()->Vector3:
	match scenario():
		"cave":return scene.roach.body.global_position+Vector3(0,6,0)
		"hive":return pop.bodies[0].global_position+Vector3(0,40,0)
		"prop":return scene.static_assemblies.solid_bodies[109].global_position
		_:return pop.bodies[id].global_position+Vector3(0,12,0)
func aim(point:Vector3):
	var offset:Vector3=point-scene.camera.global_position
	var yaw=atan2(-offset.x,-offset.z)
	var pitch=atan2(offset.y,Vector2(offset.x,offset.z).length())
	var event=InputEventMouseMotion.new()
	event.relative=Vector2(-wrapf(yaw-scene.player.rotation.y,-PI,PI)/(0.002 if scenario()=="cave" else 0.003),-(pitch-scene.camera.rotation.x)/(0.002 if scenario()=="cave" else 0.003))
	Input.parse_input_event(event);Input.flush_buffered_events()
func place_before_fight(point:Vector3):
	# Select one clear standing start; this is the only pose setup in the test.
	var chosen=Vector3.ZERO
	for angle in range(0,360,30):
		var offset=Vector3(sin(deg_to_rad(angle)),0,cos(deg_to_rad(angle)))*42
		var start=point+offset+Vector3.UP*45
		var down=PhysicsRayQueryParameters3D.create(start,start-Vector3.UP*220,1|256,[scene.player.get_rid()])
		var floor_hit=scene.get_world_3d().direct_space_state.intersect_ray(down)
		if floor_hit.is_empty():continue
		var camera_at:Vector3=floor_hit.position+Vector3.UP*32+scene.camera.position
		var sight=PhysicsRayQueryParameters3D.create(camera_at,point,1|256,[scene.player.get_rid()])
		var hit=scene.get_world_3d().direct_space_state.intersect_ray(sight)
		if not hit.is_empty() and hit.position.distance_to(point)>20:continue
		chosen=floor_hit.position+Vector3.UP*32;break
	assert(chosen!=Vector3.ZERO,"clear local standing start")
	scene.player.global_position=chosen;scene.player.velocity=Vector3.ZERO
	await frames(2);aim(point);await frames(2)
func sustain():
	var health:int=scene.starting_magic.health()
	if health<30:observed_blow=maxi(observed_blow,30-health)
	if health<=18:
		scene.starting_magic.set_health(30);topups+=1
func run():
	var paths={"cave":"cave_walkthrough","hive":"hive_review","jungle":"jungle_walkthrough","prop":"jungle_walkthrough","act2":"darker_jungle"}
	scene=load("res://scenes/lol2/"+paths[scenario()]+".tscn").instantiate()
	if scenario()=="act2":
		var saved=preload("res://scripts/lol2/jungle_save.gd").read_save("res://tmp/l8_shaman_serum_earned_save.json","lol2-restoration-darker-jungle")
		assert(saved.error.is_empty());set_meta("lol2_darker_resume",saved.state)
	root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		if scene.get("starting_magic")!=null and (scene.get("walkthrough_ready") if scenario()=="cave" else scene.ready_for_review):break
	await frames(2)
	root.grab_focus();Input.mouse_mode=Input.MOUSE_MODE_CAPTURED
	if is_instance_valid(scene.interface_hud):scene.interface_hud.set_cursor(false)
	if scenario()=="hive":scene.carried_inventory.collected=[SWORD];scene.carried_inventory.equipped_item=SWORD
	elif scenario()!="cave":scene.carried_collected=[SWORD];scene.equipped_item=SWORD
	else:scene.equipped_item=SWORD # combat-only setup; no claim sword is earned in Cave
	scene.starting_magic.set_health(30)
	match scenario():
		"cave":pop=scene.roach
		"hive":pop=scene.get_node("Warriors")
		"jungle":pop=scene.dino_population;id="24"
		"act2":pop=scene.act2_creatures;id="29"
		"prop":pop=scene.bramble
	await place_before_fight(target())
	print("START ",scenario()," at ",scene.player.position," target ",target())
	if scenario()=="prop":
		scene.equipped_item="";await click();assert(pop.owner_state(109)==0,"empty hand refuses")
		scene.equipped_item=SWORD
		for n in 3:
			aim(target());await click();await frames(2);assert(pop.owner_state(109)==n+1,"real cut state")
		assert(not pop.solid(109))
	else:
		var expected_damage=32 if scenario()=="act2" else 8
		var initial=hp()
		aim(target());await click();var after=hp()
		assert(after==maxi(0,initial-expected_damage),"first real click damage %d -> %d" % [initial,after])
		await click();assert(hp()==after,"second click inside cooldown")
		if scenario()=="jungle":
			await tap(KEY_F5)
			var saved_clock:float=pop.strike_remaining
			# F5 persists the precise clock at the save event, not this later read.
			var disk=preload("res://scripts/lol2/game_save.gd").read_document(preload("res://scripts/lol2/game_save.gd").slot_path(1)).state.area_save
			var disk_clock:float=disk.quests.jungle_dino_population.strike_remaining
			await frames(35);await tap(KEY_F9)
			for i in 1500:
				await process_frame
				if is_instance_valid(current_scene) and current_scene.get("ready_for_review")==true and current_scene.get("starting_magic")!=null:break
			scene=current_scene;pop=scene.dino_population
			assert(pop.strike_remaining>0 and pop.strike_remaining<=disk_clock and disk_clock>saved_clock,"F5/F9 saved cooldown")
			assert(hp()==after,"F9 creature health")
		# Witness a real incoming blow before finishing; top-ups are counted aids.
		for tick in 360:
			aim(target());await frames(1);sustain()
			if observed_blow>0:break
		assert(observed_blow>0,"real incoming blow")
		if scenario()=="act2":
			# Multiple physics ticks can arrive between rendered frames; aggregate
			# health loss is not one blow. Pin the actual receiver-side scale instead.
			assert(is_equal_approx(pop.damage_to_player_scale(id),0.25),"actual incoming quarter-scale hook")
		else:assert(observed_blow%(10 if scenario()=="jungle" else 6)==0,"unchanged incoming loss")
		for strike in 80:
			if hp()<=0:break
			for tick in 31:aim(target());await frames(1);sustain()
			var before=hp();await click()
			assert(hp()==maxi(0,before-expected_damage),"subsequent real click damage")
		assert(hp()==0,"target defeated by clicks")
		if scenario()=="act2":assert(initial==200 and clicks==8,"seven landed clicks plus one refused cooldown click")
	assert(scene.get("resets")==null or scene.resets==0,"no fall resets")
	var out=OS.get_environment("LOL2_FOUNDATION_PROOFS")
	if not out.is_empty():
		DirAccess.make_dir_recursive_absolute(out)
		root.get_texture().get_image().save_png(out+"/"+scenario()+".png")
	print("PASS combat_",scenario()," real clicks=",clicks," incoming=",observed_blow," topups=",topups," resets=0")
	scene.free();current_scene=null;await process_frame;quit()
