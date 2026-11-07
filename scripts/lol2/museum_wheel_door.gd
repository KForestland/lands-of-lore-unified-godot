extends Node3D
## Museum wheel door = static assembly / control80 behind the curtain (docs/museum-wheel-door.md). Template61 child151
## is a 12 x 70 x 85 box across the doorway; its west face is the resource138 phase group (marble -> vortex ->
## transparent). Empty-hand use (kind4 value0, g7008): op7 plays the group + sound342. End of the group (kind6 value2,
## g7030): op9 property2 unlinks the assembly, opening the passage. Saved as "museum_wheel_door".
const SOURCE := "res://scripts/lol2/museum_wheel_door_source.json"
## Adapter: the op7 clock is not replayed; 15 frames/s measured from the longplay (40 frames in about 2.7 s).
const FPS := 15.0
const FRAMES := 40
const WEST_FACE := 3

var host: Node3D
var src: Dictionary = {}
## 0 linked (closed), 1 playing, 2 unlinked (open).
var state := 0
var clock := 0.0
var wheel_material: StandardMaterial3D
var frames: Array[ImageTexture] = []
var body: StaticBody3D
var voice: AudioStreamPlayer3D
var box_min := Vector3.INF
var box_max := -Vector3.INF

static func source() -> Dictionary:
	var data = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	return data if data is Dictionary else {}

static func assets_ready() -> bool:
	var data := source()
	if data.is_empty(): return false
	for file in data.images:
		if FileAccess.get_sha256(str(data.root) + file) != str(data.images[file]): return false
	for id in data.audio:
		if FileAccess.get_sha256(data.audio[id].path) != str(data.audio[id].wav_sha256): return false
	return true

static func initial() -> Dictionary:
	return {"version":1, "state":0, "clock":0.0}

static func validate(saved: Variant) -> String:
	if not saved is Dictionary or saved.size() != 3 or not saved.has_all(["version", "state", "clock"]): return "Invalid wheel door state."
	for key in ["version", "state"]:
		if not (saved[key] is int or saved[key] is float) or float(saved[key]) != floorf(float(saved[key])): return "Invalid wheel door state."
	if int(saved.version) != 1 or not int(saved.state) in [0, 1, 2]: return "Invalid wheel door state."
	if not (saved.clock is int or saved.clock is float) or not is_finite(float(saved.clock)): return "Invalid wheel door state."
	if float(saved.clock) < 0 or float(saved.clock) >= FRAMES / FPS or (int(saved.state) != 1 and float(saved.clock) != 0.0): return "Invalid wheel door state."
	return ""

func setup(owner_host: Node3D, saved: Variant) -> String:
	host = owner_host
	name = "MuseumWheelDoor80"
	src = source()
	if src.is_empty(): return "Wheel door source missing."
	for file in src.frames:
		frames.append(ImageTexture.create_from_image(Image.load_from_file(str(src.root) + file)))
	for p in src.faces[0].points + src.faces[1].points:
		var v := Vector3(p[0], p[1], p[2])
		box_min = box_min.min(v)
		box_max = box_max.max(v)
	var centre := (box_min + box_max) / 2.0
	var by_resource: Dictionary = {}
	for face in src.faces:
		var key := int(face.resource)
		if not by_resource.has(key): by_resource[key] = []
		by_resource[key].append(face)
	for key in by_resource:
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		# A closed box: back faces stay culled so the passage shows through the transparent vortex frames.
		material.cull_mode = BaseMaterial3D.CULL_BACK
		if key == 138:
			material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			wheel_material = material
		else:
			material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(str(src.root) + "material_%d.png" % key))
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for face in by_resource[key]:
			var points: Array[Vector3] = []
			for p in face.points: points.append(Vector3(p[0], p[1], p[2]))
			var order := [0, 1, 2, 0, 2, 3]
			# Godot draws clockwise triangles as front faces: wind every face to face out of the box.
			var normal := (points[1] - points[0]).cross(points[2] - points[0])
			if normal.dot((points[0] + points[2]) / 2.0 - centre) > 0: order = [0, 2, 1, 0, 3, 2]
			for i in order:
				surface.set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
				surface.add_vertex(points[i])
		var mesh := MeshInstance3D.new()
		mesh.name = "Resource%d" % key
		mesh.mesh = surface.commit()
		mesh.material_override = material
		add_child(mesh)
	body = StaticBody3D.new()
	body.name = "Barrier"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = box_max - box_min
	shape.shape = box
	shape.position = centre
	body.add_child(shape)
	add_child(body)
	voice = AudioStreamPlayer3D.new()
	voice.position = west_centre()
	add_child(voice)
	var proposed: Variant = saved if saved != null else initial()
	return restore(proposed if validate(proposed).is_empty() else initial())

