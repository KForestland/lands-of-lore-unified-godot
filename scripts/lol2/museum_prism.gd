extends Node3D
## Prop280/group6590: one empty-hand Prism grant, then remove the display.
const ITEM := "museum:prop280:Prism"
const Catalog = preload("res://scripts/lol2/item_catalog.gd")
var host: Node3D
var taken := false
var display: Sprite3D
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
	add_child(display);restore(saved)
func checkpoint() -> bool:return taken
func restore(saved: bool) -> void:
	taken=saved
	if is_instance_valid(display):display.visible=not taken
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
