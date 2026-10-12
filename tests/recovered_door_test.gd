extends SceneTree
const Door = preload("res://scripts/lol2/recovered_door.gd")
func _initialize() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/doors/motion.json"))
	var checks := 0
	for record in data.doors:
		var door := Door.new()
		root.add_child(door)
		for factor in [1.0, 0.025]:
			door.configure(record, factor)
			assert(door.original_record == int(record.index))
			for frame in [0, 50, 100]:
				door.set_opening(frame)
				for face in range(4):
					var mesh: ArrayMesh = door.get_child(face).mesh
					var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
					var order := [0, 1, 2, 0, 2, 3]
					for i in range(6):
						var p: Array = record.frames[frame][face].vertices[order[i]]
						assert(vertices[i].is_equal_approx(Vector3(p[0], p[1], p[2]) * factor))
						checks += 1
			door.set_opening(0)
			var initial: ArrayMesh = door.get_child(0).mesh
			door.set_opening(100)
			door.set_opening(-10)
			assert(door.opening_percent == 0 and door.get_child(0).mesh == initial)
			door.set_opening(110)
			assert(door.opening_percent == 100)
			assert(door.get_child_count() == 4)
			checks += 3
		door.free()
	print("Recovered door component: %d geometry/scale/reset/cache checks passed" % checks)
	quit()
