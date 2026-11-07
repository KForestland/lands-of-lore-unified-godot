extends Node3D
## Source jungle geometry review. Not connected to the normal walkthrough.
const ROOT := "res://assets/lol2/generated/jungle_review/"
@export var geometry_file := ROOT + "jungle.json"
## Original L4_HJ panorama (tools/prepare_jungle_sky.py); the authored sky stays as the fallback and for other maps.
const JUNGLE_SKY := "res://assets/lol2/generated/jungle_sky/"
## The sky pack this scene uses (hosts of other areas point it at theirs, e.g. darker_jungle_sky for L8_SJ).
var sky_pack := JUNGLE_SKY
## Wall faces with no source wall record (no bound texture) stay collision but may be left undrawn.
## The original renders walls per wall record, so an edge without one shows nothing (Jungle: ~1385 faces).
## Original-bug row 9 (misclipped plasma bolts), map side: the Act 2/3 packs' source walls (kind "source_wall", drawn only for movement)
## also form a "ProjectileWalls" body on this layer, so a projectile mask that carries it stops at walls. No mover's mask carries it;
## the first Act 2 projectile host adds it to dawn_projectile_world's mask. Act 1 packs have no such faces and build no body.
const PROJECTILE_WALL_LAYER := 1 << 10
var projectile_wall_triangles := 0
var draw_unbound_walls := true
## Faces of kind "source_wall" (the Act 2/3 packs) are drawn only unless a host keeps them solid (the Dark Halls).
var source_wall_kind_collides := false
## The original portal renderer draws a region's walls only while looking into that region, so a wall is never seen from
## behind. When set, wall faces are wound to face their own region and drawn one-sided (floors stay two-sided).
var one_sided_walls := false
## Hooks for a host that lights its static faces per sector (darker_jungle.gd, L8 night): when vertex_light_enabled the static
## meshes carry static_face_light(face) in CUSTOM0 (RGBA float) and are listed in static_meshes. Defaults leave every mesh as before.
var vertex_light_enabled := false
var static_meshes: Array[MeshInstance3D] = []
## Optional portal-visibility batching (region_visibility.gd): region index -> cluster id. When set, static faces are
## batched per (material, cluster) and cluster_meshes lists each cluster's meshes; empty keeps the old batching.
var region_cluster: Dictionary = {}
var cluster_meshes: Dictionary = {}
var _cluster_material_cache: Dictionary = {}
## Mouse pitch clamp (radians); darker_jungle.gd limits it to the native panorama's range (DEVIATIONS 2026-10-31).
var pitch_limit := 1.4
## Floors whose source floor selector is 255 have no surface material (map_surfaces.py): when cleared they are not drawn
## (collision stays), instead of the neutral placeholder colour.
var draw_floorless := true
## With the original sky: boundary walls without a wall texture, floorless floors and a backing behind each cut-out
## boundary wall are drawn with the backdrop (backdrop.gdshader), so they show the panorama and hide what lies beyond.
var backdrop_edges := false
## Span materials kept one-sided: 744 is the flat palette-3 black of the imp pit (owner r10 reports 33/35, black blocks).
const ONE_SIDED_SPAN_MATERIALS := ["744"]
## Outer boundary walls without a wall record (Jungle: 54 visible ones; 57 more are zero-size) borrow the texture of the nearest
## textured outer wall, tiled at 2 texels per unit across and stretched over the wall height, instead of showing the
## backdrop at eye level. The original's frames show foliage there (owner 2026-10-24); a port fill, see DEVIATIONS.
## The same fill covers (owner r12h 2026-10-25, "transparent, can see the sky box"): outer walls whose cut-out texture
## has no opaque texel (Jungle material 469, 78 faces), interior step spans with no wall record, and floorless floors
## (source floor selector 255; all 49 Jungle ones are impassable), which take the nearest textured floor's material.
var fill_untextured_edges := false
## A region group that runs beneath another region's floor (Jungle: the 22-region river gorge under the south bank) is
## drawn only up to the top of its openings: the original portal walk reaches it only through those openings, so its
## walls never show above them (longplay 36:40-38:10). Collision is unchanged. See DEVIATIONS (2026-10-25).
var clip_sunken_groups := false
## Indoor areas: the original clears to black where no face is drawn (Hive longplay 40:00-43:52, 91:36-92:18: banners
## and floors in a black void), so the authored daylight sky is replaced by a black background.
var indoor_background := false
var backdrop_material: ShaderMaterial
@export var review_title := "Huline Jungle"
var player: CharacterBody3D
var camera: Camera3D
var start := Vector3.ZERO
var ready_for_review := false
var face_count := 0
var flying := false
var jump_requested := false
var resets := 0
var fall_reset_height := -2048.0
var development_mode := true
var development_overlay: CanvasLayer
var materials: Dictionary = {}
var dynamic_floor_regions: Array[int] = []
## Face indices of jungle.json drawn by a feature host instead (river dam walls).
var excluded_faces: Dictionary = {}
## Unbound span above the chopped-tree props (records 3268 and 3277). Jungle pack only.
const TREE_TOP_SKIP := 8631
## Faces dropped by small map fixes (not drawn, collision unchanged); kept apart from excluded_faces, which the river dam
## tests compare one to one with the dam's own walls.
var skipped_faces: Dictionary = {}
## Geometric spans retired by appended source walls (prepare_source_walls.py retired_static_wall_indices).
var retired_faces: Dictionary = {}
var surface_animation: Node
var walk_feel = preload("res://scripts/lol2/walk_feel.gd").new()

