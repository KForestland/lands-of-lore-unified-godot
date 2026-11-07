extends Node3D
## Source scenic guard55. No target/combat/loot interface. All environmental
## commands must be acknowledged by a supplied host adapter in original order.
const State=preload("res://scripts/lol2/cave_scenic_guard_state.gd")
const Library=preload("res://scripts/lol2/creature_sprite_library.gd")
var source:=State.source()
var state:=State.initial()
var library:=Library.new()
var mesh: MeshInstance3D
var material: ShaderMaterial
var host: Node3D
var effect_handler: Callable
var active: Callable
var prop_meshes: Dictionary={}
var prop_texture: Texture2D
var effects: Node3D
func setup(owner_host: Node3D, supplied_effects: Callable=Callable(), world_active: Callable=Callable(), saved: Variant=null) -> String:
	host=owner_host;effect_handler=supplied_effects;active=world_active
	var error:=library.load_manifest("res://assets/lol2/generated/cave_scenic_guard/")
	if not error.is_empty():return error
	mesh=MeshInstance3D.new();var quad:=QuadMesh.new()
	# Same human scale as source cave guards; canvas comes from full original frames.
	quad.size=Vector2(400,248)*0.25;quad.center_offset=Vector3(0,28,0);mesh.mesh=quad
	material=library.bind(mesh,true);mesh.layers=2;add_child(mesh)
	if host.has_method("_copy_occluders"):host._copy_occluders(mesh)
	var translation=host.get("native_translation")
	position=Vector3(source.position[0],source.position[1],source.position[2])+(translation if translation is Vector3 else Vector3.ZERO)
	var path:="res://assets/lol2/generated/cave_scenic_guard/prop_617.png"
	if FileAccess.get_sha256(path)!=source.prop_still_sha256:return "Scenic helper still changed."
	prop_texture=ImageTexture.create_from_image(Image.load_from_file(path))
	for row in source.prop_rows:
		var prop:=MeshInstance3D.new();var shape:=QuadMesh.new()
		shape.size=Vector2(row.right-row.left,row.top-row.bottom)
		shape.center_offset=Vector3((row.left+row.right)/2.0,(row.top+row.bottom)/2.0,0)
		prop.mesh=shape;prop.layers=2
		var mat:=library.bind(prop,true);mat.set_shader_parameter("indices",prop_texture)
		prop.position=Vector3(row.position[0]-source.position[0],row.position[1]-source.position[1],row.position[2]-source.position[2])
		add_child(prop);prop_meshes[str(int(row.record))]=prop
		if host.has_method("_copy_occluders"):host._copy_occluders(prop)
	effects=preload("res://scripts/lol2/cave_scenic_guard_effects.gd").new();add_child(effects)
	error=effects.setup(self)
	if not error.is_empty():return error
	return restore(saved if saved!=null else State.initial())
func checkpoint() -> Dictionary:return state.duplicate(true)
func restore(saved: Variant) -> String:
	var error:=State.validate(saved,source)
	if not error.is_empty():return error
	state=State.canonical(saved);present()
	if effects!=null:effects.present(true)
	return ""
func supply_event(event: String) -> bool:
	if not State.enqueue(state,event):return false
	State.drain(state,source,effect_handler);present();return true
func advance(delta: float) -> void:
	if get_tree().paused or not active.is_valid() or not active.call():return
	State.drain(state,source,effect_handler)
	State.advance(state,source,delta)
	if effects!=null:effects.advance(delta)
	present()
func _physics_process(delta: float) -> void:advance(delta)
func present() -> void:
	if mesh==null:return
	mesh.visible=state.present
	for id in prop_meshes:prop_meshes[id].visible=state.prop_present if id=="574" else state.prop223_present
	library.present(material,7,int(state.selector),State.frame(state,source))
	if host.has_method("sync_render_source"):
		host.sync_render_source(mesh, library.last_texture)
		for id in prop_meshes:
			host.sync_render_source(prop_meshes[id], prop_texture)

## Only concrete source presence effects are implemented. Unknown flag/movie/etc
## helpers keep their cursor pending; they are never acknowledged as completed.
func scene_effect(command: Dictionary) -> bool:
	if effects!=null and effects.apply(command):return true
	if command.op!=9:return false
	if command.kind==2 and command.target==54 and command.argument==3:
		var guards=host.get("guard_population")
		if guards==null:return false
		guards.State.spawn(guards.state,"54");guards.present();return true
	if command.kind==3 and command.target==223 and command.argument==3:return prop_meshes.has("223")
	if command.kind==3 and command.target==574 and command.argument==2:return prop_meshes.has("574")
	return false
func scene_active() -> bool:
	return host!=null and host.get("starting_magic")!=null and host.starting_magic.world_active()

## Collision target represents the source prop574 explosion helper, not guard55.
## Existing basic Spark supplies mask1; melee mask2 is excluded by source mask17.
func receive_damage(id: String,_amount: int,melee: bool=true,effect: int=20) -> bool:
	if id not in ["prop574","prop223"] or melee or effect!=20 or not scene_active() or effects==null:return false
	return effects.receive_spark() if id=="prop574" else effects.receive_spark223()
## Source op19 hit delivered to prop223 (tar fire: masks 0x0010/0x0000, damage5). Returns whether group2326 started.
func receive_prop223_hit(mask0: int, mask2: int, damage: int) -> bool:
	if effects==null:return false
	return effects.receive_prop223_hit(mask0,mask2,damage)
