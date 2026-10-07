extends Node3D
## Live Huline village alarm on the Jungle host. Composes jungle_village_alarm_state.gd with the existing owners:
## - the Kelsrick owner runs every command on his locals (8/32/33/52), B5/flags and the shared globals (soul −2,
##   alert), through run_external();
## - the village gate closes its leaves 78/79 when this owner reports target0 (jungle_village_gate.alarm_closed());
## - Bacatta57 shuts its door 56/57 (shut_doors()).
## This owner keeps the control77/216/217 timers, local7, the movable targets and the receipts.
## Adapters (docs/jungle-village-alarm.md):
## - grounded edge entry into region3805;
## - bells (sound 403) at prop510, not restarted while playing;
## - modern arrows: a visible fast bolt from the archer control toward Luther, fired only within FIRE_RANGE with a
##   clear line, with ARROW_DAMAGE; native damage/speed tables are not replayed;
## - arrows in flight are transient (not saved).
const State=preload("res://scripts/lol2/jungle_village_alarm_state.gd")
const Packet=preload("res://scripts/lol2/jungle_village_alarm_packet.gd")
const BELLS:="res://assets/lol2/generated/jungle_village_alarm/sounds/403.wav"
const FIRE_RANGE:=1400.0
const LAUNCH_HEIGHT:=80.0
const ARROW_SPEED:=900.0
const ARROW_DAMAGE:=3
const ARROW_LIFE:=3.0
const HIT_RADIUS:=20.0
var host: Node3D
var hooks: Dictionary={}
var src: Dictionary
var state: Dictionary
var inside:=false
var effect_log: Array=[]
var bells: AudioStreamPlayer3D
var arrows: Array=[]
var arrow_mesh: BoxMesh
var arrow_material: StandardMaterial3D
var fired_arrows:=0
var arrow_hits:=0

static func assets_ready() -> bool: return FileAccess.file_exists(State.SOURCE) and FileAccess.file_exists(BELLS)

func setup(owner_host: Node3D, supplied_hooks: Dictionary={}, saved: Variant=null) -> String:
	host=owner_host;hooks=supplied_hooks
	src=State.source()
	bells=AudioStreamPlayer3D.new();bells.unit_size=400;bells.max_distance=4000;add_child(bells)
	bells.stream=AudioStreamWAV.load_from_file(BELLS)
	arrow_mesh=BoxMesh.new();arrow_mesh.size=Vector3(1.5,1.5,34)
	arrow_material=StandardMaterial3D.new();arrow_material.albedo_color=Color(0.42,0.3,0.16);arrow_material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	return restore(saved if saved!=null else initial())

func initial() -> Dictionary: return {"version":1,"state":State.initial(src),"inside":false}
func checkpoint() -> Dictionary: return {"version":1,"state":state.duplicate(true),"inside":inside}

## Atomic: an invalid packet changes nothing. Arrows in flight are dropped.
func restore(packet: Variant) -> String:
	var error:=Packet.validate(packet)
	if not error.is_empty(): return error
	state=State.canonical(packet.state);inside=bool(packet.inside)
	_clear_arrows();bells.stop()
	return ""

func origin() -> Vector3:
	var value=host.get("native_translation")
	return value if value is Vector3 else Vector3.ZERO
func world_active() -> bool: return host.starting_magic!=null and host.starting_magic.world_active()
func movable_target(index: int) -> int: return int(state.movables.get(str(index),-1)) if state!=null and not state.is_empty() else -1
func running(index: int) -> bool:
	var timers: Array=state.timers.get(str(index),[])
	return timers.any(func(t): return (int(t.flags)&1)==0)

## Predicate inputs: shared29 (village gate, sole owner) and the Kelsrick-owned locals.
func context() -> Dictionary:
	if hooks.has("context") and hooks.context is Callable and hooks.context.is_valid():
		var value=hooks.context.call()
		if value is Dictionary: return value
	return {"shared":{},"locals":{}}

## Another owner's op14 on these controls (Bacatta57 g10162 starts control216 index1).
func arm(raw: String) -> bool: return State.arm(state,src,raw)

## ---- step --------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	if state==null or state.is_empty(): return
	var live: bool=world_active() and not get_tree().paused
	bells.stream_paused=not live
	if not live or not is_finite(delta) or delta<=0: return
	_region()
	_apply(State.advance(state,src,delta,context()))
	_fly(delta)

func _region() -> void:
	var p: Vector3=host.player.global_position-origin()
	var foot: float=p.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	var polygon:=PackedVector2Array()
	for v in src.region.polygon: polygon.append(Vector2(v[0],v[1]))
	var now: bool=foot>=float(src.region.floor_min)-1 and foot<=float(src.region.floor_max)+3 and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon)
	if now and not inside: _apply(State.enter_region(state,src,int(src.region.region),context()))
	inside=now

