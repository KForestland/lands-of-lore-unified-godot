extends Node3D
## Live Dawn63: source spawn/talk/offer/hit chain (jungle_dawn_state.gd) presented with her original E065E segments
## and voice, plus the unchanged generic creature owner for her body (target, damage, death).
## Producers: grounded entry into source regions 2812/2842/2959 (edge, saved); first sighting = present body inside
## the production camera frustum with an unobstructed world ray (kind5); E-use while aimed at her with a held item
## (native first-eligible kind4: wax runes identity B45B2813 before the generic held-item records; empty hand none);
## generic damage mirrored as a hit (wildcard masks, threshold1, one-shot).
## Player properties: 0x26/0x27 hold/release, 0x0B/0x0C value×100 fighting/magic experience, 0x18 takes the held
## item, 0x3C requests human form, and 0x24/0x25 enable/disable new transformation requests.
## Actor properties 5/6 (talk focus) and external prop/sound/timer commands remain saved receipts.
## Hostile Dawn uses the shared modern combat controller; original native cast timing is not a release gate.
const State=preload("res://scripts/lol2/jungle_dawn_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const Packet=preload("res://scripts/lol2/jungle_dawn_packet.gd")
const Rewards=preload("res://scripts/lol2/player_property_rewards.gd")
const Runes=preload("res://scripts/lol2/hive_rune_items.gd")
const POP_CONFIG:={"root":"res://assets/lol2/generated/jungle_dawn_media/sprites/","source":"res://scripts/lol2/jungle_dawn_population_source.json",
	"target_prefix":"jungledawn","fighting_owner":"quest_state","nav":"res://assets/lol2/generated/creature_nav/L4_HJ.json",
	"names":{"8":"Dawn"},"look":{"8":{"canvas":[320,200],"scale":0.47,"floor_row":187,"radius":16,"height":56}}}
const ID:="63"
const WAX_IDENTITY:=0xb45b2813
## Any other carried item: only its non-emptiness matters to the generic mode1 records.
const HELD_IDENTITY:=1
const CLIP_SCALE:=0.47
const REACH:=110.0
const SIGHT:=1600.0
const MAX_RECEIPTS:=Packet.MAX_RECEIPTS
class Body extends "res://scripts/lol2/scripted_creature_population.gd":
	var last_melee:=true
	func receive_damage(id: String, amount: int, melee: bool=true, effect: int=20) -> bool:
		last_melee=melee
		return super.receive_damage(id,amount,melee,effect)
	func strike() -> bool:
		if host.has_method("actor_input_locked") and host.actor_input_locked(): return false
		return super.strike()
	## Dawn moves and fights by her source script (the body is never stepped): no Net of Exile hold.
	func net_hit(_id: String, _item: String) -> bool: return false
const SHADER:="shader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform sampler2D frame : source_color, filter_nearest, repeat_disable;\nvoid vertex() {\n\tvec3 up = vec3(0.0, 1.0, 0.0);\n\tvec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));\n\tMODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(cross(right, up), 0.0), MODEL_MATRIX[3]);\n}\nvoid fragment() {\n\tvec4 c = texture(frame, UV);\n\tif (c.a < 0.5) { discard; }\n\tALBEDO = c.rgb;\n}\n"
var combat: Node3D
var host: Node3D
var hooks: Dictionary={}
var src: Dictionary
var media: Dictionary
var projectiles:=preload("res://scripts/lol2/dawn_projectile_store.gd").new()
var state: Dictionary
var population: Node3D
var inside: Array=[]
var hold:=false
var receipts: Array=[]
var effect_log: Array=[]
var mesh: MeshInstance3D
var voice: AudioStreamPlayer3D
var voice_stream: AudioStream
var textures: Dictionary={}

func setup(owner_host: Node3D, supplied_hooks: Dictionary={}, saved: Variant=null) -> String:
	host=owner_host;hooks=supplied_hooks
	src=State.source()
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(State.MEDIA)) if FileAccess.file_exists(State.MEDIA) else null
	if not parsed is Dictionary: return "Dawn media missing (run tools/prepare_jungle_dawn_media.py)."
	media=parsed
	population=Body.new()
	population.name="DawnBody";population.configure(POP_CONFIG);add_child(population)
	var error: String=population.setup(host)
	if not error.is_empty(): return error
	population.set_physics_process(false)
	mesh=MeshInstance3D.new();mesh.mesh=QuadMesh.new()
	var shader:=Shader.new();shader.code=SHADER
	var material:=ShaderMaterial.new();material.shader=shader;mesh.material_override=material
	mesh.visible=false;add_child(mesh)
	voice=AudioStreamPlayer3D.new();add_child(voice)
	if media.clip.get("audio")!=null: voice_stream=AudioStreamWAV.load_from_file(str(media.clip.audio))
	combat=preload("res://scripts/lol2/dawn_modern_combat.gd").new();combat.dawn=self;combat.name="Combat";add_child(combat)
	return restore(saved if saved!=null else initial())

