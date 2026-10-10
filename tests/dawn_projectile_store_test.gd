extends SceneTree
const Store=preload("res://scripts/lol2/dawn_projectile_store.gd")
func _initialize() -> void:
	var store:=Store.new()
	var birth:=store.spawn(63,[100,200,300],[200,300,400],[0,0,0],123)
	assert(birth.allocated and birth.id==1)
	var event: Dictionary={"enabled":true,"collision":0,"target":63,"distance":65536,"movement_heading":123,"collision_heading":123}
	assert(not store.contact(1,event).request) # Caster suppressed.
	event.target=1
	assert(store.contact(1,event).request)
	var restored:=Store.new()
	assert(restored.restore(JSON.parse_string(JSON.stringify(store.checkpoint()))).is_empty())
	assert(not restored.contact(1,event).request) # No duplicate direct damage after reload.
	var update:=restored.update(1)
	assert(update.child==2 and not update.retired)
	assert(restored.update(1).child==0) # Pending child consumed before return.
	assert(restored.restore(JSON.parse_string(JSON.stringify(restored.checkpoint()))).is_empty())
	var neighbors: Array=[{"id":1,"kind":1,"flags":0x4000,"distance":999999999,"direct":false}]
	var requests:=restored.explosion(2,neighbors)
	assert(requests.requests.size()==1) # Saved direct target overrides enumeration hint/distance.
	assert(restored.explosion(2,neighbors).requests.is_empty())
	var resumed:=Store.new();assert(resumed.restore(JSON.parse_string(JSON.stringify(restored.checkpoint()))).is_empty())
	assert(resumed.explosion(2,neighbors).requests.is_empty())
	var prior:=resumed.checkpoint();var bad:=prior.duplicate(true);bad.effects[0].contact.counter=-1
	assert(not resumed.restore(bad).is_empty() and resumed.checkpoint()==prior)
	bad=prior.duplicate(true);bad.effects.append(bad.effects[0].duplicate(true))
	assert(not resumed.restore(bad).is_empty() and resumed.checkpoint()==prior)
	assert(resumed.update(1,true).retired and resumed.checkpoint().effects.size()==1)
	assert(resumed.retire(2) and resumed.checkpoint().effects.is_empty())
	assert(resumed.spawn(63,[0,0,0],[1,2,3],[0,0,0],0).id==3)
	# Wall contact must spawn its child before retiring the exhausted parent.
	event.collision=128;event.target=0
	assert(not resumed.contact(3,event).request)
	update=resumed.update(3)
	assert(update.events==["spawn_child","retire"] and update.child==4 and update.retired)
	assert(Store.validate(resumed.checkpoint()).is_empty())
	print("PASS: projectile save ownership, ignored caster, repeat direct/explosion suppression across JSON reload, child-before-retire, monotonic identities and atomic invalid restore.")
	quit()
