extends SceneTree
const Population=preload("res://scripts/lol2/cave_wild_roach.gd")
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	func world_active() -> bool: return true
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func run() -> void:
	var scene=load("res://scenes/lol2/cave_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for frame in range(600):
		await process_frame
		if scene.walkthrough_ready: break
	if not check(scene.walkthrough_ready,"Cave load"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	var pop=scene.wild_roach_population
	if not check(pop!=null,"Actor0 scene integration"):return
	pop.set_physics_process(false)
	if not check(pop.bodies.keys()==["0"] and pop.bodies["0"].visible and pop.targets().has("cavewildroach0"),"Actor0 identity/presence"):return
	if not check(pop.bodies["0"].position==Vector3(177,-250,-10282)+scene.native_translation,"Source placement"):return
	scene.starting_magic.set_process(false)
	var spells:=TestMagic.new();scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	scene.stalagmites.collected=["cave:prop641:harvest1:Stalagmite"]
	scene.equipped_item="cave:prop641:harvest1:Stalagmite"
	scene.player.global_position=pop.bodies["0"].global_position+Vector3(0,32,35)
	scene.camera.look_at(pop.bodies["0"].global_position+Vector3(0,6,0))
	scene.flying=false
	await physics_frame
	if not check(pop.aimed()=="0" and pop.strike() and pop.state.actors["0"].health==92,"Production aimed melee"):return
	spells.select_spell("spark")
	var mana_before: int=spells.magic_state().player.mana
	if not check(spells.cast(1) and pop.state.actors["0"].health==84 and spells.magic_state().player.mana<mana_before,"Production aimed Spark and mana"):return
	pop.creature_audio.sync(0.0)
	var saved: Dictionary=pop.checkpoint()
	var path:="user://tests/cave_wild_roach.json"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://tests"))
	if not check(scene._quicksave(path).is_empty(),"Actor0 scene disk save"):return
	if not check(pop.receive_damage("0",999) and pop.state.actors["0"].health==0,"Production defeat"):return
	pop.State.advance_clocks(pop.state,pop.src,3.0);pop.present();pop.creature_audio.sync(0.0)
	if not check(pop.creature_audio.pose("0").selector==10,"Original corpse selector"):return
	var loaded: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
	if not check(scene._quickload(path).is_empty() and pop.checkpoint()==saved,"Scene disk rollback"):return
	scene.set_physics_process(false);scene.curse.set_physics_process(false)
	var invalid: Dictionary=saved.duplicate(true);invalid.actors["0"].health=101
	if not check(not pop.restore(invalid).is_empty() and pop.checkpoint()==saved,"Atomic invalid restore"):return
	var invalid_world:=loaded.duplicate(true);invalid_world.wild_roach=invalid
	var bad_path:="user://tests/cave_wild_roach_invalid.json"
	var file:=FileAccess.open(bad_path,FileAccess.WRITE);file.store_string(JSON.stringify(invalid_world));file.close()
	if not check(not scene._quickload(bad_path).is_empty() and pop.checkpoint()==saved,"Scene rejects malformed actor before mutation"):return
	var aura_state=preload("res://scripts/lol2/player_spark_aura_state.gd")
	if not check(aura_state.valid_target("cavewildroach0") and not aura_state.valid_target("cavewildroach1"),"Aura target admission"):return
	if not check(scene.starting_magic.aura.targets().has("cavewildroach0"),"Aura live target map"):return
	var legacy:=loaded.duplicate(true);legacy.erase("wild_roach")
	var old_path:="user://tests/cave_wild_roach_legacy.json"
	file=FileAccess.open(old_path,FileAccess.WRITE);file.store_string(JSON.stringify(legacy));file.close()
	if not check(scene._quickload(old_path).is_empty() and pop.state.actors["0"].health==100,"Legacy saves initialize actor0"):return
	if not check(scene.quest_state.has("player_reward_state"),"Shared reward owner"):return
	print("PASS actor0 controller original sprites/audio, target identity, source placement, production hit/defeat/reward, corpse, disk rollback and invalid restore")
	scene.queue_free();await process_frame;await process_frame;quit()