func _ready() -> void:
	# Authored replacement sky; source terrain colors stay unshaded.
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("487f9d")
	sky_material.sky_horizon_color = Color("c8d5c4")
	sky_material.ground_horizon_color = Color("c8d5c4")
	sky_material.ground_bottom_color = Color("69795e")
	sky_material.sky_curve = 0.18
	var sky := Sky.new()
	sky.sky_material = sky_material
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	add_child(world_environment)
	if (geometry_file == ROOT + "jungle.json" or sky_pack != JUNGLE_SKY) and FileAccess.file_exists(sky_pack + "environment.json"):
		_original_jungle_sky(world_environment)
	if indoor_background:
		environment.background_mode = Environment.BG_COLOR
		environment.background_color = Color.BLACK
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(geometry_file))
	start = Vector3(data.start[0], data.start[1], data.start[2])
	# Recovery must be below every authored floor, including the lower Hive.
	# The 512-unit void margin is an adapter, not native fall-damage behavior.
	for face in data.faces:
		if face.kind == "floor":
			for point in face.points:
				fall_reset_height = minf(fall_reset_height,float(point[1])-512.0)
	var groups: Dictionary = {}
	var collision := PackedVector3Array()
	var projectile_walls := PackedVector3Array()
	var centres: Dictionary = {}
	# Interior spans start where the producer says (prepare_source_walls.py appends the original's wall records and the
	# Jungle ceilings after them); older packs end with the spans.
	var span_start: int = int(data.get("interior_audit", {}).get("span_start", data.faces.size() - int(data.get("interior_audit", {}).get("span_count", 0))))
	# Geometric wall spans an appended source wall replaces (prepare_source_walls.py): neither drawn nor collision.
	for index in data.get("retired_static_wall_indices", []): retired_faces[int(index)] = true
	if geometry_file == ROOT + "jungle.json": skipped_faces[TREE_TOP_SKIP] = true
	var backdrop := SurfaceTool.new()
	backdrop.begin(Mesh.PRIMITIVE_TRIANGLES)
	if one_sided_walls or backdrop_material != null:
		for face in data.faces:
			if face.kind == "floor":
				var c := Vector3.ZERO
				for point in face.points: c += Vector3(point[0], point[1], point[2])
				centres[int(face.region)] = c / face.points.size()
	var fills := _edge_fills(data, span_start) if fill_untextured_edges else {}
	var clips := _sunken_clips(data, span_start) if clip_sunken_groups else {}
	for index in data.faces.size():
		var face: Dictionary = fills.get(index, data.faces[index])
		if not include_static_face(face) or excluded_faces.has(index) or retired_faces.has(index) or skipped_faces.has(index): continue
		var collision_kept := false
		if clips.has(index):
			if include_collision_face(face):
				for i in [0, 1, 2, 0, 2, 3]: collision.append(Vector3(face.points[i][0], face.points[i][1], face.points[i][2]))
			collision_kept = true
			face = _clipped(face, clips[index])
			if face.is_empty():
				face_count += 1
				continue
		var lip_top := _lip_top(index)
		if lip_top >= 0.0:
			if not collision_kept and include_collision_face(face):
				for i in [0, 1, 2, 0, 2, 3]: collision.append(Vector3(face.points[i][0], face.points[i][1], face.points[i][2]))
			face = _clipped(face, lip_top)
			if face.is_empty():
				face_count += 1
				continue
		var material_key: String = static_face_material(index, face)
		# Interior spans (steps and headers between connected regions) are seen from both sides (owner r12h 2026-10-26: one-sided
		# step faces left sky cracks along slope seams); boundary walls and the flat-black imp-pit material stay one-sided.
		# Appended source walls (the original's own records) face their region like boundary walls.
		var one_sided: bool = one_sided_walls and face.kind == "wall" and (index < span_start or material_key in ONE_SIDED_SPAN_MATERIALS or bool(face.get("source_wall", false)))
		var key: String = material_key + ("|wall" if one_sided else "")
		if not region_cluster.is_empty() and face.has("region") and face.region != null: key += "@%d" % int(region_cluster.get(int(face.region), -1))
		if backdrop_material != null:
			var boundary: bool = face.kind == "wall" and index < span_start
			var cutout: bool = face.has("material") and str(face.material) in data.get("alpha_cutout_materials", [])
			if (face.kind == "floor" and not face.has("material")) or (boundary and (not face.has("material") or cutout)):
				var points: Array = []
				var toward := Vector3.UP
				if face.kind == "wall": toward = _inward(face, centres)
				# A cut-out wall keeps its texture: the backdrop shader draws its backing just behind it.
				for point in face.points: points.append(Vector3(point[0], point[1], point[2]))
				for i in _winding(points, toward): backdrop.add_vertex(points[i])
			if boundary:
				# Seen from outside, a solid edge ends the original's portal walk: its back shows the backdrop too.
				var inward := _inward(face, centres)
				var back: Array = []
				# One unit longer at both ends so the backs of meeting walls overlap at corners.
				var along := Vector3(face.points[1][0] - face.points[0][0], 0, face.points[1][2] - face.points[0][2]).normalized()
				for i in face.points.size():
					var point: Array = face.points[i]
					back.append(Vector3(point[0], point[1], point[2]) + along * (1.0 if i in [1, 2] else -1.0))
				for i in _winding(back, -inward): backdrop.add_vertex(back[i])
		if not draw_floorless and face.kind == "floor" and not face.has("material"):
			for i in [0, 1, 2, 0, 2, 3]:
				var p: Array = face.points[i]
				if include_collision_face(face): collision.append(Vector3(p[0], p[1], p[2]))
			continue
		if not groups.has(key):
			var mat_key: String = key.get_slice("@", 0)
			var mat: StandardMaterial3D = _cluster_material_cache.get(mat_key)
			if mat != null:
				var shared := SurfaceTool.new()
				shared.begin(Mesh.PRIMITIVE_TRIANGLES)
				if vertex_light_enabled: shared.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
				shared.set_material(mat)
				groups[key] = shared
		if not groups.has(key):
			var mat := StandardMaterial3D.new()
			mat.cull_mode = BaseMaterial3D.CULL_BACK if one_sided else BaseMaterial3D.CULL_DISABLED
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			if data.materials.has(material_key):
				mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(geometry_file.get_base_dir() + "/" + data.materials[material_key]))
				if material_key in data.get("alpha_cutout_materials", []):
					mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
					mat.alpha_scissor_threshold = 0.5
			else:
				mat.albedo_color = Color(0.24, 0.32, 0.25) if material_key == "floor" else Color(0.32, 0.34, 0.31)
			if not materials.has(material_key): materials[material_key] = mat
			_cluster_material_cache[key.get_slice("@", 0)] = mat
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			if vertex_light_enabled: surface.set_custom_format(0, SurfaceTool.CUSTOM_RGBA_FLOAT)
			surface.set_material(mat)
			groups[key] = surface
		var surface: SurfaceTool = groups[key]
		var collides := include_collision_face(face) and not collision_kept
		var order := [0, 1, 2, 0, 2, 3]
		if one_sided and centres.has(int(face.region)):
			var points: Array = []
			for point in face.points: points.append(Vector3(point[0], point[1], point[2]))
			order = _winding(points, _inward(face, centres))
		for i in order:
			var p: Array = face.points[i]
			var vertex := Vector3(p[0], p[1], p[2])
			if face.has("uv"):
				surface.set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
			else:
				surface.set_uv(Vector2.ZERO)
			if vertex_light_enabled: surface.set_custom(0, static_face_light(face))
			surface.add_vertex(vertex)
		# Collision keeps the source triangle order (as before one-sided walls): the facing order above only orients
		# the drawn face. Reversed wall triangles changed Godot's one-sided contacts and stuck the departure walk.
		# Appended source walls (prepare_source_walls.py) are drawn only: the original's movement is region-based (bit0 blockers,
		# floors, ceilings), its wall records never block, and its hedges/veils stand on edges the player may cross (Hive
		# records 981/1223 across the small-form cavity, material 228). Collision stays with the geometric shell.
		# The Act 2/3 packs (darker_jungle, maps/AREA) carry the original's rendered wall records as kind "source_wall" with no
		# boolean (bind_surfaces); the same rule applies to them (2026-10-31, Astra's review of the L10 pack: until then those
		# walls collided while the Act 1 packs' did not).
		# The Dark Halls pack (dark_halls/area.json) uses the same kind but keeps its walls solid (source_wall_kind_collides): with
		# its bit0 blockers off (r12r workaround) they are its only walls; r12s dropped them and the detour walk went through walls.
		if collides and not (bool(face.get("source_wall", false)) or (face.kind == "source_wall" and not source_wall_kind_collides)):
			for i in [0, 1, 2, 0, 2, 3]: collision.append(Vector3(face.points[i][0], face.points[i][1], face.points[i][2]))
		elif face.kind == "source_wall":
			# Projectile walls (original-bug row 9, design 2026-10-31): the Act 2/3 packs' source walls never block movement, but a
			# bolt must not fly through them. They get their own layer, PROJECTILE_WALL_LAYER, which no mover's mask carries.
			for i in [0, 1, 2, 0, 2, 3]: projectile_walls.append(Vector3(face.points[i][0], face.points[i][1], face.points[i][2]))
		face_count += 1
	for key in groups:
		var surface: SurfaceTool = groups[key]
		if key.begins_with("wall") and not data.materials.has("wall") and not draw_unbound_walls: continue
		surface.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.mesh = surface.commit()
		add_child(mesh)
		static_meshes.append(mesh)
		if key.contains("@"):
			var cluster := int(key.get_slice("@", 1))
			if cluster >= 0:
				if not cluster_meshes.has(cluster): cluster_meshes[cluster] = []
				cluster_meshes[cluster].append(mesh)
	if backdrop_material != null:
		var backdrop_mesh := MeshInstance3D.new()
		backdrop_mesh.name = "Backdrop"
		backdrop.set_material(backdrop_material)
		backdrop_mesh.mesh = backdrop.commit()
		add_child(backdrop_mesh)
	if not data.get("animations", {}).is_empty():
		surface_animation = preload("res://scripts/lol2/surface_animation.gd").new()
		surface_animation.configure(materials, data.animations, geometry_file.get_base_dir() + "/")
		add_child(surface_animation)
	var body := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(collision)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	add_child(body)
	if not projectile_walls.is_empty():
		var wall_body := StaticBody3D.new()
		wall_body.name = "ProjectileWalls"
		wall_body.collision_layer = PROJECTILE_WALL_LAYER
		wall_body.collision_mask = 0
		var wall_shape := ConcavePolygonShape3D.new()
		wall_shape.backface_collision = true
		wall_shape.set_faces(projectile_walls)
		var wall_collider := CollisionShape3D.new()
		wall_collider.shape = wall_shape
		wall_body.add_child(wall_collider)
		add_child(wall_body)
		projectile_wall_triangles = projectile_walls.size() / 3
	player = CharacterBody3D.new()
	player.safe_margin = 0.05
	player.floor_snap_length = 4
	var capsule := CapsuleShape3D.new()
	capsule.radius = 8
	capsule.height = 64
	var player_shape := CollisionShape3D.new()
	player_shape.shape = capsule
	player.add_child(player_shape)
	add_child(player)
	camera = Camera3D.new()
	camera.position.y = 24
	camera.near = 0.5
	camera.far = 20000
	player.add_child(camera)
	camera.current = true
	reset_position()
	var canvas := CanvasLayer.new()
	development_overlay = canvas
	add_child(canvas)
	var label := Label.new()
	label.position = Vector2(16, 16)
	label.text = review_title + " — geometry review\nWASD: walk · Mouse: look · F: fly · R: reset · Esc: release mouse\nSource terrain and supported textures. Objects and gameplay pending."
	label.add_theme_color_override("font_shadow_color", Color.BLACK)
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	canvas.add_child(label)
	get_window().title = "Lands of Lore II — Jungle geometry review"
	if not "--jungle-test" in OS.get_cmdline_user_args(): Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ready_for_review = true

