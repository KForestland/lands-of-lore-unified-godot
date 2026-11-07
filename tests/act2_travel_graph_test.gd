extends SceneTree
## Actual scene graph from L8. --maps-complete is the strict opt-in gate; CORE runs the
## diagnostic. Arrival contexts are distinct so L19's two original routes are both visited.
const Binder = preload("res://scripts/lol2/act2_progression.gd")
var failures := 0
var graph: Dictionary
var visited: Dictionary = {}
var states: Dictionary = {}
var rows: Dictionary = {}
func _initialize() -> void: run.call_deferred()
func check(ok: bool, message: String) -> void:
	if not ok: failures += 1; print("FAIL travel graph: " + message)
func open_level(area: String, selector: int) -> Node:
	if is_instance_valid(current_scene):
		current_scene.queue_free()
		await process_frame
	set_meta("lol2_level_change", true)
	set_meta("lol2_map_start_selector", selector)
	var scene = load(Binder.LEVEL_SCENES[int(area.get_slice("_", 0).trim_prefix("L"))]).instantiate()
	scene.adapter_exit_seeds = not "--no-exit-seeds" in OS.get_cmdline_user_args()
	root.add_child(scene)
	current_scene = scene
	scene.set_physics_process(false)
	scene.player.set_physics_process(false)
	if scene.progression != null: scene.progression.set_physics_process(false)
	return scene
func run() -> void:
	graph = JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/act2_travel.json"))
	Engine.set_meta("lol2_enhanced", false)
	for edge in graph.edges:
		rows[edge.id] = {"id":edge.id,"area":edge.area,"destination":edge.destination,"selector":edge.selector,"traversed":false,"reason":"Source not reached from L8"}
	var queue: Array = [{"area":"L8_SJ","selector":1}]
	while not queue.is_empty():
		var entry: Dictionary = queue.pop_front()
		var area := str(entry.area)
		var state_key := "%s:%d" % [area,int(entry.selector)]
		if states.has(state_key): continue
		states[state_key] = true
		visited[area] = true
		for edge in graph.edges:
			if str(edge.area) != area or bool(rows[edge.id].traversed): continue
			var scene = await open_level(area,int(entry.selector))
			var p = scene.progression
			check(p != null, "binder " + area)
			if p == null: continue
			var preparation: Array = []
			if area == "L10_DC" and str(edge.owner) == "region:42": preparation = p.use_exit("control:150")
			var result: Array
			if area == "L9_DR" and str(edge.owner) == "prop:104":
				preparation = p.use_exit("control:82")
				for tick in 3:
					if not p.level_changes.is_empty(): break
					p.advance_exit_timers(10.0)
				result = []
				for event in p.route_log: result.append_array(event.results)
			elif str(edge.owner).begins_with("region:"): result = p.enter_region(int(str(edge.owner).get_slice(":",1)))
			else: result = p.use_exit(str(edge.owner))
			var verdict: Dictionary = {}
			for row in result:
				if int(row.group) == int(edge.group): verdict = row
			var record := {"id":edge.id,"area":area,"destination":edge.destination,"selector":edge.selector,
				"source_arrival":entry.selector,"verdict":verdict,"preparation":preparation,"arrival_adapters":p.seeds_applied.duplicate(true),"traversed":false}
			rows[edge.id] = record
			if p.level_changes.is_empty():
				print("BLOCKED ",edge.id," ",verdict.get("reasons",["No level change"]))
				continue
			var change: Dictionary = p.level_changes[0].duplicate()
			var matched := int(change.level)==int(edge.level) and int(change.selector)==int(edge.selector) and str(verdict.get("status",""))=="ran"
			# A native request can be refused by a story gate or held by a room movie.
			# This diagnostic reports the blocked edge; it must not seed that story or hang.
			var previous_id: int = scene.get_instance_id()
			for frame in 4:
				await process_frame
				if is_instance_valid(current_scene) and current_scene.get_instance_id() != previous_id: break
			if is_instance_valid(current_scene) and current_scene.get_instance_id() == previous_id:
				record["reason"] = "Native request did not change scene: story admission or presentation pending."
				print("BLOCKED ",edge.id," ",record.reason)
				continue
			var next = current_scene
			check(next != null and next.start_selector==int(change.selector),"actual destination selector " + str(edge.id))
			if next == null: continue
			next.set_physics_process(false)
			next.player.set_physics_process(false)
			if next.progression != null: next.progression.set_physics_process(false)
			await physics_frame
			var point: Vector3 = next.player.global_position
			var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*2,point-Vector3.UP*96,1)
			var hit: Dictionary = next.get_world_3d().direct_space_state.intersect_ray(ray)
			record["floor_contact"] = not hit.is_empty()
			check(not hit.is_empty(),"arrival floor within96 " + str(edge.id))
			if next.progression != null:
				next.progression._physics_process(0.016)
				check(next.progression.level_changes.is_empty(),"no arrival bounce " + str(edge.id))
			record.traversed = matched
			if not matched: record["reason"] = "A different native conditional edge ran in this arrival context."
			var destination := ""
			for name in graph.areas:
				if int(str(name).get_slice("_",0).trim_prefix("L"))==int(change.level): destination=str(name)
			if destination != "L4_HJ" and not destination.is_empty(): queue.append({"area":destination,"selector":int(change.selector)})
	var blocked: Array = rows.values().filter(func(row):return not bool(row.traversed))
	var complete := failures==0 and blocked.is_empty() and visited.size()==10
	var report := {"maps_complete":complete,"reachable_levels":visited.keys(),"arrival_contexts":states.keys(),"edges":rows.values(),
		"blocked_edges":blocked.size(),"failures":failures,"scope":"Native event graph with named, reversible arrival adapters; not a corridor walk or unadapted original parity."}
	var file := FileAccess.open("res://tmp/act2_travel_graph_report.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	check(rows.size()==graph.edges.size(),"every exit accounted for")
	if "--maps-complete" in OS.get_cmdline_user_args(): check(complete,"maps-complete gate: %d blocked edges" % blocked.size())
	if failures==0: print("PASS travel graph diagnostic; maps_complete=",complete," reached=",visited.size()," blocked=",blocked.size())
	quit(0 if failures==0 else 1)
