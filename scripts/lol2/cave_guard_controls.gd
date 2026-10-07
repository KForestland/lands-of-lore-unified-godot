extends Node3D
## Sole guard-population step while active; original support movies and guard39 path0.
const State=preload("res://scripts/lol2/cave_guard_controls_state.gd")
const Contact=preload("res://scripts/lol2/source_control_contact.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Path=preload("res://scripts/lol2/hive_path_control.gd")
const Body=preload("res://scripts/lol2/player_form_body.gd")
var host: Node3D
var population: Node3D
var src:=State.source()
var media:=State.media()
var state: Dictionary={}
var textures: Dictionary={}
var pictures: Dictionary={}
var voices: Dictionary={}
var last_health39:=150
var last_player_properties: Dictionary={}
func setup(owner_host: Node3D,saved: Variant=null) -> String:
	host=owner_host;population=host.guard_population;process_mode=Node.PROCESS_MODE_ALWAYS
	if population==null:return "Guard controls require the cave guard population."
	var layer:=CanvasLayer.new();layer.layer=22;add_child(layer)
	for resource in media.clips:
		var clip: Dictionary=media.clips[resource];var frames: Array=[]
		for row in clip.frames:
			if FileAccess.get_sha256(row.file)!=str(row.sha256):return "Guard cutscene frame hash differs."
			frames.append(ImageTexture.create_from_image(Image.load_from_file(row.file)))
		textures[int(resource)]=frames
	for owner in ["prop533","actor52","control119"]:
		var picture:=TextureRect.new();picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_SCALE;layer.add_child(picture);pictures[owner]=picture
		var voice:=AudioStreamPlayer3D.new();voice.unit_size=160;voice.max_distance=1200;add_child(voice);voices[owner]=voice
	population.creature_audio.queue_free();population.creature_audio=preload("res://scripts/lol2/cave_guard_controls_audio.gd").new();population.creature_audio.controls=self;population.add_child(population.creature_audio)
	var error: String=population.creature_audio.setup(population,population.audio_contract,str(population.config.audio_manifest))
	if not error.is_empty():return error
	population.set_physics_process(false)
	return restore(saved if saved!=null else State.initial(),saved==null)
## Region-owned disarms written by the population since the last controls step are part of the saved bank
## (same max-merge as advance), so a save between the two steps cannot lose them.
func checkpoint() -> Dictionary:
	if not state.is_empty():
		for id in state.controls:state.controls[id]=maxi(int(state.controls[id]),int(population.state.controls.get(id,0)))
	return state.duplicate(true)
func restore(saved: Variant,legacy: bool=false) -> String:
	var error:=State.validate(saved,src,media)
	if not error.is_empty():return error
	state=State.canonical(saved)
	if legacy:
		for id in state.controls:state.controls[id]=int(population.state.controls.get(id,0))
		state.actor39.present=population.state.actors["39"].present
	for id in state.controls:population.state.controls[id]=int(state.controls[id])
	last_health39=int(population.state.actors["39"].health)
	for voice in voices.values():voice.stop()
	population.creature_audio.sync(0.0,true);present(true);return ""
func input_locked() -> bool:return not state.is_empty() and State.input_locked(state)
func active() -> bool:
	if state.is_empty() or not host.walkthrough_ready or host.chamber_arrival_state!="not_started" or get_tree().paused or host.flying or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:return false
	if host.starting_magic==null or host.starting_magic.health()<=0 or is_instance_valid(host.inventory) or is_instance_valid(host.video_overlay):return false
	if host.captain!=null and host.captain.intro_active():return false
	return true
func walking39() -> bool:
	return not state.is_empty() and state.branch109=="beast" and state.actor39.present and int(state.actor39.goal)==7 and (int(state.actor39.b5)&13)==0 and population.state.actors["39"].health>0
func advance(delta: float) -> void:
	if not is_finite(delta) or delta<=0:return
	if not active():population.creature_audio.pause();present();return
	# Region-owned disarms and legacy owner states share the existing population bank.
	for id in state.controls:state.controls[id]=maxi(int(state.controls[id]),int(population.state.controls[id]))
	if state.branch109=="none":state.actor39.present=population.state.actors["39"].present
	var p: Vector3=host.player.global_position-host.native_translation
	for e in Contact.update(state.contact,src,Vector2(p.x,p.z),p.y-Body.FOOT_OFFSET,host.player.is_on_floor(),int(host.player_form),state.controls):apply(State.plate(state,src,int(e.owner),int(e.value)))
	for id in state.controls:population.state.controls[id]=int(state.controls[id])
	var health39:=int(population.state.actors["39"].health)
	if state.branch109=="beast" and state.actor39.present and health39<last_health39:apply(State.hit39(state,src))
	last_health39=health39
	var held: Dictionary={}
	for id in ["39","52"]:
		if (id=="39" and walking39()) or (id=="52" and input_locked()):
			var actor: Dictionary=population.state.actors[id];held[id]=[actor.woken,actor.rise];actor.woken=false;actor.rise=-1.0
			population.state.live[id].merge({"mode":0,"elapsed":0.0,"hit":false,"hits":0},true);population.state.live[id].erase("cooldown")
	population.advance(delta)
	for id in held:population.state.actors[id].woken=held[id][0];population.state.actors[id].rise=held[id][1]
	apply(State.advance(state,src,media,delta))
	if walking39():walk39(delta)
	update_region39()
	present()
func hide39() -> void:
	if state.hidden39.is_empty() or state.actor39.removed:state.hidden39={"actor":population.state.actors["39"].duplicate(true),"live":population.state.live["39"].duplicate(true)}
	var fresh:=Generic.initial(population.src);population.state.actors["39"]=fresh.actors["39"];population.state.live["39"]=fresh.live["39"]
	population.present()
func show39() -> void:
	if not state.hidden39.is_empty():
		population.state.actors["39"]=state.hidden39.actor.duplicate(true);population.state.live["39"]=state.hidden39.live.duplicate(true)
	population.state.actors["39"].present=true
	var p: Array=population.state.actors["39"].position;population.bodies["39"].position=Vector3(p[0],p[1],p[2])+population.origin()
	if (int(state.actor39.b5)&12)!=0:Generic.wake(population.state,"39")
	last_health39=int(population.state.actors["39"].health);population.present()
func apply(effects: Array) -> void:
	for e in effects:
		match str(e.type):
			"presence":
				if e.present:show39()
				else:hide39()
			"pending":
				if int(e.actor)==52 or state.actor39.present:Generic.wake(population.state,str(int(e.actor)))
			"reposition":
				var p: Array=e.position;var target: Vector3=Vector3(p[0],p[1],p[2])+host.native_translation
				var ray:=PhysicsRayQueryParameters3D.create(target+Vector3.UP*64,target-Vector3.UP*128,1,[host.player.get_rid()]);var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(ray)
				if not hit.is_empty():target.y=hit.position.y
				host.player.global_position=target+Vector3.UP*Body.FOOT_OFFSET;host.player.velocity=Vector3.ZERO
			"player_property":last_player_properties[str(int(e.property))]=int(e.value)
func walk39(delta: float) -> void:
	var actor: CharacterBody3D=population.bodies["39"];var p: Vector3=actor.global_position-population.origin()
	var index:=int(Path.select_marker(src.path,int(state.actor39.path_index)).marker)-int(src.path.first)
	var target: Array=src.path.points[index].position;var difference:=Vector2(target[0]-p.x,target[1]-p.z)
	if difference.length()<8:
		state.actor39.path_index=int(Path.advance_index(src.path,int(state.actor39.path_index),0).index)
		index=absi(int(state.actor39.path_index));target=src.path.points[index].position;difference=Vector2(target[0]-p.x,target[1]-p.z)
	var direction:=difference.normalized();actor.velocity=Vector3(direction.x*48,0 if actor.is_on_floor() else actor.velocity.y-128*delta,direction.y*48)
	actor.move_and_slide();p=actor.global_position-population.origin()
	population.state.actors["39"].position=[p.x,p.y,p.z]
	population.state.live["39"].heading=population.Live.heading_units(Vector2(direction.x,-direction.y))
	state.walk_clock=fmod(snappedf(float(state.walk_clock)+delta,1.0/1024),1.75)
func update_region39() -> void:
	if state.branch109=="none" or not state.actor39.present:return
	var p: Vector3=population.bodies["39"].global_position-population.origin()
	var row: Dictionary=src.exit_region;var polygon:=PackedVector2Array()
	for v in row.polygon:polygon.append(Vector2(v[0],v[1]))
	var region:=746 if p.y>=row.floor_min-4 and p.y<=row.floor_max+4 and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon) else -1
	apply(State.entered39(state,src,region))
