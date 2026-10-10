extends Node3D
## Original control110 movie encounter; modern sight/reach and collision, source event outcomes.
const State=preload("res://scripts/lol2/jungle_drunk_state.gd")
const MEDIA="res://assets/lol2/generated/jungle_drunk_media/"
const SHADER=preload("res://scripts/lol2/jungle_bacatta65.gd").SHADER
var host: Node3D
var src: Dictionary
var media: Dictionary
var state: Dictionary
var inside: Array=[]
var mesh: MeshInstance3D
var body: StaticBody3D
var barrier: StaticBody3D
var voice: AudioStreamPlayer3D
var voice_segment: int=-1
var voice_elapsed: float=-1.0
var textures: Dictionary={}
var effects_log: Array=[]
static func assets_ready() -> bool: return FileAccess.file_exists(MEDIA+"media.json")
func initial() -> Dictionary: return {"version":1,"state":State.initial(),"inside":[]}
func checkpoint() -> Dictionary: return {"version":1,"state":state.duplicate(true),"inside":inside.duplicate()}
static func validate(packet: Variant) -> String:
	return preload("res://scripts/lol2/jungle_drunk_packet.gd").validate(packet)
func setup(owner_host: Node3D, saved: Variant=null) -> String:
	host=owner_host;src=State.source();media=JSON.parse_string(FileAccess.get_file_as_string(MEDIA+"media.json"))
	mesh=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(src.control.dimensions[0],src.control.dimensions[2]);quad.center_offset=Vector3(0,quad.size.y/2,0);mesh.mesh=quad
	var shader:=Shader.new();shader.code=SHADER;var material:=ShaderMaterial.new();material.shader=shader;mesh.material_override=material;add_child(mesh)
	body=StaticBody3D.new();body.collision_layer=1;body.collision_mask=0;var collider:=CollisionShape3D.new();var shape:=BoxShape3D.new();shape.size=Vector3(85,60,35);collider.shape=shape;collider.position.y=30;body.add_child(collider);add_child(body)
	barrier=StaticBody3D.new();barrier.collision_mask=0;var prism:=ConvexPolygonShape3D.new();var points:=PackedVector3Array()
	for v in src.blocked_region.polygon:
		points.append(Vector3(v[0],float(src.blocked_region.floor_min)-4,v[1]));points.append(Vector3(v[0],float(src.blocked_region.floor_max)+100,v[1]))
	prism.points=points;var barrier_shape:=CollisionShape3D.new();barrier_shape.shape=prism;barrier.add_child(barrier_shape);add_child(barrier)
	voice=AudioStreamPlayer3D.new();voice.stream=AudioStreamWAV.load_from_file(MEDIA+"voice.wav");voice.unit_size=300;add_child(voice)
	return restore(initial() if saved==null else saved)
func restore(packet: Variant) -> String:
	var error:=validate(packet)
	if not error.is_empty(): return error
	state=State.canonical(packet.state);inside=packet.inside.map(func(id):return int(id));voice.stop();voice_segment=-1;present();return ""
func origin() -> Vector3:
	var offset=host.get("native_translation")
	return offset if offset is Vector3 else Vector3.ZERO
func anchor() -> Vector3:
	var p: Array=src.control.position;return Vector3(p[0],p[1],p[2])+origin()
func context() -> Dictionary:
	return {"locals":{"7":int(host.village_alarm.state.locals["7"])},"shared":{"29":int(host.village_gate.state().shared29)}}
func movement_locked() -> bool: return not state.is_empty() and bool(state.hold)
func input_locked() -> bool: return movement_locked()
## Chief-hut g4442: op8 control110 property1 stops its current playback.
func stop_external() -> void:
	State.stop(state);state.blocked=false;present()
func live() -> bool: return is_instance_valid(host.starting_magic) and host.starting_magic.world_active() and not get_tree().paused
func dispatch(kind: String, owner: int, code: int, value: int=0) -> void:
	apply(State.event(state,src,kind,owner,code,value,context()));present()
