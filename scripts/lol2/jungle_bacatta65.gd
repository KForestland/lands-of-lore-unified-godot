extends Node3D
## Live Huline-alert-before-first-meeting Bacatta: prop553 (template84 talk movie) → actor65 (BACL4) on the Jungle host.
## Composes jungle_bacatta65_state.gd (pinned source groups, clocks) with the unchanged generic creature owner for
## actor65's body/combat, presents the original in-world VQA frames and voices, and repositions/faces the player.
## Producers: first sighting of prop3235 (camera frustum + unobstructed ray, as prop552/prop554); grounded entry into
## the pinned regions (saved inside-set); E-use aimed at prop553 with a carried item (kind4 mode1 offer); armed melee
## aimed at prop553 (kind9 mode1, threshold1).
## Shared globals: GV_HULINE_ALERT (shared29) is read and written only through the host hook (its owner is the
## village gate state); GV_MET_BACATTA, GV_BACATTA_RELATIONSHIP and GV_LUTHERS_SOUL are monastery globals.
## Adapters (docs/jungle-bacatta65.md): the source hold (0x26/0x27) locks movement and jumping while a spoken line
## runs, not during the BC08 idle waits; a peaceful actor65 (outcome B, A7544 own behaviour) stands at her
## placement, and striking her makes her hostile; hostile actor65 fights through the generic creature owner.
const State=preload("res://scripts/lol2/jungle_bacatta65_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Packet=preload("res://scripts/lol2/jungle_bacatta65_packet.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const POP_CONFIG:={"root":"res://assets/lol2/generated/jungle_bacatta65_media/bacatta_sprites/","source":"res://scripts/lol2/jungle_bacatta65_population_source.json",
	"target_prefix":"junglebacatta65","fighting_owner":"quest_state","nav":"res://assets/lol2/generated/creature_nav/L4_HJ.json",
	"names":{"5":"Bacatta"},"look":{"5":{"canvas":[320,200],"scale":0.47,"floor_row":187,"radius":20,"height":60}}}
const ID:="65"
const CLIP_SCALE:=0.47
const REACH:=96.0
const SIGHT:=1600.0
const SHADER:="shader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform sampler2D frame : source_color, filter_nearest, repeat_disable;\nvoid vertex() {\n\tvec3 up = vec3(0.0, 1.0, 0.0);\n\tvec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));\n\tVERTEX = right * VERTEX.x + up * VERTEX.y;\n}\nvoid fragment() {\n\tvec4 c = texture(frame, UV);\n\tif (c.a < 0.5) discard;\n\tALBEDO = c.rgb;\n}\n"
var host: Node3D
var hooks: Dictionary={}
var src: Dictionary
var timing: Dictionary
var media: Dictionary
var state: Dictionary
var population: Node3D
var inside: Array=[]
var effect_log: Array=[]
var mesh: MeshInstance3D
var voice: AudioStreamPlayer3D
var voice_key:=""
var prop_body: StaticBody3D
var textures: Dictionary={}

static func assets_ready() -> bool:
	return FileAccess.file_exists(State.MEDIA) and FileAccess.file_exists(State.SOURCE) and FileAccess.file_exists(str(POP_CONFIG.source))

func setup(owner_host: Node3D, supplied_hooks: Dictionary={}, saved: Variant=null) -> String:
	host=owner_host;hooks=supplied_hooks
	src=State.source();timing=State.timing()
	if timing.is_empty(): return "Bacatta65 media missing (run tools/prepare_jungle_bacatta65_media.py)."
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(State.MEDIA))
	if not parsed is Dictionary or str(parsed.get("source_sha256",""))!=FileAccess.get_sha256(State.SOURCE): return "Bacatta65 media does not match the source contract."
	media=parsed
	population=preload("res://scripts/lol2/scripted_creature_population.gd").new()
	population.name="Bacatta65Body";population.configure(POP_CONFIG);add_child(population)
	var error: String=population.setup(host)
	if not error.is_empty(): return error
	population.set_physics_process(false);population.set_process(false);population.set_process_unhandled_input(false)
	var shader:=Shader.new();shader.code=SHADER
	mesh=MeshInstance3D.new();mesh.mesh=QuadMesh.new()
	var material:=ShaderMaterial.new();material.shader=shader;mesh.material_override=material
	mesh.visible=false;add_child(mesh)
	voice=AudioStreamPlayer3D.new();voice.unit_size=160;voice.max_distance=1200;add_child(voice)
	prop_body=StaticBody3D.new();prop_body.collision_layer=1;prop_body.collision_mask=0
	var shape:=CollisionShape3D.new();var cylinder:=CylinderShape3D.new();cylinder.radius=28;cylinder.height=90
	shape.shape=cylinder;shape.position.y=45;prop_body.add_child(shape);add_child(prop_body)
	prop_body.set_meta("bacatta_prop",State.PROP)
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
	voice_key="";voice.stop()
	_sync_body(0.0);_sync_voice();_present()
	return ""

