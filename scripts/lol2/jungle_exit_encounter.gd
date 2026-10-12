extends Node3D
## Live Jungle exit encounter consumer (guards58-60, prop4398 endings).
## Authority split: jungle_exit_encounter_state.gd owns source phase, presence, B5 blocking, owned
## locals, timers, health/defeat count and the ending; the unchanged generic owner
## scripted_creature_population.gd owns bodies, original def9 frames, pursuit/attack, player
## strikes and melee rewards. Each step mirrors generic health loss into the source damage path
## (kind9 then event10) and spawn/remove/wake/block back into the generic packet.
## Supplied: context Callable -> {"shared":{13,14,18,47}, "locals":{41,49,51}} from the Jungle
## owner; prop552 first eligible visibility admits spawn_guards(), with a saved native-style latch. Region event2 fires on
## entry into the source polygons (edge, saved). No automatic spawn or departure gate.
## Adapters (not native timing claims): opcode8 argument2 on a guard is acknowledged when that
## guard's scripted pose clip (VQA, 15fps) ends, every other opcode8 at once; event0 is that clip
## end; blocked guards are held idle; ending reposition is applied after the movie.
const State=preload("res://scripts/lol2/jungle_exit_encounter_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Live=preload("res://scripts/lol2/creature_live_rules.gd")
const MEDIA:="res://assets/lol2/generated/jungle_exit_movies/movies.json"
const GUARD_CONFIG:={"root":"res://assets/lol2/generated/jungle_exit_guard_sprites/","source":"res://scripts/lol2/jungle_exit_guard_population_source.json","target_prefix":"jungleexitguard","fighting_owner":"quest_state","nav":"res://assets/lol2/generated/creature_nav/L4_HJ.json",
	"names":{"9":"Guard"},"look":{"9":{"canvas":[400,248],"scale":0.47,"floor_row":236,"radius":15,"height":46}}}
const POSE_SCALE:=0.47
const POSE_SHADER:="shader_type spatial;\nrender_mode unshaded, cull_disabled;\nuniform sampler2D frame : source_color, filter_nearest, repeat_disable;\nvoid vertex() {\n\tvec3 up = vec3(0.0, 1.0, 0.0);\n\tvec3 right = normalize(cross(up, INV_VIEW_MATRIX[2].xyz));\n\tMODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(right, 0.0), vec4(up, 0.0), vec4(cross(right, up), 0.0), MODEL_MATRIX[3]);\n}\nvoid fragment() {\n\tvec4 c = texture(frame, UV);\n\tif (c.a < 0.5) { discard; }\n\tALBEDO = c.rgb;\n}\n"
var host: Node3D
var src: Dictionary
var media: Dictionary
var clips: Dictionary={}      # selector -> {duration, frames, textures, audio}
var endings: Dictionary={}    # movie name -> playback row
var population: Node3D
var context_provider: Callable
var effect_handler: Callable
var encounter: Dictionary
var poses: Dictionary={}
var movie: Dictionary={"phase":"none","elapsed":0.0}
var inside: Array=[]
var visibility:={"seen":false,"present":false}
var effect_log: Array=[]
var released: Dictionary={}
var pose_meshes: Dictionary={}
var pose_voices: Dictionary={}
var overlay: CanvasLayer
var picture: TextureRect
var atlas: AtlasTexture
var voice: AudioStreamPlayer
var page:=-1
var page_movie:=""
var host_paused:=false

func setup(owner_host: Node3D, context: Callable=Callable(), effects: Callable=Callable(), saved: Variant=null) -> String:
	host=owner_host;context_provider=context;effect_handler=effects
	src=State.source()
	var error:=_load_media()
	if not error.is_empty(): return error
	population=preload("res://scripts/lol2/scripted_creature_population.gd").new()
	population.name="ExitGuards";population.configure(GUARD_CONFIG)
	add_child(population)
	error=population.setup(host)
	if not error.is_empty(): return error
	population.set_physics_process(false) # stepped by advance() so source blocking applies first
	var shader:=Shader.new();shader.code=POSE_SHADER
	for id in State.GUARDS:
		var mesh:=MeshInstance3D.new();mesh.mesh=QuadMesh.new()
		var material:=ShaderMaterial.new();material.shader=shader;mesh.material_override=material
		mesh.visible=false;add_child(mesh);pose_meshes[id]=mesh
		var sound:=AudioStreamPlayer3D.new();add_child(sound);pose_voices[id]=sound
	_build_overlay()
	return restore(saved if saved!=null else initial())

func _load_media() -> String:
	var parsed=JSON.parse_string(FileAccess.get_file_as_string(MEDIA))
	if not parsed is Dictionary or parsed.get("version")!=1: return "Exit encounter media missing (run tools/prepare_jungle_exit_movies.py)."
	media=parsed
	for row in media.poses:
		var textures: Array=[]
		for f in row.frame_files:
			if FileAccess.get_sha256(f.file)!=str(f.png_sha256): return "Exit pose frame hash differs."
			textures.append(ImageTexture.create_from_image(Image.load_from_file(f.file)))
		clips[int(row.selector)]={"duration":float(row.duration),"frames":int(row.frames),"textures":textures,"size":Vector2(row.width,row.height),"audio":AudioStreamWAV.load_from_file(row.audio)}
	for row in media.endings:
		for path in row.atlases+[row.audio]:
			if not FileAccess.file_exists(path): return "Exit ending media missing."
		endings[str(row.movie)]=row
	for e in src.endings:
		if not endings.has(str(e.movie)) or str(endings[str(e.movie)].movie_sha256)!=str(e.movie_sha256): return "Exit ending media differs from source."
	return ""

func _build_overlay() -> void:
	overlay=CanvasLayer.new();overlay.layer=41;overlay.visible=false
	var background:=ColorRect.new();background.color=Color.BLACK
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(background)
	picture=TextureRect.new();picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	atlas=AtlasTexture.new();picture.texture=atlas;overlay.add_child(picture)
	voice=AudioStreamPlayer.new();overlay.add_child(voice)
	add_child(overlay)

## ---- saved packet ----------------------------------------------------------------------------

func initial() -> Dictionary:
	return {"version":1,"encounter":State.initial(src),"guards":Generic.initial(population.src),"poses":{"58":-1.0,"59":-1.0,"60":-1.0},"movie":{"phase":"none","elapsed":0.0},"inside":[],"visibility":{"seen":false,"present":false}}

func validate(packet: Variant) -> String:
	return preload("res://scripts/lol2/jungle_exit_packet.gd").validate(packet)

func checkpoint() -> Dictionary:
	_mirror_damage(context())
	_sync_population()
	return {"version":1,"encounter":encounter.duplicate(true),"guards":population.checkpoint(),"poses":poses.duplicate(),"movie":movie.duplicate(),"inside":inside.duplicate(),"visibility":visibility.duplicate()}

## Atomic: an invalid packet changes nothing.
func restore(packet: Variant) -> String:
	var error:=validate(packet)
	if not error.is_empty(): return error
	error=population.restore(packet.guards)
	if not error.is_empty(): return error
	encounter=State.canonical(packet.encounter,src)
	poses={};for id in State.GUARDS: poses[id]=float(packet.poses[id])
	movie={"phase":str(packet.movie.phase),"elapsed":float(packet.movie.elapsed)}
	visibility=packet.get("visibility",{"seen":int(encounter.locals["56"])>0,"present":int(encounter.locals["56"])>0 and int(encounter.locals["42"])<2}).duplicate()
	inside=packet.inside.map(func(r):return int(r))
	released.clear()
	for id in State.GUARDS:
		pose_voices[id].stop()
		if poses[id]>=0: _start_pose_voice(id)
	page=-1;voice.stop()
	_present_movie(true)
	_present()
	return ""

## ---- supplied triggers ---------------------------------------------------------------------

func context() -> Dictionary:
	var supplied: Dictionary={}
	if context_provider.is_valid():
		var value=context_provider.call()
		if value is Dictionary: supplied=value
	return {"shared":supplied.get("shared",{}),"locals":supplied.get("locals",{}),"opcode8":_opcode8,"supplied":context_provider.is_valid()}

## Prop552 kind5 value0; production caller is _visible_spawn(). Tests may supply the event directly. Returns whether any source group ran.
func spawn_guards() -> bool:
	if movie.phase=="playing": return false
	var effects:=State.spawn_guards(encounter,src,context())
	_apply(effects);_sync_population();_present()
	return not effects.is_empty()

func _opcode8(command: Dictionary) -> bool:
	if int(command.kind)==2 and int(command.argument)==2 and encounter.actors.has(str(int(command.target))):
		var id:=str(int(command.target))
		# Waits on the pose clip when one is playing; nothing to wait for otherwise.
		return released.has(id) or not clips.has(int(encounter.actors[id].pose))
	return true

## ---- step --------------------------------------------------------------------------------

func world_active() -> bool:
	return host.starting_magic!=null and host.starting_magic.world_active()

func active() -> bool:
	return movie.phase=="playing"

func _input(event: InputEvent) -> void:
	if not active(): return
	# The existing HUD owns F5/F9, including partial-movie saves. All gameplay/UI input waits.
	if event is InputEventKey and event.keycode in [KEY_F5,KEY_F9]: return
	get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void: advance(delta)

func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0: return
	if movie.phase=="playing":
		_advance_movie(delta);return
	if not world_active(): return
	var ctx:=context()
	if ctx.supplied:
		_visible_spawn()
		_regions(ctx)
	_mirror_damage(ctx)
	for id in State.GUARDS:
		if poses[id]<0: continue
		var clip: Dictionary=clips[int(encounter.actors[id].pose)]
		poses[id]=snappedf(poses[id]+delta,1.0/1024)
		if poses[id]<float(clip.duration): continue
		# Clip end: release this guard's opcode8 argument2, then its event0 (adapter order).
		released[id]=true
		_apply(State.resume(encounter,src,ctx))
		released.erase(id);poses[id]=-1.0;pose_voices[id].stop()
		_apply(State.pose_finished(encounter,src,id,ctx))
	_apply(State.resume(encounter,src,ctx))
	if movie.phase!="playing": _apply(State.advance(encounter,src,delta,ctx))
	_sync_population()
	if movie.phase=="playing": _present();return
	_step_population(delta)
	_mirror_damage(ctx)
	_present()

## Native F6C87 renderer eligibility is approximated with camera frustum + world occlusion.
## Predicate rejection must leave the latch clear, permitting post-translation re-evaluation.
func _visible_spawn() -> void:
	if visibility.seen or not visibility.present: return
	var p: Array=src.prop552.position
	var base: Vector3=Vector3(p[0],p[1],p[2])+population.origin()
	for height in [16.0,40.0,64.0]:
		var point: Vector3=base+Vector3.UP*height
		if not host.camera.is_position_in_frustum(point): continue
		var query:=PhysicsRayQueryParameters3D.create(host.camera.global_position,point,1,[host.player.get_rid()])
		var hit:=get_world_3d().direct_space_state.intersect_ray(query)
		if not hit.is_empty() and hit.position.distance_to(point)>2.0:
			var bacatta: Node=host.get("bacatta")
			if bacatta==null or hit.collider!=bacatta.prop_body: continue
		if spawn_guards(): visibility.seen=true
		return

func _regions(ctx: Dictionary) -> void:
	var p: Vector3=host.player.global_position-population.origin()
	var foot: float=p.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	var now: Array=[]
	for region in src.regions:
		if foot<float(region.floor_min)-1 or foot>float(region.floor_max)+3: continue
		var polygon:=PackedVector2Array()
		for v in region.polygon: polygon.append(Vector2(v[0],v[1]))
		if Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon): now.append(int(region.region))
	for r in now:
		if r not in inside: _apply(State.enter_region(encounter,src,r,ctx))
	inside=now