func apply(effects: Array) -> void:
	for e in effects:
		effects_log.append(e)
		match str(e.type):
			"local7": host.village_alarm.state.locals["7"]=int(e.value)
			"soul":
				if not host.quest_state.has("monastery"):host.quest_state.monastery=preload("res://scripts/lol2/monastery_quest_state.gd").initial()
				var bank: Dictionary=host.quest_state.monastery.globals
				bank.GV_LUTHERS_SOUL=clampi(preload("res://scripts/lol2/shared_global_defaults.gd").read(bank,"GV_LUTHERS_SOUL")+int(e.delta),0,10)
			"reposition": host.player.global_position=Vector3(e.position[0],e.position[1],e.position[2])+origin()+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET;host.player.velocity=Vector3.ZERO
	if effects_log.size()>100:effects_log=effects_log.slice(-100)
func aimed() -> bool:
	if not state.present or int(state.segment)<0 or not live(): return false
	var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,host.camera.global_position-host.camera.global_basis.z*140,1,[host.player.get_rid(),barrier.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.collider==body
func offer() -> bool:
	if not aimed() or movement_locked() or int(state.owner_state)!=0:return false
	dispatch("control",110,4);return true
func strike() -> bool:
	if not aimed() or movement_locked() or (int(host.player_form)==0 and str(host.equipped_item)==""):return false
	dispatch("control",110,9);return true
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and offer():get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and strike():get_viewport().set_input_as_handled()
func visible_starter(row: Dictionary) -> bool:
	var p: Array=row.position;var target:=Vector3(p[0],p[1]+40,p[2])+origin()
	if host.camera.global_position.distance_to(target)>1000 or not host.camera.is_position_in_frustum(target):return false
	var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,target,1,[host.player.get_rid(),body.get_rid(),barrier.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func advance(delta: float) -> void:
	if state.is_empty():return
	voice.stream_paused=not live()
	if not live() or not is_finite(delta) or delta<=0:return
	var local7: int=context().locals["7"]
	# Retirement must release the temporary barrier even if a movie-end removal happened before the next sight event.
	if local7==2:
		state.present=false;State.stop(state);state.blocked=false
	elif local7==0 and int(state.segment)<0:
		for row in src.starters:
			if visible_starter(row):dispatch("prop",int(row.id),5);break
	var now: Array=[];var pos: Vector3=host.player.global_position-origin();var foot: float=pos.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	for region in src.regions:
		var poly:=PackedVector2Array()
		for v in region.polygon:poly.append(Vector2(v[0],v[1]))
		if foot<float(region.floor_min)-4 or foot>float(region.floor_max)+6 or not Geometry2D.is_point_in_polygon(Vector2(pos.x,pos.z),poly):continue
		now.append(int(region.id))
		if int(region.id) not in inside:dispatch("region",int(region.id),2)
	inside=now
	apply(State.advance(state,src,delta,context()));present()
func present() -> void:
	if state.is_empty():return
	mesh.global_position=anchor();body.global_position=anchor();voice.global_position=anchor();barrier.global_position=origin()
	mesh.visible=state.present and int(state.segment)>=0;body.collision_layer=1 if mesh.visible else 0;barrier.collision_layer=1 if state.blocked else 0
	if not mesh.visible:voice.stop();voice_segment=-1;return
	var segment: Dictionary=media.segments[int(state.segment)];var frame:=mini(int(segment.last),int(segment.first)+int(float(state.elapsed)*15))
	if not textures.has(frame):
		if textures.size()>90:textures.clear()
		textures[frame]=ImageTexture.create_from_image(Image.load_from_file(MEDIA+str(media.frames[frame])))
	mesh.material_override.set_shader_parameter("frame",textures[frame])
	if voice_segment!=int(state.segment) or float(state.elapsed)<voice_elapsed:
		voice_segment=int(state.segment);voice.play(float(segment.first)/15+float(state.elapsed))
	voice_elapsed=float(state.elapsed)
	voice.stream_paused=not live()
func _physics_process(delta: float) -> void:advance(delta)