## ---- host links --------------------------------------------------------------------------------
func origin() -> Vector3: return population.origin()
func world_active() -> bool: return host.starting_magic!=null and host.starting_magic.world_active()
func movement_locked() -> bool: return state!=null and not state.is_empty() and State.movement_locked(state,src)
func hostile() -> bool: return state!=null and not state.is_empty() and State.hostile(state)
func prop_anchor() -> Vector3: return Vector3(float(src.prop.position[0]),float(src.prop.position[1]),float(src.prop.position[2]))+origin()
func starter_anchor() -> Vector3: return Vector3(float(src.starter.position[0]),float(src.starter.position[1]),float(src.starter.position[2]))+origin()

func context() -> Dictionary:
	if hooks.has("context") and hooks.context is Callable and hooks.context.is_valid():
		var value=hooks.context.call()
		if value is Dictionary: return value
	var globals: Dictionary=host.quest_state.get("monastery",{}).get("globals",{}) if host.get("quest_state") is Dictionary else {}
	var shared: Dictionary={}
	for id in src.shared_names: shared[id]=int(globals.get(str(src.shared_names[id]),0))
	return {"shared":shared}

func held_item() -> String:
	if hooks.has("held_item") and hooks.held_item is Callable and hooks.held_item.is_valid(): return str(hooks.held_item.call())
	return ""