func _apply(effects: Array) -> void:
	for e in effects:
		if str(e.type)!="sound" or effect_log.is_empty() or str(effect_log[-1].type)!="sound": effect_log.append(e)
		match str(e.type):
			"kelsrick": _kelsrick(e)
			"movable":
				if int(e.movable) in [56,57] and int(e.target)==100: _shut_doors()
				elif int(e.movable) in [74,75] and hooks.has("inner_gate") and hooks.inner_gate is Callable and hooks.inner_gate.is_valid():
					hooks.inner_gate.call("0120%02x%02x%02x%02x"%[int(e.movable)&255,int(e.movable)>>8,int(e.target)&255,int(e.target)>>8])
			"sound": _bells()
			"arrow": _fire(int(e.control))
		if hooks.has("effects") and hooks.effects is Callable and hooks.effects.is_valid() and str(e.type) not in ["group","sound"]: hooks.effects.call(e)
	if effect_log.size()>300: effect_log=effect_log.slice(effect_log.size()-300)

func _kelsrick(e: Dictionary) -> void:
	var rest: Array=[]
	if hooks.has("kelsrick") and hooks.kelsrick is Callable and hooks.kelsrick.is_valid(): rest=hooks.kelsrick.call(int(e.group),e.commands)
	else:
		effect_log.append({"type":"kelsrick_absent","group":int(e.group)})
		return
	for r in rest:
		if str(r.type)=="local" and state.locals.has(str(int(r.index))): state.locals[str(int(r.index))]=int(r.value)
		elif r.has("raw") and str(r.raw) not in state.receipts and state.receipts.size()<State.MAX_RECEIPTS: state.receipts.append(str(r.raw))

func _shut_doors() -> void:
	if hooks.has("doors") and hooks.doors is Callable and hooks.doors.is_valid(): hooks.doors.call()

func _bells() -> void:
	var p: Array=src.sound_object.position
	bells.global_position=Vector3(float(p[0]),float(p[1]),float(p[2]))+origin()
	if not bells.playing: bells.play()

## ---- arrows ------------------------------------------------------------------------------------------------
func launch_point(control: int) -> Vector3:
	var p: Array=src.archers[str(control)].position
	return Vector3(float(p[0]),float(p[1])+LAUNCH_HEIGHT,float(p[2]))+origin()

func _aim() -> Vector3: return host.player.global_position+Vector3.UP*10

func _fire(control: int) -> void:
	var from:=launch_point(control);var to:=_aim()
	if from.distance_to(to)>FIRE_RANGE or host.starting_magic.health()<=0:
		effect_log.append({"type":"arrow_held","control":control,"reason":"range"});return
	var ray:=PhysicsRayQueryParameters3D.create(from,to,1,[host.player.get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		effect_log.append({"type":"arrow_held","control":control,"reason":"blocked"});return
	var node:=MeshInstance3D.new();node.mesh=arrow_mesh;node.material_override=arrow_material
	add_child(node);node.global_position=from;node.look_at(to)
	arrows.append({"node":node,"velocity":(to-from).normalized()*ARROW_SPEED,"life":ARROW_LIFE,"control":control})
	fired_arrows+=1

func _fly(delta: float) -> void:
	var space:=get_world_3d().direct_space_state
	for a in arrows.duplicate():
		var node: MeshInstance3D=a.node
		var from: Vector3=node.global_position;var to: Vector3=from+a.velocity*delta
		a.life=float(a.life)-delta
		var chest: Vector3=_aim()
		var ray:=PhysicsRayQueryParameters3D.create(from,to,1,[host.player.get_rid()])
		var wall: Dictionary=space.intersect_ray(ray)
		var reachable: Vector3=to if wall.is_empty() else wall.position
		var nearest:=Geometry3D.get_closest_point_to_segment(chest,from,reachable)
		if nearest.distance_to(chest)<=HIT_RADIUS:
			_hit(int(a.control));_drop(a);continue
		if not wall.is_empty() or float(a.life)<=0: _drop(a);continue
		node.global_position=to

func _hit(control: int) -> void:
	var health: int=host.starting_magic.health()
	host.starting_magic.set_health(maxi(0,health-ARROW_DAMAGE))
	arrow_hits+=1
	effect_log.append({"type":"arrow_hit","control":control,"damage":ARROW_DAMAGE})
	if host.has_method("save_feedback"): host.save_feedback("You fell. R: recover here · F9: load save" if host.starting_magic.health()==0 else "An arrow struck you.")

func _drop(a: Dictionary) -> void:
	arrows.erase(a)
	if is_instance_valid(a.node): a.node.queue_free()

func _clear_arrows() -> void:
	for a in arrows:
		if is_instance_valid(a.node): a.node.queue_free()
	arrows.clear()
