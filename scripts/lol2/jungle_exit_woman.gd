extends Node3D
## Live pre-exit L4WW conversation: prop554 (template83) and actors 0/66 on the Jungle host.
## Composes jungle_exit_woman_state.gd (source groups, clip clocks, generation guards) with the unchanged
## generic creature owner for the L4WW bodies, presents the original in-world VQA frames and voices, holds
## player input while the source hold (player property 0x26/0x27) is active and repositions the player.
## Producers: grounded entry into source regions 4387/4407/1902/1903/1907 (saved inside-set); first
## sighting = prop554 inside the production camera frustum with an unobstructed ray (kind5, as for Dawn);
## armed melee aimed at the prop is the kind9 hit (context after=0, like prop552); the exit guard spawn
## (exit local56 >= 1, group10720) runs its prop554/local1 commands once.
## L4WW bodies (goal3, no target) return to their placement home node and raise their own kind6 value8
## on arrival (native A267C → A2704 → A29EA), which removes them through their source groups 28230/31228.
## Adapters: the frame track has no picture of its own (one template frame); the walk uses the shared
## creature speed along the pinned certified-route segment 164→170 (the shared nav graph stops at 165); arrival = horizontal distance <= HOME_EXTENT (the native test is
## the 111ECC output minus the vtable+0x14 extent, not replayed).
const State=preload("res://scripts/lol2/jungle_exit_woman_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Packet=preload("res://scripts/lol2/jungle_exit_woman_packet.gd")
const MEDIA:="res://assets/lol2/generated/jungle_exit_woman_media/media.json"
const POP_CONFIG:={"root":"res://assets/lol2/generated/jungle_exit_woman_media/l4ww_sprites/","source":"res://scripts/lol2/jungle_exit_woman_population_source.json",
	"target_prefix":"jungleexitwoman","fighting_owner":"quest_state","nav":"res://assets/lol2/generated/creature_nav/L4_HJ.json",
	"names":{"6":"Huline elder"},"look":{"6":{"canvas":[320,200],"scale":0.47,"floor_row":187,"radius":20,"height":60}}}
const CLIP_SCALE:=0.47
const REACH:=96.0
const SIGHT:=1600.0
const HOME_EXTENT:=20.0
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const SHADER:="shader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform sampler2D frame : source_color, filter_nearest, repeat_disable;\nvoid vertex() {\n\tvec3 up = vec3(0.0, 1.0, 0.0);\n\tvec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));\n\tVERTEX = right * VERTEX.x + up * VERTEX.y;\n}\nvoid fragment() {\n\tvec4 c = texture(frame, UV);\n\tif (c.a < 0.5) discard;\n\tALBEDO = c.rgb;\n}\n"
var host: Node3D
var hooks: Dictionary={}
var src: Dictionary
var timing: Dictionary
var media: Dictionary
var state: Dictionary
var population: Node3D
var inside: Array=[]
var sighted:=false
var exit_applied:=false
var effect_log: Array=[]
var mesh: MeshInstance3D
var voice: AudioStreamPlayer3D
var voice_generation:=-1
## Highest playback generation any exit-woman presenter in this process has issued. Runtime only (never
## saved or restored): every restore resumes above it, so repeated loads never reuse a generation.
static var generation_high_water:=0
var prop_body: StaticBody3D
var textures: Dictionary={}

static func assets_ready() -> bool:
	return FileAccess.file_exists(MEDIA) and FileAccess.file_exists(State.SOURCE) and FileAccess.file_exists(str(POP_CONFIG.source))

func setup(owner_host: Node3D, supplied_hooks: Dictionary={}, saved: Variant=null) -> String:
	host=owner_host;hooks=supplied_hooks
	src=State.source();timing=State.timing()
	if timing.is_empty(): return "Exit conversation media missing (run tools/prepare_jungle_exit_woman_media.py)."
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(MEDIA))
	if not parsed is Dictionary or str(parsed.get("source_sha256",""))!=FileAccess.get_sha256(State.SOURCE): return "Exit conversation media does not match the source contract."
	media=parsed
	population=preload("res://scripts/lol2/scripted_creature_population.gd").new()
	population.name="ExitWomanBodies";population.configure(POP_CONFIG);add_child(population)
	var error: String=population.setup(host)
	if not error.is_empty(): return error
	population.set_physics_process(false);population.set_process(false);population.set_process_unhandled_input(false)
	var shader:=Shader.new();shader.code=SHADER
	mesh=MeshInstance3D.new();mesh.mesh=QuadMesh.new()
	var material:=ShaderMaterial.new();material.shader=shader;mesh.material_override=material
	mesh.visible=false;add_child(mesh)
	voice=AudioStreamPlayer3D.new();voice.unit_size=160;voice.max_distance=1200;add_child(voice)
	prop_body=StaticBody3D.new();prop_body.collision_layer=1;prop_body.collision_mask=0
	var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=24;cylinder.height=80
	shape.shape=cylinder;shape.position.y=40;prop_body.add_child(shape);add_child(prop_body)
	prop_body.set_meta("exit_woman_prop",int(src.prop.id))
	return restore(saved if saved!=null else initial())

