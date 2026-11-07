extends SceneTree
## Static assembly presence (shared helper for the Jungle causeway and plank hosts): placement flags bit 0x1000 marks an
## assembly absent at load; set_present() links/unlinks a managed assembly in drawing and in its solid body; the presence
## set saves and restores. Jungle L4_HJ: controls 61/62 (template79) and 211 (template22) are placed absent, 84 present.
func _initialize() -> void: run.call_deferred()
func fail(message: String) -> void:
	push_error(message); print("FAIL static_assembly_presence: ", message); quit(1)

func visible(assemblies: Node, id: int) -> bool:
	var meshes: Array = assemblies.stateful_meshes.get(id, [])
	if meshes.is_empty(): return false
	for mesh in meshes:
		if not mesh.visible: return false
	return true

func run() -> void:
	var host := Node3D.new(); root.add_child(host)
	var assemblies = preload("res://scripts/lol2/static_assemblies.gd").new(); host.add_child(assemblies)
	var error: String = assemblies.setup(host, "L4_HJ", [], [], [61, 62, 84, 211])
	if not error.is_empty(): return fail(error)
	for id in [61, 62, 211]:
		if assemblies.is_present(id) or visible(assemblies, id): return fail("Assembly %d should start absent" % id)
	if not assemblies.is_present(84) or not visible(assemblies, 84): return fail("Assembly 84 should start present")
	if not assemblies.add_scripted_solids("L4_HJ", [84]).is_empty(): return fail("84 solid not built")
	var solid: StaticBody3D = assemblies.solid_bodies[84]
	if solid.collision_layer != assemblies.SCENERY_LAYER: return fail("84 solid not colliding while present")
	assemblies.set_present(84, false)
	assemblies.set_present(61, true)
	if visible(assemblies, 84) or solid.collision_layer != 0: return fail("Unlinked 84 still drawn or solid")
	if not visible(assemblies, 61): return fail("Linked 61 not drawn")
	assemblies.set_mode(61, 0)
	if not visible(assemblies, 61): return fail("set_mode lost the presence of 61")
	var saved: Dictionary = assemblies.presence_state()
	if saved != {"61": true, "62": false, "84": false, "211": false}: return fail("Presence state %s" % saved)
	var fresh = preload("res://scripts/lol2/static_assemblies.gd").new(); host.add_child(fresh)
	fresh.setup(host, "L4_HJ", [], [], [61, 62, 84, 211])
	fresh.add_scripted_solids("L4_HJ", [84])
	if not fresh.restore_presence(saved).is_empty(): return fail("Restore refused")
	if fresh.presence_state() != saved or fresh.solid_bodies[84].collision_layer != 0 or not visible(fresh, 61): return fail("Restore did not apply")
	if fresh.restore_presence({"61": true}).is_empty() or fresh.restore_presence({"61": 1, "62": false, "84": false, "211": false}).is_empty():
		return fail("Malformed presence accepted")
	if fresh.presence_state() != saved: return fail("Malformed restore changed presence")
	print("PASS static_assembly_presence: 61/62/211 absent at load, 84 present; link/unlink drives meshes and solid; save/restore round trip")
	quit(0)
