extends SceneTree
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const Save=preload("res://scripts/lol2/jungle_save.gd")
class TestMagic extends "res://scripts/lol2/player_starting_magic.gd":
	func world_active() -> bool: return true
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> bool:
	if not ok: push_error(message);quit(1)
	return ok
func step(pop, seconds: float) -> void:
	for i in range(roundi(seconds*60)):
		pop.advance(1.0/60.0)
		await physics_frame
func run() -> void:
	set_meta("lol2_jungle_handoff",{"collected":[Save.Museum.SWORD],"equipped_item":Save.Museum.SWORD,"equipped_armor":""})
	var scene=load("res://scenes/lol2/jungle_walkthrough.tscn").instantiate()
	root.add_child(scene);current_scene=scene
	for i in range(5): await process_frame
	scene.set_physics_process(false)
	var pop=scene.villager_population
	if not check(pop!=null and pop.bodies.size()==18 and pop.targets().size()==18,"Villagers missing"):return
	pop.set_physics_process(false)
	if scene.dino_population!=null: scene.dino_population.set_physics_process(false)
	scene.starting_magic.set_process(false);scene.item_effects.set_process(false)
	var spells:=TestMagic.new();scene.add_child(spells);spells.set_process(false);scene.starting_magic=spells
	# Friendly: standing next to a villager for seconds changes nothing; quests untouched.
	var before: Dictionary=scene.quest_state.duplicate(true)
	var body: CharacterBody3D=pop.bodies["56"]
	scene.player.global_position=body.global_position+Vector3(0,32,40)
	await physics_frame
	await step(pop,3.0)
	if not check(scene.health==30 and scene.quest_state==before and not scene.quest_state.has("jungle_villagers"),"Idle villager acted or mutated quests"):return
	# Provoked: a melee hit wakes it; it fights back.
	scene.camera.look_at(body.global_position+Vector3(0,24,0))
	await physics_frame
	pop.strike_remaining=0.0
	if not check(pop.aimed()=="56" and pop.strike() and pop.state.actors["56"].woken and scene.quest_state.has("jungle_villagers"),"Provocation failed"):return
	var waited:=0.0
	while scene.health==30 and waited<12.0:
		await step(pop,0.25);waited+=0.25
	if not check(scene.health<30,"Provoked villager did not fight back"):return
	scene.health=30
	var path:="user://tests/jungle_villagers.json"
	if not check(scene.quicksave(path).is_empty(),"Save failed"):return
	var saved: Dictionary=pop.checkpoint()
	await step(pop,1.0)
	if not check(scene.quickload(path).is_empty() and pop.checkpoint()==saved and scene.quest_state.jungle_villagers==pop.state,"Villager disk rollback failed"):return
	var handoff: Dictionary=scene.area_handoff()
	if not check(Save.Quests.validate(handoff.quests).is_empty() and handoff.quests.jungle_villagers.actors["56"].woken,"Quest transport lost villagers"):return
	DirAccess.remove_absolute(path)
	print("PASS: 18 source Huline villagers idle and harmless until provoked; provoked villager fights; quests untouched until change; disk rollback; quest transport")
	scene.queue_free()
	await process_frame
	quit()
