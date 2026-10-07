extends Node3D
## Source surface chain; actor/sound consumers attach to script_group separately.
signal script_group(group: int)
const State=preload("res://scripts/lol2/hive_boulder_sequence.gd")
const Geometry=preload("res://scripts/lol2/hive_moving_geometry.gd")
const ROOT="res://assets/lol2/generated/hive_boulders/"
const WALL_REGIONS=[794,795,800,801,1216,1217,1218]
var host: Node3D
var data: Dictionary
var state:=State.initial()
var body: StaticBody3D
var collider: CollisionShape3D
var mesh: MeshInstance3D
var last_offsets: Dictionary={}
static func replaces(face: Dictionary) -> bool:
	var region:=int(face.region)
	return (face.kind=="wall" and region in WALL_REGIONS) or (face.kind=="floor" and region in [1216,1217,1218]) or (face.kind=="ceiling" and region in [794,801])
func _ready() -> void:
	host=get_parent()
	data=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"boulders.json"))
	body=StaticBody3D.new()
	add_child(body)
	collider=CollisionShape3D.new()
	body.add_child(collider)
	mesh=MeshInstance3D.new()
	body.add_child(mesh)
	rebuild()
func checkpoint() -> Dictionary:
	return state.duplicate(true)
func restore(value: Variant) -> String:
	var restored:=State.restore(value)
	if restored.has("error"): return restored.error
	state=restored.state
	rebuild()
	return ""
func rebuild() -> void:
	var offsets:=State.offsets(state)
	if offsets==last_offsets: return
	var faces:=Geometry.faces(data,offsets)
	var groups: Dictionary={}
	var collision:=PackedVector3Array()
	for face in faces:
		var key: String=face.get("material",face.kind)
		if not groups.has(key):
			var surface:=SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(host.materials.get(key,host.materials.get("wall")))
			groups[key]=surface
		var surface: SurfaceTool=groups[key]
		for index in [0,1,2,0,2,3]:
			var p: Array=face.points[index]
			var vertex:=Vector3(p[0],p[1],p[2])
			var uv: Array=face.get("uv",[[0,0],[0,0],[0,0],[0,0]])[index]
			surface.set_uv(Vector2(uv[0],uv[1]))
			surface.add_vertex(vertex)
			collision.append(vertex)
	var rebuilt:=ArrayMesh.new()
	for surface in groups.values():
		surface.generate_normals()
		surface.commit(rebuilt)
	mesh.mesh=rebuilt
	var shape:=ConcavePolygonShape3D.new()
	shape.backface_collision=true
	shape.set_faces(collision)
	collider.shape=shape
	last_offsets=offsets
func inside(points: Array) -> bool:
	var polygon:=PackedVector2Array()
	for p in points: polygon.append(Vector2(p[0],p[1]))
	return Geometry2D.is_point_in_polygon(Vector2(host.player.position.x,host.player.position.z),polygon)
func on_moving_floor() -> bool:
	if not host.player.is_on_floor() or host.player.velocity.y>0: return false
	var inside_floor:=false
	for row in data.surfaces:
		if row.kind!="floor": continue
		for face in row.faces:
			var polygon: Array=[]
			for point in face.points: polygon.append([point[0],point[2]])
			if inside(polygon): inside_floor=true
	if not inside_floor: return false
	var foot: Vector3=host.player.global_position-Vector3.UP*32.0
	var query:=PhysicsRayQueryParameters3D.create(foot+Vector3.UP*1.0,foot-Vector3.UP*1.0,1,[host.player.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider==body and hit.normal.y>0.5
func _physics_process(delta: float) -> void:
	if get_tree().paused or host.flying or host.get_node("Warriors").health==0: return
	var conversation=host.get_node("ConversationReview")
	if conversation.started and not conversation.completed: return
	if state.phase==0 and host.player.is_on_floor() and absf(host.player.position.y-32.0-float(data.trigger.floor))<1.0 and inside(data.trigger.polygon):
		for group in State.begin(state): script_group.emit(group)
	var riding:=on_moving_floor()
	var previous: float=State.offsets(state).floor1216
	var result:=State.advance(state,delta)
	rebuild()
	if riding: host.player.position.y+=float(State.offsets(state).floor1216)-previous
	for group in result.groups: script_group.emit(group)
