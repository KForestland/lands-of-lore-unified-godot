extends Node3D
const RESTORE_ON := ["load"]
## Dawn shaft. Prop 98 kind 6 caller 20. Local 4 == 0 runs group 1762 and the cab
## goes to -990/-1000. Local 4 == 1 runs group 1964 and the cab returns to -90/-100.
## An unread local 4 is not 0, so the lever does not move the cab until a writer
## runs. Golden Door 51's open group is that writer. Region 1943 entry runs group
## 1100, which enqueues the same lever. The area save does not keep native locals
## or floor targets, so the optional key stores both. A save without the key stays
## valid. A fresh boot claims each cab region whose saved height differs from the
## source floor before that height is written, so the deck keeps the source floor
## as native_floor. The load always writes local 4 from the save. The lever mesh
## is not a floor face. Its aim height follows region 1943 plus the placement
## offset of 100 so a rider can still reach it.
const KEY := "l19_dawn_elevator"
const LEVER := "prop:98"
const PLATFORM := 1943
const LEVER_X := 2616
const LEVER_Z := -774
const LEVER_LIFT := 100
const CAB: Array[int] = [1935, 1936, 1937, 1938, 1939, 1940, 1941, 1942, 1943]
var host: Node3D
var hint: Label

static func initial() -> Dictionary:
	return {"version": 1, "local4": -1, "floors": {}}

static func validate(s: Variant, _quests: Dictionary = {}) -> String:
	if not s is Dictionary or (s as Dictionary).size() != 3:
		return "Invalid dawn elevator state."
	var version: Variant = s.get("version")
	if not (version is int or version is float) or int(version) != 1:
		return "Invalid dawn elevator state."
	var local4: Variant = s.get("local4")
	if not (local4 is int or local4 is float) or int(local4) < 0 or int(local4) > 255:
		return "Invalid dawn elevator state."
	var floors: Variant = s.get("floors")
	if not floors is Dictionary or (floors as Dictionary).size() != CAB.size():
		return "Invalid dawn elevator state."
	for id in CAB:
		var height: Variant = (floors as Dictionary).get(str(id))
		if not (height is int or height is float) or not is_finite(float(height)) or float(height) != floorf(float(height)):
			return "Invalid dawn elevator state."
		if int(height) < -32768 or int(height) > 32767:
			return "Invalid dawn elevator state."
	return ""

static func attach(map: Node3D) -> Node:
	var n: Node = load("res://scripts/lol2/l19_dawn_elevator.gd").new()
	n.host = map
	n.name = "L19DawnElevator"
	map.add_child(n)
	return n

func state() -> Dictionary:
	var raw: Variant = host.quest_state.get(KEY, {})
	if not raw is Dictionary or not (raw as Dictionary).has("floors"):
		return initial()
	var floors: Dictionary = {}
	var listed: Variant = (raw as Dictionary).get("floors", {})
	if listed is Dictionary:
		for id in CAB:
			floors[str(id)] = int((listed as Dictionary).get(str(id), 0))
	return {"version": 1, "local4": int((raw as Dictionary).get("local4", -1)), "floors": floors}

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 34
	add_child(canvas)
	hint = Label.new()
	hint.position = Vector2(24, 548)
	canvas.add_child(hint)

func _moving(region: int) -> bool:
	var motion: Variant = host.progression.floor_motion.get(region)
	return motion is Dictionary and int((motion as Dictionary).get("remaining", 0)) != 0

func _place(region: int, height: int) -> void:
	var pr: Node = host.progression
	var old: int = int(pr.regions[region][1])
	pr.regions[region][1] = height
	if pr.floor_decks.has(region):
		var deck: Node3D = pr.floor_decks[region] as Node3D
		deck.position.y = float(height - int(deck.get_meta("native_floor", old)))
	if not _moving(region):
		pr.floor_motion.erase(region)

func restore() -> void:
	if host == null or host.progression == null or host.progression.native == null:
		return
	var packet: Dictionary = state()
	if int(packet.local4) < 0:
		return
	var pr: Node = host.progression
	pr.native.set_local(4, int(packet.local4))
	var floors: Dictionary = packet.floors
	for id in CAB:
		if _moving(id):
			continue
		var height: int = int(floors.get(str(id), pr.regions[id][1]))
		# native_floor is the region height at claim time, so this runs before _place.
		if height != int(pr.regions[id][1]):
			pr._claim_region_floor(id)
		_place(id, height)

func _capture() -> void:
	var pr: Node = host.progression
	if pr == null or pr.native == null or not pr.native.locals.has(4):
		return
	var floors: Dictionary = {}
	for id in CAB:
		floors[str(id)] = int(pr.regions[id][1])
	var local4: int = int(pr.native.locals[4])
	var current: Dictionary = state()
	if int(current.local4) == local4 and (current.floors as Dictionary).size() == floors.size():
		var same: bool = true
		for id in CAB:
			if int((current.floors as Dictionary).get(str(id), 0)) != int(floors[str(id)]):
				same = false
		if same:
			return
	host.quest_state[KEY] = {"version": 1, "local4": local4, "floors": floors}

func _track_lever() -> void:
	var pr: Node = host.progression
	if pr == null or not pr.exit_objects.has(LEVER):
		return
	var floor: int = int(pr.regions[PLATFORM][1])
	var edges: Array = pr.exit_objects[LEVER] as Array
	if edges.is_empty():
		return
	var edge: Dictionary = edges[0]
	edge["position"] = [LEVER_X, floor + LEVER_LIFT, LEVER_Z]

func _process(_delta: float) -> void:
	if hint != null:
		hint.text = ""
	if host == null or host.progression == null:
		return
	_track_lever()
	_capture()
	if host.flying or not host.starting_magic.world_active():
		return
	var here: int = host.progression.region_at(host.player.global_position)
	if here == PLATFORM:
		hint.text = "E — Use the lever"

func generic_target() -> Dictionary:
	if host.progression.aimed_exit()!=LEVER:return {}
	var point:Array=host.progression.exit_objects[LEVER][0].position
	return {"point":Vector3(point[0],point[1],point[2])}
func try_use() -> bool:
	if generic_target().is_empty():return false
	var results:Array=host.progression.use_exit(LEVER)
	var pending:bool=results.any(func(row):return str(row.status)=="unhosted")
	host.save_feedback("This passage is not available yet." if pending else "You use the passage control.")
	return true
