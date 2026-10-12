extends Node3D
## Original explosion/fire/audio with modern projected-VQA presentation. Source
## command order, movie endpoint, reward, and zero-child helpers are persistent.
const BASE="res://assets/lol2/generated/cave_scenic_guard_movie/"
const Values=preload("res://scripts/lol2/save_value_rules.gd")
var guard: Node3D
var data: Dictionary
var frames: Array=[]
var flames: Array=[]
var fire_meshes: Dictionary={}
var original_props: Dictionary={}
var voices: Dictionary={}
var streams: Dictionary={}
var overlay: TextureRect
var target: StaticBody3D
var helpers: Dictionary={}
static func initial() -> Dictionary:
	return {"durability":3,"started":false,"movie_time":-1.0,"movie_loaded":false,"movie_done":false,"fire_time":0.0,"selectors":{},"flags17":[],"health":{},"events":{},"sounds":{},"reward_issued":false,"local11":false,"burst":false}
static func validate(s: Variant) -> String:
	if not s is Dictionary or not Values.integer(s.get("durability"),3):return "Invalid scenic effect durability."
	for key in ["started","movie_loaded","movie_done","reward_issued","local11","burst"]:
		if not s.get(key) is bool:return "Invalid scenic effect latch."
	for key in ["movie_time","fire_time"]:
		var v=s.get(key)
		if not (v is int or v is float) or not is_finite(float(v)) or v<(-1 if key=="movie_time" else 0) or v>(6 if key=="movie_time" else 1):return "Invalid scenic effect clock."
	if not s.get("flags17") is Array:return "Invalid scenic flags."
	for id in s.flags17:
		if not Values.integer(id,1400):return "Invalid scenic flag owner."
	for key in ["selectors","health","events","sounds"]:
		if not s.get(key) is Dictionary:return "Invalid scenic effect bank."
		for id in s[key]:
			if not id is String or not id.is_valid_int():return "Invalid scenic effect identity."
			var v=s[key][id]
			if key=="sounds":
				if id not in ["411","426"] or not (v is int or v is float) or not is_finite(float(v)) or v<0 or v>5:return "Invalid scenic voice clock."
			elif not Values.integer(v,255):return "Invalid scenic effect value."
	return ""
static func canonical(s: Dictionary) -> Dictionary:
	var result:=s.duplicate(true);result.durability=int(result.durability)
	result.movie_time=float(result.movie_time);result.fire_time=float(result.fire_time)
	result.flags17=result.flags17.map(func(n):return int(n))
	for key in ["selectors","health","events"]:
		for id in result[key]:result[key][id]=int(result[key][id])
	for id in result.sounds:result.sounds[id]=float(result.sounds[id])
	return result
func packet() -> Dictionary:
	if not guard.state.has("effects"):guard.state.effects=initial()
	return guard.state.effects
