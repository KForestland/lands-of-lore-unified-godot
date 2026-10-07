extends Node3D
## Live Hive Dawn20: the prop71/actor20 source chain (hive_dawn20_state.gd) on the Hive host, presented with her
## original E075E segments and voice, plus the unchanged generic creature owner for her body (target, death).
## Producers: the existing RUNES room entry (hive_rune_entry: control0 group5244, opcode9 prop71 property21) queues
## prop71 kind6/20 on entry and runs it when the room closes; E-use while aimed at her with any held item (kind4 mode1;
## empty hand none); generic damage mirrored as the kind9 hit (threshold1, one-shot); her kind2 timer.
## Shared writes go to the carried monastery globals by source name (GV_RUNES_TRANSLATED, GV_LUTHERS_SOUL,
## GV_DAWN_RELATIONSHIP). Player properties 0x26/0x27 hold/release; actor properties 5/6 (talk focus: she is
## faced while held) and other external commands are saved receipts.
## After a hit she takes goals13/7 (hostile b5); the shared modern combat controller then attacks.
## Grounded entry into source region478 (edge saved as state.region) runs group906 (pred192: unload her clip, prop318
## property10 receipt). Adapter: her kind5 values 6/262 have no bound producer.
const State=preload("res://scripts/lol2/hive_dawn20_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const Packet=preload("res://scripts/lol2/hive_dawn20_packet.gd")
const POP_CONFIG:={"root":"res://assets/lol2/generated/hive_dawn20_media/sprites/","source":"res://scripts/lol2/hive_dawn20_population_source.json",
	"target_prefix":"hivedawn","fighting_owner":"carried_quest_checkpoint","nav":"res://assets/lol2/generated/creature_nav/L5_HC.json",
	"names":{"3":"Dawn"},"look":{"3":{"canvas":[320,200],"scale":0.47,"floor_row":187,"radius":16,"height":56}}}
const ID:="20"
## Any carried item: only its non-emptiness matters to her mode1 records.
const HELD_IDENTITY:=1
const CLIP_SCALE:=0.47
const REACH:=110.0
const SIGHT:=1600.0
const MAX_RECEIPTS:=Packet.MAX_RECEIPTS
class Body extends "res://scripts/lol2/scripted_creature_population.gd":
	var last_melee:=true
	## The shared melee rule (cave_melee_reward) runs on the Hive's carried quests; the Hive banks progression in
	## player_reward_checkpoint (as its return/executioner owners do), so it is handed in and taken back.
	func receive_damage(id: String, amount: int, melee: bool=true, effect: int=20) -> bool:
		last_melee=melee
		if not melee or not host.get("player_reward_checkpoint") is Dictionary: return super.receive_damage(id,amount,melee,effect)
		if not host.player_reward_checkpoint.is_empty(): host.carried_quest_checkpoint["player_reward_state"]=host.player_reward_checkpoint.duplicate(true)
		var ok: bool=super.receive_damage(id,amount,melee,effect)
		if ok and host.carried_quest_checkpoint.has("player_reward_state"): host.player_reward_checkpoint=host.carried_quest_checkpoint.player_reward_state.duplicate(true)
		return ok
	func strike() -> bool:
		if host.has_method("actor_input_locked") and host.actor_input_locked(): return false
		return super.strike()
const SHADER:="shader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform sampler2D frame : source_color, filter_nearest, repeat_disable;\nvoid vertex() {\n\tvec3 up = vec3(0.0, 1.0, 0.0);\n\tvec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));\n\tMODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(cross(right, up), 0.0), MODEL_MATRIX[3]);\n}\nvoid fragment() {\n\tvec4 c = texture(frame, UV);\n\tif (c.a < 0.5) { discard; }\n\tALBEDO = c.rgb;\n}\n"
var combat: Node3D
var host: Node3D
var hooks: Dictionary={}
var src: Dictionary
var media: Dictionary
var projectiles:=preload("res://scripts/lol2/dawn_projectile_store.gd").new()
var state: Dictionary
var population: Node3D
var hold:=false
var receipts: Array=[]
var effect_log: Array=[]
var mesh: MeshInstance3D
var voice: AudioStreamPlayer3D
var voice_stream: AudioStream
var textures: Dictionary={}

static func assets_ready() -> bool:
	return FileAccess.file_exists(State.MEDIA) and FileAccess.file_exists(State.SOURCE) and FileAccess.file_exists(str(POP_CONFIG.source))

func setup(owner_host: Node3D, supplied_hooks: Dictionary={}, saved: Variant=null) -> String:
	host=owner_host;hooks=supplied_hooks
	if not assets_ready(): return "Hive Dawn media missing (run tools/prepare_hive_dawn20_media.py)."
	src=State.source()
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(State.MEDIA))
	if not parsed is Dictionary or str(parsed.get("source_sha256",""))!=FileAccess.get_sha256(State.SOURCE): return "Hive Dawn media does not match the source contract."
	media=parsed
	population=Body.new()
	population.name="HiveDawnBody";population.configure(POP_CONFIG);add_child(population)
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
	return {"version":1,"state":State.initial(src),"body":Generic.initial(population.src),"hold":false,"receipts":[]}

