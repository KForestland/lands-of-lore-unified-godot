extends RefCounted
## Material/motion portion of accepted source group5074 only.
## Caller executes preceding prop453/view/audio commands and owns collision admission,
## native tick production, world surfaces, and region-completion dispatch to local7.
const Motion=preload("res://scripts/lol2/floor_motion_step.gd")
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const SOURCE="res://scripts/lol2/cave_rapids_floor_source.json"
static var _source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
static func source() -> Dictionary:
	return _source
static func initial() -> Dictionary:
	var floors: Dictionary={}
	for row in source().floors:
		floors[str(int(row.region))]={"height":int(row.height),"remaining":0,"fraction":0,"speed":int(row.speed),"material":int(row.initial_material),"derived_byte39":int(row.initial_derived_byte39),"completed":false}
	return {"version":1,"started":false,"floors":floors}
static func validate(s: Variant) -> String:
	if not s is Dictionary or s.get("version")!=1 or s.size()!=3:return "Invalid rapids floor version."
	if not s.get("started") is bool or not s.get("floors") is Dictionary or s.floors.size()!=3:return "Invalid rapids floor bank."
	for row in source().floors:
		var f=s.floors.get(str(int(row.region)))
		if not f is Dictionary or f.size()!=7 or not Motion.valid(f):return "Invalid rapids floor motion."
		if not f.get("completed") is bool or f.speed!=row.speed:return "Invalid rapids floor completion."
		if not Values.integer(f.get("material"),255) or not Values.integer(f.get("derived_byte39"),255):return "Invalid rapids material."
		if not s.started:
			if f.height!=row.height or f.remaining!=0 or f.fraction!=0 or f.completed or f.material!=row.initial_material or f.derived_byte39!=row.initial_derived_byte39:return "Changed inactive rapids floor."
		else:
			if f.height<row.height or f.height>row.target or f.height+f.remaining!=row.target:return "Rapids floor target mismatch."
			if f.material!=row.material or f.derived_byte39!=row.derived_byte39:return "Rapids material command missing."
			if f.completed!=(f.remaining==0):return "Rapids completion receipt mismatch."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var result:=s.duplicate(true);result.version=1
	for id in result.floors:
		for key in ["height","remaining","fraction","speed","material","derived_byte39"]:result.floors[id][key]=int(result.floors[id][key])
	return result
static func start(s: Dictionary) -> bool:
	if not validate(s).is_empty():return false
	# Reissuing an admitted source group resets command fractions from the current heights.
	# The caller, not this component, enforces predicate199/local7 and control hit admission.
	for row in source().floors:
		var f: Dictionary=s.floors[str(int(row.region))]
		f.material=int(row.material);f.derived_byte39=int(row.derived_byte39)
		f.remaining=int(row.target)-int(f.height);f.fraction=0;f.completed=f.remaining==0
	s.started=true
	return true
static func advance_accepted(s: Dictionary, tick_fixed: int) -> Array:
	var events: Array=[]
	if not validate(s).is_empty() or not s.started or tick_fixed<0 or tick_fixed>131072:return events
	for row in source().floors:
		var f: Dictionary=s.floors[str(int(row.region))]
		if Motion.advance_one(f,tick_fixed):
			f.completed=true
			# Native upward-floor completion emits region event4 on this update.
			events.append({"region":int(row.region),"event":4})
	return events
static func local7_write(event: Dictionary) -> bool:
	return event.get("region")==10 and event.get("event")==4
