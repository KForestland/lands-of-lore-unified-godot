extends Node3D
# Hypothetical capsule: radius 8, total height 64 in original coordinate units.
func point(p: Array) -> Vector3:
	return Vector3(p[0], p[1], p[2])
func _ready() -> void:
	var gravity_motion := "--gravity-motion" in OS.get_cmdline_user_args()
	var expanded := "--expanded" in OS.get_cmdline_user_args()
	var include_shell := "--shell" in OS.get_cmdline_user_args()
	var source := "traversal_expanded.json" if expanded else "traversal_fixtures.json"
	var fixtures = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/original_floors/" + source))
	var missing_floor: Dictionary = fixtures[0].duplicate(true)
	missing_floor.faces = []
	missing_floor.shell = []
	missing_floor.kind = "missing-floor control"
	fixtures.append(missing_floor)
	if include_shell:
		var wall_control: Dictionary = fixtures[0].duplicate(true)
		wall_control.kind = "synthetic blocking wall control"
		var direction := point(wall_control.end) - point(wall_control.start)
		direction.y = 0
		var tangent := direction.normalized().cross(Vector3.UP) * 1000.0
		wall_control.shell.append([[tangent.x, -10, tangent.z], [-tangent.x, -10, -tangent.z], [-tangent.x, 128, -tangent.z], [tangent.x, 128, tangent.z]])
		wall_control.expected_pass = false
		fixtures.append(wall_control)
		var ceiling_control: Dictionary = fixtures[0].duplicate(true)
		ceiling_control.kind = "synthetic low ceiling control"
		for face in ceiling_control.faces:
			var roof: Array = []
			for p in face: roof.append([p[0], p[1] + 32, p[2]])
			ceiling_control.shell.append(roof)
		ceiling_control.expected_pass = false
		fixtures.append(ceiling_control)
	var results: Array = []
	for fixture in fixtures:
		for reverse in [false, true]:
			var stage := Node3D.new()
			add_child(stage)
			var body := StaticBody3D.new()
			var collision := CollisionShape3D.new()
			var shape := ConcavePolygonShape3D.new()
			shape.backface_collision = true
			var triangles := PackedVector3Array()
			var collision_faces: Array = fixture.faces.duplicate()
			if include_shell: collision_faces.append_array(fixture.shell)
			for face in collision_faces:
				for index in [0, 1, 2, 0, 2, 3]: triangles.append(point(face[index]))
			if not triangles.is_empty(): shape.set_faces(triangles)
			collision.shape = shape
			body.add_child(collision)
			if not triangles.is_empty(): stage.add_child(body)
			else: body.free()
			var player := CharacterBody3D.new()
			player.safe_margin = 0.05
			player.floor_snap_length = 4.0
			var capsule := CapsuleShape3D.new()
			capsule.radius = 8.0
			capsule.height = 64.0
			var player_shape := CollisionShape3D.new()
			player_shape.shape = capsule
			player.add_child(player_shape)
			stage.add_child(player)
			var start := point(fixture.end if reverse else fixture.start)
			var target := point(fixture.start if reverse else fixture.end)
			player.position = start + Vector3.UP * 34.0
			await get_tree().physics_frame
			var overlap_query := PhysicsShapeQueryParameters3D.new()
			var inner_capsule := CapsuleShape3D.new()
			inner_capsule.radius = 7.9
			inner_capsule.height = 63.8
			overlap_query.shape = inner_capsule
			overlap_query.transform = player.global_transform
			overlap_query.exclude = [player.get_rid()]
			var initial_overlap := not get_world_3d().direct_space_state.intersect_shape(overlap_query).is_empty()
			var settled := false
			for frame in range(60):
				await get_tree().physics_frame
				player.velocity = Vector3.DOWN * 64.0
				player.move_and_slide()
				if player.is_on_floor(): settled = true; break
			var reached := false
			var airborne := 0
			for frame in range(180):
				await get_tree().physics_frame
				var delta := target - player.position
				delta.y = 0
				if delta.length() < 1.0: reached = true; break
				var vertical := -64.0
				if gravity_motion:
					vertical = 0.0 if player.is_on_floor() else player.velocity.y - 128.0 * get_physics_process_delta_time()
				player.velocity = delta.normalized() * 32.0 + Vector3.UP * vertical
				player.move_and_slide()
				if not player.is_on_floor(): airborne += 1
			var passed := settled and reached and airborne == 0 and not initial_overlap
			results.append({"regions": fixture.regions, "kind": fixture.kind, "reverse": reverse, "initial_overlap": initial_overlap, "settled": settled, "reached": reached, "airborne_frames": airborne, "passed": passed, "expected_pass": fixture.get("expected_pass", not fixture.faces.is_empty()), "final_position": [player.position.x, player.position.y, player.position.z]})
			stage.queue_free()
			await get_tree().physics_frame
	var failures := 0
	for result in results:
		if result.passed != result.expected_pass: failures += 1
	var report := {"gravity_motion": gravity_motion, "expanded": expanded, "include_shell": include_shell, "scope": "Isolated continuous floor pairs, locally centered original units; hypothetical capsule radius 8 height 64; optional provisional boundary walls and ceilings; no native movement parity.", "results": results, "failures": failures}
	var suffix := ("_expanded" if expanded else "") + ("_shell" if include_shell else "") + ("_gravity" if gravity_motion else "")
	var file := FileAccess.open("res://captures/capsule_traversal_audit" + suffix + ".json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("Capsule traversal: ", results.size(), " routes, ", failures, " failures")
	get_tree().quit(0 if failures == 0 else 1)