func checkpoint() -> Dictionary:
	_mirror_damage()
	var packet: Dictionary={"version":1,"state":state.duplicate(true),"body":population.checkpoint(),"hold":hold,"receipts":receipts.duplicate()}
	var effects: Dictionary=projectiles.checkpoint()
	if effects!=projectiles.initial():packet.projectiles=effects
	var fighting: Dictionary=combat.checkpoint()
	if fighting!=combat.initial():packet.combat=fighting
	return packet

## Atomic: an invalid packet changes nothing.
func restore(packet: Variant) -> String:
	var error:=Packet.validate(packet)
	if not error.is_empty(): return error
	error=population.restore(packet.body)
	if not error.is_empty(): return error
	projectiles.restore(packet.get("projectiles",projectiles.initial()))
	state=State.canonical(packet.state)
	combat.restore(packet.get("combat",combat.initial()))
	hold=bool(packet.hold);receipts=packet.receipts.duplicate()
	_start_voice();_sync_body(0.0);_present()
	return ""

## ---- host links ------------------------------------------------------------------------------
func set_up() -> bool: return state!=null and not state.is_empty() and voice!=null
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


## The source hold (0x26..0x27) spans her talk; while she speaks every input is held.
func talking() -> bool: return set_up() and not state.clip.is_empty() and not bool(state.clip.repeat)
func input_locked() -> bool: return set_up() and hold and talking()
func movement_locked() -> bool: return set_up() and hold
func hostile() -> bool: return set_up() and bool(state.present) and int(state.health)>0 and (int(state.b5)&12)!=0 and (int(state.b5)&1)==0

## Shared operands by source index from the carried monastery globals (named bank).
func context() -> Dictionary:
	var globals: Dictionary=host.monastery_checkpoint.get("globals",{}) if host.get("monastery_checkpoint") is Dictionary else {}
	var shared: Dictionary={}
	for index in src.shared_names: shared[index]=int(globals.get(str(src.shared_names[index]),0))
	return {"shared":shared,"locals":{}}

func held_item() -> String:
	if hooks.has("held_item") and hooks.held_item is Callable and hooks.held_item.is_valid(): return str(hooks.held_item.call())
	return str(host.get("equipped_item")) if host.get("equipped_item")!=null else ""

## ---- producers ---------------------------------------------------------------------------------
## RUNES room entry (opcode9 prop71 property21): admitted groups are queued now and run when the room closes.
func room_entered() -> void:
	if set_up(): State.link(state,src,context())
func room_closed() -> void:
	if not set_up(): return
	_apply(State.run_link(state,src,context()))
	_sync_body(0.0);_present()

func _aimed() -> bool:
	if not state.present or int(state.health)<=0 or host.get_tree().paused: return false
	if host.get("interface_hud")!=null and is_instance_valid(host.interface_hud) and host.interface_hud.cursor_active: return false
	var to: Vector3=host.camera.global_position-host.camera.global_basis.z*REACH
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(host.camera.global_position,to,3,[host.player.get_rid()]))
	return not hit.is_empty() and hit.collider==population.bodies[ID]

