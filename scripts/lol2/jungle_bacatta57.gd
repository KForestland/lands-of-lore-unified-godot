extends Node3D
## Live village-entry Bacatta (actor57) on the Jungle host: region3501 → prop482 event20 → g10162 when
## GV_BACATTA_RELATIONSHIP==0. The village double door (movables 56/57, template82) swings shut, the threshold is sealed,
## and Bacatta57 stands outside, non-hostile. Region3157 removes her once GV_MET_BACATTA==1.
## Composes jungle_bacatta57_state.gd with the unchanged generic creature owner for actor57's body/combat
## (BACL4 definition5 sprites staged by the Bacatta65 media preparer).
## Adapters (docs/jungle-bacatta57.md):
## - door swing time;
## - a collision prism over region3501 once sealed (source region bit0);
## - g7026's op18 return point applied once the VILLAGE room has closed, so the player is outside the shut doors;
## - a peaceful body that turns hostile when struck;
## - absent globals read with their native new-game values (relationship 1).
const State=preload("res://scripts/lol2/jungle_bacatta57_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Packet=preload("res://scripts/lol2/jungle_bacatta57_packet.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const DOORS:="res://assets/lol2/generated/jungle_bacatta57/doors.json"
const POP_CONFIG:={"root":"res://assets/lol2/generated/jungle_bacatta65_media/bacatta_sprites/","source":"res://scripts/lol2/jungle_bacatta57_population_source.json",
	"target_prefix":"junglebacatta57","fighting_owner":"quest_state","nav":"res://assets/lol2/generated/creature_nav/L4_HJ.json",
	"names":{"5":"Bacatta"},"look":{"5":{"canvas":[320,200],"scale":0.47,"floor_row":187,"radius":20,"height":60}}}
const ID:="57"
## How long the sealing entry waits for the VILLAGE room to open before applying the return point anyway.
const ROOM_WAIT:=0.25
var host: Node3D
var hooks: Dictionary={}
var src: Dictionary
var state: Dictionary
var population: Node3D
var inside: Array=[]
var effect_log: Array=[]
var doors: Dictionary
var leaves: Array[StaticBody3D]=[]
var poses: Dictionary={}
var materials: Dictionary={}
var pose:=-1
var barrier: StaticBody3D
var room_wait:=0.0

static func assets_ready() -> bool:
	return FileAccess.file_exists(State.SOURCE) and FileAccess.file_exists(DOORS) and FileAccess.file_exists(str(POP_CONFIG.source)) and DirAccess.dir_exists_absolute(str(POP_CONFIG.root))

func setup(owner_host: Node3D, supplied_hooks: Dictionary={}, saved: Variant=null) -> String:
	host=owner_host;hooks=supplied_hooks
	src=State.source()
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(DOORS))
	if not parsed is Dictionary or FileAccess.get_sha256(DOORS)!=str(src.doors_sha256): return "Bacatta57 doors do not match the source contract (run tools/prepare_jungle_bacatta57.py)."
	doors=parsed
	population=preload("res://scripts/lol2/scripted_creature_population.gd").new()
	population.name="Bacatta57Body";population.configure(POP_CONFIG);add_child(population)
	var error: String=population.setup(host)
	if not error.is_empty(): return error
	population.set_physics_process(false);population.set_process(false);population.set_process_unhandled_input(false)
	for leaf in doors.leaves:
		var body:=StaticBody3D.new();body.name="Door%d"%int(leaf.index);body.collision_layer=1;body.collision_mask=0
		body.set_meta("source_movable",int(leaf.index))
		body.add_child(MeshInstance3D.new());body.add_child(CollisionShape3D.new())
		add_child(body);body.position=origin();leaves.append(body)
	barrier=StaticBody3D.new();barrier.name="ThresholdSeal";barrier.collision_layer=0;barrier.collision_mask=0
	var prism:=ConvexPolygonShape3D.new();var points:=PackedVector3Array()
	var threshold: Dictionary=_region(int(src.threshold))
	for v in threshold.polygon:
		points.append(Vector3(v[0],float(threshold.floor_min)-4,v[1]));points.append(Vector3(v[0],float(threshold.ceiling)+40,v[1]))
	prism.points=points
	var shape:=CollisionShape3D.new();shape.shape=prism;barrier.add_child(shape);add_child(barrier)
	return restore(saved if saved!=null else initial())

## ---- saved packet ----------------------------------------------------------------------------
func initial() -> Dictionary:
	return {"version":1,"branch":State.initial(src),"body":Generic.initial(population.src),"inside":[]}