## Generic health loss (player melee/spells) enters the source as kind9 then event10.
func _mirror_damage(ctx: Dictionary) -> void:
	for id in State.GUARDS:
		var a: Dictionary=encounter.actors[id];var b: Dictionary=population.state.actors[id]
		if a.present and int(b.health)<int(a.health): _apply(State.damage(encounter,src,id,int(a.health)-int(b.health),ctx))

func _sync_population() -> void:
	var fresh: Dictionary=Generic.initial(population.src)
	for id in State.GUARDS:
		var a: Dictionary=encounter.actors[id];var b: Dictionary=population.state.actors[id]
		if a.present and not b.present: Generic.spawn(population.state,id)
		elif not a.present and b.present:
			population.state.actors[id]=fresh.actors[id].duplicate(true);population.state.live[id]=fresh.live[id].duplicate(true)
			var p: Array=fresh.actors[id].position
			population.bodies[id].position=Vector3(p[0],p[1],p[2])+population.origin()
		if State.fighting(encounter,id) and not population.state.actors[id].woken: Generic.wake(population.state,id)
	population.present()

## Source-blocked or undecided guards (B5) take no generic pursuit/attack step.
func _step_population(delta: float) -> void:
	var held: Dictionary={}
	for id in State.GUARDS:
		var b: Dictionary=population.state.actors[id]
		if b.present and int(b.health)>0 and not State.fighting(encounter,id):
			held[id]=[b.woken,b.rise];b.woken=false
			population.state.live[id].merge({"mode":Live.IDLE,"elapsed":0.0,"hit":false,"hits":0},true)
			population.state.live[id].erase("cooldown")
	population.advance(delta)
	for id in held:
		population.state.actors[id].woken=held[id][0];population.state.actors[id].rise=held[id][1]

