extends Node3D
## Camera frustum/world-ray adapter for native upstream assembly traversal eligibility.
const State=preload("res://scripts/lol2/museum_control96_state.gd")
const Creatures=preload("res://scripts/lol2/museum_skeleton_population_state.gd")
const ROOT="res://assets/lol2/generated/museum_control96/"
var host: Node3D
var state: Dictionary=State.initial()
var meshes: Array=[]
var textures: Array[ImageTexture]=[]
var source: Dictionary
var current_frame:=-2
var idle_texture: ImageTexture
static func assets_ready() -> bool:
	for file in ["source.json","material_403.png","material_259.png"]:
		if not FileAccess.file_exists(ROOT+file): return false
	for frame in range(68):
		if not FileAccess.file_exists(ROOT+"frame_%03d.png"%frame): return false
	return true
func setup(owner: Node3D, saved: Variant=null) -> String:
	if saved!=null:
		var error:=State.validate(saved)
		if not error.is_empty(): return error
		state=State.canonical(saved)
	host=owner
	source=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"source.json"))
	for file in source.frames: textures.append(ImageTexture.create_from_image(Image.load_from_file(ROOT+file)))
	for face in source.faces:
		var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in [0,1,2,0,2,3]:
			st.set_uv(Vector2(face.uv[i][0],face.uv[i][1]))
			var p=face.points[i];st.add_vertex(Vector3(p[0],p[1],p[2]))
		var mesh:=MeshInstance3D.new();mesh.mesh=st.commit()
		var mat:=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		mat.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(ROOT+face.texture))
		if int(face.source_index)==96: idle_texture=mat.albedo_texture
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mesh.material_override=mat;mesh.set_meta("control",int(face.source_index));add_child(mesh);meshes.append(mesh)
	present()
	return ""
func checkpoint() -> Dictionary: return state.duplicate(true)
func restore_checkpoint(value: Variant) -> String:
	var error:=State.validate(value)
	if not error.is_empty(): return error
	state=State.canonical(value);current_frame=-2;present();return ""
func eligible() -> bool:
	if not is_instance_valid(host) or not is_instance_valid(host.camera): return false
	var camera: Camera3D=host.camera
	# Sample center and inset corners of source face403. Nearby walls reject all samples.
	for target in [Vector3(426,39,-1337.5),Vector3(426,79,-1390),Vector3(426,79,-1285),Vector3(426,-1,-1390),Vector3(426,-1,-1285)]:
		if not camera.is_position_in_frustum(target): continue
		var offset: Vector3=target-camera.global_position
		if offset.length()<0.1: continue
		var ray:=PhysicsRayQueryParameters3D.create(camera.global_position,target-offset.normalized()*0.5)
		ray.exclude=[host.player.get_rid()]
		if host.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): return true
	return false
func _physics_process(delta: float) -> void:
	if not is_instance_valid(host) or host.get_tree().paused or host.introduction_state!="complete": return
	if host.starting_magic==null or not host.starting_magic.world_active(): return
	if not state.latched and eligible(): State.admit(state)
	var effects:=State.advance(state,delta)
	for effect in effects:
		if effect=="spawn30" and is_instance_valid(host.skeleton_population):
			Creatures.spawn(host.skeleton_population.state,"30")
			host.skeleton_population.present()
	present()
func present() -> void:
	var frame:=State.frame(state)
	for mesh in meshes:
		if int(mesh.get_meta("control"))==96:
			mesh.visible=state.present
			if frame!=current_frame: mesh.material_override.albedo_texture=textures[frame] if frame>=0 else idle_texture
		else: mesh.visible=state.control179
	current_frame=frame
