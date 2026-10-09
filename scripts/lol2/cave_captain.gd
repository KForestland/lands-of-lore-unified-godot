extends Node3D
## Original plate89 intro and captain56 source events on the shared creature owner.
const State=preload("res://scripts/lol2/cave_captain_state.gd")
const Generic=preload("res://scripts/lol2/scripted_creature_state.gd")
const Contact=preload("res://scripts/lol2/source_control_contact.gd")
const Values=preload("res://scripts/lol2/save_value_rules.gd")
const MEDIA="res://assets/lol2/generated/cave_captain_movie/movie.json"
var host: Node3D
var population: Node3D
var src:=State.source()
var media: Dictionary
var state: Dictionary
var frames: Array=[]
var picture: TextureRect
var voice: AudioStreamPlayer
var speech: AudioStreamPlayer3D
var effects: Array=[]
var loot: Node3D
static func initial() -> Dictionary:
	return {"version":1,"source":State.initial(State.source()),"contact":Contact.initial(),"region":-1,"movie":-1.0,"movie_done":false,"pose":0.0,"speech":-1.0,"receipts":[]}
static func validate(saved: Variant) -> String:
	if not saved is Dictionary or saved.get("version")!=1:return "Invalid captain scene version."
	var error:=State.validate(saved.get("source"),State.source())
	if not error.is_empty():return error
	error=preload("res://scripts/lol2/cave_captain_loot.gd").validate(saved.get("loot"),saved.source)
	if not error.is_empty():return error
	var m=JSON.parse_string(FileAccess.get_file_as_string(MEDIA))
	if not m is Dictionary:return "Missing captain media."
	error=Contact.validate(saved.get("contact"),m)
	if not error.is_empty():return error
	if not State._integer(saved.get("region"),954,-1) or int(saved.region) not in [-1,953,954,951,924,925,922]:return "Invalid captain own region."
	for key in ["movie","pose","speech"]:
		var value=saved.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or value<(-1 if key in ["movie","speech"] else 0) or value>20:return "Invalid captain presentation clock."
	if not saved.get("movie_done") is bool or not saved.get("receipts") is Array:return "Invalid captain scene latches."
	if saved.receipts.size()>128:return "Too many captain source receipts."
	for receipt in saved.receipts:
		if not receipt is Dictionary or not receipt.get("type") is String:return "Invalid captain source receipt."
		for key in receipt:
			var value=receipt[key]
			if not key is String or not (value is String or State._integer(value,4294967295 if key=="identity" else 65535)):return "Invalid captain source receipt value."
	return ""
func setup(owner_host: Node3D, saved: Variant=null) -> String:
	host=owner_host;population=host.guard_population;process_mode=Node.PROCESS_MODE_ALWAYS
	media=JSON.parse_string(FileAccess.get_file_as_string(MEDIA))
	for row in media.frames:
		if FileAccess.get_sha256(row.file)!=str(row.sha256):return "Captain frame hash mismatch."
		frames.append(ImageTexture.create_from_image(Image.load_from_file(row.file)))
	var layer:=CanvasLayer.new();layer.layer=22;add_child(layer)
	picture=TextureRect.new();picture.mouse_filter=Control.MOUSE_FILTER_IGNORE;picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_SCALE;layer.add_child(picture)
	voice=AudioStreamPlayer.new();voice.stream=AudioStreamWAV.load_from_file(media.audio);add_child(voice)
	speech=AudioStreamPlayer3D.new();speech.stream=AudioStreamWAV.load_from_file(media.speech["1031"].path);speech.unit_size=160;speech.max_distance=1200;add_child(speech)
	population.creature_audio.queue_free()
	population.creature_audio=preload("res://scripts/lol2/cave_captain_audio.gd").new();population.add_child(population.creature_audio)
	var audio_error: String=population.creature_audio.setup(population,population.audio_contract,str(population.config.audio_manifest))
	if not audio_error.is_empty():return audio_error
	loot=preload("res://scripts/lol2/cave_captain_loot.gd").new();add_child(loot);loot.setup(self)
	return restore(saved if saved!=null else initial())