func checkpoint() -> Dictionary:
	return {"version":1, "state":state, "clock":clock}

func restore(saved: Variant) -> String:
	var proposed: Variant = saved if saved != null else initial()
	var error := validate(proposed)
	if not error.is_empty(): return error
	state = int(proposed.state)
	clock = float(proposed.clock)
	voice.stop()
	present()
	return ""

func west_centre() -> Vector3:
	return Vector3(box_min.x, (box_min.y + box_max.y) / 2.0, (box_min.z + box_max.z) / 2.0)

func linked() -> bool:
	return state != 2

func frame() -> int:
	return mini(int(clock * FPS), FRAMES - 1) if state == 1 else 0

func present() -> void:
	visible = linked()
	if is_instance_valid(body): body.collision_layer = 1 if linked() else 0
	if wheel_material != null: wheel_material.albedo_texture = frames[frame()]

## Distance from `origin` along `direction` to the box face the viewer stands in front of (west face from the west,
## east face from the east), or -1 when the ray misses it.
func face_hit_distance(origin: Vector3, direction: Vector3) -> float:
	var plane_x: float
	if origin.x < box_min.x and direction.x > 0.0001: plane_x = box_min.x
	elif origin.x > box_max.x and direction.x < -0.0001: plane_x = box_max.x
	else: return -1.0
	var distance := (plane_x - origin.x) / direction.x
	var hit := origin + direction * distance
	if hit.y < box_min.y or hit.y > box_max.y or hit.z < box_min.z or hit.z > box_max.z: return -1.0
	return distance

## Kind4 value0 (empty hand) on control80, aimed anywhere on its visible face within reach. From the west the curtain
## hangs in front of it: closed or drawing, the curtain takes the click; gathered (mode2), the wheel is reachable.
func can_use() -> bool:
	if state != 0 or get_tree().paused or str(host.hand_item) != "": return false
	var origin: Vector3 = host.camera.global_position
	if origin.x < box_min.x and is_instance_valid(host.curtain) and int(host.curtain.mode) != 2: return false
	var direction: Vector3 = -host.camera.global_basis.z
	var distance := face_hit_distance(origin, direction)
	if distance < 0 or distance > 96: return false
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * maxf(distance - 1.0, 0.0), preload("res://scripts/lol2/region_blockers.gd").RAY_MASK)
	query.exclude = [host.player.get_rid(), body.get_rid()]
	return host.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

## Modern adapter: E prompt; the original has no on-screen prompt for the wheel door.
func interaction_hint() -> String:
	return "E — Push stone wheel" if can_use() else ""

func use() -> bool:
	if not can_use(): return false
	# g7008: op7 control80 sub0 + op0x14 sound342.
	state = 1
	clock = 0.0
	play()
	present()
	return true

func play() -> void:
	var clip: AudioStream = AudioStreamWAV.load_from_file(src.audio[str(int(src.sound))].path)
	if clip == null: return
	voice.stream = clip
	voice.play()

func step(delta: float) -> void:
	if state != 1 or not is_finite(delta) or delta <= 0: return
	clock += delta
	if clock >= FRAMES / FPS:
		# Kind6 value2, g7030: op9 property2 unlinks the assembly.
		state = 2
		clock = 0.0
	present()