func set_development_mode(enabled: bool) -> void:
	development_mode = enabled
	if is_instance_valid(development_overlay): development_overlay.visible = enabled
	if not enabled:
		flying = false
		player.velocity = Vector3.ZERO

func reset_position() -> void:
	jump_requested = false
	player.position = start
	player.velocity = Vector3.ZERO
	# Temporary review direction; native heading conversion remains unverified.
	player.rotation = Vector3(0, -PI / 2, 0)
	camera.rotation = Vector3.ZERO
	flying = false

func _unhandled_input(event: InputEvent) -> void:
	if "--jungle-test" in OS.get_cmdline_user_args(): return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		player.rotate_y(-event.relative.x * 0.003)
		camera.rotation.x = clampf(camera.rotation.x - event.relative.y * 0.003, -pitch_limit, pitch_limit)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT: Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		if event.keycode == KEY_SPACE and request_jump():
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F3:
			set_development_mode(not development_mode)
			return
		if not development_mode: return
		if event.keycode == KEY_R: reset_position()
		if event.keycode == KEY_F:
			flying = not flying
			player.velocity = Vector3.ZERO

## Health 0 through the shared player health owner (player_starting_magic.health(); Museum/Jungle host health).
func player_fallen() -> bool:
	var magic = get("starting_magic")
	return magic != null and is_instance_valid(magic) and magic.has_method("health") and int(magic.health()) <= 0

