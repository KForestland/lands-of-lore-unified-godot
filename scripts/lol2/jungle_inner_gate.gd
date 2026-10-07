extends Node3D
## Live Kelsrick inner gate (movables 74/75) on the Jungle host: the original two leaves, shut at rest, with source
## open/shut producers (jungle_inner_gate_state.gd).
## - Region2752 entry: grounded edge, saved.
## - Use: E aimed at a leaf, empty hand allowed (kind4 mode0), effective only once Kelsrick is dead.
## - Kelsrick's control98 selectors and op1 commands, and the alarm's op1 commands, arrive through external().
## Modern: swing time; a leaf holds its whole remaining swing while Luther stands anywhere in it (no native pushing).
const State=preload("res://scripts/lol2/jungle_inner_gate_state.gd")
const REACH:=110.0
var host: Node3D
var hooks: Dictionary={}
var src: Dictionary
var data: Dictionary
var state: Dictionary
var inside:=false
var effect_log: Array=[]
var leaves: Dictionary={}
var poses: Dictionary={}
var pose: Dictionary={"74":-1,"75":-1}
var materials: Dictionary={}

static func assets_ready() -> bool: return FileAccess.file_exists(State.SOURCE) and FileAccess.file_exists(State.LEAVES)

func setup(owner_host: Node3D, supplied_hooks: Dictionary={}, saved: Variant=null) -> String:
	host=owner_host;hooks=supplied_hooks
	src=State.source()
	if FileAccess.get_sha256(State.LEAVES)!=str(src.leaves_sha256): return "Inner gate leaves do not match the source contract (run tools/prepare_jungle_inner_gate.py)."
	data=JSON.parse_string(FileAccess.get_file_as_string(State.LEAVES))
	for leaf in data.leaves:
		var body:=StaticBody3D.new();body.name="InnerGate%d"%int(leaf.index);body.collision_layer=1;body.collision_mask=0
		body.set_meta("source_movable",int(leaf.index))
		body.add_child(MeshInstance3D.new());body.add_child(CollisionShape3D.new())
		add_child(body);body.position=origin();leaves[str(int(leaf.index))]=body
	return restore(saved if saved!=null else initial())

func initial() -> Dictionary: return {"version":1,"state":State.initial(false),"inside":false}
func checkpoint() -> Dictionary: return {"version":1,"state":state.duplicate(true),"inside":inside}
static func validate(packet: Variant) -> String:
	if not packet is Dictionary or packet.size()!=3 or not (packet.get("version") is int or packet.get("version") is float) or packet.version!=1 or not packet.get("inside") is bool: return "Invalid inner gate packet."
	return State.validate(packet.get("state"))

func restore(packet: Variant) -> String:
	var error:=validate(packet)
	if not error.is_empty(): return error
	state=State.canonical(packet.state);inside=bool(packet.inside)
	for k in leaves: _set_pose(k,State.percent(state,k))
	return ""

func origin() -> Vector3:
	var value=host.get("native_translation")
	return value if value is Vector3 else Vector3.ZERO
func world_active() -> bool: return host.starting_magic!=null and host.starting_magic.world_active()
func context() -> Dictionary:
	if hooks.has("context") and hooks.context is Callable and hooks.context.is_valid():
		var value=hooks.context.call()
		if value is Dictionary: return value
	return {"shared":{}}

## Raw command from another owner (Kelsrick g5084/g30684, the village alarm g27172).
func external(raw: String) -> bool:
	var effects:=State.external(state,src,raw,context())
	effect_log.append_array(effects)
	return not effects.is_empty()

## ---- producers --------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	if state==null or state.is_empty() or get_tree().paused or not world_active() or not is_finite(delta) or delta<=0: return
	var p: Vector3=host.player.global_position-origin()
	var foot: float=p.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	var region: Dictionary=src.regions[0]
	var polygon:=PackedVector2Array()
	for v in region.polygon: polygon.append(Vector2(v[0],v[1]))
	var now: bool=foot>=float(region.floor_min)-1 and foot<=float(region.floor_max)+3 and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon)
	if now and not inside: effect_log.append_array(State.enter_region(state,src,int(region.region),context()))
	inside=now
	for k in leaves: _step(k,delta)

