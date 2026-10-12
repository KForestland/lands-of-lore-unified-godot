extends SceneTree
class Host extends Node3D:
	var quest_state: Dictionary={}
	var starting_magic: Node=null
func _initialize() -> void:
	var host:=Host.new()
	var population:=preload("res://scripts/lol2/jungle_dino_population.gd").new()
	population.host=host
	population.source={"reward_scale":4}
	var before:=host.quest_state.duplicate(true)
	for request in [["21",0],["21",-1],["999",8]]:
		if population.receive_damage(request[0],request[1]) or host.quest_state!=before:
			push_error("Rejected DINO damage changed legacy quest state")
			host.free();population.free();quit(1);return
	# Missing magic owner must reject before initializing the population packet.
	if population.receive_damage("21",8,false) or host.quest_state!=before:
		push_error("Rejected DINO spell changed legacy quest state")
		host.free();population.free();quit(1);return
	host.quest_state={"cave_melee_seed":-1}
	before=host.quest_state.duplicate(true)
	if population.receive_damage("21",8) or host.quest_state!=before:
		push_error("Rejected DINO melee reward changed legacy quest state")
		host.free();population.free();quit(1);return
	var state:=preload("res://scripts/lol2/jungle_dino_population_state.gd").initial()
	state.actors["21"].health=0
	host.quest_state={"jungle_dino_population":state}
	before=host.quest_state.duplicate(true)
	if population.receive_damage("21",8) or host.quest_state!=before:
		push_error("DINO corpse hit changed saved state")
		host.free();population.free();quit(1);return
	print("PASS: invalid DINO targets/damage and unavailable spell rewards leave legacy quests unchanged")
	host.free();population.free();quit()
