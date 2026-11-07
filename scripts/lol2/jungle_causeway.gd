extends Node3D
## Huline Jungle causeway collapse (L4_HJ prop4648 event20, group17352; tools/prepare_jungle_causeway.py).
## All three exit endings (prop4398 groups 16986/17076/17160) run op9 prop4648 property21 before their movie; its
## g17352 sinks the causeway: 12 floors to -200 (water preset 42 on 11 of them) and region4445 by 20, controls 61/62
## linked and control84 unlinked, local43 = 1. The exit encounter state queues the group; this host applies it.
## State: quests.jungle_causeway {version, collapsed}. A save that already holds a played exit ending but no causeway
## entry (made before this host) is read as collapsed, since the ending ran g17352 natively.
## Control84 keeps its native solid (static_collision_L4_HJ.json, template24 mode3 child47, 60 high) while linked;
## region bit1 on 4429/4448/4447 becomes creature refusal (creature_region_barrier.gd) once collapsed.
## Modern adapters (docs/DEVIATIONS.md): floors are shown at their final height at once (native speeds 244 and 25 settle
## in about 0.1 and 0.3 s); the barrier is the documented refusal adapter. The eight scripted causeway props
## (template39, sprite 755) are drawn here: 507/509/4162 unlink, 4161/508/506/4181/4160 teleport to their op18 x/z and
## keep their height (native 65BB0: flags 0x0a85 = bit 0x04 teleport, height only with bit 0x100). Content gaps (not hosted): the shake and the movables 59/60/62/63.
const ROOT := "res://assets/lol2/generated/jungle_causeway/"
const KEY := "jungle_causeway"
var host: Node3D
var src: Dictionary
var textures: Dictionary = {}
var materials: Dictionary = {}
var floors: Dictionary = {}
var walls_before: StaticBody3D
var walls_after: StaticBody3D
var creature_barriers: Array = []
var props: Dictionary = {}  # record -> MeshInstance3D

static func assets_ready() -> bool: return FileAccess.file_exists(ROOT + "source.json")
static func source() -> Dictionary: return JSON.parse_string(FileAccess.get_file_as_string(ROOT + "source.json"))
static func initial() -> Dictionary: return {"version": 1, "collapsed": false}

static func validate(value: Variant) -> String:
	if not value is Dictionary or value.size() != 2 or value.get("version") != 1 or not value.get("collapsed") is bool: return "Invalid jungle causeway."
	return ""

## Floor regions and wall faces the Jungle scene leaves to this host (called before the scene builds its static mesh).
static func dynamic_regions() -> Array: return source().floors.keys().map(func(k): return int(k))
static func static_exclusions() -> Array: return source().walls_before
## Static assemblies whose presence g17352 changes (static_assemblies.gd managed presence).
static func managed_assemblies() -> Array:
	var s := source()
	return s.link + s.unlink

## Read without creating the entry: loading the Jungle must not change the quests.
func state() -> Dictionary:
	var saved: Variant = host.quest_state.get(KEY)
	if saved is Dictionary and validate(saved).is_empty(): return saved
	return {"version": 1, "collapsed": _ending_played()}
func collapsed() -> bool: return bool(state().collapsed)

## A played exit ending (the encounter state records it when the ending's group runs, together with g17352).
func _ending_played() -> bool:
	var exit: Variant = host.quest_state.get("jungle_exit_encounter")
	if not exit is Dictionary or not exit.get("encounter") is Dictionary: return false
	var ending: Variant = exit.encounter.get("ending")
	return ending is Dictionary and not ending.is_empty()

func setup(owner_host: Node3D) -> String:
	name = "JungleCauseway"
	host = owner_host
	src = source()
	if not src is Dictionary or int(src.get("version", 0)) != 1 or int(src.owner.group) != 17352: return "Invalid causeway source."
	for region in src.floors:
		var body := StaticBody3D.new(); body.name = "CausewayFloor" + region
		body.add_child(MeshInstance3D.new()); body.add_child(CollisionShape3D.new()); add_child(body)
		floors[region] = {"body": body, "final": null}
	var faces: Array = []
	var scene: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/jungle_review/jungle.json"))
	for index in src.walls_before: faces.append(scene.faces[int(index)])
	walls_before = _walls("CausewayWallsBefore", faces)
	walls_after = _walls("CausewayWallsAfter", src.walls_after)
	var assemblies = host.get("static_assemblies")
	if assemblies != null and is_instance_valid(assemblies):
		var solid_error: String = assemblies.add_scripted_solids("L4_HJ", src.unlink.map(func(id): return int(id)))
		if not solid_error.is_empty(): return solid_error
	for row in src.props:
		var node := MeshInstance3D.new()
		node.name = "CausewayProp%d" % int(row.record)
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
		var path := ROOT + str(row.image)
		if not textures.has(path): textures[path] = ImageTexture.create_from_image(Image.load_from_file(path))
		material.albedo_texture = textures[path]
		var quad := QuadMesh.new()
		quad.size = Vector2(float(row.right) - float(row.left), float(row.top) - float(row.bottom))
		quad.center_offset = Vector3((float(row.left) + float(row.right)) / 2.0, (float(row.bottom) + float(row.top)) / 2.0, 0)
		node.mesh = quad
		node.material_override = material
		add_child(node)
		props[int(row.record)] = node
	for row in src.creature_regions:
		var barrier: StaticBody3D = preload("res://scripts/lol2/creature_region_barrier.gd").new()
		barrier.name = "CausewayCreatureBarrier%d" % int(row.id)
		add_child(barrier)
		barrier.setup(host, row)
		creature_barriers.append(barrier)
	present()
	return ""

