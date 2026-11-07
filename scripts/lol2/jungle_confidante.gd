extends Node3D
## Live village Confidante on the Jungle host (jungle_confidante_state.gd): controls 112/123 show their original
## E103E/E102E.VQA segments on in-world planes with the original voices and sounds 227/269.
## Producers: a starter prop coming into sight (kind5; 1465 for 123, 492 for 112), grounded entry edges into the source
## regions, and a landed melee strike or basic Spark on a visible control body (kind9 hit). The host supplies locals 6/33
## (Kelsrick owner) and the shared globals through hooks and receives shared writes (Soul) and repositions.
## Modern adapters (docs/jungle-confidante.md): sight is an edge (out of view -> in view within 1000 units; a loaded
## save or new scene starts from what is already in view, like the saved region history); regions are
## not evaluated while a control holds Luther; a control is drawn only while a segment plays; one clip callback per
## update; body/aim reach. The gate leaves 78/79 are not opened here (contract item 4).
const State=preload("res://scripts/lol2/jungle_confidante_state.gd")
const Packet=preload("res://scripts/lol2/jungle_confidante_packet.gd")
const MyJournal=preload("res://scripts/lol2/my_journal.gd")
const MEDIA:="res://assets/lol2/generated/jungle_confidante_media/"
const SHADER=preload("res://scripts/lol2/jungle_bacatta65.gd").SHADER
const REACH:=140.0
const SIGHT:=1000.0
const FPS:=15.0
var host: Node3D
var hooks: Dictionary={}
var src: Dictionary
var media: Dictionary={}
var state: Dictionary
var inside: Array=[]
var seen: Dictionary={}
## A restore is not a sight edge: the first look after it records what is already in view without dispatching.
var prime_sight:=true
var meshes: Dictionary={}
var bodies: Dictionary={}
var voices: Dictionary={}
var voice_key: Dictionary={}
var voice_elapsed: Dictionary={}
var sounds: Dictionary={}
var textures: Dictionary={}
var effects_log: Array=[]

static func assets_ready() -> bool:
	if not FileAccess.file_exists(State.SOURCE): return false
	for c in State.CONTROLS:
		if not FileAccess.file_exists(MEDIA+c+"/media.json"): return false
	return FileAccess.file_exists(MEDIA+"sounds/227.wav") and FileAccess.file_exists(MEDIA+"sounds/269.wav")

func setup(owner_host: Node3D, supplied_hooks: Dictionary={}, saved: Variant=null) -> String:
	host=owner_host;hooks=supplied_hooks;src=State.source()
	for c in State.CONTROLS:
		media[c]=JSON.parse_string(FileAccess.get_file_as_string(MEDIA+c+"/media.json"))
		var ctl: Dictionary=src.locations[c].control
		var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(float(ctl.dimensions[0]),float(ctl.dimensions[2]));quad.center_offset=Vector3(0,quad.size.y/2,0);mesh.mesh=quad
		var shader:=Shader.new();shader.code=SHADER;var material:=ShaderMaterial.new();material.shader=shader;mesh.material_override=material;add_child(mesh);meshes[c]=mesh
		var body:=StaticBody3D.new();body.collision_layer=0;body.collision_mask=0;body.name="Confidante%s"%c
		var shape:=BoxShape3D.new();shape.size=Vector3(30,float(ctl.dimensions[2]),30);var collider:=CollisionShape3D.new();collider.shape=shape;collider.position.y=float(ctl.dimensions[2])/2
		body.add_child(collider);body.set_meta("population_actor","control"+c);body.set_meta("population_owner",self);add_child(body);bodies[c]=body
		var voice:=AudioStreamPlayer3D.new();voice.stream=AudioStreamWAV.load_from_file(MEDIA+c+"/"+str(media[c].audio));voice.unit_size=300;voice.attenuation_model=AudioStreamPlayer3D.ATTENUATION_DISABLED;voice.max_distance=1200.0;add_child(voice);voices[c]=voice
	for n in src.sounds:
		var player:=AudioStreamPlayer3D.new();player.stream=AudioStreamWAV.load_from_file(MEDIA+"sounds/%s.wav"%n);player.unit_size=300;add_child(player);sounds[n]=player
	return restore(saved if saved!=null else initial())