func _physics_process(delta: float) -> void:
	if not ready_for_review: return
	var direction := Vector3.ZERO
	if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var axis := Vector3(float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)), 0, float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
		direction = (player.basis * axis).normalized()
		if flying: direction.y = float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL))
	# A fallen player ("You fell · R / F9") cannot walk; gravity still applies. R or F9 restores health and movement.
	if player_fallen(): direction = Vector3.ZERO
	if flying:
		player.position += direction * 160 * delta
		return
	move_grounded(direction,delta,Input.is_physical_key_pressed(KEY_SHIFT))

func _jump_input_active()->bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func request_jump() -> bool:
	if jump_requested or flying or get_tree().paused or not _jump_input_active() or not player.is_on_floor(): return false
	var warriors = get_node_or_null("Warriors")
	if warriors != null and warriors.health == 0: return false
	jump_requested = true
	return true

func jump_launch_speed(_sprint: bool = false) -> float: return 200.0

func move_grounded(direction: Vector3, delta: float, sprint: bool = false) -> void:
	# Shared by player input and bounded traversal acceptance tests.
	var speed: float = walk_feel.RUN_SPEED if sprint else walk_feel.WALK_SPEED
	var planar := walk_feel.velocity(Vector2(direction.x, direction.z) * speed, delta)
	player.velocity.x = planar.x
	player.velocity.z = planar.y
	var jumping := jump_requested and player.is_on_floor()
	jump_requested = false
	player.velocity.y = jump_launch_speed(sprint) if jumping else (0.0 if player.is_on_floor() else player.velocity.y - 320 * delta)
	if not jumping and player.velocity.y <= 0 and preload("res://scripts/lol2/walk_step.gd").try_step(player,Vector3(player.velocity.x,0,player.velocity.z)*delta):
		player.velocity.x = 0
		player.velocity.z = 0
	player.move_and_slide()
	walk_feel.bob(camera, Vector2(player.get_real_velocity().x, player.get_real_velocity().z).length(), player.is_on_floor(), delta)
	if player.position.y < fall_reset_height:
		resets += 1
		reset_position()