func checkpoint() -> Dictionary:
	return {"version":1,"branch":state.duplicate(true),"body":population.checkpoint(),"inside":inside.duplicate()}

## Atomic: an invalid packet changes nothing.
func restore(packet: Variant) -> String:
	var error:=Packet.validate(packet)
	if not error.is_empty(): return error
	error=population.restore(packet.body)
	if not error.is_empty(): return error
	state=State.canonical(packet.branch)
	inside=packet.inside.map(func(r): return int(r))
	room_wait=0.0
	_sync_body(0.0);_present()
	return ""

## ---- host links --------------------------------------------------------------------------------
func origin() -> Vector3: return population.origin()
func world_active() -> bool: return host.starting_magic!=null and host.starting_magic.world_active()
func hostile() -> bool: return state!=null and not state.is_empty() and State.hostile(state)
func sealed() -> bool: return state!=null and not state.is_empty() and bool(state.sealed)
func _region(id: int) -> Dictionary: return src.regions.filter(func(r): return int(r.region)==id)[0]

## Shared globals the source tests: GV_BACATTA_RELATIONSHIP (13) and GV_MET_BACATTA (18). An absent global takes its
## native new-game value (GLOBAL.MIX: relationship 1).
func context() -> Dictionary:
	if hooks.has("context") and hooks.context is Callable and hooks.context.is_valid():
		var value=hooks.context.call()
		if value is Dictionary: return value
	var globals: Dictionary=host.quest_state.get("monastery",{}).get("globals",{}) if host.get("quest_state") is Dictionary else {}
	var shared: Dictionary={}
	for id in src.shared_names:
		var name:=str(src.shared_names[id])
		shared[id]=int(globals.get(name,int(src.native_initial.get(name,0))))
	return {"shared":shared}

func room_active() -> bool:
	if hooks.has("room_active") and hooks.room_active is Callable and hooks.room_active.is_valid(): return bool(hooks.room_active.call())
	var rooms=host.get("monastery")
	return rooms!=null and is_instance_valid(rooms) and rooms.active()

## ---- step --------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	if state==null or state.is_empty() or get_tree().paused or not is_finite(delta) or delta<=0: return
	# Region entry is sampled even while a room is up, so predicate173 is tested when Luther crosses the threshold (queue
	# time), not after a CAN farewell has reset the relationship.
	_regions()
	if room_active(): room_wait=0.0
	elif room_wait>0: room_wait=maxf(room_wait-delta,0.0)
	if sealed() and room_wait<=0 and not room_active() and _inside_threshold(): _return_outside()
	if world_active():
		_advance_doors(delta)
		_sync_body(delta)
	_present()

func _foot_local() -> Vector3:
	var p: Vector3=host.player.global_position-origin()
	p.y-=preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	return p

func _in(region: Dictionary, p: Vector3) -> bool:
	if p.y<float(region.floor_min)-1 or p.y>float(region.floor_max)+3: return false
	var polygon:=PackedVector2Array()
	for v in region.polygon: polygon.append(Vector2(v[0],v[1]))
	return Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon)

func _inside_threshold() -> bool: return _in(_region(int(src.threshold)),_foot_local())

func _regions() -> void:
	var p:=_foot_local()
	var now: Array=[]
	for region in src.regions:
		if _in(region,p): now.append(int(region.region))
	for r in now:
		if r not in inside: _apply(State.enter_region(state,src,r,context()))
	inside=now

func _apply(effects: Array) -> void:
	for e in effects:
		effect_log.append(e)
		match str(e.type):
			"sealed": room_wait=ROOM_WAIT
			"actor_presence": _sync_body(0.0)
		if hooks.has("effects") and hooks.effects is Callable and hooks.effects.is_valid() and str(e.type)!="group": hooks.effects.call(e)
	if effect_log.size()>200: effect_log=effect_log.slice(effect_log.size()-200)

