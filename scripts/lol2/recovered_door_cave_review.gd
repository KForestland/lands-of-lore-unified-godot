extends "res://scripts/lol2/original_floor_review.gd"
const Door = preload("res://scripts/lol2/recovered_door.gd")
var door_controls: VBoxContainer
var recovered_doors: Array[Node3D] = []

func _ready() -> void:
	super._ready()
	var motion: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/doors/motion.json"))
	var placement: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/doors/placement.json"))
	center = Vector3.ZERO
	for source in placement.placements:
		var record: Dictionary = {}
		for candidate in motion.doors:
			if int(candidate.index) == int(source.index):
				record = candidate
		assert(not record.is_empty())
		var door := Door.new()
		add_child(door)
		door.configure(record, 1.0 / 64.0)
		var p: Array = source.floor_review_position
		door.position = Vector3(p[0], p[1], p[2])
		# Motion data is X,height,+Y. Existing cave review is X,height,-Y.
		door.scale.z = -1.0
		recovered_doors.append(door)
		center += door.position
	center /= recovered_doors.size()
	center.y += 0.5
	radius = 4.0
	yaw = 0.8
	pitch = 0.35
	_update_camera()
	selection_label.text = "Original door placements — orbit/zoom to inspect.\nVisual integration only; door collision and chain trigger are pending."
	get_window().title = "Lands of Lore II — recovered doors in original cave"
	var ui := CanvasLayer.new()
	add_child(ui)
	var box := VBoxContainer.new()
	door_controls = box
	box.position = Vector2(24, 570)
	box.custom_minimum_size.x = 520
	ui.add_child(box)
	var opening := Label.new()
	opening.text = "Door opening: 0%"
	box.add_child(opening)
	var slider := HSlider.new()
	slider.max_value = 100
	slider.step = 1
	box.add_child(slider)
	slider.value_changed.connect(func(value: float) -> void:
		for door in recovered_doors:
			door.set_opening(int(value))
		opening.text = "Door opening: %d%%" % int(value))
	if "--door-placement-check" in OS.get_cmdline_user_args():
		var checks := 0
		for i in range(recovered_doors.size()):
			var door = recovered_doors[i]
			var source: Dictionary = placement.placements[i]
			var record: Dictionary = motion.doors[i]
			assert(door.original_record == int(record.index))
			for frame in [0, 50, 100]:
				door.set_opening(frame)
				for face in range(4):
					var surface: MeshInstance3D = door.get_child(face)
					var vertices: PackedVector3Array = surface.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
					var order := [0, 1, 2, 0, 2, 3]
					for v in range(6):
						var local: Array = record.frames[frame][face].vertices[order[v]]
						var anchor: Array = source.native_xyz
						var expected := Vector3(anchor[0] + local[0], anchor[2] + local[1], -anchor[1] - local[2]) / 64.0
						assert(surface.to_global(vertices[v]).is_equal_approx(expected))
						checks += 1
		print("Cave door placement: %d original world-vertex checks passed" % checks)
		get_tree().quit()
