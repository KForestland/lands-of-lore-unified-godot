extends Node3D
## Live actor62 (Huline, definition1 TIG_MAL): source region link + event20 greeting (jungle_actor62_state.gd)
## with his four original lines played at his body, his source talk pose (selector4, 16 views) and the native
## sound-finished chain, using the unchanged generic creature owner for his body.
## Producers: grounded entry into regions 1672/1698/1703 (edge, saved); the line clock (decoded duration).
## Player/actor repositions (opcode18) are applied as instant moves (adapter: native stores the command at
## [0xB7D5E]). Player properties 0/1 (player+0x227 bit 0x40, meaning unverified), talk focus 5/6 and the prop1913
## sound are saved receipts. Event3 = end of his action2 clip (Grok 0xA56B3) → 29610 state11/action1/B5 0x0C;
## no attack rows are staged for him, so no combat is claimed.
const State=preload("res://scripts/lol2/jungle_actor62_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const Packet=preload("res://scripts/lol2/jungle_actor62_packet.gd")
const POP_CONFIG:={"root":"res://assets/lol2/generated/jungle_actor62/sprites/","source":"res://scripts/lol2/jungle_actor62_population_source.json",
	"target_prefix":"junglehuline","fighting_owner":"quest_state","nav":"res://assets/lol2/generated/creature_nav/L4_HJ.json",
	"names":{"1":"Huline"},"look":{"1":{"canvas":[320,240],"scale":0.47,"floor_row":206,"radius":15,"height":46}}}
const ID:="62"
const FPS:=15.0
var host: Node3D
var src: Dictionary
var state: Dictionary
var population: Node3D
var inside: Array=[]
var receipts: Array=[]
var effect_log: Array=[]
var voice: AudioStreamPlayer3D
var pose_clock:=0.0

func setup(owner_host: Node3D, saved: Variant=null) -> String:
	host=owner_host
	if not FileAccess.file_exists(State.SOURCE): return "actor62 source missing (run tools/prepare_jungle_actor62.py)."
	src=State.source()
	population=preload("res://scripts/lol2/scripted_creature_population.gd").new()
	population.name="Actor62Body";population.configure(POP_CONFIG);add_child(population)
	var error: String=population.setup(host)
	if not error.is_empty(): return error
	population.set_physics_process(false);population.set_process_unhandled_input(false);population.set_process(false)
	voice=AudioStreamPlayer3D.new();voice.unit_size=120;add_child(voice)
	return restore(saved if saved!=null else initial())

func initial() -> Dictionary:
	return {"version":1,"state":State.initial(src),"body":Generic.initial(population.src),"inside":[],"receipts":[]}
func validate(packet: Variant) -> String: return Packet.validate(packet)
func checkpoint() -> Dictionary:
	return {"version":1,"state":state.duplicate(true),"body":population.checkpoint(),"inside":inside.duplicate(),"receipts":receipts.duplicate()}
## Atomic: an invalid packet changes nothing.
func restore(packet: Variant) -> String:
	var error:=validate(packet)
	if not error.is_empty(): return error
	error=population.restore(packet.body)
	if not error.is_empty(): return error
	state=State.canonical(packet.state)
	inside=packet.inside.map(func(r):return int(r));receipts=packet.receipts.duplicate()
	_start_voice();_sync_body();_present()
	return ""

func world_active() -> bool: return host.starting_magic!=null and host.starting_magic.world_active()
func origin() -> Vector3: return population.origin()
func talking() -> bool: return not state.sound.is_empty()

func _physics_process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
	var running: bool=world_active() and not get_tree().paused
	if is_instance_valid(voice): voice.stream_paused=not running
	if not is_finite(delta) or delta<=0 or not running: return
	_regions()
	_apply(State.advance(state,src,delta))
	pose_clock=fmod(pose_clock+delta,1000.0)
	_sync_body();_present()

func _regions() -> void:
	var p: Vector3=host.player.global_position-origin()
	var foot: float=p.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	var now: Array=[]
	for region in src.regions:
		if foot<float(region.floor_min)-1 or foot>float(region.floor_max)+3: continue
		var polygon:=PackedVector2Array()
		for v in region.polygon: polygon.append(Vector2(v[0],v[1]))
		if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon): now.append(int(region.region))
	for r in now:
		if r not in inside:
			state.region=-1
			_apply(State.enter_region(state,src,r))
	inside=now

func _sync_body() -> void:
	var body: Dictionary=population.state.actors[ID]
	if state.present and not body.present: Generic.spawn(population.state,ID)
	elif not state.present and body.present: body.present=false
	population.state.live[ID].mode=Live.IDLE

func _apply(effects: Array) -> void:
	for e in effects:
		effect_log.append(e)
		match str(e.type):
			"sound": _start_voice()
			"reposition": _move_player(e.position)
			"actor_reposition": _move_actor(e.position,int(e.heading))
			"external","actor_property","actor_command","player_property":
				var key:=str(e.get("raw",""))
				if not key.is_empty() and key not in receipts and receipts.size()<Packet.MAX_RECEIPTS: receipts.append(key)
	if effect_log.size()>200: effect_log=effect_log.slice(effect_log.size()-200)

func _floor(target: Vector3) -> Vector3:
	var down:=PhysicsRayQueryParameters3D.create(target+Vector3.UP*400,target-Vector3.UP*800,1,[host.player.get_rid(),population.bodies[ID].get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(down)
	return hit.position if not hit.is_empty() else target

func _move_player(p: Array) -> void:
	var target:=_floor(Vector3(p[0],0,p[2])+origin())
	host.player.global_position=target+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET;host.player.velocity=Vector3.ZERO

func _move_actor(p: Array, heading: int) -> void:
	var target:=_floor(Vector3(p[0],0,p[2])+origin())-origin()
	var body: Dictionary=population.state.actors[ID]
	body.position=[snappedf(target.x,1.0/1024),snappedf(target.y,1.0/1024),snappedf(target.z,1.0/1024)]
	population.state.live[ID].heading=heading&65535
	population.bodies[ID].global_position=target+origin()

func _start_voice() -> void:
	voice.stop()
	if state.sound.is_empty(): return
	voice.stream=AudioStreamWAV.load_from_file(str(src.voice[str(int(state.sound.request))].path))
	voice.global_position=population.bodies[ID].global_position+Vector3.UP*40
	if float(state.sound.elapsed)<float(voice.stream.get_length()): voice.play(float(state.sound.elapsed))

## While his lines play: his source pose (op13 sub4) in the generic view mapping; otherwise the generic idle
## presentation (no source command resets the pose afterwards, so it is not extended past the talk).
func _present() -> void:
	population.present()
	if not state.present or not population.materials.has(ID): return
	if not state.anim.is_empty():
		# His source action clip (action2 → selector5), played once; its end is event3.
		var row: Dictionary=src.actions[str(int(state.anim.action))]
		var frame:=mini(int(floor(float(state.anim.elapsed)*FPS)),int(row.frames)-1)
		population.library.present(population.materials[ID],1,int(row.selector),frame,population._view(ID,population.library.view_count(1,int(row.selector))))
		return
	if not talking() or int(state.selector)==0: return
	var sel:=int(state.selector)
	var frames:=int(src.poses[str(sel)].frames)
	population.library.present(population.materials[ID],1,sel,int(floor(pose_clock*FPS))%frames,population._view(ID,population.library.view_count(1,sel)))

func targets() -> Dictionary: return {}