func _apply(effects: Array) -> void:
	for e in effects:
		if str(e.type)!="reposition": effect_log.append(e)
		match str(e.type):
			"object":
				if int(e.kind)==3 and int(e.target)==552 and int(e.property)==2: visibility.present=false
			"pose":
				var id:=str(int(e.actor))
				if clips.has(int(e.selector)) and poses.get(id,-1.0)<0:
					poses[id]=0.0;_start_pose_voice(id)
			"movie":
				if movie.phase=="none" and not encounter.ending.is_empty():
					movie={"phase":"playing","elapsed":0.0};page=-1;_present_movie(true)
				continue
			"reposition":
				continue # applied after the movie, see _finish_movie()
		if effect_handler.is_valid() and str(e.type) not in ["group","damage","opcode8","wait"]: effect_handler.call(e)
	if effect_log.size()>400: effect_log=effect_log.slice(effect_log.size()-400)

## ---- movie ---------------------------------------------------------------------------------

func _advance_movie(delta: float) -> void:
	var row: Dictionary=endings[str(encounter.ending.movie)]
	movie.elapsed=snappedf(float(movie.elapsed)+delta,1.0/1024)
	if float(movie.elapsed)>=float(row.duration): _finish_movie()
	else: _present_movie(false)

func _finish_movie() -> void:
	movie={"phase":"done","elapsed":0.0}
	voice.stop()
	var row: Dictionary
	for e in src.endings:
		if str(e.movie)==str(encounter.ending.movie): row=e
	var p: Array=row.player_position
	var target:=Vector3(p[0],host.player.global_position.y,p[2])+Vector3(population.origin().x,0,population.origin().z)
	# Source y is 0 at this placement; the player keeps the floor found below the destination.
	var down:=PhysicsRayQueryParameters3D.create(target+Vector3.UP*400,target-Vector3.UP*800,1,[host.player.get_rid()])
	var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(down)
	if not hit.is_empty(): target.y=hit.position.y+preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
	host.player.global_position=target;host.player.velocity=Vector3.ZERO
	var effect:={"type":"reposition","position":p.duplicate(),"applied":[target.x,target.y,target.z]}
	effect_log.append(effect)
	if effect_handler.is_valid(): effect_handler.call(effect)
	_present_movie(true)

