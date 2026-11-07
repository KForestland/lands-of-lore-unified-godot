extends SceneTree
const Binder = preload("res://scripts/lol2/act2_progression.gd")
var failures := 0
func area() -> String: return ""
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; print("FAIL creatures: ", message)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	Engine.set_meta("lol2_enhanced", false)
	var scene = load(Binder.LEVEL_SCENES[int(area().get_slice("_",0).trim_prefix("L"))]).instantiate()
	root.add_child(scene)
	var owner = scene.act2_creatures
	check(owner != null, area() + " owner attached")
	if owner == null: quit(1); return
	owner.set_physics_process(false)
	scene.progression.set_physics_process(false)
	scene.player.set_physics_process(false)
	var src: Dictionary = owner.src
	check(owner.bodies.size() + src.excluded.size() == int(src.source_actor_count), "source census accounted")
	for row in src.excluded: check(str(row.reason) == "invisible B_HUMAN emitter", "unsupported actor " + str(row))
	for row in src.actors:
		var id := str(int(row.actor))
		check(owner.bodies.has(id), "source actor exists " + id)
		check(owner.state.actors[id].present == bool(row.present), "source presence " + id)
		check(owner.state.actors[id].woken == not (int(row.actor) in src.scripted_dormant.map(func(n):return int(n))), "wake admission " + id)
		check(owner.bodies[id].position == Vector3(row.position[0],row.position[1],row.position[2]), "source position " + id)
		var d := int(row.definition)
		var clips: Dictionary = src.definitions[str(d)].clips
		for clip in [clips.idle,clips.walk,clips.rise,clips.death,clips.corpse]:
			check(owner.library.present(owner.materials[id],d,int(clip.selector),0).is_empty(), "decoded original pose " + id)
	# Mutation + restore of the generic packet, including absence and health, must round-trip.
	var saved: Dictionary = owner.checkpoint()
	check(owner.restore(saved).is_empty() and owner.checkpoint() == saved, "population packet roundtrip")
	owner.sync_quests()
	var path := "user://tests/" + area() + "_population.json"
	check(scene.quicksave(path).is_empty(), "actual area save")
	var first := str(int(src.actors[0].actor))
	owner.state.actors[first].present = not owner.state.actors[first].present
	check(scene.quickload(path).is_empty(), "actual area load")
	check(owner.checkpoint() == saved, "live owner restored by area load")
	print(area(), " source=", src.source_actor_count, " creatures=",owner.bodies.size()," excluded=",src.excluded.size())
	if failures == 0: print("PASS ",area()," original creature census, presence, wake admission, sprite poses and state roundtrip")
	quit(0 if failures == 0 else 1)
