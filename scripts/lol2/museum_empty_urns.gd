extends Node3D
## Original template30 urns with no reward commands. Ivory urns189/195 keep their owner.
## Hit admission follows their identical kind9 filter; hiding the spent urn is the existing modern break adapter.
const SOURCE := "res://scripts/lol2/museum_empty_urns_source.json"
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
const IDS := [187,188,190,191,192,193,194,196,197]
class UrnBody extends StaticBody3D:
	var receiver: Node3D
	var index: int
	func receive_spark() -> void: receiver.receive_hit(index,8)
var host: Node3D
var broken: Array = [false,false,false,false,false,false,false,false,false]
var bodies: Array[StaticBody3D] = []
var urns: Array[MeshInstance3D] = []
static func validate(value: Variant) -> String:
	if value == null: return ""
	if not value is Dictionary or value.size()!=2 or value.get("version")!=1 or not value.get("broken") is Array or value.broken.size()!=IDS.size(): return "Invalid Museum urn checkpoint."
	for flag in value.broken:
		if not flag is bool: return "Invalid Museum urn break flag."
	return ""
func setup(owner: Node3D, saved: Variant=null) -> String:
	host=owner;name="MuseumEmptyUrns"
	var source: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	var material:=StandardMaterial3D.new()
	material.albedo_texture=ImageTexture.create_from_image(Image.load_from_file("res://assets/lol2/generated/museum_ivory/urn_1.png"))
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
	material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.texture_filter=BaseMaterial3D.TEXTURE_FILTER_NEAREST
	material.cull_mode=BaseMaterial3D.CULL_DISABLED
	for i in IDS.size():
		var row: Dictionary=source.urns[i]
		var p: Array=row.position
		var position:=Vector3(p[0],p[1],p[2])
		var mesh:=MeshInstance3D.new();var quad:=QuadMesh.new()
		quad.size=Vector2(44,29);quad.center_offset=Vector3(-4.5,14.5,0)
		mesh.mesh=quad;mesh.material_override=material;mesh.position=position;add_child(mesh);urns.append(mesh)
		var body:=UrnBody.new();body.receiver=self;body.index=i
		body.collision_layer=2;body.collision_mask=0;body.set_meta("spark_receiver",body)
		body.position=position+Vector3.UP*14.5
		var shape:=BoxShape3D.new();shape.size=Vector3(44,29,44)
		var collision:=CollisionShape3D.new();collision.shape=shape;body.add_child(collision)
		add_child(body);bodies.append(body)
	return restore_checkpoint(saved)
func checkpoint() -> Dictionary: return {"version":1,"broken":broken.duplicate()}
func restore_checkpoint(value: Variant) -> String:
	var error:=validate(value)
	if not error.is_empty(): return error
	broken=[false,false,false,false,false,false,false,false,false] if value==null else value.broken.duplicate()
	present();return ""
func present() -> void:
	for i in urns.size():
		urns[i].visible=not broken[i]
		bodies[i].collision_layer=0 if broken[i] else 2
func receive_hit(index: int, damage: int) -> bool:
	if not is_instance_valid(host.starting_magic) or not host.starting_magic.world_active(): return false
	if index<0 or index>=IDS.size() or damage<=0 or broken[index]: return false
	broken[index]=true;present();host.save_feedback("The urn breaks.");return true
func strike() -> bool:
	if not is_instance_valid(host.starting_magic) or not host.starting_magic.world_active(): return false
	if host.player_form==0 and (host.equipped_item not in host.carried_collected or Catalog.slot(host.equipped_item)!="weapon"): return false
	if host.player_form==2: return false
	var origin: Vector3=host.camera.global_position
	var ray:=PhysicsRayQueryParameters3D.create(origin,origin-host.camera.global_basis.z*96,3,[host.player.get_rid()])
	var hit:=get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty() or not hit.collider is UrnBody or hit.collider.receiver!=self: return false
	return receive_hit(hit.collider.index,1)
