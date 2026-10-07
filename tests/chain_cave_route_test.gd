extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var scene = load("res://scenes/lol2/recovered_chain_cave_review.tscn").instantiate()
	root.add_child(scene)
	await physics_frame
	await physics_frame
	assert(scene.route_prop != null and scene.route_prop.get_meta("original_record") == 1056)
	assert(scene.route_prop.position.is_equal_approx(Vector3(1209, -209, -11730) / 64.0))
	assert(is_equal_approx(scene.route_prop.texture.get_width() * scene.route_prop.scale.x * scene.route_prop.pixel_size, 15.0 / 64.0))
	assert(is_equal_approx(scene.route_prop.texture.get_height() * scene.route_prop.scale.y * scene.route_prop.pixel_size, 12.0 / 64.0))
	for opened in [false, true]:
		scene._start_walk()
		assert(scene.walk_player.active)
		scene.walk_player.automated = true
		for i in range(30):
			await physics_frame
		if opened:
			assert(scene._strike_chain())
			for i in range(280):
				await physics_frame
		for door in scene.recovered_doors:
			assert(door.opening_percent == (100 if opened else 0))
		var blocked := false
		var route := [800, 837, 836, 835, 753, 752]
		if opened:
			route.append_array([753, 835, 836, 837, 800])
		for region in route:
			var target := Vector3.ZERO
			var found := false
			for face in scene.floor_faces:
				if int(face.region) == region:
					for p in face.points:
						target += Vector3(p[0], p[1], p[2]) / 4.0
					found = true
					break
			assert(found)
			var reached := false
			for tick in range(480):
				var offset: Vector3 = target - scene.walk_player.position
				if Vector2(offset.x, offset.z).length() < 0.12:
					reached = true
					break
				scene.walk_player.rotation.y = 0
				scene.walk_player.test_direction = Vector2(offset.x, offset.z).normalized()
				await physics_frame
			print("Route open=", opened, " region=", region, " reached=", reached)
			if not reached:
				blocked = true
				break
			assert(absf(scene.walk_player.position.y - target.y) < 0.1, "Route stays at source floor height")
		scene.walk_player.test_direction = Vector2.ZERO
		if blocked == opened:
			push_error("Expected closed route to block and open route to pass")
			scene.free()
			quit(1)
			return
		if opened:
			scene._reset_chain()
			for i in range(3):
				await physics_frame
			for door in scene.recovered_doors:
				assert(door.opening_percent == 0, "Doors close after player returns clear of doorway")
			assert(scene.short_sword_rule.remaining == 2 and not scene.chain_state.started)
			assert(scene._strike_chain(), "Chain can be triggered again after route reset")
			for i in range(280):
				await physics_frame
			for door in scene.recovered_doors:
				assert(door.opening_percent == 100)
			assert(scene.chain_state.door_dispatch_count == 1)
		scene._stop_walk()
	print("Chain cave route: closed blocking, source spawn, chain opening and grounded outbound/return route, reset and repeat opening passed")
	scene.free()
	quit()
