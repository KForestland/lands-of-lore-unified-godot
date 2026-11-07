extends Node3D
## Actual Cave surfaces for the verified material/motion portion of group5074.
## Full control103/prop453/view/audio chain remains separate; start_material_motion
## is called only after those preceding commands have been accepted by its owner.
const State=preload("res://scripts/lol2/cave_rapids_floor_state.gd")
var state:=State.initial()
var tick_fraction:=0.0
var host: Node3D
var floors: Dictionary={}
static func initial_packet() -> Dictionary:
	return {"version":1,"state":State.initial(),"tick_fraction":0.0}
static func validate_packet(value: Variant) -> String:
	if not value is Dictionary or value.get("version")!=1 or value.size()!=3:return "Invalid rapids world packet."
	var error:=State.validate(value.get("state"))
	if not error.is_empty():return error
	var f=value.get("tick_fraction")
	if not (f is float or f is int) or not is_finite(float(f)) or f<0 or f>=1:return "Invalid rapids clock fraction."
	return ""
func setup(owner: Node3D) -> void:
	host=owner;name="CaveRapidsFloors"
	for row in State.source().floors:
		var body:=AnimatableBody3D.new();body.name="Region%d" % int(row.region);body.sync_to_physics=false
		add_child(body)
		var triangles:=PackedVector3Array()
		for i in [0,1,2,0,2,3]:triangles.append(Vector3(float(row.polygon[i][0]),0,float(row.polygon[i][1])))
		var shape:=ConcavePolygonShape3D.new();shape.backface_collision=true;shape.set_faces(triangles)
		var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
		var meshes: Array=[]
		for changed in [false,true]:
			var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			var uv: Array=row.uv_after if changed else row.uv_before
			for i in [0,1,2,0,2,3]:
				surface.set_uv(Vector2(float(uv[i][0]),float(uv[i][1])))
				surface.add_vertex(Vector3(float(row.polygon[i][0]),0,float(row.polygon[i][1])))
			surface.generate_normals()
			var mesh:=MeshInstance3D.new();mesh.mesh=surface.commit();mesh.layers=2
			# Share the existing animated Rapids material rather than another animation clock.
			mesh.material_override=host.indexed_floor_materials["134" if changed else "310"]
			body.add_child(mesh);meshes.append(mesh);host._copy_occluders(mesh)
		floors[str(int(row.region))]={"body":body,"meshes":meshes}
	present()
func checkpoint() -> Dictionary:
	return {"version":1,"state":state.duplicate(true),"tick_fraction":tick_fraction}
func restore(value: Variant) -> String:
	var error:=validate_packet(value)
	if not error.is_empty():return error
	state=State.canonical(value.state);tick_fraction=float(value.tick_fraction);present();return ""
func start_material_motion() -> bool:
	if not State.start(state):return false
	present();return true
func advance(delta: float, active: bool) -> void:
	if not active or not is_finite(delta) or delta<=0 or not state.started:return
	var moving:=false
	for f in state.floors.values():
		if f.remaining!=0:moving=true
	if not moving:return
	tick_fraction+=delta*60.0
	while tick_fraction>=1:
		tick_fraction-=1
		for event in State.advance_accepted(state,65536):
			if State.local7_write(event):host.cave_local7=1
	present()
func present() -> void:
	for id in floors:
		var row: Dictionary=floors[id];var f: Dictionary=state.floors[id]
		# Existing authored drowning query must follow the source Rapids->Cave floor switch.
		# This does not assert native liquid-depth or region byte39 semantics.
		host.river_water.dry_regions[id]=state.started
		row.body.position=host.native_translation+Vector3(0,float(f.height),0)
		for i in range(2):
			var mesh: MeshInstance3D=row.meshes[i]
			mesh.visible=(i==1)==state.started
			host.sync_render_source(mesh)
