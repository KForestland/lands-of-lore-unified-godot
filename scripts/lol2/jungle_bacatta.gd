extends Node3D
const GlobalDefaults = preload("res://scripts/lol2/shared_global_defaults.gd")
## Live Bacatta branch: prop552 → Bacatta61 → guard60 → exit prop4398 event20.
## Composes jungle_bacatta_state.gd (source groups) with the unchanged generic creature owner for
## Bacatta's body/combat, presents the original in-world VQA clips and sounds, and drives the
## property22 escort. Exit-owned state is reached only through the exit controller's hooks
## (request_prop4398_event20, write_local) and read-only queries.
## Adapters: E-use and armed melee are the player use/hit producers (hit context after=0);
## escort follow distance 2×radius; Bacatta walk/arrival from the state; Bacatta body y from a floor ray.
const State=preload("res://scripts/lol2/jungle_bacatta_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const MEDIA:="res://assets/lol2/generated/jungle_bacatta_media/media.json"
const POP_CONFIG:={"root":"res://assets/lol2/generated/jungle_bacatta_media/bacatta_sprites/","source":"res://scripts/lol2/jungle_bacatta_population_source.json",
	"target_prefix":"junglebacatta","fighting_owner":"quest_state","nav":"res://assets/lol2/generated/creature_nav/L4_HJ.json",
	"names":{"5":"Bacatta"},"look":{"5":{"canvas":[320,200],"scale":0.47,"floor_row":187,"radius":20,"height":60}}}
const CLIP_SCALE:=0.47
const REACH:=96.0
const ESCORT_RADIUS:=20.0
const FOOT:=32.0
const SHADER:="shader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform sampler2D frame : source_color, filter_nearest, repeat_disable;\nvoid vertex() {\n\tvec3 up = vec3(0.0, 1.0, 0.0);\n\tvec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));\n\tMODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(cross(right, up), 0.0), MODEL_MATRIX[3]);\n}\nvoid fragment() {\n\tvec4 c = texture(frame, UV);\n\tif (c.a < 0.5) { discard; }\n\tALBEDO = c.rgb;\n}\n"
var host: Node3D
var hooks: Dictionary={}
var src: Dictionary
var timing: Dictionary
var media: Dictionary
var state: Dictionary
var population: Node3D
var inside: Array=[]
var sighted:=false
var effect_log: Array=[]
var meshes: Dictionary={}
var voices: Dictionary={}
var sound_players: Dictionary={}
var prop_body: StaticBody3D
var textures: Dictionary={}

func setup(owner_host: Node3D, supplied_hooks: Dictionary={}, saved: Variant=null) -> String:
	host=owner_host;hooks=supplied_hooks
	src=State.source();timing=State.timing()
	if timing.is_empty(): return "Bacatta media missing (run tools/prepare_jungle_bacatta_media.py)."
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(MEDIA))
	if not parsed is Dictionary or str(parsed.get("source_sha256",""))!=FileAccess.get_sha256(State.SOURCE): return "Bacatta media manifest does not match the source contract."
	media=parsed
	population=preload("res://scripts/lol2/scripted_creature_population.gd").new()
	population.name="BacattaBody";population.configure(POP_CONFIG);add_child(population)
	var error: String=population.setup(host)
	if not error.is_empty(): return error
	population.set_physics_process(false)
	var shader:=Shader.new();shader.code=SHADER
	for owner in ["prop552","bacatta","guard60"]:
		var mesh:=MeshInstance3D.new();mesh.mesh=QuadMesh.new()
		var material:=ShaderMaterial.new();material.shader=shader;mesh.material_override=material
		mesh.visible=false;add_child(mesh);meshes[owner]=mesh
		var voice:=AudioStreamPlayer3D.new();add_child(voice);voices[owner]=voice
	prop_body=StaticBody3D.new();prop_body.collision_layer=1;prop_body.collision_mask=0
	var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=28;cylinder.height=90
	shape.shape=cylinder;shape.position.y=45;prop_body.add_child(shape);add_child(prop_body)
	prop_body.set_meta("bacatta_prop",552)
	return restore(saved if saved!=null else initial())