func setup(owner_guard: Node3D) -> String:
	guard=owner_guard;process_mode=Node.PROCESS_MODE_ALWAYS
	data=JSON.parse_string(FileAccess.get_file_as_string(BASE+"movie.json"))
	if not data is Dictionary:return "Missing scenic movie assets."
	for row in data.frames:
		if FileAccess.get_sha256(BASE+row.file)!=row.sha256:return "Scenic movie frame changed."
		frames.append(ImageTexture.create_from_image(Image.load_from_file(BASE+row.file)))
	for row in data.fire_frames:
		if FileAccess.get_sha256(BASE+row.file)!=row.sha256:return "Scenic flame frame changed."
		flames.append(ImageTexture.create_from_image(Image.load_from_file(BASE+row.file)))
	for prop in guard.host.props_root.get_children():
		var id:=str(int(prop.get_meta("original_record",-1)))
		original_props[id]=prop
	for row in data.fires:
		var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new()
		quad.size=Vector2(row.right-row.left,row.top-row.bottom);quad.center_offset=Vector3((row.left+row.right)/2,(row.bottom+row.top)/2,0);mesh.mesh=quad;mesh.layers=2
		mesh.position=Vector3(row.position[0],row.position[1],row.position[2])+guard.host.native_translation-guard.global_position
		guard.library.bind(mesh,true);add_child(mesh);guard.host._copy_occluders(mesh);fire_meshes[str(int(row.prop))]=mesh
	for id in data.sounds:
		var row: Dictionary=data.sounds[id]
		if FileAccess.get_sha256(row.path)!=row.wav_sha256:return "Scenic sound changed."
		streams[id]=AudioStreamWAV.load_from_file(row.path)
		var voice:=AudioStreamPlayer3D.new();voice.stream=streams[id];voice.unit_size=96;voice.max_distance=700;add_child(voice);voices[id]=voice
		voice.global_position=Vector3(-277,-270,-15065)+guard.host.native_translation
	var layer:=CanvasLayer.new();layer.layer=20;add_child(layer);overlay=TextureRect.new();overlay.mouse_filter=Control.MOUSE_FILTER_IGNORE;overlay.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;overlay.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;layer.add_child(overlay)
	target=StaticBody3D.new();target.collision_layer=2;target.collision_mask=0
	target.set_meta("population_actor","prop574");target.set_meta("population_owner",guard)
	var shape:=CollisionShape3D.new();var box:=BoxShape3D.new();box.size=Vector3(255,159,8);shape.shape=box;shape.position.y=79.5;target.add_child(shape);add_child(target)
	target.global_position=Vector3(-238,-270,-14947)+guard.host.native_translation
	guard.host.player.add_collision_exception_with(target)
	# Native template54 has no children: activation creates no visible geometry.
	for row in data.movables:
		var helper:=Node3D.new();add_child(helper);helper.global_position=Vector3(row.x,row.height,-row.y)+guard.host.native_translation;helpers[str(int(row.index))]=helper
	return ""
func award_magic() -> bool:
	var s:=packet()
	if s.reward_issued:return true
	var magic=guard.host.starting_magic
	if magic==null:return false
	var saved: Dictionary=magic.magic_state()
	var thresholds: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://assets/lol2/generated/hive_reward_thresholds.json"))
	var award:=50 if s.local11 else 0 if int(saved.player.level)>=30 else maxi(0,int(thresholds.thresholds[int(saved.player.level)])-int(saved.player.experience))
	var maxima: Array=[];maxima.resize(31);maxima.fill(159)
	var rng:=preload("res://scripts/lol2/hive_rune_transaction.gd").draws(int(saved.get("spark_reward_seed",324508639)),maxima)
	var result:=preload("res://scripts/lol2/hive_magic_reward.gd").award_checkpoint(saved,award,rng.values)
	if result.has("error"):return false
	result.checkpoint.spark_reward_seed=int(rng.seeds[result.draws_used]);magic.commit(result.checkpoint)
	s.local11=true;s.reward_issued=true;return true
func apply(c: Dictionary) -> bool:
	var s:=packet();var id:=str(int(c.target))
	if c.op==15 and c.argument==101:
		# The special burst shares the original explosion presentation adapter.
		s.burst=true;return true
	if c.op==9 and c.kind==3:
		if c.argument==17:
			if int(c.target) not in s.flags17:s.flags17.append(int(c.target))
			return true
		if c.argument==19:s.health[id]=int(c.value);return true
		if c.argument==16:return true # Stop this owner's sound; no initial voice is playing.
		if c.argument==21 and c.target==1031:return award_magic()
	if c.op==5 and c.kind==3 and c.argument==2 and fire_meshes.has(id):s.selectors[id]=2;return true
	if c.op==6 and ((c.kind==3 and int(c.target) in [574,581]) or (c.kind==2 and c.target==55)):
		s.events[id]=int(c.argument);return true
	if c.op==8 and c.kind==3 and c.target==574:
		if c.argument==0:s.movie_loaded=true;return true
		if c.argument==2 and s.movie_loaded:
			if s.movie_time<0:s.movie_time=0.0
			return true
		if c.argument==1:s.movie_loaded=false;return true
	if c.op==20 and c.kind==3 and c.target==581:
		var request:=str(int(c.argument)+256*int(c.value))
		if not streams.has(request):return false
		s.sounds[request]=0.0;voices[request].play();return true
	if c.op==9 and c.kind==4 and c.argument==3 and helpers.has(id):helpers[id].set_meta("source_present",true);return true
	return false
