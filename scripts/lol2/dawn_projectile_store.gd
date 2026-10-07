extends RefCounted
## Saved effect ownership. Effects remain local to their Dawn encounter packet.
## Commit transitions before returning requests to potentially reentrant callers.
const Contact=preload("res://scripts/lol2/dawn_spell_contact.gd")
const Explosion=preload("res://scripts/lol2/dawn_explosion.gd")
const Values=preload("res://scripts/lol2/dawn_cast_target.gd")
const CAPACITY:=256 # Modern allocation bound; caller still executes cast tail.
var _saved: Dictionary=initial()
static func initial() -> Dictionary: return {"version":1,"next_id":1,"effects":[]}
static func point(value: Variant) -> bool:
	if not value is Array or value.size()!=3: return false
	for n in value:
		if not Values.integer(n,-2147483648,2147483647): return false
	return true
static func validate(saved: Variant) -> String:
	if not saved is Dictionary or saved.size()!=3 or not Values.integer(saved.get("version"),1,1) or not Values.integer(saved.get("next_id"),1,0x7fffffff): return "Invalid projectile store."
	if not saved.get("effects") is Array or saved.effects.size()>CAPACITY: return "Invalid projectile population."
	var seen: Array=[]
	for effect in saved.effects:
		if not effect is Dictionary or not Values.integer(effect.get("id"),1,int(saved.next_id)-1) or effect.id in seen: return "Invalid projectile identity."
		seen.append(effect.id)
		if not Values.integer(effect.get("owner"),1,0x7fffffff) or not point(effect.get("position")): return "Invalid projectile owner/position."
		if not Values.integer(effect.get("kind"),0,255):return "Invalid effect kind."
		match int(effect.kind):
			32:
				if effect.size()!=8 or not point(effect.get("aim")) or not point(effect.get("start")) or not effect.get("cancelled") is bool: return "Invalid fireball."
				var error:=Contact.validate(effect.get("contact"))
				if not error.is_empty():return error
				if int(effect.contact.counter)>4 or int(effect.contact.threshold) not in [0,100,160]:return "Unreachable fireball contact state."
			98:
				if effect.size()!=6 or not effect.get("applied") is bool or not Values.integer(effect.get("direct"),0,0x7fffffff): return "Invalid explosion."
			_: return "Unsupported saved projectile."
	return ""
func checkpoint() -> Dictionary: return _saved.duplicate(true)
func restore(saved: Variant) -> String:
	var error:=validate(saved)
	if not error.is_empty():return error
	var next: Dictionary=saved.duplicate(true)
	next.version=1;next.next_id=int(next.next_id)
	for effect in next.effects:
		for key in ["id","kind","owner"]:effect[key]=int(effect[key])
		effect.position=effect.position.map(func(n):return int(n))
		if effect.kind==32:
			effect.aim=effect.aim.map(func(n):return int(n));effect.start=effect.start.map(func(n):return int(n))
			effect.contact=Contact.restore(effect.contact).state
		else:effect.direct=int(effect.direct)
	_saved=next
	return ""
func _index(id: int) -> int:
	for i in _saved.effects.size():
		if _saved.effects[i].id==id:return i
	return -1
func _room() -> bool: return _saved.effects.size()<CAPACITY and _saved.next_id<0x7fffffff
func spawn(owner: int, position: Array, aim: Array, start: Array, heading: int) -> Dictionary:
	if not Values.integer(owner,1,0x7fffffff) or not point(position) or not point(aim) or not point(start) or not Values.integer(heading,0,65535):return {"error":"Invalid fireball creation."}
	if not _room():return {"allocated":false}
	var id: int=_saved.next_id;_saved.next_id+=1
	_saved.effects.append({"id":id,"kind":32,"owner":owner,"position":position.duplicate(),"aim":aim.duplicate(),"start":start.duplicate(),"cancelled":false,
		"contact":{"last_contact":owner,"counter":4,"threshold":0,"heading":heading,"done":false,"contact_seen":false}})
	return {"allocated":true,"id":id}