## ---- saved packet ------------------------------------------------------------------------
func initial() -> Dictionary:
	return {"version":1,"branch":State.initial(src),"body":Generic.initial(population.src),"inside":[],"sighted":false}

func validate(packet: Variant) -> String:
	return preload("res://scripts/lol2/jungle_bacatta_packet.gd").validate(packet)

func checkpoint() -> Dictionary:
	return {"version":1,"branch":state.duplicate(true),"body":population.checkpoint(),"inside":inside.duplicate(),"sighted":sighted}

## Atomic: an invalid packet changes nothing.
func restore(packet: Variant) -> String:
	var error:=validate(packet)
	if not error.is_empty(): return error
	error=population.restore(packet.body)
	if not error.is_empty(): return error
	state=State.canonical(packet.branch)
	inside=packet.inside.map(func(r):return int(r));sighted=bool(packet.sighted)
	for owner in voices: voices[owner].stop()
	for player in sound_players.values(): player.queue_free()
	sound_players.clear()
	for owner in ["prop552","bacatta","guard60"]:
		if not state[owner].clip.is_empty(): _start_voice(owner)
	for s in state.sounds: _play_sound(int(s.request),float(s.elapsed))
	_sync_body(0.0);_present()
	return ""

## ---- host links ---------------------------------------------------------------------------
func exit_node() -> Node:
	if hooks.has("exit"): return hooks.exit
	return host.get("exit_encounter")

func world_active() -> bool:
	return host.starting_magic!=null and host.starting_magic.world_active()

func origin() -> Vector3: return population.origin()

func context() -> Dictionary:
	var ctx: Dictionary={}
	if hooks.has("context") and hooks.context is Callable and hooks.context.is_valid():
		var value=hooks.context.call()
		if value is Dictionary: ctx=value.duplicate(true)
	if not ctx.has("shared"):
		var globals: Dictionary=host.quest_state.get("monastery",{}).get("globals",{}) if host.get("quest_state") is Dictionary else {}
		var shared: Dictionary={}
		for id in src.shared_names: shared[id]=int(globals.get(str(src.shared_names[id]),GlobalDefaults.initial_value(str(src.shared_names[id]))))
		ctx.shared=shared
	if not ctx.has("locals"): ctx.locals={"41":0}
	ctx.guard60=_guard60()
	return ctx

func _guard60() -> Dictionary:
	var exit: Node=exit_node()
	if exit==null or not exit.get("encounter") is Dictionary: return {"present":false,"alive":false}
	if exit.has_method("actor_alive"): return {"present":true,"alive":bool(exit.actor_alive(60))}
	var a: Dictionary=exit.encounter.actors.get("60",{})
	return {"present":bool(a.get("present",false)),"alive":not bool(a.get("defeated",true))}

func _exit_movie_active() -> bool:
	var exit: Node=exit_node()
	return exit!=null and exit.has_method("active") and exit.active()

## Player input is locked while the property22 escort holds (host gates its own input on this).
func input_locked() -> bool: return bool(state.get("escort",false))