## ---- saved packet ---------------------------------------------------------------------------
func initial() -> Dictionary:
	return {"version":1,"state":State.initial(src),"body":Generic.initial(population.src),"inside":[],"hold":false,"receipts":[]}

func validate(packet: Variant) -> String: return Packet.validate(packet)

func checkpoint() -> Dictionary:
	_mirror_damage()
	var packet: Dictionary={"version":1,"state":state.duplicate(true),"body":population.checkpoint(),"inside":inside.duplicate(),"hold":hold,"receipts":receipts.duplicate()}
	var effects: Dictionary=projectiles.checkpoint()
	if effects!=projectiles.initial():packet.projectiles=effects
	var fighting: Dictionary=combat.checkpoint()
	if fighting!=combat.initial():packet.combat=fighting
	return packet

## Atomic: an invalid packet changes nothing.
func restore(packet: Variant) -> String:
	var error:=validate(packet)
	if not error.is_empty(): return error
	error=population.restore(packet.body)
	if not error.is_empty(): return error
	projectiles.restore(packet.get("projectiles",projectiles.initial()))
	state=State.canonical(packet.state)
	combat.restore(packet.get("combat",combat.initial()))
	inside=packet.inside.map(func(r):return int(r));hold=bool(packet.hold);receipts=packet.receipts.duplicate()
	host.curse.restore_legacy_dawn_admission(receipts)
	_start_voice();_sync_body(0.0);_present()
	return ""

## ---- host links ------------------------------------------------------------------------------
func world_active() -> bool: return host.starting_magic!=null and host.starting_magic.world_active()
func origin() -> Vector3: return population.origin()

## Shared world launch boundary for the effect owner. Source launch getters are
## supplied by that owner; this method binds map membership, physics and caster
## exclusion without mutating dialogue, health or saved encounter state.
func query_projectile_launch(context: Dictionary, target: Variant=null) -> Dictionary:
	var excluded: Array[RID]=[population.bodies[ID].get_rid()]
	return preload("res://scripts/lol2/dawn_projectile_world.gd").launch(
		get_world_3d().direct_space_state,population.navigation,origin(),context,target,excluded)

## Only a sweep naming the actual player RID can enter the live health path.
## Difficulty/mitigation/gates and collision bearing still come from the owner.
func damage_projectile_player(id: int, sweep: Dictionary, collision_heading: int, source_context: Dictionary) -> Dictionary:
	if sweep.get("blocked")!=true or not sweep.get("contact") is Dictionary or sweep.contact.get("rid")!=host.player.get_rid():
		return {"error":"Projectile did not collide with the live player."}
	var found:=false
	for effect in projectiles.checkpoint().effects:
		if effect.id==id:
			found=true
			if effect.position!=sweep.get("position"):return {"error":"Stale projectile collision position."}
	if not found:return {"error":"Unknown player collision projectile."}
	var supplied:=preload("res://scripts/lol2/dawn_player_damage.gd").live_context(host.starting_magic,preload("res://scripts/lol2/player_defense.gd").scalar(host),int(population.state.live[ID].heading),host.player.rotation.y,source_context)
	if supplied.has("error"):return supplied
	return preload("res://scripts/lol2/dawn_player_damage.gd").direct(host.starting_magic,projectiles,id,collision_heading,supplied)