func _present_movie(changed: bool) -> void:
	var playing: bool=movie.phase=="playing"
	overlay.visible=playing
	if changed and playing!=host_paused:
		host_paused=playing
		host.set_physics_process(not playing)
		if is_instance_valid(population): population.set_process_unhandled_input(not playing)
	if not playing: return
	var row: Dictionary=endings[str(encounter.ending.movie)]
	var frame:=mini(int(float(movie.elapsed)*float(row.fps)),int(row.frames)-1)
	var per_page:=int(row.per_page)
	if page!=frame/per_page or page_movie!=str(row.movie):
		page=frame/per_page;page_movie=str(row.movie)
		atlas.atlas=ImageTexture.create_from_image(Image.load_from_file(row.atlases[page]))
	atlas.region=Rect2((frame%4)*640,((frame%per_page)/4)*400,640,400)
	if changed or not voice.playing:
		if voice.stream==null or voice.get_meta("movie","")!=str(row.movie):
			voice.stream=AudioStreamWAV.load_from_file(row.audio);voice.set_meta("movie",str(row.movie))
		if float(movie.elapsed)<float(row.audio_samples)/float(row.audio_rate): voice.play(float(movie.elapsed))

## ---- presentation --------------------------------------------------------------------------

func _start_pose_voice(id: String) -> void:
	var clip: Dictionary=clips[int(encounter.actors[id].pose)]
	pose_voices[id].stream=clip.audio
	pose_voices[id].global_position=population.bodies[id].global_position+Vector3.UP*40
	if poses[id]<float(clip.audio.get_length()): pose_voices[id].play(poses[id])