## g17352, queued by an exit ending (exit encounter source_group signal). Runs once.
func on_source_group(group: int) -> void:
	if group != int(src.owner.group) or collapsed(): return
	host.quest_state[KEY] = {"version": 1, "collapsed": true}
	present()

func present() -> void:
	var done := collapsed()
	for region in floors: _present_floor(region, done)
	walls_before.visible = not done
	walls_before.collision_layer = 0 if done else 1
	walls_before.process_mode = Node.PROCESS_MODE_DISABLED if done else Node.PROCESS_MODE_INHERIT
	walls_after.visible = done
	walls_after.collision_layer = 1 if done else 0
	walls_after.process_mode = Node.PROCESS_MODE_INHERIT if done else Node.PROCESS_MODE_DISABLED
	for barrier in creature_barriers: barrier.set_enabled(done)
	for row in src.props:
		var node: MeshInstance3D = props[int(row.record)]
		node.visible = bool(row.present) and not (done and str(row.action) == "unlink")
		node.position = _vector(row.target if done and str(row.action) == "move" else row.position) + _origin()
	var assemblies = host.get("static_assemblies")
	if assemblies != null and is_instance_valid(assemblies):
		for id in src.link: assemblies.set_present(int(id), done)
		for id in src.unlink: assemblies.set_present(int(id), not done)

func _origin() -> Vector3:
	var value = host.get("native_translation")
	return value if value is Vector3 else Vector3.ZERO
func _vector(p: Array) -> Vector3: return Vector3(float(p[0]), float(p[1]), float(p[2]))

func _surface_material(key: String) -> StandardMaterial3D:
	if not materials.has(key):
		var path := ROOT + str(src.materials[key])
		if not textures.has(path): textures[path] = ImageTexture.create_from_image(Image.load_from_file(path))
		var m := StandardMaterial3D.new()
		m.albedo_texture = textures[path]
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		materials[key] = m
	return materials[key]

## Wall faces as one mesh per material plus one collider (the river dam recipe).
func _walls(label: String, faces: Array) -> StaticBody3D:
	var body := StaticBody3D.new(); body.name = label; body.collision_layer = 1; body.collision_mask = 0
	var groups := {}
	var points := PackedVector3Array()
	for face in faces:
		var key := str(face.get("material", ""))
		for i in [0, 1, 2, 0, 2, 3]:
			var p := _vector(face.points[i])
			points.append(p)
			if key.is_empty(): continue
			if not groups.has(key):
				groups[key] = SurfaceTool.new(); groups[key].begin(Mesh.PRIMITIVE_TRIANGLES); groups[key].set_material(_surface_material(key))
			groups[key].set_uv(Vector2(face.uv[i][0], face.uv[i][1])); groups[key].add_vertex(p)
	for key in groups:
		var mesh := MeshInstance3D.new(); mesh.mesh = groups[key].commit(); body.add_child(mesh)
	var shape := ConcavePolygonShape3D.new(); shape.backface_collision = true; shape.set_faces(points)
	var collision := CollisionShape3D.new(); collision.shape = shape; body.add_child(collision)
	body.position = _origin()
	add_child(body)
	return body

func _present_floor(region: String, final: bool) -> void:
	var row: Dictionary = floors[region]
	if row.final == final: return
	var face: Dictionary = src.floors[region].final if final else src.floors[region].initial
	var surface := SurfaceTool.new(); surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	if face.has("material"): surface.set_material(_surface_material(str(face.material)))
	var points := PackedVector3Array()
	for i in [0, 1, 2, 0, 2, 3]:
		var p := _vector(face.points[i])
		points.append(p)
		if face.has("uv"): surface.set_uv(Vector2(face.uv[i][0], face.uv[i][1]))
		surface.add_vertex(p)
	row.body.get_child(0).mesh = surface.commit()
	var shape := ConcavePolygonShape3D.new(); shape.backface_collision = true; shape.set_faces(points)
	row.body.get_child(1).shape = shape
	row.body.position = _origin()
	row.final = final

## Collapsed floor height of a region (tests and diagnostics).
func floor_height(region: int) -> float:
	var face: Dictionary = src.floors[str(region)].final if collapsed() else src.floors[str(region)].initial
	var low := INF
	for p in face.points: low = minf(low, float(p[1]))
	return low
