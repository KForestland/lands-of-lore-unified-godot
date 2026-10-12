extends Node3D
## Recovered geometry with authored collapse animation; chain rules remain unbound.
var sections: Dictionary = {}
var chain_rule = preload("res://scripts/lol2/river_chain_rule.gd").new()
var host: Node3D
const FALL_SECONDS := 0.7
func setup(walkthrough: Node3D) -> void:
	host = walkthrough
	var source = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/river_deck/deck.json"))
	for record in source.records:
		var b: Array = record.bounds_xyz
		var p: Array = record.native_xyz
		assert(int(record.heading) == 0)
		var dimensions := Vector3(b[1]-b[0], b[5]-b[4], b[3]-b[2])
		var center: Vector3 = Vector3(p[0]+(b[0]+b[1])/2.0, p[2]+(b[4]+b[5])/2.0, -p[1]-(b[2]+b[3])/2.0) + host.native_translation
		var mesh := MeshInstance3D.new()
		mesh.name = "RiverDeck%d" % int(record.index)
		var box := BoxMesh.new()
		box.size = dimensions
		mesh.mesh = box
		mesh.position = center
		mesh.layers = 2
		mesh.material_override = host._indexed_material("res://assets/lol2/river_deck/indices_86.png")
		add_child(mesh)
		host._copy_occluders(mesh)
		var body := StaticBody3D.new()
		body.position = center
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var bounds := BoxShape3D.new()
		bounds.size = dimensions
		shape.shape = bounds
		body.add_child(shape)
		add_child(body)

		sections[int(record.index)] = {"mesh": mesh, "body": body, "start": center, "elapsed": -1.0}

func begin_collapse(record: int) -> bool:
	if not sections.has(record) or sections[record].elapsed >= 0.0: return false
	sections[record].elapsed = 0.0
	# The section stops supporting actors as it falls; water damage is separate.
	sections[record].body.collision_layer = 0
	return true

func _physics_process(delta: float) -> void:
	for section in sections.values():
		if section.elapsed < 0.0: continue
		section.elapsed = minf(FALL_SECONDS, section.elapsed + delta)
		var fraction: float = section.elapsed / FALL_SECONDS
		section.mesh.position = section.start + Vector3.DOWN * (120.0 * fraction * fraction)
		section.mesh.visible = fraction < 1.0
		for pair in host.occluder_pairs + host.light_pairs:
			if pair[0] == section.mesh:
				pair[1].global_transform = section.mesh.global_transform
				pair[1].visible = section.mesh.visible

func cut_chain(prop: int) -> bool:
	var section: int = chain_rule.cut_chain(prop)
	return begin_collapse(section) if section >= 0 else false
