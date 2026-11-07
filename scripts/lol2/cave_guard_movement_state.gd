extends RefCounted
## Native 16.16 travel/target arithmetic. Host supplies clock and collision admission.
const Values=preload("res://scripts/lol2/save_value_rules.gd")
static func source() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/cave_guard_sequence_movables.json"))
static func initial(src: Dictionary) -> Dictionary:
	var objects: Dictionary={}
	for row in src.movables:
		objects[str(int(row.motion.index))]={"current":int(row.motion.initial_travel)*65536,"target":0,"status":0}
	return {"version":1,"objects":objects}
static func record(src: Dictionary, id: int) -> Dictionary:
	for row in src.movables:
		if int(row.motion.index)==id:return row.motion
	return {}
static func validate(s: Variant, src: Dictionary) -> String:
	if not s is Dictionary or not Values.integer(s.get("version"),1) or s.version!=1 or not s.get("objects") is Dictionary or s.objects.size()!=src.movables.size():return "Invalid encounter movement bank."
	for row in src.movables:
		var id:=str(int(row.motion.index));var v=s.objects.get(id);var maximum:=int(row.motion.travel)*65536
		if not v is Dictionary or not Values.integer(v.get("current"),maximum) or not Values.integer(v.get("target"),maximum) or not Values.integer(v.get("status"),5):return "Invalid encounter movement value."
		if int(v.target)%65536!=0:return "Invalid encounter movement target precision."
		if v.status==2 and v.current>v.target:return "Encounter rise target behind current."
		if v.status==3 and v.current<v.target:return "Encounter return target ahead of current."
		if v.status in [0,1,5] and v.current!=v.target:return "Stationary encounter object has travel remaining."
		if v.status==4:return "Unsupported continuous encounter motion."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var r:=s.duplicate(true);r.version=1
	for obj in r.objects.values():
		for key in ["current","target","status"]:obj[key]=int(obj[key])
	return r
static func command(s: Dictionary, src: Dictionary, id: int, percent: int) -> bool:
	if not s.objects.has(str(id)) or percent<0 or percent>100:return false
	var row:=record(src,id);var obj: Dictionary=s.objects[str(id)]
	obj.target=(int(row.travel)*percent/100)*65536
	# Integer division follows the source percentage command.
	obj.target=int(obj.target)
	obj.status=(1 if obj.current!=0 else 0) if obj.target==obj.current else 2 if obj.target>obj.current else 3
	return true
static func advance(s: Dictionary, src: Dictionary, tick_fixed: int) -> Array:
	if tick_fixed<0 or tick_fixed>131072:return []
	var events: Array=[]
	for id in s.objects:
		var obj: Dictionary=s.objects[id]
		if obj.status not in [2,3]:continue
		var rising: bool=obj.status==2
		if obj.current==obj.target:
			obj.status=1 if rising else 5
			events.append({"owner":int(id),"value":15 if rising else 16});events.append({"owner":int(id),"value":17})
			continue
		var row:=record(src,int(id));var speed: int=int(row.speed_byte)*10/4
		var step: int=tick_fixed*speed/60
		obj.current=mini(obj.target,obj.current+step) if rising else maxi(obj.target,obj.current-step)
	return events
static func vertical_offset(s: Dictionary, src: Dictionary, id: int) -> float:
	var row:=record(src,id)
	return float(s.objects[str(id)].current)/65536.0*(1.0 if int(row.mode)==0 else -1.0)