## ---- saved packet ----------------------------------------------------------------------------
func initial() -> Dictionary:
	return {"version":1,"conversation":State.initial(src),"body":Generic.initial(population.src),"inside":[],"sighted":false,"exit_applied":false}

func checkpoint() -> Dictionary:
	return {"version":1,"conversation":state.duplicate(true),"body":population.checkpoint(),"inside":inside.duplicate(),"sighted":sighted,"exit_applied":exit_applied}

## Atomic: an invalid packet changes nothing. Restoring starts a new playback generation, so any
## callback from the replaced presentation is stale.
func restore(packet: Variant) -> String:
	var error:=Packet.validate(packet)
	if not error.is_empty(): return error
	error=population.restore(packet.body)
	if not error.is_empty(): return error
	state=State.canonical(packet.conversation);State.restored(state,generation_high_water);_note_generation()
	inside=packet.inside.map(func(r):return int(r));sighted=bool(packet.sighted);exit_applied=bool(packet.exit_applied)
	voice.stop();voice_generation=-1
	_sync_voice();_sync_bodies();_present()
	return ""

## ---- host links ------------------------------------------------------------------------------
func origin() -> Vector3: return population.origin()

func world_active() -> bool:
	return host.starting_magic!=null and host.starting_magic.world_active()

func input_locked() -> bool: return state!=null and not state.is_empty() and bool(state.hold)

func exit_node() -> Node:
	if hooks.has("exit"): return hooks.exit
	return host.get("exit_encounter")

func prop_anchor() -> Vector3:
	return Vector3(float(src.prop.position[0]),float(src.prop.position[1]),float(src.prop.position[2]))+origin()

