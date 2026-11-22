extends SceneTree
## Five real scene/save families. Fixture generation uses the unchanged game's
## save writers; generation is opt-in and never rewrites the checked-in witnesses.
const SWORD="museum:item11:Fine_Longsword"
const AREAS={"cave":"res://scenes/lol2/cave_walkthrough.tscn","museum":"res://scenes/lol2/museum_walkthrough.tscn","hive":"res://scenes/lol2/hive_review.tscn","jungle":"res://scenes/lol2/jungle_walkthrough.tscn","act2":"res://scenes/lol2/maps/L10_DC.tscn"}
const FIXTURES="res://tests/fixtures/saves_d5da60a/"
func scenario()->String: return "health"
func _initialize(): run.call_deferred()
func scene_for(area: String):
	var scene=load(AREAS[area]).instantiate();root.add_child(scene);current_scene=scene
	for i in 1500:
		await process_frame
		var ready=scene.get("walkthrough_ready") if area=="cave" else scene.get("ready_for_review")
		if (ready==null or ready) and scene.get("starting_magic")!=null: break
	# Quiescent contract/fixture test, explicitly not real-input acceptance.
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	scene.set_physics_process(false)
	if area=="museum": scene.introduction_state="complete"
	return scene
func live(scene):
	if scene.get("roach")!=null:return scene.roach.model
	if scene.has_node("Warriors"):return scene.get_node("Warriors")
	return scene
func key_for(scene)->String: return "player_health" if scene.get("roach")!=null else "health"
func equipment(scene)->String: return str(scene.equipped_item)
func clock(scene)->float:
	if scene.get("roach")!=null:return scene.roach.model.strike_remaining
	if scene.get("dino_population")!=null:return scene.dino_population.strike_remaining
	if scene.has_node("Warriors"):return scene.get_node("Warriors").cooldown
	return -1
func run():
	var manifest={}
	var generate=OS.get_environment("LOL2_WRITE_D5_FIXTURES")=="1"
	if scenario()=="fixtures" and not generate:
		manifest=JSON.parse_string(FileAccess.get_file_as_string(FIXTURES+"manifest.json"))
	for area in AREAS:
		var scene=await scene_for(area)
		var store=live(scene);var key=key_for(scene)
		var owner=scene.player_health_owner
		assert(scene.get_node("PlayerHealth")==owner and scene.find_children("PlayerHealth","Node",false,false).size()==1,"one attached owner")
		if scenario()=="health":
			# Raw writes (including edge integers) are current behaviour, not a clamped adapter.
			for amount in [24,0,46,-3,30]:
				scene.starting_magic.set_health(amount)
				assert(int(store.get(key))==amount and scene.starting_magic.health()==amount,area+" facade write")
				store.set(key,amount+1)
				assert(scene.starting_magic.health()==amount+1 and owner.value()==amount+1,area+" legacy set() write")
				owner.current=amount
				assert(int(store.get(key))==amount and scene.starting_magic.health()==amount,area+" canonical write reaches aliases")
		else:
			var path=FIXTURES+area+".json"
			if generate:
				scene.starting_magic.set_health(19)
				if area=="hive":scene.carried_inventory.collected=[SWORD];scene.carried_inventory.equipped_item=SWORD
				elif area not in ["cave","museum"]:
					if scene.get("carried_collected")!=null:scene.carried_collected=[SWORD]
					scene.equipped_item=SWORD
				if area=="cave":scene.roach.model.strike_remaining=0.375
				if area=="jungle":scene.dino_population.strike_remaining=0.375
				if area=="hive":scene.get_node("Warriors").cooldown=0.375
				var error=scene.quicksave(path)
				assert(error.is_empty(),area+": "+error)
				manifest[area]={"health":scene.starting_magic.health(),"form":scene.player_form,"equipped_item":equipment(scene),"cooldown":clock(scene),"sha256":FileAccess.get_sha256(path)}
			else:
				assert(FileAccess.get_sha256(path)==manifest[area].sha256,"immutable d5 fixture")
				var packet:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
				if area=="cave":
					assert(not packet.has("health") and int(packet.roach.player_health)==19,"Cave SAVE owns health inside roach")
				if area=="hive":assert(is_equal_approx(float(packet.quests.hive_encounter.cooldown),0.375),"third saved player cooldown: Hive")
				scene.starting_magic.set_health(7)
				var error=scene.quickload(path)
				assert(error.is_empty(),area+": "+error)
				var expect: Dictionary=manifest[area]
				assert(scene.starting_magic.health()==int(expect.health),area+" health")
				assert(scene.player_form==int(expect.form) and equipment(scene)==expect.equipped_item,area+" form/equipment")
				assert(is_equal_approx(clock(scene),float(expect.cooldown)),area+" saved cooldown")
				if area=="cave":
					assert(int(scene._completion_state().health)==19,"separate Cave-to-Museum TRANSFER health")
					# Optional roach was absent in legacy saves. Replacement models must bind
					# and reset the same live owner, not silently create a second store.
					var legacy:Dictionary=packet.duplicate(true);legacy.erase("roach")
					var legacy_path="user://tests/foundation_cave_no_roach.json"
					assert(scene.WalkthroughSave.write_save(legacy_path,legacy,scene._checkpoint_count()).is_empty())
					assert(scene.quickload(legacy_path).is_empty())
					assert(scene.roach.model.player_health==30 and owner.value()==30 and scene.starting_magic.health()==30,"legacy model replacement bound to owner")
					DirAccess.remove_absolute(legacy_path)
		scene.free();current_scene=null;await process_frame
	if generate:
		var out=FileAccess.open(FIXTURES+"manifest.json",FileAccess.WRITE);out.store_string(JSON.stringify(manifest,"  "));out.close()
	print("PASS ",scenario(),": five actual scene stores and d5 save families")
	quit()