## Player distance comes from the actual host position. Other world neighbors
## remain supplied; an unbound damage recipient prevents consuming the pass.
func damage_projectile_explosion(id: int, player_flags: int, other_neighbors: Array, source_context: Dictionary) -> Dictionary:
	var effect: Dictionary={}
	for row in projectiles.checkpoint().effects:
		if row.id==id:effect=row
	if effect.is_empty() or effect.kind!=98:return {"error":"Unknown explosion."}
	var point: Vector3=host.player.global_position-origin()
	var distance:=preload("res://scripts/lol2/hive_condition_geometry.gd").distance_between_startup(effect.position.slice(0,2),[roundi(point.x*65536),roundi(-point.z*65536)])
	if distance.has("error") or distance.integer_invalid:return {"error":"Unsupported explosion player distance."}
	var Damage=preload("res://scripts/lol2/dawn_player_damage.gd")
	var neighbors:=other_neighbors.duplicate(true)
	neighbors.append({"id":Damage.PLAYER,"kind":1,"flags":player_flags,"distance":distance.distance,"direct":false})
	var supplied:=preload("res://scripts/lol2/dawn_player_damage.gd").live_context(host.starting_magic,preload("res://scripts/lol2/player_defense.gd").scalar(host),int(population.state.live[ID].heading),host.player.rotation.y,source_context)
	if supplied.has("error"):return supplied
	return Damage.explosion(host.starting_magic,projectiles,id,neighbors,supplied)

## Explicit shared-clock entry; scheduler/collision dispatch remain caller-owned.
func move_projectile(id: int, world_delta: int, radius: float) -> Dictionary:
	var motion: Dictionary=projectiles.motion(id,world_delta)
	if motion.has("error"):return motion
	var excluded: Array[RID]=[population.bodies[ID].get_rid()]
	var result:=preload("res://scripts/lol2/dawn_projectile_world.gd").sweep(
		get_world_3d().direct_space_state,origin(),motion.from,motion.to,radius,excluded)
	if result.has("error"):return result
	var error: String=projectiles.moved(id,motion.from,result.position)
	return {"error":error} if not error.is_empty() else result


## The source hold (0x26..0x27) spans her whole talk and wait. While she speaks every input is held; while she waits
## (looping idle) the player stays in place but can look, open the inventory, offer an item or strike.
func talking() -> bool: return not state.clip.is_empty() and not bool(state.clip.repeat)
func input_locked() -> bool: return hold and talking()
func movement_locked() -> bool: return hold
func hostile() -> bool: return bool(state.present) and int(state.health)>0 and (int(state.b5)&12)!=0 and (int(state.b5)&1)==0

func context() -> Dictionary:
	var ctx: Dictionary={}
	if hooks.has("context") and hooks.context is Callable and hooks.context.is_valid():
		var value=hooks.context.call()
		if value is Dictionary: ctx=value.duplicate(true)
	if not ctx.has("shared"): ctx.shared={}
	if not ctx.has("locals"): ctx.locals={}
	return ctx

func held_item() -> String:
	if hooks.has("held_item") and hooks.held_item is Callable and hooks.held_item.is_valid(): return str(hooks.held_item.call())
	return ""

static func identity(item: String) -> int:
	if item.is_empty(): return 0
	return WAX_IDENTITY if Runes.valid(item) else HELD_IDENTITY

## ---- producers ---------------------------------------------------------------------------------
func _ray_to_body(from: Vector3, reach: float, mask: int) -> Dictionary:
	var to: Vector3=from-host.camera.global_basis.z*reach
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,mask,[host.player.get_rid()]))