## ---- producers -------------------------------------------------------------------------------
func visible_to_camera() -> bool:
	if not state.prop.present: return false
	var point: Vector3=prop_anchor()+Vector3.UP*40
	var eye: Vector3=host.camera.global_position
	if eye.distance_to(point)>SIGHT or not host.camera.is_position_in_frustum(point): return false
	var ray:=PhysicsRayQueryParameters3D.create(eye,point,1,[host.player.get_rid(),prop_body.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _aimed_prop() -> bool:
	if not state.prop.present or host.get_tree().paused: return false
	if host.get("interface_hud")!=null and is_instance_valid(host.interface_hud) and host.interface_hud.cursor_active: return false
	var target: Vector3=prop_anchor()+Vector3.UP*40
	var offset: Vector3=target-host.camera.global_position
	if offset.length()>REACH+24 or offset.length()<0.01: return false
	var query:=PhysicsRayQueryParameters3D.create(host.camera.global_position,host.camera.global_position-host.camera.global_basis.z*(REACH+40),1,[host.player.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider==prop_body

func can_strike() -> bool:
	if not world_active() or not _aimed_prop(): return false
	return not (int(host.get("player_form"))==0 and str(host.get("equipped_item"))=="")

## Armed melee is the hit producer (masks any, after=0 <= threshold2), as for prop552.
func strike() -> bool:
	if not can_strike(): return false
	var effects:=State.hit(state,src,{"mask0":1,"mask2":1,"after":0})
	_apply(effects);_present()
	return not effects.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and strike():
		get_viewport().set_input_as_handled()

## Guarded media endpoints for any external presenter: stale selector/generation/track calls do nothing.
func media_selector_finished(selector: int, generation: int) -> bool:
	var effects:=State.selector_finished(state,src,selector,generation)
	_apply(effects);_present();return not effects.is_empty()

func media_clip_ended(selector: int, generation: int) -> bool:
	var effects:=State.clip_ended(state,src,selector,generation)
	_apply(effects);_present();return not effects.is_empty()

## ---- step ----------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	# A failed setup leaves the component inert rather than half-built.
	if state==null or state.is_empty() or voice==null: return
	var running: bool=world_active() and not get_tree().paused
	voice.stream_paused=not running
	if not is_finite(delta) or delta<=0 or not running: return
	_poll_exit()
	if not sighted and visible_to_camera():
		sighted=true;_apply(State.sighted(state,src))
	_regions()
	_apply(State.advance(state,src,timing,delta))
	_walk_home(delta)
	_present()

func _poll_exit() -> void:
	if exit_applied: return
	var exit: Node=exit_node()
	if exit==null or not exit.get("encounter") is Dictionary: return
	if int(exit.encounter.get("locals",{}).get("56",0))>=1:
		exit_applied=true;_apply(State.external_commands(state,src,src.external["1:10720"]))

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
		if r not in inside: _apply(State.enter_region(state,src,r))
	inside=now

## ---- effects ---------------------------------------------------------------------------------
func _note_generation() -> void:
	generation_high_water=maxi(generation_high_water,int(state.prop.generation))
	if int(state.prop.generation)>=State.MAX_GENERATION: push_error("Exit conversation playback generations exhausted; callbacks are refused.")

func _apply(effects: Array) -> void:
	_note_generation()
	for e in effects:
		effect_log.append(e)
		match str(e.type):
			"reposition": _reposition(e)
			"focus":
				if e.held: _face_speaker()
			"clip_start", "clip_stop", "frames_start", "prop_presence": _sync_voice()
			"spawn", "remove": _sync_bodies()
		if hooks.has("effects") and hooks.effects is Callable and hooks.effects.is_valid() and str(e.type)!="group": hooks.effects.call(e)
	if effect_log.size()>600: effect_log=effect_log.slice(effect_log.size()-600)
	_sync_voice()

func _reposition(e: Dictionary) -> void:
	var p: Array=e.position
	var target:=Vector3(p[0],host.player.global_position.y,p[2])+Vector3(origin().x,0,origin().z)
	var down:=PhysicsRayQueryParameters3D.create(target+Vector3.UP*400,target-Vector3.UP*800,1,[host.player.get_rid(),prop_body.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(down)
	if not hit.is_empty(): target.y=hit.position.y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	host.player.global_position=target;host.player.velocity=Vector3.ZERO
	_face_speaker()

## Player focus on prop554 (opcode2 property5, DD5DC) and the reposition both face the speaker.
func _face_speaker() -> void:
	var look:=Vector3(prop_anchor().x,host.player.global_position.y,prop_anchor().z)
	if look.distance_to(host.player.global_position)>0.1: host.player.look_at(look);host.camera.rotation=Vector3.ZERO

## Only the sounded clip track has a voice; it follows the clip clock and its generation.
func _sync_voice() -> void:
	var c: Dictionary=state.prop.clip
	if c.is_empty() or not state.prop.present:
		if voice.playing: voice.stop()
		voice_generation=-1;return
	if voice_generation==int(c.generation) and voice.playing: return
	var row: Dictionary=media.clips[str(int(c.selector))]
	voice.stop();voice_generation=int(c.generation)
	if row.audio==null: return
	voice.stream=AudioStreamWAV.load_from_file(str(row.audio))
	voice.global_position=prop_anchor()+Vector3.UP*40
	if float(c.elapsed)<float(voice.stream.get_length()): voice.play(float(c.elapsed))

func _sync_bodies() -> void:
	for id in src.actors:
		var linked: bool=bool(state.actors[id].present)
		var body: Dictionary=population.state.actors[id]
		if linked and not body.present:
			Generic.spawn(population.state,id)
			body=population.state.actors[id]
			body.woken=true;body.rise=Generic.clip_seconds(int(population.src.definitions["6"].clips.rise.frames))
		elif not linked and body.present:
			var fresh: Dictionary=Generic.initial(population.src)
			population.state.actors[id]=fresh.actors[id].duplicate(true);population.state.live[id]=fresh.live[id].duplicate(true)
	population.present()

## Goal3 home return: a risen body walks to its home node; arrival raises its own kind6 value8.
func _walk_home(delta: float) -> void:
	var moved:=false
	for id in src.actors:
		var a: Dictionary=population.state.actors[id]
		if not state.actors[id].present or not a.present or not Generic.ready_to_fight(population.state,population.src,id): continue
		var body: CharacterBody3D=population.bodies[id]
		var live: Dictionary=population.state.live[id]
		var home: Vector3=Vector3(float(src.actors[id].home[0]),0,float(src.actors[id].home[2]))+Vector3(origin().x,0,origin().z)
		var offset:=Vector2(home.x-body.global_position.x,home.z-body.global_position.z)
		if offset.length()<=HOME_EXTENT:
			live.mode=Live.IDLE
			_apply(State.actor_event(state,src,int(id),6,8));continue
		var target: Vector2=_home_target(id,Vector2(body.global_position.x,body.global_position.z)-Vector2(origin().x,origin().z))
		var steer:=Vector3(target.x+origin().x-body.global_position.x,0,target.y+origin().z-body.global_position.z)
		var direction:=steer.normalized() if steer.length()>0.01 else Vector3.ZERO
		var before: Vector3=body.global_position
		# move_and_slide integrates over the physics step; scale so the walk follows this component's clock.
		var scale: float=delta/maxf(body.get_physics_process_delta_time(),0.0001)
		body.velocity=Vector3(direction.x*Generic.SPEED,0 if body.is_on_floor() else body.velocity.y-128*delta,direction.z*Generic.SPEED)*scale
		body.move_and_slide()
		body.velocity/=scale
		var travel: Vector3=body.global_position-before
		if Vector2(travel.x,travel.z).length()>0.001:
			live.mode=Live.PURSUE;population.clocks[id]=float(population.clocks.get(id,0.0))+delta
			live.heading=Live.heading_units(Vector2(travel.x,-travel.z))
		a.position=Live.saved_position(body.position-origin());moved=true
	if moved: population.present()

## Next point on the pinned grounded home path (certified route segment, then the home node), derived
## from the body position alone: the nearest path point, or the one after it once reached or passed.
func _home_target(id: String, at: Vector2) -> Vector2:
	var points: Array=src.home_path.points.map(func(p): return Vector2(float(p[0]),float(p[1])))
	points.append(Vector2(float(src.actors[id].home[0]),float(src.actors[id].home[2])))
	var k:=0
	for i in points.size():
		if at.distance_to(points[i])<at.distance_to(points[k]): k=i
	if k+1<points.size() and (at.distance_to(points[k])<24.0 or at.distance_to(points[k+1])<points[k].distance_to(points[k+1])): k+=1
	return points[k]

## ---- presentation ----------------------------------------------------------------------------
func _texture(path: String) -> Texture2D:
	if not textures.has(path):
		if textures.size()>96: textures.clear()
		textures[path]=ImageTexture.create_from_image(Image.load_from_file(path))
	return textures[path]

## The sounded clip shows its frames; otherwise the frame track; otherwise the selector's first frame.
func current_frame() -> Dictionary:
	if not state.prop.present: return {}
	var track: Dictionary=state.prop.clip if not state.prop.clip.is_empty() else state.prop.frames
	var selector: int=int(track.selector) if not track.is_empty() else int(state.prop.selector)
	var row: Dictionary=media.clips[str(selector)]
	var index:=0
	if not track.is_empty(): index=mini(int(float(track.elapsed)*float(row.fps)),int(row.frames)-1)
	return {"selector":selector,"frame":index,"row":row}

func _present() -> void:
	prop_body.global_position=prop_anchor()
	prop_body.process_mode=Node.PROCESS_MODE_INHERIT if state.prop.present else Node.PROCESS_MODE_DISABLED
	prop_body.collision_layer=1 if state.prop.present else 0
	var f:=current_frame()
	mesh.visible=not f.is_empty()
	if f.is_empty(): return
	var row: Dictionary=f.row
	var quad: QuadMesh=mesh.mesh
	quad.size=Vector2(float(row.width),float(row.height))*CLIP_SCALE;quad.center_offset=Vector3(0,quad.size.y/2.0,0)
	mesh.global_position=prop_anchor()
	mesh.material_override.set_shader_parameter("frame",_texture(str(row.frame_files[int(f.frame)])))

func targets() -> Dictionary: return {}
