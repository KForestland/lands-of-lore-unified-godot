extends Node
## STORY-067 Ancient City arrival elevator (docs/l16-arrival-elevator.md, Astra). Region 233's kind-12 record runs
## stream 0 group 564: opcode 21 movie 27 (ELEVATOR.VQA) on prop 680, then opcode 18 kind 1
## `120100002bf10df7000004080080000a0000` = direct relocation (flags 0x0804) of the player to native (-3797,-2291),
## heading 0x8000; height is not assigned (0x0100 clear), the destination region 343 floor is 0.
## The native host commits group 564 and emits movie_request(27); this node plays the original movie and then applies
## the decoded relocation (the host only stages opcode 18). Presentation: frozen world, Esc/Space skip.
const MOVIE := "res://assets/lol2/generated/l16_elevator/movie.json"
const DESTINATION := Vector3(-3797.0, 32.0, 2291.0)
const HEADING_UNITS := 0x8000
## Doorway (adapter, DEVIATIONS): movables 194 and 325 close region 233. Trigger plate control 78 (native (-3848,1201),
## kind 5 values 4/5 -> groups 42098/42116 on control 194) has no decoded door motion, so standing on the plate
## retracts both panels upward and they stay open (saved). The native plate groups still run through the host.
const KEY := "l16_arrival_doorway"
const PANELS := [194, 325]
const PLATE := Vector2(-3848.0, -1201.0)
var host: Node3D
var overlay: CanvasLayer
var rides := 0
var doorway: Node3D
var opened := false
var lift := 0.0
var height := 85.0

static func owns(face: Dictionary) -> bool:
	return (face.get("placement_kind") == "movable" or face.get("kind") == "movable") and int(face.get("source_index", -1)) in PANELS

static func assets_ready() -> bool:
	if not FileAccess.file_exists(MOVIE): return false
	var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(MOVIE))
	return info is Dictionary and int(info.get("index",-1)) == 27 and FileAccess.file_exists(str(info.get("path","")))

static func attach(map: Node3D) -> Node:
	var n = load("res://scripts/lol2/l16_arrival_elevator.gd").new(); n.host = map; n.name = "L16ArrivalElevator"; map.add_child(n); return n

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_doorway()
	opened = bool(host.quest_state.get(KEY, {}).get("opened", false))
	lift = height + 8.0 if opened else 0.0
	doorway.position.y = lift
	var native = host.progression.native
	if native != null: native.connect("movie_request", _on_movie)

func _on_movie(index: int, _name: String, _byte5: int) -> void:
	if index != 27 or is_instance_valid(overlay): return
	if not assets_ready():
		host.save_feedback("The city elevator movie is not installed."); _arrive(); return
	var info: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(MOVIE))
	overlay = CanvasLayer.new(); overlay.layer = 100; overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var black := ColorRect.new(); black.color = Color.BLACK; black.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.add_child(black)
	var video := VideoStreamPlayer.new(); video.name = "Video"; video.set_anchors_preset(Control.PRESET_FULL_RECT); video.expand = true
	var stream := VideoStreamTheora.new(); stream.file = str(info.path); video.stream = stream
	video.finished.connect(_finish); overlay.add_child(video)
	add_child(overlay); get_tree().paused = true; video.play()

func _build_doorway() -> void:
	doorway = Node3D.new(); doorway.name = "DoorwayPanels"; add_child(doorway)
	var pack: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(host.geometry_file))
	var groups: Dictionary = {}; var points := PackedVector3Array(); var low := INF; var high := -INF
	for face in pack.faces:
		if not owns(face): continue
		if not groups.has(face.material):
			var t := SurfaceTool.new(); t.begin(Mesh.PRIMITIVE_TRIANGLES); groups[face.material] = t
		for i in [0, 1, 2, 0, 2, 3]:
			var v := Vector3(face.points[i][0], face.points[i][1], face.points[i][2]); low = minf(low, v.y); high = maxf(high, v.y)
			var uv: Array = face.uv[i] if face.has("uv") else [0, 0]
			groups[face.material].set_uv(Vector2(uv[0], uv[1])); groups[face.material].add_vertex(v); points.append(v)
	for key in groups:
		var mesh := MeshInstance3D.new(); mesh.mesh = groups[key].commit()
		var mat := StandardMaterial3D.new(); mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		if pack.materials.has(key): mat.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(host.geometry_file.get_base_dir() + "/" + pack.materials[key]))
		mesh.material_override = mat; doorway.add_child(mesh)
	if points.is_empty(): return
	height = high - low
	var body := AnimatableBody3D.new(); body.sync_to_physics = false; body.collision_mask = 0
	var shape := ConcavePolygonShape3D.new(); shape.backface_collision = true; shape.set_faces(points)
	var col := CollisionShape3D.new(); col.shape = shape; body.add_child(col); doorway.add_child(body)

func on_plate() -> bool:
	var p: Vector3 = host.player.global_position
	return host.player.is_on_floor() and Vector2(p.x, p.z).distance_to(PLATE) < 40.0

func _physics_process(delta: float) -> void:
	if not opened and bool(host.quest_state.get(KEY, {}).get("opened", false)):
		opened = true; lift = height + 8.0; doorway.position.y = lift
	if not opened and on_plate():
		opened = true; host.quest_state[KEY] = {"version": 1, "opened": true}
	if opened and lift < height + 8.0:
		lift = minf(height + 8.0, lift + 60.0 * delta); doorway.position.y = lift

func skip() -> void:
	if is_instance_valid(overlay): _finish()

func _finish() -> void:
	if is_instance_valid(overlay):
		var video: VideoStreamPlayer = overlay.get_node("Video"); video.stop(); overlay.queue_free()
	overlay = null; get_tree().paused = false; _arrive()

func _arrive() -> void:
	rides += 1
	host.player.velocity = Vector3.ZERO
	host.player.global_position = DESTINATION
	host.player.rotation.y = -TAU * float(HEADING_UNITS) / 65536.0

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_instance_valid(overlay) or event is not InputEventKey or not event.pressed or event.echo: return
	if event.keycode in [KEY_ESCAPE, KEY_SPACE]: skip(); get_viewport().set_input_as_handled()