func initial() -> Dictionary: return {"version":1,"state":State.initial(src),"inside":[]}
func checkpoint() -> Dictionary: return {"version":1,"state":state.duplicate(true),"inside":inside.duplicate()}
static func validate(packet: Variant) -> String: return Packet.validate(packet)

## Atomic: an invalid packet changes nothing; playback restarts from the saved clip clock.
func restore(packet: Variant) -> String:
	var error:=validate(packet)
	if not error.is_empty(): return error
	state=State.canonical(packet.state);inside=packet.inside.map(func(r): return int(r));seen={};prime_sight=true
	for c in voices: voices[c].stop();voice_key[c]="";voice_elapsed[c]=-1.0
	present();return ""

func origin() -> Vector3:
	var value=host.get("native_translation")
	return value if value is Vector3 else Vector3.ZERO
func live() -> bool: return host.starting_magic!=null and host.starting_magic.movie_world_active() and not get_tree().paused
func speaking() -> String: return State.speaking(state) if not state.is_empty() else ""
func movement_locked() -> bool: return speaking()!=""
func input_locked() -> bool: return movement_locked()
func killed() -> bool: return not state.is_empty() and int(state.locals["39"])==1
func context() -> Dictionary:
	if hooks.has("context") and hooks.context is Callable and hooks.context.is_valid():
		var value=hooks.context.call()
		if value is Dictionary: return value
	return {"locals":{},"shared":{}}
func _call(name: String, args: Array=[]) -> Variant:
	if hooks.has(name) and hooks[name] is Callable and hooks[name].is_valid(): return hooks[name].callv(args)
	return null

func apply(effects: Array) -> void:
	for e in effects:
		if str(e.type)!="group": effects_log.append(e)
		match str(e.type):
			"shared": _call("shared",[e])
			"sound":
				var key:=str(int(e.request))
				if sounds.has(key):
					var at: Vector3=meshes[str(int(e.object))].global_position if int(e.kind)==0x10 and meshes.has(str(int(e.object))) else host.player.global_position
					sounds[key].global_position=at;sounds[key].play()
			"local":
				# My Journal: Met_Confidant set (the password heard) while the den door was never opened (flag 271).
				if int(e.index)==27 and int(e.value)!=0 and int(host.quest_state.get("thieves_den",{}).get("flags",{}).get("271",0))==0:
					MyJournal.discover(host,"password_known_den_unfound")
			"reposition":
				host.player.global_position=Vector3(e.position[0],e.position[1],e.position[2])+origin()+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
				host.player.velocity=Vector3.ZERO
	if effects_log.size()>120: effects_log=effects_log.slice(-120)
	present()

## ---- producers ----------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	if state.is_empty(): return
	for c in voices: voices[c].stream_paused=not live()
	if not live() or not is_finite(delta) or delta<=0: return
	_sight()
	if speaking()=="": _regions()
	apply(State.advance(state,src,delta,context()))

func _sight() -> void:
	for c in State.CONTROLS:
		var prop: String=str(int(src.locations[c].starter_prop))
		var now:=_visible(src.props[prop])
		if now and not prime_sight and not bool(seen.get(prop,false)): apply(State.sight(state,src,int(prop),context()))
		seen[prop]=now
	prime_sight=false

func _visible(row: Dictionary) -> bool:
	var p: Array=row.position;var target:=Vector3(p[0],p[1]+40,p[2])+origin()
	if host.camera.global_position.distance_to(target)>SIGHT or not host.camera.is_position_in_frustum(target): return false
	var exclude: Array=[host.player.get_rid()]
	for c in bodies: exclude.append(bodies[c].get_rid())
	var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,target,1,exclude)
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()

func _regions() -> void:
	var now: Array=[];var pos: Vector3=host.player.global_position-origin()
	var foot: float=pos.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	for region in src.regions:
		if foot<float(region.floor_min)-4 or foot>float(region.floor_max)+6: continue
		var poly:=PackedVector2Array()
		for v in region.polygon: poly.append(Vector2(v[0],v[1]))
		if not Geometry2D.is_point_in_polygon(Vector2(pos.x,pos.z),poly): continue
		now.append(int(region.id))
		if int(region.id) not in inside:
			_journal_region(int(region.id))
			apply(State.enter_region(state,src,int(region.id),context()))
	inside=now

