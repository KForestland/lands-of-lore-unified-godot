extends StaticBody3D
## Dynamic source region bit1: refuse creature entry, without blocking player movement or aim rays.
## Modern collision adapter: source outline walls span floor..ceiling. An actor already inside can leave.
const LAYER := 1 << 10
var owner_host: Node3D
var polygon := PackedVector2Array()
var floor_height := 0.0
var ceiling_height := 0.0
var enabled := false
var creatures: Array[CollisionObject3D] = []
var allowed_exits: Array[CollisionObject3D] = []

func setup(host: Node3D, row: Dictionary) -> void:
	owner_host = host
	floor_height = float(row.floor)
	ceiling_height = float(row.ceiling)
	for p in row.polygon: polygon.append(Vector2(p[0],p[1]))
	collision_layer = 0
	collision_mask = 0
	var faces := PackedVector3Array()
	for i in polygon.size():
		var a := polygon[i]
		var b := polygon[(i+1)%polygon.size()]
		var quad := [Vector3(a.x,floor_height,a.y),Vector3(b.x,floor_height,b.y),Vector3(b.x,ceiling_height,b.y),Vector3(a.x,ceiling_height,a.y)]
		for index in [0,1,2,0,2,3]: faces.append(quad[index])
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	_visit(host)
	get_tree().node_added.connect(_register)

func _visit(node: Node) -> void:
	_register(node)
	for child in node.get_children(): _visit(child)

func _register(node: Node) -> void:
	if node is CollisionObject3D and node != owner_host.get("player") and owner_host.is_ancestor_of(node) and (node.collision_layer & 2) != 0 and node not in creatures:
		creatures.append(node)
		node.collision_mask |= LAYER
		if enabled and _inside(node.global_position):
			add_collision_exception_with(node)
			allowed_exits.append(node)

func _inside(point: Vector3) -> bool:
	return point.y >= floor_height-4 and point.y <= ceiling_height+4 and Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),polygon)

func set_enabled(value: bool) -> void:
	if enabled == value: return
	enabled = value
	collision_layer = LAYER if value else 0
	for actor in allowed_exits:
		if is_instance_valid(actor): remove_collision_exception_with(actor)
	allowed_exits.clear()
	if value:
		for actor in creatures:
			if is_instance_valid(actor) and _inside(actor.global_position):
				add_collision_exception_with(actor)
				allowed_exits.append(actor)

func _physics_process(_delta: float) -> void:
	for i in range(allowed_exits.size()-1,-1,-1):
		var actor := allowed_exits[i]
		if not is_instance_valid(actor): allowed_exits.remove_at(i)
		elif not _inside(actor.global_position):
			remove_collision_exception_with(actor)
			allowed_exits.remove_at(i)

func _exit_tree() -> void:
	for actor in creatures:
		if is_instance_valid(actor): actor.collision_mask &= ~LAYER
