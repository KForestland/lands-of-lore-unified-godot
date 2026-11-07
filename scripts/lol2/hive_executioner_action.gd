extends RefCounted
## Bind A3DEC action5 lookup/start, including explicit source-pose transitions.
## Caller still supplies live dispatch, vertical, RNG and general behavior.
const Admission = preload("res://scripts/lol2/hive_action_admission.gd")
const Attack = preload("res://scripts/lol2/hive_attack_runtime.gd")
const Spatial = preload("res://scripts/lol2/hive_spatial_admission.gd")
const Numbers = preload("res://scripts/lol2/hive_clock_runtime.gd")

static func run(actor: Variant, context: Variant, helpers: Dictionary, attack: Attack, source_pose: int = -1) -> Dictionary:
	if source_pose not in [-1,0,2]: return {"error":"Unsupported source pose."}
	if not actor is Dictionary or not Numbers._integer(actor.get("ac"),255): return {"error":"Invalid executioner action mask."}
	if attack == null or attack.checkpoint().is_empty(): return {"error":"Attack stream is unavailable."}
	var hooks := helpers.duplicate()
	if not hooks.has("vertical") and context is Dictionary and context.has("spatial"):
		var classified := Spatial.vertical(context.spatial)
		if classified.has("error"): return classified
		hooks.vertical = func(_state,margin):
			assert(margin == 0x400000)
			return classified.classification
	var selections: Array = []
	hooks.lookup = func(state,action,variant):
		assert(action == 5 and variant == -1)
		var selector := Attack.action_selector(int(state.ac),(int(state.b7)>>1)&3)
		# Native A1E44 consumes this draw even though EXEC resolves to the same
		# selector for every result. Preserve the shared random stream position.
		var sample: Variant = helpers.random.call(state,100)
		if not Numbers._integer(sample,100): return -2
		return selector
	hooks.start = func(_state,selector,flags):
		assert(flags == 0)
		var changed := false
		if source_pose in [0,2]:
			var first := attack.checkpoint()
			first.selector = selector;first.frame = 0;first.timer = 0
			var error := attack.restore(first)
			assert(error.is_empty())
			changed = true
		else:
			changed = attack.select_attack(selector)
		selections.append({"selector":selector,"changed":changed})
	var result := Admission.run(actor,context,hooks)
	if result.has("error"): return result
	# These are the same actor bytes used by frame-event processing. Keep the
	# admitted actor state authoritative, including synchronous helper mutations.
	var stream := attack.checkpoint()
	stream.reverse = (int(result.state.b4)&8) != 0
	stream.flags = int(result.state.b7)
	stream.frozen = (int(result.state.b5)&2) != 0
	stream.result_count = int(result.state.ad)
	var error := attack.restore(stream)
	if not error.is_empty(): return {"error":error}
	return {"state":result.state,"attack":attack.checkpoint(),"selections":selections}
