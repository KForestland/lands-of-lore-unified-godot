extends Node3D
## Live Kityara follow-up on the Jungle host (jungle_kityara_state.gd): her two original control locations show
## E066E.VQA segments on an in-world plane with the original voice; dropped-knife props 64/67 appear after she leaves.
## Producers: grounded entry edges into the source presence/start regions; E aimed at her with a held item (offer);
## a melee strike or basic Spark on her body (hit); E aimed at a dropped knife. The host supplies the shop-bank locals
## (23/35/41/54) and globals through hooks and receives grants, shared writes, holds and repositions.
## Modern adapters (docs/jungle-kityara.md): region edges are not evaluated while she holds Luther; the idle plane
## shows segment0's first frame while she is present and silent; one clip callback per update; body/aim reach.
const State=preload("res://scripts/lol2/jungle_kityara_state.gd")
const Packet=preload("res://scripts/lol2/jungle_kityara_packet.gd")
const MEDIA:="res://assets/lol2/generated/jungle_kityara_media/"
const ICON:="res://assets/lol2/generated/jungle_kityara/empty_hand.png"
const SHADER=preload("res://scripts/lol2/jungle_bacatta65.gd").SHADER
const REACH:=140.0
const FPS:=15.0
var host: Node3D
var hooks: Dictionary={}
var src: Dictionary
var media: Dictionary
var state: Dictionary
var inside: Array=[]
var meshes: Dictionary={}
var bodies: Dictionary={}
var drops: Dictionary={}
var voice: AudioStreamPlayer3D
var voice_key:=""
var voice_elapsed:=-1.0
var textures: Dictionary={}
var effects_log: Array=[]

static func assets_ready() -> bool: return FileAccess.file_exists(State.SOURCE) and FileAccess.file_exists(MEDIA+"media.json") and FileAccess.file_exists(ICON)

func setup(owner_host: Node3D, supplied_hooks: Dictionary={}, saved: Variant=null) -> String:
	host=owner_host;hooks=supplied_hooks;src=State.source()
	media=JSON.parse_string(FileAccess.get_file_as_string(MEDIA+"media.json"))
	for c in State.CONTROLS:
		var ctl: Dictionary=src.locations[c].control
		var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new();quad.size=Vector2(float(ctl.dimensions[0]),float(ctl.dimensions[2]));quad.center_offset=Vector3(0,quad.size.y/2,0);mesh.mesh=quad
		var shader:=Shader.new();shader.code=SHADER;var material:=ShaderMaterial.new();material.shader=shader;mesh.material_override=material;add_child(mesh);meshes[c]=mesh
		var body:=StaticBody3D.new();body.collision_layer=0;body.collision_mask=0;body.name="Kityara%s"%c
		var shape:=BoxShape3D.new();shape.size=Vector3(30,80,30);var collider:=CollisionShape3D.new();collider.shape=shape;collider.position.y=40
		body.add_child(collider);body.set_meta("population_actor","control"+c);body.set_meta("population_owner",self);add_child(body);bodies[c]=body
	for p in ["64","67"]:
		var sprite:=Sprite3D.new();sprite.texture=ImageTexture.create_from_image(Image.load_from_file(ICON));sprite.pixel_size=0.6;sprite.billboard=BaseMaterial3D.BILLBOARD_ENABLED
		sprite.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST;add_child(sprite)
		var body:=StaticBody3D.new();body.collision_layer=0;body.collision_mask=0;var shape:=BoxShape3D.new();shape.size=Vector3(30,20,30)
		var collider:=CollisionShape3D.new();collider.shape=shape;collider.position.y=10;body.add_child(collider);body.set_meta("kityara_drop",int(p));add_child(body)
		drops[p]={"sprite":sprite,"body":body}
	voice=AudioStreamPlayer3D.new();voice.stream=AudioStreamWAV.load_from_file(MEDIA+str(media.audio));voice.unit_size=300;add_child(voice)
	return restore(saved if saved!=null else initial())

func initial() -> Dictionary: return {"version":1,"state":State.initial(src),"inside":[]}
func checkpoint() -> Dictionary: return {"version":1,"state":state.duplicate(true),"inside":inside.duplicate()}
static func validate(packet: Variant) -> String: return Packet.validate(packet)

## Atomic: an invalid packet changes nothing; playback restarts from the saved clip clock.
func restore(packet: Variant) -> String:
	var error:=validate(packet)
	if not error.is_empty(): return error
	state=State.canonical(packet.state);inside=packet.inside.map(func(r): return int(r))
	voice.stop();voice_key="";voice_elapsed=-1.0
	present();return ""

func origin() -> Vector3:
	var value=host.get("native_translation")
	return value if value is Vector3 else Vector3.ZERO
