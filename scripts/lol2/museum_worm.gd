extends Node3D
## Prop163 source region-triggered movie. Exact cyan key and fixed-Y billboard are presentation adapters.
const ROOT := "res://assets/lol2/generated/museum_worm/"
var host: Node3D
var active := false
var elapsed := 0.0
var last_region := -1
var regions: Array = []
var mesh: MeshInstance3D
var material: StandardMaterial3D
var current_frame := -1
static func validate(value: Variant) -> String:
	if value == null: return ""
	if not value is Dictionary or value.size()!=3 or value.get("version")!=1 or not value.get("active") is bool: return "Invalid Museum worm checkpoint."
	var time=value.get("elapsed")
	if not (time is float or time is int) or not is_finite(float(time)) or time<0 or time>=4: return "Invalid Museum worm time."
	if not value.active and time!=0: return "Inactive Museum worm has elapsed time."
	return ""
func setup(owner: Node3D,saved: Variant=null) -> String:
	host=owner;name="MuseumWorm"
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(ROOT+"source.json"))
	regions=source.regions
	mesh=MeshInstance3D.new();var quad:=QuadMesh.new()
	quad.size=Vector2(254,143);quad.center_offset=Vector3(0.5,71.5,0)
	mesh.mesh=quad;mesh.position=Vector3(-1749,-75,-1663)
	material=StandardMaterial3D.new()
	material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(ROOT+"atlas.png"))
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	material.uv1_scale=Vector3(0.1,1.0/6.0,1)
	mesh.material_override=material;add_child(mesh)
	return restore_checkpoint(saved)
func checkpoint() -> Dictionary: return {"version":1,"active":active,"elapsed":elapsed}
func restore_checkpoint(value: Variant) -> String:
	var error:=validate(value)
	if not error.is_empty(): return error
	active=false if value==null else value.active
	elapsed=0.0 if value==null else float(value.elapsed)
	last_region=-1;current_frame=-1;present();return ""
func region_at(position: Vector3) -> int:
	for row in regions:
		if position.y<row.floor-1 or position.y>row.ceiling+1: continue
		var polygon:=PackedVector2Array()
		for point in row.polygon_xz: polygon.append(Vector2(point[0],point[1]))
		if Geometry2D.is_point_in_polygon(Vector2(position.x,position.z),polygon): return int(row.owner.owner)
	return -1
func _physics_process(delta: float) -> void:
	if not is_instance_valid(host) or host.get_tree().paused or host.introduction_state!="complete":return
	if not is_instance_valid(host.starting_magic) or not host.starting_magic.world_active():return
	var region:=region_at(host.player.position)
	if region!=last_region:
		for row in regions:
			if int(row.owner.owner)==region and active!=row.active:
				active=row.active;elapsed=0.0
		last_region=region
	if active: elapsed=fposmod(elapsed+delta,4.0)
	present()
func present() -> void:
	if not is_instance_valid(mesh):return
	mesh.visible=active
	var frame:=int(elapsed*15.0)%60
	if frame!=current_frame:
		material.uv1_offset=Vector3(float(frame%10)/10.0,float(frame/10)/6.0,0)
		current_frame=frame
