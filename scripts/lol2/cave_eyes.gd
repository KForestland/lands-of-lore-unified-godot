extends Node3D
## Original eyes24: E interaction, source path, sound232, saved timed removal.
## Movement/aim reach/ground following and event3 timing are modern adapters.
const State=preload("res://scripts/lol2/cave_eyes_state.gd")
const Library=preload("res://scripts/lol2/creature_sprite_library.gd")
var src:=State.source()
var state:=State.initial(src)
var host: Node3D
var library:=Library.new()
var mesh: MeshInstance3D
var material: ShaderMaterial
var audio: AudioStreamPlayer3D
var playing:=false
func setup(owner_host: Node3D, saved: Variant=null) -> String:
	host=owner_host
	var error:=library.load_manifest("res://assets/lol2/generated/cave_eyes/")
	if not error.is_empty(): return error
	mesh=MeshInstance3D.new();var quad:=QuadMesh.new()
	quad.size=Vector2(123,78)*0.5;quad.center_offset.y=19.5;mesh.mesh=quad;mesh.layers=2
	material=library.bind(mesh,true);add_child(mesh)
	host._copy_occluders(mesh)
	audio=AudioStreamPlayer3D.new()
	audio.stream=AudioStreamWAV.load_from_file("res://assets/lol2/generated/cave_eyes_audio/232.wav")
	audio.unit_size=160.0;audio.max_distance=1200.0;add_child(audio)
	return restore(saved if saved!=null else State.initial(src))
func active() -> bool:
	return host!=null and host.starting_magic!=null and host.starting_magic.world_active()
func checkpoint() -> Dictionary: return State.quantized(state)
func restore(saved: Variant) -> String:
	var error:=State.validate(saved,src)
	if not error.is_empty(): return error
	state=State.canonical(saved)
	if audio!=null: audio.stop()
	playing=false;present();return ""
func target() -> bool:
	if not active() or state.phase!="idle": return false
	var from: Vector3=host.camera.global_position
	var offset:=global_position-from
	if offset.length()>110.0 or offset.length()<0.001 or (-host.camera.global_basis.z).dot(offset.normalized())<0.96: return false
	var query:=PhysicsRayQueryParameters3D.create(from,global_position,1,[host.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func use() -> bool:
	if not target() or not State.use(state): return false
	present();return true
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode==KEY_E and use(): get_viewport().set_input_as_handled()
func _physics_process(delta: float) -> void:
	if host==null or mesh==null: return
	audio.stream_paused=not active()
	if active():
		State.advance(state,src,delta)
		if state.phase=="moving":
			var p: Vector3=Vector3(state.position[0],state.position[1],state.position[2])+host.native_translation
			var query:=PhysicsRayQueryParameters3D.create(p+Vector3.UP*64,p-Vector3.UP*512,1,[host.player.get_rid()])
			var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
			if not hit.is_empty(): state.position[1]=float(hit.position.y-host.native_translation.y)+44.0
	present()
func present() -> void:
	if mesh==null: return
	position=Vector3(state.position[0],state.position[1],state.position[2])+host.native_translation
	mesh.visible=state.phase!="removed"
	library.present(material,8,1 if state.phase=="moving" else 0,int(float(state.animation)*15.0)% (23 if state.phase=="moving" else 10))
	for pair in host.occluder_pairs+host.light_pairs:
		if pair[0]!=mesh: continue
		pair[1].global_transform=mesh.global_transform
		pair[1].visible=mesh.is_visible_in_tree()
		pair[1].material_override.set_shader_parameter("indices",library.last_texture)
	if state.phase!="idle" and float(state.sound_sample)<float(src.sound.samples):
		if not playing:
			audio.play(float(state.sound_sample)/float(src.sound.rate));playing=true
	else:
		if playing: audio.stop()
		playing=false
