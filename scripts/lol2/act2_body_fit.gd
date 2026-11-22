extends RefCounted
## B1: world-only body adapter for linked native region corridors. Form/strike/contact dimensions stay with Body.
## The reduced cylinder exists only during the synchronous world move. Outside that call the player's original shape
## remains on its RID, so creature movement, prop contact and form-admission queries still see the ordinary form.
const Body = preload("res://scripts/lol2/player_form_body.gd")
const Edges = preload("res://scripts/lol2/region_edge_rule.gd")
const MIN_HEIGHT := 8.0
const MIN_RADIUS := 8.0
var host: Node3D
var regions: Array = []
var links: Dictionary = {}
var polygons: Array = []
var world_rids: Array[RID] = []
var profile := Vector2.ZERO # radius, height; transient, recomputed after save/form restoration
var active := false
var contact_clamps := 0
var eye_adjustment := 0.0
var prior_eye := INF
var prior_normal := Vector2.ZERO

func setup(owner: Node3D) -> void:
	host = owner
	regions = host.nav_regions
	if regions.is_empty() and host.progression != null: regions = host.progression.regions
	links = host.collision_links if not host.collision_links.is_empty() else Edges.links(regions)
	for row in regions:
		var polygon := PackedVector2Array()
		for vertex in row[0]: polygon.append(Vector2(float(vertex[0]), float(vertex[1])))
		polygons.append(polygon)
	# Only terrain is excluded from the ordinary full-form contact sweep. Movers and custom prop bodies remain solid.
	for child in host.get_children():
		if child is StaticBody3D:
			for shape in child.get_children():
				if shape is CollisionShape3D and shape.shape is ConcavePolygonShape3D:
					world_rids.append(child.get_rid()); break

func _contact_exclusions() -> Array[RID]:
	var excluded: Array[RID] = world_rids.duplicate()
	# Save restoration and native scripts may create a deck after setup.
	if host.progression != null:
		for deck in host.progression.floor_decks.values():
			var body = deck.get_node_or_null("Collision")
			if body is PhysicsBody3D: excluded.append(body.get_rid())
	return excluded

func _inside(region: int, point: Vector3) -> bool:
	return region >= 0 and region < polygons.size() and not polygons[region].is_empty() and Geometry2D.is_point_in_polygon(Vector2(point.x,point.z),polygons[region])

func _linked_motion(direction: Vector3, distance: float) -> bool:
	if host.progression == null: return false
	var here: int = host._collision_region_at(host.player.global_position) if host.region_collision_enabled else host.progression.region_at(host.player.global_position)
	if here < 0 or links.get(here,{}).is_empty(): return false
	var point: Vector3 = host.player.global_position + direction * distance
	if _inside(here,point): return true
	for other in links.get(here,{}):
		if _inside(int(other),point): return true
		for next in links.get(other,{}):
			if _inside(int(next),point): return true
	return false

static func cylinder(radius: float, height: float) -> CylinderShape3D:
	var shape := CylinderShape3D.new(); shape.radius=radius; shape.height=height
	return shape

func _world_query(shape: Shape3D, offset: Vector3, motion: Vector3) -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	# Ignore at most two units at the supporting foot, retaining the complete top/side clearance.
	# This lets a flat small-form cylinder approach a slope; the real mover still resolves the actual floor.
	var trim := minf(2.0,float(shape.height)*0.25)
	var probe := shape.duplicate() as Shape3D
	probe.height -= trim
	query.shape=probe; query.transform=host.player.global_transform*Transform3D(Basis.IDENTITY,offset+Vector3.UP*trim*0.5)
	query.margin=host.player.safe_margin+0.01
	query.motion=motion; query.collision_mask=host.player.collision_mask & ~(2|256)
	var excluded: Array[RID]=[host.player.get_rid()]
	if host.progression != null:
		for body in host.progression.mover_bodies.values():
			if is_instance_valid(body): excluded.append(body.get_rid())
	query.exclude=excluded
	return query

func _fits(shape: Shape3D, offset: Vector3, motion: Vector3) -> bool:
	var query := _world_query(shape,offset,motion)
	var space: PhysicsDirectSpaceState3D = host.player.get_world_3d().direct_space_state
	if not space.intersect_shape(query,1).is_empty(): return false
	return motion.is_zero_approx() or space.cast_motion(query)[0] >= 0.999

func _fits_size(radius: float, height: float, motion: Vector3) -> bool:
	return _fits(cylinder(radius,height),Vector3.UP*(height*0.5-Body.FOOT_OFFSET),motion)

func _supported(direction: Vector3, distance: float) -> bool:
	# Do not turn the existing step onto a thin cap into a duck below it over an absent floor.
	# This is an actual-world support query, not a new floor or a native-floor-height substitution.
	var from:Vector3=host.player.global_position+direction*distance+Vector3.UP*(2.0-Body.FOOT_OFFSET)
	var query:=PhysicsRayQueryParameters3D.create(from,from+Vector3.DOWN*34.0,host.player.collision_mask & ~2,[host.player.get_rid()])
	var hit:Dictionary=host.player.get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and float(hit.normal.y)>0.7

