extends SceneTree
const Quests = preload("res://scripts/lol2/act_one_quest_state.gd")
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var hive = load("res://scenes/lol2/hive_review.tscn").instantiate()
	root.add_child(hive)
	hive.set_physics_process(false)
	hive.get_node("Warriors").set_physics_process(false)
	var state := {"inventory":{"collected":[],"equipped_item":"","equipped_armor":"","health":24},"quests":Quests.initial()}
	assert(hive.apply_area_handoff(state).is_empty())
	assert(hive.get_node("Warriors").health == 24)
	hive.get_node("Warriors").health = 18
	var outgoing: Dictionary = hive.area_handoff()
	assert(outgoing.inventory.health == 18 and outgoing.quests.hive_encounter.health == 18)
	# A later visit's player health wins over stored local encounter health.
	outgoing.inventory.health = 12
	assert(hive.apply_area_handoff(outgoing).is_empty())
	assert(hive.get_node("Warriors").health == 12)
	var path := "user://tests/area_health_%d.json" % Time.get_ticks_usec()
	assert(hive.quicksave(path).is_empty())
	hive.get_node("Warriors").health = 30
	assert(hive.quickload(path).is_empty())
	assert(hive.get_node("Warriors").health == 12)
	hive.get_node("Warriors").health = 0
	assert(hive.quicksave(path).is_empty())
	hive.get_node("Warriors").health = 30
	assert(hive.quickload(path).is_empty())
	assert(hive.get_node("Warriors").health == 0)
	assert(not hive.is_physics_processing())
	DirAccess.remove_absolute(path)
	hive.free()
	print("PASS area health: wounded arrival, damage handoff, revisit priority, living and death save restoration")
	quit()