func checkpoint() -> Dictionary:return state.duplicate(true)
func restore(saved: Variant) -> String:
	var error:=validate(saved)
	if not error.is_empty():return error
	state=saved.duplicate(true);state.version=1;state.source=State.canonical(state.source,src);state.contact=Contact.canonical(state.contact)
	state.region=int(state.region);state.movie=float(state.movie);state.pose=float(state.pose);state.speech=float(state.speech)
	for receipt in state.receipts:
		for key in receipt:
			if receipt[key] is float:receipt[key]=int(receipt[key])
	voice.stop();speech.stop();sync_population();population.creature_audio.sync(0.0,true);present(true);return ""
func intro_active() -> bool:return state!=null and state.movie>=0 and not state.movie_done
func fighting() -> bool:return State.fighting(state.source) and int(state.source.captain.selector) not in [10,11,12]
func active() -> bool:
	if get_tree().paused or host==null or host.flying or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:return false
	return host.starting_magic!=null and host.starting_magic.health()>0 and not is_instance_valid(host.inventory) and not is_instance_valid(host.video_overlay)
func advance(delta: float) -> void:
	if not active() or not is_finite(delta) or delta<=0:return
	if state.speech>=0:state.speech=minf(ceilf(float(media.speech["1031"].duration)*4096)/4096,snappedf(state.speech+delta,1.0/4096))
	if intro_active():
		state.movie=minf(ceilf(maxf(float(media.duration),float(media.samples)/float(media.rate))*4096)/4096,snappedf(state.movie+delta,1.0/4096))
		if state.movie>=ceilf(maxf(float(media.duration),float(media.samples)/float(media.rate))*4096)/4096:
			state.movie_done=true;apply(State.control_animation_finished(state.source,src));sync_population()
	else:
		var p: Vector3=host.player.global_position-host.native_translation
		for e in Contact.update(state.contact,media,Vector2(p.x,p.z),p.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET,host.player.is_on_floor(),int(host.player_form),{"89":state.source.objects.control89.state}):
			apply(State.plate_entered(state.source,src,int(e.owner),int(e.value)))
		own_region()
		if int(state.source.captain.selector)==10:
			state.pose=minf(35.0/8.0,snappedf(state.pose+delta,1.0/1024))
			if state.pose>=35.0/8.0:apply(State.pose_finished(state.source,src))
		apply(State.advance(state.source,src,delta))
	loot.advance(delta)
	present()
func own_region() -> void:
	if not state.source.captain.present:return
	var p: Vector3=population.bodies["56"].global_position-population.origin()
	var selected:=-1
	for row in media.regions:
		var polygon:=PackedVector2Array()
		for v in row.polygon:polygon.append(Vector2(v[0],v[1]))
		if p.y>=float(row.floor_min)-4 and p.y<=float(row.floor_max)+4 and Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon):selected=int(row.region);break
	if selected==state.region:return
	state.region=selected
	if selected>=0:apply(State.record_event(state.source,src,10,0x9000,selected))
func after_damage(amount: int, melee: bool, effect: int) -> void:
	var mask0:=2 if melee else 1
	var mask2:=4 if melee else 1
	# Only original basic Spark/aura effects have the verified 1/1 request.
	if not melee and effect not in [20,21,22,23]:mask0=0;mask2=0
	apply(State.hit(state.source,src,mask0,mask2,amount));sync_population();present()
func sync_population() -> void:
	var c: Dictionary=state.source.captain;var b: Dictionary=population.state.actors["56"]
	if c.present and not b.present:Generic.spawn(population.state,"56")
	b.present=c.present
	if int(c.health)==0 and int(b.health)>0:Generic.damage(population.state,population.src,"56",int(b.health))
	b.health=c.health
	if fighting() and not b.woken:Generic.wake(population.state,"56")
	population.present()
func record_receipt(e: Dictionary) -> void:
	if e not in state.receipts:state.receipts.append(e.duplicate(true))
