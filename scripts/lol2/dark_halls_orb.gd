extends Node
## Meta duck: walk into the dome and the orb rises. The shades come to it, then the pit floor comes up.
## Exact: region 1596 event 4 is group 1066 (link, three timers, sound 881, opcode 18 to height 900). It does not raise kind 6.
## Timer 1 is group 2040, opcode 17, state += 1, and it is offered only while local5 < 6. Timer 2 has no record.
## Kind-6 value 3 on the orb is the ten pulls, then group 2766 at state 20. Kind-6 value 20 is group 2792.
## Nothing in the scanned groups raises value 3 or value 6. The test supplies those pulses. Opcode 18's reader was not entered.
const SOURCE := "res://scripts/lol2/dark_halls_orb_source.json"
const FOOT := 32.0
const RISE_PER_SPEED := 2.5
var host: Node3D
var source: Dictionary = {}
var polygon := PackedVector2Array()
var entered := false
var orb_state := 0
var timers: Dictionary = {}
var local7 := 0
var local9 := 0
var sounds: Array[int] = []
var pulled: Dictionary = {}
var pit_y := 370.0
var pit_target := 370.0
var pit_root: Node3D
var orb_node: Node3D

func setup(walkthrough: Node3D) -> String:
	host = walkthrough
	name = "DarkHallsOrb"
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if not parsed is Dictionary:
		return "Dark Halls orb source missing."
	source = parsed
	for point_v in source.polygon:
		var point: Array = point_v
		polygon.append(Vector2(float(point[0]), float(point[1])))
	var area_v: Variant = JSON.parse_string(FileAccess.get_file_as_string(str(host.get("geometry_file"))))
	if not area_v is Dictionary:
		return "Dark Halls geometry missing."
	var area: Dictionary = area_v
	var regions: Dictionary = {}
	for id_v in source.pit.regions:
		regions[int(id_v)] = true
	pit_root = Node3D.new()
	pit_root.name = "PitFloor"
	add_child(pit_root)
	var tris: PackedVector3Array = PackedVector3Array()
	var drawn := 0
	var root := str(host.geometry_file).get_base_dir() + "/"
	var textures: Dictionary = {}
	for face_v in area.faces:
		var face: Dictionary = face_v
		if str(face.get("kind", "")) != "floor" or not regions.has(int(face.get("region", -1))):
			continue
		var key := str(face.get("material", ""))
		if not textures.has(key):
			var material := StandardMaterial3D.new()
			material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			material.cull_mode = BaseMaterial3D.CULL_DISABLED
			material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
			material.albedo_texture = ImageTexture.create_from_image(Image.load_from_file(root + str(area.materials[key])))
			material.albedo_color = host.TINT
			textures[key] = material
		pit_root.add_child(_mesh(face, textures[key]))
		var pts: Array = face.points
		if pts.size() >= 4:
			for i in [0, 1, 2, 0, 2, 3]:
				var point: Array = pts[i]
				tris.append(Vector3(float(point[0]), float(point[1]), float(point[2])))
		drawn += 1
	if drawn != 7:
		return "Dark Halls pit floor count is %d." % drawn
	var body := StaticBody3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(tris)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	body.add_child(collider)
	pit_root.add_child(body)
	var props: Dictionary = host.prop_nodes
	orb_node = props.get(int(source.orb.prop), null) as Node3D
	if orb_node == null:
		return "Dark Halls orb prop is missing."
	pit_y = float(source.pit.from)
	pit_target = pit_y
	return ""

func _mesh(face: Dictionary, material: Material) -> MeshInstance3D:
	var pts: Array = face.points
	var uvs: Array = face.uv
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := mini(pts.size(), uvs.size())
	for i in range(1, count - 1):
		for k in [0, i, i + 1]:
			var uv: Array = uvs[k]
			surface.set_uv(Vector2(float(uv[0]), float(uv[1])))
			var point: Array = pts[k]
			surface.add_vertex(Vector3(float(point[0]), float(point[1]), float(point[2])))
	var mesh := MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = material
	return mesh

func inside() -> bool:
	if host == null:
		return false
	var p: Vector3 = host.player.position
	if absf(p.y - FOOT - float(source.floor)) >= 2.0:
		return false
	return Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), polygon)

func enter_1596() -> bool:
	if entered:
		return false
	entered = true
	timers[0] = true
	timers[1] = true
	timers[2] = true
	sounds.append(int(source.orb.sound))
	var to: Array = source.orb.to
	orb_node.position = Vector3(float(to[0]), float(to[1]), float(to[2]))
	return true

func expire_timer(index: int) -> bool:
	if not bool(timers.get(index, false)) or index == 2 or _local5() >= 6:
		return false
	if index == 1:
		orb_state += 1
	return true

func raise_kind6(owner: String, value: int) -> bool:
	if owner == "orb" and value == 3:
		return _orb_value3()
	if owner == "orb" and value == 20:
		return _raise_pit()
	return false

func _local5() -> int:
	var windows := host.get_node_or_null("DarkHallsWindows")
	if windows == null:
		return 0
	var opened: Variant = windows.call("opened")
	if opened is Array:
		return (opened as Array).size()
	return 0

func _orb_value3() -> bool:
	if _local5() > 6 and local9 == 0:
		local9 = 1
		sounds.append(546)
		return true
	for row_v in source.pulls:
		var row: Dictionary = row_v
		if int(row.state) != orb_state:
			continue
		_move_actor(int(row.actor), source.pull_to)
		orb_state += 1
		return true
	if orb_state == 20:
		orb_state = 25
		return true
	return false

func _raise_pit() -> bool:
	if local7 != 0:
		return false
	local7 = 1
	pit_target = float(source.pit.to)
	sounds.append(int(source.pit.sound))
	return true

func _move_actor(actor: int, to: Array) -> void:
	var id := str(actor)
	var at := Vector3(float(to[0]), float(to[1]), float(to[2]))
	pulled[id] = at
	var pop := host.get_node_or_null("DarkHallsCreatures")
	if pop == null:
		return
	var state_v: Variant = pop.get("state")
	if state_v != null and state_v.actors.has(id):
		state_v.actors[id].position = [at.x, at.y, at.z]
	var bodies_v: Variant = pop.get("bodies")
	if bodies_v is Dictionary and (bodies_v as Dictionary).has(id):
		var body := (bodies_v as Dictionary)[id] as CharacterBody3D
		if body != null:
			var origin := Vector3.ZERO
			var origin_v: Variant = pop.call("origin")
			if origin_v is Vector3:
				origin = origin_v
			body.position = at + origin
			body.velocity = Vector3.ZERO

func _physics_process(delta: float) -> void:
	if host == null or not bool(host.get("ready_for_review")) or host.player == null:
		return
	if not entered and host.player.is_on_floor() and inside():
		enter_1596()
	if pit_root != null and pit_y < pit_target:
		var step := float(source.pit.speed) * RISE_PER_SPEED * delta
		pit_y = minf(pit_target, pit_y + step)
		pit_root.position.y = pit_y - float(source.pit.from)