func receive_spark() -> bool:
	var s:=packet()
	if s.started or not guard.state.prop_present or guard.state.prop_state!=0:return false
	# All765 native Spark cases reduce source3HP to0 or1. Use the minimum2 loss;
	# either source result admits the exact before>2/after<=2 threshold.
	var before:=int(s.durability);s.durability=maxi(0,before-2)
	if before<=2 or int(s.durability)>2:return false
	s.started=true
	return guard.supply_event("supplied_hit")
func advance(delta: float) -> void:
	var s:=packet()
	if not is_finite(delta) or delta<=0:return
	s.fire_time=fmod(snappedf(float(s.fire_time)+delta,1.0/1024),1.0)
	for id in s.sounds:s.sounds[id]=minf(5,snappedf(float(s.sounds[id])+delta,1.0/1024))
	if s.movie_time>=0 and not s.movie_done:
		s.movie_time=minf(6,snappedf(float(s.movie_time)+delta,1.0/1024))
		if s.movie_time>=6:s.movie_done=true;guard.supply_event("prop_event0")
	if guard.state.selector==3 and guard.state.actor_state==1 and guard.state.elapsed>=guard.State.duration(guard.source,3):guard.supply_event("actor_event3")
	present()
func present(restoring: bool=false) -> void:
	if not is_instance_valid(overlay):return
	var s:=packet();target.collision_layer=2 if guard.state.prop_present and not s.started else 0
	var images: Dictionary={}
	for id in fire_meshes:
		var mesh: MeshInstance3D=fire_meshes[id];mesh.visible=int(s.selectors.get(id,0))==2
		if original_props.has(id):original_props[id].visible=not mesh.visible
		var texture: Texture2D=flames[mini(int(float(s.fire_time)*flames.size()),flames.size()-1)]
		mesh.material_override.set_shader_parameter("indices",texture);images[mesh]=texture
	for pair in guard.host.occluder_pairs+guard.host.light_pairs:
		if not images.has(pair[0]):continue
		pair[1].global_transform=pair[0].global_transform;pair[1].visible=pair[0].is_visible_in_tree();pair[1].material_override.set_shader_parameter("indices",images[pair[0]])
	for id in helpers:helpers[id].set_meta("source_present",bool(guard.state.movables[id]))
	for id in voices:
		var voice: AudioStreamPlayer3D=voices[id];var seconds:=float(s.sounds.get(id,5))
		if seconds>=float(data.sounds[id].samples)/float(data.sounds[id].rate):voice.stop()
		elif restoring or not voice.playing:voice.play(seconds)
		voice.stream_paused=get_tree().paused or not guard.scene_active()
	var p: Vector3=target.global_position;var camera: Camera3D=guard.host.camera
	overlay.visible=s.movie_loaded and s.movie_time>=0 and s.movie_time<6 and not camera.is_position_behind(p+Vector3.UP*79.5)
	if overlay.visible:
		var query:=PhysicsRayQueryParameters3D.create(camera.global_position,p+Vector3.UP*79.5,1)
		var obstruction: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		if not obstruction.is_empty():overlay.visible=false
	if overlay.visible:
		var right: Vector3=camera.global_basis.x*127.5
		var top: Vector2=camera.unproject_position(p-right+Vector3.UP*159)
		var bottom: Vector2=camera.unproject_position(p+right)
		overlay.position=Vector2(minf(top.x,bottom.x),minf(top.y,bottom.y));overlay.size=Vector2(absf(bottom.x-top.x),absf(bottom.y-top.y));overlay.texture=frames[mini(89,int(s.movie_time*15))]
func _process(_delta: float) -> void:
	if guard!=null:present()
func _exit_tree() -> void:
	for voice in voices.values():voice.stop()