func apply(rows: Array) -> void:
	for e in rows:
		effects.append(e)
		if effects.size()>256:effects.pop_front()
		match str(e.type):
			"animation":
				if int(e.target)==120 and int(e.property)==2 and state.movie<0:state.movie=0.0;voice.play()
			"reposition":
				var p: Array=e.position;var target: Vector3=Vector3(p[0],p[1],p[2])+host.native_translation
				var floor_ray:=PhysicsRayQueryParameters3D.create(target+Vector3.UP*64,target-Vector3.UP*512,1,[host.player.get_rid()])
				var floor_hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(floor_ray)
				if not floor_hit.is_empty():target.y=floor_hit.position.y
				host.player.global_position=target+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET;host.player.velocity=Vector3.ZERO
				# Source scripted viewpoint faces the original captain placement.
				host.player.look_at(Vector3(src.captain.position[0],host.player.global_position.y,src.captain.position[2])+Vector3(host.native_translation.x,0,host.native_translation.z));host.camera.rotation=Vector3.ZERO
			"speech":
				if int(e.request)==1031:state.speech=0.0;speech.play()
			"selector":state.pose=0.0
			"spawn","remove":sync_population()
			"player_property":
				if int(e.property)==10:award_magic(int(e.value)*10)
				else:record_receipt(e)
			"grant_player":
				if host.has_method("save_feedback"):host.save_feedback("Received "+str(e.item)+".")
			_:
				record_receipt(e)
func present(restoring: bool=false) -> void:
	if loot!=null:loot.present()
	if picture==null:return
	picture.visible=intro_active()
	if intro_active():
		picture.texture=frames[mini(156,int(state.movie*15))]
		var p: Vector3=Vector3(media.position[0],media.position[1],media.position[2])+host.native_translation
		var cam: Camera3D=host.camera
		var right: Vector3=cam.global_basis.x*float(media.dimensions[0])/2
		var top: Vector2=cam.unproject_position(p-right+Vector3.UP*float(media.dimensions[1]))
		var bottom: Vector2=cam.unproject_position(p+right)
		picture.position=Vector2(minf(top.x,bottom.x),minf(top.y,bottom.y));picture.size=Vector2(absf(bottom.x-top.x),absf(bottom.y-top.y))
		if restoring and state.movie<float(media.samples)/float(media.rate):voice.play(state.movie)
	else:voice.stop()
	voice.stream_paused=not active()
	speech.global_position=population.bodies["56"].global_position
	if state.speech<0 or state.speech>=float(media.speech["1031"].duration):speech.stop()
	elif restoring:speech.play(state.speech)
	speech.stream_paused=not active()
	if population==null or not state.source.captain.present:return
	var selector:=int(state.source.captain.selector)
	if selector not in [10,11,12]:return
	population.library.present(population.materials["56"],0,selector,mini(34,int(state.pose*8)) if selector==10 else 0)
	for pair in host.occluder_pairs+host.light_pairs:
		if pair[0]==population.meshes["56"]:pair[1].material_override.set_shader_parameter("indices",population.library.last_texture)
func aimed() -> bool:
	if not active() or intro_active() or int(state.source.captain.state) not in [2,3]:return false
	var point: Vector3=population.bodies["56"].global_position+Vector3.UP*24
	var from: Vector3=host.camera.global_position;var offset:=point-from
	if offset.length()>110 or offset.length()<0.01 or (-host.camera.global_basis.z).dot(offset.normalized())<0.96:return false
	var ray:=PhysicsRayQueryParameters3D.create(from,point,1,[host.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func award_magic(amount: int) -> void:
	var saved: Dictionary=host.starting_magic.magic_state()
	var maxima: Array=[];maxima.resize(31);maxima.fill(159)
	var rng:=preload("res://scripts/lol2/hive_rune_transaction.gd").draws(int(saved.get("spark_reward_seed",324508639)),maxima)
	var result:=preload("res://scripts/lol2/hive_magic_reward.gd").award_checkpoint(saved,amount,rng.values)
	if result.has("error"):push_error(result.error);return
	result.checkpoint.spark_reward_seed=int(rng.seeds[result.draws_used]);host.starting_magic.commit(result.checkpoint)
func use() -> bool:
	if loot!=null and loot.collect():return true
	if not aimed():return false
	var rows:=State.use(state.source,src)
	if rows.is_empty():return false
	apply(rows);present();return true
func _input(event: InputEvent) -> void:
	if not intro_active() or Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:return
	if event is InputEventMouseMotion or (event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT) or (event is InputEventKey and event.keycode==KEY_E):get_viewport().set_input_as_handled()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and use():get_viewport().set_input_as_handled()
func _physics_process(delta: float) -> void:advance(delta)
func _process(_delta: float) -> void:present()