## g7026's op18 return point, once the threshold is sealed: Luther stands outside the shut doors facing Bacatta.
func _return_outside() -> void:
	var p: Array=src.return_point
	var target:=Vector3(p[0],host.player.global_position.y,p[2])+Vector3(origin().x,0,origin().z)
	var down:=PhysicsRayQueryParameters3D.create(target+Vector3.UP*400,target-Vector3.UP*800,1,[host.player.get_rid(),barrier.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(down)
	if not hit.is_empty(): target.y=hit.position.y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	host.player.global_position=target;host.player.velocity=Vector3.ZERO
	var a: Array=src.actor.position
	var look:=Vector3(float(a[0]),0,float(a[2]))+origin();look.y=target.y
	if state.actor.present and look.distance_to(target)>0.1: host.player.look_at(look);host.camera.rotation=Vector3.ZERO
	inside=inside.filter(func(r): return r!=int(src.threshold))
	effect_log.append({"type":"returned","position":[target.x,target.y,target.z]})

## ---- doors ---------------------------------------------------------------------------------------------
func _prepare(percent: int) -> void:
	if poses.has(percent): return
	var built: Array=[]
	for leaf in doors.leaves:
		var mesh:=ArrayMesh.new();var vertices:=PackedVector3Array()
		for face in leaf.frames[percent]:
			if not materials.has(face.material):
				var material:=StandardMaterial3D.new()
				material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(DOORS.get_base_dir()+"/"+str(face.material)))
				material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
				material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				materials[face.material]=material
			var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(materials[face.material])
			for index in [0,1,2,0,2,3]:
				var v: Array=face.vertices[index]
				surface.set_uv(Vector2(face.uv[index][0],face.uv[index][1]));surface.add_vertex(Vector3(v[0],v[1],v[2]))
				vertices.append(Vector3(v[0],v[1],v[2]))
			surface.commit(mesh)
		var shape:=ConvexPolygonShape3D.new();shape.points=vertices
		built.append([mesh,shape])
	poses[percent]=built

func _set_pose(percent: int) -> void:
	if percent==pose: return
	_prepare(percent)
	for i in leaves.size():
		leaves[i].get_child(0).mesh=poses[percent][i][0];leaves[i].get_child(1).shape=poses[percent][i][1]
	pose=percent

## Swing toward the target; a pose whose sweep would hit the player waits (modern blocker, no pushing).
func _advance_doors(delta: float) -> void:
	var probe:=state.duplicate(true);State.advance(probe,delta)
	var target:=State.door_percent(probe)
	if target==pose: state.doors.elapsed=probe.doors.elapsed;return
	var step:=1 if target>pose else -1
	for next in range(pose+step,target+step,step):
		_prepare(next)
		for i in leaves.size():
			var hull:=ConvexPolygonShape3D.new();var points: PackedVector3Array=poses[pose][i][1].points
			points.append_array(poses[next][i][1].points);hull.points=points
			var query:=PhysicsShapeQueryParameters3D.new();query.shape=hull;query.collision_mask=host.player.collision_layer
			query.transform=Transform3D(Basis(),origin())
			for hit in get_world_3d().direct_space_state.intersect_shape(query):
				if hit.collider==host.player: return
		_set_pose(next)
		state.doors.elapsed=float(next)/100.0*State.DOOR_SECONDS
	state.doors.elapsed=probe.doors.elapsed

## ---- body ----------------------------------------------------------------------------------------------
## actor57 linked by g10162: non-hostile, holding the dormant idle pose at her placement; a strike makes her hostile and
## she then fights through the generic owner.
func _sync_body(delta: float) -> void:
	var body: Dictionary=population.state.actors[ID]
	var linked: bool=bool(state.actor.present)
	if linked and not body.present: Generic.spawn(population.state,ID)
	elif not linked and body.present:
		var fresh: Dictionary=Generic.initial(population.src)
		population.state.actors[ID]=fresh.actors[ID].duplicate(true);population.state.live[ID]=fresh.live[ID].duplicate(true)
	body=population.state.actors[ID]
	var alive: bool=linked and int(body.health)>0
	population.set_process_unhandled_input(alive);population.set_process(alive)
	if not linked: population.present();return
	if alive and not hostile() and int(body.health)<int(src.actor.health): _apply(State.struck(state))
	if hostile() and alive:
		if not body.woken: Generic.wake(population.state,ID)
		# A restore (delta 0) only presents; stepping the AI would move the saved body.
		if delta>0: population.advance(delta)
		else: population.present()
		return
	if not alive:
		if delta>0: Generic.advance_clocks(population.state,population.src,delta)
		population.present();return
	population.state.live[ID].mode=Live.IDLE
	population.present()

func _present() -> void:
	_set_pose(State.door_percent(state))
	var seal_on: bool=sealed() and not _inside_threshold()
	barrier.collision_layer=1 if seal_on else 0
	barrier.global_position=origin()

## Village alarm entry point: the door owner stays here.
func shut_doors() -> void:
	if state!=null and not state.is_empty(): _apply(State.shut(state))

func targets() -> Dictionary:
	return population.targets() if state!=null and not state.is_empty() and state.actor.present and int(population.state.actors[ID].health)>0 else {}
