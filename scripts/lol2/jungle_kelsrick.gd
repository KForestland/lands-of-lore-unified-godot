extends Node3D
## Live Kelsrick64: source dialogue/use/hit chain (jungle_kelsrick_state.gd) presented with his original
## in-world VQA segments and voice, plus the unchanged generic creature owner for his body and the hostile fight.
## Producers: grounded entry into source regions 2750/3567/3791 (edge, saved); E-use while aimed at him with a
## held item (sole kind4 record is mode1: a non-empty hand is required); generic damage mirrored as a hit
## (melee context 2/4, Spark 1/1, matching the verified hit-context words). Player property 0x26/0x27 is the
## native scripted hold/release; the host gates its input on input_locked().
## External control/prop/movable commands are kept as saved receipts for later binding, never dropped.
const State=preload("res://scripts/lol2/jungle_kelsrick_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const Packet=preload("res://scripts/lol2/jungle_kelsrick_packet.gd")
const POP_CONFIG:={"root":"res://assets/lol2/generated/jungle_kelsrick/sprites/","source":"res://scripts/lol2/jungle_kelsrick_population_source.json",
	"target_prefix":"junglekelsrick","fighting_owner":"quest_state","nav":"res://assets/lol2/generated/creature_nav/L4_HJ.json",
	"names":{"7":"Kelsrick"},"look":{"7":{"canvas":[320,200],"scale":0.47,"floor_row":187,"radius":16,"height":56}}}
const CLIP_SCALE:=0.47
const REACH:=110.0
const MAX_RECEIPTS:=Packet.MAX_RECEIPTS
## The unchanged generic owner, recording whether its last health loss was melee (2/4) or Spark (1/1).
class Body extends "res://scripts/lol2/scripted_creature_population.gd":
	var last_melee:=true
	func receive_damage(id: String, amount: int, melee: bool=true, effect: int=20) -> bool:
		last_melee=melee
		return super.receive_damage(id,amount,melee,effect)
	func strike() -> bool:
		if host.get("kelsrick")!=null and is_instance_valid(host.kelsrick) and host.kelsrick.input_locked(): return false
		return super.strike()
const SHADER:="shader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform sampler2D frame : source_color, filter_nearest, repeat_disable;\nvoid vertex() {\n\tvec3 up = vec3(0.0, 1.0, 0.0);\n\tvec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));\n\tMODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(cross(right, up), 0.0), MODEL_MATRIX[3]);\n}\nvoid fragment() {\n\tvec4 c = texture(frame, UV);\n\tif (c.a < 0.5) { discard; }\n\tALBEDO = c.rgb;\n}\n"
var host: Node3D
var hooks: Dictionary={}
var src: Dictionary
var media: Dictionary
var state: Dictionary
var population: Node3D
var inside: Array=[]
var hold:=false
var receipts: Array=[]
var effect_log: Array=[]
var mesh: MeshInstance3D
var voice: AudioStreamPlayer3D
var textures: Dictionary={}

func setup(owner_host: Node3D, supplied_hooks: Dictionary={}, saved: Variant=null) -> String:
	host=owner_host;hooks=supplied_hooks
	src=State.source()
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(State.MEDIA)) if FileAccess.file_exists(State.MEDIA) else null
	if not parsed is Dictionary: return "Kelsrick media missing (run tools/prepare_jungle_kelsrick.py)."
	media=parsed
	population=Body.new()
	population.name="KelsrickBody";population.configure(POP_CONFIG);add_child(population)
	var error: String=population.setup(host)
	if not error.is_empty(): return error
	population.set_physics_process(false)
	mesh=MeshInstance3D.new();mesh.mesh=QuadMesh.new()
	var shader:=Shader.new();shader.code=SHADER
	var material:=ShaderMaterial.new();material.shader=shader;mesh.material_override=material
	mesh.visible=false;add_child(mesh)
	voice=AudioStreamPlayer3D.new();add_child(voice)
	return restore(saved if saved!=null else initial())

## ---- saved packet ---------------------------------------------------------------------------
func initial() -> Dictionary:
	return {"version":1,"state":State.initial(src),"body":Generic.initial(population.src),"inside":[],"hold":false,"receipts":[]}

func validate(packet: Variant) -> String: return Packet.validate(packet)

func checkpoint() -> Dictionary:
	_mirror_damage()
	return {"version":1,"state":state.duplicate(true),"body":population.checkpoint(),"inside":inside.duplicate(),"hold":hold,"receipts":receipts.duplicate()}

