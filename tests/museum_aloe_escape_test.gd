extends "res://tests/museum_long_arm_escape_test.gd"
## Inherits supplied walkway/open-lock prerequisites, actual fall/tiny timer and production W escape.
## No pickup grants or repositioning after the initial inherited walkway placement.
const Aloe=preload("res://scripts/lol2/museum_aloe_state.gd")
var collection_events:Array=[]
func _initialize() -> void:
	# Invalidate only this test's artifacts before the producer runs. A failed
	# route must not leave an older success available to the restart consumer.
	for path in ["user://tests/museum_aloe_escaped.json", "user://tests/museum_aloe_escape_events.json"]:
		if FileAccess.file_exists(path):
			var error := DirAccess.remove_absolute(path)
			if error != OK:
				printerr("FAIL cannot invalidate stale Aloe route artifact: ", path)
				quit(1)
				return
	super._initialize()
func check_route_pickups() -> bool:
	var owner=museum.aloe_pickups
	if not check(is_instance_valid(owner),"Missing Aloe owner on escape route"):return false
	for i in 2:
		if owner.state.taken[i]:continue
		var target:Vector3=owner.pickups[i].global_position
		if museum.camera.global_position.distance_to(target)>95:continue
		museum.camera.look_at(target)
		if owner.offered()!=i:continue
		press_e()
		if not check(owner.state.taken[i] and museum.carried_collected.count(Aloe.IDS[i])==1,"Escape E did not grant offered Aloe"):return false
		var pos:Vector3=museum.player.global_position
		collection_events.append({"id":Aloe.IDS[i],"position":[pos.x,pos.y,pos.z],"form":museum.player_form})
	return true
func check_route_pickups_complete() -> bool:
	if not check(collection_events.size()==2,"Escape missed Aloe: %s"%[collection_events]):return false
	for i in 2:
		if not check(museum.aloe_pickups.state.taken[i] and not museum.aloe_pickups.pickups[i].visible and museum.carried_collected.count(Aloe.IDS[i])==1,"Escaped reload lost Aloe receipt"):return false
	if not check(museum.quicksave("user://tests/museum_aloe_escaped.json").is_empty(),"Could not save qualified Aloe escape"):return false
	var f=FileAccess.open("user://tests/museum_aloe_escape_events.json",FileAccess.WRITE)
	f.store_string(JSON.stringify({"scope":"Supplied initial walkway and passage78 open; subsequent fall, timed tiny, movement and Aloe collection through production paths", "events":collection_events},"  "))
	print("PASS Aloe pickups during actual Long Arm escape and post-escape save/load: ",JSON.stringify(collection_events))
	return true
