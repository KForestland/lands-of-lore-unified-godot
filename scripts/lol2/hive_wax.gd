extends Node3D
## Source Hive item0. E, aim/range, pivot and scale are modern pickup controls.
const ROOT := "res://assets/lol2/generated/hive_wax/"
const ITEM := "hive:item0:Wax"
var collected := false
var sprite: Sprite3D
var host: Node3D
func _ready() -> void:
	host = get_parent()
	var source = JSON.parse_string(FileAccess.get_file_as_string(ROOT+"wax.json"))
	var image := Image.load_from_file(ROOT+"wax.png")
	sprite = Sprite3D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.pixel_size = 0.5
	sprite.position = Vector3(source.position[0],source.position[1],source.position[2])
	sprite.offset.y = image.get_height()/2.0
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(sprite)
func aim_point() -> Vector3:
	return sprite.global_position + Vector3(0,sprite.texture.get_height()*sprite.pixel_size/2.0,0)
func target() -> bool:
	if collected or host.flying or get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED: return false
	if host.get_node("Warriors").health == 0 or host.interface_hud.cursor_active: return false
	var actor = host.get_node("ConversationReview")
	if actor.started and not actor.completed: return false
	var delta: Vector3 = aim_point()-host.camera.global_position
	if delta.length() < 0.01 or delta.length() > 96.0: return false
	if (-host.camera.global_basis.z).dot(delta.normalized()) < 0.97: return false
	var query := PhysicsRayQueryParameters3D.create(host.camera.global_position,aim_point(),1,[host.player.get_rid()])
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func collect() -> bool:
	if not target() or ITEM in host.carried_inventory.collected: return false
	host.carried_inventory.collected.append(ITEM)
	restore(true)
	return true
func restore(value: bool) -> void:
	collected = value
	sprite.visible = not collected