## Atomic: an invalid packet changes nothing.
func restore(packet: Variant) -> String:
	var error:=validate(packet)
	if not error.is_empty(): return error
	error=population.restore(packet.body)
	if not error.is_empty(): return error
	state=State.canonical(packet.state)
	inside=packet.inside.map(func(r):return int(r));hold=bool(packet.hold);receipts=packet.receipts.duplicate()
	_start_voice();_sync_body(0.0);_present()
	return ""

## ---- host links ------------------------------------------------------------------------------
func world_active() -> bool: return host.starting_magic!=null and host.starting_magic.world_active()
func origin() -> Vector3: return population.origin()
func input_locked() -> bool: return hold
func fighting() -> bool: return bool(state.present) and int(state.health)>0 and (int(state.b5)&12)!=0 and (int(state.b5)&1)==0 and int(state.locals["52"])!=0

func context() -> Dictionary:
	var ctx: Dictionary={}
	if hooks.has("context") and hooks.context is Callable and hooks.context.is_valid():
		var value=hooks.context.call()
		if value is Dictionary: ctx=value.duplicate(true)
	if not ctx.has("shared"): ctx.shared={}
	if not ctx.has("locals"): ctx.locals={"15":0}
	return ctx

func held_item() -> String:
	if hooks.has("held_item") and hooks.held_item is Callable and hooks.held_item.is_valid(): return str(hooks.held_item.call())
	return str(host.get("hand_item")) if host.get("hand_item")!=null else ""