## Horizontal direction from a wall face into its own region (the side the original draws it from).
func _inward(face: Dictionary, centres: Dictionary) -> Vector3:
	var p0 := Vector3(face.points[0][0], face.points[0][1], face.points[0][2])
	var p1 := Vector3(face.points[1][0], face.points[1][1], face.points[1][2])
	var along := Vector3(p1.x - p0.x, 0, p1.z - p0.z).normalized()
	var normal := Vector3(-along.z, 0, along.x)
	if centres.has(int(face.region)) and normal.dot(centres[int(face.region)] - p0) < 0: normal = -normal
	return normal

## Triangle order for a quad whose front (Godot: clockwise, front normal -(p1-p0)x(p2-p0)) faces `toward`.
## Face index -> copy of an untextured outer boundary wall with the nearest textured outer wall's material and a tiled
## UV (2 texels per unit along the wall, the texture once over the wall height).
func _edge_fills(data: Dictionary, span_start: int) -> Dictionary:
	var clear := _clear_materials(data)
	var floor_low := {}
	var floor_donors: Array = []
	for face in data.faces:
		if face.kind != "floor": continue
		floor_low[int(face.region)] = minf(floor_low.get(int(face.region), INF), _lowest(face))
		if face.has("material"): floor_donors.append([_centre(face), str(face.material)])
	var donors: Array = []
	var span_donors: Array = []
	for index in data.faces.size():
		var face: Dictionary = data.faces[index]
		if face.kind == "wall" and face.has("material") and not clear.has(str(face.material)):
			(donors if index < span_start else span_donors).append([_middle(face), str(face.material)])
	span_donors.append_array(donors)
	var fills := {}
	for index in data.faces.size():
		var face: Dictionary = data.faces[index]
		if face.kind == "floor":
			if face.has("material") or floor_donors.is_empty(): continue
			var centre := _centre(face)
			var nearest: Array = floor_donors[0]
			for donor in floor_donors:
				if centre.distance_squared_to(donor[0]) < centre.distance_squared_to(nearest[0]): nearest = donor
			# Source floors map 64 world units to one texture repeat with u = -z, v = x (prepare_jungle_review.py).
			var floor_uv: Array = []
			for point in face.points: floor_uv.append([-float(point[2]) / 64.0, float(point[0]) / 64.0])
			var floor_fill := face.duplicate()
			floor_fill.material = nearest[1]
			floor_fill.uv = floor_uv
			floor_fill.edge_fill = true
			fills[index] = floor_fill
			continue
		if face.kind != "wall" or donors.is_empty(): continue
		if face.has("material") and not clear.has(str(face.material)): continue
		# Interior spans: only steps (the span starts at this region's floor); upper spans stay undrawn.
		if index >= span_start and (face.has("material") or absf(_lowest(face) - float(floor_low.get(int(face.region), INF))) > 1.0): continue
		var a := Vector2(face.points[0][0], face.points[0][2])
		var length := a.distance_to(Vector2(face.points[1][0], face.points[1][2]))
		var top := maxf(float(face.points[2][1]), float(face.points[3][1]))
		var height := top - minf(float(face.points[0][1]), float(face.points[1][1]))
		if length <= 0.0 or height <= 0.0: continue
		var middle := _middle(face)
		var pool: Array = donors if index < span_start else span_donors
		var best: Array = pool[0]
		for donor in pool:
			if middle.distance_squared_to(donor[0]) < middle.distance_squared_to(best[0]): best = donor
		var size: Vector2 = _material_size(data, best[1])
		var uv: Array = []
		for point in face.points:
			uv.append([a.distance_to(Vector2(point[0], point[2])) * 2.0 / size.x, (top - float(point[1])) / height])
		var fill := face.duplicate()
		fill.material = best[1]
		fill.uv = uv
		fill.edge_fill = true
		fills[index] = fill
	return fills

