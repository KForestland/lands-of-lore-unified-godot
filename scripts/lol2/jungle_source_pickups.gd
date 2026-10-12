extends Node3D
## Huline Jungle world item row 51 only. The other 87 rows are not spawned.
## E, 96-unit reach, 0.97 aim and mask-1 occlusion match the Hive wax pickup.
## The sprite is the original inventory image on a modern billboard.
const ITEM := "jungle:item51:Th_Dagger"
const ROW := 51
const DEFINITION := 9
const IDENTITY := 2242013435
const ROOT := "res://assets/lol2/generated/jungle_source_pickups/"
const REACH := 96.0
const AIM := 0.97
var host: Node3D
var sprite: Sprite3D
var collected := false

func _ready() -> void:
	host = get_parent()
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(ROOT + "pickups.json"))
	var admitted: Array = catalog.admitted_rows
	assert(admitted.size() == 1 and int(admitted[0]) == ROW)
	assert(catalog.pickups.size() == 1)
	var row: Dictionary = catalog.pickups[0]
	assert(int(row.row) == ROW and bool(row.admitted) and row.id == ITEM)
	assert(row.name == "10-Th Dagger" and int(row.definition) == DEFINITION and int(row.identity) == IDENTITY)
	assert(int(row.flags) == 2 and not bool(row.dormant) and int(row.region) == 3827)
	var image := Image.load_from_file(ROOT + "th_dagger.png")
	sprite = Sprite3D.new()
	sprite.texture = ImageTexture.create_from_image(image)
	sprite.pixel_size = 0.5
	var place: Array = row.position
	sprite.position = Vector3(float(place[0]), float(place[1]), float(place[2]))
	sprite.offset.y = image.get_height() / 2.0
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(sprite)
	restore()

func carried() -> Array:
	var pack = host.get("carried_collected")
	return pack if pack is Array else []

func restore() -> void:
	if ITEM in carried(): host.quest_state["jungle_dagger_collected"] = true
	collected = bool(host.quest_state.get("jungle_dagger_collected", false))
	if sprite != null:
		sprite.visible = not collected

func aim_point() -> Vector3:
	return sprite.global_position + Vector3(0, sprite.texture.get_height() * sprite.pixel_size / 2.0, 0)

func target() -> bool:
	if collected or sprite == null or not sprite.visible: return false
	if host.flying or get_tree().paused or not _mouse_ready(): return false
	if _overlay_blocks(): return false
	var delta: Vector3 = aim_point() - host.camera.global_position
	if delta.length() < 0.01 or delta.length() > REACH: return false
	if (-host.camera.global_basis.z).dot(delta.normalized()) < AIM: return false
	var query := PhysicsRayQueryParameters3D.create(host.camera.global_position, aim_point(), 1, [host.player.get_rid()])
	query.hit_from_inside = true
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func collect() -> bool:
	if not host.get("carried_collected") is Array: return false
	if ITEM in host.carried_collected:
		restore()
		return false
	if not target(): return false
	host.carried_collected.append(ITEM)
	restore()
	return true

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E and collect():
		get_viewport().set_input_as_handled()

func _mouse_ready() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED

func _overlay_blocks() -> bool:
	var hud = host.get("interface_hud")
	if hud != null and is_instance_valid(hud) and hud.cursor_active: return true
	var inventory = host.get("inventory")
	if inventory != null and is_instance_valid(inventory): return true
	for name in ["departure", "monastery", "magic_shop", "weapon_shop", "village_dialogue", "followup_dialogue"]:
		var room = host.get(name)
		if room != null and is_instance_valid(room) and room.has_method("active") and room.active(): return true
	return false