## ---- producers ---------------------------------------------------------------------------------
func _aimed() -> bool:
	if not state.present or int(state.health)<=0 or host.get_tree().paused: return false
	if host.get("interface_hud")!=null and is_instance_valid(host.interface_hud) and host.interface_hud.cursor_active: return false
	var origin_point: Vector3=host.camera.global_position
	var query:=PhysicsRayQueryParameters3D.create(origin_point,origin_point-host.camera.global_basis.z*REACH,3,[host.player.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
	return not hit.is_empty() and hit.collider==population.bodies["64"]

func can_use() -> bool: return world_active() and not hold and not fighting() and _aimed()

## Kind4 mode1: only a non-empty held item is admitted (native ADC76); an empty hand does nothing.
func use() -> bool:
	if not can_use(): return false
	var effects:=State.offer(state,src,not held_item().is_empty(),context())
	_apply(effects);_present()
	return not effects.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and use():
		get_viewport().set_input_as_handled()

## Generic health loss (player melee/spell) enters the source as the kind9 hit records.
func _mirror_damage() -> void:
	var body: Dictionary=population.state.actors["64"]
	var loss:=int(state.health)-int(body.health)
	if loss<=0 or not state.present: return
	var spell: bool=not population.last_melee
	_apply(State.hit(state,src,1 if spell else 2,1 if spell else 4,loss,context()))
	body.health=int(state.health)

## ---- step ----------------------------------------------------------------------------------------
func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	# The voice follows the clip clock: whenever the world is gated the clip clock stops, so the voice pauses too.
	var running: bool=world_active() and not get_tree().paused
	if is_instance_valid(voice): voice.stream_paused=not running
	if not is_finite(delta) or delta<=0 or not running: return
	var ctx:=context()
	_regions(ctx)
	_mirror_damage()
	_apply(State.advance(state,src,media,delta,ctx))
	_sync_body(delta)
	_mirror_damage()
	_present()

func _regions(ctx: Dictionary) -> void:
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
			state.region=-1 # the state models an entry edge per call
			_apply(State.enter_region(state,src,r,ctx))
	inside=now

func _sync_body(delta: float) -> void:
	var body: Dictionary=population.state.actors["64"]
	if not state.present and body.present:
		var fresh: Dictionary=Generic.initial(population.src)
		population.state.actors["64"]=fresh.actors["64"].duplicate(true);population.state.actors["64"].present=false
		population.state.live["64"]=fresh.live["64"].duplicate(true)
	elif state.present and not body.present: Generic.spawn(population.state,"64")
	body=population.state.actors["64"]
	body.health=int(state.health)
	var hostile:=fighting()
	# Source hit records also admit a peaceful Kelsrick, so strikes are live whenever he stands outside a clip/hold.
	var strikeable: bool=state.present and int(state.health)>0 and state.clip.is_empty() and not hold
	population.set_process_unhandled_input(strikeable);population.set_process(strikeable)
	if hostile:
		if not body.woken: Generic.wake(population.state,"64")
		# A restore (delta 0) only presents; stepping the AI would move the saved body.
		if state.clip.is_empty() and delta>0: population.advance(delta)
		else: population.present()
		return
	if int(state.health)==0:
		# Death/corpse clips run on the generic clocks (A7544 or a lethal blow), with no AI step.
		if delta>0: Generic.advance_clocks(population.state,population.src,delta)
		population.present()
		return
	# Peaceful or in a scripted clip: the unwoken body holds its dormant idle pose (no saved wake is invented).
	population.state.live["64"].mode=Live.IDLE
	population.present()

## ---- effects ---------------------------------------------------------------------------------------
func _apply(effects: Array) -> void:
	for e in effects:
		effect_log.append(e)
		match str(e.type):
			"player_property":
				if int(e.property)==0x26: hold=true
				elif int(e.property)==0x27: hold=false
			"reposition": _reposition(e)
			"clip": _start_voice()
			"shared": _write_shared(e)
			"external","local","grant_player":
				var key:=str(e.get("raw",""))
				if not key.is_empty() and key not in receipts and receipts.size()<MAX_RECEIPTS: receipts.append(key)
		if hooks.has("effects") and hooks.effects is Callable and hooks.effects.is_valid() and str(e.type)!="group": hooks.effects.call(e)
	if effect_log.size()>400: effect_log=effect_log.slice(effect_log.size()-400)

## Opcode206/199 on named globals (0..255; Soul capped at 10 by the verified runtime index table).
func _write_shared(e: Dictionary) -> void:
	if hooks.has("shared") and hooks.shared is Callable and hooks.shared.is_valid(): hooks.shared.call(e);return
	if not host.get("quest_state") is Dictionary: return
	var monastery: Dictionary=host.quest_state.get("monastery",{})
	if not monastery.get("globals") is Dictionary: return
	var names:={"0":"GV_LUTHERS_SOUL","11":"GV_KELSRICK_DEAD","29":"GV_HULINE_ALERT"}
	var name: String=str(names.get(str(int(e.index)),""))
	if name.is_empty(): return
	var value: int=int(e.value) if str(e.op)=="set" else int(monastery.globals.get(name,0))+int(e.value)
	monastery.globals[name]=clampi(value,0,10 if name=="GV_LUTHERS_SOUL" else 255)

func _reposition(e: Dictionary) -> void:
	var p: Array=e.position
	var target:=Vector3(p[0],host.player.global_position.y,p[2])+Vector3(origin().x,0,origin().z)
	var down:=PhysicsRayQueryParameters3D.create(target+Vector3.UP*400,target-Vector3.UP*800,1,[host.player.get_rid(),population.bodies["64"].get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(down)
	if not hit.is_empty(): target.y=hit.position.y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	host.player.global_position=target;host.player.velocity=Vector3.ZERO

## ---- presentation ----------------------------------------------------------------------------------
func clip_frame() -> int:
	var c: Dictionary=state.clip
	if c.is_empty(): return -1
	var row: Dictionary=media.clips[str(int(c.selector))]
	var seg: Dictionary={}
	for s in row.segments:
		if int(s.index)==int(c.segment): seg=s
	return mini(int(seg.first)+int(float(c.elapsed)*float(row.fps)),int(seg.last))

func _start_voice() -> void:
	voice.stop()
	var c: Dictionary=state.clip
	if c.is_empty(): return
	var row: Dictionary=media.clips[str(int(c.selector))]
	if row.get("audio")==null: return
	var seg: Dictionary={}
	for s in row.segments:
		if int(s.index)==int(c.segment): seg=s
	voice.stream=AudioStreamWAV.load_from_file(str(row.audio))
	var start: float=float(seg.first)/float(row.fps)+float(c.elapsed)
	if start<float(voice.stream.get_length()): voice.play(start)

func _texture(path: String) -> Texture2D:
	if not textures.has(path):
		if textures.size()>96: textures.clear()
		textures[path]=ImageTexture.create_from_image(Image.load_from_file(path))
	return textures[path]

func _present() -> void:
	var showing: bool=state.present and not state.clip.is_empty()
	mesh.visible=showing
	if population.meshes.has("64"): population.meshes["64"].visible=bool(state.present) and not showing
	if not showing:
		if voice.playing and state.clip.is_empty(): voice.stop()
		return
	var row: Dictionary=media.clips[str(int(state.clip.selector))]
	var quad: QuadMesh=mesh.mesh
	quad.size=Vector2(float(row.width),float(row.height))*CLIP_SCALE;quad.center_offset=Vector3(0,quad.size.y/2.0,0)
	mesh.global_position=population.bodies["64"].global_position
	mesh.material_override.set_shader_parameter("frame",_texture(str(row.frame_files[clip_frame()])))

func targets() -> Dictionary:
	return population.targets() if state.present and int(state.health)>0 else {}
