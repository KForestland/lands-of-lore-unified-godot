extends SceneTree
## Native MGAR orb offer, D6A08(+20) and Morgan presence cases must match Godot.
const Blessing = preload("res://scripts/lol2/morgan_orb_blessing.gd")
const Quest = preload("res://scripts/lol2/monastery_quest_state.gd")
func _initialize() -> void:
	_run.call_deferred()
static func canon(value: Variant) -> Variant:
	if value is float and value == floorf(value): return int(value)
	if value is Array:
		var out: Array = []
		for item in value: out.append(canon(item))
		return out
	return value
func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/morgan-orb-blessing-checks.json"))
	var failures: Array = []
	for c in data.health_cases.cases:
		if Blessing.heal(int(c.current),int(c.maximum),int(c.flags229)) != int(c.after): failures.append(["heal",c])
	for c in data.offer_cases:
		if c.held != Blessing.ORB: continue
		if str(canon(Blessing.offer_plan(c.flags,c.held))) != str(canon(c.effects)): failures.append(["offer",c])
	for c in data.presence_cases:
		var state := {"flags":{},"globals":{},"locals":{}}
		for k in c.flags: state.flags[k] = int(c.flags[k])
		if Quest.side_actor_present(state,"MGAR",c.orb_owned) != c.present: failures.append(["presence",c])
	var flags := {"258":1}
	var first := Blessing.offer_plan(flags,Blessing.ORB)
	flags["259"] = 1
	if str(canon(first)) != str(canon(data.sequence.first)) or str(canon(Blessing.offer_plan(flags,Blessing.ORB))) != str(canon(data.sequence.repeat_same_visit)): failures.append(["sequence"])
	if failures:
		for f in failures.slice(0,5): push_error(str(f))
		push_error("FAIL: %d Morgan orb cases differ" % failures.size())
		quit(1)
		return
	print("PASS: ",data.health_cases.cases.size()," heal, ",data.offer_cases.size()," offer and ",data.presence_cases.size()," presence native cases match")
	quit()
