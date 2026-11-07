extends SceneTree
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	var running:=true
	func world_active() -> bool: return running
func _initialize() -> void: run.call_deferred()
func run() -> void:
	set_meta("lol2_cave_completion",{"collected":["cave:prop641:harvest1:Stalagmite"],"equipped_item":"cave:prop641:harvest1:Stalagmite","health":30})
	var museum=load("res://scenes/lol2/museum_walkthrough.tscn").instantiate()
	museum.introduction_state="complete";root.add_child(museum);current_scene=museum
	for i in range(5): await process_frame
	museum.set_physics_process(false);museum.starting_magic.set_process(false)
	var pop=museum.skeleton_population;pop.set_physics_process(false)
	var spells:=TestMagic.new();museum.add_child(spells);spells.set_process(false);museum.starting_magic=spells
	assert(pop.receive_damage("24",1)) # Actual reward/damage/neighbour-wake path.
	pop.advance(0.25)
	assert(pop.state.audio["24"].request==989 and pop.state.audio["25"].request==989 and pop.state.audio["26"].request==989)
	var path:="user://tests/museum_creature_audio_validation.json"
	assert(museum.quicksave(path).is_empty())
	var saved: Dictionary=pop.checkpoint()
	var disk: Dictionary=museum.Save.read_save(path).state
	pop.advance(0.25)
	assert(pop.checkpoint()!=saved)
	assert(museum.quickload(path).is_empty() and pop.checkpoint()==saved)
	museum.set_physics_process(false)
	var before: Dictionary=museum.checkpoint_state()
	var position: Vector3=museum.player.position
	for change in [["request",65535],["sample",999999],["sample",0.5],["selector",999],["time",-1]]:
		var bad:=disk.duplicate(true)
		bad.checkpoint.skeletons.audio["24"][change[0]]=change[1]
		bad.player.position[0]+=100
		var file:=FileAccess.open(path,FileAccess.WRITE);file.store_string(JSON.stringify(bad));file.close()
		assert(not museum.quickload(path).is_empty())
		assert(museum.checkpoint_state()==before and museum.player.position==position)
	# Old checkpoints suppress past rise cues and preserve their missing audio field.
	var old:=disk.duplicate(true);old.checkpoint.skeletons.erase("audio")
	assert(museum.Save.write_save(path,old).is_empty() and museum.quickload(path).is_empty())
	assert(not pop.state.has("audio"))
	pop.creature_audio.sync(0.0)
	assert(pop.state.audio["24"].request==0)
	DirAccess.remove_absolute(path)
	remove_meta("lol2_cave_completion")
	museum.queue_free();await process_frame;await create_timer(0.1).timeout
	print("PASS: production hit/neighbour rise audio, partial Museum disk rollback, five malformed files rejected atomically and legacy cue suppression")
	quit()