## ---- producers -------------------------------------------------------------------------------------
## kind5 on prop3235: its first eligible sighting (frustum + clear ray), as for prop552/prop554.
func starter_visible() -> bool:
	var point: Vector3=starter_anchor()+Vector3.UP*40
	var eye: Vector3=host.camera.global_position
	if eye.distance_to(point)>SIGHT or not host.camera.is_position_in_frustum(point): return false
	var ray:=PhysicsRayQueryParameters3D.create(eye,point,1,[host.player.get_rid(),prop_body.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _aimed_prop() -> bool:
	if not state.prop.present or host.get_tree().paused: return false
	if host.get("interface_hud")!=null and is_instance_valid(host.interface_hud) and host.interface_hud.cursor_active: return false
	var target: Vector3=prop_anchor()+Vector3.UP*45
	var offset: Vector3=target-host.camera.global_position
	if offset.length()>REACH+28 or offset.length()<0.01: return false
	var query:=PhysicsRayQueryParameters3D.create(host.camera.global_position,host.camera.global_position-host.camera.global_basis.z*(REACH+40),1,[host.player.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider==prop_body

func can_offer() -> bool: return world_active() and not movement_locked() and _aimed_prop() and held_item()!=""
func can_strike() -> bool:
	if not world_active() or not _aimed_prop(): return false
	return not (int(host.get("player_form"))==0 and str(host.get("equipped_item"))=="")

## E with a carried item in hand: kind4 mode1 (the item stays with the player; no source opcode takes it).
func offer() -> bool:
	if not can_offer(): return false
	var effects:=State.offer(state,src,timing,true,context())
	_apply(effects);_present()
	return not effects.is_empty()

## Armed melee aimed at prop553: kind9 mode1 (any strike meets threshold1).
func strike() -> bool:
	if not can_strike(): return false
	var effects:=State.hit(state,src,timing,1,context())
	_apply(effects);_present()
	return not effects.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and offer():
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and strike():
		get_viewport().set_input_as_handled()

## ---- step --------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	if state==null or state.is_empty() or voice==null: return
	var running: bool=world_active() and not get_tree().paused
	voice.stream_paused=not running
	if not is_finite(delta) or delta<=0 or not running: return
	var ctx:=context()
	if not state.sighted and starter_visible(): _apply(State.sighted(state,src,timing,ctx))
	_regions()
	_apply(State.advance(state,src,timing,delta,context()))
	_sync_body(delta)
	_present()

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
		if r not in inside: _apply(State.enter_region(state,src,timing,r,context()))
	inside=now

## actor65 body: linked by the outcomes; hostile (outcome A) fights through the generic owner; peaceful (outcome B)
## holds its dormant idle pose at the placement and turns hostile when struck (adapter).
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
	if alive and not hostile() and int(body.health)<int(src.actor.health):
		state.actor.b5=(int(state.actor.b5)&243)|12;state.actor.b5=int(state.actor.b5)&254
		effect_log.append({"type":"struck_peaceful"})
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

## ---- effects ---------------------------------------------------------------------------------------
func _apply(effects: Array) -> void:
	for e in effects:
		effect_log.append(e)
		match str(e.type):
			"shared": _write_shared(e)
			"reposition": _reposition(e)
			"focus":
				if e.held: _face_speaker()
			"actor_presence": _sync_body(0.0)
		if hooks.has("effects") and hooks.effects is Callable and hooks.effects.is_valid() and str(e.type)!="group": hooks.effects.call(e)
	if effect_log.size()>600: effect_log=effect_log.slice(effect_log.size()-600)
	_sync_voice()

func _write_shared(e: Dictionary) -> void:
	if hooks.has("shared") and hooks.shared is Callable and hooks.shared.is_valid(): hooks.shared.call(e);return
	if not host.get("quest_state") is Dictionary or not host.quest_state.has("monastery"): return
	var name: String=str(src.shared_names.get(str(int(e.index)),""))
	if name.is_empty(): return
	var globals: Dictionary=host.quest_state.monastery.globals
	globals[name]=clampi(int(e.value) if str(e.op)=="set" else int(globals.get(name,0))+int(e.value),0,int(src.shared_caps.get(str(int(e.index)),255)))

func _reposition(e: Dictionary) -> void:
	var p: Array=e.position
	var target:=Vector3(p[0],host.player.global_position.y,p[2])+Vector3(origin().x,0,origin().z)
	var down:=PhysicsRayQueryParameters3D.create(target+Vector3.UP*400,target-Vector3.UP*800,1,[host.player.get_rid(),prop_body.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(down)
	if not hit.is_empty(): target.y=hit.position.y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	host.player.global_position=target;host.player.velocity=Vector3.ZERO
	_face_speaker()

## Player focus on prop553 (opcode2 property5, DD5DC) and the reposition both face the speaker.
func _face_speaker() -> void:
	var look:=Vector3(prop_anchor().x,host.player.global_position.y,prop_anchor().z)
	if look.distance_to(host.player.global_position)>0.1: host.player.look_at(look);host.camera.rotation=Vector3.ZERO

## The voice follows the clip clock: a new clip/segment (or a restore) restarts it at the clip's elapsed time.
func _sync_voice() -> void:
	var c: Dictionary=state.prop.clip
	if c.is_empty() or not state.prop.present:
		if voice.playing: voice.stop()
		voice_key="";return
	var row: Dictionary=media.clips[str(int(c.selector))]
	var key:="%d:%d:%d"%[int(c.selector),int(c.segment),int(c.passes)]
	if key==voice_key: return
	voice_key=key;voice.stop()
	if row.audio==null: return
	var start: float=float(c.elapsed)+(float(row.segments[int(c.segment)].first)/float(row.fps) if int(c.segment)>=0 else 0.0)
	voice.stream=AudioStreamWAV.load_from_file(str(row.audio))
	voice.global_position=prop_anchor()+Vector3.UP*40
	if start<float(voice.stream.get_length()): voice.play(start)

## ---- presentation ----------------------------------------------------------------------------------
func _texture(path: String) -> Texture2D:
	if not textures.has(path):
		if textures.size()>96: textures.clear()
		textures[path]=ImageTexture.create_from_image(Image.load_from_file(path))
	return textures[path]

## The clip (or its segment) shows its frames; otherwise the selector's first frame.
func current_frame() -> Dictionary:
	if not state.prop.present: return {}
	var c: Dictionary=state.prop.clip
	var selector: int=int(c.selector) if not c.is_empty() else int(state.prop.selector)
	var row: Dictionary=media.clips[str(selector)]
	var index:=0
	if not c.is_empty():
		var first:=0;var last:=int(row.frames)-1
		if int(c.segment)>=0: first=int(row.segments[int(c.segment)].first);last=int(row.segments[int(c.segment)].last)
		index=mini(first+int(float(c.elapsed)*float(row.fps)),last)
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

func targets() -> Dictionary:
	return population.targets() if state!=null and not state.is_empty() and state.actor.present and int(population.state.actors[ID].health)>0 else {}