## Cut-out materials whose texture has no opaque texel draw nothing at all (Jungle 469: 16x16, fully clear).
func _clear_materials(data: Dictionary) -> Dictionary:
	var clear := {}
	for key in data.get("alpha_cutout_materials", []):
		if not data.materials.has(str(key)): continue
		var image := Image.load_from_file(geometry_file.get_base_dir() + "/" + data.materials[str(key)])
		image.convert(Image.FORMAT_RGBA8)
		var opaque := false
		for y in image.get_height():
			for x in image.get_width():
				if image.get_pixel(x, y).a >= 0.5:
					opaque = true
					break
			if opaque: break
		if not opaque: clear[str(key)] = true
	return clear

func _centre(face: Dictionary) -> Vector2:
	var c := Vector2.ZERO
	for point in face.points: c += Vector2(point[0], point[2])
	return c / face.points.size()

## Face index -> drawn top for the walls of region groups whose outer walls pass through another group's floor. Groups join regions
## across shared floor edges whose opening has no header wall above it; a group's drawn top is the highest header bottom
## of its openings to other groups.
func _sunken_clips(data: Dictionary, span_start: int) -> Dictionary:
	var floor_of := {}
	var edges := {}
	var pieces := {}
	var floors: Array = []
	for face in data.faces:
		if face.kind == "wall":
			var key := _edge_key(face.points[0], face.points[1])
			if not pieces.has(key): pieces[key] = []
			pieces[key].append(Vector2(_lowest(face), _highest(face)))
		elif face.kind == "floor":
			var region := int(face.region)
			floor_of[region] = minf(floor_of.get(region, INF), _lowest(face))
			floors.append(face)
			for i in face.points.size():
				var key := _edge_key(face.points[i], face.points[(i + 1) % face.points.size()])
				if not edges.has(key): edges[key] = {}
				edges[key][region] = true
	var parent := {}
	for key in edges:
		var regions: Array = edges[key].keys()
		if regions.size() > 1 and is_inf(_header(pieces.get(key, []), regions, floor_of)):
			for region in regions.slice(1): _union(parent, region, regions[0])
	var grid := {}
	for face in floors:
		var low := Vector2(INF, INF)
		var high := Vector2(-INF, -INF)
		for point in face.points:
			low = low.min(Vector2(point[0], point[2]))
			high = high.max(Vector2(point[0], point[2]))
		for gx in range(floori(low.x / 256.0), floori(high.x / 256.0) + 1):
			for gz in range(floori(low.y / 256.0), floori(high.y / 256.0) + 1):
				var cell := Vector2i(gx, gz)
				if not grid.has(cell): grid[cell] = []
				grid[cell].append(face)
	var sunken := {}
	for index in span_start:
		var face: Dictionary = data.faces[index]
		if face.kind != "wall": continue
		var group = _find(parent, int(face.region))
		if sunken.has(group): continue
		for t in [0.25, 0.5, 0.75]:
			var at := Vector2(lerpf(face.points[0][0], face.points[1][0], t), lerpf(face.points[0][2], face.points[1][2], t))
			for other in grid.get(Vector2i(floori(at.x / 256.0), floori(at.y / 256.0)), []):
				var height := _lowest(other)
				if _find(parent, int(other.region)) != group and height > _lowest(face) + 1.0 and height < _highest(face) - 1.0 \
						and Geometry2D.is_point_in_polygon(at, _outline(other)):
					sunken[group] = true
	var clips := {}
	for group in sunken:
		var top := -INF
		for key in edges:
			var regions: Array = edges[key].keys()
			var inside := regions.filter(func(region): return _find(parent, region) == group)
			if inside.is_empty() or inside.size() == regions.size(): continue
			top = maxf(top, _header(pieces.get(key, []), regions, floor_of))
		if is_inf(top): continue
		for index in data.faces.size():
			var face: Dictionary = data.faces[index]
			# A sunken group's ceilings (the gorge's black 744 lid at 400) lie above its drawn top as well: dropped like the wall parts.
			if (face.kind == "wall" or face.kind == "ceiling") and _find(parent, int(face.region)) == group and _highest(face) > top + 0.5: clips[index] = top
	return clips