func aimed_leaf() -> int:
	if host.get_tree().paused or not world_active(): return -1
	var query:=PhysicsRayQueryParameters3D.create(host.camera.global_position,host.camera.global_position-host.camera.global_basis.z*REACH,1,[host.player.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider.has_meta("source_movable") or hit.collider.get_parent()!=self: return -1
	return int(hit.collider.get_meta("source_movable"))

## E aimed at a leaf: kind4 mode0 (any hand). Only the source records under GV_KELSRICK_DEAD==1 act.
func use() -> bool:
	var leaf:=aimed_leaf()
	if leaf<0: return false
	var effects:=State.use(state,src,leaf,context())
	effect_log.append_array(effects)
	return not effects.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and use(): get_viewport().set_input_as_handled()

func _touches_player(points: PackedVector3Array) -> bool:
	var hull:=ConvexPolygonShape3D.new();hull.points=points
	var query:=PhysicsShapeQueryParameters3D.new();query.shape=hull;query.collision_mask=host.player.collision_layer;query.transform=Transform3D(Basis(),origin())
	for hit in get_world_3d().direct_space_state.intersect_shape(query):
		if hit.collider==host.player: return true
	return false

## ---- presentation -----------------------------------------------------------------------------------------------
func _leaf_data(k: String) -> Dictionary: return data.leaves.filter(func(l): return str(int(l.index))==k)[0]

func _prepare(k: String, percent: int) -> void:
	var key:="%s:%d"%[k,percent]
	if poses.has(key): return
	var mesh:=ArrayMesh.new();var vertices:=PackedVector3Array()
	var frame: Array=_leaf_data(k).frames[percent]
	var lift:=_decal_offsets(frame)
	for f in frame.size():
		var face: Dictionary=frame[f]
		if not materials.has(face.material):
			var material:=StandardMaterial3D.new()
			material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(State.LEAVES.get_base_dir()+"/"+str(face.material)))
			material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
			material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			materials[face.material]=material
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(materials[face.material])
		for index in [0,1,2,0,2,3]:
			var v: Array=face.vertices[index]
			surface.set_uv(Vector2(face.uv[index][0],face.uv[index][1]));surface.add_vertex(Vector3(v[0],v[1],v[2])+lift[f]);vertices.append(Vector3(v[0],v[1],v[2]))
		surface.commit(mesh)
	var shape:=ConvexPolygonShape3D.new();shape.points=vertices
	poses[key]=[mesh,shape]

## The carved masks (template children) are exactly coplanar with the leaf faces; the native renderer paints them last.
## Presentation only: a smaller face coplanar with a larger one is drawn 0.3 units outward to avoid z-fighting.
## Collision keeps the source vertices.
static func _decal_offsets(frame: Array) -> Array:
	var centre:=Vector3.ZERO;var count:=0
	for face in frame:
		for v in face.vertices: centre+=Vector3(v[0],v[1],v[2]);count+=1
	centre/=maxf(count,1)
	var info: Array=[]
	for face in frame:
		var a:=Vector3(face.vertices[0][0],face.vertices[0][1],face.vertices[0][2]);var b:=Vector3(face.vertices[1][0],face.vertices[1][1],face.vertices[1][2]);var c:=Vector3(face.vertices[2][0],face.vertices[2][1],face.vertices[2][2])
		var n:=(b-a).cross(c-a);info.append({"origin":a,"normal":n.normalized(),"area":n.length()})
	var lift: Array=[]
	for i in frame.size():
		var offset:=Vector3.ZERO
		for j in frame.size():
			if i==j or float(info[j].area)<=float(info[i].area): continue
			var nj: Vector3=info[j].normal
			if absf(nj.dot(info[i].normal))>0.999 and absf((info[i].origin-info[j].origin).dot(nj))<0.01:
				var out:=signf((info[i].origin-centre).dot(nj))
				offset=nj*out*0.3
		lift.append(offset)
	return lift

func _set_pose(k: String, percent: int) -> void:
	if percent==int(pose[k]): return
	_prepare(k,percent)
	leaves[k].get_child(0).mesh=poses["%s:%d"%[k,percent]][0];leaves[k].get_child(1).shape=poses["%s:%d"%[k,percent]][1]
	pose[k]=percent

func _step(k: String, delta: float) -> void:
	var probe:=state.duplicate(true);State.advance(probe,k,delta)
	var target:=State.percent(probe,k)
	if target==int(pose[k]): state.leaves[k].elapsed=probe.leaves[k].elapsed;return
	var step:=1 if target>int(pose[k]) else -1
	# The leaves swing south across the passage: hold the whole remaining swing while Luther stands anywhere in it, so the
	# gate shuts behind him instead of stopping half-closed in his path (native pushing is not replayed).
	var final:=int(round(float(state.leaves[k].target)))
	var sweep: PackedVector3Array=PackedVector3Array()
	for at in range(int(pose[k]),final+step,step*10)+[final]:
		_prepare(k,at);sweep.append_array(poses["%s:%d"%[k,at]][1].points)
	if _touches_player(sweep): return
	for next in range(int(pose[k])+step,target+step,step):
		_prepare(k,next)
		var hull:=ConvexPolygonShape3D.new();var points: PackedVector3Array=poses["%s:%d"%[k,int(pose[k])]][1].points
		points.append_array(poses["%s:%d"%[k,next]][1].points);hull.points=points
		var query:=PhysicsShapeQueryParameters3D.new();query.shape=hull;query.collision_mask=host.player.collision_layer;query.transform=Transform3D(Basis(),origin())
		for hit in get_world_3d().direct_space_state.intersect_shape(query):
			if hit.collider==host.player: return
		_set_pose(k,next)
		state.leaves[k].elapsed=float(next)/100.0*State.DURATION
	state.leaves[k].elapsed=probe.leaves[k].elapsed
