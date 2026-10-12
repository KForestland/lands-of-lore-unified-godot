extends SceneTree
## Every native MOFF message9/message8 case must match the Godot planner.
const Speech = preload("res://scripts/lol2/monastery_conversation.gd")
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
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://docs/moff-revisit-checks.json"))
	var failures := 0
	var rows := 0
	for kind in ["entry","exit"]:
		for c in data.cases[kind]:
			var plan: Dictionary
			if kind == "entry": plan = Speech.moff_entry_plan(c.flags,int(c.translated_at_load),int(c.has_runes))
			else: plan = Speech.moff_exit_plan(c.flags,int(c.translated_at_load),int(c.has_runes),int(c.flags.get("144",0)),int(c.soul))
			if str(canon([c.handled,c.effects])) != str(canon([plan.handled,plan.effects])):
				failures += 1
				if failures < 5: push_error("%s mismatch %s\nnative %s\nplanner %s" % [kind,str(c.flags),str(canon(c.effects)),str(canon(plan.effects))])
			rows += 1
	if failures:
		push_error("FAIL: %d of %d MOFF planner cases differ" % [failures,rows])
		quit(1)
		return
	print("PASS: ",rows," native MOFF entry/exit cases match the planner")
	quit()