## Bottom of the lowest wall piece above an edge's opening (INF: the opening has no header).
func _header(edge_pieces: Array, regions: Array, floor_of: Dictionary) -> float:
	var start := -INF
	for region in regions: start = maxf(start, floor_of[region])
	edge_pieces = edge_pieces.duplicate()
	edge_pieces.sort_custom(func(a, b): return a.x < b.x or (a.x == b.x and a.y < b.y))
	for piece in edge_pieces:
		if piece.x <= start + 1.0: start = maxf(start, piece.y)
	var header := INF
	for piece in edge_pieces:
		if piece.x > start + 1.0: header = minf(header, piece.x)
	return header

## The wall drawn from its bottom up to `top` (UVs cut to match); empty when nothing is left below `top`.
## Jungle sky lips (grok J09). 10239 clips at region 4408's ceiling (104). 9929 clips at region 3790's ceiling (64).
func _lip_top(index: int) -> float:
	if geometry_file.ends_with("L14_HT/area.json"):
		if index == 1810 or index == 9634 or index == 9656 or index == 9657 or index == 9670: return 110.0
		return -1.0
	if geometry_file != ROOT + "jungle.json": return -1.0
	if index == 10239: return 104.0
	if index == 9929: return 64.0
	return -1.0

func _clipped(face: Dictionary, top: float) -> Dictionary:
	if _lowest(face) >= top - 0.5: return {}
	var clipped := face.duplicate(true)
	# Wall quads run bottom a, bottom b, top b, top a.
	for pair in [[3, 0], [2, 1]]:
		var upper: Array = face.points[pair[0]]
		var lower: Array = face.points[pair[1]]
		if upper[1] <= top: continue
		var t: float = (top - lower[1]) / (upper[1] - lower[1])
		clipped.points[pair[0]] = [upper[0], top, upper[2]]
		if face.has("uv"):
			clipped.uv[pair[0]] = [lerpf(face.uv[pair[1]][0], face.uv[pair[0]][0], t), lerpf(face.uv[pair[1]][1], face.uv[pair[0]][1], t)]
	return clipped

