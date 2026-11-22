extends SceneTree
## OF3. L10 assembly 70 is the cemetery gate. Material 304 is the mechanism on a clear
## field. The presenter used to draw that field, so the gate was a black slab.
class GateHost extends Node3D:
	var geometry_file := ""
	var quest_state: Dictionary = {}
	var flying := false
	var progression: Node = null
	var camera: Camera3D
	var player: CharacterBody3D

func _initialize() -> void:
	run.call_deferred()

func fail(message: String) -> void:
	push_error(message)
	print("FAIL gate cutout: ", message)
	quit(1)

func run() -> void:
	var host := GateHost.new()
	host.geometry_file = "res://assets/lol2/generated/maps/L10_DC/area.json"
	host.player = CharacterBody3D.new()
	host.camera = Camera3D.new()
	host.player.add_child(host.camera)
	host.add_child(host.player)
	root.add_child(host)
	var gate: Node3D = load("res://scripts/lol2/l10_main_gate.gd").attach(host)
	await process_frame
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
	var cutouts: Dictionary = {}
	for id in pack.alpha_cutout_materials:
		cutouts[str(id)] = true
	var meshes: Array[MeshInstance3D] = []
	for child in gate.get_node("SigilPanel").get_children():
		if child is MeshInstance3D:
			meshes.append(child)
	var index := 0
	var cut := 0
	var solid := 0
	for face in pack.faces:
		if str(face.get("placement_kind", "")) != "static_assembly" or int(face.get("source_index", -1)) != 70:
			continue
		if index >= meshes.size():
			fail("Assembly 70 has more faces than meshes")
			return
		var mat: StandardMaterial3D = meshes[index].material_override as StandardMaterial3D
		index += 1
		var want: bool = cutouts.has(str(face.material))
		var got: bool = mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		if want != got:
			fail("Material %s cut-out %s drawn %s" % [str(face.material), want, got])
			return
		if want:
			cut += 1
		else:
			solid += 1
	if cut == 0 or solid == 0:
		fail("Expected both cut-out and solid faces, saw %d and %d" % [cut, solid])
		return
	if not cutouts.has("304"):
		fail("Material 304 is not on the pack cut-out list")
		return
	host.queue_free()
	await process_frame
	print("PASS gate cutout: assembly 70 draws cut-out %d and solid %d" % [cut, solid])
	quit(0)