## My Journal: region3408 entered where the first meeting would start (p198: local20==0, hut not smoked) but neither
## GV_LUTHER_KNOWS_ABOUT_DANIEL (shared47) nor GV_KITYARA_DEAD (shared25) is set, so nobody shows (the native stuck point).
func _journal_region(region: int) -> void:
	if region!=3408 or int(state.locals["20"])!=0 or int(state.locals["27"])!=0 or int(state.locals["39"])!=0: return
	var ctx:=context()
	if int(ctx.get("locals",{}).get("6",0))!=0: return
	var shared: Dictionary=ctx.get("shared",{})
	if int(shared.get("47",0))==1 or int(shared.get("25",0))==1: return
	MyJournal.discover(host,"no_confidante_yet")

func _aimed() -> Dictionary:
	if not live() or speaking()!="": return {}
	var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,host.camera.global_position-host.camera.global_basis.z*REACH,1,[host.player.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return {}
	for c in bodies:
		if hit.collider==bodies[c]: return {"control":int(c)}
	return {}

## Armed melee strike aimed at a visible control body.
func strike() -> bool:
	var aim:=_aimed()
	if not aim.has("control") or (int(host.player_form)==0 and str(host.equipped_item)==""): return false
	var damage: int=preload("res://scripts/lol2/player_form_rules.gd").melee_damage(host.player_form,host.equipped_item!="")
	if host.get("item_effects")!=null and host.item_effects.has_method("melee_damage"): damage=host.item_effects.melee_damage(damage)
	var e:=State.hit(state,src,int(aim.control),context(),damage);apply(e);return not e.is_empty()

## Population-style hit callback (basic Spark through player_starting_magic's population_actor ray). The amount is the
## mode1 context dword +0x1E: 0 or less is rejected without any change (State.hit).
func receive_damage(id: String, amount: int, _melee: bool=true, _effect: int=20) -> bool:
	if not live() or not id.begins_with("control"): return false
	var c:=id.trim_prefix("control")
	if not bodies.has(c) or bodies[c].collision_layer==0: return false
	var e:=State.hit(state,src,int(c),context(),amount);apply(e);return not e.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and strike(): get_viewport().set_input_as_handled()

## ---- presentation -------------------------------------------------------------------------------------------------
func _texture(c: String, frame: int) -> Texture2D:
	var key:="%s:%d"%[c,frame]
	if not textures.has(key):
		if textures.size()>90: textures.clear()
		textures[key]=ImageTexture.create_from_image(Image.load_from_file(MEDIA+c+"/"+str(media[c].frames[frame])))
	return textures[key]

func present() -> void:
	if state.is_empty(): return
	for c in State.CONTROLS:
		var k: Dictionary=state.controls[c];var p: Array=src.locations[c].control.position
		var at:=Vector3(p[0],p[1],p[2])+origin()
		meshes[c].global_position=at;bodies[c].global_position=at;voices[c].global_position=at
		var playing: bool=bool(k.present) and int(k.segment)>=0
		meshes[c].visible=playing;bodies[c].collision_layer=1 if playing else 0
		if not playing:
			voices[c].stop();voice_key[c]="";voice_elapsed[c]=-1.0;continue
		var seg: Dictionary=src.locations[c].movie.segments[int(k.segment)]
		meshes[c].material_override.set_shader_parameter("frame",_texture(c,mini(int(seg.last),int(seg.first)+int(float(k.elapsed)*FPS))))
		var key:="%d"%int(k.segment)
		if key!=voice_key[c] or float(k.elapsed)<float(voice_elapsed[c]):
			voice_key[c]=key;voices[c].play(float(seg.first)/FPS+float(k.elapsed))
		voice_elapsed[c]=float(k.elapsed)
		voices[c].stream_paused=not live()

## Enter skips the line now playing (dialogue_skip.gd): the speaking control's single-pass segment is set to its last step;
## the next tick fires the source end event. Looping segments (passes) are left alone.
func skip_line() -> bool:
	if state==null or state.is_empty() or get_tree().paused: return false
	var talking: String=speaking()
	if talking=="": return false
	var k: Dictionary=state.controls[talking]
	if int(k.segment)<0 or int(k.passes)>0: return false
	k.elapsed=maxf(float(k.elapsed),float(src.locations[talking].movie.segments[int(k.segment)].duration)-1.0/4096)
	voices[talking].stop()
	return true
