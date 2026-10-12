extends Node3D
## Water-gate, oil rock, spreading fire and original hut movie; saved source progression.
const State = preload("res://scripts/lol2/jungle_chief_hut_state.gd")
const ROOT := "res://assets/lol2/generated/jungle_chief_hut/"
const AUDIO := "res://assets/lol2/generated/jungle_chief_hut_audio/"
var host: Node3D
var src: Dictionary
var state: Dictionary
var rock: StaticBody3D
var sprites: Dictionary = {}
var floors: Dictionary = {}
var textures: Dictionary = {}
var surface_materials: Dictionary = {}
var overlay: CanvasLayer
var picture: TextureRect
var movie_voice: AudioStreamPlayer
var sound: AudioStreamPlayer3D
var effects_log: Array = []
var movie_frame := -1
var last_movie_time := -1.0
var visual_time := 0.0
static func assets_ready() -> bool: return FileAccess.file_exists(State.SOURCE)
static func validate(packet: Variant) -> String: return State.validate(packet)
func initial() -> Dictionary: return State.initial()
func checkpoint() -> Dictionary: return state.duplicate(true)
func origin() -> Vector3:
	var value = host.get("native_translation")
	return value if value is Vector3 else Vector3.ZERO
func setup(owner_host: Node3D, saved: Variant=null) -> String:
	host=owner_host;src=State.source()
	for obj in src.objects:
		if int(obj.id)==561: continue
		var sprite:=MeshInstance3D.new();sprite.name="PuzzleProp%d"%int(obj.id)
		var material:=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		sprite.material_override=material;add_child(sprite)
		sprites[str(int(obj.id))]=sprite
	for face in src.floor_faces:
		var key:=str(int(face.region))
		var body:=StaticBody3D.new();body.name="PuzzleFloor"+key;body.collision_layer=1;body.collision_mask=0
		body.add_child(MeshInstance3D.new());body.add_child(CollisionShape3D.new());add_child(body)
		floors[key]={"body":body,"face":face,"height":INF,"preset":-2}
	rock=StaticBody3D.new();rock.name="OilRock";rock.collision_layer=1;rock.collision_mask=0
	rock.set_meta("chief_hut_rock",self)
	var shape:=BoxShape3D.new();shape.size=Vector3(96,53,24)
	var collision:=CollisionShape3D.new();collision.shape=shape;collision.position.y=26.5
	rock.add_child(collision);add_child(rock);rock.position=Vector3(-3013,-40,-5116)+origin()
	overlay=CanvasLayer.new();overlay.layer=45;add_child(overlay)
	var background:=ColorRect.new();background.color=Color.BLACK;background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(background)
	picture=TextureRect.new();picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE;picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST;picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);overlay.add_child(picture)
	movie_voice=AudioStreamPlayer.new();add_child(movie_voice)
	if str(src.movie.audio)!="": movie_voice.stream=AudioStreamWAV.load_from_file(ROOT+str(src.movie.audio))
	sound=AudioStreamPlayer3D.new();add_child(sound);sound.position=rock.position
	return restore(saved if saved!=null else initial())
func restore(packet: Variant) -> String:
	var error:=validate(packet)
	if not error.is_empty(): return error
	state=State.canonical(packet);movie_voice.stop();movie_frame=-1;last_movie_time=-1.0
	present();return ""
func live() -> bool:
	# The movie owner keeps its own clock during the locked movie; every other world consumer stops (world_active()).
	return is_instance_valid(host) and is_instance_valid(host.starting_magic) and host.starting_magic.movie_world_active()
func input_locked() -> bool: return not state.is_empty() and state.phase=="movie"
func movement_locked() -> bool: return input_locked()
func apply(effects: Array) -> void:
	for e in effects:
		effects_log.append(e)
		match str(e.type):
			"kelsrick":
				if is_instance_valid(host.kelsrick): host.kelsrick.run_external(int(e.group),[str(e.raw)])
			"gate":
				if is_instance_valid(host.inner_gate): host.inner_gate.external(str(e.raw))
				var b: PackedByteArray=str(e.raw).hex_decode()
				if b.decode_u16(2) in [78,79] and is_instance_valid(host.village_alarm): host.village_alarm.request_movable(b.decode_u16(2),b.decode_u16(4))
			"reposition":
				host.player.global_position=Vector3(e.position[0],e.position[1],e.position[2])+origin()+Vector3.UP*preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
				host.player.velocity=Vector3.ZERO
			"sound": play_sound(int(e.request))
			"receipt":
				if str(e.raw)=="08106e0001000000" and is_instance_valid(host.drunk): host.drunk.stop_external()
	if effects_log.size()>100: effects_log=effects_log.slice(-100)
func play_sound(request: int) -> void:
	if not FileAccess.file_exists(AUDIO+"audio.json"): return
	var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(AUDIO+"audio.json"))
	var clip: Dictionary=manifest.clips.get(str(request),{})
	if not clip.is_empty(): sound.stream=AudioStreamWAV.load_from_file(str(clip.path));sound.play()
