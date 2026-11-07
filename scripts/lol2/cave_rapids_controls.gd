extends Node3D
## Original template38 geometry and accepted-motion state. Caller owns trigger/save/world gating.
## Entry selectors come from each original event9 group; ongoing native animation is not hosted here.
const State=preload("res://scripts/lol2/cave_rapids_control_state.gd")
const Trig=preload("res://scripts/lol2/scripted_control_displacement.gd")
const ROOT="res://assets/lol2/generated/cave_rapids_trigger/"
var host: Node3D
var state: Dictionary={}
var tick_fraction:=0.0
var bodies: Dictionary={}
var surfaces: Dictionary={}
var sprites: Dictionary={}
var collisions: Dictionary={}
var last_headings: Dictionary={}
var materials: Dictionary={}
func _rotated(point: Array, heading: int) -> Vector3:
	var sine:=Trig._sine(heading);var cosine:=Trig._sine(heading+16384)
	var x: int=((int(point[0])*cosine)>>16)+((int(point[1])*sine)>>16)
	var y: int=((int(point[1])*cosine)>>16)-((int(point[0])*sine)>>16)
	return Vector3(float(x)/65536.0,float(point[2])/65536.0,-float(y)/65536.0)
func setup(owner: Node3D, rounding_mode: int) -> String:
	host=owner;state=State.initial(rounding_mode)
	if state.is_empty():return "Invalid control rounding mode."
	name="CaveRapidsControls"
	for image in ["control86.png","child13.png","child15.png"]:
		if FileAccess.get_sha256(ROOT+image)!=str(State.source().files[image]):return "Rapids control art differs."
		var material: ShaderMaterial=host._indexed_material(ROOT+image)
		material.set_shader_parameter("sprite",image!="control86.png");materials[image]=material
	for row in State.source().controls:
		var id:=str(int(row.motion.owner));var mask: int=1<<int(row.arrival.selector)
		var body:=AnimatableBody3D.new();body.name="Control"+id;body.sync_to_physics=false;body.collision_layer=1;body.collision_mask=0
		body.set_meta("source_control",int(id));add_child(body);bodies[id]=body;surfaces[id]=[];sprites[id]=[]
		for face in row.faces+row.state_faces:
			if not int(face.child_mask)&mask:continue
			var mesh:=MeshInstance3D.new();mesh.layers=2;mesh.material_override=materials[face.index_image];body.add_child(mesh)
			surfaces[id].append({"mesh":mesh,"source":face})
		for source in row.sprites+row.state_sprites:
			if not int(source.child_mask)&mask:continue
			var mesh:=MeshInstance3D.new();mesh.layers=2;mesh.material_override=materials[source.index_image]
			var quad:=QuadMesh.new();quad.size=Vector2(float(source.right)-float(source.left),float(source.top)-float(source.bottom))
			quad.center_offset=Vector3((float(source.left)+float(source.right))/2.0,(float(source.top)+float(source.bottom))/2.0,0)
			mesh.mesh=quad;body.add_child(mesh);sprites[id].append({"mesh":mesh,"source":source})
		var collision:=CollisionShape3D.new();body.add_child(collision);collisions[id]=collision
	present()
	host._copy_occluders(self)
	return ""
static func initial_packet() -> Dictionary:
	# Explicit port choice until the live original FPU control word is established.
	return {"version":1,"state":State.initial(0),"tick_fraction":0.0}
static func validate_packet(value: Variant) -> String:
	if not value is Dictionary or value.size()!=3 or value.get("version")!=1:return "Invalid rapids controls packet."
	var error:=State.validate(value.get("state"))
	if not error.is_empty():return error
	var fraction: Variant=value.get("tick_fraction")
	if not (fraction is float or fraction is int) or not is_finite(float(fraction)) or fraction<0 or fraction>=1:return "Invalid rapids control clock."
	return ""
func checkpoint() -> Dictionary:return {"version":1,"state":state.duplicate(true),"tick_fraction":tick_fraction}
func restore(value: Variant) -> String:
	var error:=validate_packet(value)
	if not error.is_empty():return error
	state=State.canonical(value.state);tick_fraction=float(value.tick_fraction);present();return ""
func start() -> bool:return State.start(state)
func advance(delta: float, active: bool) -> void:
	if not active or not is_finite(delta) or delta<=0 or not state.started:return
	var moving:=false
	for control in state.controls.values():
		if not control.complete:moving=true
	if not moving:return
	tick_fraction+=delta*60.0
	while tick_fraction>=1:
		tick_fraction-=1
		State.advance_accepted(state,65536,1)
	present()
func advance_accepted(tick_fixed: int, ticks: int) -> Array:
	var events:=State.advance_accepted(state,tick_fixed,ticks);present();return events
func present() -> void:
	for id in bodies:
		var control: Dictionary=state.controls[id];var body: AnimatableBody3D=bodies[id]
		var heading:=int(control.heading)
		if int(last_headings.get(id,-1))!=heading:
			var triangles:=PackedVector3Array()
			for face in surfaces[id]:
				var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
				for i in [0,1,2,0,2,3]:
					var vertex:=_rotated(face.source.local_fixed[i],heading)
					surface.set_uv(Vector2(face.source.uv[i][0],face.source.uv[i][1]));surface.add_vertex(vertex);triangles.append(vertex)
				surface.generate_normals();face.mesh.mesh=surface.commit()
				# These copies share the old mesh resource, so replacing it must update both passes.
				var mask_copy: Variant=host.occluder_by_source.get(face.mesh)
				if mask_copy is MeshInstance3D:mask_copy.mesh=face.mesh.mesh
				var light_bank: Variant=host.get("light_by_source")
				if light_bank is Dictionary:
					var light_copy: Variant=light_bank.get(face.mesh)
					if light_copy is MeshInstance3D:light_copy.mesh=face.mesh.mesh
			var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(triangles);collisions[id].shape=shape
			for sprite in sprites[id]:sprite.mesh.position=_rotated(sprite.source.local_fixed,heading)
			last_headings[id]=heading
		body.position=host.native_translation+Vector3(float(control.position[0])/65536.0,float(control.position[2])/65536.0,-float(control.position[1])/65536.0)
		for face in surfaces[id]:host.sync_render_source(face.mesh)
		for sprite in sprites[id]:host.sync_render_source(sprite.mesh)