func visible_to_camera() -> bool:
	if not state.present or int(state.health)<=0: return false
	var point: Vector3=population.bodies[ID].global_position+Vector3.UP*40
	var eye: Vector3=host.camera.global_position
	if eye.distance_to(point)>SIGHT or not host.camera.is_position_in_frustum(point): return false
	var query:=PhysicsRayQueryParameters3D.create(eye,point,1,[host.player.get_rid(),population.bodies[ID].get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func can_use() -> bool: return set_up() and world_active() and not talking() and not hostile() and _aimed()

func use() -> bool:
	if not can_use(): return false
	var effects:=State.offer(state,src,HELD_IDENTITY if not held_item().is_empty() else 0,context())
	_apply(effects);_present()
	return not effects.is_empty()

## Generic health loss (player melee/spell) enters the source as the kind9 hit record.
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
	if not set_up(): return
	var running: bool=world_active() and not get_tree().paused
	voice.stream_paused=not running
	if not is_finite(delta) or delta<=0 or not running: return
	var ctx:=context()
	if not state.sighted and visible_to_camera(): _apply(State.sight(state,src,ctx))
	_regions(ctx)
	_mirror_damage()
	_apply(State.advance(state,src,media,delta,ctx))
	_sync_body(delta)
	combat.advance(delta)
	_mirror_damage()
	if hold and state.present: _face()
	_present()

## Kind2 region entry edges: inside a source polygon within its floor band (as Dawn63); the saved state.region holds
## the current region, so leaving resets it and re-entry raises the event again.
func _regions(ctx: Dictionary) -> void:
	var p: Vector3=host.player.global_position-origin()
	var foot: float=p.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	var now:=-1
	for region in src.regions:
		if foot<float(region.floor_min)-1 or foot>float(region.floor_max)+3: continue
		var polygon:=PackedVector2Array()
		for v in region.polygon: polygon.append(Vector2(v[0],v[1]))
		if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon): now=int(region.region)
	if now==-1: state.region=-1
	elif int(state.region)!=now: _apply(State.enter_region(state,src,now,ctx))

func _face() -> void:
	var at: Vector3=population.bodies[ID].global_position
	var look:=Vector3(at.x,host.player.global_position.y,at.z)
	if look.distance_to(host.player.global_position)<=1.0 or not talking(): return
	host.player.look_at(look);host.camera.rotation.y=0
	# Frame her upper body (talk focus), as the source scene presents the speaker.
	var to: Vector3=at+Vector3.UP*float(media.clip.height)*CLIP_SCALE*0.7-host.camera.global_position
	host.camera.rotation.x=clampf(atan2(to.y,Vector2(to.x,to.z).length()),-1.4,1.4)

func _sync_body(delta: float) -> void:
	var body: Dictionary=population.state.actors[ID]
	if not state.present and body.present:
		var fresh: Dictionary=Generic.initial(population.src)
		population.state.actors[ID]=fresh.actors[ID].duplicate(true);population.state.actors[ID].present=false
		population.state.live[ID]=fresh.live[ID].duplicate(true)
	elif state.present and not body.present: Generic.spawn(population.state,ID)
	body=population.state.actors[ID]
	# An absent body keeps its placement health (generic validator); only a present one mirrors the source.
	if state.present: body.health=int(state.health)
	var strikeable: bool=state.present and int(state.health)>0 and not talking()
	population.set_process_unhandled_input(strikeable);population.set_process(strikeable)
	population.state.live[ID].mode=Live.IDLE
	if hostile() and not body.woken: Generic.wake(population.state,ID)
	if delta>0 and (body.woken or int(state.health)==0): Generic.advance_clocks(population.state,population.src,delta)
	population.present()

## ---- effects ---------------------------------------------------------------------------------------
func _apply(effects: Array) -> void:
	for e in effects:
		effect_log.append(e)
		match str(e.type):
			"player_property": _player_property(e)
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
		0x26: hold=true
		0x27: hold=false
		_: _receipt(e)

## Opcode199 set / opcode206 signed add on the carried named globals. The live monastery bank keeps these signed
## (GV_LUTHERS_SOUL validated to ±1000), so no native byte wrap is applied.
func _write_shared(e: Dictionary) -> void:
	var name:=str(src.shared_names.get(str(int(e.index)),""))
	if name.is_empty() or not host.get("monastery_checkpoint") is Dictionary:
		_receipt({"raw":"%02x%02x%02x"%[int(e.index),1 if str(e.op)=="set" else 0,int(e.value)&255]});return
	if not host.monastery_checkpoint.has("globals"): host.monastery_checkpoint.globals={}
	var globals: Dictionary=host.monastery_checkpoint.globals
	var value:=int(e.value) if str(e.op)=="set" else int(globals.get(name,0))+int(e.value)
	globals[name]=value

## ---- presentation ----------------------------------------------------------------------------------
func _segment() -> Dictionary:
	return media.clip.segments[int(state.clip.segment)] if not state.clip.is_empty() else {}

func clip_frame() -> int:
	var seg:=_segment()
	if seg.is_empty(): return -1
	return mini(int(seg.first)+int(float(state.clip.elapsed)*float(media.clip.fps)),int(seg.last))

## Talk segments play their slice of the single E075E voice track; the looping idle segment is silent.
func _start_voice() -> void:
	voice.stop()
	var seg:=_segment()
	if seg.is_empty() or bool(state.clip.repeat) or voice_stream==null: return
	voice.stream=voice_stream
	voice.global_position=population.bodies[ID].global_position+Vector3.UP*40
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
	if voice.playing and voice.get_playback_position()>=float(seg.last+1)/float(media.clip.fps): voice.stop()
	var quad: QuadMesh=mesh.mesh
	quad.size=Vector2(float(media.clip.width),float(media.clip.height))*CLIP_SCALE;quad.center_offset=Vector3(0,quad.size.y/2.0,0)
	mesh.global_position=population.bodies[ID].global_position
	mesh.material_override.set_shader_parameter("frame",_texture(str(media.clip.frame_files[clip_frame()])))

func targets() -> Dictionary:
	return population.targets() if set_up() and state.present and int(state.health)>0 else {}