# A saved pose or a streamed region can already overlap the original form.
# Check its complete body: the ordinary fit probe trims the supporting foot.
# Ordinary resting contact stays within the mover and query margins.
func needs_world_fit() -> bool:
	if active:return false
	var collider:CollisionShape3D=host.player.get_child(0)
	var query:=_world_query(collider.shape,collider.position,Vector3.ZERO)
	query.shape=collider.shape
	query.transform=host.player.global_transform*Transform3D(Basis.IDENTITY,collider.position)
	var contacts:PackedVector3Array=host.player.get_world_3d().direct_space_state.collide_shape(query,32)
	var depth:=0.0
	for i in range(0,contacts.size(),2):depth=maxf(depth,contacts[i].distance_to(contacts[i+1]))
	var needed:bool=depth>host.player.safe_margin+query.margin+0.01
	return needed

func begin(direction: Vector3, distance: float = 2.0, allow_fit: bool = true) -> Dictionary:
	var collider: CollisionShape3D=host.player.get_child(0)
	var normal: Shape3D=collider.shape
	var normal_offset:=collider.position
	var radius:float=normal.radius; var height:float=normal.height
	var eye:float=host.camera.position.y
	# A form/posture owner or an aiming fixture may have placed the view since our last move.
	if prior_normal==Vector2(radius,height) and is_equal_approx(eye,prior_eye):eye+=eye_adjustment
	var state={"shape":normal,"offset":normal_offset,"start":host.player.global_position,"height":height,"camera_y":eye}
	var lookahead:=maxf(2.0,distance)
	var motion:=direction.normalized()*lookahead
	if not allow_fit or _fits(normal,normal_offset,motion):
		profile=Vector2(radius,height);active=false
	elif _linked_motion(direction.normalized(),lookahead) and _supported(direction.normalized(),maxf(lookahead,radius+2.0)) and _fits_size(MIN_RADIUS,MIN_HEIGHT,motion):
		# Maximise width first, then height. Neither dimension falls below the Lizard's source body.
		var lo:=MIN_RADIUS;var hi:=radius
		if _fits_size(radius,MIN_HEIGHT,motion):lo=radius
		for i in (0 if lo==radius else 7):
			var mid:float=(lo+hi)*0.5
			if _fits_size(mid,MIN_HEIGHT,motion):lo=mid
			else:hi=mid
		var fitted_radius:=lo
		lo=MIN_HEIGHT;hi=height
		if _fits_size(fitted_radius,height,motion):lo=height
		for i in (0 if lo==height else 8):
			var mid:float=(lo+hi)*0.5
			if _fits_size(fitted_radius,mid,motion):lo=mid
			else:hi=mid
		profile=Vector2(fitted_radius,lo);active=true
	elif active and _fits_size(profile.x,profile.y,Vector3.ZERO):
		pass # Remain fitted beneath a header when looking at a solid/unlinked wall; movement still collides.
	else:
		profile=Vector2(radius,height);active=false
	if active:
		collider.shape=cylinder(profile.x,profile.y)
		collider.position=Vector3.UP*(profile.y*0.5-Body.FOOT_OFFSET)
		# Both local offsets are written in one callback. Flush each one now; otherwise the deferred
		# transform notification coalesces them and physics moves the small shape at the full-form offset.
		collider.force_update_transform()
	return state

func finish(state: Dictionary) -> void:
	var collider: CollisionShape3D=host.player.get_child(0)
	collider.shape=state.shape;collider.position=state.offset
	collider.force_update_transform()
	if active:
		# Preserve the original form's outgoing contact radius too. Native movers and props on layer1 remain in
		# this sweep; only the known terrain RIDs are excluded. Incoming creatures see the restored full shape.
		var query:=PhysicsTestMotionParameters3D.new()
		query.from=Transform3D(host.player.global_basis,state.start)
		query.motion=host.player.global_position-state.start
		query.margin=host.player.safe_margin
		query.exclude_bodies=_contact_exclusions()
		var result:=PhysicsTestMotionResult3D.new()
		if not query.motion.is_zero_approx() and PhysicsServer3D.body_test_motion(host.player.get_rid(),query,result):
			var safe:float=result.get_collision_safe_fraction()
			if safe<0.999:
				host.player.global_position=state.start+result.get_travel()
				host.player.velocity.x*=safe;host.player.velocity.z*=safe
				contact_clamps+=1
	var adjustment:float=float(state.height)-profile.y if active else 0.0
	if active or eye_adjustment>0.0:host.camera.position.y=float(state.camera_y)-adjustment
	eye_adjustment=adjustment;prior_eye=host.camera.position.y
	prior_normal=Vector2(float(state.shape.radius),float(state.height))
	host.player.set_meta("lol2_world_fit",{"active":active,"radius":profile.x,"height":profile.y})
