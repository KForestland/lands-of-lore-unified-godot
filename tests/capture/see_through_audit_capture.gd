extends SceneTree
## See-through audit (owner r12h report 2026-10-25: "textures transparent, can see the sky box"). Not a registered test.
##   python3 ~/opus_work/ai_tools/godot_capture.py --project . --out OUT --godot flatpak run org.godotengine.Godot \
##     --script res://tests/capture/see_through_audit_capture.gd -- SCENE GEOMETRY_JSON COUNT TAG
## For COUNT textured floor regions spread over the area it stands the camera at eye height and takes 8 headings at
## pitch 0, twice: "n" as rendered, and "d" with the sky background magenta and every backdrop.gdshader face cyan.
## Magenta below the horizon = nothing drawn there; cyan below the horizon = panorama painted on a surface.
const EYE := 42.0
const MAGENTA := Color(1, 0, 1)
const CYAN := Color(0, 1, 1)

func _initialize() -> void: run.call_deferred()

func meshes(node: Node, out: Array) -> void:
	if node is MeshInstance3D: out.append(node)
	for child in node.get_children(): meshes(child, out)

func run() -> void:
	var args := OS.get_cmdline_user_args()
	var scene_path: String = args[0]
	var geometry_path: String = args[1]
	var count := int(args[2])
	var tag: String = args[3]
	DirAccess.make_dir_recursive_absolute("user://capture")
	get_root().size = Vector2i(640, 360)
	var owner_poses: Array = []
	if geometry_path.ends_with("poses.json"):
		owner_poses = JSON.parse_string(FileAccess.get_file_as_string(geometry_path))
	var data: Dictionary = {} if not owner_poses.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(geometry_path))
	var centres: Array = []
	for face in data.get("faces", []):
		if face.kind != "floor" or not face.has("material"): continue
		var c := Vector3.ZERO
		for p in face.points: c += Vector3(p[0], p[1], p[2])
		centres.append(c / face.points.size())
	var picks: Array = []
	var step := maxf(1.0, float(centres.size()) / float(count))
	for i in count:
		var k := int(i * step)
		if k < centres.size(): picks.append(centres[k])
	var scene = load(scene_path).instantiate()
	root.add_child(scene); current_scene = scene
	for i in 1500:
		await process_frame
		if scene.get("ready_for_review"): break
	for i in 30: await physics_frame
	var player: Node3D = scene.get("player")
	var camera: Camera3D = get_root().get_camera_3d()
	if player: player.process_mode = Node.PROCESS_MODE_DISABLED
	var log := FileAccess.open("user://capture/%s_poses.json" % tag, FileAccess.WRITE)
	var poses: Array = []
	for pass_name in ["n", "d"]:
		if pass_name == "d":
			var environments: Array = []
			for env in scene.find_children("*", "WorldEnvironment", true, false): environments.append(env.environment)
			if camera.environment: environments.append(camera.environment)
			for environment in environments:
				environment.background_mode = Environment.BG_COLOR
				environment.background_color = MAGENTA
			var cyan := ShaderMaterial.new()
			cyan.shader = load("res://tests/capture/backdrop_debug.gdshader")
			var all: Array = []
			meshes(scene, all)
			for m in all:
				var mi: MeshInstance3D = m
				if mi.mesh == null: continue
				for s in mi.mesh.get_surface_count():
					var mat = mi.get_active_material(s)
					if mat is ShaderMaterial and mat.shader and mat.shader.resource_path.ends_with("backdrop.gdshader"):
						mi.set_surface_override_material(s, cyan)
		var views := owner_poses.size() if not owner_poses.is_empty() else picks.size()
		for i in views:
			var at: Vector3 = picks[i] + Vector3(0, EYE, 0) if owner_poses.is_empty() else Vector3(owner_poses[i].pos[0], owner_poses[i].pos[1], owner_poses[i].pos[2])
			# Pose files in source map coordinates ("native": true, e.g. creature_nav) take the scene's map offset (Cave).
			if not owner_poses.is_empty() and owner_poses[i].get("native", false) and scene.get("native_translation") != null: at += scene.native_translation
			for h in (8 if owner_poses.is_empty() else 1):
				var yaw: float = h * PI / 4.0 if owner_poses.is_empty() else float(owner_poses[i].rot[1])
				var pitch: float = 0.0 if owner_poses.is_empty() else float(owner_poses[i].rot[0])
				if player:
					player.global_position = at - (camera.global_position - player.global_position)
					player.rotation.y = yaw
					camera.rotation.x = pitch
				else:
					camera.global_position = at
					camera.rotation = Vector3(pitch, yaw, 0)
				for f in 4: await process_frame
				get_root().get_texture().get_image().save_png("user://capture/%s_%03d_%d_%s.png" % [tag, i, h, pass_name])
				if pass_name == "n": poses.append({"i": i, "h": h, "camera": [camera.global_position.x, camera.global_position.y, camera.global_position.z], "yaw": yaw})
	log.store_string(JSON.stringify(poses))
	log.close()
	print("see_through_audit %s: %d poses" % [tag, poses.size()])
	quit(0)
