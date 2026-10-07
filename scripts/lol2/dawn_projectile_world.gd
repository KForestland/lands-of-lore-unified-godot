extends RefCounted
## Godot collision adapter for the verified launch planner. Region membership
## uses the existing creature graph; sphere overlap uses live world collision.
## This is not parity with native AF0E0/AF9A4 collision traversal.
const Launch=preload("res://scripts/lol2/dawn_projectile_launch.gd")
const Rotation=preload("res://scripts/lol2/hive_boulder_impulse.gd")

static func world_position(point: Array, origin: Vector3) -> Vector3:
	return origin+Vector3(float(point[0])/65536.0,float(point[2])/65536.0,-float(point[1])/65536.0)

## The caller owns source height/radius getters and the caster RID exclusions.
## Query outcomes are generated here; callers cannot supply a fake acceptance.
static func launch(space: PhysicsDirectSpaceState3D, navigation: RefCounted, origin: Vector3,
		context: Dictionary, target: Variant=null, excluded: Array[RID]=[], mask: int=3) -> Dictionary:
	if space==null or navigation==null or not navigation.has_method("region_at") or not origin.is_finite() or mask<=0:
		return {"error":"Projectile world query unavailable."}
	var input:=context.duplicate(true)
	if target!=null:
		var bearing:=Launch.bearing(input.get("position"),target)
		if bearing.has("error"): return bearing
		input.heading=bearing.word
	if not Launch.Target.integer(input.get("heading"),0,65535): return {"error":"Invalid world launch heading."}
	input.sine=Rotation.sine(int(input.heading));input.cosine=Rotation.sine(int(input.heading)+16384)
	input.placements=[false,false];input.collision=false
	# Request both positions before touching physics; malformed input is atomic.
	var draft:=Launch.plan(input)
	if draft.has("error"): return draft
	var regions: Array=[]
	var selected:=-1
	for i in draft.placement_requests.size():
		var point:=world_position(draft.placement_requests[i],origin)
		var region: int=navigation.region_at(point-origin)
		regions.append(region)
		if region>=0:
			input.placements[i]=true;selected=i;break
	if selected>=0:
		var sphere:=SphereShape3D.new()
		# Godot requires a positive radius; a source point gets minimal extent.
		sphere.radius=maxf(float(input.effect_radius),0.001)
		var query:=PhysicsShapeQueryParameters3D.new()
		query.shape=sphere
		query.transform=Transform3D(Basis.IDENTITY,world_position(draft.placement_requests[selected],origin))
		query.collision_mask=mask;query.exclude=excluded
		input.collision=not space.intersect_shape(query,1).is_empty()
	var result:=Launch.plan(input)
	result.regions=regions
	result.world_position=world_position(result.position,origin)
	return result