func _edge_key(a: Array, b: Array) -> String:
	var p := Vector2i(roundi(a[0]), roundi(a[2]))
	var q := Vector2i(roundi(b[0]), roundi(b[2]))
	return "%s|%s" % ([p, q] if p < q else [q, p])

func _lowest(face: Dictionary) -> float:
	var low := INF
	for point in face.points: low = minf(low, point[1])
	return low

func _highest(face: Dictionary) -> float:
	var high := -INF
	for point in face.points: high = maxf(high, point[1])
	return high

func _outline(face: Dictionary) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for point in face.points: outline.append(Vector2(point[0], point[2]))
	return outline

func _find(parent: Dictionary, region: int) -> int:
	while parent.get(region, region) != region: region = parent[region]
	return region

func _union(parent: Dictionary, a: int, b: int) -> void:
	var ra := _find(parent, a)
	var rb := _find(parent, b)
	if ra != rb: parent[ra] = rb

func _middle(face: Dictionary) -> Vector2:
	return Vector2(face.points[0][0] + face.points[1][0], face.points[0][2] + face.points[1][2]) * 0.5

var _material_sizes := {}
func _material_size(data: Dictionary, key: String) -> Vector2:
	if not _material_sizes.has(key):
		var image := Image.load_from_file(geometry_file.get_base_dir() + "/" + data.materials[key])
		_material_sizes[key] = Vector2(image.get_width(), image.get_height())
	return _material_sizes[key]

func _winding(points: Array, toward: Vector3) -> Array:
	var cross: Vector3 = (points[1] - points[0]).cross(points[2] - points[0])
	return [0, 2, 1, 0, 3, 2] if cross.dot(toward) > 0 else [0, 1, 2, 0, 2, 3]

## Drawn faces that also collide; Dark Halls leaves its object faces out (dark_halls.gd).
## The material key a static face is drawn with; hosts override it for witnessed adapters (dark_halls.gd garden bed).
## Per-face light for a vertex_light_enabled host (CUSTOM0): [ambient, fade start, span, multiplier]; full-bright by default.
func static_face_light(_face: Dictionary) -> Color:
	return Color(63, 9999, 9999, 128)

func static_face_material(_index: int, face: Dictionary) -> String:
	return face.get("material", face.kind)

func include_collision_face(_face: Dictionary) -> bool:
	return true

func include_static_face(face: Dictionary) -> bool:
	return not (face.kind == "floor" and int(face.region) in dynamic_floor_regions)

## The Cave sky recipe (indexed_cave_wall_review.gd) on the Jungle panorama: the original jungle and mountains show
## through the transparent map-edge walls (material 469) instead of the authored sky's flat ground.
func _original_jungle_sky(world_environment: WorldEnvironment) -> void:
	var metadata: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(sky_pack + "environment.json"))
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://scripts/lol2/all_maps_sky.gdshader")
	sky_material.set_shader_parameter("panorama", ImageTexture.create_from_image(Image.load_from_file(sky_pack + "panorama.png")))
	sky_material.set_shader_parameter("panorama_indices", ImageTexture.create_from_image(Image.load_from_file(sky_pack + "panorama_indices.png")))
	sky_material.set_shader_parameter("native_projection", true)
	sky_material.set_shader_parameter("vertical_origin", float(metadata.panorama.vertical_origin))
	world_environment.environment.sky.sky_material = sky_material
	world_environment.name = "JungleSkyEnvironment"
	var controller = preload("res://scripts/lol2/map_sky_controller.gd").new()
	controller.environment_path = NodePath("../JungleSkyEnvironment")
	if backdrop_edges:
		backdrop_material = ShaderMaterial.new()
		backdrop_material.shader = preload("res://scripts/lol2/backdrop.gdshader")
		for key in ["panorama", "panorama_indices", "vertical_origin"]:
			backdrop_material.set_shader_parameter(key, sky_material.get_shader_parameter(key))
		controller.mirrors.append(backdrop_material)
	add_child(controller)