func pose_frame(id: String) -> int:
	if poses[id]<0: return -1
	var clip: Dictionary=clips[int(encounter.actors[id].pose)]
	return mini(int(poses[id]*15.0),int(clip.frames)-1)

func _present() -> void:
	for id in State.GUARDS:
		var mesh: MeshInstance3D=pose_meshes[id]
		var showing: bool=poses[id]>=0 and bool(encounter.actors[id].present)
		mesh.visible=showing
		population.meshes[id].visible=not showing
		if not showing: continue
		var clip: Dictionary=clips[int(encounter.actors[id].pose)]
		var quad: QuadMesh=mesh.mesh
		quad.size=clip.size*POSE_SCALE;quad.center_offset=Vector3(0,quad.size.y/2.0,0)
		mesh.global_position=population.bodies[id].global_position
		mesh.material_override.set_shader_parameter("frame",clip.textures[pose_frame(id)])

func targets() -> Dictionary:
	return {} if movie.phase=="playing" else population.targets()

## Narrow source bridge for the separately owned Bacatta choreography.
func request_prop4398_event20(supplied: Dictionary={}) -> void:
	var ctx: Dictionary=context() if supplied.is_empty() else supplied
	ctx.opcode8=_opcode8
	_apply(State._dispatch(encounter,src,"prop",4398,6,20,ctx))
	_sync_population();_present()

func write_local(id: int, value: int) -> bool:
	if id!=42 or value<0 or value>255: return false
	encounter.locals[str(id)]=value
	return true

func actor_alive(id: int) -> bool:
	var actor: Dictionary=encounter.actors.get(str(id),{})
	return bool(actor.get("present",false)) and int(actor.get("health",0))>0

func set_prop_present(value: bool) -> void:
	visibility.present=value