func contact(id: int, event: Dictionary) -> Dictionary:
	var i:=_index(id)
	if i<0 or _saved.effects[i].kind!=32:return {"error":"Unknown fireball."}
	var result:=Contact.contact(_saved.effects[i].contact,event)
	if result.has("error"):return result
	_saved.effects[i].contact=result.state # Before caller dispatches health loss.
	return {"request":result.request,"owner":_saved.effects[i].owner,"target":result.state.last_contact}
func update(id: int, cancelled: bool=false) -> Dictionary:
	var i:=_index(id)
	if i<0 or _saved.effects[i].kind!=32:return {"error":"Unknown fireball."}
	var effect: Dictionary=_saved.effects[i]
	var allocate:=_room()
	var result:=Contact.update(effect.contact,cancelled or effect.cancelled,160 if allocate else null)
	if result.has("error"):return result
	effect.contact=result.state
	var child:=0
	if result.spawn_child and allocate:
		child=_saved.next_id;_saved.next_id+=1
		_saved.effects.append({"id":child,"kind":98,"owner":effect.owner,"position":effect.position.duplicate(),"direct":int(effect.contact.last_contact),"applied":false})
	if result.retired:_saved.effects.remove_at(i)
	return {"child":child,"retired":result.retired,"events":result.events}
func explosion(id: int, neighbors: Array) -> Dictionary:
	var i:=_index(id)
	if i<0 or _saved.effects[i].kind!=98:return {"error":"Unknown explosion."}
	var checked:=Explosion.first_pass(true,neighbors)
	if checked.has("error"):return checked
	var bound:=neighbors.duplicate(true)
	for neighbor in bound:neighbor.direct=int(neighbor.id)==int(_saved.effects[i].direct)
	var result:=Explosion.first_pass(_saved.effects[i].applied,bound)
	if result.has("error"):return result
	_saved.effects[i].applied=result.applied # Reentrant saves see consumed pass.
	return {"owner":_saved.effects[i].owner,"requests":result.requests}
func retire(id: int) -> bool:
	var i:=_index(id)
	if i<0:return false
	_saved.effects.remove_at(i)
	return true

## Shared world clock delta, never an independent projectile wall clock.
func motion(id: int, delta: int) -> Dictionary:
	var i:=_index(id)
	if i<0 or _saved.effects[i].kind!=32:return {"error":"Unknown fireball."}
	var effect: Dictionary=_saved.effects[i]
	if effect.cancelled or effect.contact.counter==0:return {"error":"Inactive fireball motion."}
	var distance:=preload("res://scripts/lol2/hive_condition_geometry.gd").distance_between_startup(effect.position.slice(0,2),effect.aim.slice(0,2))
	if distance.has("error") or distance.integer_invalid:return {"error":"Unsupported fireball target distance."}
	var request:=preload("res://scripts/lol2/dawn_spell_motion.gd").request({"heading":effect.contact.heading,"delta":delta,"planar_distance":distance.distance,
		"height_delta":preload("res://scripts/lol2/dawn_projectile_launch.gd").signed32(int(effect.aim[2])-int(effect.position[2]))})
	if request.has("error"):return request
	var rotation=preload("res://scripts/lol2/hive_boulder_impulse.gd")
	var wrap=preload("res://scripts/lol2/dawn_projectile_launch.gd")
	var next: Array=[wrap.signed32(int(effect.position[0])+((request.distance*rotation.sine(request.heading))>>16)),
		wrap.signed32(int(effect.position[1])+((request.distance*rotation.sine(request.heading+16384))>>16)),
		wrap.signed32(int(effect.position[2])+request.vertical)]
	return {"from":effect.position.duplicate(),"to":next,"request":request}

## Commit a synchronous world sweep only if its starting position still matches.
func moved(id: int, from: Array, to: Array) -> String:
	var i:=_index(id)
	if i<0 or _saved.effects[i].kind!=32 or not point(from) or not point(to):return "Invalid projectile motion commit."
	for axis in 3:
		if int(_saved.effects[i].position[axis])!=int(from[axis]):return "Stale projectile motion commit."
	_saved.effects[i].position=to.map(func(n):return int(n))
	return ""