func present(restoring: bool=false) -> void:
	if state.is_empty():return
	for owner in pictures:
		var clip: Dictionary=state.clips[owner];var row: Dictionary=media.clips[str(int(clip.resource))];var picture: TextureRect=pictures[owner];var voice: AudioStreamPlayer3D=voices[owner]
		var position: Array=src.placements[owner].position if owner!="actor52" else population.state.actors["52"].position
		var p: Vector3=Vector3(position[0],position[1],position[2])+host.native_translation
		var size: Vector2
		if owner=="control119":size=Vector2(src.control_template.dimensions[0],src.control_template.dimensions[2])
		elif owner=="prop533":size=Vector2(row.width*130.0/400.0,row.height*80.0/248.0)
		else:size=Vector2(row.width,row.height)*0.25
		picture.visible=clip.playing and not host.camera.is_position_behind(p+Vector3.UP*size.y/2)
		if picture.visible:
			var right: Vector3=host.camera.global_basis.x*size.x/2
			var top: Vector2=host.camera.unproject_position(p-right+Vector3.UP*size.y);var bottom: Vector2=host.camera.unproject_position(p+right)
			picture.position=Vector2(minf(top.x,bottom.x),minf(top.y,bottom.y));picture.size=Vector2(absf(bottom.x-top.x),absf(bottom.y-top.y));picture.texture=textures[int(clip.resource)][mini(row.frames.size()-1,int(clip.elapsed*15))]
		voice.global_position=p
		if not clip.playing or clip.elapsed>=float(row.samples)/float(row.rate):voice.stop()
		else:
			if voice.get_meta("resource",-1)!=int(clip.resource):voice.stream=AudioStreamWAV.load_from_file(row.audio);voice.set_meta("resource",int(clip.resource))
			if active() and (restoring or not voice.playing):voice.play(float(clip.elapsed))
		voice.stream_paused=not active()
	# The actor52 movie replaces its indexed body for the whole two-clip sequence.
	var show52: bool=population.state.actors["52"].present and not input_locked()
	population.meshes["52"].visible=show52;population.bodies["52"].collision_layer=2 if show52 and population.state.actors["52"].health>0 else 0
	var updates: Dictionary={}
	if walking39():
		population.library.present(population.materials["39"],1,1,int(state.walk_clock*8)%14,population._view("39",population.library.view_count(1,1)))
		updates[population.meshes["39"]]=population.library.last_texture
	for pair in host.occluder_pairs+host.light_pairs:
		if pair[0]==population.meshes["52"]:pair[1].visible=show52
		if updates.has(pair[0]):pair[1].global_transform=pair[0].global_transform;pair[1].material_override.set_shader_parameter("indices",updates[pair[0]])
func _input(event: InputEvent) -> void:
	if not input_locked() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:return
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.keycode==KEY_E):get_viewport().set_input_as_handled()
func _physics_process(delta: float) -> void:advance(delta)
func _process(_delta: float) -> void:present()
