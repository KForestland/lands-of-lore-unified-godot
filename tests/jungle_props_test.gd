extends SceneTree
## Huline Jungle sprite props (prepare_jungle_props.py) and scenery assemblies: the walkthrough draws every staged prop
## once (5830 billboards, 68 batches; 5904 before tools/lol2/map_props.py stopped hosting the 75 placements whose region
## word is 65535 and that no region contains, 2026-10-30), none of them a scripted prop that a feature host owns (oil pool 1350 and its
## flames), and the L4_HJ static assemblies with their native solid boxes.
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> bool:
	push_error(message); print("FAIL jungle_props: ", message); quit(1); return false
func run() -> void:
	change_scene_to_file("res://scenes/lol2/jungle_walkthrough.tscn")
	for i in range(1500):
		await process_frame
		if current_scene != null and current_scene.get("ready_for_review"): break
	var scene = current_scene
	if scene == null or not scene.get("ready_for_review"): return fail("Jungle not ready")
	var props = scene.props
	if props == null or props.instance_count != 5830 or props.get_child_count() != 68: return fail("Props not drawn: %s" % [props.instance_count if props else -1])
	var owned: Array = [1350]
	for f in scene.oil_fire.source.flames: owned.append(int(f.prop))
	for group in props.data.groups:
		for row in group.instances:
			if int(row[3]) in owned: return fail("Host-owned prop %d drawn twice" % int(row[3]))
	var sa = scene.static_assemblies
	if sa == null or str(sa.data.area) != "L4_HJ" or sa.data.drawn.size() != 171 or sa.solid_bodies.size() != 54 + scene.JUNGLE_BRIDGE.size() + (scene.causeway.src.unlink.size() if scene.get("causeway") != null else 0): return fail("L4 scenery assemblies/boxes missing")
	print("PASS jungle_props: 5830 sprite props in 68 batches, no host-owned prop drawn twice, 171 L4 scenery assemblies with 53 native solid boxes")
	quit(0)