func aimed() -> bool:
	if not live() or input_locked(): return false
	var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,host.camera.global_position-host.camera.global_basis.z*140,1,[host.player.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	return not hit.is_empty() and hit.collider==rock
func strike() -> bool:
	if not aimed() or (host.player_form==0 and str(host.equipped_item)==""): return false
	var effects:=State.strike(state,src)
	apply(effects);present();return not effects.is_empty()
func receive_spark() -> bool:
	if not live() or input_locked(): return false
	var effects:=State.ignite(state,src)
	apply(effects);present();return not effects.is_empty()
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and strike(): get_viewport().set_input_as_handled()
func pool_visible() -> bool:
	var target:=Vector3(-3073,-23,-5033)+origin()
	if host.camera.global_position.distance_to(target)>700 or not host.camera.is_position_in_frustum(target): return false
	var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,target,1,[host.player.get_rid(),rock.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	return hit.is_empty() or hit.position.distance_to(target)<25
func _physics_process(delta: float) -> void: advance(delta)
func advance(delta: float) -> void:
	if state.is_empty(): return
	movie_voice.stream_paused=not live();sound.stream_paused=not live()
	if not live() or not is_finite(delta) or delta<=0: return
	visual_time+=delta
	if not input_locked():
		var now: Array=[]
		var pos: Vector3=host.player.global_position-origin()
		var foot: float=pos.y-preload("res://scripts/lol2/player_form_body.gd").FOOT_OFFSET
		for region in src.regions:
			var polygon:=PackedVector2Array()
			for p in region.polygon: polygon.append(Vector2(p[0],p[1]))
			if foot<float(region.floor_min)-4 or foot>float(region.floor_max)+6 or not Geometry2D.is_point_in_polygon(Vector2(pos.x,pos.z),polygon): continue
			var id:=int(region.id);now.append(id)
			if id in state.inside: continue
			if id==2443: apply(State.village_entry(state,src,int(host.village_gate.state().shared29)))
			elif is_instance_valid(host.kelsrick): apply(State.raise_gate(state,src,host.kelsrick.local_value(8)))
		state.inside=now
		if pool_visible(): apply(State.observe_pool(state,src))
	apply(State.advance(state,src,delta));present()
func texture(path: String) -> Texture2D:
	if not textures.has(path): textures[path]=ImageTexture.create_from_image(Image.load_from_file(ROOT+path))
	return textures[path]
func present() -> void:
	for obj in src.objects:
		var id:=int(obj.id)
		if id==561: continue
		var sprite: MeshInstance3D=sprites[str(id)]
		var index:=1 if (id==1486 and state.locals["10"]==1) or (id==427 and state.locals["9"]==1) else 0
		var selector: Dictionary=obj.selectors[index]
		var mesh:=QuadMesh.new();mesh.size=Vector2(float(selector.right)-float(selector.left),float(selector.top)-float(selector.bottom))
		mesh.center_offset=Vector3((float(selector.left)+float(selector.right))/2.0,(float(selector.top)+float(selector.bottom))/2.0,0)
		sprite.mesh=mesh;sprite.position=Vector3(obj.position[0],obj.position[1],obj.position[2])+origin()
		var frame: int=int(visual_time*10)%selector.frames.size()
		if id==427: frame=selector.frames.size()-1 if index==1 else 0
		if id==1486: frame=mini(selector.frames.size()-1,int(float(state.rock_elapsed)/State.ROCK_TIME*selector.frames.size())) if index==1 else 0
		sprite.material_override.albedo_texture=texture(str(selector.frames[frame]))
		if id in State.ORDER:
			sprite.visible=state.fire_index>=State.ORDER.find(id) or state.phase in ["movie","done"]
			if state.phase=="extinguished" and state.locals["11"]==1: sprite.visible=false
	for k in floors: present_floor(k)
	overlay.visible=state.phase=="movie"
	if overlay.visible:
		var frame:=mini(59,int(float(state.movie_elapsed)*15))
		if frame!=movie_frame: picture.texture=texture(str(src.movie.frames[frame]));movie_frame=frame
		if movie_voice.stream!=null and (last_movie_time<0 or float(state.movie_elapsed)<last_movie_time): movie_voice.play(float(state.movie_elapsed))
		last_movie_time=float(state.movie_elapsed)
	else: movie_voice.stop();last_movie_time=-1.0
func present_floor(k: String) -> void:
	var row: Dictionary=floors[k];var face: Dictionary=row.face
	var height: float=state.floor_heights.get(k,float(face.points[0][1]))
	var preset:=int(state.floor_presets.get(k,-1))
	if row.height==height and row.preset==preset: return
	var material_id:=str(face.material) if preset<0 else str(int(src.presets[str(preset)].resource))
	if not surface_materials.has(material_id):
		var material:=StandardMaterial3D.new();material.albedo_texture=texture(str(src.materials[material_id][0]))
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.cull_mode=BaseMaterial3D.CULL_DISABLED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		surface_materials[material_id]=material
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(surface_materials[material_id])
	var points:=PackedVector3Array();var uv: Array=face.uv if preset<0 else face.preset_uv[str(preset)]
	for i in [0,1,2,0,2,3]:
		var p:=Vector3(face.points[i][0],height,face.points[i][2]);points.append(p)
		surface.set_uv(Vector2(uv[i][0],uv[i][1]));surface.add_vertex(p)
	row.body.get_child(0).mesh=surface.commit()
	var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(points)
	row.body.get_child(1).shape=shape;row.body.position=origin();row.height=height;row.preset=preset