func _aimed() -> bool:
	if not state.present or int(state.health)<=0 or host.get_tree().paused: return false
	if host.get("interface_hud")!=null and is_instance_valid(host.interface_hud) and host.interface_hud.cursor_active: return false
	var hit:=_ray_to_body(host.camera.global_position,REACH,3)
	return not hit.is_empty() and hit.collider==population.bodies[ID]

## Kind5 support/visibility: her body point inside the production frustum with nothing solid in between.
func visible_to_camera() -> bool:
	if not state.present or int(state.health)<=0: return false
	var point: Vector3=population.bodies[ID].global_position+Vector3.UP*40
	var eye: Vector3=host.camera.global_position
	if eye.distance_to(point)>SIGHT or not host.camera.is_position_in_frustum(point): return false
	var query:=PhysicsRayQueryParameters3D.create(eye,point,1,[host.player.get_rid(),population.bodies[ID].get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func can_use() -> bool: return world_active() and not talking() and not hostile() and _aimed()

func use() -> bool:
	if not can_use(): return false
	var effects:=State.offer(state,src,identity(held_item()),context())
	_apply(effects);_present()
	return not effects.is_empty()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and use():
		get_viewport().set_input_as_handled()

## Generic health loss (player melee/spell) enters the source as the kind9 hit record (melee 2/4, Spark 1/1).
func _mirror_damage() -> void:
	var body: Dictionary=population.state.actors[ID]
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
	# Sighting first: a region entered in the same step as her first sighting sees her movie already loaded.
	if not state.sighted and visible_to_camera(): _apply(State.sight(state,src,ctx))
	_regions(ctx)
	if not state.sighted and visible_to_camera(): _apply(State.sight(state,src,ctx))
	_mirror_damage()
	_apply(State.advance(state,src,media,delta,ctx))
	_sync_body(delta)
	combat.advance(delta)
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
			# Modern safeguard: walking into her area counts as noticing her even if the camera faced away, so her
			# talk (whose movie the sighting loads) can never start unloaded and soft-lock the 0x26 hold.
			if state.present and not state.sighted: _apply(State.sight(state,src,ctx))
			state.region=-1 # the state models an entry edge per call
			_apply(State.enter_region(state,src,r,ctx))
	inside=now

func _sync_body(delta: float) -> void:
	var body: Dictionary=population.state.actors[ID]
	if not state.present and body.present:
		var fresh: Dictionary=Generic.initial(population.src)
		population.state.actors[ID]=fresh.actors[ID].duplicate(true);population.state.actors[ID].present=false
		population.state.live[ID]=fresh.live[ID].duplicate(true)
	elif state.present and not body.present: Generic.spawn(population.state,ID)
	body=population.state.actors[ID]
	body.health=int(state.health)
	# Source hit admission covers a peaceful Dawn too, so strikes are live whenever she stands outside a clip/hold.
	var strikeable: bool=state.present and int(state.health)>0 and not talking()
	population.set_process_unhandled_input(strikeable);population.set_process(strikeable)
	population.state.live[ID].mode=Live.IDLE
	if hostile() and not body.woken: Generic.wake(population.state,ID)
	# Body rise/death/corpse use generic clocks; modern attacks run in combat.advance.
	if delta>0 and (body.woken or int(state.health)==0): Generic.advance_clocks(population.state,population.src,delta)
	population.present()

## ---- effects ---------------------------------------------------------------------------------------
func _apply(effects: Array) -> void:
	for e in effects:
		effect_log.append(e)
		match str(e.type):
			"player_property": _player_property(e)
			"reposition": _reposition(e)
			"clip": _start_voice()
			"shared": _write_shared(e)
			"external","actor_property","actor_command": _receipt(e)
		if hooks.has("effects") and hooks.effects is Callable and hooks.effects.is_valid() and str(e.type)!="group": hooks.effects.call(e)
	if effect_log.size()>400: effect_log=effect_log.slice(effect_log.size()-400)

func _receipt(e: Dictionary) -> void:
	var key:=str(e.get("raw",""))
	if not key.is_empty() and key not in receipts and receipts.size()<MAX_RECEIPTS: receipts.append(key)

func _player_property(e: Dictionary) -> void:
	match int(e.property):
		0x24,0x25:
			host.curse.set_requests_enabled(int(e.property)==0x24)
			_receipt(e)
		0x26: hold=true
		0x27: hold=false
		0x0b:
			if host.get("quest_state") is Dictionary:
				var result:=Rewards.fighting(host.quest_state,int(e.value)*100)
				if result.has("error"): push_error(result.error)
				else: host.quest_state=result.quests
		0x0c:
			if host.starting_magic!=null and host.starting_magic.has_method("magic_state"):
				var result:=Rewards.magic(host.starting_magic.magic_state(),int(e.value)*100)
				if result.has("error"): push_error(result.error)
				else: host.starting_magic.commit(result.checkpoint)
		0x18:
			# Takes the held item (the offer that was just admitted).
			if hooks.has("consume_held") and hooks.consume_held is Callable and hooks.consume_held.is_valid(): hooks.consume_held.call()
		0x3c:
			if host.get("curse")!=null and host.curse.has_method("request_human"): host.curse.request_human()
		_: _receipt(e)

## Opcode206/199 through the host's named-global writer (caps owned there).
func _write_shared(e: Dictionary) -> void:
	if hooks.has("shared") and hooks.shared is Callable and hooks.shared.is_valid(): hooks.shared.call(e)
	else: _receipt({"raw":"%02x%02x%02x"%[int(e.index),1 if str(e.op)=="set" else 0,int(e.value)&255]})

func _reposition(e: Dictionary) -> void:
	var p: Array=e.position
	var target:=Vector3(p[0],host.player.global_position.y,p[2])+Vector3(origin().x,0,origin().z)
	var down:=PhysicsRayQueryParameters3D.create(target+Vector3.UP*400,target-Vector3.UP*800,1,[host.player.get_rid(),population.bodies[ID].get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(down)
	if not hit.is_empty(): target.y=hit.position.y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	host.player.global_position=target;host.player.velocity=Vector3.ZERO

## ---- presentation ----------------------------------------------------------------------------------
func _segment() -> Dictionary:
	return media.clip.segments[int(state.clip.segment)] if not state.clip.is_empty() else {}

func clip_frame() -> int:
	var seg:=_segment()
	if seg.is_empty(): return -1
	return mini(int(seg.first)+int(float(state.clip.elapsed)*float(media.clip.fps)),int(seg.last))

## Talk segments play their slice of the single E065E voice track; the looping idle segment is silent.
func _start_voice() -> void:
	voice.stop()
	var seg:=_segment()
	if seg.is_empty() or bool(state.clip.repeat) or voice_stream==null: return
	voice.stream=voice_stream
	var start: float=float(seg.first)/float(media.clip.fps)+float(state.clip.elapsed)
	if start<float(voice_stream.get_length()): voice.play(start)

func _texture(path: String) -> Texture2D:
	if not textures.has(path):
		if textures.size()>96: textures.clear()
		textures[path]=ImageTexture.create_from_image(Image.load_from_file(path))
	return textures[path]

func _present() -> void:
	var showing: bool=state.present and not state.clip.is_empty()
	mesh.visible=showing
	if population.meshes.has(ID): population.meshes[ID].visible=bool(state.present) and not showing
	if not showing:
		if voice.playing: voice.stop()
		return
	var seg:=_segment()
	# The voice slice ends with its segment (the shared track continues into the next line otherwise).
	if voice.playing and voice.get_playback_position()>=float(seg.last+1)/float(media.clip.fps): voice.stop()
	var quad: QuadMesh=mesh.mesh
	quad.size=Vector2(float(media.clip.width),float(media.clip.height))*CLIP_SCALE;quad.center_offset=Vector3(0,quad.size.y/2.0,0)
	mesh.global_position=population.bodies[ID].global_position
	mesh.material_override.set_shader_parameter("frame",_texture(str(media.clip.frame_files[clip_frame()])))

func targets() -> Dictionary:
	return population.targets() if state.present and int(state.health)>0 else {}
