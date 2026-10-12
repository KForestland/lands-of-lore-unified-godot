extends SceneTree
const State=preload("res://scripts/lol2/cave_roach_population_state.gd")
func _initialize() -> void:
	var state:=State.initial()
	assert(State.validate(state).is_empty() and state.actors.size()==23)
	var regions: Array=JSON.parse_string(FileAccess.get_file_as_string(State.SOURCE)).regions
	for region in regions:
		var point:=Vector3.ZERO
		for vertex in region.polygon: point+=Vector3(vertex[0],0,vertex[1])
		point/=region.polygon.size();point.y=float(region.floor_min)+32.0
		var contact:=State.initial()
		State.contact_at(contact,regions,point,false)
		assert(contact.regions.is_empty())
		State.contact_at(contact,regions,point+Vector3(0,100,0),true)
		assert(contact.regions.is_empty())
		State.contact_at(contact,regions,point,true)
		assert(int(region.region) in contact.regions and contact.actors["25"].b5==12)
	var before:=state.duplicate(true)
	state.actors["25"].word7c=91
	state.actors["26"].health=0;state.actors["26"].a8=15;state.actors["26"].word7c=17
	assert(State.first_contact(state,1140))
	for id in [25,27,28,29,30,31,32,33,34,35,43]:
		assert(state.actors[str(id)].b5==12 and state.actors[str(id)].word7c==0)
	assert(state.actors["26"].word7c==17 and state.actors["26"].b5==0)
	for id in [40,41,42,44,45,46,47,48,49,50,51]:assert(state.actors[str(id)]==before.actors[str(id)])
	assert(not State.first_contact(state,1140) and not State.first_contact(state,999))
	assert(State.apply_pending(state,"25",6,0))
	assert(state.actors["25"].a8==14 and state.actors["25"].a9==6)
	assert(not State.commit(state,"25",0) and state.actors["25"].a8==14)
	assert(State.commit(state,"25",1) and state.actors["25"].a8==6 and state.actors["25"].aa==0)
	var disk=JSON.parse_string(JSON.stringify(state))
	assert(State.validate(disk).is_empty())
	var resumed:=State.canonical(disk)
	assert(State.first_contact(state,1358)==State.first_contact(resumed,1358))
	assert(state==resumed)
	var bad:=state.duplicate(true);bad.actors["25"].health=0
	assert(not State.validate(bad).is_empty())
	bad=state.duplicate(true);bad.actors["24"]=bad.actors["25"];bad.actors.erase("25")
	assert(not State.validate(bad).is_empty())
	bad=state.duplicate(true);bad.regions=[1140,1140]
	assert(not State.validate(bad).is_empty())
	print("PASS:23 source Roach identities, exact12-actor groups, defeated skip, pending/commit split, JSON continuation and malformed rejection")
	quit()
