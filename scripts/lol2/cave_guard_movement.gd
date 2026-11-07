extends Node3D
## Original geometry and native travel arithmetic; Godot bodies supply collision.
## Caller owns source command order, tick clock, callbacks and save transaction.
const State=preload("res://scripts/lol2/cave_guard_movement_state.gd")
## Spiked bar gates (material 133): see-through between the bars, solid to walk into.
const BARS: Array[int]=[70,71,73]
var src:=State.source()
var state: Dictionary={}
var bodies: Dictionary={}
var materials: Dictionary={}
var origin:=Vector3.ZERO
var render_host: Node3D
var surfaces: Array[MeshInstance3D]=[]
var face_centers: Dictionary={}
func setup(translation: Vector3, saved: Variant=null, indexed_host: Node3D=null) -> String:
	origin=translation;render_host=indexed_host
	var proposed: Variant=State.initial(src) if saved==null else saved
	var error:=State.validate(proposed,src)
	if not error.is_empty():return error
	state=State.canonical(proposed)
	for file in src.materials:
		if FileAccess.get_sha256(file)!=str(src.materials[file]):return "Encounter movable texture hash differs."
		var material:=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
		material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file(file));material.cull_mode=BaseMaterial3D.CULL_DISABLED
		materials[file]=material
		if render_host!=null:
			var indexed: Dictionary=src.indexed_materials[file]
			if FileAccess.get_sha256(indexed.path)!=str(indexed.sha256):return "Encounter index texture hash differs."
			materials[file]=render_host._indexed_material(indexed.path)
	# The bar gates' texture (material 133) is open between the bars (index 0 / alpha 0, 61% of the texels); drawn
	# without the cutout the gaps became a black panel and hid the guard (KENNETH_ROOM_REPRO_20261028 B2).
	for row in src.movables:
		if int(row.motion.index) in BARS:
			for face in row.faces:
				var bar_material: Material=materials[face.material]
				if bar_material is ShaderMaterial:bar_material.set_shader_parameter("cutout",true)
				elif bar_material is StandardMaterial3D:bar_material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	for row in src.movables:
		var id:=str(int(row.motion.index));var body:=AnimatableBody3D.new();body.name="SourceMovable"+id;body.collision_layer=1;body.collision_mask=0;body.sync_to_physics=false
		body.set_meta("original_record",int(id));add_child(body);bodies[id]=body
		var placement: Dictionary=row.placement;var anchor:=Vector3(placement.x,placement.height,-placement.y)
		var hull:=PackedVector3Array()
		face_centers[id]=[]
		for face in row.faces:
			var center:=Vector3.ZERO
			for point in face.points:center+=Vector3(point[0],point[1],point[2])-anchor
			face_centers[id].append(center/4)
			var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES);surface.set_material(materials[face.material])
			for n in [0,1,2,0,2,3]:
				var point: Array=face.points[n];var vertex:=Vector3(point[0],point[1],point[2])-anchor
				surface.set_uv(Vector2(face.uv[n][0],face.uv[n][1]));surface.add_vertex(vertex)
				if not hull.has(vertex):hull.append(vertex)
			var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.layers=2;body.add_child(mesh);surfaces.append(mesh)
		var shape:=ConvexPolygonShape3D.new();shape.points=hull
		var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
	present()
	if render_host!=null:render_host._copy_occluders(self)
	return ""
## Bodies of the bar gates, for line-of-sight checks that must look through the bars.
func bar_rids() -> Array[RID]:
	var rids: Array[RID]=[]
	for id in BARS:
		if bodies.has(str(id)):rids.append(bodies[str(id)].get_rid())
	return rids
func checkpoint() -> Dictionary:return state.duplicate(true)
func restore(saved: Variant) -> String:
	var error:=State.validate(saved,src)
	if not error.is_empty():return error
	state=State.canonical(saved);present();return ""
func command(id: int, percent: int) -> bool:return State.command(state,src,id,percent)
func advance(tick_fixed: int) -> Array:
	var events:=State.advance(state,src,tick_fixed);present();return events
func present() -> void:
	for row in src.movables:
		var id:=int(row.motion.index);var placement: Dictionary=row.placement
		bodies[str(id)].position=origin+Vector3(placement.x,float(placement.height)+State.vertical_offset(state,src,id),-placement.y)

	if render_host!=null:
		for mesh in surfaces:render_host.sync_render_source(mesh)