## Her own clip clock runs during her hold, while world_active() freezes creatures and other owners behind it.
func live() -> bool: return host.starting_magic!=null and host.starting_magic.movie_world_active() and not get_tree().paused
func speaking() -> String: return State.speaking(state) if not state.is_empty() else ""
func movement_locked() -> bool: return speaking()!=""
func input_locked() -> bool: return movement_locked()
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
			"shop_local": _call("shop_local",[str(e.name),int(e.value)])
			"shared": _call("shared",[e])
			"grant": _call("grant",[int(e.identity)])
			"consume_held": _call("consume_held")
			"reposition":
				host.player.global_position=Vector3(e.position[0],e.position[1],e.position[2])+origin()+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
				host.player.velocity=Vector3.ZERO
	if effects_log.size()>120: effects_log=effects_log.slice(-120)
	present()

## ---- producers ----------------------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	if state.is_empty(): return
	voice.stream_paused=not live()
	if not live() or not is_finite(delta) or delta<=0: return
	if speaking()=="": _regions()
	apply(State.advance(state,src,delta,context()))

func _regions() -> void:
	var now: Array=[];var pos: Vector3=host.player.global_position-origin()
	var foot: float=pos.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	for region in src.regions:
		if foot<float(region.floor_min)-4 or foot>float(region.floor_max)+6: continue
		var poly:=PackedVector2Array()
		for v in region.polygon: poly.append(Vector2(v[0],v[1]))
		if not Geometry2D.is_point_in_polygon(Vector2(pos.x,pos.z),poly): continue
		now.append(int(region.id))
		if int(region.id) not in inside: apply(State.enter_region(state,src,int(region.id),context()))
	inside=now

func _aimed() -> Dictionary:
	if not live() or speaking()!="": return {}
	var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,host.camera.global_position-host.camera.global_basis.z*REACH,1,[host.player.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty(): return {}
	for c in bodies:
		if hit.collider==bodies[c]: return {"control":int(c)}
	if hit.collider.has_meta("kityara_drop"): return {"prop":int(hit.collider.get_meta("kityara_drop"))}
	return {}

## E: offer the held item to her (exact source identity), or pick up a dropped knife.
func use() -> bool:
	var aim:=_aimed()
	if aim.has("prop"):
		var e:=State.use_prop(state,src,int(aim.prop),context());apply(e);return not e.is_empty()
	if aim.has("control"):
		var identity: int=int(_call("held_identity")) if hooks.has("held_identity") else 0
		var e:=State.offer(state,src,int(aim.control),identity,context());apply(e);return not e.is_empty()
	return false

## Armed melee strike aimed at her body.
func strike() -> bool:
	var aim:=_aimed()
	if not aim.has("control") or (int(host.player_form)==0 and str(host.equipped_item)==""): return false
	var e:=State.hit(state,src,int(aim.control),context());apply(e);return not e.is_empty()

## Basic Spark (player_starting_magic population_actor ray) on her body.
func receive_damage(id: String, _amount: int, _melee: bool=true, _effect: int=20) -> bool:
	if not live() or not id.begins_with("control"): return false
	var e:=State.hit(state,src,int(id.trim_prefix("control")),context());apply(e);return not e.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and use(): get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and Input.mouse_mode==Input.MOUSE_MODE_CAPTURED and strike(): get_viewport().set_input_as_handled()

## ---- presentation -------------------------------------------------------------------------------------------------
func _texture(frame: int) -> Texture2D:
	if not textures.has(frame):
		if textures.size()>90: textures.clear()
		textures[frame]=ImageTexture.create_from_image(Image.load_from_file(MEDIA+str(media.frames[frame])))
	return textures[frame]

func present() -> void:
	if state.is_empty(): return
	var talking:=""
	for c in State.CONTROLS:
		var k: Dictionary=state.controls[c];var p: Array=src.locations[c].control.position
		var at:=Vector3(p[0],p[1],p[2])+origin()
		meshes[c].global_position=at;bodies[c].global_position=at
		meshes[c].visible=bool(k.present);bodies[c].collision_layer=1 if bool(k.present) else 0
		if not bool(k.present): continue
		var frame:=0
		if int(k.segment)>=0:
			var seg: Dictionary=src.movie.segments[int(k.segment)]
			frame=mini(int(seg.last),int(seg.first)+int(float(k.elapsed)*FPS))
			talking=c
		meshes[c].material_override.set_shader_parameter("frame",_texture(frame))
	for p in drops:
		var q: Dictionary=state.props[p];var pos: Array=src.props[p].position
		var at:=Vector3(pos[0],pos[1],pos[2])+origin()
		drops[p].sprite.global_position=at+Vector3.UP*6;drops[p].body.global_position=at
		drops[p].sprite.visible=bool(q.present);drops[p].body.collision_layer=1 if bool(q.present) else 0
	if talking=="":
		voice.stop();voice_key="";voice_elapsed=-1.0;return
	var k: Dictionary=state.controls[talking];var seg: Dictionary=src.movie.segments[int(k.segment)]
	var key:="%s:%d"%[talking,int(k.segment)]
	voice.global_position=meshes[talking].global_position
	if key!=voice_key or float(k.elapsed)<voice_elapsed:
		voice_key=key;voice.play(float(seg.first)/FPS+float(k.elapsed))
	voice_elapsed=float(k.elapsed)
	voice.stream_paused=not live()