## ---- producers ---------------------------------------------------------------------------
func _aimed_prop() -> bool:
	if not state.prop552.present or host.get_tree().paused: return false
	if host.get("interface_hud")!=null and is_instance_valid(host.interface_hud) and host.interface_hud.cursor_active: return false
	var target: Vector3=prop_body.global_position+Vector3.UP*45
	var offset: Vector3=target-host.camera.global_position
	if offset.length()>REACH+28 or offset.length()<0.01: return false
	var query:=PhysicsRayQueryParameters3D.create(host.camera.global_position,host.camera.global_position-host.camera.global_basis.z*(REACH+40),1,[host.player.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider==prop_body

func can_use() -> bool: return world_active() and not input_locked() and _aimed_prop()

func can_strike() -> bool:
	if not world_active() or input_locked() or not _aimed_prop() or not state.prop552.armed: return false
	return not (int(host.get("player_form"))==0 and str(host.get("equipped_item"))=="")

func use() -> bool:
	if not can_use(): return false
	var effects:=State.use(state,src,timing,context())
	_apply(effects);_present()
	return not effects.is_empty()

## Armed melee is the hit producer (adapter context: masks any, after=0 ≤ threshold2).
func strike() -> bool:
	if not can_strike(): return false
	var effects:=State.hit(state,src,timing,{"mask0":1,"mask2":1,"after":0,"special":0},context())
	_apply(effects);_present()
	return not effects.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and use():
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and strike():
		get_viewport().set_input_as_handled()

## Commands other components run on prop552 (exit group10720 loop, region4435/guard-hit removal).
func external_commands(commands: Array) -> void:
	_apply(State.external_commands(state,src,timing,commands,context()));_present()

## ---- step ------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	# Voices follow the clip clocks: gated world (or the exit's own movie) pauses them with the clocks.
	var running: bool=world_active() and not get_tree().paused and not _exit_movie_active()
	for v in voices.values()+sound_players.values():
		if is_instance_valid(v): v.stream_paused=not running
	if not is_finite(delta) or delta<=0 or not running: return
	var ctx:=context()
	_poll_exit()
	_regions(ctx)
	_apply(State.advance(state,src,timing,delta,ctx))
	_escort(delta)
	_sync_body(delta)
	_present()

## Exit-owned groups that run prop552 commands: first-visibility group10720 (exit latch seen/local56),
## and region4435/guard-hit removals (exit local42 reaches 2/3 while prop552 is still present).
func _poll_exit() -> void:
	var exit: Node=exit_node()
	if exit==null or not exit.get("encounter") is Dictionary: return
	var locals: Dictionary=exit.encounter.get("locals",{})
	if not sighted and state.prop552.present and int(locals.get("56",0))>=1:
		sighted=true;external_commands(src.external_prop552["10720"])
	if state.prop552.present and int(state.prop552.state)==0 and int(locals.get("42",0))>=2:
		external_commands(src.external_prop552["17646"])

func _regions(ctx: Dictionary) -> void:
	var p: Vector3=host.player.global_position-origin()
	var foot: float=p.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	var now: Array=[]
	for region in src.regions:
		if int(region.region)!=1921: continue
		if foot<float(region.floor_min)-1 or foot>float(region.floor_max)+3: continue
		var polygon:=PackedVector2Array()
		for v in region.polygon: polygon.append(Vector2(v[0],v[1]))
		if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon): now.append(1921)
	for r in now:
		if r not in inside: _apply(State.enter_region(state,src,timing,r,ctx))
	inside=now

## Native D4D1E: the player turns toward and walks to the +0x81 object while farther than 2×radius.
func _escort(delta: float) -> void:
	var target: Variant=State.escort_target(state)
	if target==null: return
	var goal:=Vector3(target.x,0,target.y)+Vector3(origin().x,0,origin().z)
	var here: Vector3=host.player.global_position
	var flat:=Vector3(goal.x-here.x,0,goal.z-here.z)
	if flat.length()>2.0*ESCORT_RADIUS:
		host.move_grounded(flat.normalized(),delta)
	if flat.length()>0.01: host.player.rotation.y=atan2(-flat.x,-flat.z)

func _sync_body(delta: float) -> void:
	var b: Dictionary=state.bacatta
	var body: Dictionary=population.state.actors["61"]
	if b.present and not body.present: Generic.spawn(population.state,"61")
	elif not b.present and body.present:
		var fresh: Dictionary=Generic.initial(population.src)
		population.state.actors["61"]=fresh.actors["61"].duplicate(true);population.state.live["61"]=fresh.live["61"].duplicate(true)
	# Only a hostile Bacatta takes generic strikes or shows the aim label; the friendly escort cannot be hit.
	var hostile: bool=b.present and State.bacatta_fighting(state)
	population.set_process_unhandled_input(hostile);population.set_process(hostile)
	if is_instance_valid(population.label): population.label.text="" if not hostile else population.label.text
	if not b.present: population.present();return
	if hostile:
		if not body.woken: Generic.wake(population.state,"61")
		population.advance(delta)
		var at: Vector3=population.bodies["61"].position
		_apply(State.actor_moved(state,src,timing,Vector2(at.x,at.z),context()))
		return
	# Friendly/scripted: the source state owns position; the generic owner presents walk/idle frames.
	var node: CharacterBody3D=population.bodies["61"]
	var target:=Vector3(float(b.position[0]),node.position.y,float(b.position[1]))
	var ray:=PhysicsRayQueryParameters3D.create(target+origin()+Vector3.UP*300,target+origin()-Vector3.UP*600,1,[node.get_rid(),host.player.get_rid(),prop_body.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty(): target.y=hit.position.y-origin().y
	if target.distance_to(node.position)>0.01 and b.walking:
		var dir:=target-node.position;population.state.live["61"].heading=Live.heading_units(Vector2(dir.x,-dir.z))
	node.position=target;body.position=Live.saved_position(target)
	# Scripted (goal7) Bacatta needs no rise clip: woken with a completed rise clock.
	body.woken=true;body.rise=Generic.clip_seconds(int(population.src.definitions["5"].clips.rise.frames))
	population.state.live["61"].mode=Live.PURSUE if b.walking else Live.IDLE
	if b.walking: population.clocks["61"]=float(population.clocks.get("61",0.0))+delta
	population.present()

## ---- effects -------------------------------------------------------------------------------
func _apply(effects: Array) -> void:
	for e in effects:
		effect_log.append(e)
		match str(e.type):
			"shared": _write_shared(e)
			"local":
				var exit: Node=exit_node()
				if int(e.local)==42 and exit!=null and exit.has_method("write_local"): exit.write_local(42,int(e.value))
			"exit_event20":
				var exit: Node=exit_node()
				if exit!=null and exit.has_method("request_prop4398_event20"): exit.request_prop4398_event20()
			"reposition": _reposition(e)
			"prop_presence":
				var exit: Node=exit_node()
				if exit!=null and exit.has_method("set_prop_present"): exit.set_prop_present(bool(e.present))
			"clip": _start_voice(str(e.owner))
			"zero_health":
				# Ordinary death outcome on the generic body (mode0); the generic owner plays death/corpse.
				if str(e.owner)=="bacatta" and population.state.actors["61"].present and int(population.state.actors["61"].health)>0:
					Generic.damage(population.state,population.src,"61",int(population.state.actors["61"].health))
			"sound": _play_sound(int(e.request),0.0)
		if hooks.has("effects") and hooks.effects is Callable and hooks.effects.is_valid() and str(e.type)!="group": hooks.effects.call(e)
	if effect_log.size()>600: effect_log=effect_log.slice(effect_log.size()-600)

## Opcode206/199 on named globals; 0..255 clamp. Runtime caps (0x23342-44) are applied by the host hook.
func _write_shared(e: Dictionary) -> void:
	if hooks.has("shared") and hooks.shared is Callable and hooks.shared.is_valid(): hooks.shared.call(e);return
	if not host.get("quest_state") is Dictionary: return
	var monastery: Dictionary=host.quest_state.get("monastery",{})
	if not monastery.get("globals") is Dictionary: return
	var name: String=str(src.shared_names.get(str(int(e.index)),""))
	if name.is_empty(): return
	var value: int=int(monastery.globals.get(name,GlobalDefaults.initial_value(name)))
	value=int(e.value) if str(e.op)=="set" else value+int(e.value)
	var caps: Dictionary={"GV_LUTHERS_SOUL":10,"GV_DAWN_RELATIONSHIP":2,"GV_BACATTA_RELATIONSHIP":2}
	monastery.globals[name]=clampi(value,0,int(caps.get(name,255)))

func _reposition(e: Dictionary) -> void:
	var p: Array=e.position
	var target:=Vector3(p[0],host.player.global_position.y,p[2])+Vector3(origin().x,0,origin().z)
	var down:=PhysicsRayQueryParameters3D.create(target+Vector3.UP*400,target-Vector3.UP*800,1,[host.player.get_rid(),prop_body.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(down)
	if not hit.is_empty(): target.y=hit.position.y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	host.player.global_position=target;host.player.velocity=Vector3.ZERO

## ---- presentation ---------------------------------------------------------------------------
func _clip_row(owner: String, clip: Dictionary) -> Dictionary:
	return media.clips[owner][str(int(clip.selector))]

func clip_frame(owner: String) -> int:
	var clip: Dictionary=state[owner].clip
	if clip.is_empty(): return -1
	var row:=_clip_row(owner,clip)
	var first:=0;var last:=int(row.frames)-1
	if int(clip.segment)>=0:
		var seg: Dictionary=row.segments[int(clip.segment)];first=int(seg.first);last=int(seg.last)
	return mini(first+int(float(clip.elapsed)*float(row.fps)),last)

func _texture(path: String) -> Texture2D:
	if not textures.has(path):
		if textures.size()>96: textures.clear()
		textures[path]=ImageTexture.create_from_image(Image.load_from_file(path))
	return textures[path]

func _start_voice(owner: String) -> void:
	var clip: Dictionary=state[owner].clip
	var voice: AudioStreamPlayer3D=voices[owner]
	voice.stop()
	if clip.is_empty(): return
	var row:=_clip_row(owner,clip)
	if row.audio==null: return
	var start: float=float(clip.elapsed)+(float(row.segments[int(clip.segment)].first)/float(row.fps) if int(clip.segment)>=0 else 0.0)
	voice.stream=AudioStreamWAV.load_from_file(str(row.audio))
	if start<float(voice.stream.get_length()): voice.play(start)

func _play_sound(request: int, elapsed: float) -> void:
	var row: Dictionary=media.sounds.get(str(request),{})
	if row.is_empty(): return
	var player:=AudioStreamPlayer3D.new();add_child(player)
	player.stream=AudioStreamWAV.load_from_file(str(row.path))
	player.global_position=population.bodies["61"].global_position+Vector3.UP*40
	player.finished.connect(func():sound_players.erase(player.get_instance_id());player.queue_free())
	sound_players[player.get_instance_id()]=player
	if elapsed<float(row.duration): player.play(elapsed)

func _owner_anchor(owner: String) -> Variant:
	match owner:
		"prop552": return Vector3(float(src.prop552.position[0]),float(src.prop552.position[1]),float(src.prop552.position[2]))+origin()
		"bacatta": return population.bodies["61"].global_position
		"guard60":
			var exit: Node=exit_node()
			if exit!=null and exit.get("population")!=null and exit.population.bodies.has("60"): return exit.population.bodies["60"].global_position
	return null

func _present() -> void:
	prop_body.global_position=Vector3(float(src.prop552.position[0]),float(src.prop552.position[1]),float(src.prop552.position[2]))+origin()
	prop_body.process_mode=Node.PROCESS_MODE_INHERIT if state.prop552.present else Node.PROCESS_MODE_DISABLED
	prop_body.collision_layer=1 if state.prop552.present else 0
	for owner in ["prop552","bacatta","guard60"]:
		var mesh: MeshInstance3D=meshes[owner]
		var o: Dictionary=state[owner]
		var showing: bool=not o.clip.is_empty() and (owner!="prop552" or o.present) and (owner!="bacatta" or o.present)
		var anchor: Variant=_owner_anchor(owner)
		if anchor==null: showing=false
		mesh.visible=showing
		if owner=="bacatta" and population.meshes.has("61"): population.meshes["61"].visible=bool(o.present) and not showing
		if owner=="guard60":
			var exit: Node=exit_node()
			if exit!=null and exit.get("population")!=null and exit.population.meshes.has("60") and not o.clip.is_empty(): exit.population.meshes["60"].visible=not showing
		if not showing: continue
		var row:=_clip_row(owner,o.clip)
		var quad: QuadMesh=mesh.mesh
		quad.size=Vector2(float(row.width),float(row.height))*CLIP_SCALE;quad.center_offset=Vector3(0,quad.size.y/2.0,0)
		mesh.global_position=anchor
		mesh.material_override.set_shader_parameter("frame",_texture(str(row.frame_files[clip_frame(owner)])))

func targets() -> Dictionary:
	return population.targets() if State.bacatta_fighting(state) else {}
