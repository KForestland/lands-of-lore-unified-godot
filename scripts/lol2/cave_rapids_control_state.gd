extends RefCounted
## Five source group4076 controls. Accepted-motion adapter; native collision is not implemented here.
const Step=preload("res://scripts/lol2/scripted_control_step.gd")
const Displacement=preload("res://scripts/lol2/scripted_control_displacement.gd")
static var _source: Dictionary={}
static func source() -> Dictionary:
	if _source.is_empty():_source=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/cave_rapids_trigger_source.json"))
	return _source
static func _native(point: Array) -> Array:
	return [int(point[0])*65536,-int(point[2])*65536,int(point[1])*65536]
static func initial(rounding_mode: int) -> Dictionary:
	if rounding_mode<0 or rounding_mode>3:return {}
	var controls: Dictionary={}
	for row in source().controls:
		var motion: Dictionary=row.motion
		controls[str(int(motion.owner))]={"position":_native(motion.position),"heading":int(motion.heading),"flags":int(motion.motion_flags),"elapsed":0,"pitch":0,"speed":int(motion.base_constructor_speed),"complete":false}
	return {"version":1,"started":false,"rounding_mode":rounding_mode,"controls":controls}
static func start(state: Dictionary) -> bool:
	if state.started:return false
	state.started=true
	return true
static func speed_refresh(horizontal: int, tick_fixed: int) -> int:
	return ((horizontal*24/tick_fixed)+1)&255 if horizontal>0 and tick_fixed>0 else 0
static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size()!=4 or value.get("version")!=1 or not value.get("started") is bool or not Step._integer(value.get("rounding_mode"),0,3) or not value.get("controls") is Dictionary:return "Invalid rapids control packet."
	if value.controls.size()!=5:return "Missing rapids controls."
	var pristine:=initial(int(value.rounding_mode))
	for row in source().controls:
		var m: Dictionary=row.motion
		var id:=str(int(m.owner))
		var item: Variant=value.controls.get(id)
		if not item is Dictionary or item.size()!=7 or not item.get("complete") is bool:return "Invalid rapids control "+id
		if not item.get("position") is Array or item.position.size()!=3:return "Invalid rapids control position."
		for coordinate in item.position:
			if not Step._integer(coordinate,-0x7fffffff,0x7fffffff):return "Invalid rapids control coordinate."
		if not Step._integer(item.get("heading"),0,65535):return "Invalid rapids control heading."
		for key in ["elapsed","pitch","speed"]:
			if not Step._integer(item.get(key),0,255):return "Invalid rapids control "+key
		var flags: int=int(m.motion_flags)
		if not Step._integer(item.get("flags"),0,65535) or int(item.flags) not in [flags,flags|16,flags|32,flags|48]:return "Invalid rapids control flags."
		if bool(item.complete)!=bool(int(item.flags)&32):return "Rapids control completion mismatch."
		if item.complete:
			var target:=_native(m.target)
			for i in 3:
				if int(item.position[i])!=target[i]:return "Rapids control endpoint mismatch."
			if int(item.heading)!=int(m.target_heading):return "Rapids control terminal heading mismatch."
		if not value.started:
			var expected: Dictionary=pristine.controls[id]
			for key in ["heading","flags","elapsed","pitch","speed"]:
				if int(item[key])!=int(expected[key]):return "Inactive rapids control changed."
			for i in 3:
				if int(item.position[i])!=int(expected.position[i]):return "Inactive rapids position changed."
	return ""
static func canonical(value: Dictionary) -> Dictionary:
	var out: Dictionary=value.duplicate(true)
	out.version=1;out.rounding_mode=int(out.rounding_mode)
	for item in out.controls.values():
		for key in ["heading","flags","elapsed","pitch","speed"]:item[key]=int(item[key])
		for i in 3:item.position[i]=int(item.position[i])
	return out
## Caller explicitly admits the complete proposed move. No native collision/retry claim.
static func advance_accepted(state: Dictionary, tick_fixed: int, ticks: int) -> Array:
	if not state.started or tick_fixed<0 or tick_fixed>65536 or ticks<0 or ticks>255:return []
	var completed: Array=[]
	for row in source().controls:
		var motion: Dictionary=row.motion
		var id:=str(int(motion.owner))
		var control: Dictionary=state.controls[id]
		if control.complete:continue
		var context: Dictionary=control.duplicate(true)
		context.target=_native(motion.target);context.target_heading=int(motion.target_heading)
		context.target_speed=int(motion.speed_byte);context.base_speed=int(control.speed)
		context.ticks=ticks;context.tick_fixed=tick_fixed;context.rounding_mode=int(state.rounding_mode)
		var result:=Step.step(context)
		assert(not result.is_empty())
		for key in ["flags","elapsed","pitch","heading"]:control[key]=result[key]
		if int(result.result)==1:
			control.position=result.position;control.complete=true;completed.append(int(motion.owner))
		else:
			var delta:=Displacement.step(int(result.vector[0])&65535,int(result.vector[1]))
			control.position[0]=int(control.position[0])+int(delta.dx)
			control.position[1]=int(control.position[1])+int(delta.dy)
			control.position[2]=int(control.position[2])+int(result.vector[2])
			control.speed=speed_refresh(int(result.vector[1]),tick_fixed)
	return completed
