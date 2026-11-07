extends RefCounted
## Original spell32 collision transition. Object identities and collision/distance
## are supplied by the world adapter; this component never applies health loss.
const Numbers=preload("res://scripts/lol2/save_value_rules.gd")
const LIMITS={"last_contact":0x7fffffff,"counter":255,"threshold":255,"heading":65535}

static func validate(state: Variant) -> String:
	if not state is Dictionary or state.size()!=6: return "Invalid spell contact state."
	for field in LIMITS:
		if not Numbers.integer(state.get(field),LIMITS[field]): return "Invalid spell contact field."
	for field in ["done","contact_seen"]:
		if not state.get(field) is bool: return "Invalid spell contact flag."
	return ""

static func restore(saved: Variant) -> Dictionary:
	var error:=validate(saved)
	if not error.is_empty(): return {"error":error}
	var state: Dictionary=saved.duplicate(true)
	for field in LIMITS: state[field]=int(state[field])
	return {"state":state}

## Original update prefix. The caller supplies the child-construction outcome:
## null means allocation/construction failed, otherwise its state byte14 radius.
## The caller must process events in order: spawn first, then retire.
static func update(saved: Variant, cancelled: Variant, child_radius: Variant=null) -> Dictionary:
	var result:=restore(saved)
	if result.has("error"): return result
	if not cancelled is bool or (child_radius!=null and not Numbers.integer(child_radius,255)): return {"error":"Invalid spell lifecycle input."}
	var state: Dictionary=result.state
	result.spawn_child=false;result.retired=false;result.events=[]
	if cancelled:
		result.retired=true
		result.events.append("retire")
		return result
	if state.done:
		result.spawn_child=true
		result.events.append("spawn_child")
		state.threshold=100 if child_radius==null else int(child_radius)
		state.done=false
	result.retired=state.counter==0
	if result.retired: result.events.append("retire")
	return result

static func contact(saved: Variant, event: Variant) -> Dictionary:
	var result:=restore(saved)
	if result.has("error"): return result
	if not event is Dictionary or not event.get("enabled") is bool: return {"error":"Invalid spell collision event."}
	for field in {"collision":255,"target":0x7fffffff,"distance":0x7fffffff,"movement_heading":65535,"collision_heading":65535}:
		var maximum: int=255 if field=="collision" else 65535 if field in ["movement_heading","collision_heading"] else 0x7fffffff
		if not Numbers.integer(event.get(field),maximum): return {"error":"Invalid spell collision input."}
	var state: Dictionary=result.state
	result.request=false
	if not event.enabled: return result
	state.contact_seen=true
	if int(event.collision)==128:
		state.counter=0;state.last_contact=0
	else:
		if int(event.target)==state.last_contact:
			state.counter=maxi(0,state.counter-1)
			return result
		state.last_contact=int(event.target)
	if state.done: return result
	state.counter=maxi(0,state.counter-1)
	if int(event.distance)<=state.threshold*65536: return result
	if state.last_contact!=0:
		var heading:=int(event.movement_heading)
		var difference: int=(heading-int(event.collision_heading))&65535
		if difference<32768: heading-=mini(difference,4096)
		else: heading+=mini(65535-difference,4096)
		state.heading=heading&65535
		result.request=true
	state.done=true
	return result
