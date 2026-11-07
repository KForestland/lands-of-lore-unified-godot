extends "res://scripts/lol2/hive_return_population.gd"
## Original unfold/eating films; shared combat steering remains a modern adapter.
const Ambush=preload("res://scripts/lol2/hive_ambush_state.gd")
const MEDIA_ROOT:="res://assets/lol2/generated/hive_ambush/"
var data: Dictionary
var films: Dictionary={}
var textures: Array[Texture2D]=[]
var prop363: MeshInstance3D
var feeding_target: StaticBody3D
func _ready() -> void:
	rules=Ambush;state=Ambush.initial();target_prefix="hiveambush"
	visual_paths={35:"res://assets/lol2/generated/hive_nest/executioner.png"}
	super._ready()
	# EXEC PNG retains its320x200 source canvas, unlike the cropped warrior pose.
	var executioner_pose: MeshInstance3D=bodies["35"].get_child(1)
	var executioner_quad:=QuadMesh.new()
	executioner_quad.size=Vector2(90,56)
	executioner_quad.center_offset.y=56.0*(176.0/200.0-0.5)-35.0
	executioner_pose.mesh=executioner_quad
	data=JSON.parse_string(FileAccess.get_file_as_string(MEDIA_ROOT+"ambush.json"))
	for clip in data.clips:
		textures.append(ImageTexture.create_from_image(Image.load_from_file(MEDIA_ROOT+clip.atlas)))
	for id in [33,35]:
		var prop:=316 if id==33 else 318
		var placement: Dictionary=data.placements.filter(func(p): return p.kind=="prop" and int(p.index)==prop)[0]
		var sprite:=MeshInstance3D.new()
		var quad:=QuadMesh.new()
		quad.size=Vector2(160,100) if id==33 else Vector2(125,78)
		# Fixed lowest opaque row across the related films, an explicit preview anchor.
		var baseline:=181.0 if id==33 else 187.0
		quad.center_offset.y=quad.size.y*(baseline/200.0-0.5)
		sprite.mesh=quad
		sprite.position=Vector3(placement.position[0],placement.position[1],placement.position[2])
		var mat:=StandardMaterial3D.new()
		mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		mat.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
		mat.cull_mode=BaseMaterial3D.CULL_DISABLED
		mat.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		sprite.material_override=mat
		add_child(sprite);films[str(id)]=sprite
	feeding_target=StaticBody3D.new()
	feeding_target.position=films["35"].position+Vector3(0,28,0)
	feeding_target.collision_layer=8
	feeding_target.collision_mask=0
	feeding_target.set_meta("hive_feeding_prop",318)
	var hit_shape:=CollisionShape3D.new()
	var capsule:=CapsuleShape3D.new()
	capsule.radius=24;capsule.height=56
	hit_shape.shape=capsule
	feeding_target.add_child(hit_shape)
	add_child(feeding_target)
	bind_source_props.call_deferred()
	present()
func bind_source_props() -> void:
	for sprite in host.get_node("SourcePropCandidates").instances:
		var record:=int(sprite.get_meta("source_record"))
		if record in [316,318]: sprite.hide()
		if record==363: prop363=sprite
	present()
func restore(saved: Dictionary) -> void:
	super.restore(saved)
func receive_feeding_spark() -> bool:
	if not active(): return false
	var admitted:=Ambush.spark_feeding(state)
	present()
	return admitted
func target_label(id: String) -> String:
	return ("Executioner" if id=="35" else "Hive Warrior")+" %d/%d" % [int(state.actors[id].health),Ambush.HEALTH[int(id)]]
func inside_region(region: Dictionary) -> bool:
	var p: Vector3=host.player.position
	if p.y<float(region.floor) or p.y>float(region.ceiling): return false
	var polygon:=PackedVector2Array()
	for point in region.polygon: polygon.append(Vector2(point[0],point[1]))
	return Geometry2D.is_point_in_polygon(Vector2(p.x,p.z),polygon)
func approach() -> void:
	if not active() or not host.player.is_on_floor(): return
	for region in data.regions:
		var id:=int(region.region)
		if id in [444,716] and inside_region(region): Ambush.arm(state,33 if id==444 else 35,id==716)
func _physics_process(delta: float) -> void:
	approach()
	advance(delta)
func advance(delta: float) -> void:
	if not active(): return
	Ambush.advance(state,delta)
	super.advance(delta)
	present()
func present() -> void:
	super.present()
	if is_instance_valid(feeding_target): feeding_target.collision_layer=8 if state.actors["35"].phase in [0,1,2] else 0
	if films.is_empty(): return # Base _ready restores before the films are created.
	for id in films:
		var a: Dictionary=state.actors[id]
		var sprite: MeshInstance3D=films[id]
		sprite.visible=a.phase!=3
		if not sprite.visible: continue
		var index:=0 if id=="33" else 2 if a.phase==2 else 1
		var clip: Dictionary=data.clips[index]
		sprite.mesh.center_offset.y=sprite.mesh.size.y*(float(clip.opaque_baseline_max)/200.0-0.5)
		var frame:=mini(int(float(a.elapsed)*15),int(clip.frames)-1)
		var material: StandardMaterial3D=sprite.material_override
		material.albedo_texture=textures[index]
		material.uv1_scale=Vector3(1.0/float(clip.columns),1.0/float(clip.rows),1)
		material.uv1_offset=Vector3(float(frame%int(clip.columns))/float(clip.columns),float(frame/int(clip.columns))/float(clip.rows),0)
	if is_instance_valid(prop363): prop363.visible=state.actors["35"].phase==3
