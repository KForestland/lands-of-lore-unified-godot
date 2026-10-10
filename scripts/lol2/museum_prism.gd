extends Node3D
## Prop280/group6590: one empty-hand Prism grant, then remove the display. The same group's seven op204
## commands clear the alcove's painted panorama (wall records 1743..1772, descriptors 430..424 -> transparent
## 871; museum_prism_panorama.json, docs/prism-effects.md): shown while the Prism is on display, cleared by the
## pickup and by a taken receipt. No new save field. The Prism's on-hit blind lives in prism_blind.gd.
const ITEM := "museum:prop280:Prism"
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const PANORAMA := "res://scripts/lol2/museum_prism_panorama.json"
const ROOT := "res://assets/lol2/generated/museum_prism/"
var host: Node3D
var taken := false
var display: Sprite3D
var panorama: MeshInstance3D
static func assets_ready() -> bool:
	var data=JSON.parse_string(FileAccess.get_file_as_string(PANORAMA)) if FileAccess.file_exists(PANORAMA) else null
	if not data is Dictionary or not data.get("panels") is Array or data.panels.size()!=7: return false
	for panel in data.panels:
		if not FileAccess.file_exists(ROOT+str(panel.image)): return false
	return true
static func validate(saved: Variant,carried: Array) -> String:
	if not saved is bool or saved != (ITEM in carried):return "Prism receipt and inventory disagree."
	return ""
func setup(owner: Node3D,saved: bool=false) -> void:
	host=owner
	if is_instance_valid(host.museum_props):
		for child in host.museum_props.get_children():
			if child.get_meta("source_record",-1)==280:child.hide()
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://scripts/lol2/museum_prism_source.json"))
	var prop: Dictionary=source.prop
	display=Sprite3D.new();display.texture=ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/museum_prism/display.png"))
	display.billboard=BaseMaterial3D.BILLBOARD_FIXED_Y;display.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	display.alpha_cut=SpriteBase3D.ALPHA_CUT_DISCARD
	display.pixel_size=(float(prop.right)-float(prop.left))/float(display.texture.get_width())
	var p: Array=prop.position
	display.position=Vector3(p[0],float(p[1])+(float(prop.top)+float(prop.bottom))/2.0,p[2])
	add_child(display);_build_panorama(Vector3(p[0],0,p[2]));restore(saved)
## One surface per source panel, one-sided toward the Prism (front faces wind clockwise as seen from the alcove).
func _build_panorama(centre: Vector3) -> void:
	if not assets_ready(): push_warning("Museum Prism panorama assets missing; panels not shown.");return
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(PANORAMA))
	var mesh:=ArrayMesh.new()
	for panel in data.panels:
		var points: Array[Vector3]=[];var uv: Array[Vector2]=[]
		for i in 4:
			points.append(Vector3(panel.points[i][0],panel.points[i][1],panel.points[i][2]));uv.append(Vector2(panel.uv[i][0],panel.uv[i][1]))
		var order:=[0,1,2,0,2,3]
		var inward: Vector3=centre-points[0];inward.y=0
		if (points[1]-points[0]).cross(points[2]-points[0]).dot(inward)>0: order=[0,2,1,0,3,2]
		var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in order:
			surface.set_uv(uv[i]);surface.add_vertex(points[i])
		surface.commit(mesh)
		var material:=StandardMaterial3D.new()
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(ROOT+str(panel.image)))
		mesh.surface_set_material(mesh.get_surface_count()-1,material)
	panorama=MeshInstance3D.new();panorama.name="PrismPanorama";panorama.mesh=mesh;add_child(panorama)
func checkpoint() -> bool:return taken
func restore(saved: bool) -> void:
	taken=saved
	if is_instance_valid(display):display.visible=not taken
	if is_instance_valid(panorama):panorama.visible=not taken
func active() -> bool:
	return not taken and host.hand_item=="" and not host.flying and not get_tree().paused and is_instance_valid(host.starting_magic) and host.starting_magic.world_active()
func reachable() -> bool:
	if not active():return false
	var delta: Vector3=display.global_position-host.camera.global_position
	if delta.length()<0.01 or delta.length()>96 or (-host.camera.global_basis.z).dot(delta.normalized())<0.97:return false
	var ray:=PhysicsRayQueryParameters3D.create(host.camera.global_position,display.global_position,1,[host.player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
func interaction_hint() -> String:return "E — Take Prism" if reachable() else ""
func use() -> bool:
	if not reachable():return false
	if host.carried_collected.size()>=Catalog.MAX_CARRIED:
		host.save_feedback("You cannot carry more.");return true
	host.carried_collected.append(ITEM);restore(true);host.save_feedback("Prism added to inventory.")
	return true
