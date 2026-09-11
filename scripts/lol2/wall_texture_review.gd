extends Node3D

const ROOT := "res://assets/lol2/generated/wall_review/"
var walls: Array = []
var selected := 0
var mesh_instance := MeshInstance3D.new()
var camera := Camera3D.new()
var label := Label.new()
var variant := 0
var frames := 0
var textures: Dictionary = {}

func _ready() -> void:
	add_child(mesh_instance)
	add_child(camera)
	camera.current = true
	camera.near = 0.1
	camera.far = 100000.0
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(label)
	label.position = Vector2(20, 20)
	if not FileAccess.file_exists(ROOT + "walls.json"):
		label.text = "Wall review assets missing. Run the diagnostic wall export first."
		if "--wall-smoke" in OS.get_cmdline_user_args():
			get_tree().quit(1)
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "walls.json"))
	walls = data["walls"]
	for wall in walls:
		var id := int(wall["descriptor"])
		if not textures.has(id):
			var variants: Array = []
			for v in range(int(wall.get("variant_count", 1))):
				var path := ROOT + "material_%d_variant_%d.png" % [id, v]
				if v == 0 and not FileAccess.file_exists(path):
					path = ROOT + "material_%d.png" % id
				var image := Image.load_from_file(path)
				if image == null or image.is_empty():
					push_error("Missing wall variant: " + path)
					get_tree().quit(1)
					return
				variants.append(ImageTexture.create_from_image(image))
			textures[id] = variants
	# Start with the original rock fixture rather than the unresolved photo material.
	for i in range(walls.size()):
		if int(walls[i]["record"]) == 2168:
			selected = i
			break
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--wall-id="):
			var requested := argument.trim_prefix("--wall-id=")
			var found := false
			if requested.is_valid_int():
				for i in range(walls.size()):
					if int(walls[i]["record"]) == int(requested):
						selected = i
						found = true
						break
			if not found:
				push_error("Wall ID not present in diagnostic export: " + requested)
				get_tree().quit(1)
				return
	if "--wall-smoke" in OS.get_cmdline_user_args():
		for i in range(walls.size()):
			selected = i
			for v in range(textures[int(walls[i]["descriptor"])].size()):
				variant = v
				show_wall()
		print("Wall review: %d meshes and %d textures loaded" % [walls.size(), textures.size()])
		get_tree().quit()
	else:
		show_wall()

func show_wall() -> void:
	var wall: Dictionary = walls[selected]
	var points := PackedVector3Array()
	var center := Vector3.ZERO
	for p in wall["points_godot"]:
		var point := Vector3(p[0], p[1], p[2])
		points.append(point)
		center += point / 4.0
	for i in range(4):
		points[i] -= center
	var uv := PackedVector2Array()
	for pair in wall["uv_unwrapped"]:
		uv.append(Vector2(pair[0], pair[1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = points
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh_instance.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = load("res://scripts/lol2/wall_review.gdshader")
	material.set_shader_parameter("wall_texture", textures[int(wall["descriptor"])][variant % textures[int(wall["descriptor"])].size()])
	material.set_shader_parameter("address_mode", int(wall.get("addressing", 8)))
	mesh_instance.material_override = material
	var edge := points[1] - points[0]
	var normal := Vector3(-edge.z, 0.0, edge.x).normalized()
	var extent := maxf(points[0].distance_to(points[1]), maxf(points[0].distance_to(points[3]), points[1].distance_to(points[2])))
	camera.position = normal * maxf(extent * 1.5, 10.0)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	label.text = "Diagnostic wall textures | N/P or arrows: next/previous\nWall %d | region %d | material %d | %d/%d\nOriginal palette, inferred UVs; lighting and transparency unverified." % [wall["record"], wall["region"], wall["descriptor"], selected + 1, walls.size()]
	label.text += "\nV: next stored variant | %d/%d (timing and layout unverified)" % [variant % textures[int(wall["descriptor"])].size() + 1, textures[int(wall["descriptor"])].size()]
	if int(wall["descriptor"]) == 3:
		label.text += "\nPHOTO/TEST MATERIAL: cave use unresolved."

func _unhandled_key_input(event: InputEvent) -> void:
	if walls.is_empty() or not event.is_pressed() or event.is_echo():
		return
	if event.keycode == KEY_V:
		variant += 1
		show_wall()
		return
	variant = 0
	if event.keycode in [KEY_N, KEY_RIGHT]:
		selected = (selected + 1) % walls.size()
	elif event.keycode in [KEY_P, KEY_LEFT]:
		selected = posmod(selected - 1, walls.size())
	else:
		return
	show_wall()

func _process(_delta: float) -> void:
	frames += 1
	if frames == 20 and "--wall-capture" in OS.get_cmdline_user_args():
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute("res://captures")
		get_viewport().get_texture().get_image().save_png("res://captures/wall_texture_review.png")
		get_tree().quit()
