extends SceneTree
const State=preload("res://scripts/lol2/jungle_dino_population_state.gd")
const Audio=preload("res://scripts/lol2/jungle_dino_audio_state.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false);scene.dino_population.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var population:=State.initial();population.audio=Audio.initial()
	Audio.sample(population.audio["21"],4,1.125,0.0)
	scene.quest_state.jungle_dino_population=population
	var path:="user://tests/jungle_dino_audio_validation.json"
	assert(scene.quicksave(path).is_empty())
	var disk: Dictionary=scene.Save.read_save(path).state
	var before: Dictionary=scene.quest_state.duplicate(true)
	var inventory: Dictionary=scene.inventory_state().duplicate(true)
	var position: Vector3=scene.player.position
	# Invalid audio must be rejected before inventory, quests, player or voices mutate.
	for change in [["request",977],["request",978.5],["elapsed",17023],["elapsed",0.5],["time",-1],["pose",11]]:
		var bad:=disk.duplicate(true)
		bad.quests.jungle_dino_population.audio["21"][change[0]]=change[1]
		bad.player.position[0]+=100
		var file:=FileAccess.open(path,FileAccess.WRITE)
		file.store_string(JSON.stringify(bad));file.close()
		assert(not scene.quickload(path).is_empty())
		assert(scene.quest_state==before and scene.inventory_state()==inventory and scene.player.position==position)
		assert(not scene.dino_population.audio.players["21"].playing)
	# The malformed file never replaced the live packet; a valid file still restores.
	assert(scene.Save.write_save(path,disk).is_empty())
	assert(scene.quickload(path).is_empty())
	assert(scene.quest_state.jungle_dino_population==population)
	DirAccess.remove_absolute(path)
	scene.queue_free();await process_frame;await create_timer(0.1).timeout
	print("PASS: six malformed disk audio packets rejected atomically; valid partial clip restores")
	quit()
